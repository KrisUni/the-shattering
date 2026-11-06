class_name Glint
extends Node2D
## A glint that catches the eye on something worth picking up: every so often a small four-pointed
## sparkle flares on it and fades, so a pickup reads apart from the floor dressing round it. Drawn in
## code on the art pixel grid. Only a look.

const CORE := Color("fbf5ef")
const ARM := Color("f2d3ab")

## How often it flares, in seconds.
@export var every := 2.6
## How long a flare lasts, in seconds.
@export var lasting := 0.45
## Where it may flare, around the node: each flare picks a spot in this box, in art pixels.
@export var area := Rect2(-8, -3, 16, 6)

var _time := 0.0
var _spot := Vector2.ZERO
var _count := 0


func _ready() -> void:
	z_index = 1
	# Things that glint do not flare all at once.
	_time = fposmod(global_position.x * 0.071 + global_position.y * 0.037, every)


func _process(delta: float) -> void:
	var before := _time
	_time = fposmod(_time + delta, every)
	if _time < before:
		_count += 1
		var seed := _count * 7 + int(absf(global_position.x))
		_spot = (area.position + Vector2(float(seed % 5) / 4.0 * area.size.x, float((seed / 5) % 3) / 2.0 * area.size.y)).round()
	queue_redraw()


func _draw() -> void:
	if _time > lasting:
		return
	var t := _time / lasting
	# It flares up to its full size half way, then shrinks away.
	var reach := roundi(2.0 * sin(PI * t))
	var fade := sin(PI * t)
	draw_rect(Rect2(_spot, Vector2.ONE), Color(CORE, fade))
	for i in range(1, reach + 1):
		var colour := Color(ARM, fade * (1.0 - 0.3 * float(i - 1)))
		for way in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_rect(Rect2(_spot + way * float(i), Vector2.ONE), colour)
