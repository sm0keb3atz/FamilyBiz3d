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

## Saving

The prototype has one versioned JSON save slot:

- `F5`: Save
- `F9`: Load

It stores money, inventory, progression, Health, Stamina, player position and
facing, and each territory's Heat and Reputation. Missing, damaged, or
incompatible data is rejected without changing the current state.

## Deferred Systems

Police AI, arrests, stash houses, laundering, properties, and automated dealers
are future milestones built on this foundation.
