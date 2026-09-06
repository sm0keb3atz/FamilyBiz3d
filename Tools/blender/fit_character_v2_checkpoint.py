"""Generate an unapproved regular-body clothing fit for visual inspection.

Uses source skin weights as a deformation cage between bone segments, then
transfers fresh weights from the complete target body. Source files are read only.
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


BONE_MAP = dict(Hips='pelvis', Spine='spine_01', Spine1='spine_02',
    Spine2='spine_03', Neck='neck_01', Head='Head')
for side, suffix in [('Left', 'l'), ('Right', 'r')]:
    for old, new in [('Shoulder', 'clavicle'), ('Arm', 'upperarm'),
        ('ForeArm', 'lowerarm'), ('Hand', 'hand'), ('UpLeg', 'thigh'),
        ('Leg', 'calf'), ('Foot', 'foot'), ('ToeBase', 'ball')]:
        BONE_MAP[side + old] = new + '_' + suffix


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--garments', nargs='+', required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if args.output.exists():
        raise RuntimeError('Refusing to overwrite existing fit')
    # Capture original rest geometry and weights before opening target master.
    bpy.ops.wm.open_mainfile(filepath=str(args.source.resolve()), load_ui=False)
    originals = {}
    for name in args.garments:
        obj = bpy.data.objects[name]
        rig = next(m.object for m in obj.modifiers if m.type == 'ARMATURE' and m.object)
        bones = {}
        for bone in rig.data.bones:
            simple = bone.name.replace('mixamorig:', '').replace('mixamorig_', '')
            if simple in BONE_MAP:
                bones[bone.name] = (BONE_MAP[simple], rig.matrix_world @ bone.head_local,
                    rig.matrix_world @ bone.tail_local)
        originals[name] = dict(vertices=[obj.matrix_world @ v.co for v in obj.data.vertices],
            weights=[[(obj.vertex_groups[g.group].name, g.weight) for g in v.groups]
                for v in obj.data.vertices], bones=bones)
    bpy.ops.wm.open_mainfile(filepath=str(args.base.resolve()), load_ui=False)
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    weight_source = next(o for o in bpy.context.scene.objects if o.name.endswith('_WeightSource'))
    target_bones = {b.name: (rig.matrix_world @ b.head_local,
        rig.matrix_world @ b.tail_local) for b in rig.data.bones}
    body_surface = BVHTree.FromPolygons(
        [weight_source.matrix_world @ v.co for v in weight_source.data.vertices],
        [list(p.vertices) for p in weight_source.data.polygons])
    report = {'status': 'UNAPPROVED_AUTOMATIC_FIT', 'garments': []}
    for name, original in originals.items():
        with bpy.data.libraries.load(str(args.source.resolve()), link=False) as (src, dst):
            dst.objects = [name]
        garment = dst.objects[0]
        bpy.data.collections['03_CLOTHING'].objects.link(garment)
        garment.parent = None
        garment.matrix_world = Matrix.Identity(4)
        garment.modifiers.clear()
        # Align anatomical landmarks without inheriting bone roll differences.
        pairs = [(head, target_bones[new][0]) for new, head, tail in original['bones'].values()
            if new in target_bones]
        a, b = np.array([list(x) for x, _ in pairs]), np.array([list(y) for _, y in pairs])
        ac, bc = a.mean(axis=0), b.mean(axis=0)
        u, singular, vt = np.linalg.svd((a-ac).T @ (b-bc))
        rotation = vt.T @ u.T
        if np.linalg.det(rotation) < 0:
            vt[-1] *= -1
            rotation = vt.T @ u.T
        scale = np.sqrt(np.square(b-bc).sum() / np.square(a-ac).sum())
        rotate = Matrix(rotation.tolist())
        transforms = {}
        for old, (new, head, tail) in original['bones'].items():
            th, tt = target_bones[new]
            vector = rotate @ (tail-head)
            swing = vector.rotation_difference(tt-th)
            transforms[old] = (head, th, swing)
        unmapped = 0
        for vertex, point, groups in zip(garment.data.vertices, original['vertices'], original['weights']):
            influences = [(transforms[g], w) for g, w in groups if g in transforms and w > 0]
            total = sum(w for _, w in influences)
            if total <= 0:
                unmapped += 1
                vertex.co = rotate @ (point-Vector(ac)) * scale + Vector(bc)
            else:
                vertex.co = sum(((th + swing @ (rotate @ (point-head) * scale)) * (w/total)
                    for (head, th, swing), w in influences), Vector())
        corrected = 0
        clearance = 0.006 if name.startswith('BOTTOM') else 0.009
        for vertex in garment.data.vertices:
            nearest, normal, face, distance = body_surface.find_nearest(vertex.co)
            if nearest is not None and (vertex.co - nearest).dot(normal) < clearance:
                vertex.co = nearest + normal * clearance
                corrected += 1
        garment.vertex_groups.clear()
        garment.hide_set(False)
        garment.hide_viewport = False
        garment.hide_render = False
        bpy.ops.object.select_all(action='DESELECT')
        garment.select_set(True)
        bpy.context.view_layer.objects.active = garment
        transfer = garment.modifiers.new('V2_COMPLETE_BODY_WEIGHTS', 'DATA_TRANSFER')
        transfer.object = weight_source
        transfer.use_vert_data = True
        transfer.data_types_verts = {'VGROUP_WEIGHTS'}
        transfer.vert_mapping = 'POLYINTERP_NEAREST'
        bpy.ops.object.datalayout_transfer(modifier=transfer.name)
        bpy.ops.object.modifier_apply(modifier=transfer.name)
        bpy.ops.object.vertex_group_limit_total(limit=4)
        bpy.ops.object.vertex_group_normalize_all(lock_active=False)
        modifier = garment.modifiers.new('V2_Armature', 'ARMATURE')
        modifier.object = rig
        # Neutral stylized material for fit review; final graphics remain pending.
        material = bpy.data.materials.new('V2_FitReview_' + name)
        material.diffuse_color = (0.12, 0.28, 0.42, 1) if name.startswith('TOP') else (0.08, 0.09, 0.12, 1)
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value = material.diffuse_color
        bsdf.inputs['Roughness'].default_value = 0.8
        garment.data.materials.clear()
        garment.data.materials.append(material)
        garment['fb_validation_status'] = 'UNAPPROVED_AUTOMATIC_FIT'
        report['garments'].append(dict(name=name, fallback_vertices=unmapped,
            body_clearance_corrections=corrected,
            unweighted=sum(not v.groups for v in garment.data.vertices)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output.resolve()), check_existing=False)
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('V2_FIT_CHECKPOINT_SAVED', json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
