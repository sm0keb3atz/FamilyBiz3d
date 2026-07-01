# Dev Summary - Stats and Early Combat Foundation

## Session Outcome

The player now has a complete first-pass stats and progression system, a
functional HUD and attribute menu, stamina-driven sprinting, a full
damage-to-respawn loop with ragdoll death, and the beginnings of pistol combat.

The pistol currently uses procedural recoil and reload motion layered over the
existing aiming pose. This avoids modifying imported animations and keeps the
motion tunable directly from the player components.

## Player Stats and Progression

A reusable `StatsComponent` and configuration resource now manage:

- Health and delayed Health regeneration.
- Stamina, Stamina regeneration, and sprint consumption.
- EXP, Level, and skill points.
- Strength as the first purchasable attribute.
- Inspector-tunable starting values, regeneration rates, and progression
  bonuses.

Current progression rules:

- Base Health: `100`.
- Base Stamina: `100`.
- Health regeneration: `1` per second after `5` seconds without damage.
- Stamina regeneration: `15` per second.
- EXP requirement: `100 x current level`.
- Every level grants `1` skill point and `2` maximum Stamina.
- Every Strength point grants `10` maximum Health and `5` maximum Stamina.

Sprint drains `20` Stamina per second. Reaching zero causes exhaustion, and the
player cannot sprint again until Stamina is completely full.

## HUD and Attribute Menu

The player HUD displays:

- Health and Stamina progress bars.
- Current Level.
- Current EXP and the next-level requirement.
- A `PLAYER DOWN` state when Health reaches zero.

The attribute menu displays Level, EXP, skill points, Strength, maximum Health,
and maximum Stamina. Strength can be purchased directly from this menu.

Controls:

- `Tab`: Open or close the attribute menu.
- `1`: Deal `25` debug damage to the player.
- `2`: Grant `100` debug EXP.

Movement pauses while the attribute menu is open, and mouse focus is restored
correctly when it closes.

## Health, Death, Ragdoll, and Respawning

The health flow now tracks three states:

- `ALIVE`
- `DOWNED`
- `RESPAWNING`

When Health reaches zero:

- Health regeneration stops.
- Movement and regular animation processing stop.
- The CharacterBody collision capsule is disabled.
- The configured physical skeleton begins ragdoll simulation.
- The HUD displays `PLAYER DOWN`.

Physical bones use their own collision layer so they do not interfere with the
camera spring arm while inactive.

Pressing `R` while downed:

- Stops ragdoll simulation.
- Resets the skeleton pose.
- Returns the player to their original spawn transform.
- Restores full Health and Stamina.
- Restores movement, animation, collision, camera behavior, and HUD state.

## Aiming Improvements

Aiming now supports:

- Horizontal body rotation toward the camera.
- Vertical upper-body aiming distributed across the three spine bones.
- Level shoulders during vertical aiming by rotating in skeleton space.
- Smooth transitions between left and right aiming-strafe animations.
- Separate aim-entry and aim-exit blend speeds.

The lower body remains controlled by locomotion while the upper body follows
the camera pitch.

## Pistol Shooting Foundation

`WeaponComponent` provides the first combat-facing interface:

- Left-click fires only while aiming.
- Fire rate is limited by a `0.2` second interval.
- Firing emits a reusable `fired` signal.
- Firing is blocked during reload.
- Dead players cannot fire or reload.

The pistol recoil is procedural:

- The spine kicks upward.
- Both elbows and wrists receive smaller secondary recoil.
- Recoil smoothly returns to the aiming pose.
- Recoil angle, recovery speed, elbow scale, and wrist scale are exposed for
  tuning.

## Procedural Reload

Pressing `R` while alive starts a `0.9` second reload. Reloading works whether
the player was already aiming or not.

The reload:

- Temporarily blends into the pistol aiming pose.
- Lowers the left arm and elbow.
- Adds smaller hand and right-arm adjustments.
- Uses one continuous down-and-up motion without a pause.
- Smoothly fades from the pistol pose back to idle.
- Emits `reload_started` and `reload_completed` signals.

Reload timing, arm drop, elbow drop, hand turn, and pose blend speeds are
exposed on the weapon and animation components.

## Main Files

- `Scripts/Player/Components/player_stats_component.gd`
- `Scripts/Player/Components/player_stats_config.gd`
- `Scripts/Player/Components/player_health_component.gd`
- `Scripts/Player/Components/player_ragdoll_component.gd`
- `Scripts/Player/Components/player_respawn_component.gd`
- `Scripts/Player/Components/player_weapon_component.gd`
- `Scripts/Player/Components/player_animation_component.gd`
- `Scripts/UI/player_hud.gd`
- `Scripts/UI/player_stats_menu.gd`
- `Scenes/UI/PlayerHUD.tscn`
- `Scenes/UI/PlayerStatsMenu.tscn`
- `Scenes/Player.tscn`

## Recommended Next Steps

1. Add ammunition counts, magazine capacity, and reserve ammunition.
2. Connect `fired` to a camera-centered hitscan or raycast.
3. Create a reusable damage interface for enemies and destructible targets.
4. Add muzzle flash, gunshot audio, impact effects, and a crosshair.
5. Add a simple enemy or target dummy for combat testing.
6. Replace temporary debug controls as production gameplay systems come online.

## Cleanup Note

The failed experimental files under `Assets/Animations/Retargeted` are unused
and can be deleted. The working player does not reference them.
