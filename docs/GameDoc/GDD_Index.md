# Family Business — Game Design Document Index

## Game Overview

**Family Business** is a low-poly life simulator and empire-management game.
The player begins as a street dealer, builds territory, buys property, cleans
dirty money, and eventually manages a city-wide wholesale network.

## Design Documents

1. [Core Concept and Design Pillars](GDD_Core_Concept.md)
2. [Player Stats System](GDD_Player_Stats.md)
3. [Territory Stats and Heat](GDD_Territory_Stats.md)
4. [Money and Economy System](GDD_Money_System.md)
5. [Current Gameplay Foundation](GDD_Gameplay_Foundation.md)

## Technical Foundation

The project is built in **Godot 4.7**. The permanent game composition root is
`Scenes/Maps/World/world.tscn`. It owns shared environment, navigation, spawn
points, gameplay actors, and the two current territory scenes.

The player is component-based. Movement, animation, camera, stats, health,
weapons, wallet, inventory, interaction, solicitation, appearance, and trading
are separate child components beneath the player scene.

`Scenes/Maps/test_map.tscn` remains an isolated development sandbox.
