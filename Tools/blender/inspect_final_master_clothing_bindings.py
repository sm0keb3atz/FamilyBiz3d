import bpy


rig = bpy.data.objects.get("CHR_Armature")
print("RIG", rig.name if rig else None)

for obj in bpy.data.objects:
    if obj.type != "MESH":
        continue
    if not obj.name.startswith(("TOP_", "BOTTOM_", "SHOES_", "HAIR_", "BODY_")):
        continue

    print(
        "OBJ",
        obj.name,
        "parent",
        obj.parent.name if obj.parent else None,
        "rotXdeg",
        round(obj.rotation_euler.x * 180.0 / 3.1415926535, 2),
        "groups",
        len(obj.vertex_groups),
        "mods",
        [
            (
                mod.name,
                mod.type,
                mod.object.name if getattr(mod, "object", None) else None,
                mod.show_viewport,
            )
            for mod in obj.modifiers
        ],
    )
