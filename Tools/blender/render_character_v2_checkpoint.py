"""Render a staging master without saving changes to it."""
import sys
from pathlib import Path
import bpy
from mathutils import Vector

output = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 800
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world.color = (0.25, 0.25, 0.25)
for obj in scene.objects:
    if obj.type == 'MESH' and (obj.name.startswith('WGT') or obj.name.endswith('_WeightSource')):
        obj.hide_render = True
    if obj.type == 'ARMATURE':
        obj.data.pose_position = 'REST'
bpy.ops.object.camera_add(location=(2.7, -5.5, 2.4))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0.95)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.5
scene.camera = camera
for position, energy, size in [((3, -4, 5), 600, 4), ((-3, -1, 3), 400, 3), ((0, 3, 4), 500, 3)]:
    bpy.ops.object.light_add(type='AREA', location=position)
    light = bpy.context.object
    light.data.energy = energy
    light.data.shape = 'DISK'
    light.data.size = size
    light.rotation_euler = (Vector((0, 0, 1)) - light.location).to_track_quat('-Z', 'Y').to_euler()
output.parent.mkdir(parents=True, exist_ok=True)
scene.render.filepath = str(output)
bpy.ops.render.render(write_still=True)
