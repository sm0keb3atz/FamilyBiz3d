import os
import sys
import bpy


EXPORT_PATH = sys.argv[-1]


def is_export_object(obj):
    if obj.name == "CHR_Armature":
        return True
    if obj.type != "MESH":
        return False
    return (
        obj.name.startswith("BODY_")
        or obj.name.startswith("TOP_")
        or obj.name.startswith("BOTTOM_")
        or obj.name.startswith("SHOES_")
        or obj.name.startswith("HAIR_")
    )


if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
for obj in bpy.context.scene.objects:
    if is_export_object(obj):
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)

os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=EXPORT_PATH,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
    export_skins=True,
    export_morph=True,
)
print("FB_TEMP_EXPORT:", EXPORT_PATH)
