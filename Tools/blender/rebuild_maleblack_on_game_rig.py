import os
import bpy
import bmesh
from mathutils import Vector, kdtree


PROJECT_ROOT = "C:/Users/smo0o/OneDrive/Documents/family-biz-prototype"
NEW_MODEL_BLEND = (
    "C:/Users/smo0o/OneDrive/Desktop/shh/Project material/Family Business/"
    "Assets/Chracters/3d models/NewModels/MaleBlack.blend"
)
OUTPUT_BLEND = PROJECT_ROOT + "/Assets/BaseChracters/Player/Source/MaleBlack_GameRig_Master_v001.blend"
OUTPUT_GLB = PROJECT_ROOT + "/Assets/BaseChracters/Player/Working/FB_Character_Working.glb"
FALLBACK_GLB = PROJECT_ROOT + "/Assets/BaseChracters/Player/Working/FB_Character_Working_FIXED.glb"

RIG_NAME = "CHR_Armature"
NEW_OBJECTS = [
    "Head",
    "Torso",
    "LeftArm",
    "RightArm",
    "LeftLeg",
    "RightLeg",
    "Hoodie",
    "Tshirt",
    "Jeans",
    "Sneakers",
    "Hair",
    "Hair2",
]
BODY_EXPORT_NAMES = {
    "BODY_Head",
    "BODY_Hands",
    "BODY_Torso",
    "BODY_Legs",
    "BODY_Feet",
}


def log(message):
    print("FB_MALEBLACK_GAMERIG:", message)


def ensure_collection(name):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection_name):
    collection = ensure_collection(collection_name)
    for old_collection in tuple(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)


def make_active(obj):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def world_bounds(objects):
    points = []
    for obj in objects:
        for corner in obj.bound_box:
            points.append(obj.matrix_world @ Vector(corner))
    mins = Vector([min(point[i] for point in points) for i in range(3)])
    maxs = Vector([max(point[i] for point in points) for i in range(3)])
    return mins, maxs


def import_new_objects():
    imported = {}
    before = set(bpy.data.objects)
    object_dir = NEW_MODEL_BLEND + "/Object"
    for object_name in NEW_OBJECTS:
        bpy.ops.wm.append(
            filepath=object_dir + "/" + object_name,
            directory=object_dir,
            filename=object_name,
        )
    after = [obj for obj in bpy.data.objects if obj not in before]
    for obj in after:
        base_name = obj.name.split(".")[0]
        if base_name in NEW_OBJECTS:
            imported[base_name] = obj
            obj.name = "NEW_" + base_name
            if hasattr(obj.data, "name"):
                obj.data.name = "MESH_NEW_" + base_name
            move_to_collection(obj, "90_REFERENCE")
    return imported


def align_new_to_old(imported):
    old_body = [
        bpy.data.objects[name]
        for name in BODY_EXPORT_NAMES
        if name in bpy.data.objects
    ]
    new_body = [
        imported[name]
        for name in ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
        if name in imported
    ]
    old_min, old_max = world_bounds(old_body)
    new_min, new_max = world_bounds(new_body)
    offset = Vector(
        [
            ((old_min.x + old_max.x) * 0.5) - ((new_min.x + new_max.x) * 0.5),
            ((old_min.y + old_max.y) * 0.5) - ((new_min.y + new_max.y) * 0.5),
            old_min.z - new_min.z,
        ]
    )
    for obj in imported.values():
        obj.location += offset
    log("Aligned imported model by offset {}".format(tuple(round(v, 4) for v in offset)))


def duplicate_object(obj, new_name):
    make_active(obj)
    bpy.ops.object.duplicate()
    duplicate = bpy.context.object
    duplicate.name = new_name
    duplicate.data = duplicate.data.copy()
    duplicate.data.name = "MESH_" + new_name
    return duplicate


def filter_mesh_to_vertex_groups(obj, keep_match):
    keep_groups = {
        group.index for group in obj.vertex_groups if keep_match(group.name)
    }
    keep_vertices = set()
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            if group.group in keep_groups and group.weight > 0.0001:
                keep_vertices.add(vertex.index)
                break
    if not keep_vertices:
        log("Keeping full mesh for " + obj.name + " because no split weights matched")
        return
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    delete_verts = [
        vertex for vertex in bm.verts if vertex.index not in keep_vertices
    ]
    bmesh.ops.delete(bm, geom=delete_verts, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def join_objects(objects, new_name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = new_name
    joined.data.name = "MESH_" + new_name
    return joined


def remove_armature_modifiers(obj):
    for modifier in tuple(obj.modifiers):
        if modifier.type in {"ARMATURE", "DATA_TRANSFER"}:
            obj.modifiers.remove(modifier)


def clear_to_bone_groups(obj, rig):
    bone_names = {bone.name for bone in rig.data.bones}
    for group in tuple(obj.vertex_groups):
        if group.name not in bone_names:
            obj.vertex_groups.remove(group)


def transfer_weights_nearest(target, source, rig):
    remove_armature_modifiers(target)
    target.vertex_groups.clear()
    source_groups = list(source.vertex_groups)
    group_lookup = {}
    for source_group in source_groups:
        group_lookup[source_group.index] = target.vertex_groups.new(
            name=source_group.name
        )

    kd = kdtree.KDTree(len(source.data.vertices))
    source_world = source.matrix_world
    for vertex in source.data.vertices:
        kd.insert(source_world @ vertex.co, vertex.index)
    kd.balance()

    for target_vertex in target.data.vertices:
        target_world = target.matrix_world @ target_vertex.co
        _, source_index, _ = kd.find(target_world)
        source_vertex = source.data.vertices[source_index]
        for source_weight in source_vertex.groups:
            if source_weight.weight <= 0.0001:
                continue
            group = group_lookup.get(source_weight.group)
            if group is not None:
                group.add([target_vertex.index], source_weight.weight, "REPLACE")

    clear_to_bone_groups(target, rig)
    modifier = target.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    modifier.use_deform_preserve_volume = True
    make_active(target)
    if target.vertex_groups:
        bpy.ops.object.vertex_group_clean(
            group_select_mode="ALL",
            limit=0.0001,
            keep_single=True,
        )
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def rename_old_export_objects():
    for obj in list(bpy.data.objects):
        if obj.name in BODY_EXPORT_NAMES or obj.name.startswith(("TOP_", "BOTTOM_", "SHOES_", "HAIR_")):
            obj.name = "REF_" + obj.name
            if hasattr(obj.data, "name"):
                obj.data.name = "REF_" + obj.data.name
            move_to_collection(obj, "90_REFERENCE")
            obj.hide_viewport = True
            obj.hide_render = True


def build_body(imported, rig):
    old_sources = {
        "BODY_Head": bpy.data.objects["REF_BODY_Head"],
        "BODY_Torso": bpy.data.objects["REF_BODY_Torso"],
        "BODY_Hands": bpy.data.objects["REF_BODY_Hands"],
        "BODY_Legs": bpy.data.objects["REF_BODY_Legs"],
        "BODY_Feet": bpy.data.objects["REF_BODY_Feet"],
    }

    head = imported["Head"]
    head.name = "BODY_Head"
    head.data.name = "MESH_BODY_Head"

    torso = imported["Torso"]
    torso.name = "BODY_Torso"
    torso.data.name = "MESH_BODY_Torso"

    hands_left = duplicate_object(imported["LeftArm"], "BODY_Hands_Left_TEMP")
    hands_right = duplicate_object(imported["RightArm"], "BODY_Hands_Right_TEMP")
    filter_mesh_to_vertex_groups(hands_left, lambda name: "Hand" in name)
    filter_mesh_to_vertex_groups(hands_right, lambda name: "Hand" in name)
    hands = join_objects([hands_left, hands_right], "BODY_Hands")

    legs = join_objects([imported["LeftLeg"], imported["RightLeg"]], "BODY_Legs")

    feet_left = duplicate_object(legs, "BODY_Feet_Left_TEMP")
    feet_right = duplicate_object(legs, "BODY_Feet_Right_TEMP")
    filter_mesh_to_vertex_groups(
        feet_left,
        lambda name: "Foot" in name or "Toe" in name,
    )
    filter_mesh_to_vertex_groups(
        feet_right,
        lambda name: "Foot" in name or "Toe" in name,
    )
    feet = join_objects([feet_left, feet_right], "BODY_Feet")

    for obj in [head, torso, hands, legs, feet]:
        transfer_weights_nearest(obj, old_sources[obj.name], rig)
        obj.data.materials.clear()
        skin_mat = bpy.data.materials.get("MAT_BODY_Skin")
        if skin_mat is not None:
            obj.data.materials.append(skin_mat)
        move_to_collection(obj, "01_BODY")
        obj.hide_viewport = False
        obj.hide_render = False
    return {
        "head": head,
        "torso": torso,
        "hands": hands,
        "legs": legs,
        "feet": feet,
    }


def setup_mesh(obj, name, source, rig, collection_name):
    obj.name = name
    obj.data.name = "MESH_" + name
    transfer_weights_nearest(obj, source, rig)
    move_to_collection(obj, collection_name)
    obj.hide_viewport = False
    obj.hide_render = False
    return obj


def build_clothes_and_hair(imported, body, rig):
    setup_mesh(imported["Hoodie"], "TOP_01_Hoodie", body["torso"], rig, "02_TOPS")
    setup_mesh(imported["Tshirt"], "TOP_02_TShirt", body["torso"], rig, "02_TOPS")
    setup_mesh(imported["Jeans"], "BOTTOM_01_Jeans", body["legs"], rig, "03_BOTTOMS")
    setup_mesh(imported["Sneakers"], "SHOES_01_Sneakers", body["feet"], rig, "04_SHOES")
    setup_mesh(imported["Hair"], "HAIR_01_Short", body["head"], rig, "05_HAIR")
    setup_mesh(imported["Hair2"], "HAIR_02_Alt", body["head"], rig, "05_HAIR")


def is_export_object(obj):
    if obj.name == RIG_NAME:
        return True
    if obj.type != "MESH":
        return False
    return (
        obj.name in BODY_EXPORT_NAMES
        or obj.name.startswith("TOP_")
        or obj.name.startswith("BOTTOM_")
        or obj.name.startswith("SHOES_")
        or obj.name.startswith("HAIR_")
    )


def export_glb():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if is_export_object(obj):
            obj.select_set(True)
    os.makedirs(os.path.dirname(OUTPUT_GLB), exist_ok=True)
    try:
        bpy.ops.export_scene.gltf(
            filepath=OUTPUT_GLB,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_animations=False,
            export_lights=False,
            export_cameras=False,
            export_skins=True,
            export_morph=True,
        )
        log("Exported " + OUTPUT_GLB)
    except Exception as error:
        log("Could not overwrite working GLB, exporting fallback: " + str(error))
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
        )
        log("Exported " + FALLBACK_GLB)


def main():
    rig = bpy.data.objects.get(RIG_NAME)
    if rig is None:
        raise RuntimeError("Open this script on the old game-rig master blend")
    rig.rotation_euler = (0.0, 0.0, 0.0)
    rig.scale = (0.01, 0.01, 0.01)
    for collection_name in ["01_BODY", "02_TOPS", "03_BOTTOMS", "04_SHOES", "05_HAIR", "90_REFERENCE"]:
        ensure_collection(collection_name)
    imported = import_new_objects()
    align_new_to_old(imported)
    rename_old_export_objects()
    body = build_body(imported, rig)
    build_clothes_and_hair(imported, body, rig)
    os.makedirs(os.path.dirname(OUTPUT_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_BLEND)
    log("Saved " + OUTPUT_BLEND)
    export_glb()


if __name__ == "__main__":
    main()
