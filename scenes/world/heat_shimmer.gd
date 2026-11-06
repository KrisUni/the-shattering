class_name HeatShimmer
extends Node2D
## Heat rising off a held flame: a few faint, wavering threads of light drifting up above it.
## It hangs under the flame, so it shows only while the flame does. Drawn in code on the art pixel
## grid. Only a look.

const HEAT := Color("f7c468")

@export var height := 18.0
@export var threads := 3

var _time := 0.0


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in threads:
		var phase := fposmod(_time * 0.9 + float(i) / float(threads), 1.0)
		var x := (float(i) - float(threads - 1) / 2.0) * 3.0
		for k in 4:
			var t := phase + float(k) * 0.06
			if t >= 1.0:
				continue
			var at := Vector2(x + sin(t * 10.0 + float(i) * 2.0) * 1.5, -height * t).round()
			draw_rect(Rect2(at, Vector2.ONE), Color(HEAT, 0.35 * (1.0 - t)))
