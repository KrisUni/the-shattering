class_name Movable
extends CharacterBody2D
## A movable object, such as a Crate or a Boulder: a body that blocks Almos and the enemies like a
## wall, on the walls layer, and stands where it is put until a Shove or a Pull moves it. It is
## lifted while it moves: it slides as an enemy does, but no edge of a Gap or a Ledge stops it, so
## a Pull fetches it across a Gap, and only a wall, Almos or an enemy does. One that a Shove leaves
## with its centre inside a Gap falls and is gone. One too heavy for him only shudders. Its
## numbers, Weight included, come from its tuning, which the scene's instances give.

# The collision layer of the area inside a Gap, the sixth.
const GAP_AREA_LAYER := 32

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


func _ready() -> void:
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
	_slide_direction = direction.normalized()
	_slide_left = distance
	_slide_speed = speed


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
		# Lifted, it crosses a Gap; it falls only if it is put down inside one.
		if hit != null or _slide_left <= 0.0:
			_sliding = false
			_fallen = true
			fell.emit()
			queue_free()
		return
	if hit != null or _slide_left <= 0.0:
		_sliding = false


func _in_a_gap() -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = GAP_AREA_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
