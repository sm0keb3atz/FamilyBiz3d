bl_info = {
    "name": "Family Business Clothing Setup",
    "author": "Family Business",
    "version": (1, 0, 0),
    "blender": (4, 3, 0),
    "location": "3D View > Sidebar > FB Clothing",
    "description": "Prepare a sculpted garment for the modular character rig",
    "category": "Rigging",
}

import os
import re

import bpy
from bpy.props import EnumProperty, IntProperty, StringProperty


RIG_NAME = "CHR_Armature"
SLOT_SETTINGS = {
    "TOP": {
        "collection": "02_TOPS",
        "sources": ("TOP_01_Hoodie", "BODY_Torso"),
    },
    "BOTTOM": {
        "collection": "03_BOTTOMS",
        "sources": ("BOTTOM_01_Jeans", "BODY_Legs"),
    },
    "SHOES": {
        "collection": "04_SHOES",
        "sources": ("SHOES_01_Sneakers", "BODY_Feet"),
    },
}


def clean_description(value):
    words = re.findall(r"[A-Za-z0-9]+", value)
    return "".join(word[:1].upper() + word[1:] for word in words)


def find_weight_source(slot):
    for object_name in SLOT_SETTINGS[slot]["sources"]:
        source = bpy.data.objects.get(object_name)
        if source and source.type == "MESH":
            return source
    return None


def move_to_collection(obj, collection_name):
    collection = bpy.data.collections.get(collection_name)
    if collection is None:
        raise RuntimeError("Missing collection: " + collection_name)

    for old_collection in tuple(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)


def make_active(obj):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def remove_existing_rig_data(obj):
    for modifier in tuple(obj.modifiers):
        if modifier.type in {"ARMATURE", "DATA_TRANSFER"}:
            obj.modifiers.remove(modifier)
    obj.vertex_groups.clear()


def transfer_weights(obj, source, rig):
    armature_modifier = obj.modifiers.new("FB_Armature", "ARMATURE")
    armature_modifier.object = rig
    armature_modifier.use_deform_preserve_volume = True

    transfer = obj.modifiers.new("FB_TransferWeights_TEMP", "DATA_TRANSFER")
    transfer.object = source
    transfer.use_vert_data = True
    transfer.data_types_verts = {"VGROUP_WEIGHTS"}
    transfer.vert_mapping = "POLYINTERP_NEAREST"
    transfer.mix_mode = "REPLACE"
    transfer.mix_factor = 1.0

    make_active(obj)
    bpy.ops.object.modifier_apply(modifier=transfer.name)

    bone_names = {bone.name for bone in rig.data.bones}
    for group in tuple(obj.vertex_groups):
        if group.name not in bone_names:
            obj.vertex_groups.remove(group)

    bpy.ops.object.vertex_group_clean(
        group_select_mode="ALL",
        limit=0.0001,
        keep_single=True,
    )
    bpy.ops.object.vertex_group_limit_total(
        group_select_mode="ALL",
        limit=4,
    )
    bpy.ops.object.vertex_group_normalize_all(
        group_select_mode="ALL",
        lock_active=False,
    )


def load_image(path):
    absolute_path = bpy.path.abspath(path)
    if not path or not os.path.isfile(absolute_path):
        return None
    return bpy.data.images.load(absolute_path, check_existing=True)


def create_image_node(nodes, image, label, location, non_color=False):
    node = nodes.new("ShaderNodeTexImage")
    node.image = image
    node.label = label
    node.name = label
    node.location = location
    if non_color:
        image.colorspace_settings.name = "Non-Color"
    return node


def build_material(obj, material_name, base_path, normal_path, orm_path):
    material = bpy.data.materials.get(material_name)
    if material is None:
        material = bpy.data.materials.new(material_name)
    material.use_nodes = True

    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (700, 0)
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.location = (400, 0)
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])

    base_image = load_image(base_path)
    normal_image = load_image(normal_path)
    orm_image = load_image(orm_path)

    base_node = None
    if base_image:
        base_node = create_image_node(
            nodes, base_image, "Base Color", (-700, 180)
        )
        links.new(base_node.outputs["Color"], shader.inputs["Base Color"])

    if normal_image:
        normal_node = create_image_node(
            nodes, normal_image, "Normal", (-700, -80), True
        )
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.location = (100, -100)
        links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])

    if orm_image:
        orm_node = create_image_node(
            nodes, orm_image, "ORM", (-700, -360), True
        )
        separate = nodes.new("ShaderNodeSeparateColor")
        separate.location = (-350, -360)
        links.new(orm_node.outputs["Color"], separate.inputs["Color"])
        links.new(separate.outputs["Green"], shader.inputs["Roughness"])
        links.new(separate.outputs["Blue"], shader.inputs["Metallic"])

        if base_node:
            multiply = nodes.new("ShaderNodeMixRGB")
            multiply.blend_type = "MULTIPLY"
            multiply.inputs["Fac"].default_value = 1.0
            multiply.location = (80, 160)
            links.remove(shader.inputs["Base Color"].links[0])
            links.new(base_node.outputs["Color"], multiply.inputs[1])
            links.new(separate.outputs["Red"], multiply.inputs[2])
            links.new(multiply.outputs["Color"], shader.inputs["Base Color"])

    obj.data.materials.clear()
    obj.data.materials.append(material)
    return material


class FB_OT_setup_clothing(bpy.types.Operator):
    bl_idname = "fb.setup_clothing"
    bl_label = "Prepare Selected Garment"
    bl_description = "Name, organize, rig, weight, and material the selected garment"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        scene = context.scene
        garment = context.active_object
        rig = bpy.data.objects.get(RIG_NAME)

        if garment is None or garment.type != "MESH":
            self.report({"ERROR"}, "Select one garment mesh first")
            return {"CANCELLED"}
        if garment.name.startswith(("BODY_", "TOP_", "BOTTOM_", "SHOES_")):
            self.report(
                {"ERROR"},
                "Select the newly imported garment, not an existing character mesh",
            )
            return {"CANCELLED"}
        if rig is None or rig.type != "ARMATURE":
            self.report({"ERROR"}, "CHR_Armature was not found")
            return {"CANCELLED"}

        slot = scene.fb_clothing_slot
        description = clean_description(scene.fb_clothing_description)
        if not description:
            self.report({"ERROR"}, "Enter a garment description")
            return {"CANCELLED"}

        object_name = "{}_{:02d}_{}".format(
            slot,
            scene.fb_clothing_option_id,
            description,
        )
        if bpy.data.objects.get(object_name) not in {None, garment}:
            self.report({"ERROR"}, object_name + " already exists")
            return {"CANCELLED"}

        source = find_weight_source(slot)
        if source is None:
            self.report({"ERROR"}, "No compatible weight source was found")
            return {"CANCELLED"}

        make_active(garment)
        bpy.ops.object.transform_apply(
            location=False,
            rotation=True,
            scale=True,
        )

        garment.name = object_name
        garment.data.name = "MESH_" + object_name
        move_to_collection(
            garment,
            SLOT_SETTINGS[slot]["collection"],
        )

        remove_existing_rig_data(garment)
        transfer_weights(garment, source, rig)

        material_name = "MAT_" + object_name
        build_material(
            garment,
            material_name,
            scene.fb_base_color_path,
            scene.fb_normal_path,
            scene.fb_orm_path,
        )

        garment["fb_slot"] = slot
        garment["fb_option_id"] = scene.fb_clothing_option_id
        garment["fb_weight_source"] = source.name
        garment["fb_setup_complete"] = True

        self.report(
            {"INFO"},
            "{} prepared using weights from {}".format(
                object_name,
                source.name,
            ),
        )
        return {"FINISHED"}


class FB_PT_clothing_setup(bpy.types.Panel):
    bl_label = "FB Clothing Setup"
    bl_idname = "FB_PT_clothing_setup"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "FB Clothing"

    def draw(self, context):
        layout = self.layout
        scene = context.scene

        garment = context.active_object
        if garment and garment.type == "MESH":
            layout.label(text="Selected: " + garment.name, icon="MESH_DATA")
        else:
            layout.label(text="Select a garment mesh", icon="ERROR")

        layout.prop(scene, "fb_clothing_slot")
        layout.prop(scene, "fb_clothing_option_id")
        layout.prop(scene, "fb_clothing_description")

        box = layout.box()
        box.label(text="Optional Textures")
        box.prop(scene, "fb_base_color_path")
        box.prop(scene, "fb_normal_path")
        box.prop(scene, "fb_orm_path")

        layout.separator()
        layout.operator(
            FB_OT_setup_clothing.bl_idname,
            icon="MOD_DATA_TRANSFER",
        )
        layout.label(text="Then test animations and weight paint.")


CLASSES = (
    FB_OT_setup_clothing,
    FB_PT_clothing_setup,
)


def register():
    for cls in CLASSES:
        bpy.utils.register_class(cls)

    bpy.types.Scene.fb_clothing_slot = EnumProperty(
        name="Slot",
        items=(
            ("TOP", "Top", "Prepare a top"),
            ("BOTTOM", "Bottom", "Prepare bottoms"),
            ("SHOES", "Shoes", "Prepare shoes"),
        ),
        default="TOP",
    )
    bpy.types.Scene.fb_clothing_option_id = IntProperty(
        name="Option Number",
        default=2,
        min=1,
        max=99,
    )
    bpy.types.Scene.fb_clothing_description = StringProperty(
        name="Description",
        default="Jacket",
    )
    bpy.types.Scene.fb_base_color_path = StringProperty(
        name="Base Color",
        subtype="FILE_PATH",
    )
    bpy.types.Scene.fb_normal_path = StringProperty(
        name="Normal",
        subtype="FILE_PATH",
    )
    bpy.types.Scene.fb_orm_path = StringProperty(
        name="ORM",
        subtype="FILE_PATH",
    )


def unregister():
    del bpy.types.Scene.fb_orm_path
    del bpy.types.Scene.fb_normal_path
    del bpy.types.Scene.fb_base_color_path
    del bpy.types.Scene.fb_clothing_description
    del bpy.types.Scene.fb_clothing_option_id
    del bpy.types.Scene.fb_clothing_slot

    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
