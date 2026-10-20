class_name Torch
extends Node2D
## A torch on a wall or a stand, drawn as a placeholder bracket with a flame. It is lit at first.
## Pull takes the flame of the nearest lit one in range and puts it out. It is in the group
## "torches", which is where Almos looks for one, and has no body, so he walks through it.
## While it burns it lights the area around it, which is what enemies read at Almos's position
## to tell how far they see (see LightZone.light_at). A rest or a Death relights it.

## Emitted once, when the flame is drawn and the torch goes out. Going out quietly (see
## extinguish) is not a draw and does not emit it.
signal put_out

## The numbers of its light. They live in data/torch_light.tres.
@export var tuning: TorchTuning = preload("res://data/torch_light.tres")

## The gameplay light it gives within its radius while lit.
var light: float:
	get:
		return tuning.light

## How far from it, in pixels, its light reaches.
var radius: float:
	get:
		return tuning.radius

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


## The torch goes out without being drawn, and says nothing: put_out is for a draw only. Almos
## does this to the torch he carries when it leaves his hand. A torch already out is left as it is.
func extinguish() -> void:
	_lit = false
	_show()


## The flame burns again. Says whether it was out; a lit torch is left as it is.
func relight() -> bool:
	if _lit:
		return false
	_lit = true
	_show()
	return true


## Whether the torch lights this point (global coordinates): it is lit and the point is within its
## radius, the edge included.
func lights(point: Vector2) -> bool:
	return _lit and global_position.distance_to(point) <= radius


# The flame is drawn only while it burns.
func _show() -> void:
	if _flame != null:
		_flame.visible = _lit
