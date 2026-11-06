class_name AirRipple
extends Node2D
## The air rippling in the wake of a thing Shoved: faint pale arcs left behind it as it flies, each
## widening and fading. It follows the thing for a while and then frees itself. Drawn in code on
## the art pixel grid. Only a look.

const PALE := Color("f2d3ab")

@export var lifetime := 0.5
## How often an arc is left, in seconds.
@export var every := 0.05

var target: Node2D
var _age := 0.0
var _since := 0.0
var _last := Vector2.ZERO
var _arcs: Array[Dictionary] = []


## A wake behind this thing, in this parent.
static func trail(parent: Node, thing: Node2D) -> AirRipple:
	var ripple := AirRipple.new()
	ripple.target = thing
	parent.add_child(ripple)
	ripple.global_position = Vector2.ZERO
	ripple._last = thing.global_position
	return ripple


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_age += delta
	_since += delta
	if is_instance_valid(target) and _age < lifetime and _since >= every:
		var now := target.global_position
		var way := now - _last
		if way.length() > 0.5:
			_arcs.append({"at": now - way.normalized() * 8.0, "way": way.normalized(), "age": 0.0})
		_last = now
		_since = 0.0
	for arc in _arcs:
		arc["age"] += delta
	_arcs = _arcs.filter(func(arc: Dictionary) -> bool: return arc["age"] < 0.3)
	if _age >= lifetime and _arcs.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for arc in _arcs:
		var t: float = arc["age"] / 0.3
		var across: Vector2 = Vector2(-arc["way"].y, arc["way"].x)
		var width := 3.0 + 5.0 * t
		var colour := Color(PALE, 0.55 * (1.0 - t))
		for k in range(-int(width), int(width) + 1):
			var bend := absf(float(k)) / width
			var at: Vector2 = (arc["at"] + across * float(k) + arc["way"] * (bend * bend * 3.0)).round()
			draw_rect(Rect2(at, Vector2.ONE), colour)
