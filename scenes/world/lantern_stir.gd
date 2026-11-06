extends Node
## A lantern stirred by someone rushing past: when Almos dashes or sprints close by, its flame leans
## away from him, a pixel or two, and rocks back as it settles. It moves only the lit flame's
## picture (its parent's Flame/Art), never the lantern or its light. Only a look.

## How near he must pass, in units, and how long the flame takes to settle, in seconds.
const NEAR := 64.0
const SETTLE := 0.6

var _art: Node2D
var _home := Vector2.ZERO
var _left := 0.0
var _way := 1.0


func _ready() -> void:
	_art = get_parent().get_node_or_null(^"Flame/Art") as Node2D
	if _art != null:
		_home = _art.position


func _process(delta: float) -> void:
	if _art == null:
		return
	var lantern := get_parent() as Node2D
	for almos in get_tree().get_nodes_in_group(&"almos"):
		var body := almos as Node2D
		if body == null or not (almos.get(&"rolling") == true or almos.get(&"sprinting") == true):
			continue
		if body.global_position.distance_to(lantern.global_position) < NEAR and _left <= SETTLE * 0.5:
			_left = SETTLE
			_way = signf(lantern.global_position.x - body.global_position.x)
			if _way == 0.0:
				_way = 1.0
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		var t := 1.0 - _left / SETTLE
		# A lean away from him, then a smaller one back, then still.
		var lean := 2.0 if t < 0.35 else (-1.0 if t < 0.7 else 0.0)
		_art.position = _home + Vector2(_way * lean, 0.0)
	elif _art.position != _home:
		_art.position = _home
