class_name TestOpenMap
extends Node2D
## A placeholder Open map: one continuous area, bigger than the screen, that the camera follows
## Almos through. It stands in for a real Open map until there is one, and is where Open maps
## are tried out.

## The map's extent, in global coordinates. The camera never shows beyond it.
@export var bounds := Rect2(0, 0, 2304, 1296)

@onready var _camera: OpenMapCamera = $Camera


func _ready() -> void:
	_camera.bounds = bounds
