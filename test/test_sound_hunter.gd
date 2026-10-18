extends GutTest
## The Sound hunter in the test room with the real Almos and the shipped tuning, driven by Input
## actions: it notices the Noise Almos makes within the radius of it, through walls, and never
## notices by Sight; a Sight enemy ignores Noise. Every distance is worked from the tuning.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const PLAYER_TUNING_PATH := AlmosInput.TUNING_PATH
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const HUNTER_TUNING_PATH := "res://data/sound_hunter.tres"
# In physics frames. How long a case that should stay unnoticed is watched for.
const WATCH_FRAMES := 30
const TAP_FRAMES := 3
# In pixels. How far past the edge of a radius Almos stands, to be clearly out of it.
const BEYOND_MARGIN := 40.0
# In pixels. Where the hunter stands, in the open and clear of the walls.
const HUNTER_AT := Vector2(700.0, 324.0)
const WALL_THICKNESS := 8.0
const WALL_HEIGHT := 200.0
const FAR_AWAY := Vector2(-10000.0, -10000.0)
# In pixels. Clearance around the things the hunter must stay clear of in the test room.
const CLEARANCE := 8.0

var _almos_input: AlmosInput
var _player: PlayerTuning
var _hunter_tuning: EnemyTuning


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_player = load(PLAYER_TUNING_PATH) as PlayerTuning
	_hunter_tuning = load(HUNTER_TUNING_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_the_sound_hunter_data_is_a_sound_hunter_and_the_training_enemy_is_not() -> void:
	assert_true(_hunter_tuning.sound_hunter)
	assert_false((load(ENEMY_TUNING_PATH) as EnemyTuning).sound_hunter)


func test_the_test_room_has_a_sound_hunter_clear_of_the_pickups_the_checkpoint_and_the_other_enemys_sight() -> void:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	add_child_autofree(room)
	var hunter := room.get_node("SoundHunter") as Node2D
	assert_eq(hunter.tuning, _hunter_tuning, "it uses the Sound hunter data")
	assert_eq(hunter.target, room.get_node("Almos"), "it goes after Almos")
	var at := hunter.global_position
	var sight := (load(ENEMY_TUNING_PATH) as EnemyTuning).sight_length_full
	assert_gt(at.distance_to(room.get_node("TrainingEnemy").global_position), sight + CLEARANCE, "against the other enemy's Sight")
	assert_gt(at.distance_to(room.get_node("Checkpoint").global_position), CLEARANCE * 4.0, "from the Checkpoint")
	for node in room.get_children():
		if node is Node2D and String(node.name).ends_with("Pickup"):
			assert_gt(at.distance_to(node.global_position), CLEARANCE * 4.0, "from %s" % node.name)


func test_sprinting_within_the_radius_is_noticed_but_beyond_it_is_not() -> void:
	var radius := _player.noise_sprint_radius
	var near := _case(HUNTER_AT + Vector2.RIGHT * radius * 0.5)
	# Towards the hunter, so that he is still inside the radius when the Sprint begins, however
	# far he walks while the button is held to the threshold.
	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"roll")
	await _watch(WATCH_FRAMES)
	assert_true(near.hunter.noticed, "within the radius it hears the Sprint")
	await _retire(near)

	var far := _case(HUNTER_AT + Vector2.RIGHT * (radius + BEYOND_MARGIN))
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _watch(WATCH_FRAMES)
	assert_false(far.hunter.noticed, "beyond the radius it does not")


func test_rolling_within_the_radius_is_noticed_but_beyond_it_is_not() -> void:
	var radius := _player.noise_roll_radius
	var near := _case(HUNTER_AT + Vector2.RIGHT * radius * 0.5)
	await _tap_roll_away()
	assert_true(near.hunter.noticed, "within the radius it hears the Roll")
	await _retire(near)

	var far := _case(HUNTER_AT + Vector2.RIGHT * (radius + BEYOND_MARGIN))
	await _tap_roll_away()
	assert_false(far.hunter.noticed, "beyond the radius it does not")


func test_fighting_within_the_radius_is_noticed_but_beyond_it_is_not() -> void:
	var radius := _player.noise_attack_radius
	var near := _case(HUNTER_AT + Vector2.RIGHT * radius * 0.5)
	await _swing()
	assert_true(near.hunter.noticed, "within the radius it hears the fight")
	await _retire(near)

	var far := _case(HUNTER_AT + Vector2.RIGHT * (radius + BEYOND_MARGIN))
	await _swing()
	assert_false(far.hunter.noticed, "beyond the radius it does not")


func test_noise_is_heard_through_a_wall() -> void:
	var radius := _player.noise_attack_radius
	var walled := _case(HUNTER_AT + Vector2.RIGHT * radius * 0.5)
	_wall_in(walled.room, HUNTER_AT + Vector2.RIGHT * radius * 0.25)

	await _swing()

	assert_true(walled.hunter.noticed, "a wall does not stop Noise")


func test_almos_walking_or_standing_right_behind_it_is_not_noticed() -> void:
	var behind := _case(HUNTER_AT + Vector2.RIGHT * 30.0)
	await _watch(WATCH_FRAMES)
	assert_false(behind.hunter.noticed, "standing")

	_almos_input.press_action(&"move_right")
	await _watch(WATCH_FRAMES)
	assert_false(behind.hunter.noticed, "walking")


func test_almos_walking_or_standing_in_front_of_it_in_the_light_is_not_noticed() -> void:
	var sight := (load(ENEMY_TUNING_PATH) as EnemyTuning).sight_length_full
	var front := _case(HUNTER_AT + Vector2.LEFT * sight * 0.25)
	front.hunter.post_facing = Vector2.LEFT
	await _watch(WATCH_FRAMES)
	assert_false(front.hunter.noticed, "standing")

	_almos_input.press_action(&"move_left")
	await _watch(WATCH_FRAMES)
	assert_false(front.hunter.noticed, "walking")


func test_a_sight_enemy_facing_away_ignores_the_noise_behind_it() -> void:
	var room := _case(HUNTER_AT + Vector2.RIGHT * 30.0)
	var enemy := room.room.get_node("TrainingEnemy") as Node2D
	enemy.position = HUNTER_AT
	enemy.post_facing = Vector2.LEFT
	room.hunter.position = FAR_AWAY

	await _swing()

	assert_false(enemy.noticed, "Noise means nothing to Sight")


# A test room with Almos here, the Sound hunter at its post facing left and the Sight enemy far
# away.
func _case(almos_at: Vector2) -> Dictionary:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var almos := room.get_node("Almos") as Node2D
	var hunter := room.get_node("SoundHunter")
	almos.position = almos_at
	hunter.position = HUNTER_AT
	hunter.post_facing = Vector2.LEFT
	room.get_node("TrainingEnemy").position = FAR_AWAY
	add_child_autofree(room)
	return {"room": room, "almos": almos, "hunter": hunter}


func _tap_roll_away() -> void:
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _watch(WATCH_FRAMES)
	_almos_input.release_action(&"move_right")


func _swing() -> void:
	_almos_input.press_action(&"attack_light")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	await _watch(WATCH_FRAMES)


func _wall_in(room: Node, at: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_THICKNESS, WALL_HEIGHT)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = at
	room.add_child(wall)


func _retire(room_case: Dictionary) -> void:
	# Let go of every button and let a frame pass, so that the next case starts with none held.
	_almos_input.release_everything()
	room_case.room.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _watch(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame

