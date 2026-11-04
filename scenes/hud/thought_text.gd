extends Control
## A thought of Almos's shown on screen: a few short lines in a dark box low on the screen, typed out
## letter by letter, with a faint prompt under them once they are all out. Any key, mouse click or
## pad button takes it away (a press while it is still typing shows it all first); it then tells so
## with dismissed and frees itself. Drawn in the pixel font. Only a look: what it holds up is up to
## whoever shows it.

const PixelText := preload("res://scenes/hud/pixel_text.gd")

const BOX := Color(0.047, 0.043, 0.078, 0.86)
const EDGE := Color("494d7e")
const TEXT := Color("f2d3ab")
const SHADOW := Color("0c0b14")
const PROMPT := Color("8b6d9c")
# In letters a second.
const TYPE_SPEED := 32.0
# In pixels.
const PADDING := 8
const LINE_GAP := 4
const BOTTOM_MARGIN := 28

## Emitted once, when a press takes it away.
signal dismissed

## The lines of the thought.
@export var lines: PackedStringArray = []
## The prompt shown under them once they are out.
@export var prompt := "PRESS ANY BUTTON"

## In seconds: when more than zero, the thought takes no press at all (so it never holds Almos up or
## eats a press of his) and fades by itself this long after its lines are out, with no prompt.
@export var auto_hide_after := 0.0

var _shown := 0.0
var _total := 0
var _time := 0.0
var _gone := false
var _shown_for := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line in lines:
		_total += line.length()


## Whether every letter is out.
func all_shown() -> bool:
	return int(_shown) >= _total


## Takes it away at once, as a press does once it is all shown.
func dismiss() -> void:
	if _gone:
		return
	_gone = true
	dismissed.emit()
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	_shown = minf(_shown + TYPE_SPEED * delta, _total)
	if auto_hide_after > 0.0 and all_shown():
		_shown_for += delta
		modulate.a = clampf((auto_hide_after - _shown_for) / 0.5, 0.0, 1.0)
		if _shown_for >= auto_hide_after:
			dismiss()
			return
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _gone or auto_hide_after > 0.0 or not _is_a_press(event):
		return
	get_viewport().set_input_as_handled()
	if not all_shown():
		_shown = _total
		return
	dismiss()


static func _is_a_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	return false


func _draw() -> void:
	# The view as the HUD layer draws it, which may be scaled up.
	var view := get_viewport_rect().size / get_canvas_transform().get_scale()
	var widest := 0
	for line in lines:
		widest = maxi(widest, PixelText.width_of(line))
	if auto_hide_after <= 0.0:
		widest = maxi(widest, PixelText.width_of(prompt))
	var line_height := PixelText.HEIGHT + LINE_GAP
	var height := PADDING * 2 + lines.size() * line_height + (line_height if auto_hide_after <= 0.0 else 0)
	var width := widest + PADDING * 2
	var origin := Vector2(floorf((view.x - width) / 2.0), floorf(view.y - BOTTOM_MARGIN - height))
	draw_rect(Rect2(origin, Vector2(width, height)), BOX)
	draw_rect(Rect2(origin, Vector2(width, 1)), EDGE)
	draw_rect(Rect2(origin + Vector2(0, height - 1), Vector2(width, 1)), EDGE)
	# Three little bubbles rising from its corner: a thought, not words said.
	for i in 3:
		var bubble := origin + Vector2(PADDING + i * 5, -4 - i * 3)
		draw_rect(Rect2(bubble, Vector2(2 + (2 - i), 2 + (2 - i))), Color(TEXT, 0.7))
	var left := int(_shown)
	var y := origin.y + PADDING
	for line in lines:
		var part := line.substr(0, clampi(left, 0, line.length()))
		left -= line.length()
		var x := origin.x + floorf((width - PixelText.width_of(line)) / 2.0)
		PixelText.draw(self, Vector2(x, y), part, TEXT, 1, SHADOW)
		y += line_height
	if auto_hide_after <= 0.0 and all_shown() and fmod(_time, 1.2) < 0.85:
		var x := origin.x + floorf((width - PixelText.width_of(prompt)) / 2.0)
		PixelText.draw(self, Vector2(x, y + 1), prompt, PROMPT, 1, SHADOW)
