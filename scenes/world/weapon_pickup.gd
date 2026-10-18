class_name WeaponPickup
extends Node2D
## A Weapon lying in a room, drawn as a placeholder bar. It holds the Weapon's data file in
## `weapon`, which is what Almos takes up when he picks it up with a tap of Interact; the pickup
## is then gone. Almos leaves one where he stands when he drops the Weapon in hand. It is in the
## group "weapon_pickups", which is where Almos looks for one, and has no body, so he walks
## through it, as through a Checkpoint.

## The Weapon lying here: its data file, such as data/spear.tres.
@export var weapon: WeaponData
