import bpy
import json
import sys


def obj_info(obj):
    mods = []
    for mod in obj.modifiers:
        item = {"name": mod.name, "type": mod.type}
        if mod.type == "ARMATURE" and getattr(mod, "object", None):
            item["target"] = mod.object.name
        mods.append(item)
    mats = []
    if hasattr(obj.data, "materials"):
        mats = [m.name if m else None for m in obj.data.materials]
    vgroups = [g.name for g in obj.vertex_groups[:10]]
    return {
        "name": obj.name,
        "type": obj.type,
        "data_name": getattr(obj.data, "name", None),
        "collection_names": [c.name for c in obj.users_collection],
        "location": [round(v, 6) for v in obj.location],
        "rotation": [round(v, 6) for v in obj.rotation_euler],
        "scale": [round(v, 6) for v in obj.scale],
        "modifiers": mods,
        "materials": mats,
        "vertex_group_count": len(obj.vertex_groups),
        "vertex_group_sample": vgroups,
        "hidden_viewport": obj.hide_viewport,
        "hidden_render": obj.hide_render,
    }


armatures = []
for obj in bpy.data.objects:
    if obj.type == "ARMATURE":
        bones = [b.name for b in obj.data.bones]
        armatures.append({
            "name": obj.name,
            "data_name": obj.data.name,
            "bone_count": len(bones),
            "bone_sample": bones[:20],
            "scale": [round(v, 6) for v in obj.scale],
        })

report = {
    "file": bpy.data.filepath,
    "collections": [c.name for c in bpy.data.collections],
    "armatures": armatures,
    "objects": [obj_info(o) for o in bpy.data.objects],
    "actions": [a.name for a in bpy.data.actions],
    "materials": [m.name for m in bpy.data.materials],
    "images": [i.name for i in bpy.data.images],
}

print("FB_INSPECT_JSON_START")
print(json.dumps(report, indent=2))
print("FB_INSPECT_JSON_END")
