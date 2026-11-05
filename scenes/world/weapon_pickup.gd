class_name WeaponPickup
extends Node2D
## A Weapon lying in a room, drawn as a placeholder bar, or as its `art` where it has some. It holds the Weapon's data file in
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

## How it lies on the floor, drawn in place of the placeholder bar: a picture centred on it, such
## as the fallen jailer's sword (assets/dungeons/furniture/sword_floor.png). Left empty, the bar shows.
@export var art: Texture2D


func _ready() -> void:
	if id != &"" and WorldState.is_taken(id):
		queue_free()
		return
	if art != null:
		var bar := get_node_or_null("Look/Bar") as CanvasItem
		if bar != null:
			bar.visible = false
		var sprite := Sprite2D.new()
		sprite.name = "Art"
		sprite.texture = art
		get_node("Look").add_child(sprite)
