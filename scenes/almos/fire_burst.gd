class_name FireBurst
extends Node2D
## The look of a fireball bursting where it hits: a white-hot flash, a ring of fire that runs out to
## the splash radius (so it shows how far the splash reaches), sparks thrown outward, and smoke
## that rises as it dies down. It frees itself when it is over. It is only a look: the damage and
## the Fire are the fireball's own. It leaves a scorch on the ground under everything that fades
## away over a few seconds.
##
## Palette colours on the art pixel grid: cream, sand and Fire amber for the fire, dusty rose and
## slate for the smoke, navy and slate for the scorch.

const CREAM := Color("fbf5ef")
const SAND := Color("f2d3ab")
const AMBER := Color("f29a2e")
const ROSE := Color("c69fa5")
const SLATE := Color("494d7e")
const NAVY := Color("272744")

# In units. One art pixel.
const PIXEL := 2.0
## In seconds. How long the fire of the burst lasts, and how long its scorch stays on the ground.
const DURATION := 0.5
const SCORCH_TIME := 3.0
## In seconds. How long the ring takes to reach the splash radius.
const RING_TIME := 0.22
const SPARKS := 12

## In units. How far the ring runs: the fireball's splash radius.
var radius := 48.0

var _time := 0.0
var _spark_angles: Array[float] = []
var _spark_speeds: Array[float] = []


var _scorch: Node2D


func _ready() -> void:
	z_index = 2
	# The scorch draws under Almos and everything standing, on the floor.
	_scorch = Node2D.new()
	_scorch.z_as_relative = false
	_scorch.z_index = -1
	_scorch.draw.connect(_draw_scorch)
	add_child(_scorch)
	# The sparks fly at fixed, evenly spread angles with uneven speeds: no randomness, so the burst
	# looks the same every time and tests are steady.
	for i in SPARKS:
		_spark_angles.append(TAU * i / SPARKS + 0.3 * sin(i * 2.1))
		_spark_speeds.append(0.7 + 0.3 * absf(sin(i * 1.7)))


## Sets the burst going at this point in the world, its ring running out to this radius.
func burst(at: Vector2, splash_radius: float) -> void:
	global_position = at
	if splash_radius > 0.0:
		radius = splash_radius


## Whether the fire of the burst is over, leaving only its scorch.
func burnt_down() -> bool:
	return _time >= DURATION


func _process(delta: float) -> void:
	_time += delta
	if _time >= SCORCH_TIME:
		queue_free()
		return
	queue_redraw()
	_scorch.queue_redraw()


# A blackened patch, its edge ragged, thinning away as it fades.
func _draw_scorch() -> void:
	var fade := clampf((_time - DURATION) / (SCORCH_TIME - DURATION), 0.0, 1.0)
	var reach := radius * 0.45
	var step := PIXEL
	var y := -reach
	while y <= reach:
		var x := -reach
		while x <= reach:
			var d := Vector2(x, y * 1.6).length()
			var ragged := reach * (0.8 + 0.2 * sin(atan2(y, x) * 5.0))
			if d <= ragged:
				var cell := int(x / step) + int(y / step) * 7
				# Thins out as it fades: more of its pixels drop each moment.
				if fposmod(cell * 0.618, 1.0) >= fade:
					var colour := NAVY if d < ragged * 0.6 else SLATE
					_scorch.draw_rect(Rect2(Vector2(x, y).snapped(Vector2(step, step)), Vector2(step, step)), colour)
			x += step
		y += step


func _draw() -> void:
	if _time >= DURATION:
		return
	var t := _time / DURATION
	# The flash: a white-hot core that shrinks fast.
	if _time < 0.08:
		_disc(Vector2.ZERO, 7.0, SAND)
		_disc(Vector2.ZERO, 5.0, CREAM)
	elif _time < 0.18:
		_disc(Vector2.ZERO, 5.0, AMBER)
		_disc(Vector2.ZERO, 3.0, SAND)
	# The ring: runs out to the splash radius, then thins and fades by dropping pixels.
	var ring_t := clampf(_time / RING_TIME, 0.0, 1.0)
	var ring_radius := lerpf(6.0, radius, 1.0 - pow(1.0 - ring_t, 2.0))
	if _time < RING_TIME + 0.12:
		var steps := int(ring_radius * 0.9) + 8
		var keep_every := 1 if _time < RING_TIME else 2
		for i in steps:
			if i % keep_every != 0:
				continue
			var angle := TAU * i / steps
			var point := Vector2.from_angle(angle) * ring_radius
			var colour := AMBER if ring_t < 0.6 else (SAND if i % 3 else ROSE)
			_pixel(point, PIXEL * (2.0 if ring_t < 0.5 else 1.0), colour)
	# Sparks fly out and slow down.
	if t < 0.8:
		for i in SPARKS:
			var travel := radius * 0.9 * _spark_speeds[i] * (1.0 - pow(1.0 - minf(t / 0.8, 1.0), 3.0))
			var point := Vector2.from_angle(_spark_angles[i]) * travel
			var colour := CREAM if t < 0.25 or i % 4 == 0 else AMBER
			_pixel(point, PIXEL, colour)
	# Smoke rises as it dies down.
	if t > 0.35:
		var smoke_t := (t - 0.35) / 0.65
		for i in 5:
			var x := (i - 2) * 9.0 + sin(i * 1.3) * 3.0
			var point := Vector2(x, -smoke_t * 26.0 - absf(x) * 0.3)
			if (i + int(_time * 20.0)) % 4 == 0:
				continue
			_pixel(point, PIXEL * (2.0 if smoke_t < 0.5 else 1.0), ROSE if smoke_t < 0.5 else SLATE)


# A round blob of art pixels, this many art pixels in radius.
func _disc(at: Vector2, radius: float, colour: Color) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= radius * radius + 0.5:
				_pixel(at + Vector2(x, y) * PIXEL, PIXEL, colour)


func _pixel(at: Vector2, size: float, colour: Color) -> void:
	var snapped := at.snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(size, size) / 2.0, Vector2(size, size)), colour)
