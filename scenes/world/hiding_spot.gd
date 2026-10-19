class_name HidingSpot
extends Node2D
## A Hiding spot: a place Almos can get into with a tap of Interact within reach, such as a barrel,
## a bed or a curtain. It is drawn as a placeholder, is in the group "hiding_spots", which is where
## Almos looks for one, and has no body, so he walks through it. What it does to him and to the
## enemies is Almos's and the enemies' business; the spot only marks the place.
## Every one is flammable: it has a Flammable that sets it alight and burns it away.

## The part of it that catches Fire. Once it burns, and until it is whole again after a return, the
## spot is no longer one: it leaves the group, so he cannot get in. Optional.
@export var flammable: Flammable


func _ready() -> void:
	if flammable != null:
		flammable.caught.connect(_on_caught)
		flammable.burned_out.connect(_on_burned_out)
		flammable.restored.connect(_on_restored)


# It is burning: he cannot get into it.
func _on_caught() -> void:
	remove_from_group(&"hiding_spots")


func _on_burned_out() -> void:
	remove_from_group(&"hiding_spots")


# It is whole again after a return: Almos can get into it once more.
func _on_restored() -> void:
	add_to_group(&"hiding_spots")
