import bpy


MASTER_RIG_NAME = "CHR_Armature"
EXPORT_MESH_PREFIXES = (
    "BODY_",
    "TOP_",
    "BOTTOM_",
    "SHOES_",
    "HAIR_",
)


def log(message: str) -> None:
    print(f"[FB duplicate armature fix] {message}")


def unlink_from_all_collections(obj):
    for col in list(obj.users_collection):
        col.objects.unlink(obj)


def ensure_collection(name: str):
    col = bpy.data.collections.get(name)
    if not col:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def move_to_collection(obj, collection_name: str) -> None:
    target = ensure_collection(collection_name)
    if obj.name not in target.objects:
        unlink_from_all_collections(obj)
        target.objects.link(obj)


def main():
    master_rig = bpy.data.objects.get(MASTER_RIG_NAME)
    if not master_rig:
        raise RuntimeError(f"Missing master rig: {MASTER_RIG_NAME}")

    log("Normalizing master rig transform...")
    master_rig.location = (0, 0, 0)
    master_rig.rotation_euler = (0, 0, 0)
    master_rig.scale = (0.01, 0.01, 0.01)
    move_to_collection(master_rig, "00_RIG")

    log("Re-pointing all character mesh armature modifiers to the master rig...")
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if not obj.name.startswith(EXPORT_MESH_PREFIXES):
            continue

        # Do not let imported source armatures remain as parents.
        obj.parent = None
        obj.matrix_parent_inverse.identity()
        obj.location = (0, 0, 0)
        obj.rotation_euler = (0, 0, 0)
        obj.scale = (1, 1, 1)

        armature_mods = [mod for mod in obj.modifiers if mod.type == "ARMATURE"]
        if not armature_mods:
            mod = obj.modifiers.new("Armature", "ARMATURE")
            armature_mods = [mod]

        # Keep exactly one Armature modifier.
        first = armature_mods[0]
        first.name = "Armature"
        first.object = master_rig
        for extra in armature_mods[1:]:
            obj.modifiers.remove(extra)

    log("Removing duplicate imported armatures...")
    for obj in list(bpy.data.objects):
        if obj.type == "ARMATURE" and obj.name != MASTER_RIG_NAME:
            log(f"Removing {obj.name}")
            bpy.data.objects.remove(obj, do_unlink=True)

    log("Putting mesh objects back in their collections...")
    collection_map = {
        "BODY_": "01_BODY",
        "TOP_": "02_TOPS",
        "BOTTOM_": "03_BOTTOMS",
        "SHOES_": "04_SHOES",
        "HAIR_": "05_HAIR",
    }
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for prefix, collection_name in collection_map.items():
            if obj.name.startswith(prefix):
                move_to_collection(obj, collection_name)
                break

    feet = bpy.data.objects.get("BODY_Feet")
    if feet:
        feet.hide_viewport = True
        feet.hide_render = True

    log("Saving clean master...")
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    log("Done.")


if __name__ == "__main__":
    main()
