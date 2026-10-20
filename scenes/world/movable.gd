class_name Movable
extends CharacterBody2D
## A movable object, such as a Crate or a Boulder: a body that blocks Almos and the enemies like a
## wall, on the walls layer, and stands where it is put until a Shove or a Pull moves it. It is
## lifted while it moves: it slides as an enemy does, but no edge of a Gap or a Ledge stops it, so
## a Pull fetches it across a Gap, and only a wall, Almos or an enemy does. One that a Shove leaves
## with its centre inside a Gap falls and is gone. One too heavy for him only shudders. Its
## numbers, Weight included, come from its tuning, which the scene's instances give.

# The collision layer of the area inside a Gap, the sixth, and of Almos's body, the ninth.
const GAP_AREA_LAYER := 32
const PLAYER_BODY_LAYER := 256

# How far past the one who pulls it a Pull looks for a place clear of a Gap, in pixels.
const CARRY_LIMIT := 2000.0

# How a shudder looks: for this many physics frames its look jumps this many pixels from side to
# side, each frame the other way. A look, not tuning.
const SHUDDER_FRAMES := 8
const SHUDDER_OFFSET := 3.0

## Emitted once each time a Shove or a Pull is too much for its Weight and it shudders instead of
## moving.
signal shuddered

## Emitted once, when it falls into a Gap and is gone.
signal fell

@export var tuning: MovableTuning

## How heavy it is.
var weight: float:
	get:
		return tuning.weight

## Whether a Shove or a Pull is sliding it.
var sliding: bool:
	get:
		return _sliding

## Whether it has fallen into a Gap. It is freed at the end of that physics frame.
var dead: bool:
	get:
		return _fallen

@onready var _placeholder: Polygon2D = $Placeholder

var _sliding := false
var _fallen := false
var _slide_direction := Vector2.ZERO
var _slide_left := 0.0
var _slide_speed := 0.0
var _shudder_left := 0
# The physics layer it was made with, which it has again when it is put down.
var _home_layer := 0
# Whether the slide under way is a Pull, which never drops it in a Gap.
var _pulled := false


func _ready() -> void:
	_home_layer = collision_layer
	var half := tuning.size / 2.0
	_placeholder.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	_placeholder.color = tuning.color
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tuning.size, tuning.size)
	($CollisionShape2D as CollisionShape2D).shape = shape


func _physics_process(delta: float) -> void:
	if _shudder_left > 0:
		_placeholder.position.x = SHUDDER_OFFSET if _shudder_left % 2 == 0 else -SHUDDER_OFFSET
		_shudder_left -= 1
	else:
		_placeholder.position.x = 0.0
	if _sliding:
		_slide(delta)


## A Shove or a Pull slides it this way, a unit vector, for this many pixels at this many pixels
## per second.
func slide(direction: Vector2, distance: float, speed: float) -> void:
	if _fallen or distance <= 0.0 or direction.is_zero_approx():
		return
	_sliding = true
	_pulled = false
	_slide_direction = direction.normalized()
	_slide_left = distance
	_slide_speed = speed


## A Pull slides it towards this point (global coordinates), where Almos stands, to come to rest this
## far from it, at this speed. A Pull never drops it in a Gap: if that rest point is inside one, it
## is carried on along the same line, passing him (it ignores his body while lifted), and rests at
## the first point at least that far beyond him that is clear of the Gap.
func pull_towards(point: Vector2, stop_distance: float, speed: float) -> void:
	var away := global_position - point
	var direction := -away.normalized()
	if _fallen or direction.is_zero_approx():
		return
	var rest := away.length() - stop_distance
	if rest < 0.0:
		return
	if _in_a_gap_at(point - direction * stop_distance):
		var past := stop_distance
		while past < CARRY_LIMIT and _in_a_gap_at(point + direction * past):
			past += 1.0
		rest = away.length() + past
		# Lifted over him, it neither is blocked by his body nor blocks it.
		collision_mask &= ~PLAYER_BODY_LAYER
		collision_layer = 0
	slide(direction, rest, speed)
	_pulled = true


## A Shove or a Pull is more than its Weight allows: it shudders and stays where it is.
func shudder() -> void:
	_shudder_left = SHUDDER_FRAMES
	shuddered.emit()


# One physics frame of the slide: it stops against what blocks it, falls if it ends in a Gap.
func _slide(delta: float) -> void:
	var step := minf(_slide_speed * delta, _slide_left)
	var hit := move_and_collide(_slide_direction * step)
	_slide_left -= step
	if _in_a_gap():
		# Lifted, it crosses a Gap; a Shove drops it only if it is put down inside one.
		if hit != null or _slide_left <= 0.0:
			_end_slide()
			if _pulled:
				return
			_fallen = true
			fell.emit()
			queue_free()
		return
	if hit != null or _slide_left <= 0.0:
		_end_slide()


func _end_slide() -> void:
	_sliding = false
	collision_mask |= PLAYER_BODY_LAYER
	collision_layer = _home_layer


func _in_a_gap() -> bool:
	return _in_a_gap_at(global_position)


func _in_a_gap_at(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = GAP_AREA_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
