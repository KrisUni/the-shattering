extends GutTest
## Resting at the Checkpoint of the test room, through the Interact action: what it refills,
## where it sends Almos back to, which enemies it brings back, and when the press is lost.
## The room is the shipped scene with its shipped tuning.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const ENEMY_SCENE_PATH := "res://scenes/enemies/training_enemy.tscn"
const TOLERANCE := 0.0001
# In pixels. How far from the Checkpoint's centre Almos is put when he is to rest: within reach.
const BESIDE_THE_CHECKPOINT := 10.0
# In pixels. How far inside or outside the edge of his reach he is put to try it.
const REACH_MARGIN := 1.0
# How much of their maximum the bars are taken down by, as a fraction.
const HURT_FRACTION := 0.6
# In physics frames. How long to let a press reach Almos and take effect.
const PRESS_FRAMES := 3
# In pixels. How far below Almos an enemy is put to be within reach of its strike.
const ENEMY_STRIKE_DISTANCE := 30.0
# In pixels. How far from Almos an enemy is put to be within the range of his Lock-on.
const ENEMY_LOCK_ON_DISTANCE := 100.0
# In physics frames. The most a test waits for an enemy to begin a swing.
const WAIT_FRAME_LIMIT := 400
# In physics frames. How long to carry on past the end of a swing to see whether it lands.
const PAST_THE_SWING_FRAMES := 10

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first
	# processed after the first sample and what it presses is seen from the next frame.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_resting_refills_health() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.health.take_damage(tuning.health_maximum * HURT_FRACTION)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_resting_refills_stamina() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.stamina.spend(tuning.stamina_maximum * HURT_FRACTION)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)


func test_resting_announces_the_checkpoint_rested_at() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	watch_signals(almos)

	await _press_interact()

	assert_signal_emitted_with_parameters(almos, "rested", [room.find_child("Checkpoint", true, false)])


func test_a_press_of_interact_rests_only_as_it_is_let_go_of() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)

	_almos_input.press_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
	assert_almost_eq(almos.health.current, hurt, TOLERANCE, "no rest while the button is down")
	_almos_input.release_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)

	assert_almost_eq(almos.health.current, almos.health.maximum, TOLERANCE, "rested as it was let go of")


func test_a_press_held_to_the_drop_does_not_rest_when_it_is_let_go_of() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	watch_signals(almos)

	_almos_input.press_action(&"interact")
	await wait_seconds(tuning.drop_hold_time + 0.2)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)

	assert_signal_not_emitted(almos, "rested")
	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_resting_makes_the_checkpoint_the_return_point() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_eq(room.return_point, checkpoint.global_position)


func test_until_he_rests_the_return_point_is_where_he_started_in_the_room() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)

	assert_eq(room.return_point, almos.global_position)


func test_the_return_point_stays_where_it_was_when_he_walks_away_without_resting() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start := almos.global_position

	almos.global_position += Vector2.RIGHT * 100.0
	await wait_physics_frames(PRESS_FRAMES)

	assert_eq(room.return_point, start)


func test_resting_flashes_the_checkpoint() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Checkpoint = room.find_child("Checkpoint", true, false)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_true(checkpoint.flashing, "the Checkpoint should flash")


func test_resting_works_with_an_enemy_close_by() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var enemy: Node2D = room.find_child("TrainingEnemy", true, false)
	almos.health.take_damage(tuning.health_maximum * HURT_FRACTION)
	_stand_beside_the_checkpoint(room, almos)
	enemy.global_position = almos.global_position + Vector2.RIGHT * 60.0

	await _press_interact()

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_resting_brings_back_a_killed_ordinary_enemy_where_it_started() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start: Vector2 = room.find_child("TrainingEnemy", true, false).global_position
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 0, "the enemy should be dead and gone")
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "one enemy should be back")
	assert_eq(_enemy(room).global_position, start)


func test_resting_gives_the_enemy_it_brings_back_full_health() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_almost_eq(_enemy(room).health.current, enemy_tuning.health_maximum, TOLERANCE)


func test_resting_resets_a_hurt_ordinary_enemy_to_full_health() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_enemy(room).health.take_damage(enemy_tuning.health_maximum * HURT_FRACTION)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_almost_eq(_enemy(room).health.current, enemy_tuning.health_maximum, TOLERANCE)


func test_resting_empties_the_stagger_of_an_ordinary_enemy() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_enemy(room).stagger.add(enemy_tuning.stagger_capacity * HURT_FRACTION)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_almost_eq(_enemy(room).stagger.current, 0.0, TOLERANCE)


func test_resting_puts_a_wandered_ordinary_enemy_back_where_it_started() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start: Vector2 = _enemy(room).global_position
	_enemy(room).global_position = start + Vector2(0.0, 150.0)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "there should be one enemy, not two")
	assert_eq(_enemy(room).global_position, start)


func test_the_enemy_brought_back_goes_after_almos() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_eq(_enemy(room).target, almos)


func test_the_enemy_brought_back_is_processed_after_almos() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_gt(_enemy(room).get_index(), almos.get_index(), "Almos must come first in the tree")


func test_the_enemy_replaced_is_out_of_the_enemies_in_the_frame_of_the_rest() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var old: Node = _enemy(room)
	_stand_beside_the_checkpoint(room, almos)
	# Looked at as the rest is announced, which is in the frame of the press: a frame later the
	# old enemy is freed, and says nothing.
	var still_in_group: Array[bool] = []
	almos.rested.connect(func(_checkpoint: Checkpoint) -> void:
		still_in_group.append(get_tree().get_nodes_in_group("enemies").has(old)))

	await _press_interact()

	assert_eq(still_in_group, [false], "the old enemy should have left the group by then")


func test_killing_the_enemy_brought_back_gives_almos_its_experience_again() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	_stand_beside_the_checkpoint(room, almos)
	await _press_interact()

	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)

	assert_eq(almos.experience.total, enemy_tuning.experience * 2)


func test_resting_does_not_bring_back_a_killed_named_enemy() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room_with_a_named_enemy()
	var almos: Almos = room.find_child("Almos", true, false)
	var named: Node = room.find_child("NamedEnemy", true, false)
	named.health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_null(room.find_child("NamedEnemy", true, false), "the named enemy should stay dead")
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "only the ordinary enemy should be there")


func test_resting_leaves_a_living_named_enemy_as_it_is() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room_with_a_named_enemy()
	var almos: Almos = room.find_child("Almos", true, false)
	var named: Node = room.find_child("NamedEnemy", true, false)
	var hurt := enemy_tuning.health_maximum * HURT_FRACTION
	named.health.take_damage(hurt)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	assert_same(room.find_child("NamedEnemy", true, false), named, "it should be the same enemy")
	assert_almost_eq(named.health.current, enemy_tuning.health_maximum - hurt, TOLERANCE)


func test_resting_brings_back_the_ordinary_enemy_but_not_the_named_one_killed_together() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room_with_a_named_enemy()
	var almos: Almos = room.find_child("Almos", true, false)
	room.find_child("NamedEnemy", true, false).health.take_damage(enemy_tuning.health_maximum)
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	_stand_beside_the_checkpoint(room, almos)

	await _press_interact()

	var back: Array[Node] = get_tree().get_nodes_in_group("enemies")
	assert_eq(back.size(), 1, "one enemy should be back")
	assert_eq(back[0].name, &"TrainingEnemy")


func test_a_press_just_inside_his_reach_rests() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.health.take_damage(tuning.health_maximum * HURT_FRACTION)
	_stand_from_the_checkpoint(room, almos, tuning.rest_reach - REACH_MARGIN)

	await _press_interact()

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_a_press_just_outside_his_reach_does_nothing() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var hurt := tuning.health_maximum * HURT_FRACTION
	almos.health.take_damage(hurt)
	_stand_from_the_checkpoint(room, almos, tuning.rest_reach + REACH_MARGIN)

	await _press_interact()

	assert_almost_eq(almos.health.current, tuning.health_maximum - hurt, TOLERANCE)


func test_a_press_out_of_reach_does_not_move_the_return_point() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start := almos.global_position
	_stand_from_the_checkpoint(room, almos, tuning.rest_reach + REACH_MARGIN)

	await _press_interact()

	assert_eq(room.return_point, start)


func test_a_press_out_of_reach_brings_nobody_back() -> void:
	var enemy_tuning := _enemy_tuning()
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	_stand_from_the_checkpoint(room, almos, tuning.rest_reach + REACH_MARGIN)

	await _press_interact()

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 0)


func test_a_press_is_lost_in_a_roll() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	# He rolls along the Checkpoint, from half a Roll before it, so that he is by it at the press.
	_stand_from_the_checkpoint(room, almos, -tuning.roll_distance / 2.0)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(2)
	_almos_input.release_action(&"roll")
	await wait_physics_frames(2)
	assert_true(almos.rolling, "he should be in a Roll")
	# Where he is when the press is read, which is the frame after this one, before he moves in it.
	assert_lte(almos.global_position.distance_to(checkpoint.global_position), tuning.rest_reach,
			"he should be within reach of the Checkpoint when the press is read")

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_is_lost_while_blocking() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.blocking, "he should be blocking")

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_is_lost_in_a_jump() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"jump")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"jump")
	assert_true(almos.airborne, "he should be in the air")

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_is_lost_in_a_light_attack() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"attack_light")
	assert_true(almos.attacking, "he should be in a swing")

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_is_lost_while_charging_a_heavy_attack() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.charging, "he should be charging")

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_is_lost_in_a_parry() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"parry")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"parry")
	assert_true(almos.parrying, "he should be in a Parry")

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_lost_while_not_free_is_not_kept_for_when_he_is_free_again() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	var hurt := _hurt(almos)
	_almos_input.press_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.press_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"interact")
	_almos_input.release_action(&"block")

	await wait_physics_frames(PRESS_FRAMES)

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_a_press_rests_again_each_time_he_is_free() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	await _press_interact()
	almos.health.take_damage(tuning.health_maximum * HURT_FRACTION)

	await _press_interact()

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_a_press_is_lost_in_a_guard_break() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	# Less Stamina than a blocked hit costs, so that the hit takes the last of it.
	almos.stamina.spend(tuning.stamina_maximum - tuning.block_stamina_cost / 3.0)
	# The Hitbox is made before the settling, so that the physics has it by the time it is on.
	var hits := AlmosHits.new(self)
	var hitbox := hits.hitbox_from(almos, almos.facing * AlmosHits.HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.blocking, "he should be blocking")
	await hits.swing(hitbox, 1)
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.guard_broken, "the blocked hit should have broken his guard")
	var hurt := almos.health.current

	await _press_interact()

	assert_almost_eq(almos.health.current, hurt, TOLERANCE)


func test_resting_twice_in_a_row_leaves_one_enemy_in_its_place() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	await _press_interact()

	await _press_interact()
	await wait_physics_frames(PRESS_FRAMES)

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1)


func test_resting_again_brings_back_the_enemy_killed_since_the_first_rest() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	await _press_interact()
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 0, "the enemy should be dead and gone")

	await _press_interact()

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1)


func test_a_swing_under_way_when_he_rests_does_not_land_afterwards() -> void:
	var tuning := _player_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var old: Node = _enemy(room)
	var swing: AttackData = old.tuning.attack
	_stand_beside_the_checkpoint(room, almos)
	old.global_position = almos.global_position + Vector2.DOWN * ENEMY_STRIKE_DISTANCE
	old.post_facing = Vector2.UP
	for i in WAIT_FRAME_LIMIT:
		if old.attacking:
			break
		await get_tree().physics_frame
	assert_true(old.attacking, "the enemy should begin a swing")

	await _press_interact()
	await wait_physics_frames(swing.total_frames() + PAST_THE_SWING_FRAMES)

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_the_lock_on_to_an_enemy_a_rest_replaces_is_let_go_of() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_stand_beside_the_checkpoint(room, almos)
	_enemy(room).global_position = almos.global_position + Vector2.RIGHT * ENEMY_LOCK_ON_DISTANCE
	_almos_input.press_action(&"lock_on")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"lock_on")
	assert_true(almos.locked_on, "he should have locked on to the enemy")

	await _press_interact()

	assert_false(almos.locked_on, "he should have let go of the enemy that is gone")


# The player tuning of the shipped data file, checked to have what the test needs.
func _player_tuning() -> PlayerTuning:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	assert_gt(tuning.rest_reach, 0.0, "rest_reach in the data file should be positive")
	assert_gt(tuning.drop_hold_time, 0.0, "drop_hold_time in the data file should be positive")
	assert_gt(tuning.health_maximum, 0.0, "health_maximum in the data file should be positive")
	return tuning


func _enemy_tuning() -> EnemyTuning:
	var tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(tuning, "the training enemy tuning data file should load")
	assert_gt(tuning.health_maximum, 0.0, "health_maximum in the data file should be positive")
	return tuning


# These tests count the enemies the room comes with, which they take to be the one Training
# enemy, so the Sound hunter placed in the room is taken out before the room starts.
func _drop_the_sound_hunter(room: Node) -> void:
	var hunter := room.get_node("SoundHunter")
	room.remove_child(hunter)
	hunter.free()


# The test room as shipped. The test frees it.
func _spawn_room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	var room := scene.instantiate()
	_drop_the_sound_hunter(room)
	add_child_autofree(room)
	return room


# The test room with a named enemy added to it before it starts, so that it knows it as it does
# the enemy it comes with. The test frees it.
func _spawn_room_with_a_named_enemy() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	assert_not_null(enemy_scene, "the training enemy scene should load")
	var room := scene.instantiate()
	_drop_the_sound_hunter(room)
	var named := enemy_scene.instantiate()
	named.name = "NamedEnemy"
	named.named = true
	named.position = Vector2(900.0, 500.0)
	# It recovers no Health at its post, so that the Health a test hurts it to is what it is read at.
	named.tuning = (load(ENEMY_TUNING_PATH) as EnemyTuning).duplicate(true)
	named.tuning.health_recovery_rate = 0.0
	named.target = room.find_child("Almos", true, false)
	room.add_child(named)
	add_child_autofree(room)
	return room


# The ordinary enemy the room comes with, which is the one called TrainingEnemy.
func _enemy(room: Node):
	return room.find_child("TrainingEnemy", true, false)


func _stand_beside_the_checkpoint(room: Node, almos: Almos) -> void:
	_stand_from_the_checkpoint(room, almos, BESIDE_THE_CHECKPOINT)


# Puts Almos this far to the right of the Checkpoint's centre.
func _stand_from_the_checkpoint(room: Node, almos: Almos, distance: float) -> void:
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	assert_not_null(checkpoint, "the test room should have a Checkpoint")
	almos.global_position = checkpoint.global_position + Vector2.RIGHT * distance


# Takes some of Almos's Health off and returns how much he has left.
func _hurt(almos: Almos) -> float:
	almos.health.take_damage(almos.health.maximum * HURT_FRACTION)
	return almos.health.current


# Taps Interact, a press let go of well before the hold that drops a Weapon, and lets the tap take
# effect: a tap does its work as it is let go of.
func _press_interact() -> void:
	_almos_input.press_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
