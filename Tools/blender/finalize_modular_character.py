"""Finalize user-added modular outfit options and export the player GLB."""

from __future__ import annotations

import json
import math
import shutil
import sys
from pathlib import Path

import bpy


OPTIONS = {
    "TOP_01_Hoodie": ("MESH_TOP_01_Hoodie", "MAT_TOP_01_Hoodie"),
    "TOP_02_TShirt": ("MESH_TOP_02_TShirt", "MAT_TOP_02_TShirt"),
    "BOTTOM_01_Jeans": ("MESH_BOTTOM_01_Jeans", "MAT_BOTTOM_01_Jeans"),
    "BOTTOM_02_Sweatpants": (
        "MESH_BOTTOM_02_Sweatpants",
        "MAT_BOTTOM_02_Sweatpants",
    ),
    "SHOES_01_Sneakers": (
        "MESH_SHOES_01_Sneakers",
        "MAT_SHOES_01_Sneakers",
    ),
    "SHOES_02_Boots": ("MESH_SHOES_02_Boots", "MAT_SHOES_02_Boots"),
}

BODY_ZONES = [
    "BODY_Head",
    "BODY_Hands",
    "BODY_Torso",
    "BODY_Legs",
    "BODY_Feet",
]

TEST_ACTIONS = ["Idle", "Walk", "Sprint", "LeftStrafe", "RightStrafe", "PistolAim"]


def require(name: str, kind: str) -> bpy.types.Object:
    obj = bpy.data.objects.get(name)
    if obj is None or obj.type != kind:
        raise RuntimeError(f"Missing required {kind}: {name}")
    return obj


def normalize_and_limit(obj: bpy.types.Object, limit: int = 4) -> int:
    changed = 0
    for vertex in obj.data.vertices:
        memberships = [
            (membership.group, membership.weight)
            for membership in vertex.groups
            if membership.weight > 0.0
        ]
        memberships.sort(key=lambda item: item[1], reverse=True)
        kept = memberships[:limit]
        total = sum(weight for _, weight in kept)
        if len(memberships) > limit:
            changed += 1
        kept_indices = {group_index for group_index, _ in kept}
        for group_index, _ in memberships:
            if group_index not in kept_indices:
                obj.vertex_groups[group_index].remove([vertex.index])
        if total > 0.0:
            for group_index, weight in kept:
                obj.vertex_groups[group_index].add(
                    [vertex.index], weight / total, "REPLACE"
                )
    obj.data.update()
    return changed


def ensure_parent(obj: bpy.types.Object, armature: bpy.types.Object) -> None:
    if obj.parent == armature:
        return
    world_matrix = obj.matrix_world.copy()
    obj.parent = armature
    obj.matrix_world = world_matrix


def rename_data_and_materials(obj: bpy.types.Object, mesh: str, material: str) -> None:
    obj.data.name = mesh
    for index, slot_material in enumerate(obj.data.materials):
        if slot_material is None:
            continue
        slot_material.name = (
            material if index == 0 else f"{material}_Secondary_{index:02d}"
        )


def validate_deformation(
    armature: bpy.types.Object, objects: list[bpy.types.Object]
) -> list[str]:
    errors: list[str] = []
    original_action = (
        armature.animation_data.action
        if armature.animation_data and armature.animation_data.action
        else None
    )
    depsgraph = bpy.context.evaluated_depsgraph_get()

    for action_name in TEST_ACTIONS:
        action = bpy.data.actions.get(action_name)
        if action is None:
            errors.append(f"Missing test action: {action_name}")
            continue
        if armature.animation_data is None:
            armature.animation_data_create()
        armature.animation_data.action = action
        start, end = action.frame_range
        frames = {int(start), int((start + end) * 0.5), int(end)}
        for frame in sorted(frames):
            bpy.context.scene.frame_set(frame)
            depsgraph.update()
            for obj in objects:
                evaluated = obj.evaluated_get(depsgraph)
                mesh = evaluated.to_mesh()
                try:
                    coordinates = [
                        evaluated.matrix_world @ vertex.co for vertex in mesh.vertices
                    ]
                    if not coordinates:
                        errors.append(f"{obj.name}: empty during {action_name}")
                        continue
                    if not all(
                        math.isfinite(component)
                        for coordinate in coordinates
                        for component in coordinate
                    ):
                        errors.append(
                            f"{obj.name}: invalid deformation in {action_name}"
                        )
                        continue
                    extents = [
                        max(coordinate[axis] for coordinate in coordinates)
                        - min(coordinate[axis] for coordinate in coordinates)
                        for axis in range(3)
                    ]
                    if max(extents) > 5.0:
                        errors.append(
                            f"{obj.name}: exploded deformation in "
                            f"{action_name} frame {frame}"
                        )
                finally:
                    evaluated.to_mesh_clear()

    armature.animation_data.action = original_action
    bpy.context.scene.frame_set(1)
    return sorted(set(errors))


def export_glb(
    destination: Path,
    armature: bpy.types.Object,
    meshes: list[bpy.types.Object],
) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    armature.hide_set(False)
    armature.select_set(True)
    for obj in meshes:
        obj.hide_set(False)
        obj.select_set(True)
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


def main() -> None:
    source = Path(bpy.data.filepath)
    output_dir = (
        Path(sys.argv[sys.argv.index("--") + 1])
        if "--" in sys.argv
        else source.parent
    )
    backup = output_dir / "FB_Character_Master_v001_before_finalize.blend"
    if not backup.exists():
        shutil.copy2(source, backup)

    armature = require("CHR_Armature", "ARMATURE")
    options: list[bpy.types.Object] = []
    changed_weights: dict[str, int] = {}

    for name, (mesh_name, material_name) in OPTIONS.items():
        obj = require(name, "MESH")
        ensure_parent(obj, armature)
        rename_data_and_materials(obj, mesh_name, material_name)
        armature_modifiers = [
            modifier for modifier in obj.modifiers if modifier.type == "ARMATURE"
        ]
        if len(armature_modifiers) != 1:
            raise RuntimeError(
                f"{name}: expected one Armature modifier, "
                f"found {len(armature_modifiers)}"
            )
        armature_modifiers[0].object = armature
        if name.endswith(("TShirt", "Sweatpants", "Boots")):
            changed_weights[name] = normalize_and_limit(obj)
        options.append(obj)

    body = [require(name, "MESH") for name in BODY_ZONES]
    deformation_errors = validate_deformation(armature, options)
    if deformation_errors:
        raise RuntimeError(json.dumps(deformation_errors, indent=2))

    # Save a clean default outfit state while retaining all options in the file.
    for obj in options:
        is_default = "_01_" in obj.name
        obj.hide_set(not is_default)
        obj.hide_render = not is_default
    for obj in body:
        obj.hide_set(False)
        obj.hide_render = False

    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    export_glb(
        output_dir / "FB_Player_Modular_v002.glb",
        armature,
        body + options,
    )

    report = {
        "backup": str(backup),
        "master": str(source),
        "export": str(output_dir / "FB_Player_Modular_v002.glb"),
        "weight_vertices_reduced_to_four": changed_weights,
        "deformation_actions_checked": TEST_ACTIONS,
        "deformation_errors": deformation_errors,
        "objects": [obj.name for obj in body + options],
    }
    (output_dir / "FB_Character_Master_v001_finalize_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    print("CODEX_FINALIZE_REPORT")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
