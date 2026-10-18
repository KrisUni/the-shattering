extends GutTest
## The Remains in the world, seen through their scene: they hold an amount of Experience, and
## Almos touching them gets it back and takes them away. Almos is walked into them with the move
## actions, or put on top of them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const REMAINS_SCENE_PATH := "res://scenes/world/remains.tscn"
# A little more than what an enemy gives, so that a test cannot pass with the wrong amount by luck.
const AMOUNT := 137
# In pixels. How far from the Remains Almos starts when he is walked into them.
const WALK_DISTANCE := 100.0
# In pixels. How far away Almos is put to be well out of reach of them.
const FAR_AWAY := 400.0
# In physics frames. How long to let Almos walk, or stand, so that anything that is to happen has.
const WATCH_FRAMES := 90
# In pixels. How far to the side of the line of a Jump the Remains lie, near enough that he is over
# them in the middle of the Jump, and far enough that he comes down and takes off clear of them.
const SIDE_OF_THE_JUMP := 20.0
# In physics frames. The most a Jump is waited for to end.
const JUMP_FRAME_LIMIT := 120
# In physics frames. How long to let the Remains notice Almos after he has come down.
const NOTICE_FRAMES := 3

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_walking_into_the_remains_gives_almos_the_experience_back() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position - Vector2.RIGHT * WALK_DISTANCE)

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, AMOUNT)


func test_the_experience_is_added_to_what_he_has_gained_since() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position - Vector2.RIGHT * WALK_DISTANCE)
	almos.experience.gain(50)

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, AMOUNT + 50)


func test_reaching_the_remains_takes_them_away() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	_spawn_almos(remains.position - Vector2.RIGHT * WALK_DISTANCE)

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(get_tree().get_nodes_in_group("remains").size(), 0, "no Remains should be left")
	assert_false(is_instance_valid(remains) and remains.is_inside_tree(), "they should be out of the scene")


func test_the_remains_are_freed_once_he_has_reached_them() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	_spawn_almos(remains.position - Vector2.RIGHT * WALK_DISTANCE)

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WATCH_FRAMES)

	assert_false(is_instance_valid(remains), "they should be freed, not left about")


func test_the_remains_are_out_of_the_remains_group_in_the_frame_he_reaches_them() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	_spawn_almos(remains.position)
	# Read once the frame's work is done, while a node only queued to be freed is still in the scene.
	var seen: Array[int] = []
	remains.recovered.connect(func(_amount: int) -> void:
		seen.append(get_tree().get_nodes_in_group("remains").size()),
		CONNECT_DEFERRED)

	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(seen, [0])


func test_reaching_the_remains_announces_how_much_was_recovered() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	_spawn_almos(remains.position - Vector2.RIGHT * WALK_DISTANCE)
	# Kept by hand, since the Remains are gone by the end and GUT cannot watch a freed node.
	var announced: Array[int] = []
	remains.recovered.connect(func(amount: int) -> void: announced.append(amount))

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(announced, [AMOUNT])


func test_standing_on_the_remains_recovers_them_with_no_button() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position)

	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, AMOUNT)


func test_the_experience_is_recovered_only_once() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var place := remains.position
	var almos := _spawn_almos(place)
	await wait_physics_frames(WATCH_FRAMES)

	almos.global_position = place
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, AMOUNT)


func test_almos_out_of_reach_leaves_the_remains_where_they_are() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position + Vector2.DOWN * FAR_AWAY)

	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, 0)
	assert_true(remains.is_inside_tree(), "they should still be there")


func test_an_enemy_standing_on_the_remains_does_not_recover_them() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var enemy_scene := load("res://scenes/enemies/training_enemy.tscn") as PackedScene
	var enemy = enemy_scene.instantiate()
	enemy.position = remains.position
	add_child_autofree(enemy)

	await wait_physics_frames(WATCH_FRAMES)

	assert_true(remains.is_inside_tree(), "they should still be there")


func test_almos_lying_limp_on_the_remains_does_not_recover_them() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position + Vector2.DOWN * FAR_AWAY)
	almos.health.take_damage(almos.health.maximum)
	almos.global_position = remains.position

	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, 0)
	assert_true(remains.is_inside_tree(), "they should still be there")


func test_the_remains_are_recovered_once_he_is_on_his_feet_on_them() -> void:
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position + Vector2.DOWN * FAR_AWAY)
	almos.health.take_damage(almos.health.maximum)
	almos.global_position = remains.position
	await wait_physics_frames(WATCH_FRAMES)

	almos.return_to(remains.position)
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.experience.total, AMOUNT)


func test_jumping_over_the_remains_does_not_recover_them() -> void:
	var tuning := load(AlmosInput.TUNING_PATH) as PlayerTuning
	var jump_length := tuning.walk_speed * tuning.jump_duration
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var start := remains.position + Vector2(-jump_length / 2.0, SIDE_OF_THE_JUMP)
	var almos := _spawn_almos(start)
	assert_gt(jump_length / 2.0, SIDE_OF_THE_JUMP, "the Jump should come down clear of the Remains")

	await _jump_to_the_right(almos)
	await wait_physics_frames(WATCH_FRAMES)

	assert_gt(almos.global_position.x, remains.position.x, "he should have gone over them")
	assert_eq(almos.experience.total, 0)
	assert_true(remains.is_inside_tree(), "they should still be there")


func test_coming_down_on_the_remains_recovers_them() -> void:
	var tuning := load(AlmosInput.TUNING_PATH) as PlayerTuning
	var jump_length := tuning.walk_speed * tuning.jump_duration
	var remains := _spawn_remains(Vector2(500.0, 300.0), AMOUNT)
	var almos := _spawn_almos(remains.position - Vector2.RIGHT * jump_length)

	await _jump_to_the_right(almos)
	await wait_physics_frames(NOTICE_FRAMES)

	assert_eq(almos.experience.total, AMOUNT)


# Remains of this much Experience at this point in the scene. The test frees them.
func _spawn_remains(at: Vector2, amount: int) -> Remains:
	var scene := load(REMAINS_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the Remains scene should load")
	var remains := scene.instantiate() as Remains
	remains.position = at
	remains.amount = amount
	add_child_autofree(remains)
	return remains


# Almos at this point in the scene. The test frees him.
func _spawn_almos(at: Vector2) -> Almos:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	var almos := scene.instantiate() as Almos
	almos.position = at
	add_child_autofree(almos)
	return almos


# He jumps while walking right, and the Jump is waited out until he is down. He is left standing
# where he came down.
func _jump_to_the_right(almos: Almos) -> void:
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"jump")
	await wait_physics_frames(NOTICE_FRAMES)
	assert_true(almos.airborne, "he should be in the air")
	_almos_input.release_action(&"jump")
	for i in JUMP_FRAME_LIMIT:
		if not almos.airborne:
			break
		await get_tree().physics_frame
	_almos_input.release_action(&"move_right")
	assert_false(almos.airborne, "the Jump should be over")
