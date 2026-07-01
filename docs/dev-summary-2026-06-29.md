# Dev Summary - 2026-06-29

## What We Built

We restarted the project in Godot and got a solid third-person player base working.

Current player features:
- Third-person camera with mouse look
- WASD movement relative to camera direction
- Sprint
- Jump
- Ground collision fallback on the test map
- Locomotion animation blending with `AnimationTree`
- Jump state flow with `Jump_Start`, `Jump`, and `Jump_Land`

## Main Files

- `Scenes/player.tscn`
- `Scripts/player.gd`
- `Scenes/test_map.tscn`
- `AnimationLibary.res`
- `Assets/new_animation_node_blend_space_1d.tres`

## Player Scene Setup

`Scenes/player.tscn` is built around:
- `CharacterBody3D` root
- `CollisionShape3D`
- `CameraPivot`
- `SpringArm3D`
- `Camera3D`
- `Visual`
- `AnimationPlayer`
- `AnimationTree`

The locomotion blend space is no longer the root by itself. The `AnimationTree` root is now a state machine that contains:
- `Locomotion`
- `AnimationLibary_Jump_Start`
- `AnimationLibary_Jump`
- `AnimationLibary_Jump_Land`

## Animation Tree / State Machine Notes

Current state machine intent:
- `Start -> Locomotion` can auto-enter
- `Locomotion -> Jump_Start` is code-driven
- `Jump_Start -> Jump` is code-driven from script timing
- `Jump -> Jump_Land` is code-driven
- `Jump_Land -> Locomotion` is code-driven with a small crossfade

Important: we had a loop warning earlier because too many transitions were set to auto-advance. That was fixed by making the jump transitions manual.

Current `Jump_Land -> Locomotion` transition in `Scenes/player.tscn`:
- `xfade_time = 0.12`

## Current Movement / Animation Script Behavior

`Scripts/player.gd` currently handles:
- gravity
- jump input
- movement acceleration / deceleration
- steering smoothing
- player visual facing
- locomotion blend position updates
- jump state switching

Current animation logic:
- locomotion blend is written to `parameters/Locomotion/blend_position`
- jump start and landing duration are based on animation clip length
- landing exits earlier if the player is already moving, to avoid sliding through the landing pose

Current landing behavior:
- if landing mostly in place, let `Jump_Land` finish
- if landing while moving fast enough, leave `Jump_Land` early and blend back to locomotion

Current tuning values in `Scripts/player.gd`:
- `animation_end_buffer = 0.02`
- `moving_landing_speed_threshold = 1.5`
- `moving_landing_min_time = 0.06`

## Test Map Notes

`Scenes/test_map.tscn` has a basic structure for world building:
- `WorldEnvironment`
- `DirectionalLight3D`
- `Gameplay`
- `PlayerSpawn`
- `Player`
- `Ground`
- `Buildings`
- `Roads`
- `Props`

We also added a simple collision fallback floor because the modular ground pieces did not have working collision yet.

## What Went Well

- Switching to Godot gave us a much faster base to iterate on
- The player now feels usable
- Sprint smoothing and turn behavior were improved a lot
- The jump setup is now in a much better place than the original blend-space-only version

## Known Issues / Current Tradeoffs

- The landing animation is improved, but it is still a compromise
- The landing clip itself appears short or not ideal for blending back into locomotion
- Showing too much of the landing clip causes visible sliding while moving
- Hiding too much of it makes the landing feel skipped

Right now the best compromise is the current setup:
- full landing when mostly stationary
- shortened landing when moving

## Best Next Steps

1. Test and refine jump / landing with more clips if available.
2. If a better landing clip exists, swap it in.
3. Consider adding a separate fall state later if the current `Jump` clip is doing too much work.
4. Start planning upper-body animation layering for weapons, aiming, reloads, and shooting.
5. Keep building the test level so movement and animation can be judged in a more realistic space.

## Notes For The Next Agent

- Do not revert the current player animation setup without testing first.
- The project already has working momentum on the player controller; build on it.
- If landing feels off again, inspect the clip itself before over-tuning script timings.
- The user is hands-on in the Godot editor and can adjust scenes/resources directly, so editor-compatible guidance is useful.
