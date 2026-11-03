extends Node2D
## The small life of a Room, only a look: dust motes drifting slowly where the light falls, water
## gathering and dripping from points on the walls with a splash where it lands, and, over a chasm,
## pale motes drifting up out of the dark and fading. Everything is drawn on the art pixel grid, and
## each Room keeps its own rhythm (seeded from where it stands).

const PIXEL := 2.0
const DUST := Color(0.95, 0.88, 0.74)
const WATER := Color(0.62, 0.7, 0.86)
const WATER_LIGHT := Color(0.86, 0.92, 1.0)
const MOTE := Color(0.79, 0.88, 0.42)

## Where dust drifts, in the Room's coordinates.
@export var dust_area := Rect2(0, 64, 1152, 160)
## How many motes of dust drift at once.
@export var dust_count := 26
## Where drops of water fall from (a point on a wall) and how far they fall before they land.
@export var drips: PackedVector2Array = PackedVector2Array()
@export var drip_fall := 44.0
## Where motes rise out of a chasm, in the Room's coordinates; an empty rect for none.
@export var updraft_area := Rect2()
@export var updraft_count := 18

var _time := 0.0
var _seed := 0.0


func _ready() -> void:
	z_index = 1
	_seed = fposmod(global_position.x * 0.013 + global_position.y * 0.007, 1.0) * 100.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var t := _time + _seed
	# Dust: each mote drifts on its own slow loop, and twinkles in and out.
	for i in dust_count:
		var h := _rand(i)
		var speed := 4.0 + 6.0 * _rand(i + 50)
		var x := dust_area.position.x + fposmod(h * dust_area.size.x + t * speed, dust_area.size.x)
		var y := dust_area.position.y + fposmod(_rand(i + 100) * dust_area.size.y + sin(t * 0.6 + i) * 10.0 - t * 2.0, dust_area.size.y)
		var glint := 0.5 + 0.5 * sin(t * (0.8 + _rand(i + 150)) + i * 2.0)
		_pixel(Vector2(x, y), Color(DUST, 0.08 + 0.22 * glint))
	# Drips: a drop swells at the wall, falls, and splashes; each on its own cycle.
	for i in drips.size():
		var from := drips[i]
		var period := 2.8 + 2.4 * _rand(i + 200)
		var phase := fposmod(t + _rand(i + 250) * period, period)
		var swell := 1.6
		if phase < swell:
			_pixel(from, Color(WATER, 0.4 + 0.5 * phase / swell))
		elif phase < swell + 0.35:
			var fall := (phase - swell) / 0.35
			var at := from + Vector2(0.0, drip_fall * fall * fall)
			_pixel(at, Color(WATER_LIGHT, 0.9))
			_pixel(at + Vector2(0.0, -PIXEL), Color(WATER, 0.5))
		elif phase < swell + 0.75:
			var s := (phase - swell - 0.35) / 0.4
			var land := from + Vector2(0.0, drip_fall)
			var spread := 2.0 + 6.0 * s
			var a := 0.8 * (1.0 - s)
			_pixel(land + Vector2(-spread, 0.0), Color(WATER_LIGHT, a))
			_pixel(land + Vector2(spread, 0.0), Color(WATER_LIGHT, a))
			_pixel(land + Vector2(-spread * 0.5, -PIXEL * 2.0 * (1.0 - s)), Color(WATER, a))
			_pixel(land + Vector2(spread * 0.5, -PIXEL * 2.0 * (1.0 - s)), Color(WATER, a))
	# Updraft: pale motes rise out of the chasm, sway, and fade as they come up.
	if updraft_area.size != Vector2.ZERO:
		for i in updraft_count:
			var life := 6.0 + 4.0 * _rand(i + 300)
			var phase := fposmod(t + _rand(i + 350) * life, life) / life
			var x := updraft_area.position.x + _rand(i + 400) * updraft_area.size.x + sin(t * 0.9 + i) * 6.0
			var y := updraft_area.end.y - phase * updraft_area.size.y
			var a := sin(phase * PI) * 0.45
			_pixel(Vector2(x, y), Color(MOTE, a))


func _rand(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + _seed * 78.233) * 43758.5453, 1.0)


func _pixel(at: Vector2, colour: Color) -> void:
	var snapped := at.snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped, Vector2(PIXEL, PIXEL)), colour)
