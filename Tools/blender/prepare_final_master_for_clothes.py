import os
import bpy
import bmesh


OUTPUT_PATH = (
    "C:/Users/smo0o/OneDrive/Desktop/shh/Project material/Family Business/"
    "Assets/Chracters/3d models/NewModels/FB_Player_Final_Master_v002.blend"
)

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
BODY_NAMES = {
    "BODY_Head",
    "BODY_Torso",
    "BODY_Hands",
    "BODY_Legs",
    "BODY_Feet",
}


def log(message):
    print("FB_FINAL_MASTER:", message)


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


def object_by_name(*names):
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            return obj
    return None


def duplicate_mesh_object(source, new_name):
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    duplicate.animation_data_clear()
    bpy.context.scene.collection.objects.link(duplicate)
    duplicate.name = new_name
    duplicate.data.name = "MESH_" + new_name
    return duplicate


def filter_object_by_vertex_groups(obj, keep_match, invert=False):
    keep_groups = {
        group.index for group in obj.vertex_groups if keep_match(group.name)
    }
    if not keep_groups:
        log("No matching vertex groups on " + obj.name + "; keeping mesh as-is")
        return

    keep_vertices = set()
    for vertex in obj.data.vertices:
        has_match = False
        for group in vertex.groups:
            if group.group in keep_groups and group.weight > 0.0001:
                has_match = True
                break
        if has_match != invert:
            keep_vertices.add(vertex.index)

    if not keep_vertices:
        log("Filter would empty " + obj.name + "; keeping mesh as-is")
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


def ensure_armature_modifier(obj, rig):
    found = None
    for modifier in tuple(obj.modifiers):
        if modifier.type == "ARMATURE":
            if found is None:
                found = modifier
            else:
                obj.modifiers.remove(modifier)
    if found is None:
        found = obj.modifiers.new("Armature", "ARMATURE")
    found.name = "Armature"
    found.object = rig
    found.use_deform_preserve_volume = True


def clean_vertex_groups(obj, rig):
    bone_names = {bone.name for bone in rig.data.bones}
    for group in tuple(obj.vertex_groups):
        if group.name not in bone_names:
            obj.vertex_groups.remove(group)
    make_active(obj)
    if obj.vertex_groups:
        bpy.ops.object.vertex_group_clean(
            group_select_mode="ALL",
            limit=0.0001,
            keep_single=True,
        )
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(
            group_select_mode="ALL",
            lock_active=False,
        )


def set_material_name(obj, material_name):
    if not hasattr(obj.data, "materials"):
        return
    if obj.data.materials and obj.data.materials[0] is not None:
        obj.data.materials[0].name = material_name
    else:
        material = bpy.data.materials.new(material_name)
        obj.data.materials.append(material)


def prep_mesh(obj, rig, collection_name, material_name):
    obj.data.name = "MESH_" + obj.name
    ensure_armature_modifier(obj, rig)
    clean_vertex_groups(obj, rig)
    set_material_name(obj, material_name)
    move_to_collection(obj, collection_name)
    obj.hide_viewport = False
    obj.hide_render = False


def hide_reference(obj):
    move_to_collection(obj, "90_REFERENCE")
    obj.hide_viewport = True
    obj.hide_render = True


def build_body_zones(rig):
    head = object_by_name("BODY_Head", "Head")
    torso = object_by_name("BODY_Torso", "Torso")
    left_arm = object_by_name("LeftArm")
    right_arm = object_by_name("RightArm")
    left_leg = object_by_name("LeftLeg")
    right_leg = object_by_name("RightLeg")

    if None in [head, torso, left_arm, right_arm, left_leg, right_leg]:
        raise RuntimeError("Missing one of Head/Torso/LeftArm/RightArm/LeftLeg/RightLeg")

    head.name = "BODY_Head"
    torso.name = "BODY_Torso"

    left_hand = duplicate_mesh_object(left_arm, "BODY_Hands_Left_TEMP")
    right_hand = duplicate_mesh_object(right_arm, "BODY_Hands_Right_TEMP")
    # Keep the whole arm for now. This avoids short-sleeve/aim-pose holes.
    hands = join_objects([left_hand, right_hand], "BODY_Hands")

    left_foot = duplicate_mesh_object(left_leg, "BODY_Feet_Left_TEMP")
    right_foot = duplicate_mesh_object(right_leg, "BODY_Feet_Right_TEMP")
    filter_object_by_vertex_groups(
        left_foot,
        lambda name: "Foot" in name or "Toe" in name,
    )
    filter_object_by_vertex_groups(
        right_foot,
        lambda name: "Foot" in name or "Toe" in name,
    )
    feet = join_objects([left_foot, right_foot], "BODY_Feet")

    filter_object_by_vertex_groups(
        left_leg,
        lambda name: "Foot" in name or "Toe" in name,
        invert=True,
    )
    filter_object_by_vertex_groups(
        right_leg,
        lambda name: "Foot" in name or "Toe" in name,
        invert=True,
    )
    legs = join_objects([left_leg, right_leg], "BODY_Legs")

    for obj in [head, torso, hands, legs, feet]:
        prep_mesh(obj, rig, "01_BODY", "MAT_BODY_Skin")

    # Old arm source objects were duplicated into BODY_Hands, so hide originals.
    hide_reference(left_arm)
    hide_reference(right_arm)


def prep_hair(rig):
    hair = object_by_name("HAIR_01_Short", "Hair")
    if hair is None:
        return
    hair.name = "HAIR_01_Short"
    prep_mesh(hair, rig, "05_HAIR", "MAT_HAIR_01_Short")


def prep_scene():
    for collection_name in COLLECTIONS:
        ensure_collection(collection_name)

    rig = object_by_name(RIG_NAME, "Armature")
    if rig is None or rig.type != "ARMATURE":
        raise RuntimeError("Could not find one armature")
    rig.name = RIG_NAME
    rig.data.name = "RIG_CHR_Armature"
    move_to_collection(rig, "00_RIG")

    build_body_zones(rig)
    prep_hair(rig)

    parent_node = bpy.data.objects.get("ParentNode")
    if parent_node is not None:
        hide_reference(parent_node)

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_PATH)
    log("Saved clean clothing-ready master: " + OUTPUT_PATH)


if __name__ == "__main__":
    prep_scene()
