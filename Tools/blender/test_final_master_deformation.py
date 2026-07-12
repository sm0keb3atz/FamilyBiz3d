import math
import bpy


def world_bounds(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(depsgraph)
    corners = [eval_obj.matrix_world @ corner for corner in eval_obj.bound_box]
    return (
        tuple(round(min(c[i] for c in corners), 4) for i in range(3)),
        tuple(round(max(c[i] for c in corners), 4) for i in range(3)),
    )


rig = bpy.data.objects["CHR_Armature"]
test_objects = [
    bpy.data.objects.get("BODY_Hands"),
    bpy.data.objects.get("BODY_Torso"),
    bpy.data.objects.get("TOP_01_Tshirt"),
    bpy.data.objects.get("TOP_02_Hoodie"),
    bpy.data.objects.get("TOP_03_PoliceShirt"),
]
test_objects = [obj for obj in test_objects if obj]

bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.select_all(action="SELECT")
bpy.ops.pose.transforms_clear()
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()

print("BEFORE")
for obj in test_objects:
    print(obj.name, world_bounds(obj))

bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")
pb = rig.pose.bones.get("mixamorig:LeftForeArm")
pb.rotation_mode = "XYZ"
pb.rotation_euler.rotate_axis("Z", math.radians(65))
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()

print("AFTER")
for obj in test_objects:
    print(obj.name, world_bounds(obj))
