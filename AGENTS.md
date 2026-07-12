# Family Business Character Pipeline

## When to use this runbook

Follow this section whenever the user asks to add, replace, repair, export, or
connect female character clothing or Mixamo animations. Preserve unrelated
working-tree changes and never delete an edited Blender copy without first
confirming that the authoritative master contains the same garments/actions.

## Authoritative files

- Female Blender master:
  `C:/Users/smo0o/OneDrive/Desktop/shh/Project material/Family Business/Assets/Chracters/3d models/FB_Female_Character_Master.blend`
- Installed Blender add-on:
  `C:/Users/smo0o/AppData/Roaming/Blender Foundation/Blender/5.1/scripts/addons/fb_clothing_setup.py`
- Maintained add-on source:
  `Tools/blender/fb_clothing_setup.py`
- Female Godot GLB:
  `Assets/BaseChracters/Player/Meshes/Female/FB_Female_NPC_Variant.glb`
- Female extraction tool:
  `Tools/Godot/extract_female_character_meshes.gd`
- Shared modular visual:
  `Scenes/PlayerVisualModular.tscn`
- Appearance behavior:
  `Scripts/Player/Components/player_appearance_component.gd`
- NPC animation behavior:
  `Scripts/NPC/Components/npc_animation_component.gd`
- Main animation library:
  `Assets/Animations/MainAnimationLibary.res`
- Focused verification:
  `Tests/female_appearance_smoke_test.gd`

## Female clothing workflow

1. Inspect the latest saved Blender master before changing or exporting it.
   Inventory every `TOP_Female_*`, `BOTTOM_Female_*`, and `SHOES_Female_*`
   mesh. Do not assume garments visible in an open Blender window were saved.
2. In Blender, the garment must use the correct slot, `Fit Profile: Female`, a
   unique option number, and a stable descriptive name.
3. Prepare or reweight the garment with the FB Clothing Setup add-on. The
   transfer source must be the complete undeformed `BODY_Female_WeightSource`.
   Data Transfer must be applied before adding the Armature modifier.
4. Confirm the garment has the expected arm/leg/foot bone groups and test it
   in more than one pose before export.
5. Save the authoritative master, then export to the Female Godot GLB path.
6. Preserve the female GLB import retarget map. Its import settings must keep:
   `animation/remove_immutable_tracks=false`. Mixamo constant rotations are
   required for correct retargeting.
7. Update `FEMALE_NAMES` in the extraction tool for every new female garment.
   Run the tool to save both the `ArrayMesh` and its dedicated `Skin`. Do not
   assign the male shared Skin to a female mesh: bind ordering differs.
8. Add the extracted mesh and Skin resources to `PlayerVisualModular.tscn`.
9. Register the mesh in `FEMALE_CLOTHING_MESHES` and, when it maps to a normal
   clothing slot, `FEMALE_CLOTHING_BY_SLOT` in the appearance component.
10. Female-only garments must hide male slot meshes. White garment materials
    should be duplicated per NPC before applying randomized colors so NPCs do
    not recolor one another through a shared material.

Current female garment names:

- `TOP_Female_01_HoodieCrop`
- `BOTTOM_Female_01_Leggins` (keep the existing spelling for compatibility)
- `SHOES_Female_01_FemaleSneakers`

## Mixamo animation workflow

Recommended Mixamo download settings:

- FBX Binary
- Without Skin
- 30 FPS
- Keyframe Reduction: None
- In Place for locomotion controlled by Godot movement code

For each animation:

1. Keep the original FBX and assign a stable action name.
2. Verify all 41 Mixamo bones match before directly assigning an action.
3. Confirm the character remains upright across the start, middle, and end
   frames in Blender.
4. Import through Godot's humanoid BoneMap used by the female GLB.
5. Disable immutable-track removal. A healthy full-body action should retain
   dozens of tracks; the broken catwalk import retained only two and produced
   a T-pose.
6. Save the extracted animation as a standalone `.anim`, then add it to the
   main animation library under a clear stable name.
7. Importing an action does not activate it. Connect it to the relevant
   AnimationTree node or gameplay/NPC state and test the transition.
8. Avoid mutating external/shared AnimationTree resources per NPC. A previous
   female walk switch changed the shared blend-space and caused the player and
   every NPC to enter a synchronized sunken T-pose. Use an instance-local tree
   or animation library when a variant truly needs a different action.
9. Unless the user explicitly requests another female-specific locomotion
   attempt, female NPCs use the same proven `Walk` animation as male NPCs.

## Required verification

After clothing or animation changes:

1. Force Godot to reimport the changed GLB when import settings or source data
   changed.
2. Run `Tools/Godot/extract_female_character_meshes.gd` when the GLB changes.
3. Run `Tests/female_appearance_smoke_test.gd` headlessly.
4. The test must verify female body visibility, full outfit visibility,
   per-NPC color materials, male/female switching, and that both sexes still
   use the intended walk without changing a shared AnimationTree node.
5. Treat the Jolt RID leak messages printed during headless test teardown as a
   separate existing cleanup issue when the command exits successfully and
   prints `FEMALE_APPEARANCE_SMOKE_TEST_PASS`.
6. Ask the user to stop the running game and restart Godot after binary
   animation-library or imported GLB changes.

## Safety and backups

- Back up the authoritative `.blend` before destructive changes.
- Never overwrite the authoritative master from a temporary test copy unless
  its complete mesh/action inventory has been compared first.
- Do not remove alternate Blender files merely because they look temporary;
  they may contain unsaved garment work. Ask before deletion.
- Keep object names stable after Godot resources reference them.
