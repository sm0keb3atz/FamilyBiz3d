# Male Body Texture Kit

Use `FB_Male_Body_Texture_Source.glb` only for **texture/retexture** work.

- Keep its existing UV layout. In the Blender master it is named
  `Retopo_Untitled_NewUVMap`; GLB exports label the same layout `UVMap`.
- Do **not** choose remesh, regenerate mesh, auto-unwrap, or create-model modes.
- `Body_Texture_01.png` and `Body_Texture_02.png` are the two known-good body textures already used by the game.
- `FB_Male_Body_Original_UV_Layout.svg` is the original UV guide. A new texture must match this layout exactly.

If a generated result has five separate body pieces with UV maps each filling
the whole square, it is a new Trip mesh and its texture is not compatible with
this character.
