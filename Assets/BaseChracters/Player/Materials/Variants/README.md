# Automatic Clothing Material Variants

Save clothing material resources in this folder using:

`<ExactClothingObjectName>__<MenuName>.tres`

Examples:

- `TOP_02_TShirt__White.tres`
- `TOP_03_PoliceShirt__Blue.tres`
- `BOTTOM_03_PolicePants__Black.tres`
- `SHOES_03_PoliceBoots__Brown.tres`

The name before `__` must exactly match the clothing object name. The name
after `__` becomes the customization-menu label. Underscores in the menu
name become spaces.

To add a variant:

1. Put image textures in `Assets/BaseChracters/Player/Textures`.
2. Create a `StandardMaterial3D` in Godot.
3. Assign Base Color, Normal, ORM, or other texture maps.
4. Save the material into this folder using the naming rule above.
5. Restart the running game or launch it again.

No GDScript changes are required.
