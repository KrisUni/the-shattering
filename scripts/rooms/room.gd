class_name Room
extends Node2D
## A single screen-sized space inside a building. While Almos is in it the camera is fixed to
## it, showing all of it and nothing more. Its position is its top left corner; leaving it
## through one of its RoomExits moves the view to the next Room.

## The Room's size in pixels: by default the project's window, so one Room fills the view.
@export var size := Vector2(1152, 648)


## The Room's extent, in global coordinates.
func get_rect() -> Rect2:
	return Rect2(global_position, size)


## The middle of the Room, in global coordinates: where the camera is put to show all of it.
func get_view_center() -> Vector2:
	return get_rect().get_center()
