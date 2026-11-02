extends Node2D
## The look of a thrown prop hitting something: a puff of dust and a spray of wood splinters that
## fall, then it frees itself. Only a look.

const DUST := Color("8a7f74")
const DUST_LIGHT := Color("b8ab9b")
const SPLINTER := Color("b38c76")
const SPLINTER_DARK := Color("6e4f3e")
const PIXEL := 2.0
const DURATION := 0.45
const SPLINTERS := 9

var _time := 0.0


func _ready() -> void:
	z_index = 3


## Whether it has run its course.
func done() -> bool:
	return _time >= DURATION


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / DURATION
	# Dust: puffs that swell and thin out.
	for i in 6:
		var angle := TAU * i / 6.0 + 0.5
		var reach := lerpf(4.0, 18.0, t) * (0.7 + 0.3 * absf(sin(i * 1.7)))
		var at := Vector2.from_angle(angle) * reach + Vector2(0, -t * 6.0)
		var radius := lerpf(2.0, 1.0, t)
		if (i + int(_time * 24.0)) % 3 == 0 and t > 0.5:
			continue
		_disc(at, radius, DUST_LIGHT if i % 2 == 0 else DUST)
	# Splinters fly out and drop.
	for i in SPLINTERS:
		var angle := TAU * i / SPLINTERS + 0.2 * sin(i * 3.1)
		var speed := 22.0 + 10.0 * absf(sin(i * 2.3))
		var at := Vector2.from_angle(angle) * speed * t + Vector2(0, 30.0 * t * t)
		_pixel(at, SPLINTER if i % 3 else SPLINTER_DARK)


func _disc(at: Vector2, radius: float, colour: Color) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= radius * radius + 0.5:
				_pixel(at + Vector2(x, y) * PIXEL, colour)


func _pixel(at: Vector2, colour: Color) -> void:
	var snapped := at.snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(PIXEL, PIXEL) / 2.0, Vector2(PIXEL, PIXEL)), colour)
