# Character Clothing Round-Trip

Blender exports one working file:

`Assets/BaseChracters/Player/Working/FB_Character_Working.glb`

Godot runs `fb_character_post_import.gd` whenever that GLB changes. It
extracts body and clothing meshes into:

`Assets/BaseChracters/Player/Meshes/Auto`

The player appearance component discovers those resources by their object
names. Existing options are refreshed and newly numbered clothing options
are added automatically.

Required names:

- `TOP_03_PoliceShirt`
- `BOTTOM_03_PolicePants`
- `SHOES_03_PoliceBoots`
- `BODY_Head`, `BODY_Hands`, `BODY_Torso`, `BODY_Legs`, `BODY_Feet`

Do not export `BODY_Source`, animations, cameras, lights, or another rig.
