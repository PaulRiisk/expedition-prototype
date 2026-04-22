# Blockshooter

A small prototype project built to experiment with different control schemes and simple room-based combat.
You play as a blue rectangle fighting through a series of rooms filled with enemies, trying to survive and reach the end.

The main goal of this project is to compare which control mode feels more fun and responsive.

---

## Features

* Movement with WASD
* Two control modes:

  * **Mode A (Default):** Auto-shoot while standing still (targets nearest enemy)
  * **Mode B (Alternative):** Manual aiming and shooting with mouse (can shoot while moving)
* 15 connected rooms with increasing difficulty
* 2 boss fights
* Enemy types:

  * Melee (red)
  * Ranged (orange)
  * Spread shooters (purple)
* HP system (5 lives) with invincibility frames after taking damage
* Attempt counter per session
* Room progression system (advance after clearing enemies)
* Game over and win screens
* Basic game feel elements (hit flash, screen shake, particles)

---

## Version 1.0 – Changes

* Added **attempt counter** (resets on win or mode switch)
* Added **purple projectiles** for spread enemies and Boss 2
* Improved **end screen** with attempt count and mode display
* Expanded to **15 rooms with 2 bosses**

  * Boss 1 (Room 10): charge attack
  * Boss 2 (Room 15): enhanced version with spread shots
* Implemented **anti-overlap system** for enemies (separation + spawn distance)
* Added **death and hit particles** (no external assets)
* Added **custom game icon (icon.svg)**

---

## Notes

This is a prototype and not a fully polished game.
You may encounter bugs or unexpected behavior.
