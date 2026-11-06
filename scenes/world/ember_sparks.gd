class_name EmberSparks
extends Node2D
## Embers rising off a fire: now and then a spark lifts from the flames, drifts up and sideways,
## cools from cream through amber to a dull red-brown and goes out. Drawn in code on the art pixel
## grid. Only a look.

const HOT := [Color("fcecc8"), Color("f7c468"), Color("f29a2e"), Color("8c4a2a")]

## How many sparks are in the air at once, at most.
@export var count := 4
## How long a spark rises, in seconds.
@export var lifetime := 1.1
## How high a spark rises, in art pixels.
@export var rise := 26.0
## How wide the fire is, in art pixels: where sparks set off from.
@export var width := 12.0

var _time := 0.0


func _ready() -> void:
	z_index = 1
	_time = fposmod(global_position.x * 0.13, lifetime)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in count:
		# Each spark keeps its own place in the cycle, so they rise one after another.
		var phase := fposmod(_time / lifetime + float(i) / float(count), 1.0)
		var round_no := floori(_time / lifetime + float(i) / float(count))
		var seed := (round_no * 31 + i * 17) % 97
		var start_x := (float(seed % 11) / 10.0 - 0.5) * width
		var drift := (float(seed % 7) / 6.0 - 0.5) * 8.0
		var at := Vector2(start_x + drift * phase + sin(phase * 9.0 + float(i)) * 1.2, -rise * phase).round()
		var colour: Color = HOT[mini(int(phase * HOT.size()), HOT.size() - 1)]
		colour.a = 1.0 if phase < 0.7 else (1.0 - phase) / 0.3
		draw_rect(Rect2(at, Vector2.ONE), colour)
