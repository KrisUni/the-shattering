extends GutTest

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const JAILER_TUNING_PATH := "res://data/nar_jailer.tres"
const TOLERANCE := 0.0001
# In pixels. How far in front of Almos the enemy is put for a Light attack to reach it.
const LIGHT_ATTACK_DISTANCE := 30.0
# How many taps of the Light attack button are tried before giving up on a kill.
const LIGHT_ATTACK_PRESS_LIMIT := 6
# In physics frames. How long the Light attack button is held for a tap, and left alone after.
const TAP_FRAMES := 3
# In pixels. How far from the edge of the floor Almos starts when he is sent at a wall.
const DISTANCE_FROM_WALL := 180.0
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


func test_almos_goes_limp_in_the_room_when_his_health_reaches_zero() -> void:
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

	almos.health.take_damage(tuning.health_maximum)

	assert_true(almos.dead, "he should lie limp where he fell")
	assert_true(almos.is_inside_tree(), "the room should carry on with the same Almos")


func test_almos_does_not_go_limp_while_he_has_health_left() -> void:
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
	var start: Vector2 = almos.global_position
	watch_signals(almos)

	almos.health.take_damage(tuning.health_maximum / 2.0)
	await wait_seconds(tuning.death_pause + 0.5)

	assert_false(almos.dead, "he should be on his feet")
	assert_signal_not_emitted(almos, "died")
	assert_eq(almos.global_position, start, "he should not have been sent anywhere")


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


func test_the_test_room_has_a_nar_jailer_with_the_jailers_data() -> void:
	var room := _spawn_room()
	if room == null:
		return
	var jailer = room.find_child("NarJailer", true, false)
	assert_not_null(jailer, "the test room should contain a NarJailer")
	if jailer == null:
		return

	assert_eq(jailer.tuning.resource_path, JAILER_TUNING_PATH, "the data file it uses")
	assert_true(jailer.tuning.guards, "it should guard")


func test_killing_the_training_enemy_gives_almos_its_tuned_experience_and_the_label_shows_it() -> void:
	var enemy_tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(enemy_tuning, "the training enemy tuning data file should load")
	if enemy_tuning == null:
		return
	assert_gt(enemy_tuning.experience, 0, "experience in the data file should be positive")
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	var enemy = room.find_child("TrainingEnemy", true, false)
	var label = room.find_child("ExperienceLabel", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(enemy, "the test room should contain a TrainingEnemy")
	assert_not_null(label, "the test room should contain an ExperienceLabel")
	if almos == null or enemy == null or label == null:
		return

	enemy.health.take_damage(enemy_tuning.health_maximum)
	await get_tree().process_frame

	assert_eq(almos.experience.total, enemy_tuning.experience, "killing the enemy should give its Experience")
	assert_string_contains(label.text, str(enemy_tuning.experience), "the label should show the new total")


func test_hurting_the_training_enemy_without_killing_it_gives_no_experience() -> void:
	var enemy_tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(enemy_tuning, "the training enemy tuning data file should load")
	if enemy_tuning == null:
		return
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	var enemy = room.find_child("TrainingEnemy", true, false)
	var label = room.find_child("ExperienceLabel", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(enemy, "the test room should contain a TrainingEnemy")
	assert_not_null(label, "the test room should contain an ExperienceLabel")
	if almos == null or enemy == null or label == null:
		return
	var text_before: String = label.text

	enemy.health.take_damage(enemy_tuning.health_maximum - 1.0)
	await get_tree().process_frame

	assert_eq(almos.experience.total, 0, "an enemy that is hurt but not killed should give none")
	assert_eq(label.text, text_before, "the label should not change")


func test_the_experience_label_shows_none_before_any_kill() -> void:
	var room := _spawn_room()
	if room == null:
		return
	var label = room.find_child("ExperienceLabel", true, false)
	if label == null:
		fail_test("the test room should contain an ExperienceLabel")
		return

	assert_true(label.text.ends_with("0"), "the label should show a total of none")


func test_two_kills_add_up_in_almos_experience_and_the_label() -> void:
	var enemy_tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(enemy_tuning, "the training enemy tuning data file should load")
	if enemy_tuning == null:
		return
	var room := _spawn_room_with_a_second_enemy()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	var enemy = room.find_child("TrainingEnemy", true, false)
	var second = room.find_child("SecondEnemy", true, false)
	var label = room.find_child("ExperienceLabel", true, false)
	if almos == null or enemy == null or second == null or label == null:
		fail_test("the test room should contain Almos, both enemies and an ExperienceLabel")
		return

	enemy.health.take_damage(enemy_tuning.health_maximum)
	await get_tree().process_frame
	second.health.take_damage(enemy_tuning.health_maximum)
	await get_tree().process_frame

	assert_eq(almos.experience.total, 2 * enemy_tuning.experience, "two kills should give twice the Experience")
	assert_true(label.text.ends_with(str(2 * enemy_tuning.experience)), "the label should show the summed total")


func test_killing_the_training_enemy_with_a_light_attack_gives_almos_its_tuned_experience() -> void:
	var enemy_tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(enemy_tuning, "the training enemy tuning data file should load")
	if enemy_tuning == null:
		return
	var room := _spawn_room()
	if room == null:
		return
	var almos = room.find_child("Almos", true, false)
	var enemy = room.find_child("TrainingEnemy", true, false)
	if almos == null or enemy == null:
		fail_test("the test room should contain Almos and a TrainingEnemy")
		return
	# Left with a sliver of Health and put right in front of him, so that one Light attack
	# finishes it.
	enemy.health.take_damage(enemy_tuning.health_maximum - 1.0)
	enemy.global_position = almos.global_position + almos.facing * LIGHT_ATTACK_DISTANCE

	for i in LIGHT_ATTACK_PRESS_LIMIT:
		if almos.experience.total > 0:
			break
		_almos_input.press_action(&"attack_light")
		await wait_physics_frames(TAP_FRAMES)
		_almos_input.release_action(&"attack_light")
		await wait_physics_frames(TAP_FRAMES)

	assert_eq(almos.experience.total, enemy_tuning.experience, "a kill made with a Light attack should give the Experience")


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


# The test room with a second training enemy added before it starts, so that it watches it
# as it does the enemy it comes with. The test frees it.
func _spawn_room_with_a_second_enemy() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	var enemy_scene := load("res://scenes/enemies/training_enemy.tscn") as PackedScene
	assert_not_null(scene, "the test room scene should load")
	assert_not_null(enemy_scene, "the training enemy scene should load")
	if scene == null or enemy_scene == null:
		return null
	var room := scene.instantiate()
	var second := enemy_scene.instantiate()
	second.name = "SecondEnemy"
	room.add_child(second)
	add_child_autofree(room)
	return room
