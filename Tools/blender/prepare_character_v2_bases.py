"""Create isolated V2 body masters and GLBs from the inventoried vendor pack.

blender --background --factory-startup --disable-autoexec --python this.py --
    --pack <vendor directory> --output <new authoring directory>

Outputs are staging assets, not approved runtime replacements. Existing output
masters are never overwritten. Vendor sources are never saved.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy


PROFILES = {
    'regular_male': ('Regular_Male_FullBody.blend', 'RegularMale'),
    'regular_female': ('Regular_Female_FullBody.blend', 'Female_Regular'),
    'teen_male': ('Teen_Male_FullBody.blend', 'Teen_Male'),
    'teen_female': ('Teen_Female_FullBody.blend', 'Teen_Female'),
    'superhero_male': ('Superhero_Male_FullBody.blend', 'SuperHero_Male'),
    'superhero_female': ('Superhero_Female_FullBody.blend', 'Superhero_Female'),
}


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def relocate(obj, destination):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    destination.objects.link(obj)


def prepare(pack, output, profile, filename, body_name):
    source = pack / 'Base Characters' / filename
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False)
    body = bpy.data.objects[body_name]
    rig = next(m.object for m in body.modifiers if m.type == 'ARMATURE' and m.object)
    keep = {body, rig, bpy.data.objects['Eyes'], bpy.data.objects['Eyebrows']}
    # Rigify display widgets and unused authoring objects must not enter exports.
    for bone in rig.pose.bones:
        bone.custom_shape = None
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    rig.animation_data_clear()
    rig.data.pose_position = 'REST'
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    export_collection = collection('01_EXPORT_' + profile)
    for obj in keep:
        for modifier in list(obj.modifiers):
            if modifier.type == 'ARMATURE' and modifier.object is None:
                obj.modifiers.remove(modifier)
        relocate(obj, export_collection)
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
    body.name = 'BODY_' + profile
    rig.name = 'RIG_' + profile
    for name in ('03_CLOTHING', '04_HAIR', '05_POSE_TESTS'):
        collection(name)
    weights = collection('02_WEIGHT_SOURCE')
    weight_source = body.copy()
    weight_source.data = body.data.copy()
    weight_source.name = 'BODY_' + profile + '_WeightSource'
    weights.objects.link(weight_source)
    weight_source.modifiers.clear()
    weight_source.hide_render = True
    weight_source.hide_set(True)
    weights.hide_render = True
    body['fb_body_profile'] = profile
    body['fb_source_file'] = str(source)
    body['fb_validation_status'] = 'base_only_clothing_and_animation_pending'
    # Pack used images so the new source master is independent of vendor paths.
    missing = []
    used_images = set()
    for obj in keep:
        if obj.type != 'MESH':
            continue
        for material in obj.data.materials:
            if material and material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type == 'TEX_IMAGE' and node.image:
                        used_images.add(node.image)
    for image in used_images:
        if image.source == 'FILE' and not image.packed_file:
            if Path(bpy.path.abspath(image.filepath)).exists():
                image.pack()
            else:
                missing.append(image.filepath)
    if missing:
        raise RuntimeError('Missing used textures: ' + repr(missing))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in keep:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.context.view_layer.update()
    destination = output / profile
    destination.mkdir(parents=True, exist_ok=True)
    master = destination / ('FB_' + profile + '_Master.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(master), check_existing=False)
    bpy.ops.export_scene.gltf(filepath=str(destination / (profile + '.glb')),
        export_format='GLB', use_selection=True, export_animations=False,
        export_skins=True, export_yup=True, export_cameras=False,
        export_lights=False)
    signature = [dict(name=b.name, parent=b.parent.name if b.parent else None,
        rest=[list(row) for row in b.matrix_local]) for b in rig.data.bones]
    return dict(id=profile, source=str(source), master=str(master),
        status='base_only_clothing_and_animation_pending',
        height=float(body.dimensions.z), vertices=len(body.data.vertices),
        rig_signature=hashlib.sha256(json.dumps(signature, sort_keys=True).encode()).hexdigest(),
        bones=signature, missing_used_textures=missing)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pack', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--profile', choices=PROFILES)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    output = args.output.resolve()
    if not args.profile and output.exists() and any(output.iterdir()):
        raise RuntimeError('Choose an empty output directory; authoring work is never overwritten')
    output.mkdir(parents=True, exist_ok=True)
    report_path = output / 'manifest.json'
    report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {'status': 'staging', 'profiles': []}
    for profile, (filename, body_name) in PROFILES.items():
        if args.profile and profile != args.profile:
            continue
        if (output / profile).exists():
            raise RuntimeError('Profile already exists; refusing to overwrite ' + profile)
        report['profiles'].append(prepare(args.pack.resolve(), output, profile, filename, body_name))
        (output / 'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print('V2_BASE_PREPARED', profile, flush=True)


if __name__ == '__main__':
    main()
