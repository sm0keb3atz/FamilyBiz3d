# Family Business — Polish Pass 1

## Purpose

Polish Pass 1 turns the existing gameplay foundation into a cohesive,
performant, and presentable six-territory city. This is a refinement-and-
completion phase: review every player-facing system, improve it where play
testing identifies a real need, and finish the map without committing to
unneeded new empire-management mechanics.

## Working Rules

- Work one independently testable system or territory slice at a time.
- Preserve existing save compatibility and run the relevant smoke tests
  sequentially after each change.
- Record balance and presentation findings separately from correctness bugs.
- Do not add physical-cash laundering, audit mechanics, delivery logistics, or
  office/laptop executive management unless the system review identifies a
  specific player-experience problem they solve.
- New events are in scope when they strengthen an existing loop. Post-ownership
  territory defense and rival-pressure events are explicitly in scope.

## Phase 0 — Documentation and Baseline

- [ ] Reconcile the GDD, checkpoint, and roadmap with the live implementation.
- [ ] Create a current-system inventory for trading, properties/stashes, front
  businesses, wholesaling/brick processing, territory/dealers, police, legal,
  girlfriends, vehicles, combat, NPC life, save/load, UI, time, and audio.
- [ ] For every system, record: intended player experience, current behavior,
  known issues, polish opportunities, dependencies, and acceptance check.
- [ ] Establish a clean baseline: run existing focused smoke tests sequentially
  and document existing failures before beginning polish work.
- [ ] Define repeatable manual playthrough scenarios for street dealing,
  property/business operation, legal consequences, territory ownership,
  automated dealers, wholesale supply, combat, and travel.

## Phase 1 — Core System Review and Game Events

- [ ] Trading, economy, progression, inventory, and product flow: tune prices,
  quantities, gates, feedback, failure messaging, and cross-system balance.
- [ ] Properties, stashes, front businesses, and brick processing: review
  ownership, storage, restocking, passive earnings, UI clarity, and save/load.
- [ ] Territory, dealers, wholesalers, and player crews: review claim flow,
  supply, staffing, earnings, faction conversion, risk, rewards, and travel
  incentives between territories.
- [ ] Add and tune post-ownership territory defense/rival-pressure events with
  clear triggers, stakes, response choices, rewards, failure outcomes, and
  save-safe state.
- [ ] Police, wanted response, arrest, court, and lawyers: review escalation,
  pursuit readability, evidence, sentencing, legal services, recovery, and
  player feedback.
- [ ] Girlfriends, Aura, clothing, vehicles, weapons, combat, health, and
  respawn: review progression value, controls, edge cases, and feedback.
- [ ] Civilian life, dealers, traffic, time, and world interactions: review
  believability, interruption safety, population behavior, and day/night flow.
- [ ] Add focused smoke coverage for every new event or changed state boundary.

## Phase 2 — Performance and Technical Polish

- [ ] Capture baseline performance in representative scenarios: normal street
  activity, busy traffic, active solicitation, dealer combat, police response,
  territory events, dense UI, and night-time effects.
- [ ] Set target frame-time and memory budgets for the supported PC target.
- [ ] Profile and improve pooled actors, navigation/AI updates, physics,
  animation, draw calls, material duplication, shadows, lights, particles,
  shaders, UI redraws, and unnecessary per-frame work.
- [ ] Re-run the same scenarios after each change and retain before/after
  measurements.

## Phase 3 — Visual and Effects Pass

- [ ] Define lighting, time-of-day, post-processing, fog/atmosphere, material,
  shader, particle, and interaction-feedback standards for the low-poly style.
- [ ] Improve visual readability at night, indoors, during combat, during police
  response, and while interacting with gameplay objects.
- [ ] Apply the standards across all territories while giving each district a
  distinct mood and progression identity.
- [ ] Verify that every visual change remains within the performance budget.

## Phase 4 — UI/UX and Audio Pass

- [ ] Audit the HUD, menus, interaction prompts, shops, property/stash views,
  territory dashboard, legal screens, girlfriend screens, police feedback,
  pause flow, and developer-facing UI for hierarchy and clarity.
- [ ] Improve mouse and controller flow, focus order, feedback, error states,
  readability, and accessibility options.
- [ ] Build an audio coverage checklist for movement, weapons, vehicles, world
  ambience, NPC reactions, interactions, menus, businesses, police, court, and
  territory events.
- [ ] Tune audio mixing, distance, priorities, looping, transitions, subtitles,
  and captions where applicable.

## Phase 5 — Six-Territory City Completion

| Territory | Completion target |
| --- | --- |
| Hood East | Reference-quality full gameplay loop and final polish benchmark. |
| Hood West | Full system parity, distinct identity, and connected travel routes. |
| Downtown East | Integrated permanent territory with district identity, economy, population, mobility, and police coverage. |
| Downtown West | Finish scene integration, permanent territory setup, and district identity. |
| Suburbs East | Build and integrate as a complete territory. |
| Suburbs West | Build and integrate as a complete territory. |

For every territory:

- [ ] Register a stable permanent ID, boundary, market/economy state, heat,
  Reputation, ownership, and save/load migration path.
- [ ] Author dealer zones, wholesaler access where appropriate, police coverage,
  pedestrian destinations, traffic/mobility routes, events, map identity, and
  progression purpose.
- [ ] Validate navigation, spawns, intersections, interactions, travel links,
  territory transitions, and player-owned dealer support.
- [ ] Complete visual, UI, audio, and performance standards before sign-off.

## Definition of Done

- [ ] Every core system has a completed review record and an acceptance check.
- [ ] All intended automated tests pass, with known unrelated issues documented.
- [ ] A full save/load playthrough works across the complete six-territory city.
- [ ] The player can progress through street dealing, business ownership, legal
  consequences, territory control, dealer operation, wholesale supply, and
  territory events without contradicting systems or unclear handoffs.
- [ ] Performance, visual, UI, and audio standards are met in the representative
  scenarios.
