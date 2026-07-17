# Living Neighborhood and Business Roadmap

## Milestone Goal

Prove one complete Hood East vertical slice in which believable ambient life,
territory economics, owned stores, stash-supplied dealers, branching traffic,
and a road-based police response work together.

This is a sequence of small implementation passes. A pass must be completed,
tested, and documented before the next pass begins. Do not combine adjacent
passes merely because they eventually share data.

## Definition of Done

Without debug commands, the player can spend a normal play session in the
reference territory and:

1. See pedestrians and dealer groups perform varied environmental activities.
2. See traffic choose multiple valid routes through working intersections.
3. Compare local daily prices, buy product, and store it in a stash house.
4. Buy the gun and clothing stores with Clean Cash.
5. Restock both stores with Dirty Cash and receive passive Clean Cash revenue.
6. Move Reputation above and below zero and see the correct event tier.
7. Claim Hood East through three gang-war wins or one of the deliberate
   `+100` Reputation takeover routes.
8. Supply converted player dealers from territory stash inventory.
9. Trigger a cruiser response that arrives through the traffic network and
   releases officers into the existing foot response.
10. Save, reload, sleep to the next day, and retain all relevant state.

## Pass 0 - Finish the Existing Property Checkpoint

**Status:** Working. This session treats the property checkpoint as complete.

### Outcome

The current house purchase and stash work is verified and isolated as a stable
foundation before its data model is extended.

### Work

- Review the uncommitted property files and overlapping player/UI changes.
- Run `property_system_smoke_test.gd` by itself.
- Run every existing smoke test sequentially.
- Fix only regressions caused by the property pass.
- Update the July 14 checkpoint from `In Progress` to `Working` after success.

### Acceptance

- Four unique Hood East houses can be purchased for Clean Cash.
- Ownership controls doors, beds, wardrobes, and stashes.
- Dirty Cash, products, weapons, ammunition, and attachments survive save/load.
- No existing trading, clothing, weapon, vehicle, civilian, police, or time test
  regresses.

### Do Not Add Yet

Property roles, stores as properties, passive business income, territory
ownership, NPC activities, or police cruisers.

## Pass 1 - Signed Territory State

**Status:** Implemented July 14, 2026. Focused automated coverage passes;
player-run regression verification remains pending.

### Outcome

Territory state can represent hostility and future ownership without changing
dealer factions yet.

### Work

- Change Reputation to a `-100` to `100` range.
- Preserve existing positive Reputation during save migration.
- Add persistent owner faction with neutral/rival/player values.
- Reserve deliberate takeover availability for `+100` Reputation.
- Add rival-pressure tiers at `-25`, `-50`, and `-75`.
- Expose clear query methods and change signals for UI and later systems.
- Keep existing positive dealer unlock gates at `0`, `15`, `40`, `80`, and
  wholesaler `100`.

### Acceptance

- Reputation crosses zero and clamps correctly at both ends.
- Existing supplier gates still work.
- Ownership and pressure tier survive save/load.
- No gang-war encounter is implemented in this pass.

## Pass 2 - Daily Territory Market Quotes

**Status:** Implemented July 14, 2026. The current-territory HUD price row is
the comparison view for this pass; Reputation price adjustments are explicitly
deferred. Focused automated coverage passes; player-run regression verification
remains pending.

### Outcome

Every product has a stable daily dealer price per territory, and customer
payout is a predictable Hustle markup over that local price.

### Work

- Add a territory market state keyed by permanent territory and product IDs.
- Generate one bounded random dealer-price multiplier at day rollover.
- Save the generated date and quotes so loading cannot reroll the same day.
- Apply a small signed-Reputation adjustment after the daily quote. **Deferred
  by product decision; Reputation does not modify prices in this pass.**
- Route dealer purchases through the quote service and derive customer payout
  from that same quote: `70%` markup at Hustle 1 plus `15%` per additional level.
- Show the dealer unit price and marked-up payout in transaction UI.
- Show the current territory's three gram-product dealer quotes in the HUD; a
  separate discovered-territory comparison screen is deferred.

### Acceptance

- Dealer quotes differ between territories and can differ between products.
- Quotes remain unchanged during a day and across save/load.
- Sleeping advances the day and generates exactly one new quote set.
- Failed trades do not change quotes or partially change inventory/money.

## Pass 3 - Property Roles and Front-Business Data

**Status:** Implemented July 14, 2026. Focused business-data and existing
property smoke coverage passes; player-run presentation verification remains
pending.

### Outcome

Houses and stores share ownership infrastructure while retaining different
behavior.

### Work

- Add explicit `STASH_HOUSE` and `FRONT_BUSINESS` property roles.
- Keep the four existing houses as stash houses.
- Register the current gun and clothing store scenes as front businesses.
- Define per-business purchase price, stock capacity, Dirty Cash restock cost,
  Clean Cash revenue per sale, sales interval, and operating hours.
- Add persistent business stock, accumulated earnings, total earned, and last
  processed game time to the player property component.
- Increase the save version and provide defaults for older saves.

### Acceptance

- House behavior is unchanged.
- Both stores can be bought with Clean Cash.
- Business state is separate from player-facing gun/clothing catalog inventory.
- Ownership and business state survive save/load.

## Pass 4 - Passive Store Operation

**Status:** Implemented July 14, 2026. Focused passive-business, UI, property,
and time smoke coverage passes; player-run presentation verification remains
pending.

### Outcome

The owned gun and clothing stores form the first Dirty-to-Clean business loop.

### Work

- Add a small management interaction/menu for purchase, restocking, stock,
  earnings, and collection/automatic deposit behavior.
- Spend Dirty Cash to add abstract stock units.
- Process passive sales against game time, stock, operating hours, and the
  configured sales interval.
- Credit Clean Cash through the normal wallet transaction reporting path.
- Stop sales at zero stock.
- Include business revenue and restock spending in the daily report.

### Acceptance

- Both stores earn nothing before purchase or while out of stock.
- Restocking cannot exceed capacity or spend unavailable Dirty Cash.
- Equivalent elapsed game time produces consistent results after save/load.
- Exact clothing and weapon SKUs remain outside business stock accounting.

## Pass 5 - Reusable NPC Activity Spots

**Status:** Starter slice in progress July 16, 2026. Stand/wait remains an
authored reservable spot, while civilians now discover nearby building walls
for leaning and form temporary two-person conversations wherever they meet.
Female walks use instance-local locomotion nodes. Civilian leaning and texting
are temporarily disabled by default: leaning is being reserved for dealer
hangout groups, and the current texting clips need corrected arm/hand poses.
Additional activity animations remain incremental.

### Outcome

Ambient NPCs do more than continuously walk without requiring persistent life
schedules.

### Work

- Add reservable activity spots with activity type, animation name, facing,
  duration range, capacity, and allowed roles.
- Begin with stand/wait and short wander using existing animations; add sit,
  lean, phone, smoke, talk, and browse as their verified animations become
  available.
- Let roaming civilians occasionally reserve a nearby compatible spot, travel
  to it, perform the activity, release it, and resume their route.
- Ensure solicitation, panic, damage, pooling, death, and despawn interrupt and
  release activities.
- Do not mutate shared AnimationTree resources per NPC.

### Acceptance

- Reservations prevent multiple NPCs from occupying a single-capacity spot.
- Every interruption path releases the reservation.
- Missing animations fall back safely to standing idle.
- Existing solicitation and panic behavior remains intact.

## Pass 6 - Store Customer Visits

**Status:** Implementation complete July 17, 2026; focused user-run verification
is pending. Both Hood East stores now expose a one-customer reservable visit
flow driven by transient presentation tickets from authoritative passive sales.

### Outcome

Visible NPC behavior represents the passive store economy without controlling
the authoritative ledger.

### Work

- Add reservable entrance, browse/counter, and exit destinations to both stores.
- Let eligible ambient civilians accept store-visit tasks when the store is
  open and stocked.
- Have visitors walk in, browse or wait, perform a purchase presentation, and
  leave through the pedestrian network.
- Treat visits as presentation of already scheduled passive sales; do not make
  business income depend on whether the player is nearby or an NPC is loaded.

### Acceptance

- Nearby players can observe believable visits at both stores.
- Visitors release all destinations when interrupted.
- Off-screen stores continue processing the same authoritative passive ledger.

## Pass 7 - Dealer Activity Zones

**Status:** Implemented July 17, 2026; focused user-run verification pending.

### Outcome

Dealer sites are authored groups with varied presentation and stable identity.

### Work

- Replace simple circular placement with persistent dealer activity zones.
- Retire the legacy `DealerSpawner`. `DealerActivityZone3D` is the single
  spawning and persistence system for permanent street dealers.
- Author exactly two zones per territory with 3–5 members in each zone and at
  least one level-1 dealer somewhere in every territory.
- Configure each zone with territory, faction, group size, dealer levels,
  standing/activity spots, and one required interactable dealer position.
- Use different available activities across group members.
- Pair talking members so they face one another. Leaning members navigate to
  the nearest reachable building wall and fall back to Idle when none is safe.
- Alert nearby same-territory dealers when the player damages a member so the
  group joins the fight instead of ignoring an attack beside them.
- Respawn defeated permanent dealers after one in-game hour unless the
  territory is at `100` Reputation. Clamp older longer deadlines when
  migrating existing saves.
- Add faction-change hooks but do not connect stash supply until Pass 9.

### Acceptance

- Dealers do not overlap and do not all play the same presentation.
- At least one living, non-hostile dealer remains available for interaction.
- Combat and dealer stock tests continue to pass.
- Zone identity and faction survive save/load.

## Pass 8 - Territory Takeover Event

**Status:** Implemented July 17, 2026; focused user-run verification pending.

### Outcome

Hood East supports recurring negative-Reputation gang wars and three deliberate
territory-claim routes without silently granting ownership from Reputation.

### Work

- Roll hourly gang-war risk at `5%`, `15%`, `30%`, or `50%` as negative
  Reputation crosses `-1`, `-25`, `-50`, and `-75`.
- Run three dealer waves over 60 real seconds. A win adds `15` Reputation and a
  loss subtracts `10`; three saved wins claim the territory.
- Suspend wanted-level escalation for the 60-second war so gunshots and dealer
  casualties cannot pull police into the encounter. Restore any wanted level
  the player already had when the war ends, including across save/load.
- At `+100` Reputation, allow a `$100,000` Dirty Cash purchase or a complete
  wipe of all permanent rival dealer-zone members.
- Route every success through one claim operation that sets player ownership,
  sets Reputation to `+100`, and converts the dealer zones exactly once.
- Award dealer-kill EXP immediately; require a corpse search within 20 seconds
  to collect permanent dealers' Dirty Cash and remaining stock.

### Acceptance

- Reputation alone never silently changes ownership.
- Gang-war wins, cooldown, active encounter state, dealer-zone state, and
  ownership survive save/load.
- Temporary gang-war attackers award EXP but cannot be farmed for cash or stock.
- Completing any route converts the territory exactly once.

## Pass 9 - Stash-Supplied Player Dealers

**Status:** Implementation complete July 17, 2026; focused user-run verification pending.

### Outcome

Claimed-territory dealer sites become player-managed crews whose authoritative
sales consume local stash supply and return net Dirty Cash to the source stash.

### Work

- Begin claimed Hood East with all six permanent dealer slots vacant, then let
  the player hire and fire each slot from a Territory inventory tab.
- Hire every player dealer at Level 1 for `$500` Dirty Cash, then upgrade that
  employee to Levels 2–4 for `$1,000`, `$2,000`, and `$4,000`. Higher levels
  attempt sales every `120`, `90`, `60`, or `45` in-game minutes.
- Combine stashed 1g weed, coke, and fent across owned local stash houses.
  Bricks remain wholesale inventory until broken down.
- Consume product and deposit sale revenue atomically in the same source stash.
  Dealers retain a 10% commission; passive sales award no EXP, Reputation,
  Heat, wanted response, or carried-wallet cash.
- Process sales authoritatively even when the player is away. Nearby ambient
  customers may present a completed sale by approaching the hired dealer,
  performing a short exchange, and returning to their route.
- Show supply, per-stash cash, staffing, sale intervals, out-of-stock state,
  daily/lifetime gross, commission, and net revenue in the Territory tab. Keep
  a save-safe seven-day net-revenue history and render it as a line graph.
- Persist employment, schedules, and revenue. Fired or killed employees vacate
  their slots and must be hired again.

### Acceptance

- Claiming or migrating an already-owned territory never grants free employees.
- Player dealers cannot create product through timed restocking, and concurrent
  sales never exceed eligible territory stash supply.
- Every sale removes one gram product and deposits its net Dirty Cash into the
  same stash; moving stock updates availability immediately.
- Visible customer presentation cannot create, cancel, or duplicate revenue and
  releases reservations on every interruption path.
- Hiring, firing, dealer death, schedules, supply, and revenue survive save/load.
- The Territory menu renders above the gameplay HUD, needs no scrolling, and
  shows today immediately on its seven-day revenue graph.
- Rival and wholesaler stock, interaction, restocking, and respawn behavior
  remains unchanged.

## Pass 10 - One-Territory Pedestrian and Traffic Rebuild

### Outcome

Hood East becomes the reference authored network for later city expansion.

### Work

- Add connected sidewalks, designated crossings, activity/store destinations,
  branching directed lanes, intersection turns, and external connectors.
- Mark traffic entry, exit, spawn, stop-line, lane, speed, and dispatch points.
- Extend validation for disconnected sections, dead ends, invalid links,
  unsafe spawns, unreachable destinations, and signal mistakes.
- Tune following, stopping, intersection clearance, and blocked-car recycling.
- Make pedestrian crossing decisions conservative enough to avoid routine
  traffic collisions.

### Acceptance

- Cars can take multiple routes and do not depend on a single block loop.
- Cars obey signals and do not spawn inside intersections.
- Pedestrian destinations used by earlier passes remain reachable.
- Hood West is not rebuilt in this pass.

## Pass 11 - Police Cruiser Dispatch Foundation

### Outcome

Wanted police arrive through the world rather than appearing near the player.

### Work

- Represent reported crimes as structured incidents containing type, severity,
  position, territory, time, and last-known player position.
- Keep the current 0-3 star rules and foot police modes.
- Dispatch a cruiser after a response delay from an off-screen external traffic
  connector.
- Route it to a valid staging point near the incident, stop safely, and release
  officers into arrest, search, or combat behavior.
- Recycle the cruiser and officers safely after the response resolves.

### Acceptance

- One star remains arrest-focused.
- Witnessed gun violence and fatal violence retain their current escalation.
- A cruiser uses the road network, stops, and releases functioning officers.
- Police do not spawn beside the player merely because a star was added.

## Pass 12 - Vertical-Slice Integration Test

### Outcome

The complete reference territory can be played for 15-20 minutes without debug
commands and without systems contradicting one another.

### Work

- Add focused smoke tests for every new state boundary and save migration.
- Run all smoke tests sequentially.
- Perform the full Definition of Done play session.
- Record balance problems separately from correctness bugs.
- Update the project checkpoint and GDD current-foundation rules.

### Acceptance

Every Definition of Done item works in the same save, in the same territory,
without manual state injection.

## Deferred After the Vertical Slice

- Hood West and full-city network rollout.
- Persistent named NPC homes, jobs, and schedules.
- Exact front-business merchandise inventory.
- Civilian car ownership and general NPC vehicle entry/exit.
- Vehicle chases, ramming, roadblocks, SWAT, and coordinated cruiser tactics.
- Territory loss, citywide gang wars, wholesale logistics, crew management,
  business audits, and executive management interfaces.
- Final animation volume, onboarding, broad balance, and presentation polish.
