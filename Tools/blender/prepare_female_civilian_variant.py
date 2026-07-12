"""Rig the imported female body and export the modular character GLB."""

from __future__ import annotations

import json
import math
import shutil
import sys
from pathlib import Path

import bpy


FEMALE_PARTS = {
    "Head": "BODY_Female_Head",
    "Torso": "BODY_Female_Torso",
    "LeftArm": "BODY_Female_LeftArm",
    "RightArm": "BODY_Female_RightArm",
    "Legs": "BODY_Female_Legs",
}
TEST_ACTIONS = ["Idle", "Walk", "Sprint", "LeftStrafe", "RightStrafe", "PistolAim"]


def require(name: str, kind: str) -> bpy.types.Object:
    obj = bpy.data.objects.get(name)
    if obj is None or obj.type != kind:
        raise RuntimeError(f"Missing required {kind}: {name}")
    return obj


def transfer_weights(
    target: bpy.types.Object,
    source: bpy.types.Object,
) -> None:
    for group in list(target.vertex_groups):
        target.vertex_groups.remove(group)
    for source_group in source.vertex_groups:
        target.vertex_groups.new(name=source_group.name)
    modifier = target.modifiers.new("FB_TransferWeights", "DATA_TRANSFER")
    modifier.object = source
    modifier.use_vert_data = True
    modifier.data_types_verts = {"VGROUP_WEIGHTS"}
    modifier.vert_mapping = "POLYINTERP_NEAREST"
    modifier.mix_mode = "REPLACE"
    modifier.mix_factor = 1.0
    bpy.context.view_layer.objects.active = target
    target.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    target.select_set(False)


def normalize_and_limit(obj: bpy.types.Object, limit: int = 4) -> None:
    for vertex in obj.data.vertices:
        memberships = sorted(
            (
                (membership.group, membership.weight)
                for membership in vertex.groups
                if membership.weight > 0.00001
            ),
            key=lambda item: item[1],
            reverse=True,
        )
        kept = memberships[:limit]
        kept_indices = {group_index for group_index, _weight in kept}
        for group_index, _weight in memberships:
            if group_index not in kept_indices:
                obj.vertex_groups[group_index].remove([vertex.index])
        total = sum(weight for _group_index, weight in kept)
        if total > 0.0:
            for group_index, weight in kept:
                obj.vertex_groups[group_index].add(
                    [vertex.index], weight / total, "REPLACE"
                )
    obj.data.update()


def ensure_armature_modifier(
    obj: bpy.types.Object,
    armature: bpy.types.Object,
) -> None:
    for modifier in list(obj.modifiers):
        if modifier.type == "ARMATURE":
            obj.modifiers.remove(modifier)
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = armature
    modifier.use_vertex_groups = True
    world_matrix = obj.matrix_world.copy()
    obj.parent = armature
    obj.matrix_world = world_matrix


def validate_mesh(obj: bpy.types.Object, deform_bones: set[str]) -> list[str]:
    errors: list[str] = []
    if not obj.vertex_groups:
        errors.append(f"{obj.name}: no vertex groups")
    group_names = {group.name for group in obj.vertex_groups}
    unknown = sorted(group_names - deform_bones)
    if unknown:
        errors.append(f"{obj.name}: unknown groups {unknown}")
    unweighted = 0
    for vertex in obj.data.vertices:
        weight = sum(item.weight for item in vertex.groups)
        if weight < 0.999 or weight > 1.001:
            unweighted += 1
    if unweighted:
        errors.append(f"{obj.name}: {unweighted} vertices are not normalized")
    armature_modifiers = [m for m in obj.modifiers if m.type == "ARMATURE"]
    if len(armature_modifiers) != 1:
        errors.append(f"{obj.name}: expected one armature modifier")
    return errors


def validate_deformation(
    armature: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> list[str]:
    errors: list[str] = []
    original_action = (
        armature.animation_data.action
        if armature.animation_data and armature.animation_data.action
        else None
    )
    if armature.animation_data is None:
        armature.animation_data_create()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for action_name in TEST_ACTIONS:
        action = bpy.data.actions.get(action_name)
        if action is None:
            errors.append(f"Missing action: {action_name}")
            continue
        armature.animation_data.action = action
        start, end = action.frame_range
        for frame in {int(start), int((start + end) * 0.5), int(end)}:
            bpy.context.scene.frame_set(frame)
            depsgraph.update()
            for obj in meshes:
                evaluated = obj.evaluated_get(depsgraph)
                mesh = evaluated.to_mesh()
                try:
                    coordinates = [
                        evaluated.matrix_world @ vertex.co
                        for vertex in mesh.vertices
                    ]
                    if not coordinates:
                        errors.append(f"{obj.name}: empty in {action_name}")
                        continue
                    if not all(
                        math.isfinite(component)
                        for coordinate in coordinates
                        for component in coordinate
                    ):
                        errors.append(f"{obj.name}: invalid deformation")
                    extents = [
                        max(value[axis] for value in coordinates)
                        - min(value[axis] for value in coordinates)
                        for axis in range(3)
                    ]
                    if max(extents) > 5.0:
                        errors.append(
                            f"{obj.name}: exploded in {action_name} frame {frame}"
                        )
                finally:
                    evaluated.to_mesh_clear()
    armature.animation_data.action = original_action
    bpy.context.scene.frame_set(1)
    return sorted(set(errors))


def export_glb(destination: Path, armature: bpy.types.Object) -> list[str]:
    exported: list[str] = []
    bpy.ops.object.select_all(action="DESELECT")
    armature.hide_set(False)
    armature.select_set(True)
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if not obj.name.startswith(("BODY_", "TOP_", "BOTTOM_", "SHOES_", "HAIR_")):
            continue
        if obj.name == "BODY_Source":
            continue
        obj.hide_set(False)
        obj.hide_render = False
        obj.select_set(True)
        exported.append(obj.name)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(destination),
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
    return exported


def main() -> None:
    if "--" not in sys.argv:
        raise RuntimeError("Expected export directory after --")
    export_dir = Path(sys.argv[sys.argv.index("--") + 1])
    export_dir.mkdir(parents=True, exist_ok=True)
    source_path = Path(bpy.data.filepath)
    backup_path = source_path.with_name(
        "FB_Character_Master_v001_before_female_variant.blend"
    )
    if not backup_path.exists():
        shutil.copy2(source_path, backup_path)

    armature = require("CHR_Armature", "ARMATURE")
    weight_source = require("BODY_Source", "MESH")
    female_collection = bpy.data.collections.get("01_BODY_FEMALE")
    if female_collection is None:
        female_collection = bpy.data.collections.new("01_BODY_FEMALE")
        bpy.context.scene.collection.children.link(female_collection)

    female_meshes: list[bpy.types.Object] = []
    female_material = bpy.data.materials.get("Material")
    if female_material is not None:
        female_material.name = "MAT_BODY_Female"

    for imported_name, final_name in FEMALE_PARTS.items():
        obj = bpy.data.objects.get(final_name) or require(imported_name, "MESH")
        obj.name = final_name
        obj.data.name = f"MESH_{final_name}"
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        female_collection.objects.link(obj)
        transfer_weights(obj, weight_source)
        normalize_and_limit(obj)
        ensure_armature_modifier(obj, armature)
        obj.hide_set(False)
        obj.hide_render = False
        female_meshes.append(obj)

    deform_bones = {bone.name for bone in armature.data.bones if bone.use_deform}
    errors: list[str] = []
    for mesh in female_meshes:
        errors.extend(validate_mesh(mesh, deform_bones))
    errors.extend(validate_deformation(armature, female_meshes))
    if errors:
        raise RuntimeError(json.dumps(sorted(set(errors)), indent=2))

    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    export_path = export_dir / "FB_Player_Modular_v003.glb"
    exported = export_glb(export_path, armature)
    report = {
        "master": str(source_path),
        "backup": str(backup_path),
        "export": str(export_path),
        "female_meshes": [obj.name for obj in female_meshes],
        "exported_meshes": exported,
        "actions_checked": TEST_ACTIONS,
        "errors": errors,
    }
    report_path = export_dir / "FB_Player_Modular_v003_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("FB_FEMALE_VARIANT_REPORT")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
