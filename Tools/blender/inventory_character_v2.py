"""Read-only source inspection. Run in Blender with -- --output report.json roots...

Never saves a Blender source. Reports geometry, full rig rest matrices, modifiers,
actions and missing image dependencies so source selection is evidence based.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def inspect(path):
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False)
    meshes = []
    rigs = []
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            meshes.append(dict(
                name=obj.name, vertices=len(obj.data.vertices),
                polygons=len(obj.data.polygons),
                dimensions=list(obj.dimensions), scale=list(obj.scale),
                groups=[g.name for g in obj.vertex_groups],
                materials=[m.name if m else None for m in obj.data.materials],
                modifiers=[dict(type=m.type, name=m.name,
                    target=getattr(getattr(m, 'object', None), 'name', None))
                    for m in obj.modifiers],
                unweighted=sum(not v.groups for v in obj.data.vertices),
            ))
        elif obj.type == 'ARMATURE':
            rigs.append(dict(name=obj.name, scale=list(obj.scale), bones=[dict(
                name=b.name, parent=b.parent.name if b.parent else None,
                rest=[list(row) for row in b.matrix_local], deform=b.use_deform
            ) for b in obj.data.bones]))
    return dict(path=str(path), sha256=digest(path), meshes=meshes, rigs=rigs,
        actions=[a.name for a in bpy.data.actions],
        images=[dict(name=i.name, path=i.filepath, packed=bool(i.packed_file),
            missing=bool(i.filepath and not i.packed_file and
                not Path(bpy.path.abspath(i.filepath)).exists()))
            for i in bpy.data.images if i.source == 'FILE'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('roots', nargs='+')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    paths = set()
    for root in map(Path, args.roots):
        if root.is_file():
            paths.add(root.resolve())
        else:
            paths.update(p.resolve() for p in root.rglob('*')
                if p.is_file() and p.suffix.lower() in ('.blend', '.blend1', '.blend2'))
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    report = dict(sources=[], errors=[])
    for path in sorted(paths):
        try:
            entry = inspect(path)
            report['sources'].append(entry)
            print('INVENTORY_OK', path.name, len(entry['meshes']), 'meshes', flush=True)
        except Exception as error:
            report['errors'].append(dict(path=str(path), error=str(error)))
        output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    if report['errors']:
        raise RuntimeError('Source inventory incomplete; see report errors')


if __name__ == '__main__':
    main()
