# NPC component architecture

`BaseNPC` is the composition root and compatibility façade for every NPC.
Callers continue to use the NPC itself (`advance_navigation()`,
`apply_vehicle_impact()`, VFX attachment methods), while the implementation is
owned by these child components:

- `NPCMovementComponent`: navigation targets, avoidance, obstacle steering,
  gravity, velocity, facing, and movement.
- `NPCAnimationComponent`: locomotion playback, visibility-based animation
  processing, hit reactions, and character visual scale.
- `NPCHealthComponent`: defeat state, vehicle impact damage, ragdoll, body
  cleanup, reuse reset, and blood VFX attachment support.

Each component also owns its inspector tuning. `BaseNPC` exposes compatibility
properties only where role scripts need to read or change shared state, such as
customer panic temporarily changing movement speed.

NPC role scripts should contain only role-specific coordination. For example,
`DealerNPC` owns shop behavior and `CustomerNPC` owns customer state/route
coordination. Shared physical behavior belongs in a base component instead of a
role script.

## Role composition

NPC identity is composition-based:

- `DealerRoleComponent` owns shop identity, product configuration, prompts,
  interaction groups, and purchases.
- `CivilianRoleComponent` owns customer identity, solicitation eligibility,
  trade interaction, prompts, and civilian groups.
- `PoliceRoleComponent` provides the police identity and groups. Detection,
  pursuit, arrest, and combat should be separate police AI components instead
  of one oversized role script.

Police currently composes `PedestrianPatrolComponent`,
`PolicePerceptionComponent`, `NPCCombatComponent`, and `PoliceAIComponent`.
The combat component is role-neutral so an armed dealer or guard can reuse it.

`DealerNPC` and `CustomerNPC` remain small compatibility façades for systems
that already use those types. The selected role is a child named
`Components/RoleComponent` in each specialized scene.

## Dependency rule

Components may coordinate through the `BaseNPC` public façade. Game systems
outside the NPC scene should not reach into `Components` directly. This keeps
component layout replaceable without breaking vehicles, combat, AI, or tests.

## Adding behavior

1. Put reusable behavior in a focused component under
   `Scripts/NPC/Components`.
2. Add that component to `Scenes/NPC/BaseNPC.tscn`.
3. Expose only the stable operations needed by callers through `BaseNPC`.
4. Keep customer/dealer-only behavior out of the base component set.
