bl_info = {
    "name": "Family Business Clothing Setup",
    "author": "Family Business",
    "version": (1, 2, 2),
    "blender": (4, 3, 0),
    "location": "3D View > Sidebar > FB Clothing",
    "description": "Prepare a sculpted garment for the modular character rig",
    "category": "Rigging",
}

import os
import re

import bpy
from bpy.props import EnumProperty, IntProperty, StringProperty


RIG_NAMES = ("CHR_Armature", "CHR_Female_Armature", "Armature")
DEFAULT_EXPORT_PATH = (
    "C:/Users/smo0o/OneDrive/Documents/family-biz-prototype/"
    "Assets/BaseChracters/Player/Working/FB_Character_Working.glb"
)
BODY_EXPORT_NAMES = {
    "BODY_Head",
    "BODY_Hands",
    "BODY_Torso",
    "BODY_Legs",
    "BODY_Feet",
    "BODY_Female_Head",
    "BODY_Female_Torso",
    "BODY_Female_LeftArm",
    "BODY_Female_RightArm",
    "BODY_Female_Legs",
}
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
    "HAIR": {
        "collection": "05_HAIR",
        "sources": ("HAIR_01_Short", "BODY_Head"),
    },
}
FIT_SOURCES = {
    "MALE": {
        "TOP": ("TOP_01_Hoodie", "BODY_Torso"),
        "BOTTOM": ("BOTTOM_01_Jeans", "BODY_Legs"),
        "SHOES": ("SHOES_01_Sneakers", "BODY_Feet"),
        "HAIR": ("HAIR_01_Short", "BODY_Head"),
    },
    "FEMALE": {
        "TOP": ("BODY_Female_WeightSource",),
        "BOTTOM": ("BODY_Female_WeightSource",),
        "SHOES": ("BODY_Female_WeightSource",),
        "HAIR": ("BODY_Female_WeightSource",),
    },
}
FEMALE_BODY_PARTS = (
    ("BODY_Female_Head", "Head"),
    ("BODY_Female_Torso", "Torso"),
    ("BODY_Female_LeftArm", "LeftArm"),
    ("BODY_Female_RightArm", "RightArm"),
    ("BODY_Female_Legs", "Legs"),
)


def clean_description(value):
    words = re.findall(r"[A-Za-z0-9]+", value)
    return "".join(word[:1].upper() + word[1:] for word in words)


def find_rig(fit_profile=None):
    names = RIG_NAMES
    if fit_profile == "FEMALE":
        names = ("CHR_Female_Armature", "CHR_Armature", "Armature")
    elif fit_profile == "MALE":
        names = ("CHR_Armature", "CHR_Female_Armature", "Armature")
    for name in names:
        rig = bpy.data.objects.get(name)
        if rig and rig.type == "ARMATURE":
            return rig
    return None


def find_weight_source(slot, fit_profile):
    if fit_profile == "FEMALE":
        source = ensure_female_weight_source()
        if source is not None:
            return source
    for object_name in FIT_SOURCES[fit_profile][slot]:
        source = bpy.data.objects.get(object_name)
        if source and source.type == "MESH":
            return source
    return None


def ensure_female_weight_source():
    existing = bpy.data.objects.get("BODY_Female_WeightSource")
    if existing and existing.type == "MESH":
        required = {"mixamorig:LeftForeArm", "mixamorig:RightForeArm"}
        if not existing.modifiers and required.issubset(
            {group.name for group in existing.vertex_groups}
        ):
            return existing
        bpy.data.objects.remove(existing, do_unlink=True)

    parts = []
    for candidates in FEMALE_BODY_PARTS:
        part = next(
            (
                bpy.data.objects.get(name)
                for name in candidates
                if bpy.data.objects.get(name) is not None
            ),
            None,
        )
        if part is None or part.type != "MESH":
            return None
        parts.append(part)

    # Create an invisible, joined copy of the complete female body. It exists
    # only as a nearest-surface weight-transfer source, so sleeves find arm
    # weights instead of borrowing weights from the torso or legs.
    duplicates = []
    for part in parts:
        copy = part.copy()
        copy.data = part.data.copy()
        # Sample the body's rest geometry, not its current animated pose.
        copy.modifiers.clear()
        bpy.context.scene.collection.objects.link(copy)
        duplicates.append(copy)
    make_active(duplicates[0])
    for duplicate in duplicates[1:]:
        duplicate.select_set(True)
    bpy.ops.object.join()
    source = bpy.context.active_object
    source.name = "BODY_Female_WeightSource"
    source.data.name = "MESH_BODY_Female_WeightSource"
    source.hide_set(True)
    source.hide_render = True
    move_to_collection(source, "90_REFERENCE")
    return source


def move_to_collection(obj, collection_name):
    collection = bpy.data.collections.get(collection_name)
    if collection is None:
        collection = bpy.data.collections.new(collection_name)
        bpy.context.scene.collection.children.link(collection)

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
    # Blender's Data Transfer modifier is more reliable when the destination
    # already has matching vertex group names. Without this, brand-new imported
    # garments can finish the transfer with zero groups, and Blender then errors
    # during vertex_group_clean().
    for source_group in source.vertex_groups:
        if obj.vertex_groups.get(source_group.name) is None:
            obj.vertex_groups.new(name=source_group.name)

    transfer = obj.modifiers.new("FB_TransferWeights_TEMP", "DATA_TRANSFER")
    transfer.object = source
    transfer.use_vert_data = True
    transfer.data_types_verts = {"VGROUP_WEIGHTS"}
    transfer.vert_mapping = "POLYINTERP_NEAREST"
    transfer.mix_mode = "REPLACE"
    transfer.mix_factor = 1.0

    make_active(obj)
    bpy.ops.object.modifier_apply(modifier=transfer.name)

    # Skin after transfer so Blender samples the garment in rest space.
    armature_modifier = obj.modifiers.new("FB_Armature", "ARMATURE")
    armature_modifier.object = rig
    armature_modifier.use_deform_preserve_volume = True

    bone_names = {bone.name for bone in rig.data.bones}
    for group in tuple(obj.vertex_groups):
        if group.name not in bone_names:
            obj.vertex_groups.remove(group)

    if not obj.vertex_groups:
        raise RuntimeError(
            "No vertex groups were transferred. Check that the garment is close "
            "to the body source before preparing it."
        )

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


def is_export_object(obj):
    if obj.type == "ARMATURE" and obj.name in RIG_NAMES:
        return True
    if obj.type != "MESH":
        return False
    return (
        obj.name in BODY_EXPORT_NAMES
        or obj.name.startswith("TOP_")
        or obj.name.startswith("BOTTOM_")
        or obj.name.startswith("SHOES_")
        or obj.name.startswith("HAIR_")
    )


def garment_object_name(slot, fit_profile, option_id, description):
    if fit_profile == "FEMALE":
        return "{}_Female_{:02d}_{}".format(slot, option_id, description)
    return "{}_{:02d}_{}".format(slot, option_id, description)


def validate_export_objects(objects, rig):
    errors = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        armature_modifiers = [
            modifier
            for modifier in obj.modifiers
            if modifier.type == "ARMATURE"
        ]
        if len(armature_modifiers) != 1:
            errors.append(
                "{} needs exactly one Armature modifier".format(obj.name)
            )
        elif armature_modifiers[0].object != rig:
            errors.append(
                    "{} Armature modifier must target {}".format(
                        obj.name,
                    rig.name,
                )
            )
    return errors


class FB_OT_setup_clothing(bpy.types.Operator):
    bl_idname = "fb.setup_clothing"
    bl_label = "Prepare Selected Garment"
    bl_description = "Name, organize, rig, weight, and material the selected garment"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        scene = context.scene
        garment = context.active_object
        rig = find_rig(scene.fb_clothing_fit_profile)

        if garment is None or garment.type != "MESH":
            self.report({"ERROR"}, "Select one garment mesh first")
            return {"CANCELLED"}
        if garment.name.startswith((
            "BODY_",
            "TOP_",
            "BOTTOM_",
            "SHOES_",
            "HAIR_",
        )):
            self.report(
                {"ERROR"},
                "Select the newly imported garment, not an existing character mesh",
            )
            return {"CANCELLED"}
        if rig is None or rig.type != "ARMATURE":
            self.report({"ERROR"}, "No compatible character armature was found")
            return {"CANCELLED"}

        slot = scene.fb_clothing_slot
        description = clean_description(scene.fb_clothing_description)
        if not description:
            self.report({"ERROR"}, "Enter a garment description")
            return {"CANCELLED"}

        fit_profile = scene.fb_clothing_fit_profile
        object_name = garment_object_name(
            slot, fit_profile, scene.fb_clothing_option_id, description
        )
        if bpy.data.objects.get(object_name) not in {None, garment}:
            self.report({"ERROR"}, object_name + " already exists")
            return {"CANCELLED"}

        source = find_weight_source(slot, fit_profile)
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
        garment["fb_fit_profile"] = fit_profile
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


class FB_OT_reweight_selected_garment(bpy.types.Operator):
    bl_idname = "fb.reweight_selected_garment"
    bl_label = "Reweight Selected Garment"
    bl_description = "Replace the selected garment's weights using the chosen slot and fit profile"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        scene = context.scene
        garment = context.active_object
        rig = find_rig(scene.fb_clothing_fit_profile)
        if garment is None or garment.type != "MESH":
            self.report({"ERROR"}, "Select the garment mesh first")
            return {"CANCELLED"}
        if rig is None or rig.type != "ARMATURE":
            self.report({"ERROR"}, "No compatible character armature was found")
            return {"CANCELLED"}

        slot = scene.fb_clothing_slot
        fit_profile = scene.fb_clothing_fit_profile
        source = find_weight_source(slot, fit_profile)
        if source is None:
            self.report({"ERROR"}, "No compatible weight source was found")
            return {"CANCELLED"}

        make_active(garment)
        remove_existing_rig_data(garment)
        transfer_weights(garment, source, rig)
        garment["fb_slot"] = slot
        garment["fb_fit_profile"] = fit_profile
        garment["fb_weight_source"] = source.name
        garment["fb_setup_complete"] = True
        self.report(
            {"INFO"},
            "{} reweighted from {}".format(garment.name, source.name),
        )
        return {"FINISHED"}


class FB_OT_export_working_glb(bpy.types.Operator):
    bl_idname = "fb.export_working_glb"
    bl_label = "Export Working GLB to Godot"
    bl_description = "Export the rig, body zones, and every clothing option"

    def execute(self, context):
        scene = context.scene
        rig = find_rig(scene.fb_clothing_fit_profile)
        if rig is None or rig.type != "ARMATURE":
            self.report({"ERROR"}, "No compatible character armature was found")
            return {"CANCELLED"}

        export_objects = [
            obj for obj in scene.objects if is_export_object(obj)
        ]
        errors = validate_export_objects(export_objects, rig)
        if errors:
            self.report({"ERROR"}, errors[0])
            return {"CANCELLED"}
        if not any(obj.type == "MESH" for obj in export_objects):
            self.report({"ERROR"}, "No modular meshes were found")
            return {"CANCELLED"}

        export_path = bpy.path.abspath(scene.fb_working_glb_path)
        if not export_path.lower().endswith(".glb"):
            self.report({"ERROR"}, "Export path must end in .glb")
            return {"CANCELLED"}
        os.makedirs(os.path.dirname(export_path), exist_ok=True)

        previous_active = context.view_layer.objects.active
        previous_selection = list(context.selected_objects)
        previous_pose_position = rig.data.pose_position

        if context.object and context.object.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        for obj in export_objects:
            obj.select_set(True)
        context.view_layer.objects.active = rig
        rig.data.pose_position = "REST"

        try:
            bpy.ops.export_scene.gltf(
                filepath=export_path,
                export_format="GLB",
                use_selection=True,
                export_animations=True,
                export_animation_mode="ACTIONS",
                export_cameras=False,
                export_lights=False,
                export_apply=True,
            )
        except Exception as error:
            self.report({"ERROR"}, "GLB export failed: {}".format(error))
            return {"CANCELLED"}
        finally:
            rig.data.pose_position = previous_pose_position
            bpy.ops.object.select_all(action="DESELECT")
            for obj in previous_selection:
                if obj.name in bpy.data.objects:
                    obj.select_set(True)
            if previous_active and previous_active.name in bpy.data.objects:
                context.view_layer.objects.active = previous_active

        self.report(
            {"INFO"},
            "Exported {} meshes to Godot".format(
                sum(obj.type == "MESH" for obj in export_objects)
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
        layout.prop(scene, "fb_clothing_fit_profile")
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
        layout.operator(
            FB_OT_reweight_selected_garment.bl_idname,
            icon="GROUP_VERTEX",
        )
        layout.label(text="Then test animations and weight paint.")

        layout.separator()
        export_box = layout.box()
        export_box.label(text="Godot Quick Update")
        export_box.prop(scene, "fb_working_glb_path")
        export_box.operator(
            FB_OT_export_working_glb.bl_idname,
            icon="EXPORT",
        )
        export_box.label(text="Keep object names unchanged.")


CLASSES = (
    FB_OT_setup_clothing,
    FB_OT_reweight_selected_garment,
    FB_OT_export_working_glb,
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
            ("HAIR", "Hair", "Prepare hair"),
        ),
        default="TOP",
    )
    bpy.types.Scene.fb_clothing_fit_profile = EnumProperty(
        name="Fit Profile",
        items=(
            ("MALE", "Male", "Transfer weights from male body or clothing"),
            ("FEMALE", "Female", "Transfer weights from the female body"),
        ),
        default="FEMALE",
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
    bpy.types.Scene.fb_working_glb_path = StringProperty(
        name="Working GLB",
        subtype="FILE_PATH",
        default=DEFAULT_EXPORT_PATH,
    )


def unregister():
    del bpy.types.Scene.fb_working_glb_path
    del bpy.types.Scene.fb_orm_path
    del bpy.types.Scene.fb_normal_path
    del bpy.types.Scene.fb_base_color_path
    del bpy.types.Scene.fb_clothing_description
    del bpy.types.Scene.fb_clothing_option_id
    del bpy.types.Scene.fb_clothing_slot
    del bpy.types.Scene.fb_clothing_fit_profile

    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
