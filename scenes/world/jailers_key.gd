class_name JailersKey
extends Node2D
## The Jailer's key lying in a room, drawn as a placeholder bar. It waits hidden while the key
## jailer lives, and when he dies it lies where he fell. Almos takes it with a tap of Interact, and
## the taking is kept for good: WorldState notes it taken at once, so a Death does not put it back.
## It is in the group "key_pickups", which is where Almos looks for one, and has no body, so he
## walks through it, as through a Checkpoint.
##
## A room built with the key jailer already dead and the key not taken, as after a Death before
## taking it, shows the key where it is placed, at his post. A key that is taken frees itself when
## it is made.

## What it is called in WorldState, stable across builds of the room.
@export var id: StringName

## The key jailer, whose death lets the key be taken. It may be empty, or gone from a room built
## after he died.
@export var jailer: Node

## Whether Almos can take it: not while the key jailer lives.
var takeable := true


func _ready() -> void:
	if WorldState.is_taken(id):
		queue_free()
		return
	if is_instance_valid(jailer) and not jailer.is_queued_for_deletion():
		takeable = false
		visible = false
		jailer.died.connect(_on_jailer_died)


# He announces his death just before he leaves the room, so he still stands where he fell.
func _on_jailer_died() -> void:
	global_position = jailer.global_position
	takeable = true
	visible = true
