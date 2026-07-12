import bpy


def log(message: str) -> None:
    print(f"[FB clear bad pose] {message}")


rig = bpy.data.objects.get("CHR_Armature")
if rig is None:
    raise RuntimeError("CHR_Armature not found")

log("Clearing assigned armature action...")
if rig.animation_data:
    rig.animation_data.action = None

log("Clearing pose bone transforms...")
bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.select_all(action="SELECT")
bpy.ops.pose.transforms_clear()
bpy.ops.pose.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")

log("Keeping armature in Pose Position for easy clothing testing...")
rig.data.pose_position = "POSE"

bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
log("Done.")
