import os
import bpy
import bmesh
from mathutils import Vector, kdtree


PROJECT_ROOT = "C:/Users/smo0o/OneDrive/Documents/family-biz-prototype"
NEW_MODEL_BLEND = (
    "C:/Users/smo0o/OneDrive/Desktop/shh/Project material/Family Business/"
    "Assets/Chracters/3d models/NewModels/MaleBlack.blend"
)
OUTPUT_BLEND = PROJECT_ROOT + "/Assets/BaseChracters/Player/Source/MaleBlack_GameRig_Master_v002.blend"
OUTPUT_GLB = PROJECT_ROOT + "/Assets/BaseChracters/Player/Working/FB_Character_Working.glb"
FALLBACK_GLB = PROJECT_ROOT + "/Assets/BaseChracters/Player/Working/FB_Character_Working_FIXED.glb"

RIG_NAME = "CHR_Armature"
BODY_NAMES = ["BODY_Head", "BODY_Torso", "BODY_Hands", "BODY_Legs", "BODY_Feet"]
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


def log(message):
    print("FB_REPLACE_MESHDATA:", message)


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
    for obj in [obj for obj in bpy.data.objects if obj not in before]:
        base_name = obj.name.split(".")[0]
        if base_name in NEW_OBJECTS:
            imported[base_name] = obj
            obj.name = "IMPORT_" + base_name
            if hasattr(obj.data, "name"):
                obj.data.name = "MESH_IMPORT_" + base_name
            move_to_collection(obj, "90_REFERENCE")
            obj.hide_viewport = True
            obj.hide_render = True
    return imported


def align_imported_to_old(imported):
    old_body = [bpy.data.objects[name] for name in BODY_NAMES]
    new_body = [imported[name] for name in ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]]
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
    log("Aligned import by {}".format(tuple(round(v, 4) for v in offset)))


def duplicate_for_reference(obj):
    duplicate = obj.copy()
    duplicate.data = obj.data.copy()
    duplicate.animation_data_clear()
    duplicate.name = "WEIGHT_REF_" + obj.name
    duplicate.data.name = "MESH_" + duplicate.name
    bpy.context.scene.collection.objects.link(duplicate)
    move_to_collection(duplicate, "90_REFERENCE")
    duplicate.hide_viewport = True
    duplicate.hide_render = True
    return duplicate


def make_mesh_from_world_sources(name, sources, target_object):
    vertices = []
    faces = []
    material_indices = []
    target_inv = target_object.matrix_world.inverted()

    for source in sources:
        vertex_offset = len(vertices)
        for vertex in source.data.vertices:
            vertices.append(target_inv @ (source.matrix_world @ vertex.co))
        for polygon in source.data.polygons:
            faces.append([vertex_offset + index for index in polygon.vertices])
            material_indices.append(polygon.material_index)

    mesh = bpy.data.meshes.new("MESH_" + name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for index, polygon in enumerate(mesh.polygons):
        if index < len(material_indices):
            polygon.material_index = material_indices[index]
    return mesh


def filtered_duplicate(source, keep_match):
    duplicate = source.copy()
    duplicate.data = source.data.copy()
    duplicate.animation_data_clear()
    bpy.context.scene.collection.objects.link(duplicate)
    keep_groups = {
        group.index for group in duplicate.vertex_groups if keep_match(group.name)
    }
    keep_vertices = set()
    for vertex in duplicate.data.vertices:
        for group in vertex.groups:
            if group.group in keep_groups and group.weight > 0.0001:
                keep_vertices.add(vertex.index)
                break
    if keep_vertices:
        bm = bmesh.new()
        bm.from_mesh(duplicate.data)
        bm.verts.ensure_lookup_table()
        delete_verts = [vertex for vertex in bm.verts if vertex.index not in keep_vertices]
        bmesh.ops.delete(bm, geom=delete_verts, context="VERTS")
        bm.to_mesh(duplicate.data)
        bm.free()
        duplicate.data.update()
    move_to_collection(duplicate, "90_REFERENCE")
    duplicate.hide_viewport = True
    duplicate.hide_render = True
    return duplicate


def transfer_weights(target, source_reference, rig):
    target.vertex_groups.clear()
    group_lookup = {}
    for source_group in source_reference.vertex_groups:
        group_lookup[source_group.index] = target.vertex_groups.new(name=source_group.name)

    kd = kdtree.KDTree(len(source_reference.data.vertices))
    source_world = source_reference.matrix_world
    for vertex in source_reference.data.vertices:
        kd.insert(source_world @ vertex.co, vertex.index)
    kd.balance()

    bone_names = {bone.name for bone in rig.data.bones}
    for target_vertex in target.data.vertices:
        target_world = target.matrix_world @ target_vertex.co
        _, source_index, _ = kd.find(target_world)
        source_vertex = source_reference.data.vertices[source_index]
        for source_weight in source_vertex.groups:
            if source_weight.weight <= 0.0001:
                continue
            group = group_lookup.get(source_weight.group)
            if group is not None and group.name in bone_names:
                group.add([target_vertex.index], source_weight.weight, "REPLACE")

    for group in tuple(target.vertex_groups):
        if group.name not in bone_names:
            target.vertex_groups.remove(group)

    make_active(target)
    if target.vertex_groups:
        bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.0001, keep_single=True)
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def replace_object_mesh(target, sources, source_reference, rig, material_source=None):
    old_mesh = target.data
    new_mesh = make_mesh_from_world_sources(target.name, sources, target)
    target.data = new_mesh
    if material_source is not None and hasattr(material_source.data, "materials"):
        target.data.materials.clear()
        for material in material_source.data.materials:
            target.data.materials.append(material)
    elif old_mesh.materials:
        for material in old_mesh.materials:
            target.data.materials.append(material)
    transfer_weights(target, source_reference, rig)
    target.hide_viewport = False
    target.hide_render = False


def create_hair_object(name, source, head_template, head_reference, rig):
    hair = head_template.copy()
    hair.data = head_template.data.copy()
    hair.animation_data_clear()
    hair.name = name
    bpy.context.scene.collection.objects.link(hair)
    move_to_collection(hair, "05_HAIR")
    replace_object_mesh(hair, [source], head_reference, rig, source)
    return hair


def export_objects():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if (
            obj.name == RIG_NAME
            or obj.name in BODY_NAMES
            or obj.name.startswith("TOP_")
            or obj.name.startswith("BOTTOM_")
            or obj.name.startswith("SHOES_")
            or obj.name.startswith("HAIR_")
        ):
            obj.select_set(True)
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
        log("Could not overwrite working GLB; exporting fallback: " + str(error))
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
    rig = bpy.data.objects[RIG_NAME]
    rig.rotation_euler = (0.0, 0.0, 0.0)
    rig.scale = (0.01, 0.01, 0.01)
    for collection_name in ["01_BODY", "02_TOPS", "03_BOTTOMS", "04_SHOES", "05_HAIR", "90_REFERENCE"]:
        ensure_collection(collection_name)

    references = {name: duplicate_for_reference(bpy.data.objects[name]) for name in BODY_NAMES}
    references["TOP_01_Hoodie"] = duplicate_for_reference(bpy.data.objects["TOP_01_Hoodie"])
    references["TOP_02_TShirt"] = duplicate_for_reference(bpy.data.objects["TOP_02_TShirt"])
    references["BOTTOM_01_Jeans"] = duplicate_for_reference(bpy.data.objects["BOTTOM_01_Jeans"])
    references["SHOES_01_Sneakers"] = duplicate_for_reference(bpy.data.objects["SHOES_01_Sneakers"])

    imported = import_new_objects()
    align_imported_to_old(imported)

    left_hand = filtered_duplicate(imported["LeftArm"], lambda name: "Hand" in name)
    right_hand = filtered_duplicate(imported["RightArm"], lambda name: "Hand" in name)
    left_feet = filtered_duplicate(imported["LeftLeg"], lambda name: "Foot" in name or "Toe" in name)
    right_feet = filtered_duplicate(imported["RightLeg"], lambda name: "Foot" in name or "Toe" in name)

    replace_object_mesh(bpy.data.objects["BODY_Head"], [imported["Head"]], references["BODY_Head"], rig, imported["Head"])
    replace_object_mesh(bpy.data.objects["BODY_Torso"], [imported["Torso"]], references["BODY_Torso"], rig, imported["Torso"])
    replace_object_mesh(bpy.data.objects["BODY_Hands"], [left_hand, right_hand], references["BODY_Hands"], rig, imported["Head"])
    replace_object_mesh(bpy.data.objects["BODY_Legs"], [imported["LeftLeg"], imported["RightLeg"]], references["BODY_Legs"], rig, imported["Head"])
    replace_object_mesh(bpy.data.objects["BODY_Feet"], [left_feet, right_feet], references["BODY_Feet"], rig, imported["Head"])

    replace_object_mesh(bpy.data.objects["TOP_01_Hoodie"], [imported["Hoodie"]], references["TOP_01_Hoodie"], rig, imported["Hoodie"])
    replace_object_mesh(bpy.data.objects["TOP_02_TShirt"], [imported["Tshirt"]], references["TOP_02_TShirt"], rig, imported["Tshirt"])
    replace_object_mesh(bpy.data.objects["BOTTOM_01_Jeans"], [imported["Jeans"]], references["BOTTOM_01_Jeans"], rig, imported["Jeans"])
    replace_object_mesh(bpy.data.objects["SHOES_01_Sneakers"], [imported["Sneakers"]], references["SHOES_01_Sneakers"], rig, imported["Sneakers"])

    create_hair_object("HAIR_01_Short", imported["Hair"], bpy.data.objects["BODY_Head"], references["BODY_Head"], rig)
    create_hair_object("HAIR_02_Alt", imported["Hair2"], bpy.data.objects["BODY_Head"], references["BODY_Head"], rig)

    os.makedirs(os.path.dirname(OUTPUT_BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_BLEND)
    log("Saved " + OUTPUT_BLEND)
    export_objects()


if __name__ == "__main__":
    main()
