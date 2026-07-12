"""Export the original male body and its UV layout for texture-authoring tools."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy


def main() -> None:
    if "--" not in sys.argv:
        raise RuntimeError("Expected output directory after --")
    output_dir = Path(sys.argv[sys.argv.index("--") + 1])
    output_dir.mkdir(parents=True, exist_ok=True)

    source = bpy.data.objects.get("BODY_Source")
    if source is None:
        raise RuntimeError("Missing BODY_Source")
    if not source.data.uv_layers.get("Retopo_Untitled_NewUVMap"):
        raise RuntimeError("Original male UV map is missing")

    texture_path = Path(
        "C:/Users/smo0o/OneDrive/Documents/family-biz-prototype/"
        "Assets/BaseChracters/Player/Textures/Body.png"
    )
    normal_path = Path(
        "C:/Users/smo0o/OneDrive/Documents/family-biz-prototype/"
        "Assets/BaseChracters/Player/Textures/BodyN.png"
    )
    if not texture_path.exists() or not normal_path.exists():
        raise RuntimeError("Body 1 texture files are missing")

    # Work entirely with a temporary duplicate: the Blender master is unchanged.
    mesh_copy = source.copy()
    mesh_copy.data = source.data.copy()
    bpy.context.collection.objects.link(mesh_copy)
    mesh_copy.name = "FB_Male_Body_Texture_Source"
    mesh_copy.data.name = "MESH_FB_Male_Body_Texture_Source"
    world_matrix = mesh_copy.matrix_world.copy()
    mesh_copy.parent = None
    mesh_copy.matrix_world = world_matrix
    for modifier in list(mesh_copy.modifiers):
        mesh_copy.modifiers.remove(modifier)
    mesh_copy.hide_set(False)
    mesh_copy.hide_render = False

    material = bpy.data.materials.new("MAT_FB_Male_Body_Texture_Source")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    color = nodes.new("ShaderNodeTexImage")
    color.name = "Body 1 Base Color"
    color.image = bpy.data.images.load(str(texture_path), check_existing=True)
    normal_image = nodes.new("ShaderNodeTexImage")
    normal_image.name = "Body 1 Normal"
    normal_image.image = bpy.data.images.load(str(normal_path), check_existing=True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(color.outputs["Color"], principled.inputs["Base Color"])
    links.new(normal_image.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], principled.inputs["Normal"])
    mesh_copy.data.materials.clear()
    mesh_copy.data.materials.append(material)
    mesh_copy["texture_workflow"] = "Keep Retopo_Untitled_NewUVMap; do not remesh or unwrap."
    mesh_copy["texture_source"] = "Body Texture 01 (Body.png)"

    bpy.ops.object.select_all(action="DESELECT")
    mesh_copy.select_set(True)
    bpy.context.view_layer.objects.active = mesh_copy
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.export_layout(
        filepath=str(output_dir / "FB_Male_Body_Original_UV_Layout.svg"),
        export_all=True,
        modified=False,
        mode="SVG",
        size=(2048, 2048),
        opacity=0.35,
    )
    bpy.ops.object.mode_set(mode="OBJECT")

    bpy.ops.object.select_all(action="DESELECT")
    mesh_copy.select_set(True)
    bpy.context.view_layer.objects.active = mesh_copy
    bpy.ops.export_scene.gltf(
        filepath=str(output_dir / "FB_Male_Body_Texture_Source.glb"),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_skins=False,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
    )

    bpy.data.objects.remove(mesh_copy, do_unlink=True)
    bpy.data.materials.remove(material, do_unlink=True)
    print("MALE_TEXTURE_KIT_EXPORT_PASS")


if __name__ == "__main__":
    main()
