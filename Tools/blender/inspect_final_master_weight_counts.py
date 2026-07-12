import bpy


for obj in bpy.data.objects:
    if obj.type != "MESH":
        continue
    if not obj.name.startswith(("TOP_", "BOTTOM_", "SHOES_", "HAIR_", "BODY_")):
        continue

    counts = {group.index: 0 for group in obj.vertex_groups}
    total_weights = 0
    for vertex in obj.data.vertices:
        for weight in vertex.groups:
            if weight.weight > 0.0001:
                counts[weight.group] = counts.get(weight.group, 0) + 1
                total_weights += 1

    named_counts = [
        (group.name, counts.get(group.index, 0))
        for group in obj.vertex_groups
        if counts.get(group.index, 0) > 0
    ]
    print(
        "WEIGHTS",
        obj.name,
        "verts",
        len(obj.data.vertices),
        "groups",
        len(obj.vertex_groups),
        "weighted_groups",
        len(named_counts),
        "total_assignments",
        total_weights,
        "sample",
        named_counts[:10],
    )
