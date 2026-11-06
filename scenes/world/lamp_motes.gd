extends Node2D
## Motes of dust drifting in a lamp's pool of light, each catching it and twinkling as it turns. It
## hangs under the lamp's glow, so it shows only while the flame burns. Drawn on the art pixel grid,
## in world units whatever its parent's scale. Only a look.

const AMBER := Color("f7c468")

## How many motes, and how far from the flame they drift, in world units.
@export var count := 5
@export var reach := 30.0

var _time := 0.0


func _ready() -> void:
	z_index = 1
	z_as_relative = false
	# The glow it hangs under is drawn at scale 2; the motes are not.
	scale = Vector2.ONE / get_parent().scale if get_parent() is Node2D and (get_parent() as Node2D).scale != Vector2.ZERO else Vector2.ONE
	_time = fposmod(global_position.x * 0.07, 20.0)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in count:
		var h := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var a := _time * (0.15 + 0.1 * h) + h * TAU
		var r := reach * (0.35 + 0.65 * fposmod(h * 7.0, 1.0))
		var at := Vector2(cos(a) * r, sin(a * 1.3) * r * 0.6 + 6.0).round()
		var twinkle := 0.5 + 0.5 * sin(_time * (1.5 + h) + float(i) * 2.0)
		draw_rect(Rect2(at, Vector2.ONE), Color(AMBER, 0.15 + 0.45 * twinkle))
