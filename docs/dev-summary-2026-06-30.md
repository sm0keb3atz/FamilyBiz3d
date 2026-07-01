# Dev Summary - 2026-06-30

## Session Outcome

The third-person player is now in a strong, stable place. Aiming, directional
movement, animation playback, and the camera all work together cleanly, and the
player was reorganized into components for easier expansion.

## Aiming and Animation Fixes

- The full character turns toward the camera while aiming.
- Corrected the pistol animation's sideways upper-body rotation without forcing
  its sideways hip pose onto the legs.
- Added forward, backward, left, and right aiming locomotion.
- Left and right strafe clips now keep the hips facing forward.
- Removed horizontal root motion from the strafe clips so the CharacterBody
  remains responsible for movement.
- Added separate playback-speed controls for walking and aiming movement.
- Smoothed the sprint-to-walk transition by blending animation playback speed
  from the character's actual velocity instead of switching on button release.

## Current Tuning

- Walk movement speed: `2.5 m/s`
- Sprint movement speed: `6.5 m/s`
- Aim movement speed: `3.0 m/s`
- Walk animation speed: `2.0x`
- Aim/strafe animation speed: `1.35x`

These values are exposed on the movement and animation components for further
editor tuning.

## Camera Improvements

- Normal camera distance: `2.0 m`
- Aiming camera distance: `1.0 m`
- Aim-only right shoulder offset: `0.6 m`
- Camera zoom and shoulder movement transition smoothly.
- Camera distance, shoulder offset, sensitivity, and transition speeds are
  exposed on `CameraComponent`.

## Player Composition

`Scenes/Player.tscn` is now a composition root with a `Components` container:

- `MovementComponent` handles velocity, acceleration, gravity, facing, and
  movement input.
- `CameraComponent` handles mouse look, zoom, and the aiming shoulder offset.
- `AnimationComponent` handles locomotion blending, playback speed, aiming
  layers, and runtime correction of imported animations.
- `Scripts/Player/player.gd` remains intentionally minimal.

Main component scripts:

- `Scripts/Player/Components/player_movement_component.gd`
- `Scripts/Player/Components/player_camera_component.gd`
- `Scripts/Player/Components/player_animation_component.gd`

## Important Implementation Notes

- Do not add the pistol animation's raw hips track back to the upper-body
  filter. Its rotation is corrected at runtime so the upper body aims forward
  while locomotion retains control of the legs.
- The strafe animations are also corrected at runtime to face forward and stay
  in place.
- The CharacterBody should continue to control world movement instead of using
  animation root motion.
- Godot headless startup and runtime validation pass without errors.

## Next Session: Stat System

The next planned feature is the player stat system. It should fit naturally
under the existing `Components` container.

Suggested starting direction:

1. Add a `StatsComponent` for runtime values and stat-related signals.
2. Store base/default stats in a reusable custom `Resource`.
3. Begin with health and stamina, then add other stats as gameplay needs them.
4. Let movement consume stamina through the stats component later instead of
   coupling stat logic directly into movement.
