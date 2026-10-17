extends GutTest

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
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

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


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


func test_the_health_bar_follows_the_health_almos_has_left() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	if tuning == null:
		return
	assert_gt(tuning.health_maximum, 0.0, "health_maximum in the data file should be positive")
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	var bar = room.find_child("HealthBar", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(bar, "the test room should contain a HealthBar")
	if almos == null or bar == null:
		return
	var damage := tuning.health_maximum / 4.0

	almos.health.take_damage(damage)

	assert_almost_eq(bar.value, tuning.health_maximum - damage, TOLERANCE)
	assert_almost_eq(bar.max_value, tuning.health_maximum, TOLERANCE)


func test_the_room_requests_a_restart_when_almos_health_reaches_zero() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	if tuning == null:
		return
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	if almos == null:
		return
	watch_signals(room)

	almos.health.take_damage(tuning.health_maximum)

	assert_signal_emit_count(room, "restart_requested", 1)


func test_the_room_does_not_request_a_restart_while_almos_has_health_left() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	if tuning == null:
		return
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	if almos == null:
		return
	watch_signals(room)

	almos.health.take_damage(tuning.health_maximum - 1.0)

	assert_signal_not_emitted(room, "restart_requested")


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

	_almos_input.press_action(params.action)
	_almos_input.press_action(&"roll")
	await wait_seconds(SECONDS_AT_THE_WALL)

	assert_true(floor_bounds.has_point(almos.global_position), "Almos should still be on the floor, but is at %s" % almos.global_position)
	assert_gte((almos.global_position - start).dot(params.direction), LEAST_PROGRESS, "Almos should have got up to the wall")


func test_the_test_room_has_a_training_enemy_going_after_almos_from_a_little_way_off() -> void:
	var enemy_tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(enemy_tuning, "the training enemy tuning data file should load")
	if enemy_tuning == null:
		return
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	var enemy = room.find_child("TrainingEnemy", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(enemy, "the test room should contain a TrainingEnemy")
	if almos == null or enemy == null:
		return

	assert_eq(enemy.target, almos, "the training enemy should go after Almos")
	assert_gt(enemy.global_position.distance_to(almos.global_position), enemy_tuning.attack_range, "it should start out of reach of him")


# The test room, in the test's scene tree, or null if its scene will not load. The test
# frees it.
func _spawn_room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return null
	var room := scene.instantiate()
	add_child_autofree(room)
	return room


# The floor's outline, as a rectangle in the room's own coordinates.
func _floor_bounds(room: Node) -> Rect2:
	var floor_shape := room.find_child("Floor", true, false) as Polygon2D
	if floor_shape == null or floor_shape.polygon.is_empty():
		return Rect2()
	var bounds := Rect2(floor_shape.to_global(floor_shape.polygon[0]), Vector2.ZERO)
	for point in floor_shape.polygon:
		bounds = bounds.expand(floor_shape.to_global(point))
	return bounds
