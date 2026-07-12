import math
import bpy


MASTER_RIG_NAME = "CHR_Armature"
CHARACTER_PREFIXES = ("BODY_", "HAIR_", "TOP_", "BOTTOM_", "SHOES_")


def log(message: str) -> None:
    print(f"[FB mesh orientation fix] {message}")


def main():
    rig = bpy.data.objects.get(MASTER_RIG_NAME)
    if not rig:
        raise RuntimeError(f"Missing {MASTER_RIG_NAME}")

    # The armature object must stay export-friendly.
    rig.location = (0, 0, 0)
    rig.rotation_euler = (0, 0, 0)
    rig.scale = (0.01, 0.01, 0.01)

    log("Restoring Blender display orientation on character meshes...")
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if not obj.name.startswith(CHARACTER_PREFIXES):
            continue

        obj.location = (0, 0, 0)
        obj.rotation_euler = (math.radians(90), 0, 0)
        obj.scale = (1, 1, 1)
        obj.parent = rig
        obj.matrix_parent_inverse.identity()

        armature_mods = [mod for mod in obj.modifiers if mod.type == "ARMATURE"]
        if not armature_mods:
            armature_mods = [obj.modifiers.new("Armature", "ARMATURE")]
        armature_mods[0].name = "Armature"
        armature_mods[0].object = rig
        for extra in armature_mods[1:]:
            obj.modifiers.remove(extra)

    # Reference arms are not part of the working body; keep them hidden if they exist.
    for ref_name in ("LeftArm", "RightArm", "ParentNode"):
        ref = bpy.data.objects.get(ref_name)
        if ref:
            ref.hide_viewport = True
            ref.hide_render = True

    feet = bpy.data.objects.get("BODY_Feet")
    if feet:
        # BODY_Legs contains the full visible lower body now.
        feet.hide_viewport = True
        feet.hide_render = True

    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    log("Done.")


if __name__ == "__main__":
    main()
