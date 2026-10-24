class_name Doorway
extends Area2D
## Where one space is left for another: a door or a path at the edge of an Open map, or of a Room
## in a building. Almos walking into it is how he goes to the joined space: it tells the host,
## which loads that space and puts him at the Entrance of the Doorway there that this one is
## paired with. The two refer to each other by name.

## Tells that Almos has walked into this doorway.
signal used(doorway: Doorway)

## The scene of the space this doorway leads to.
@export_file("*.tscn") var destination: String
## The name of the Doorway in that space which this one is paired with, and where Almos arrives.
@export var destination_entrance: StringName

## Where Almos stands when he comes through this doorway from its pair: a little inside its own
## space, and clear of the doorway's area, so that arriving does not send him straight back.
@onready var entrance: Marker2D = $Entrance


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Almos:
		used.emit(self)
