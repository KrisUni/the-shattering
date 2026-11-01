extends Node2D
## The dust a thrown prop kicks up behind it: puffs where it has been that thin and fade. When the
## prop comes to rest it stops adding puffs, lets the last ones fade, and frees itself. Only a look.

const DUST := Color("8a7f74")
const DUST_LIGHT := Color("b8ab9b")
const PIXEL := 2.0
const LENGTH := 10
const FADE := 0.3

var _prop: Node2D
var _points: Array[Vector2] = []
var _stopped_for := -1.0
var _frame := 0


func _ready() -> void:
	z_index = 2


## Follows this prop until stop() is called.
func follow(prop: Node2D) -> void:
	_prop = prop


## The prop has come to rest.
func stop() -> void:
	_stopped_for = 0.0


func _physics_process(delta: float) -> void:
	_frame += 1
	if _stopped_for < 0.0 and _prop != null and is_instance_valid(_prop):
		if _frame % 2 == 0:
			_points.push_front(_prop.global_position + Vector2(0, -8))
			if _points.size() > LENGTH:
				_points.resize(LENGTH)
	else:
		if _stopped_for < 0.0:
			_stopped_for = 0.0
		_stopped_for += delta
		if not _points.is_empty() and _frame % 2 == 0:
			_points.pop_back()
		if _stopped_for >= FADE or _points.is_empty():
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	for i in _points.size():
		var t := float(i) / LENGTH
		if i % 2 == 1 and t > 0.5:
			continue
		var at := _points[i] - global_position + Vector2(sin(i * 2.1) * 3.0, -t * 6.0)
		var size := PIXEL * (2.0 if t < 0.4 else 1.0)
		var snapped := at.snapped(Vector2(PIXEL, PIXEL))
		draw_rect(Rect2(snapped - Vector2(size, size) / 2.0, Vector2(size, size)), DUST_LIGHT if t < 0.3 else DUST)
