"""Prepare the Family Business modular character master in Blender.

Run with:
  blender --background animtest.blend --python prepare_modular_character.py -- <output_dir>

The source .blend is never saved. A new master and GLB are written to output_dir.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import bpy
import bmesh


MASTER_NAME = "FB_Character_Master_v001.blend"
GLB_NAME = "FB_Player_Modular_v001.glb"

OBJECT_RENAMES = {
    "Armature": "CHR_Armature",
    "Body": "BODY_Source",
    "Hoodie": "TOP_01_Hoodie",
    "Jeans": "BOTTOM_01_Jeans",
    "Sneakers.001": "SHOES_01_Sneakers",
}

MESH_NAMES = {
    "BODY_Source": "MESH_BODY_Source",
    "TOP_01_Hoodie": "MESH_TOP_01_Hoodie",
    "BOTTOM_01_Jeans": "MESH_BOTTOM_01_Jeans",
    "SHOES_01_Sneakers": "MESH_SHOES_01_Sneakers",
}

MATERIAL_NAMES = {
    "BODY_Source": "MAT_BODY_Skin",
    "TOP_01_Hoodie": "MAT_TOP_01_Hoodie",
    "BOTTOM_01_Jeans": "MAT_BOTTOM_01_Jeans",
    "SHOES_01_Sneakers": "MAT_SHOES_01_Sneakers",
}

ZONE_NAMES = ("Head", "Hands", "Torso", "Legs", "Feet")


def require_object(name: str, object_type: str) -> bpy.types.Object:
    obj = bpy.data.objects.get(name)
    if obj is None or obj.type != object_type:
        raise RuntimeError(f"Required {object_type} object is missing: {name}")
    return obj


def get_or_create_collection(
    name: str, parent: bpy.types.Collection
) -> bpy.types.Collection:
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
    if collection.name not in {child.name for child in parent.children}:
        parent.children.link(collection)
    return collection


def move_to_collection(
    obj: bpy.types.Object, collection: bpy.types.Collection
) -> None:
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def rename_existing_objects() -> None:
    for old_name, new_name in OBJECT_RENAMES.items():
        obj = require_object(
            old_name, "ARMATURE" if old_name == "Armature" else "MESH"
        )
        obj.name = new_name
        if obj.type == "MESH":
            obj.data.name = MESH_NAMES[new_name]
            for index, material in enumerate(obj.data.materials):
                if material is not None:
                    base_name = MATERIAL_NAMES[new_name]
                    material.name = (
                        base_name if index == 0 else f"{base_name}_Secondary_{index:02d}"
                    )


def bone_zone(name: str) -> str:
    normalized = name.lower().replace("mixamorig:", "")
    if "head" in normalized or normalized == "neck":
        return "Head"
    if "hand" in normalized:
        return "Hands"
    if "foot" in normalized or "toe" in normalized:
        return "Feet"
    if "upleg" in normalized or normalized.endswith("leg"):
        return "Legs"
    return "Torso"


def classify_faces(body: bpy.types.Object) -> dict[str, set[int]]:
    zones = {name: set() for name in ZONE_NAMES}
    group_names = {group.index: group.name for group in body.vertex_groups}

    for polygon in body.data.polygons:
        scores = {name: 0.0 for name in ZONE_NAMES}
        for vertex_index in polygon.vertices:
            vertex = body.data.vertices[vertex_index]
            for membership in vertex.groups:
                group_name = group_names.get(membership.group)
                if group_name:
                    scores[bone_zone(group_name)] += membership.weight
        zone = max(scores, key=scores.get)
        zones[zone].add(polygon.index)
    return zones


def make_body_zones(
    source: bpy.types.Object,
    body_collection: bpy.types.Collection,
) -> list[bpy.types.Object]:
    face_zones = classify_faces(source)
    created: list[bpy.types.Object] = []

    for zone_name in ZONE_NAMES:
        zone_object = source.copy()
        zone_object.data = source.data.copy()
        zone_object.name = f"BODY_{zone_name}"
        zone_object.data.name = f"MESH_BODY_{zone_name}"
        body_collection.objects.link(zone_object)

        keep = face_zones[zone_name]
        mesh = zone_object.data
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.faces.ensure_lookup_table()
        remove = [face for face in bm.faces if face.index not in keep]
        bmesh.ops.delete(bm, geom=remove, context="FACES")
        loose = [vertex for vertex in bm.verts if not vertex.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()

        for modifier in zone_object.modifiers:
            if modifier.type == "ARMATURE":
                modifier.object = bpy.data.objects["CHR_Armature"]
        created.append(zone_object)

    return created


def validate(
    armature: bpy.types.Object,
    body_zones: list[bpy.types.Object],
    garments: list[bpy.types.Object],
) -> dict:
    errors: list[str] = []
    warnings: list[str] = []

    expected_bones = {bone.name for bone in armature.data.bones}
    for obj in body_zones + garments:
        armature_modifiers = [
            modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"
        ]
        if len(armature_modifiers) != 1:
            errors.append(
                f"{obj.name}: expected one Armature modifier, "
                f"found {len(armature_modifiers)}"
            )
            continue
        if armature_modifiers[0].object != armature:
            errors.append(f"{obj.name}: Armature modifier targets the wrong rig")
        unknown_groups = {
            group.name for group in obj.vertex_groups
        } - expected_bones
        if unknown_groups:
            warnings.append(
                f"{obj.name}: non-bone vertex groups: "
                + ", ".join(sorted(unknown_groups))
            )

        for material in obj.data.materials:
            if material is None or material.node_tree is None:
                continue
            for node in material.node_tree.nodes:
                if node.type != "TEX_IMAGE" or node.image is None:
                    continue
                image = node.image
                image_path = bpy.path.abspath(image.filepath)
                if not image.packed_file and (
                    not image_path or not os.path.isfile(image_path)
                ):
                    warning = (
                        f"{material.name}: missing source texture {image.name}"
                    )
                    if warning not in warnings:
                        warnings.append(warning)

    if tuple(round(value, 6) for value in armature.scale) != (0.01, 0.01, 0.01):
        errors.append("CHR_Armature scale changed from the required 0.01")

    return {
        "errors": errors,
        "warnings": warnings,
        "body_zone_polygons": {
            obj.name: len(obj.data.polygons) for obj in body_zones
        },
        "bones": len(armature.data.bones),
        "garments": [obj.name for obj in garments],
        "missing_options": [
            "TOP_02_<Description>",
            "BOTTOM_02_<Description>",
            "SHOES_02_<Description>",
        ],
    }


def export_glb(
    output_path: Path,
    armature: bpy.types.Object,
    export_meshes: list[bpy.types.Object],
) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    armature.hide_set(False)
    armature.hide_render = False
    armature.select_set(True)
    for obj in export_meshes:
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature

    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_skins=True,
        export_morph=True,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
    )


def main() -> None:
    output_dir = (
        Path(sys.argv[sys.argv.index("--") + 1])
        if "--" in sys.argv
        else Path(bpy.path.abspath("//"))
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    rename_existing_objects()
    armature = require_object("CHR_Armature", "ARMATURE")
    source_body = require_object("BODY_Source", "MESH")
    garments = [
        require_object("TOP_01_Hoodie", "MESH"),
        require_object("BOTTOM_01_Jeans", "MESH"),
        require_object("SHOES_01_Sneakers", "MESH"),
    ]

    scene_root = bpy.context.scene.collection
    root = get_or_create_collection("FB_CHARACTER", scene_root)
    collections = {
        "rig": get_or_create_collection("00_RIG", root),
        "body": get_or_create_collection("01_BODY", root),
        "tops": get_or_create_collection("02_TOPS", root),
        "bottoms": get_or_create_collection("03_BOTTOMS", root),
        "shoes": get_or_create_collection("04_SHOES", root),
        "reference": get_or_create_collection("90_REFERENCE", root),
    }

    move_to_collection(armature, collections["rig"])
    move_to_collection(source_body, collections["reference"])
    move_to_collection(garments[0], collections["tops"])
    move_to_collection(garments[1], collections["bottoms"])
    move_to_collection(garments[2], collections["shoes"])

    body_zones = make_body_zones(source_body, collections["body"])
    source_body.hide_set(True)
    source_body.hide_render = True

    report = validate(armature, body_zones, garments)
    if report["errors"]:
        raise RuntimeError(json.dumps(report, indent=2))

    master_path = output_dir / MASTER_NAME
    bpy.ops.wm.save_as_mainfile(filepath=str(master_path), copy=False)
    export_glb(output_dir / GLB_NAME, armature, body_zones + garments)

    report_path = output_dir / "FB_Character_Master_v001_validation.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("CODEX_MODULAR_CHARACTER_REPORT")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
