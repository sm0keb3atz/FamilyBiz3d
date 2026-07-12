import bpy
import sys
import json
from mathutils import Vector


def object_bounds_world(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    mins = [min(corner[i] for corner in corners) for i in range(3)]
    maxs = [max(corner[i] for corner in corners) for i in range(3)]
    center = [(mins[i] + maxs[i]) / 2.0 for i in range(3)]
    size = [maxs[i] - mins[i] for i in range(3)]
    return {
        "center": [round(v, 4) for v in center],
        "size": [round(v, 4) for v in size],
    }


path = sys.argv[-1]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=path)

objects = {}
for obj in bpy.data.objects:
    if obj.type == "MESH":
        objects[obj.name] = object_bounds_world(obj)

print("FB_GLB_BOUNDS_START")
print(json.dumps(objects, indent=2))
print("FB_GLB_BOUNDS_END")
