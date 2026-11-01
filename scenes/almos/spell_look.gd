class_name SpellLook
extends Node2D
## How Almos's Pull looks. While he winds up a Pull on a torch or a Fire, the flame streams from it
## to his hand as two twisting strands: one of fire (Fire amber, sand, cream) and one of the magic
## that draws it (Ilion violet-magenta, the accent of Channelling). The stream keeps flowing a moment
## after the release, and the flame lands with a flash. While he holds the flame, a few magenta
## sparks circle it. Everything is drawn on the art pixel grid, in palette colours.
##
## It only reads AlmosSpell; no gameplay depends on it. It draws in world space (top_level), so it
## is not turned or tinted with his Look.

const AMBER := Color("f29a2e")
const SAND := Color("f2d3ab")
const CREAM := Color("fbf5ef")
const MAGENTA := Color("d23fd0")

# In units. One art pixel.
const PIXEL := 2.0
# How many motes each strand carries, and how fast a mote crosses the whole way, in crossings a
# second.
const MOTES := 13
const FLOW := 2.6
# In units. How far the two strands swing apart in the middle of the way.
const SWING := 16.0
# In seconds. How long the stream keeps flowing after the release, and how long the landing flash
# lasts.
const AFTERFLOW := 0.25
const FLASH := 0.18
# In units, from Almos. Where the flame lands: his raised hand, and where a held flame hovers.
const HAND := Vector2(0, -20)
const HOVER := Vector2(0, -62)
# In units, from a torch. Where its flame burns.
const TORCH_FLAME := Vector2(0, -22)

## The AlmosSpell whose Pull it shows.
@export var spell: AlmosSpell

var _time := 0.0
# Where the stream comes from, kept after the release so the afterflow knows.
var _source := Vector2.ZERO
var _streaming_for := -1.0
var _since_release := -1.0
var _was_winding_up := false


func _ready() -> void:
	top_level = true
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	if spell == null:
		return
	var from := spell.drawing_from
	if from != null:
		_source = _flame_point(from)
		if not _was_winding_up:
			_streaming_for = 0.0
		_streaming_for += delta
		_was_winding_up = true
	elif _was_winding_up:
		_was_winding_up = false
		_since_release = 0.0 if spell.holding else -1.0
		if not spell.holding:
			_streaming_for = -1.0
	if _since_release >= 0.0:
		_since_release += delta
		if _since_release > maxf(AFTERFLOW, FLASH):
			_since_release = -1.0
			_streaming_for = -1.0
	queue_redraw()


## Whether the stream is showing now: during a wind-up and the afterflow after its release.
func streaming() -> bool:
	return _streaming_for >= 0.0


## Whether the landing flash is showing now.
func flashing() -> bool:
	return _since_release >= 0.0 and _since_release <= FLASH


func _draw() -> void:
	if spell == null:
		return
	var almos := spell.body
	if almos == null:
		return
	var hand := almos.global_position + HAND
	if streaming():
		_draw_stream(_source, hand)
		if _since_release < 0.0:
			_draw_grip(_source, spell.wind_up_progress)
	if flashing():
		_draw_flash(hand, _since_release / FLASH)
	if spell.holding:
		_draw_orbit(almos.global_position + HOVER)


# Two strands of motes from the source to the hand, twisting about each other.
func _draw_stream(from: Vector2, to: Vector2) -> void:
	var along := to - from
	if along.length() < 1.0:
		return
	var across := along.orthogonal().normalized()
	# While winding up, motes only reach as far as the wind-up has got; in the afterflow, the last
	# of them drain into the hand.
	var reach := 1.0 if _since_release >= 0.0 else clampf(_streaming_for * FLOW * 1.5, 0.15, 1.0)
	for strand in 2:
		var side := 1.0 if strand == 0 else -1.0
		for i in MOTES:
			var t := fposmod(_time * FLOW + float(i) / MOTES + strand * 0.5 / MOTES, 1.0)
			if t > reach:
				continue
			if _since_release >= 0.0 and t < _since_release / AFTERFLOW:
				continue
			var swing := sin(t * PI) * SWING * side * cos(_time * 9.0 + t * 6.0)
			var point := from + along * t + across * swing
			var colour: Color
			if strand == 1:
				colour = MAGENTA if t < 0.85 else CREAM
			else:
				colour = AMBER if t < 0.4 else (SAND if t < 0.8 else CREAM)
			var size := PIXEL * (3.0 if t < 0.3 else (2.0 if t < 0.75 else 1.0))
			_pixel(point, size, colour)
			# A faint tail behind each fire mote, every other art pixel.
			if strand == 0 and t > 0.08:
				var behind := from + along * (t - 0.05) + across * sin((t - 0.05) * PI) * SWING * side * cos(_time * 9.0 + (t - 0.05) * 6.0)
				_pixel(behind, PIXEL, AMBER)


# A ring of magic closing on the flame being drawn, tighter as the wind-up goes on.
func _draw_grip(at: Vector2, progress: float) -> void:
	var radius := lerpf(26.0, 10.0, progress)
	var count := 10
	for i in count:
		var angle := TAU * i / count - _time * 6.0
		_pixel(at + Vector2(cos(angle), sin(angle) * 0.8) * radius, PIXEL * 2.0 if i % 2 == 0 else PIXEL, MAGENTA)


# A ring of light bursting out of the hand as the flame lands.
func _draw_flash(at: Vector2, progress: float) -> void:
	var radius := lerpf(4.0, 22.0, progress)
	var count := 12
	for i in count:
		var angle := TAU * i / count + progress
		var colour := CREAM if progress < 0.4 else (MAGENTA if i % 2 == 0 else AMBER)
		_pixel(at + Vector2.from_angle(angle) * radius, PIXEL * (2.0 if progress < 0.5 else 1.0), colour)
	if progress < 0.35:
		_pixel(at, PIXEL * 4.0, CREAM)


# A few sparks circling the flame he holds.
func _draw_orbit(at: Vector2) -> void:
	for i in 4:
		var angle := _time * 4.0 + TAU * i / 4.0
		var point := at + Vector2(cos(angle) * 20.0, sin(angle) * 9.0)
		_pixel(point, PIXEL * (2.0 if i % 2 == 0 else 1.0), MAGENTA if i != 0 else CREAM)


# Where the flame of a torch or a Fire burns.
func _flame_point(from: Node2D) -> Vector2:
	if from is Torch:
		return from.global_position + TORCH_FLAME
	return from.global_position


# A square of the given size, snapped to the art pixel grid.
func _pixel(at: Vector2, size: float, colour: Color) -> void:
	var snapped := (at - global_position).snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(size, size) / 2.0, Vector2(size, size)), colour)
