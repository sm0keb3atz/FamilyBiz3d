import bpy
import os


SOURCE_BLEND = r"C:\Users\smo0o\OneDrive\Desktop\shh\Project material\Family Business\Assets\Chracters\3d models\NewModels\FB_Player_Final_Master_v001.blend"


def log(message: str) -> None:
    print(f"[FB lower-body fix] {message}")


def collection(name: str):
    col = bpy.data.collections.get(name)
    if not col:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def move_to_collection(obj, target_name: str) -> None:
    target = collection(target_name)
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    target.objects.link(obj)


def delete_object(name: str) -> None:
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)


def append_source_legs():
    source_objects = ["LeftLeg", "RightLeg"]
    existing = set(bpy.data.objects.keys())
    directory = os.path.join(SOURCE_BLEND, "Object")
    for obj_name in source_objects:
        bpy.ops.wm.append(
            filepath=os.path.join(directory, obj_name),
            directory=directory,
            filename=obj_name,
            link=False,
        )

    appended = []
    for obj in bpy.context.selected_objects:
        if obj.name not in existing and obj.type == "MESH":
            appended.append(obj)

    if len(appended) < 2:
        # Blender may preserve selected state oddly after append, so fall back by name.
        appended = [bpy.data.objects.get(name) for name in source_objects if bpy.data.objects.get(name)]
        appended = [obj for obj in appended if obj and obj.type == "MESH"]

    if len(appended) < 2:
        raise RuntimeError("Could not append both LeftLeg and RightLeg from the clean v001 source.")

    return appended


def duplicate_objects(objects, suffix: str):
    duplicates = []
    for obj in objects:
        dup = obj.copy()
        dup.data = obj.data.copy()
        dup.animation_data_clear()
        dup.name = f"TMP_{obj.name}_{suffix}"
        dup.data.name = f"MESH_{dup.name}"
        bpy.context.scene.collection.objects.link(dup)
        duplicates.append(dup)
    return duplicates


def join_objects(objects, object_name: str, mesh_name: str):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.ops.object.mode_set.poll() else None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = object_name
    joined.data.name = mesh_name
    return joined


def assign_body_material(obj) -> None:
    mat = bpy.data.materials.get("MAT_BODY_Skin")
    if mat:
        obj.data.materials.clear()
        obj.data.materials.append(mat)


def set_armature_modifier(obj) -> None:
    rig = bpy.data.objects.get("CHR_Armature")
    if not rig:
        raise RuntimeError("CHR_Armature not found.")

    for mod in list(obj.modifiers):
        if mod.type == "ARMATURE":
            obj.modifiers.remove(mod)
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig


def keep_only_foot_vertices(obj) -> None:
    foot_group_indices = {
        group.index
        for group in obj.vertex_groups
        if "foot" in group.name.lower() or "toe" in group.name.lower()
    }
    if not foot_group_indices:
        raise RuntimeError(f"{obj.name} has no Foot/Toe vertex groups to build BODY_Feet from.")

    bpy.ops.object.mode_set(mode="OBJECT") if bpy.ops.object.mode_set.poll() else None
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="VERT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")

    for vertex in obj.data.vertices:
        vertex.select = any(weight.group in foot_group_indices for weight in vertex.groups)

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="INVERT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")


def normalize_transforms(obj) -> None:
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)


def main():
    rig = bpy.data.objects.get("CHR_Armature")
    if rig:
        rig.rotation_euler = (0, 0, 0)
        rig.scale = (0.01, 0.01, 0.01)

    log("Appending clean LeftLeg/RightLeg from v001...")
    source_legs = append_source_legs()
    for obj in source_legs:
        normalize_transforms(obj)

    log("Deleting broken BODY_Legs and BODY_Feet...")
    delete_object("BODY_Legs")
    delete_object("BODY_Feet")

    log("Rebuilding BODY_Legs as one continuous full lower-body mesh...")
    full_leg_parts = duplicate_objects(source_legs, "FULL")
    body_legs = join_objects(full_leg_parts, "BODY_Legs", "MESH_BODY_Legs")
    assign_body_material(body_legs)
    set_armature_modifier(body_legs)
    move_to_collection(body_legs, "01_BODY")

    log("Rebuilding BODY_Feet from clean foot/toe weighted vertices...")
    foot_parts = duplicate_objects(source_legs, "FEET")
    for obj in foot_parts:
        keep_only_foot_vertices(obj)
    body_feet = join_objects(foot_parts, "BODY_Feet", "MESH_BODY_Feet")
    assign_body_material(body_feet)
    set_armature_modifier(body_feet)
    move_to_collection(body_feet, "01_BODY")
    # BODY_Legs now includes the feet too, so this helper stays hidden in Blender to avoid double-geometry confusion.
    body_feet.hide_viewport = True
    body_feet.hide_render = True

    log("Removing temporary appended source legs...")
    for obj in source_legs:
        if obj.name in bpy.data.objects:
            bpy.data.objects.remove(obj, do_unlink=True)

    for obj in (body_legs, body_feet):
        normalize_transforms(obj)

    log("Saving repaired master...")
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    log("Done.")


if __name__ == "__main__":
    main()
