class_name ScreenEffects
extends CanvasLayer
## What the whole screen does, looks only, over the world and under nothing: a short fade in from
## black each time Almos comes into a Room, a dim wine-dark vignette that pulses round the edges
## while his Health is low, and a white flash as he rests at a Checkpoint.

## How long the fade in from black takes, in seconds.
const FADE := 0.22
## Below this share of his Health the vignette shows, and how fast it pulses, in pulses a second.
const LOW_HEALTH := 0.3
const PULSE := 1.1
## How long the rest's flash takes to fade, in seconds.
const FLASH := 0.35
## The vignette's colour: a dark wine, well away from Danger red.
const VIGNETTE := Color("5c1630")
## In screen pixels: how far in the vignette reaches, and the size of its dithered steps.
const REACH := 170.0
const STEP := 4.0

var almos: Node

var _fade_left := 0.0
var _flash_left := 0.0
var _time := 0.0
var _canvas: Control


func _ready() -> void:
	layer = 40
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_screen)
	add_child(_canvas)
	if almos != null and almos.has_signal(&"rested"):
		almos.rested.connect(func(_checkpoint: Node) -> void: flash())


## A fade in from black: he has come into a Room.
func fade_in() -> void:
	_fade_left = FADE


## A white flash: he has rested.
func flash() -> void:
	_flash_left = FLASH


## How low his Health is, as a share of its maximum; 1 when there is no Almos.
func health_share() -> float:
	var health: Node = almos.get_node_or_null(^"Health") if almos != null else null
	if health == null:
		return 1.0
	var maximum := float(health.get(&"maximum"))
	return float(health.get(&"current")) / maximum if maximum > 0.0 else 1.0


## Whether the vignette shows now.
func vignette_showing() -> bool:
	return almos != null and almos.get(&"dead") != true and health_share() < LOW_HEALTH


func _process(delta: float) -> void:
	_time += delta
	_fade_left = maxf(_fade_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_canvas.queue_redraw()


func _draw_screen() -> void:
	var size := _canvas.get_viewport_rect().size
	if vignette_showing():
		var pulse := 0.6 + 0.4 * sin(_time * TAU * PULSE)
		var depth := clampf(1.0 - health_share() / LOW_HEALTH, 0.7, 1.0)
		var bands := int(REACH / STEP)
		for i in bands:
			var a := (1.0 - float(i) / float(bands))
			a = a * a * 0.95 * pulse * depth
			var inset := float(i) * STEP
			var colour := Color(VIGNETTE, a)
			_canvas.draw_rect(Rect2(inset, inset, size.x - inset * 2.0, STEP), colour)
			_canvas.draw_rect(Rect2(inset, size.y - inset - STEP, size.x - inset * 2.0, STEP), colour)
			_canvas.draw_rect(Rect2(inset, inset + STEP, STEP, size.y - inset * 2.0 - STEP * 2.0), colour)
			_canvas.draw_rect(Rect2(size.x - inset - STEP, inset + STEP, STEP, size.y - inset * 2.0 - STEP * 2.0), colour)
	if _flash_left > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.98, 0.92, 0.55 * _flash_left / FLASH))
	if _fade_left > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, _fade_left / FADE))
