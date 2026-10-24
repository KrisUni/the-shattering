class_name ArmourPickup
extends Node2D
## A piece of Armour lying in a room, drawn as a placeholder plate. It holds the Armour's data
## file in `armour`, which is what Almos wears when he takes it with a tap of Interact; the pickup
## is then gone. The Armour is a placeholder until Armour and Load is done, so wearing it has no
## effect. It is in the group "armour_pickups", which is where Almos looks for one, and has no
## body, so he walks through it, as through a Checkpoint.
##
## A pickup that lies in a room has an `id`, and Almos taking it notes it taken in WorldState: it
## stays taken once he rests at a Checkpoint, and lies there again after a Death before one. A
## pickup with an id that is taken frees itself when it is made. One without an id is not tracked.

## The Armour lying here: its data file, such as data/almos_armour.tres.
@export var armour: ArmourData

## What it is called in WorldState, stable across builds of the room, or empty for a pickup that
## is not tracked.
@export var id: StringName


func _ready() -> void:
	if id != &"" and WorldState.is_taken(id):
		queue_free()
