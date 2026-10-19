class_name Torch
extends Node2D
## A torch on a wall or a stand, drawn as a placeholder bracket with a flame. It is lit at first.
## Flame draw takes the flame of the nearest lit one in range and puts it out. It is in the group
## "torches", which is where Almos looks for one, and has no body, so he walks through it.

## Emitted once, when the flame is drawn and the torch goes out.
signal put_out

## Whether the flame is burning.
var lit: bool:
	get:
		return _lit

var _lit := true

@onready var _flame: CanvasItem = $Flame


func _ready() -> void:
	_show()


## The flame is drawn out of it: it goes out. Says whether there was a flame to draw; an unlit
## torch has none, and nothing happens.
func draw() -> bool:
	if not _lit:
		return false
	_lit = false
	_show()
	put_out.emit()
	return true


# The flame is drawn only while it burns.
func _show() -> void:
	if _flame != null:
		_flame.visible = _lit
