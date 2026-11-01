class_name HudBar
extends ProgressBar
## A bar of the HUD, drawn pixel-exact in place of the default ProgressBar look: a dark frame around
## a recessed background, the fill with a lit top row and a shaded bottom row, and a pale trail that
## lingers where a loss took the bar from, then drains down to it, so a hit reads at a glance. It is
## still a ProgressBar: value and max_value are what it shows. Health, Stamina and Mana each set
## their own fill colours.

# The frame and the background, the same for every bar. Looks, not tuning.
const FRAME := Color("0c0b14")
const BACK := Color("1b1a2b")
const BACK_SHADE := Color("14131f")
# The trail a loss leaves.
const TRAIL := Color("e8dccb")
# In seconds: how long the trail holds before it drains, and how fast it drains, in shares of the
# bar a second.
const TRAIL_HOLD := 0.45
const TRAIL_SPEED := 0.8

## The fill's colour, its lit top row and its shaded bottom row.
@export var fill_color := Color("9b3a46")
@export var fill_light := Color("c25a63")
@export var fill_shade := Color("6e2632")

# Where the trail ends, in the bar's own value, and how long it still holds before draining.
var _trail := 0.0
var _trail_hold := 0.0


func _init() -> void:
	show_percentage = false
	# Nothing of the default look: the bar draws itself.
	add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	add_theme_stylebox_override(&"fill", StyleBoxEmpty.new())


## Shows this much out of this maximum. A drop leaves the trail behind where the bar was; a rise
## does not.
func show_amount(current: float, maximum: float) -> void:
	var before := value
	max_value = maximum
	if current < before:
		_trail = maxf(_trail, before)
		_trail_hold = TRAIL_HOLD
	value = current
	if _trail < value:
		_trail = value
	queue_redraw()


## Where the trail ends now, in the bar's value: no further than the value once it has drained.
func trail_end() -> float:
	return _trail


func _process(delta: float) -> void:
	if _trail <= value:
		return
	if _trail_hold > 0.0:
		_trail_hold -= delta
		return
	_trail = maxf(value, _trail - TRAIL_SPEED * max_value * delta)
	queue_redraw()


func _draw() -> void:
	var w := floorf(size.x)
	var h := floorf(size.y)
	if w < 3.0 or h < 3.0:
		return
	# The frame, and the recessed background inside it, darker along its top.
	draw_rect(Rect2(0, 0, w, h), FRAME)
	var inner := Rect2(1, 1, w - 2, h - 2)
	draw_rect(inner, BACK)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), BACK_SHADE)
	if max_value <= 0.0:
		return
	var fill_w := floorf(inner.size.x * clampf(value / max_value, 0.0, 1.0))
	var trail_w := floorf(inner.size.x * clampf(_trail / max_value, 0.0, 1.0))
	# The trail of a loss, past the fill.
	if trail_w > fill_w:
		draw_rect(Rect2(inner.position.x + fill_w, inner.position.y, trail_w - fill_w, inner.size.y), TRAIL)
	if fill_w <= 0.0:
		return
	# The fill, lit along its top and shaded along its bottom.
	draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), fill_color)
	draw_rect(Rect2(inner.position, Vector2(fill_w, 1)), fill_light)
	if inner.size.y > 2.0:
		draw_rect(Rect2(inner.position.x, inner.end.y - 1, fill_w, 1), fill_shade)
