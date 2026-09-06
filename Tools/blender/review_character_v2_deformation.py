"""Repair coincident garment vertices and generate explicit synthetic pose reviews.

Never overwrites an input or an existing output. These are stress poses, NOT
retargeted gameplay animations. Reports intentionally remain unapproved.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Quaternion, Vector
from mathutils.bvhtree import BVHTree


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
    out = args.output.resolve()
    if out.exists():
        raise RuntimeError('Refusing to overwrite review directory')
    out.mkdir(parents=True)
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    body = next(o for o in bpy.context.scene.objects
                if o.name.startswith('BODY_') and not o.name.endswith('_WeightSource'))
    garments = [o for o in bpy.context.scene.objects
                if o.type == 'MESH' and o.name.startswith(('TOP_', 'BOTTOM_', 'SHOES_'))]
    report = {'status': 'UNAPPROVED_POSE_REVIEW', 'input': bpy.data.filepath,
              'notes': ['Synthetic stress poses only; gameplay clips not validated.',
                        'Inside-vertex counts are nearest-surface heuristics, not a collision pass.',
                        'No runtime assets or original downloaded files changed.'],
              'garments': [], 'poses': {}}
    for obj in garments:
        before = len(obj.data.vertices)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.vertex_group_limit_total(limit=4)
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
        deform = {g.index for g in obj.vertex_groups
                  if g.name in rig.data.bones and rig.data.bones[g.name].use_deform}
        totals = [sum(g.weight for g in v.groups if g.group in deform)
                  for v in obj.data.vertices]
        report['garments'].append({
            'name': obj.name, 'vertices': len(totals),
            'coincident_vertices_joined': before-len(totals),
            'unweighted': sum(t < 1e-6 for t in totals),
            'non_normalized': sum(abs(t-1) > 0.0001 for t in totals),
            'max_influences': max(sum(g.weight > 1e-6 for g in v.groups)
                                  for v in obj.data.vertices),
            'unknown_groups': [g.name for g in obj.vertex_groups if g.name not in rig.data.bones],
        })
        obj['fb_validation_status'] = 'UNAPPROVED_POSE_REVIEW'
    rig.data.pose_position = 'POSE'
    rig.animation_data_clear()
    # Vendor Rigify constraints override direct deform-bone rotations. Mute only
    # in this isolated review copy, leaving the authoring rig fully untouched.
    report['review_only_muted_constraints'] = 0
    for bone in rig.pose.bones:
        for constraint in bone.constraints:
            constraint.mute = True
            report['review_only_muted_constraints'] += 1
    poses = {
        'rest': {},
        'arms_down': {'upperarm_l': ('Y', 70), 'upperarm_r': ('Y', -70)},
        'elbows_bent': {'upperarm_l': ('Y', 65), 'upperarm_r': ('Y', -65),
                        'lowerarm_l': ('Z', -90), 'lowerarm_r': ('Z', 90)},
        'stride': {'upperarm_l': ('Y', 70), 'upperarm_r': ('Y', -70),
                   'thigh_l': ('X', -40), 'thigh_r': ('X', 30), 'calf_r': ('X', 65)},
        'seated': {'upperarm_l': ('Y', 65), 'upperarm_r': ('Y', -65),
                   'lowerarm_l': ('Z', -80), 'lowerarm_r': ('Z', 80),
                   'thigh_l': ('X', -85), 'thigh_r': ('X', -85),
                   'calf_l': ('X', 90), 'calf_r': ('X', 90)},
        'crouch': {'upperarm_l': ('Y', 60), 'upperarm_r': ('Y', -60),
                   'thigh_l': ('X', -100), 'thigh_r': ('X', -100),
                   'calf_l': ('X', 125), 'calf_r': ('X', 125),
                   'foot_l': ('X', -25), 'foot_r': ('X', -25)},
    }
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
    bpy.ops.object.camera_add(location=(2.7, -5.5, 2.4))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0.95))-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 2.5
    scene.camera = camera
    for location, energy in [((3, -4, 5), 600), ((-3, -1, 3), 400), ((0, 3, 4), 500)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.shape = 'DISK'
        light.data.size = 4
        light.rotation_euler = (Vector((0, 0, 1))-light.location).to_track_quat('-Z', 'Y').to_euler()
    for index, (label, rotations) in enumerate(poses.items()):
        frame = 1 + index*20
        scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.rotation_mode = 'QUATERNION'
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
            bone.rotation_quaternion = Quaternion()
            if bone.name in rotations:
                axis, degrees = rotations[bone.name]
                vector = Vector({'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}[axis])
                local = bone.bone.matrix_local.to_quaternion().inverted() @ vector
                bone.rotation_quaternion = Quaternion(local, math.radians(degrees))
            bone.keyframe_insert(data_path='rotation_quaternion', frame=frame)
        scene.timeline_markers.new(label, frame=frame)
        bpy.context.view_layer.update()
        if rotations:
            changed = any((rig.pose.bones[name].matrix.to_quaternion().rotation_difference(
                rig.data.bones[name].matrix_local.to_quaternion())).angle > 0.01
                for name in rotations)
            if not changed:
                raise RuntimeError('Stress pose did not move the rig: '+label)
        deps = bpy.context.evaluated_depsgraph_get()
        evaluated_body = body.evaluated_get(deps)
        mesh = evaluated_body.to_mesh()
        surface = BVHTree.FromPolygons([body.matrix_world @ v.co for v in mesh.vertices],
                                      [list(p.vertices) for p in mesh.polygons])
        evaluated_body.to_mesh_clear()
        metrics = {}
        for obj in garments:
            ev = obj.evaluated_get(deps)
            mesh = ev.to_mesh()
            inside = 0
            for v in mesh.vertices:
                point = obj.matrix_world @ v.co
                nearest, normal, face, distance = surface.find_nearest(point)
                inside += int(nearest is not None and (point-nearest).dot(normal) < -0.002)
            metrics[obj.name] = {'possibly_inside_body_vertices': inside}
            ev.to_mesh_clear()
        report['poses'][label] = {'frame': frame, 'metrics': metrics}
        scene.render.filepath = str(out / (label+'.png'))
        bpy.ops.render.render(write_still=True)
        print('POSE_REVIEW_RENDERED', label, flush=True)
    scene.frame_start = 1
    scene.frame_end = 101
    scene.frame_set(1)
    if rig.animation_data and rig.animation_data.action:
        rig.animation_data.action.name = 'REVIEW_ONLY_SyntheticStressPoses'
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'pose_review.blend'), check_existing=False)
    (out/'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('POSE_REVIEW_COMPLETE', json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
