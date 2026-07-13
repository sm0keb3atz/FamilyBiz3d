# Family Business — Current Gameplay Foundation

## Permanent World

`Scenes/Maps/World/world.tscn` is the permanent main world. It contains the
environment, Hood East and Hood West, navigation, stable spawn points, gameplay
actors, and the save/load controller.

Each territory owns a permanent ID, boundary, Heat, and Reputation. Current IDs
are `hood_east` and `hood_west`. Saved data uses these IDs, not scene paths.

## Trading Rules

All purchases and sales use the central trade service. A transaction either
applies every cost and reward, or changes nothing.

A successful sale removes one product, adds Dirty Cash and EXP, and adds the
product's Reputation and Heat rewards to the territory where it occurred. At
76 or more Heat, customers in that territory refuse sales. Heat decays over
time, and both neighborhoods track their state independently.

Street solicitation is inventory-adaptive. Each selected customer chooses a
gram product the player currently carries, prioritizing the largest remaining
stack. Customer level controls only the requested quantity: Level 1 buys
`1-4g`, Level 2 `5-10g`, Level 3 `10-20g`, and Level 4 `20-40g`. Approaching
and waiting customers reserve their quantities so the same inventory is not
promised twice. Bricks must be broken down before street sale.

Hustle starts at `1`. It attracts at least two customers per solicitation,
adds one customer per point up to six, and adds `5%` street-sale cash and EXP
per point after the first. Current street prices are `$18/g` Weed, `$90/g`
Coke, and `$105/g` Fent.

## Saving

The prototype has one versioned JSON save slot:

- `F5`: Save
- `F9`: Load

It stores money, inventory, progression (including Hustle), Health, Stamina, player position and
facing, and each territory's Heat and Reputation. Missing, damaged, or
incompatible data is rejected without changing the current state.

## Deferred Systems

Police AI, arrests, stash houses, laundering, properties, and automated dealers
are future milestones built on this foundation.
