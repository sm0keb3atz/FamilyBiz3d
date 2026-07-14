# Family Business — Current Gameplay Foundation

## Permanent World

`Scenes/Maps/World/world.tscn` is the permanent main world. It contains the
environment, Hood East and Hood West, navigation, stable spawn points, gameplay
actors, and the save/load controller.

Each territory owns a permanent ID, boundary, Heat, signed `-100..100`
Reputation, ownership state, rival-pressure tier, and takeover availability.
Current IDs are `hood_east` and `hood_west`. Saved data uses these IDs, not
scene paths. Older saves migrate to neutral ownership without losing positive
Reputation.

## Trading Rules

All purchases and sales use the central trade service. A transaction either
applies every cost and reward, or changes nothing. Each territory receives one
saved set of daily dealer prices. Most rolls stay within `85-115%` of the
configured dealer price, with occasional `70-84%` low and `116-130%` high
outliers. Quotes reroll exactly once when the in-game date advances.

Customers pay a markup over the current local dealer price rather than using a
second unrelated quote. Hustle 1 pays `70%` over the dealer price, and every
additional Hustle level adds `15%`, reaching `205%` over dealer price at Hustle
10. The final total is rounded to whole dollars. The same per-level Hustle bonus
applies to EXP without the base cash markup, reaching `135%` bonus at Hustle 10.

A successful sale removes one product, adds Dirty Cash and EXP, and adds the
product's Reputation and Heat rewards to the territory where it occurred. At
76 or more Heat, customers in that territory refuse sales. Heat decays over
time, and both neighborhoods track their state independently.

Reputation grows more slowly than product volume: Weed awards `0.15 Rep/g`,
Coke `0.30 Rep/g`, and Fent `0.45 Rep/g`. Selling 100g therefore earns 15, 30,
or 45 Reputation rather than completing the territory progression outright.

Street solicitation is inventory-adaptive. Each selected customer chooses a
gram product the player currently carries, prioritizing the largest remaining
stack. Customer level controls only the requested quantity: Level 1 buys
`1-4g`, Level 2 `5-10g`, Level 3 `10-20g`, and Level 4 `20-40g`. Approaching
and waiting customers reserve their quantities so the same inventory is not
promised twice. A single customer can take at most 50% of an available stack at
Hustle 1, scaling gradually to 72.5% at Hustle 10, except when only one unit
remains. Bricks must be broken down before street sale.

Hustle starts at `1`. It attracts at least two customers per solicitation,
adds one customer per point up to six, and adds `15%` street-sale cash and EXP
per point after the first. Customer cash also starts with a `70%` base markup
over the local dealer quote. Hustle improves customer quality: at Hustle 1 the
level chances are `88% / 11% / 1% / 0%`, while at Hustle 10 they are
`38% / 31% / 23% / 8%`. Configured dealer-price anchors are `$8/g` Weed,
`$45/g` Coke, and `$30/g` Fent. Their randomized local dealer prices appear
beside the icons in the territory HUD. Reputation price adjustments are
deferred.

## Saving

The prototype has one versioned JSON save slot:

- `F5`: Save
- `F9`: Load

It stores money, inventory, progression (including Hustle), Health, Stamina, player position and
facing, each territory's Heat/Reputation/owner state, and the generated daily
market date and dealer quotes. Missing market data from an older save generates one
set for the loaded date. Damaged or incompatible data is rejected without
changing the current state.

## Deferred Systems

Police AI, arrests, stash houses, laundering, properties, and automated dealers
are future milestones built on this foundation.
