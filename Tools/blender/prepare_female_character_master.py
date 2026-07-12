"""Normalize and organize the separate female character master for Godot."""

from __future__ import annotations

import json
import shutil
from pathlib import Path
from math import pi

import bpy
from mathutils import Matrix, Vector


BODY_RENAMES = {
    "Head": "BODY_Female_Head",
    "Torso": "BODY_Female_Torso",
    "LeftArm": "BODY_Female_LeftArm",
    "RightArm": "BODY_Female_RightArm",
    "Legs": "BODY_Female_Legs",
}


def ensure_collection(name: str, parent: bpy.types.Collection) -> bpy.types.Collection:
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
    if collection.name not in {child.name for child in parent.children}:
        parent.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current in tuple(obj.users_collection):
        current.objects.unlink(obj)
    collection.objects.link(obj)


def world_bounds(objects: list[bpy.types.Object]) -> dict:
    corners = [
        obj.matrix_world @ Vector(corner)
        for obj in objects
        for corner in obj.bound_box
    ]
    return {
        "minimum": [round(min(point[i] for point in corners), 5) for i in range(3)],
        "maximum": [round(max(point[i] for point in corners), 5) for i in range(3)],
    }


def main() -> None:
    source = Path(bpy.data.filepath)
    backup = source.with_name("FB_Female_Character_Master_before_godot_setup.blend")
    if not backup.exists():
        shutil.copy2(source, backup)

    rig = bpy.data.objects.get("CHR_Female_Armature") or bpy.data.objects.get("Armature")
    if rig is None or rig.type != "ARMATURE":
        raise RuntimeError("Female armature was not found")
    if len(rig.data.bones) < 40:
        raise RuntimeError("Female armature does not have a complete Mixamo skeleton")

    # The imported female uses a +90 degree armature rotation while the game
    # character is Z-up. Clearing that armature rotation alone preserves each
    # child's prior world transform, so rotate the body meshes by -90 degrees
    # in world space at the same time. The result matches the male pipeline:
    # Z is height, Y is depth, and the body remains visually unchanged.
    rig.rotation_euler = (0.0, 0.0, 0.0)
    rig.location = (0.0, 0.0, 0.0)
    rig.name = "CHR_Female_Armature"
    rig.data.name = "ARM_Female_Mixamo"
    rig.data.pose_position = "REST"
    if rig.animation_data:
        rig.animation_data.action = None

    root = ensure_collection("FB_FEMALE_CHARACTER", bpy.context.scene.collection)
    rig_collection = ensure_collection("00_RIG_FEMALE", root)
    body_collection = ensure_collection("01_BODY_FEMALE", root)
    ensure_collection("02_TOPS_FEMALE", root)
    ensure_collection("03_BOTTOMS_FEMALE", root)
    ensure_collection("04_SHOES_FEMALE", root)
    move_to_collection(rig, rig_collection)

    body_objects: list[bpy.types.Object] = []
    for imported_name, final_name in BODY_RENAMES.items():
        obj = bpy.data.objects.get(final_name) or bpy.data.objects.get(imported_name)
        if obj is None or obj.type != "MESH":
            raise RuntimeError(f"Missing female body mesh: {imported_name}")
        obj.name = final_name
        obj.data.name = f"MESH_{final_name}"
        obj.matrix_world = Matrix.Rotation(-pi * 0.5, 4, "X") @ obj.matrix_world
        obj.parent = rig
        for modifier in tuple(obj.modifiers):
            if modifier.type == "ARMATURE":
                modifier.object = rig
        if not any(modifier.type == "ARMATURE" for modifier in obj.modifiers):
            modifier = obj.modifiers.new("Armature", "ARMATURE")
            modifier.object = rig
        move_to_collection(obj, body_collection)
        body_objects.append(obj)

    bone_names = {bone.name for bone in rig.data.bones}
    errors = []
    for obj in body_objects:
        unknown_groups = {group.name for group in obj.vertex_groups} - bone_names
        if unknown_groups:
            errors.append(f"{obj.name}: invalid vertex groups {sorted(unknown_groups)}")
        if not obj.vertex_groups:
            errors.append(f"{obj.name}: no skin weights")
    if errors:
        raise RuntimeError("; ".join(errors))

    bounds = world_bounds(body_objects)
    if bounds["maximum"][2] - bounds["minimum"][2] < 0.7:
        raise RuntimeError("Female body is not Z-up after orientation normalization")

    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    report = {
        "master": str(source),
        "backup": str(backup),
        "rig": rig.name,
        "bone_count": len(rig.data.bones),
        "rest_pose": rig.data.pose_position,
        "rig_rotation": [round(value, 6) for value in rig.rotation_euler],
        "rig_scale": [round(value, 6) for value in rig.scale],
        "body_meshes": [obj.name for obj in body_objects],
        "world_bounds": bounds,
    }
    source.with_name("FB_Female_Character_Master_godot_setup_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    print("FB_FEMALE_MASTER_SETUP_PASS")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
