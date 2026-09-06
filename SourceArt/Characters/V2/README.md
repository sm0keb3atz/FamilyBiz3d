# Character replacement work in progress

These are authoring and review assets, excluded from Godot by SourceArt/.gdignore.
The existing game still uses the original character system. No legacy assets have
been deleted or replaced. This directory is not a recovery backup outside the project.

## Completed preparation

- Inventoried 58 source Blender files, including alternate masters and backups,
  with source hashes, complete bone rest matrices, meshes, actions, and image paths.
  See source_inventory.json. Inventory completed without errors.
- Created six separate body masters and GLB staging exports in Bases, with complete
  undeformed weight sources and clothing/hair collections. No vendor file was saved.
- Removed empty Armature modifiers from the superhero female staging master.
- Confirmed different skeleton rest signatures across the six bodies. Reuse of one
  body's Skin on another profile is not valid merely because bone names match.
- Generated regular male hoodie/jeans/sneakers and regular female cropped hoodie/
  leggings/sneakers fitting checkpoints. All garment vertices have transferred weights.
- Generated first-pass and clearance-corrected variants without overwriting either.

## Validation status

All garment fits are UNAPPROVED_AUTOMATIC_FIT. Zero unweighted vertices is not a
deformation or clipping pass. Initial rendered checks exposed collar, waist, hip,
leg and shoe clipping. Clearance corrections require renewed visual inspection,
surface cleanup, and multi-pose verification. Review materials are temporary plain
materials, not the final approved stylized textures. Base GLB export logged reduction
to four joint influences; exported deformation must be checked before runtime use.

## Next required work

1. Correct and validate the regular pair in rest and multiple action poses, including
   garment-to-garment overlap and coverage boundaries. Preserve source UVs/graphics.
2. Fit remaining garments and police uniforms to the agreed body profiles; prepare
   hair, facial hair, eyebrows, coverage resources, and final materials.
3. Retarget and test all gameplay actions with dedicated per-profile skins.
4. Implement catalog/state interfaces, creator/appearance UI, shop compatibility,
   wardrobe restoration, save migration, NPC/vehicle/weapon/ragdoll integration.
5. Run Godot smoke, rendered, crowd and packaged-game checks.
6. Make a verified external recovery backup and dependency report before removing
   obsolete project assets. Update AGENTS.md only after replacing the live workflow.

## Tools

- Tools/blender/inventory_character_v2.py: read-only inventory; never saves sources.
- Tools/blender/prepare_character_v2_bases.py: creates new isolated body masters;
  refuses to overwrite existing profile directories.
- Tools/blender/fit_character_v2_checkpoint.py: generates review fits with source
  weights driving anatomical alignment, body clearance correction, then fresh
  complete-body weight transfer before the Armature modifier. Refuses overwrite.
- Tools/blender/render_character_v2_checkpoint.py: renders without saving its scene
  changes back into the source master.

Run scripts with Blender 5.1 in background mode, --disable-autoexec and
--python-exit-code 1. Each script's command-line arguments follow --.
