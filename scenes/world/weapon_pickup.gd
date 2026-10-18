class_name WeaponPickup
extends Node2D
## A Weapon lying in a room, drawn as a placeholder bar. It holds the Weapon's data file in
## `weapon`, which is what Almos will take up when picking it up arrives. It is in the group
## "weapon_pickups", which is where Almos will look for one, and has no body, so he walks through
## it, as through a Checkpoint.

## The Weapon lying here: its data file, such as data/spear.tres.
@export var weapon: WeaponData
