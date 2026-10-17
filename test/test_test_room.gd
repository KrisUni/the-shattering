extends GutTest

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const TOLERANCE := 0.0001
# In pixels. How far from the edge of the floor Almos starts when he is sent at a wall.
const DISTANCE_FROM_WALL := 150.0
# The least, in pixels, he must get towards the wall, so that a test where he never moved
# cannot pass.
const LEAST_PROGRESS := 100.0
# In seconds. Much longer than a Sprint needs to cover the distance to the wall and a good
# way beyond it.
const SECONDS_AT_THE_WALL := 1.5

var wall_params = ParameterFactory.named_parameters(
	["direction", "action"],
	[
		[Vector2.LEFT, &"move_left"], [Vector2.RIGHT, &"move_right"],
		[Vector2.UP, &"move_up"], [Vector2.DOWN, &"move_down"],
	],
)

var _held_actions: Array[StringName] = []


func after_each() -> void:
	for action in _held_actions:
		Input.action_release(action)
	_held_actions.clear()


func test_test_room_instantiates() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return

	var room := scene.instantiate()
	add_child_autofree(room)

	assert_not_null(room, "the test room should instantiate")


func test_test_room_contains_a_placeholder_almos() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return

	var room := scene.instantiate()
	add_child_autofree(room)

	assert_not_null(room.find_child("Almos", true, false), "the test room should contain a node named Almos")


func test_the_stamina_bar_follows_the_stamina_almos_has_left() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	if tuning == null:
		return
	assert_gt(tuning.stamina_maximum, 0.0, "stamina_maximum in the data file should be positive")
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return
	var room := scene.instantiate()
	add_child_autofree(room)
	var almos = room.find_child("Almos", true, false)
	var bar = room.find_child("StaminaBar", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(bar, "the test room should contain a StaminaBar")
	if almos == null or bar == null:
		return
	var cost := tuning.stamina_maximum / 4.0

	almos.stamina.spend(cost)

	assert_almost_eq(bar.value, tuning.stamina_maximum - cost, TOLERANCE)
	assert_almost_eq(bar.max_value, tuning.stamina_maximum, TOLERANCE)


func test_sprinting_at_a_wall_keeps_almos_on_the_floor(params = use_parameters(wall_params)) -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return
	var room := scene.instantiate()
	add_child_autofree(room)
	var almos = room.find_child("Almos", true, false)
	var floor_bounds := _floor_bounds(room)
	assert_not_null(almos, "the test room should contain Almos")
	assert_gt(floor_bounds.size.x, 0.0, "the test room should have a floor")
	if almos == null or floor_bounds.size.x <= 0.0:
		return
	var start: Vector2 = floor_bounds.get_center() + params.direction * (floor_bounds.size / 2.0 - Vector2.ONE * DISTANCE_FROM_WALL)
	almos.global_position = start

	_hold(params.action)
	_hold(&"roll")
	await wait_seconds(SECONDS_AT_THE_WALL)

	assert_true(floor_bounds.has_point(almos.global_position), "Almos should still be on the floor, but is at %s" % almos.global_position)
	assert_gte((almos.global_position - start).dot(params.direction), LEAST_PROGRESS, "Almos should have got up to the wall")


# The floor's outline, as a rectangle in the room's own coordinates.
func _floor_bounds(room: Node) -> Rect2:
	var floor_shape := room.find_child("Floor", true, false) as Polygon2D
	if floor_shape == null or floor_shape.polygon.is_empty():
		return Rect2()
	var bounds := Rect2(floor_shape.to_global(floor_shape.polygon[0]), Vector2.ZERO)
	for point in floor_shape.polygon:
		bounds = bounds.expand(floor_shape.to_global(point))
	return bounds


func _hold(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)
