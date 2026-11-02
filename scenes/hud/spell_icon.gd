extends Control
## A small icon on the HUD, by the Health bar, for the Spell Almos has selected: Pull, arrows drawn in
## to a mote of energy, or Shove (push), arrows bursting out from it, with the key that switches them
## (V) beside it. It follows the selection through the Spell's selection_changed signal, and pulses
## when the selection changes. Drawn in code, pixel-exact, in the HUD bars' frame colours. Only a look.

const PixelText := preload("res://scenes/hud/pixel_text.gd")

const FRAME := Color("0c0b14")
const BACK := Color("1b1a2b")
const EDGE := Color("494d7e")
const CREAM := Color("fbf5ef")
const SAND := Color("f2d3ab")
const ROSE := Color("c69fa5")
const VIOLET := Color("8b6d9c")
# In pixels: the icon's box.
const BOX := 15
# The icons, 13 by 13 inside the box: "#" an arrow, "o" and "v" the mote of energy.
const PULL_ART: PackedStringArray = [
	".............",
	".............",
	".............",
	".............",
	"...#.....#...",
	"....#.v.#....",
	"#####vov#####",
	"....#.v.#....",
	"...#.....#...",
	".............",
	".............",
	".............",
	".............",
]
const SHOVE_ART: PackedStringArray = [
	".............",
	".............",
	".............",
	".............",
	"..#.......#..",
	".#....v....#.",
	"#####vov#####",
	".#....v....#.",
	"..#.......#..",
	".............",
	".............",
	".............",
	".............",
]
# In seconds: how long the pulse of a switch lasts.
const PULSE := 0.25

## The Spell whose selection it shows.
@export var spell: AlmosSpell
## The key shown beside it, which switches the Spell.
@export var key_hint := "V"

var _pulse_left := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(BOX + 2 + PixelText.width_of(key_hint), BOX)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spell != null:
		spell.selection_changed.connect(_on_selection_changed)
	queue_redraw()


## Whether it shows Pull now (else Shove).
func showing_pull() -> bool:
	return spell == null or spell.selected == AlmosSpell.Spell.PULL


func _process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left = maxf(_pulse_left - delta, 0.0)
		queue_redraw()


func _on_selection_changed() -> void:
	_pulse_left = PULSE
	queue_redraw()


func _draw() -> void:
	# The box, framed like the bars.
	draw_rect(Rect2(0, 0, BOX, BOX), FRAME)
	draw_rect(Rect2(1, 1, BOX - 2, BOX - 2), BACK)
	var lit := _pulse_left > 0.0
	draw_rect(Rect2(1, 1, BOX - 2, 1), CREAM if lit else EDGE)
	# The mote of energy in the middle, and the arrows: drawn in to it for Pull, out from it for Shove.
	var art: PackedStringArray = PULL_ART if showing_pull() else SHOVE_ART
	var arrow := CREAM if lit else SAND
	for row in art.size():
		for column in art[row].length():
			match art[row][column]:
				"#":
					draw_rect(Rect2(1 + column, 1 + row, 1, 1), arrow)
				"o":
					draw_rect(Rect2(1 + column, 1 + row, 1, 1), CREAM)
				"v":
					draw_rect(Rect2(1 + column, 1 + row, 1, 1), VIOLET)
	PixelText.draw(self, Vector2(BOX + 2, (BOX - PixelText.HEIGHT) / 2.0), key_hint, ROSE, 1, FRAME)

