class_name FireballTrail
extends Node2D
## How a fireball looks in flight: a bright head (cream heart, sand and Fire amber around it) and a
## trail of fire that cools to dusty rose and slate smoke behind it, shedding embers that drift off
## and fall. When the fireball is gone, the trail stays where
## it was and fades out, then frees itself.
##
## It starts as a child of the fireball and moves itself up beside it, so that it outlives it. It
## only reads where the fireball is; no gameplay depends on it. Palette colours, on the art pixel
## grid.

const CREAM := Color("fbf5ef")
const SAND := Color("f2d3ab")
const AMBER := Color("f29a2e")
const ROSE := Color("c69fa5")
const SLATE := Color("494d7e")

# In units. One art pixel.
const PIXEL := 2.0
## How many past positions the trail keeps: one a physics frame.
const LENGTH := 16
## In seconds. How long the trail takes to fade once the fireball is gone.
const FADE := 0.25

var _fireball: WeakRef
var _points: Array[Vector2] = []
var _time := 0.0
var _gone_for := -1.0


func _ready() -> void:
	z_index = 2
	var fireball := get_parent() as Node2D
	_fireball = weakref(fireball)
	if fireball != null:
		_points.append(fireball.global_position)
	_move_beside.call_deferred(fireball)


# Moves up to be the fireball's sibling, so it is not freed with it.
func _move_beside(fireball: Node2D) -> void:
	if fireball == null or not is_instance_valid(fireball) or fireball.get_parent() == null:
		return
	var parent := fireball.get_parent()
	fireball.remove_child(self)
	parent.add_child(self)
	top_level = true
	global_position = Vector2.ZERO


## Whether the fireball is gone and the trail is fading.
func fading() -> bool:
	return _gone_for >= 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	var fireball := _fireball.get_ref() as Node2D if _fireball != null else null
	if fireball != null and is_instance_valid(fireball) and fireball.is_inside_tree():
		_points.push_front(fireball.global_position)
		if _points.size() > LENGTH:
			_points.resize(LENGTH)
	else:
		if _gone_for < 0.0:
			_gone_for = 0.0
		_gone_for += delta
		# The trail drains away from its tail.
		if not _points.is_empty():
			_points.pop_back()
		if _gone_for >= FADE or _points.is_empty():
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if _points.is_empty():
		return
	var count := _points.size()
	var heading := Vector2.RIGHT
	if count > 1 and _points[0] != _points[1]:
		heading = (_points[0] - _points[1]).normalized()
	var across := heading.orthogonal()
	# The trail, from its tail to the head, so the head draws on top.
	for i in range(count - 1, 0, -1):
		var t := float(i) / LENGTH
		var flicker := across * (PIXEL if (i + int(_time * 30.0)) % 3 == 0 else 0.0)
		var colour: Color
		var size: float
		if t < 0.2:
			colour = SAND
			size = 2.5
		elif t < 0.45:
			colour = AMBER
			size = 2.0
		elif t < 0.7:
			colour = ROSE
			size = 1.5
		else:
			# Smoke: every other art pixel, so it reads thin.
			if i % 2 == 1:
				continue
			colour = SLATE
			size = 1.0
		_disc(_points[i] + flicker, size, colour)
		# Embers shed from the trail drift out and fall behind it.
		if i % 3 == 1 and t < 0.75:
			var side := 1.0 if posmod(floori(i / 3.0), 2) == 0 else -1.0
			var drift := across * side * (3.0 + t * 10.0) + Vector2(0, t * t * 14.0)
			_pixel(_points[i] + drift, PIXEL, CREAM if t < 0.3 else AMBER)
	if fading():
		return
	# The head: an amber rim, sand within, a cream heart.
	var head := _points[0]
	_disc(head, 4.0, AMBER)
	_disc(head + heading * PIXEL, 3.0, SAND)
	_disc(head + heading * PIXEL * 2.0, 1.5, CREAM)


# A round blob of art pixels, this many art pixels in radius.
func _disc(at: Vector2, radius: float, colour: Color) -> void:
	var reach := ceili(radius)
	for y in range(-reach, reach + 1):
		for x in range(-reach, reach + 1):
			if x * x + y * y <= radius * radius + 0.5:
				_pixel(at + Vector2(x, y) * PIXEL, PIXEL, colour)


func _pixel(at: Vector2, size: float, colour: Color) -> void:
	var snapped := (at - global_position).snapped(Vector2(PIXEL, PIXEL))
	draw_rect(Rect2(snapped - Vector2(size, size) / 2.0, Vector2(size, size)), colour)
