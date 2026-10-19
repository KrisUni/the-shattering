class_name HidingSpot
extends Node2D
## A Hiding spot: a place Almos can get into with a tap of Interact within reach, such as a barrel,
## a bed or a curtain. It is drawn as a placeholder, is in the group "hiding_spots", which is where
## Almos looks for one, and has no body, so he walks through it. What it does to him and to the
## enemies is Almos's and the enemies' business; the spot only marks the place.
## Every one is flammable: it has a Flammable that sets it alight and burns it away.

## The part of it that catches Fire. Once it is burnt out the spot is no longer one: it leaves the
## group, so he cannot get in. Optional.
@export var flammable: Flammable


func _ready() -> void:
	if flammable != null:
		flammable.burned_out.connect(_on_burned_out)


func _on_burned_out() -> void:
	remove_from_group(&"hiding_spots")
