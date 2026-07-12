import bpy

rig = bpy.data.objects.get("CHR_Armature")
if rig is None or rig.type != "ARMATURE":
    raise RuntimeError("CHR_Armature not found")

rig.rotation_euler = (0.0, 0.0, 0.0)
rig.scale = (0.01, 0.01, 0.01)
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print("FB_FINAL_MASTER: set CHR_Armature rotation to 0,0,0")
