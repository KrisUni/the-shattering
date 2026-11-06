class_name SmokeCurl
extends Node2D
## A curl of smoke off a flame that has gone out, as when Pull takes a torch's flame: a few soft
## puffs that rise, curl one way and the other, swell and thin away. Drawn in code on the art pixel
## grid in muted violets. Only a look.

const SMOKE := [Color("8a7d94"), Color("6f6480"), Color("5a5068")]

@export var lifetime := 1.3
@export var rise := 22.0

var _age := 0.0


## A curl put in this parent at this global place.
static func rise_from(parent: Node, at: Vector2) -> SmokeCurl:
	var curl := SmokeCurl.new()
	parent.add_child(curl)
	curl.global_position = at.round()
	return curl


func _ready() -> void:
	z_index = 2


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in 5:
		var t := _age / lifetime - float(i) * 0.08
		if t <= 0.0 or t >= 1.0:
			continue
		var at := Vector2(sin(t * 7.0 + float(i)) * (2.0 + 3.0 * t), -rise * t - float(i)).round()
		var size := 1.0 + floorf(2.0 * t)
		var colour: Color = SMOKE[mini(int(t * SMOKE.size()), SMOKE.size() - 1)]
		colour.a = 0.85 * (1.0 - t)
		draw_rect(Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)).abs(), colour)
