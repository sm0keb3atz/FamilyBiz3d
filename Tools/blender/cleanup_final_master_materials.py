import bpy


def get_or_create_material(name):
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
    material.use_nodes = True
    return material


BODY_MAT = get_or_create_material("MAT_BODY_Skin")

for obj in bpy.data.objects:
    if obj.type != "MESH":
        continue
    if obj.name.startswith("BODY_"):
        obj.data.materials.clear()
        obj.data.materials.append(BODY_MAT)
        obj.data.name = "MESH_" + obj.name
    elif obj.name.startswith("HAIR_"):
        material = get_or_create_material("MAT_" + obj.name)
        obj.data.materials.clear()
        obj.data.materials.append(material)
        obj.data.name = "MESH_" + obj.name

bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print("FB_FINAL_MASTER: cleaned material names")
