class_name DustPuff
extends Node2D
## A little puff of dust kicked up from the floor: a few motes that burst out from where it is put,
## drift up and away and fade, then it is gone. Drawn in code on the art pixel grid, in the floor's
## own muted earth. Only a look.

# From the first moment to the last: a pale mote catching the light, fading into the floor's dark.
const COLOURS := [Color("a5938a"), Color("8a7a80"), Color("6f6066")]

## How many motes it throws.
@export var count := 4
## How far they spread, in art pixels, by the end.
@export var spread := 7.0
## Which way they mostly go, a unit vector; zero for every way, a ring round the place.
@export var heading := Vector2.ZERO
## How long it lasts, in seconds.
@export var lifetime := 0.4

var _age := 0.0
var _motes: Array[Vector2] = []


## A puff put in this parent at this global place.
static func kick(parent: Node, at: Vector2, motes := 4, reach := 7.0, way := Vector2.ZERO) -> DustPuff:
	var puff := DustPuff.new()
	puff.count = motes
	puff.spread = reach
	puff.heading = way
	parent.add_child(puff)
	puff.global_position = at.round()
	return puff


func _ready() -> void:
	z_index = -1
	var seed := int(absf(global_position.x * 7.0 + global_position.y * 13.0))
	for i in count:
		var angle: float
		if heading == Vector2.ZERO:
			angle = TAU * (float(i) + 0.5 * float((seed + i) % 2)) / float(count)
		else:
			angle = heading.angle() + (float(i) / maxf(float(count - 1), 1.0) - 0.5) * 1.6
		# Each goes out its own way, a little up as well, as dust rises.
		_motes.append(Vector2(cos(angle), sin(angle) * 0.45 - 0.35) * (0.7 + 0.3 * float((seed + i * 3) % 4) / 3.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var out := 1.0 - (1.0 - t) * (1.0 - t)
	var colour: Color = COLOURS[mini(int(t * COLOURS.size()), COLOURS.size() - 1)]
	colour.a = 1.0 - t * t
	for mote in _motes:
		var at := (mote * spread * out).round()
		# Big at first, a single pixel as it thins.
		var size := 2.0 if t < 0.45 else 1.0
		draw_rect(Rect2(at, Vector2(size, size)), colour)
