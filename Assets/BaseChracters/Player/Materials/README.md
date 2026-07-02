# Player Character Materials

## Modular

`Modular/` contains the texture-authored materials used by the runtime
character customizer.

- Body: two existing skin texture sets.
- Hoodie: two existing texture variants.
- T-shirt, jeans, sweatpants, sneakers, and boots: their current original
  texture sets.

Add future variants here as separate `.tres` materials, then register them in
`player_appearance_component.gd`. Texture-authored variants are preferred over
runtime tinting because they preserve fabric detail and intentional color
placement.

## Legacy folders

The existing `Mats/` and `Textures/` folders remain in place because NPC scenes
and imported resources already reference them. Moving those files outside the
Godot editor would risk breaking their imported UIDs.
