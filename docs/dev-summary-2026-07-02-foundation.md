# Dev Summary — Main World and Gameplay Foundation

## Outcome

The new two-neighborhood World scene is now the permanent game entry point.
Hood East and Hood West have independent boundaries, Heat, Reputation, and
saved state. The old test map remains available as a sandbox.

## World Structure

`Scenes/Maps/World/world.tscn` now owns environment, territories, navigation,
spawn points, gameplay actors, and the world controller. Both neighborhoods
contain stable territory IDs and boundary volumes. The player, dealers, and
customers are placed in the shared Gameplay layer.

## Trading

Dealer purchases and customer sales now pass through `TradeService`.
Transactions validate before committing and return a `TradeResult`. Sales award
Dirty Cash, EXP, Reputation, and Heat together. Customers refuse sales at 76
Heat, and Heat decays over time.

## Saving

`F5` saves and `F9` loads a versioned single-slot JSON save. It preserves money,
inventory, progression, Health, Stamina, player transform, and territory state.
Stable product and territory IDs are used instead of scene paths.

## Player Testing

1. Start the project and confirm it opens the new World.
2. Buy product from either dealer.
3. Press Space near a customer, then interact with `E`.
4. Confirm local Heat and Reputation change on the HUD.
5. Use `F5`, change state or move, and use `F9` to restore it.
6. Travel into the other neighborhood and confirm its Heat and Reputation are
   independent.
