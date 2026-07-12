import bpy


rig = bpy.data.objects.get("CHR_Armature")
if rig is None:
    raise RuntimeError("CHR_Armature not found")

print("RIG_TRANSFORM", tuple(rig.location), tuple(rig.rotation_euler), tuple(rig.scale))
print("RIG_PARENT", rig.parent.name if rig.parent else None)
print("RIG_ACTION", rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else None)

changed = []
for pb in rig.pose.bones:
    quat_changed = (
        abs(pb.rotation_quaternion.w - 1.0) > 1e-5
        or abs(pb.rotation_quaternion.x) > 1e-5
        or abs(pb.rotation_quaternion.y) > 1e-5
        or abs(pb.rotation_quaternion.z) > 1e-5
    )
    loc_changed = any(abs(v) > 1e-5 for v in pb.location)
    euler_changed = any(abs(v) > 1e-5 for v in pb.rotation_euler)
    scale_changed = any(abs(v - 1.0) > 1e-5 for v in pb.scale)
    if loc_changed or euler_changed or quat_changed or scale_changed:
        changed.append(
            (
                pb.name,
                tuple(round(v, 4) for v in pb.location),
                tuple(round(v, 4) for v in pb.rotation_euler),
                tuple(round(v, 4) for v in pb.rotation_quaternion),
                tuple(round(v, 4) for v in pb.scale),
                pb.rotation_mode,
            )
        )

print("CHANGED_POSE_BONES", len(changed))
for item in changed[:40]:
    print("POSE_BONE", item)
