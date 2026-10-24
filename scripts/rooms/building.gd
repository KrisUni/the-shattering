class_name Building
extends Node2D
## A building made of Rooms. The camera is fixed to the Room Almos is in; when he leaves it
## through a RoomExit he is put at the Entrance of the paired exit, in the next Room, and the
## camera moves there. Rooms are its children, side by side in world space and not overlapping.

## Tells that Almos has come into a Room, with the Room he is in now.
signal room_changed(room: Room)

## Almos, who is in the building.
@export var almos: Almos
## The Room Almos starts in.
@export var start_room: Room

## The Room Almos is in.
var current_room: Room

@onready var _camera: Camera2D = $Camera


func _ready() -> void:
	for child in get_children():
		for room_exit in child.find_children("*", "RoomExit", true, false):
			room_exit.used.connect(_on_exit_used)
	current_room = start_room
	_camera.global_position = current_room.get_view_center()


func _on_exit_used(room_exit: RoomExit) -> void:
	# Moving a body is not allowed in the middle of the physics step the exit was entered in.
	_travel.call_deferred(room_exit)


func _travel(room_exit: RoomExit) -> void:
	var target := room_exit.target
	if target == null:
		push_warning("%s has no exit to go to" % room_exit.name)
		return
	almos.global_position = target.entrance.global_position
	current_room = target.get_room()
	_camera.global_position = current_room.get_view_center()
	room_changed.emit(current_room)
