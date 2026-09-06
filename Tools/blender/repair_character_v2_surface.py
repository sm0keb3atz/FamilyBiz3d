"""Non-destructive surface-repair candidate for the regular male review outfit.

Keeps source UVs and rig, welds coincident vertices, relaxes hoodie irregularities,
restores body clearance, and widens the sneaker toe boxes. Requires visual review.
"""
import json
import sys
from pathlib import Path
import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

out = Path(sys.argv[sys.argv.index('--')+1]).resolve()
if out.exists():
    raise RuntimeError('Refusing to overwrite surface repair output')
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
source = next(o for o in bpy.data.objects if o.name == 'BODY_regular_male_WeightSource')
surface = BVHTree.FromPolygons([source.matrix_world @ v.co for v in source.data.vertices],
                              [list(p.vertices) for p in source.data.polygons])
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
report = {'status': 'UNAPPROVED_SURFACE_REPAIR', 'input': bpy.data.filepath, 'garments': []}
for name in ['TOP_01_Hoodie', 'BOTTOM_01_Jeans', 'SHOES_01_Sneakers']:
    obj = bpy.data.objects[name]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
    joined = before-len(bm.verts)
    if name.startswith('TOP'):
        # Small relaxation steps followed by collision clearance preserve volume
        # better than the unconstrained Smooth brush at the waist.
        for iteration in range(8):
            targets = {}
            for v in bm.verts:
                if not v.link_edges or v.is_boundary:
                    continue
                center = sum((e.other_vert(v).co for e in v.link_edges), Vector())/len(v.link_edges)
                targets[v] = v.co.lerp(center, 0.2)
            for v, co in targets.items():
                world = obj.matrix_world @ co
                nearest, normal, face, distance = surface.find_nearest(world)
                if nearest is not None and (world-nearest).dot(normal) < 0.012:
                    world = nearest + normal*0.012
                v.co = obj.matrix_world.inverted() @ world
    if name.startswith('SHOES'):
        for v in bm.verts:
            # Restrict expansion to the low toe box, preserving ankle openings.
            world = obj.matrix_world @ v.co
            factor = max(0.0, min(1.0, (0.14-world.z)/0.06))
            foot = rig.data.bones['foot_l' if world.x >= 0 else 'foot_r']
            center = rig.matrix_world @ foot.head_local
            world.x = center.x + (world.x-center.x)*(1+0.13*factor)
            world.y = center.y + (world.y-center.y)*(1+0.13*factor)
            v.co = obj.matrix_world.inverted() @ world
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    # Refresh weights from the complete undeformed body after geometry edits.
    obj.modifiers.clear()
    obj.vertex_groups.clear()
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    transfer = obj.modifiers.new('Complete undeformed body transfer', 'DATA_TRANSFER')
    transfer.object = source
    transfer.use_vert_data = True
    transfer.data_types_verts = {'VGROUP_WEIGHTS'}
    transfer.vert_mapping = 'POLYINTERP_NEAREST'
    bpy.ops.object.datalayout_transfer(modifier=transfer.name)
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    obj.modifiers.new('V2_Armature', 'ARMATURE').object = rig
    obj['fb_validation_status'] = 'UNAPPROVED_SURFACE_REPAIR'
    report['garments'].append({'name': name, 'joined_vertices': joined,
                               'unweighted': sum(not v.groups for v in obj.data.vertices)})
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out), check_existing=False)
out.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('SURFACE_REPAIR_CANDIDATE', json.dumps(report), flush=True)
