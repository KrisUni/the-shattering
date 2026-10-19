extends GutTest
## The Sight check: inside the cone's arc and length, and not behind a wall. Its numbers are the
## training enemy's tuning, and every distance and angle is worked from them.

const WALL_LAYER := 1
# In degrees and pixels. How far inside or outside an edge of the cone a point is put.
const ANGLE_MARGIN := 5.0
const LENGTH_MARGIN := 5.0
const WALL_THICKNESS := 8.0
const WALL_HEIGHT := 400.0

var _tuning: EnemyTuning
var _space: PhysicsDirectSpaceState2D


func before_each() -> void:
	await get_tree().process_frame
	_tuning = load("res://data/training_enemy.tres") as EnemyTuning
	_space = get_viewport().world_2d.direct_space_state


func test_a_point_inside_the_arc_and_the_length_is_seen() -> void:
	var point := _point(_tuning.sight_arc_degrees / 2.0 - ANGLE_MARGIN, _tuning.sight_length_full - LENGTH_MARGIN)

	assert_true(_sees(point, _tuning.sight_length_full))


func test_a_point_straight_ahead_is_seen() -> void:
	assert_true(_sees(_point(0.0, _tuning.sight_length_full / 2.0), _tuning.sight_length_full))


func test_a_point_outside_the_arc_on_either_side_is_not_seen() -> void:
	var angle := _tuning.sight_arc_degrees / 2.0 + ANGLE_MARGIN

	assert_false(_sees(_point(angle, _tuning.sight_length_full / 2.0), _tuning.sight_length_full), "to one side")
	assert_false(_sees(_point(-angle, _tuning.sight_length_full / 2.0), _tuning.sight_length_full), "to the other")


func test_a_point_behind_is_not_seen() -> void:
	assert_false(_sees(_point(180.0, 10.0), _tuning.sight_length_full))


func test_a_point_beyond_the_length_is_not_seen() -> void:
	assert_false(_sees(_point(0.0, _tuning.sight_length_full + LENGTH_MARGIN), _tuning.sight_length_full))


func test_a_shorter_length_leaves_out_a_point_the_longer_one_reaches() -> void:
	var point := _point(0.0, (_tuning.sight_length_dark + _tuning.sight_length_full) / 2.0)

	assert_true(_sees(point, _tuning.sight_length_full), "in full light")
	assert_false(_sees(point, _tuning.sight_length_dark), "in the dark")


func test_a_wall_between_blocks_it() -> void:
	var distance := _tuning.sight_length_full / 2.0
	var point := _point(0.0, distance)
	_wall_at(Vector2.RIGHT * distance / 2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_false(_sees(point, _tuning.sight_length_full))


func test_a_wall_beyond_the_point_does_not_block_it() -> void:
	var distance := _tuning.sight_length_full / 2.0
	var point := _point(0.0, distance)
	_wall_at(Vector2.RIGHT * (distance + 2.0 * WALL_THICKNESS))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(_sees(point, _tuning.sight_length_full))


# Someone at the origin, facing right, looking at this point.
func _sees(point: Vector2, length: float) -> bool:
	return Sight.sees(_space, Vector2.ZERO, Vector2.RIGHT, point, _tuning.sight_arc_degrees, length, WALL_LAYER)


# The point this far from the origin, this many degrees off straight ahead (right).
func _point(degrees: float, distance: float) -> Vector2:
	return Vector2.RIGHT.rotated(deg_to_rad(degrees)) * distance


func _wall_at(at: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = WALL_LAYER
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_THICKNESS, WALL_HEIGHT)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = at
	add_child_autofree(wall)
