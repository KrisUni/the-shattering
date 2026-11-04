class_name JailersKey
extends Node2D
## The Jailer's key, kept in the key crate in Radio/Officers (scenes/world/key_crate.tscn), where it
## does not show. Almos takes it with a tap of Interact within reach, beside the crate, and the
## taking is kept for good: WorldState notes it taken at once, so a Death does not put it back.
## It is in the group "key_pickups", which is where Almos looks for one, and has no body of its own.
## A key that is taken frees itself when it is made.

## What it is called in WorldState, stable across builds of the room.
@export var id: StringName

## Whether Almos can take it. It always can while it is there.
var takeable := true


func _ready() -> void:
	if WorldState.is_taken(id):
		queue_free()
