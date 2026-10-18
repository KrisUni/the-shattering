extends GutTest
## The training enemy noticing Almos by its Sight, in the test room with the real Almos and the
## shipped tuning, driven by Input actions. The enemy stands at its post facing a set way until
## Almos is inside its Sight (shorter in the dark zone, blocked by walls) or it is hit. Every
## distance is worked from the enemy's tuning, and nothing here pins a number in it.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
# In pixels. Where Almos stands when the test does not move him: clear of the walls and the pickups.
const OPEN_SPOT := Vector2(300.0, 150.0)
# In physics frames. How long a case that should stay unnoticed is watched for.
const WATCH_FRAMES := 20
# In physics frames. The most a walk towards the enemy may take.
const WALK_FRAME_LIMIT := 600
# In pixels. How far past the edge of the Sight Almos starts the walk.
const WALK_START_MARGIN := 40.0
# In pixels. How far above the enemy Almos stands for a sword to reach it.
const SWORD_DISTANCE := 30.0
const WALL_THICKNESS := 8.0
const WALL_HEIGHT := 200.0
const FAR_AWAY := Vector2(-10000.0, -10000.0)
const TAP_FRAMES := 3

var _almos_input: AlmosInput
var _tuning: EnemyTuning


func before_each() -> void:
	# Start between two physics frames, as real input arrives.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_tuning = load(ENEMY_TUNING_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_an_enemy_with_almos_behind_it_stays_at_its_post_facing_the_set_way() -> void:
	var enemy_at := Vector2(700.0, 324.0)
	var room := _room(enemy_at + Vector2.LEFT * 50.0, enemy_at, Vector2.RIGHT)

	await _watch(WATCH_FRAMES)

	assert_false(room.enemy.in_pursuit)
	assert_eq(room.enemy.facing, Vector2.RIGHT, "it keeps facing the set way")
	assert_eq(room.enemy.position, enemy_at, "it stays where it is")


func test_almos_walking_into_the_cone_is_noticed_once_he_is_within_its_length() -> void:
	var length := _tuning.sight_length_full
	var enemy_at := Vector2(700.0, 324.0)
	var room := _room(enemy_at + Vector2.LEFT * (length + WALK_START_MARGIN), enemy_at, Vector2.LEFT)
	await _watch(WATCH_FRAMES)
	assert_false(room.enemy.in_pursuit, "outside the length he is not noticed")

	_almos_input.press_action(&"move_right")
	var distance_when_noticed := await _walk_until_noticed(room)
	_almos_input.release_action(&"move_right")

	assert_true(room.enemy.in_pursuit, "he should be noticed on the way")
	assert_lte(distance_when_noticed, length, "noticed no farther than the length")


func test_almos_standing_at_a_distance_is_noticed_in_the_light_but_not_in_the_dark_zone() -> void:
	assert_lt(_tuning.sight_length_dark, _tuning.sight_length_full, "the dark must shorten the Sight")
	var distance := (_tuning.sight_length_dark + _tuning.sight_length_full) / 2.0

	var dark := _dark_zone_case(distance, false)
	await _watch(WATCH_FRAMES)
	assert_false(dark.enemy.in_pursuit, "in the dark zone he is beyond the shortened Sight")
	await _retire(dark)

	var lit := _dark_zone_case(distance, true)
	await _watch(WATCH_FRAMES)
	assert_true(lit.enemy.in_pursuit, "the same distance in the light is within the Sight")


func test_almos_close_enough_is_noticed_even_in_the_dark_zone() -> void:
	var room := _dark_zone_case(_tuning.sight_length_dark / 2.0, false)

	await _watch(WATCH_FRAMES)

	assert_true(room.enemy.in_pursuit)


func test_almos_in_front_of_the_enemy_is_noticed_but_behind_it_he_is_not() -> void:
	var distance := _tuning.sight_length_dark / 2.0
	var enemy_at := Vector2(700.0, 324.0)
	var in_front := _room(enemy_at + Vector2.LEFT * distance, enemy_at, Vector2.LEFT)
	await _watch(WATCH_FRAMES)
	assert_true(in_front.enemy.in_pursuit, "in front of it he is noticed")
	await _retire(in_front)

	var behind := _room(enemy_at + Vector2.LEFT * distance, enemy_at, Vector2.RIGHT)
	await _watch(WATCH_FRAMES)
	assert_false(behind.enemy.in_pursuit, "behind it he is not")


func test_almos_behind_a_wall_is_not_noticed_but_without_the_wall_he_is() -> void:
	var distance := _tuning.sight_length_dark / 2.0
	var enemy_at := Vector2(700.0, 324.0)
	var walled := _room(enemy_at + Vector2.LEFT * distance, enemy_at, Vector2.LEFT)
	_wall_in(walled.room, enemy_at + Vector2.LEFT * distance / 2.0)
	await _watch(WATCH_FRAMES)
	assert_false(walled.enemy.in_pursuit, "the wall blocks the Sight")
	await _retire(walled)

	var open := _room(enemy_at + Vector2.LEFT * distance, enemy_at, Vector2.LEFT)
	await _watch(WATCH_FRAMES)
	assert_true(open.enemy.in_pursuit, "without the wall he is seen")


func test_a_hit_from_behind_is_noticed() -> void:
	var enemy_at := OPEN_SPOT + Vector2.DOWN * SWORD_DISTANCE
	var room := _room(OPEN_SPOT, enemy_at, Vector2.DOWN)
	await _watch(WATCH_FRAMES)
	assert_false(room.enemy.in_pursuit, "control: Almos behind it is not noticed before the hit")
	var swing := (load("res://data/sword.tres") as WeaponData).light_attacks[0]

	_almos_input.press_action(&"attack_light")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	await _watch(swing.startup_frames + swing.active_frames)

	assert_lt(room.enemy.health.current, room.enemy.health.maximum, "the blow should have landed")
	assert_true(room.enemy.in_pursuit)


# --- Helpers ---

# The test room with Almos and the room's training enemy put here before it enters the tree,
# the enemy standing at its post facing this way. Returns {"room", "almos", "enemy"}. The test
# frees it.
func _room(almos_at: Vector2, enemy_at: Vector2, enemy_facing: Vector2) -> Dictionary:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var almos := room.find_child("Almos", true, false) as Node2D
	var enemy := room.find_child("TrainingEnemy", true, false)
	almos.position = almos_at
	enemy.position = enemy_at
	enemy.post_facing = enemy_facing
	add_child_autofree(room)
	return {"room": room, "almos": almos, "enemy": enemy}


# A room with Almos standing in the dark zone's centre (or the zone moved far away, so that
# he stands in the light), and the enemy this far to his left, facing him.
func _dark_zone_case(distance: float, zone_away: bool) -> Dictionary:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var zone := room.find_child("DarkZone", true, false) as Node2D
	var almos := room.find_child("Almos", true, false) as Node2D
	var enemy := room.find_child("TrainingEnemy", true, false)
	var centre := zone.position
	if zone_away:
		zone.position = FAR_AWAY
	almos.position = centre
	enemy.position = centre + Vector2.LEFT * distance
	enemy.post_facing = Vector2.RIGHT
	add_child_autofree(room)
	return {"room": room, "almos": almos, "enemy": enemy}


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


# Frees a case's room at once, so that its light zone and walls do not reach the next one.
func _retire(room_case: Dictionary) -> void:
	room_case.room.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _watch(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


# Waits until the enemy has noticed Almos, or the limit; returns how far apart they stood in
# the frame it did, read before anything moved in the frame after it.
func _walk_until_noticed(room: Dictionary) -> float:
	for i in WALK_FRAME_LIMIT:
		await get_tree().physics_frame
		if room.enemy.in_pursuit:
			return room.almos.global_position.distance_to(room.enemy.global_position)
	return INF
