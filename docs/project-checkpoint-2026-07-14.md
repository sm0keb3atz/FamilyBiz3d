# Family Business - Project Checkpoint

**Date:** July 14, 2026  
**Purpose:** Current-state handoff for the next development sessions.

## Current Direction

Family Business is a third-person street-life and criminal-empire simulator.
The player begins by buying and selling product manually, builds local
Reputation while attracting Heat, acquires stash houses and legitimate stores,
then grows into territory ownership and an automated dealer network.

The next milestone is **one living, economically connected territory**. It is
not a full-city expansion or a polish pass. The milestone should prove that the
existing traffic, pedestrian, dealer, property, economy, territory, and police
systems can work together in one neighborhood before they are copied elsewhere.

## Repository Safety

The working tree already contains user changes. Preserve them. In particular,
the property/stash implementation and its scenes, menus, tests, and save hooks
are currently uncommitted. Do not replace, discard, or broadly reformat these
files while working on an unrelated roadmap step.

Before each implementation pass:

1. Read `AGENTS.md`.
2. Inspect `git status --short` and the diff for files in scope.
3. Limit the pass to one independently testable outcome.
4. Run Godot smoke tests sequentially, never several headless instances at once.
5. Record the result before starting the next pass.

The July 14 parallel test attempt is not a valid failure report. Multiple Godot
processes tried to write the same `user://logs` file and crashed before the test
scripts produced results.

## Status Summary

### Working Foundation

- `Scenes/Maps/World/world.tscn` is the permanent two-territory world.
- Hood East and Hood West have stable IDs, boundaries, Heat, signed Reputation,
  neutral/rival/player ownership state, rival-pressure tiers, and takeover
  availability queries.
- The player can buy product, solicit customers, sell product, gain EXP and
  local Reputation, generate local Heat, and save/load progress.
- Customers are pooled, navigate a pedestrian waypoint network, approach the
  player, wait for a sale, return to their route, and panic after gunshots.
- Dealers support levels, reputation gates, stock, restocking, weapons, and
  hostile combat behavior.
- The player has Dirty and Clean Cash, inventory, stats, weapons, clothing,
  Aura, vehicles, a wanted component, and component-based save data.
- The world has a working clock, day rollover, sleep-to-morning, and daily
  earned/spent reporting.
- Every product has a persistent daily dealer quote per territory. Dealers use
  that quote, customers pay a Hustle markup over it, and the territory HUD
  shows the three local gram-product dealer prices.
- Clothing and gun stores sell their current catalogs for Clean Cash.
- The ATM transfers limited Dirty Cash into Clean Cash and supports withdrawals.
- Traffic has pooled cars, a waypoint graph, weighted route choices, signals,
  following/obstacle checks, and separate East/West population managers.
- Police currently share the pedestrian population system and support patrol,
  perception, last-known-position search, arrest, combat, and 0-3 wanted stars.
- Focused smoke tests exist for the main gameplay foundations.

### Recently Completed Foundation

- The Pass 0 property checkpoint is complete for this session baseline.
- Four Hood East houses are purchasable properties.
- Owned houses have locked/unlocked doors, beds, wardrobes, and persistent
  stashes for Dirty Cash, products, weapons, ammunition, and attachments.
- Property ownership and stash state are connected to the save controller.
- Recent uncommitted customer, solicitation, wardrobe, weapon, UI, and world
  changes overlap this work and must continue to be preserved.
- Passes 1 and 2 are implemented with focused smoke coverage; the user will run
  the remaining Godot regression and in-editor presentation checks.

### Prototype Quality / Needs Rework

- Pedestrians mostly roam between waypoints; they do not yet reserve and use
  environmental activities such as sitting, leaning, talking, or phone use.
- Dealer spawners arrange dealers in a simple circle rather than authored,
  believable groups.
- Traffic can branch in code, but the current authored road network still feels
  like local loops and is not yet the city-wide intersection network.
- Rival-pressure encounters, takeover events, and dealer faction conversion do
  not exist yet; Pass 1 provides only their persistent state and queries.
- Player-owned dealers are not supplied by stash houses.
- Stores are shopping locations, not purchasable front businesses with stock
  and passive Clean Cash earnings.
- Wanted police are increased through pedestrian population targets; cruisers
  do not yet dispatch through the road network and unload officers.

## Locked Product Decisions

- Build and validate **one living territory** before rolling systems city-wide.
- Ambient NPC life uses reservable **activity spots**, not full daily schedules.
- Gun and clothing stores are the first two front-business types.
- Front-business inventory uses abstract stock units in the first version.
- Stores are bought with Clean Cash, restocked with Dirty Cash, and produce
  Clean Cash from passive sales.
- Daily product prices are bounded random territory quotes that remain fixed for
  that in-game day.
- Territory Reputation becomes signed from `-100` to `100`.
- Territory ownership requires `+60` Reputation and a takeover event.
- Dealer locations become persistent activity zones that switch faction after
  takeover instead of being deleted and replaced.
- Police vehicle scope is dispatch, arrival, safe stopping, and officer exit.
  Advanced vehicle pursuit and roadblocks remain deferred.

## Immediate Next Move

Have the user run the Pass 1/2 focused and full sequential smoke-test suite,
then verify the signed Reputation meter and local Weed/Coke/Fent HUD quote row
in the editor. After that verification, continue with Pass 3 property roles and
front-business data; do not combine it with passive store operation from Pass 4.
