import os
import re
import bpy
import bmesh
from mathutils import kdtree


PROJECT_ROOT = "C:/Users/smo0o/OneDrive/Documents/family-biz-prototype"
WORKING_GLB = PROJECT_ROOT + "/Assets/BaseChracters/Player/Working/FB_Character_Working.glb"
FALLBACK_GLB = PROJECT_ROOT + "/Assets/BaseChracters/Player/Working/FB_Character_Working_FIXED.glb"
CLEAN_BLEND = PROJECT_ROOT + "/Assets/BaseChracters/Player/Source/MaleBlack_Master_v001.blend"

RIG_NAME = "CHR_Armature"

COLLECTIONS = [
    "FB_CHARACTER",
    "00_RIG",
    "01_BODY",
    "02_TOPS",
    "03_BOTTOMS",
    "04_SHOES",
    "05_HAIR",
    "90_REFERENCE",
]

BODY_EXPORT_NAMES = {
    "BODY_Head",
    "BODY_Hands",
    "BODY_Torso",
    "BODY_Legs",
    "BODY_Feet",
}

RENAME_MAP = {
    "Hoodie": "TOP_01_Hoodie",
    "Tshirt": "TOP_02_TShirt",
    "Jeans": "BOTTOM_01_Jeans",
    "Sneakers": "SHOES_01_Sneakers",
    "Hair": "HAIR_01_Short",
    "Hair2": "HAIR_02_Alt",
}

COLLECTION_FOR_PREFIX = {
    "BODY_": "01_BODY",
    "TOP_": "02_TOPS",
    "BOTTOM_": "03_BOTTOMS",
    "SHOES_": "04_SHOES",
    "HAIR_": "05_HAIR",
}


def log(message):
    print("FB_MALEBLACK_SETUP:", message)


def ensure_collection(name):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection_name):
    collection = ensure_collection(collection_name)
    for old in tuple(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def object_by_name(*names):
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            return obj
    return None


def make_active(obj):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def duplicate_object(obj, new_name):
    make_active(obj)
    bpy.ops.object.duplicate()
    duplicate = bpy.context.object
    duplicate.name = new_name
    duplicate.data = duplicate.data.copy()
    duplicate.data.name = "MESH_" + new_name
    return duplicate


def filter_mesh_to_vertex_groups(obj, keep_match):
    group_indices = {
        group.index
        for group in obj.vertex_groups
        if keep_match(group.name)
    }
    if not group_indices:
        log("No matching vertex groups found for " + obj.name)
        return
    keep_vertices = set()
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            if group.group in group_indices and group.weight > 0.0001:
                keep_vertices.add(vertex.index)
                break

    if not keep_vertices:
        log(
            "No weighted vertices matched for "
            + obj.name
            + "; keeping the full mesh instead"
        )
        return

    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    delete_verts = [
        vertex for vertex in bm.verts if vertex.index not in keep_vertices
    ]
    bmesh.ops.delete(bm, geom=delete_verts, context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def join_objects(objects, new_name):
    objects = [obj for obj in objects if obj is not None]
    if not objects:
        raise RuntimeError("No objects to join for " + new_name)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = new_name
    joined.data.name = "MESH_" + new_name
    return joined


def remove_extra_armature_modifiers(obj, rig):
    for modifier in tuple(obj.modifiers):
        if modifier.type == "ARMATURE":
            obj.modifiers.remove(modifier)
    modifier = obj.modifiers.new("FB_Armature", "ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = True


def remove_non_bone_vertex_groups(obj, rig):
    bone_names = {bone.name for bone in rig.data.bones}
    for group in tuple(obj.vertex_groups):
        if group.name not in bone_names:
            obj.vertex_groups.remove(group)


def transfer_weights(obj, source, rig):
    for modifier in tuple(obj.modifiers):
        if modifier.type in {"ARMATURE", "DATA_TRANSFER"}:
            obj.modifiers.remove(modifier)
    obj.vertex_groups.clear()

    source_groups = list(source.vertex_groups)
    if not source_groups:
        raise RuntimeError(source.name + " has no source vertex groups")
    target_groups = {}
    for source_group in source_groups:
        target_groups[source_group.index] = obj.vertex_groups.new(
            name=source_group.name
        )

    kd = kdtree.KDTree(len(source.data.vertices))
    source_world = source.matrix_world
    for vertex in source.data.vertices:
        kd.insert(source_world @ vertex.co, vertex.index)
    kd.balance()

    for target_vertex in obj.data.vertices:
        target_world = obj.matrix_world @ target_vertex.co
        _, source_vertex_index, _ = kd.find(target_world)
        source_vertex = source.data.vertices[source_vertex_index]
        for source_weight in source_vertex.groups:
            if source_weight.weight <= 0.0001:
                continue
            target_group = target_groups.get(source_weight.group)
            if target_group is None:
                continue
            target_group.add(
                [target_vertex.index],
                source_weight.weight,
                "REPLACE",
            )

    armature_modifier = obj.modifiers.new("FB_Armature", "ARMATURE")
    armature_modifier.object = rig
    armature_modifier.use_deform_preserve_volume = True

    make_active(obj)

    remove_non_bone_vertex_groups(obj, rig)
    if obj.vertex_groups:
        bpy.ops.object.vertex_group_clean(
            group_select_mode="ALL",
            limit=0.0001,
            keep_single=True,
        )
        bpy.ops.object.vertex_group_limit_total(
            group_select_mode="ALL",
            limit=4,
        )
        bpy.ops.object.vertex_group_normalize_all(
            group_select_mode="ALL",
            lock_active=False,
        )


def clean_description_from_name(name):
    parts = name.split("_")
    if len(parts) >= 3:
        return "_".join(parts[2:])
    return name


def ensure_material(obj, fallback_color=(0.8, 0.8, 0.8, 1.0)):
    if not hasattr(obj.data, "materials"):
        return
    part = obj.name.split("_", 1)[0]
    description = clean_description_from_name(obj.name)
    material_name = "MAT_" + obj.name
    if obj.data.materials and obj.data.materials[0] is not None:
        material = obj.data.materials[0]
        material.name = material_name
    else:
        material = bpy.data.materials.new(material_name)
        obj.data.materials.append(material)
    material.use_nodes = True
    obj.data.materials[0] = material
    obj.data.name = "MESH_" + obj.name


def rename_existing_objects():
    for old_name, new_name in RENAME_MAP.items():
        obj = bpy.data.objects.get(old_name)
        if obj is None:
            continue
        obj.name = new_name
        if hasattr(obj.data, "name"):
            obj.data.name = "MESH_" + new_name


def setup_collections():
    for name in COLLECTIONS:
        ensure_collection(name)


def setup_rig():
    rig = object_by_name("CHR_Armature", "Armature")
    if rig is None or rig.type != "ARMATURE":
        raise RuntimeError("Could not find the armature")
    rig.name = RIG_NAME
    rig.data.name = "RIG_" + RIG_NAME
    move_to_collection(rig, "00_RIG")
    return rig


def build_body_zones(rig):
    head = object_by_name("BODY_Head", "Head")
    torso = object_by_name("BODY_Torso", "Torso")
    left_arm = object_by_name("LeftArm")
    right_arm = object_by_name("RightArm")
    left_leg = object_by_name("LeftLeg")
    right_leg = object_by_name("RightLeg")

    if head is None or torso is None:
        raise RuntimeError("Missing Head or Torso body mesh")
    if left_arm is None or right_arm is None:
        raise RuntimeError("Missing arm meshes")
    if left_leg is None or right_leg is None:
        raise RuntimeError("Missing leg meshes")

    head.name = "BODY_Head"
    head.data.name = "MESH_BODY_Head"
    torso.name = "BODY_Torso"
    torso.data.name = "MESH_BODY_Torso"

    hands_parts = [
        duplicate_object(
            left_arm,
            "BODY_Hands_Left_TEMP",
        ),
        duplicate_object(
            right_arm,
            "BODY_Hands_Right_TEMP",
        ),
    ]
    for part in hands_parts:
        filter_mesh_to_vertex_groups(
            part,
            lambda group_name: "Hand" in group_name,
        )
    hands = join_objects(hands_parts, "BODY_Hands")

    feet_parts = [
        duplicate_object(
            left_leg,
            "BODY_Feet_Left_TEMP",
        ),
        duplicate_object(
            right_leg,
            "BODY_Feet_Right_TEMP",
        ),
    ]
    for part in feet_parts:
        filter_mesh_to_vertex_groups(
            part,
            lambda group_name: (
                "Foot" in group_name or "Toe" in group_name
            ),
        )
    feet = join_objects(feet_parts, "BODY_Feet")

    legs = join_objects([left_leg, right_leg], "BODY_Legs")

    for obj in [head, torso, hands, legs, feet]:
        remove_extra_armature_modifiers(obj, rig)
        remove_non_bone_vertex_groups(obj, rig)
        ensure_material(obj)
        move_to_collection(obj, "01_BODY")
    return {
        "head": head,
        "torso": torso,
        "hands": hands,
        "legs": legs,
        "feet": feet,
    }


def setup_named_mesh(obj, rig, collection_name):
    if obj is None:
        return
    remove_extra_armature_modifiers(obj, rig)
    remove_non_bone_vertex_groups(obj, rig)
    ensure_material(obj)
    move_to_collection(obj, collection_name)


def bake_mesh_transform(obj):
    make_active(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def bake_world_geometry_to_identity(obj):
    world = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        vertex.co = world @ vertex.co
    obj.matrix_world.identity()
    obj.data.update()


def parent_to_rig_keep_transform(obj, rig):
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_world = world


def setup_clothes_and_hair(rig, body):
    rename_existing_objects()

    setup_named_mesh(object_by_name("HAIR_01_Short"), rig, "05_HAIR")
    setup_named_mesh(object_by_name("HAIR_02_Alt"), rig, "05_HAIR")

    clothes = [
        ("TOP_01_Hoodie", body["torso"], "02_TOPS"),
        ("TOP_02_TShirt", body["torso"], "02_TOPS"),
        ("BOTTOM_01_Jeans", body["legs"], "03_BOTTOMS"),
        (
            "SHOES_01_Sneakers",
            body["feet"] if len(body["feet"].data.vertices) > 0 else body["legs"],
            "04_SHOES",
        ),
    ]
    for object_name, source, collection_name in clothes:
        obj = object_by_name(object_name)
        if obj is None:
            log("Missing clothing object " + object_name)
            continue
        make_active(obj)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        transfer_weights(obj, source, rig)
        ensure_material(obj)
        move_to_collection(obj, collection_name)
        log("Weighted " + object_name + " from " + source.name)


def move_unwanted_to_reference():
    for obj in bpy.data.objects:
        if obj.name == RIG_NAME:
            continue
        if obj.type not in {"MESH", "EMPTY", "CAMERA", "LIGHT"}:
            continue
        if is_export_object(obj):
            continue
        move_to_collection(obj, "90_REFERENCE")
        obj.hide_viewport = True
        obj.hide_render = True


def normalize_export_mesh_transforms(rig):
    for obj in bpy.context.scene.objects:
        if not is_export_object(obj) or obj.type != "MESH":
            continue
        obj.parent = None
        remove_extra_armature_modifiers(obj, rig)


def is_export_object(obj):
    if obj.name == RIG_NAME:
        return True
    if obj.type != "MESH":
        return False
    return (
        obj.name.startswith("TOP_")
        or obj.name.startswith("BOTTOM_")
        or obj.name.startswith("SHOES_")
        or obj.name == "HAIR_02_Alt"
    )


def validate_export(rig):
    errors = []
    for obj in bpy.context.scene.objects:
        if not is_export_object(obj) or obj.type != "MESH":
            continue
        armature_modifiers = [
            mod for mod in obj.modifiers if mod.type == "ARMATURE"
        ]
        if len(armature_modifiers) != 1:
            errors.append(obj.name + " needs exactly one armature modifier")
        elif armature_modifiers[0].object != rig:
            errors.append(obj.name + " armature modifier target is wrong")
        if len(obj.vertex_groups) == 0:
            errors.append(obj.name + " has no vertex groups")
    if errors:
        raise RuntimeError("; ".join(errors))


def save_clean_blend():
    os.makedirs(os.path.dirname(CLEAN_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=CLEAN_BLEND)
    log("Saved clean blend: " + CLEAN_BLEND)


def export_glb():
    os.makedirs(os.path.dirname(WORKING_GLB), exist_ok=True)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if is_export_object(obj):
            obj.hide_viewport = False
            obj.hide_render = False
            obj.select_set(True)
    try:
        bpy.ops.export_scene.gltf(
            filepath=WORKING_GLB,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_animations=False,
            export_lights=False,
            export_cameras=False,
            export_skins=True,
            export_morph=True,
            export_yup=True,
        )
        log("Exported working GLB: " + WORKING_GLB)
    except Exception as error:
        log("Could not overwrite working GLB; exporting fallback. " + str(error))
        bpy.ops.export_scene.gltf(
            filepath=FALLBACK_GLB,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_animations=False,
            export_lights=False,
            export_cameras=False,
            export_skins=True,
            export_morph=True,
            export_yup=True,
        )
        log("Exported fallback GLB: " + FALLBACK_GLB)


def main():
    setup_collections()
    rig = setup_rig()
    body = build_body_zones(rig)
    setup_clothes_and_hair(rig, body)
    move_unwanted_to_reference()
    normalize_export_mesh_transforms(rig)
    validate_export(rig)
    save_clean_blend()
    export_glb()
    log("Done")


if __name__ == "__main__":
    main()
