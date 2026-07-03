# Family Business — Project Checkpoint

**Date:** July 2, 2026

## Where the Game Stands

Family Business now has the foundation of its first real gameplay phase. It is
no longer only a movement or combat prototype: the player can enter a permanent
two-neighborhood world, buy product from dealers, find customers, complete
street sales, earn Dirty Cash and EXP, and build local Reputation while
generating local Heat.

The game also remembers meaningful progress. Money, inventory, player
progression, position, Health, Stamina, and the state of both territories can
be saved and loaded.

## Work Completed This Session

### Permanent Main World

- Promoted `Scenes/Maps/World/world.tscn` to the main game scene.
- Organized the world into Environment, Territories, Navigation, SpawnPoints,
  and Gameplay.
- Integrated Hood East and Hood West without redesigning their map geometry.
- Added the player, dealers, customers, lighting, navigation, and stable spawn
  locations.
- Kept the old test map as an isolated development sandbox.

### Independent Territories

- Gave Hood East and Hood West permanent IDs.
- Added territory boundary volumes so the game knows the player's location.
- Added independent Heat and Reputation state to each neighborhood.
- Made Heat decay over time.
- Blocked customer sales at 76 or more local Heat.
- Ensured activity in one neighborhood does not change the other.

### Trading Foundation

- Centralized buying and selling in a reusable Trade Service.
- Added structured transaction results for gameplay and UI feedback.
- Made transactions atomic: failed trades do not partially remove money,
  products, or rewards.
- Successful sales now update inventory, Dirty Cash, EXP, Reputation, and Heat
  together.
- Added configurable Heat rewards to product definitions.

### Save and Load

- Added a versioned single-slot JSON save system.
- `F5` saves and `F9` loads during the prototype.
- Saves use permanent product and territory IDs rather than fragile scene
  paths.
- Missing, damaged, or incompatible save files fail safely without replacing
  the current state.

### HUD

- Added a live Reputation progress bar at the top-center of the screen.
- Added a live Heat progress bar at the top-right.
- Both meters show the current territory and update as the player travels or
  completes sales.
- Existing Health, Stamina, money, weapon, interaction, and feedback displays
  remain intact.

### Documentation

- Updated the GDD index for Godot 4.7 and the permanent World scene.
- Replaced obsolete document links.
- Documented the current trading, territory, Heat, and saving rules.
- Recorded the World scene as the permanent composition root going forward.

## The Playable Loop Today

The current prototype supports:

1. Explore Hood East or Hood West.
2. Buy product from a dealer using Dirty Cash.
3. Approach or solicit a customer.
4. Sell product for a profit.
5. Gain EXP and local Reputation.
6. Generate local Heat.
7. Move operations when a neighborhood becomes too hot.
8. Save progress and continue later.

This is the first working version of the **Street Phase** described in the
grand vision.

## Progress Toward the Grand Vision

### Street Phase — Foundation Established

The core street fantasy now exists in simple form: physical movement through a
city, direct buying and selling, customer interaction, risky Dirty Cash, local
Reputation, and pressure from Heat.

Still needed to complete this phase:

- More products, suppliers, customers, prices, and demand differences.
- Inventory capacity and physical product storage.
- Police awareness, patrols, searches, pursuit, arrest, and confiscation.
- Stash houses and safe storage for product and Dirty Cash.
- Better customer behavior, schedules, preferences, and deal presentation.
- Missions, onboarding, and early progression goals.
- A fuller city environment with buildings, interiors, traffic, and population.

### Business Phase — Designed, Not Yet Built

The territory, money, and saving foundations are deliberately structured to
support the Business Phase, but its defining systems do not exist yet.

Major remaining systems:

- Purchasing properties and front businesses.
- Transporting and storing physical Dirty Cash.
- Laundering Dirty Cash into Clean Cash.
- Business capacity, efficiency, expenses, audits, and upgrades.
- Vehicles, clothing, jewelry, and the Aura economy.
- Territory pricing, ownership, rivals, and defensive events.
- Hiring and assigning street runners.

### Kingpin Phase — Long-Term Vision

The executive management layer remains the long-term destination.

It will eventually require:

- Wholesale suppliers and bulk inventory.
- Automated dealer networks.
- District-level control and rival organizations.
- Crew management and delegation.
- Large-scale police pressure and investigations.
- Management interfaces, financial reports, and strategic decisions.
- High-end property, lifestyle, and endgame progression.

## Foundation Health

The project is in a good position for continued growth:

- Player features are separated into focused components.
- Static product data is stored in reusable resources.
- Territories have stable identities and independent runtime state.
- Trades pass through one controlled system.
- Important progress survives scene and game restarts.
- The permanent World can grow without replacing the gameplay architecture.

The biggest remaining foundational gap is **consequence**. Heat is visible and
can stop sales, but it does not yet produce police activity, searches, arrest,
loss, or meaningful danger. Dirty Cash is tracked, but it is not yet physically
risky or connected to storage and laundering.

## Recommended Development Roadmap

### 1. Consequences and Stash Storage

- Add arrest and death penalties.
- Confiscate carried Dirty Cash and illegal inventory.
- Add a stash container for safely storing product and cash.
- Connect high Heat to basic police presence and detection.

This would make the current street loop strategically meaningful.

### 2. Economy Depth

- Add multiple products and territory-dependent prices.
- Add inventory limits.
- Add customer demand and availability.
- Add dealer stock and restocking.

This would turn the test transaction into a small economy.

### 3. First Laundering Milestone

- Add one purchasable front business.
- Give it a cleaning capacity and fee.
- Convert deposited Dirty Cash into Clean Cash over time.
- Add one legitimate purchase that requires Clean Cash.

This would create the first playable bridge from the Street Phase into the
Business Phase.

### 4. World Population and Presentation

- Expand the two neighborhoods.
- Add NPC spawning and schedules.
- Improve deal animations, audio, feedback, and customer variety.
- Add a short onboarding sequence and clear early objectives.

## Current Bottom Line

The grand vision is still large, but the project now contains the correct
small-scale version of its central idea:

> Make money on the street, build influence, attract pressure, move between
> territories, and preserve your rise.

The next major step should make that rise dangerous by connecting Heat, carried
contraband, stash storage, police, and arrest into one consequence loop. Once
that loop works, the game will have a real Street Phase rather than only the
systems that describe one.
