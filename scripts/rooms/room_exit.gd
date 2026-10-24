class_name RoomExit
extends Area2D
## Where a Room is left: a thin strip along one of its edges, or, with a smaller shape, a door.
## It is a child of the Room it leaves. Almos walking into it is how he goes to the next Room:
## it tells the Building, which puts him at the Entrance of the exit it is paired with.

## Tells that Almos has walked into this exit.
signal used(room_exit: RoomExit)

## The exit in the next Room that this one leads to. The two refer to each other.
@export var target: RoomExit

## Where Almos stands when he comes through this exit: a little inside its own Room, and clear
## of the exit's area, so that arriving does not send him straight back.
@onready var entrance: Marker2D = $Entrance


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## The Room this exit leaves.
func get_room() -> Room:
	return room_of(self)


## The Room this node is in, at whatever depth, or null if it is in none.
static func room_of(node: Node) -> Room:
	var ancestor := node.get_parent()
	while ancestor != null and not ancestor is Room:
		ancestor = ancestor.get_parent()
	return ancestor as Room


func _on_body_entered(body: Node2D) -> void:
	if body is Almos:
		used.emit(self)
