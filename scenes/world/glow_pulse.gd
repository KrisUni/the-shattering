extends Sprite2D
## Something that glows with the arch tree's light, such as the small fungus on the Dungeons' walls
## and floors: its light swells and ebbs, slowly, each on its own beat. Only a look.

## How far the glow swells and ebbs, as a share of its brightness.
@export var depth := 0.18
## How long one swell and ebb takes, in seconds.
@export var period := 3.4

var _time := 0.0


func _ready() -> void:
	_time = fposmod(global_position.x * 0.19 + global_position.y * 0.07, period)


func _process(delta: float) -> void:
	_time += delta
	var swell := 1.0 + depth * sin(TAU * _time / period)
	modulate = Color(swell, swell, swell * 0.98, 1.0)
