class_name PathBlocker
extends StaticBody2D
## A path blocker: a placeholder door or living roots that close a passage. While whole it is a body
## that blocks Almos and the enemies. It is flammable (a Flammable of kind path blocker): once it
## burns out it is open. It records its id in WorldState when it catches; the record is saved when
## Almos rests at a Checkpoint, and a Death undoes it. So a path blocker that caught is open at every
## return and whenever the room is built again, until a Death takes back one that burnt since the last
## rest: it is whole and closed again.

## What it is called in WorldState, stable across builds of the room. Each blocker needs its own.
@export var id: StringName

## Its width and height, in pixels, centred on the node.
@export var size := Vector2(16.0, 80.0)

## The part of it that catches Fire.
@export var flammable: Flammable

## How much larger than the body the box that catches Fire is, on each axis, in pixels, so that a
## swing or a fireball at the face of the body finds it.
const CATCH_MARGIN := 16.0

var _open := false
# The physics layer the body was made with, which it has again when it is whole.
var _home_layer := 0

## Whether it is open: burnt out, so that nothing blocks.
var open: bool:
	get:
		return _open

@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _shape: Polygon2D = $Look/Shape


func _ready() -> void:
	_home_layer = collision_layer
	var shape := RectangleShape2D.new()
	shape.size = size
	_body_shape.shape = shape
	var half := size / 2.0
	_shape.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	var catch_shape := RectangleShape2D.new()
	catch_shape.size = size + Vector2.ONE * CATCH_MARGIN
	flammable.get_node("CollisionShape2D").shape = catch_shape
	flammable.caught.connect(_on_caught)
	flammable.burned_out.connect(_on_burned_out)
	flammable.restored.connect(_on_restored)
	if WorldState.is_burnt(id):
		flammable.burn_out_now()


func _on_caught() -> void:
	WorldState.record_burnt(id)


# It has burnt out: nothing blocks any more.
func _on_burned_out() -> void:
	_open = true
	set_deferred(&"collision_layer", 0)


# It is whole again after a Death undid its burning: it blocks as before.
func _on_restored() -> void:
	_open = false
	set_deferred(&"collision_layer", _home_layer)
