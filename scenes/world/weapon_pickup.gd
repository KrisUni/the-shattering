class_name WeaponPickup
extends Node2D
## A Weapon lying in a room, drawn as a placeholder bar. It holds the Weapon's data file in
## `weapon`, which is what Almos takes up when he picks it up with a tap of Interact; the pickup
## is then gone. Almos leaves one where he stands when he drops the Weapon in hand. It is in the
## group "weapon_pickups", which is where Almos looks for one, and has no body, so he walks
## through it, as through a Checkpoint.
##
## A pickup that lies in a room has an `id`, and Almos taking it notes it taken in WorldState: it
## stays taken once he rests at a Checkpoint, and lies there again after a Death before one. A
## pickup with an id that is taken frees itself when it is made. One without an id, such as the
## one Almos leaves when he drops a Weapon, is not tracked.

## The Weapon lying here: its data file, such as data/spear.tres.
@export var weapon: WeaponData

## What it is called in WorldState, stable across builds of the room, or empty for a pickup that
## is not tracked.
@export var id: StringName


func _ready() -> void:
	if id != &"" and WorldState.is_taken(id):
		queue_free()
