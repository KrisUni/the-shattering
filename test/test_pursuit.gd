extends GutTest
## Pursuit in the test room with the real Almos and the shipped tuning: an enemy that notices him
## goes after him; when it has not had him in its Sight for the lose-time it gives up, walks back to
## its post, and recovers Health there; noticing him again on the way back resumes the Pursuit with
## the Health it has got back. Almos is moved by the test (he is put behind a wall, or far away),
## because what is under test is the enemy's side of it. Every distance and time is worked from the
## tuning, and nothing here pins a number in it.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const ENEMY_SCENE_PATH := "res://scenes/enemies/training_enemy.tscn"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const HUNTER_TUNING_PATH := "res://data/sound_hunter.tres"
# In pixels. Where the enemy has its post: in the open, clear of the pickups and the Checkpoint.
const POST := Vector2(700.0, 324.0)
# In pixels. Where Almos stands when the test does not move him.
const OPEN_SPOT := Vector2(300.0, 150.0)
# In pixels. Somewhere no Sight in the test reaches.
const FAR_AWAY_SPOT := Vector2(1100.0, 80.0)
const WALL_THICKNESS := 8.0
const WALL_HEIGHT := 200.0
const FAR_AWAY := Vector2(-10000.0, -10000.0)
# Fractions of the Sight length, along the line leftwards from the post: where Almos is seen,
# where the wall stands and where he hides behind it.
const SEEN_AT := 0.45
const WALL_AT := 0.7
const HIDDEN_AT := 0.85
# In physics frames. Slack allowed in a time counted in frames, and the most any wait may take.
const FRAME_LIMIT := 2000
# In Health points.
const TOLERANCE := 0.001
# In physics frames. How long Almos is out of sight before the test acts, short of the lose-time.
const SOME_FRAMES := 5
# In seconds. How much Health the enemy is hurt by, in time of recovery.
const HURT_SECONDS := 2.0
# In pixels. How far in front of the enemy Almos steps when he turns up on its way back.
const STEP_IN_FRONT := 50.0

var _almos_input: AlmosInput
var _tuning: EnemyTuning


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_tuning = load(ENEMY_TUNING_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_an_enemy_that_notices_almos_is_in_pursuit() -> void:
	var c := _case()
	assert_false(c.enemy.in_pursuit, "control: it is not before it has looked")

	await _frames(2)

	assert_true(c.enemy.in_pursuit)


func test_pursuit_ends_when_almos_has_stayed_out_of_sight_for_the_lose_time_and_not_a_frame_before() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)

	await _frames(_tuning.lose_sight_frames - 1)
	assert_true(c.enemy.in_pursuit, "one frame short of the lose-time it is still after him")

	await _frames(1)
	assert_false(c.enemy.in_pursuit, "the lose-time is up")


func test_out_of_sight_it_walks_to_where_it_last_saw_him_and_waits_there_until_the_lose_time_is_up() -> void:
	var c := _case()
	await _frames(2)
	var last_seen: Vector2 = c.almos.global_position
	_hide(c)

	await _frames(_tuning.lose_sight_frames - 1)

	assert_true(c.enemy.in_pursuit)
	assert_lt(c.enemy.global_position.distance_to(last_seen), 1.0, "it has walked to the place and waits on it")


func test_after_losing_him_it_walks_back_to_its_post_and_faces_the_way_it_was_set() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	await _frames(_tuning.lose_sight_frames)
	assert_false(c.enemy.in_pursuit, "control: it has lost him")
	assert_ne(c.enemy.global_position, POST, "control: it is away from its post")

	await _until(func() -> bool: return c.enemy.facing == Vector2.LEFT)

	assert_eq(c.enemy.facing, Vector2.LEFT, "facing the way it was set")
	assert_almost_eq(c.enemy.global_position, POST, Vector2.ONE, "once it is back at its post")
	assert_false(c.enemy.in_pursuit)


func test_it_walks_back_facing_the_way_it_goes() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	await _frames(_tuning.lose_sight_frames + SOME_FRAMES)

	assert_false(c.enemy.in_pursuit)
	assert_eq(c.enemy.facing, Vector2.RIGHT, "its post is to the right of where it waited")


func test_seeing_him_again_before_the_lose_time_starts_the_count_over() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	await _frames(_tuning.lose_sight_frames - SOME_FRAMES)
	assert_true(c.enemy.in_pursuit, "control: it has not given up yet")

	# In front of it, where it waits, and clear of its body.
	c.almos.global_position = c.enemy.global_position + Vector2.LEFT * _tuning.attack_range * 0.75
	await _frames(SOME_FRAMES)
	_hide(c)

	await _frames(_tuning.lose_sight_frames - 1)
	assert_true(c.enemy.in_pursuit, "the count started over when it saw him")
	await _frames(1)
	assert_false(c.enemy.in_pursuit, "and runs its whole length from then")


func test_end_pursuit_ends_it_at_once_and_it_goes_back_to_its_post() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	await _frames(SOME_FRAMES)
	assert_true(c.enemy.in_pursuit, "control: it is in pursuit with the lose-time far off")

	c.enemy.end_pursuit()

	assert_false(c.enemy.in_pursuit, "at once")
	assert_false(c.enemy.noticed)
	await _until(func() -> bool: return c.enemy.global_position.distance_to(POST) < 1.0)
	assert_lt(Engine.get_physics_frames() - c.start_frame, _tuning.lose_sight_frames, "it did not wait for the lose-time to go back")
	assert_false(c.enemy.in_pursuit)


func test_end_pursuit_leaves_an_enemy_at_its_post_where_it_is() -> void:
	var c := _case(FAR_AWAY_SPOT)
	await _frames(SOME_FRAMES)

	c.enemy.end_pursuit()
	await _frames(SOME_FRAMES)

	assert_false(c.enemy.in_pursuit)
	assert_eq(c.enemy.global_position, POST)
	assert_eq(c.enemy.facing, Vector2.LEFT)


func test_it_recovers_no_health_in_pursuit_and_recovers_it_at_the_tuned_rate_once_it_has_lost_him() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	var hurt := _tuning.health_recovery_rate * HURT_SECONDS
	c.enemy.health.take_damage(hurt)
	var hurt_health: float = c.enemy.health.current

	await _frames(_tuning.lose_sight_frames - 1)
	assert_true(c.enemy.in_pursuit, "control: still in pursuit")
	assert_almost_eq(c.enemy.health.current, hurt_health, TOLERANCE, "none in pursuit")

	await _frames(1)
	var at_loss: float = c.enemy.health.current
	var seconds := 0.5
	await _frames(int(seconds * 60.0))

	assert_almost_eq(c.enemy.health.current - at_loss, _tuning.health_recovery_rate * seconds, TOLERANCE, "the tuned rate")


func test_health_recovery_stops_at_the_maximum() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	c.enemy.health.take_damage(_tuning.health_recovery_rate * HURT_SECONDS)
	await _frames(_tuning.lose_sight_frames)

	await _frames(int(HURT_SECONDS * 60.0) + SOME_FRAMES)
	assert_almost_eq(c.enemy.health.current, c.enemy.health.maximum, TOLERANCE, "it is back to full")

	await _frames(SOME_FRAMES)
	assert_almost_eq(c.enemy.health.current, c.enemy.health.maximum, TOLERANCE, "and no more")


func test_noticing_almos_on_its_way_back_resumes_pursuit_with_the_health_it_has_recovered() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	var hurt := _tuning.health_recovery_rate * HURT_SECONDS * 2.0
	c.enemy.health.take_damage(hurt)
	var hurt_health: float = c.enemy.health.current
	await _frames(_tuning.lose_sight_frames + SOME_FRAMES * 4)
	assert_false(c.enemy.in_pursuit, "control: on its way back")
	assert_gt(c.enemy.health.current, hurt_health, "control: it has recovered some")

	# It walks right, so Almos steps in front of it on that side.
	c.almos.global_position = c.enemy.global_position + Vector2.RIGHT * STEP_IN_FRONT
	await _frames(2)
	assert_true(c.enemy.in_pursuit, "it sees him and is after him again")
	var kept: float = c.enemy.health.current
	assert_gt(kept, hurt_health, "it keeps what it has recovered")
	assert_lt(kept, c.enemy.health.maximum, "control: it was not whole yet")

	await _frames(SOME_FRAMES * 2)
	assert_almost_eq(c.enemy.health.current, kept, TOLERANCE, "and recovers none while it is in pursuit again")


func test_a_hit_on_its_way_back_resumes_pursuit() -> void:
	var c := _case()
	await _frames(2)
	_hide(c)
	await _frames(_tuning.lose_sight_frames + SOME_FRAMES)
	assert_false(c.enemy.in_pursuit, "control: on its way back")

	c.enemy.get_node("Hurtbox").landed.emit(0.0, c.enemy.global_position, false)

	assert_true(c.enemy.in_pursuit)


func test_each_of_two_pursuers_gives_up_on_its_own_timeline() -> void:
	var c := _case()
	var first: Node = c.enemy
	var wall_x: float = POST.x - _tuning.sight_length_full * WALL_AT
	var second := _second_enemy(c, Vector2(wall_x, POST.y - _tuning.sight_length_full * 0.75))
	await _frames(2)
	assert_true(first.in_pursuit and second.in_pursuit, "control: both are after him")
	var later_by := SOME_FRAMES * 4
	_hide(c)
	var first_ended := -1
	var second_ended := -1
	for frame in _tuning.lose_sight_frames + later_by + SOME_FRAMES:
		if frame == later_by:
			# Out of sight of the second enemy too, from here.
			c.almos.global_position = FAR_AWAY_SPOT
		await get_tree().physics_frame
		if first_ended < 0 and not first.in_pursuit:
			first_ended = frame + 1
		if second_ended < 0 and not second.in_pursuit:
			second_ended = frame + 1

	assert_eq(first_ended, _tuning.lose_sight_frames, "the first lost him when it ceased to see him")
	assert_eq(second_ended, _tuning.lose_sight_frames + later_by, "the second kept him in sight for longer, and lost him later")


func test_a_sound_hunter_loses_him_when_he_goes_silent() -> void:
	var hunter_tuning := load(HUNTER_TUNING_PATH) as EnemyTuning
	var player := load(AlmosInput.TUNING_PATH) as PlayerTuning
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var almos := room.get_node("Almos") as Node2D
	var hunter := room.get_node("SoundHunter")
	almos.position = POST + Vector2.RIGHT * player.noise_sprint_radius * 0.3
	hunter.position = POST
	hunter.post_facing = Vector2.LEFT
	room.get_node("TrainingEnemy").position = FAR_AWAY
	add_child_autofree(room)
	await _frames(SOME_FRAMES)
	assert_false(hunter.in_pursuit, "control: Almos standing there makes no Noise")

	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	var last_noisy := -1
	var ended := -1
	var silent := false
	for frame in FRAME_LIMIT:
		await get_tree().physics_frame
		if almos.noise_radius > 0.0 and almos.global_position.distance_to(hunter.global_position) <= almos.noise_radius:
			last_noisy = frame
		if not silent and hunter.in_pursuit:
			# It hears him sprint. He stops and is put out of reach of any Noise he might still make.
			_almos_input.release_everything()
			almos.global_position = FAR_AWAY_SPOT
			silent = true
		elif silent and not hunter.in_pursuit:
			ended = frame
			break

	assert_gt(last_noisy, -1, "control: he was still making Noise for a moment")
	assert_eq(ended - last_noisy, hunter_tuning.lose_sight_frames, "it loses him when he has been silent for the lose-time")


func test_the_enemy_death_brings_back_is_at_its_post_and_not_in_pursuit() -> void:
	var c := _case(OPEN_SPOT)
	c.almos.global_position = POST + Vector2.LEFT * _tuning.sight_length_full * SEEN_AT
	await _frames(2)
	assert_true(c.enemy.in_pursuit, "control: it is in pursuit")

	c.almos.health.take_damage(c.almos.health.maximum)
	await _frames(2)
	await _until(func() -> bool: return not c.almos.dead)

	var fresh = c.room.get_node("TrainingEnemy")
	assert_not_same(fresh, c.enemy, "control: it is a new enemy")
	assert_false(fresh.in_pursuit)
	assert_eq(fresh.global_position, POST)
	assert_eq(fresh.facing, Vector2.LEFT, "facing the way it was set")


# --- Helpers ---

# The test room with Almos where the enemy sees him, a wall behind him across the line, and the
# enemy at its post facing left. The Sound hunter is far away. Returns {"room", "almos", "enemy",
# "hidden_at", "start_frame"}. The test frees it.
func _case(almos_at: Vector2 = Vector2.INF) -> Dictionary:
	var length := _tuning.sight_length_full
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var almos := room.get_node("Almos") as Node2D
	var enemy := room.get_node("TrainingEnemy")
	almos.position = POST + Vector2.LEFT * length * SEEN_AT if almos_at == Vector2.INF else almos_at
	enemy.position = POST
	enemy.post_facing = Vector2.LEFT
	room.get_node("SoundHunter").position = FAR_AWAY
	add_child_autofree(room)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_THICKNESS, WALL_HEIGHT)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = POST + Vector2.LEFT * length * WALL_AT
	room.add_child(wall)
	return {
		"room": room, "almos": almos, "enemy": enemy,
		"hidden_at": POST + Vector2.LEFT * length * HIDDEN_AT, "start_frame": Engine.get_physics_frames(),
	}


# A second enemy, which sees Almos across the wall's end, aimed straight down at him.
func _second_enemy(c: Dictionary, at: Vector2) -> Node:
	var enemy := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	enemy.name = "SecondEnemy"
	enemy.position = at
	enemy.tuning = _tuning
	enemy.target = c.almos
	enemy.post_facing = Vector2.DOWN
	c.room.add_child(enemy)
	return enemy


# Almos steps behind the wall, out of the Sight of the enemy in front of it.
func _hide(c: Dictionary) -> void:
	c.almos.global_position = c.hidden_at
	c.start_frame = Engine.get_physics_frames()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# Waits until this is true, for no more than FRAME_LIMIT frames.
func _until(condition: Callable) -> void:
	for i in FRAME_LIMIT:
		if condition.call():
			return
		await get_tree().physics_frame
