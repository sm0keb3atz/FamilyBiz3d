import bpy
import json
from mathutils import Vector


def bounds(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    mins = [min(corner[i] for corner in corners) for i in range(3)]
    maxs = [max(corner[i] for corner in corners) for i in range(3)]
    return {
        "center": [round((mins[i] + maxs[i]) / 2.0, 4) for i in range(3)],
        "size": [round(maxs[i] - mins[i], 4) for i in range(3)],
        "rot": [round(v, 4) for v in obj.rotation_euler],
        "scale": [round(v, 4) for v in obj.scale],
    }


result = {}
for obj in bpy.data.objects:
    if obj.type == "MESH":
        result[obj.name] = bounds(obj)

print("FB_BLEND_BOUNDS_START")
print(json.dumps(result, indent=2))
print("FB_BLEND_BOUNDS_END")
