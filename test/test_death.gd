extends GutTest
## Almos's Death, seen only through his scene: what his Health reaching zero does to him, the
## limp pause that follows, how he comes back from it whatever he was doing, and the room's part
## in a Death: where he goes, the Remains, the enemies, the "Fallen" label. Expected numbers come
## from the tuning data files; the actions he is put in are begun with input actions.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const ENEMY_SCENE_PATH := "res://scenes/enemies/training_enemy.tscn"
const TOLERANCE := 0.0001
# In physics frames. How long to let a press reach Almos and take effect.
const PRESS_FRAMES := 3
# In physics frames. How long a limp Almos is watched to see whether he does anything.
const WATCH_FRAMES := 20
# In pixels. How far from Almos an enemy is put to be within the range of his Lock-on.
const ENEMY_LOCK_ON_DISTANCE := 100.0
# In pixels. Where Almos is sent back to in these tests, away from wherever he fell.
const RETURN_POINT := Vector2(300.0, 200.0)
# In pixels. Where he is put before he falls, clear of the origin that the return point is read from.
const FALL_POINT := Vector2(700.0, 500.0)
# In physics frames. Keeps a time that is a whole number of frames from being counted as one more.
const FRAME_COUNT_ALLOWANCE := 0.0001
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
# In pixels. Where Almos dies in the room: clear of the walls, the gap, the ledge and the start.
const DEATH_SPOT := Vector2(576.0, 474.0)
# In pixels. Another place to die at, a long way from the first and from the start.
const OTHER_DEATH_SPOT := Vector2(900.0, 150.0)
# In Experience. What he carries when he dies, apart from what an enemy gives.
const CARRIED := 137
# In Experience. What he carries at a second death.
const CARRIED_LATER := 61
# In pixels. How far from Almos an enemy is put to be within reach of its strike.
const ENEMY_STRIKE_DISTANCE := 30.0
# In physics frames. The most a test waits for an enemy to strike.
const WAIT_FRAME_LIMIT := 400
# In physics frames. How long Almos is walked to reach Remains 150 pixels away, with room to spare.
const WALK_FRAMES := 150
# In pixels. How far along the ledge Almos is set down at his second climb, short of where he fell.
const LEDGE_WALK := 60.0
# In physics frames. The most a Jump onto the ledge is waited for to end.
const JUMP_FRAME_LIMIT := 120
# In physics frames. How far before the end of the pause a late press is made.
const LATE_PRESS_BEFORE_END := 8

# What he does when each of these buttons is pressed on a free Almos, and which of his states
# shows it.
var action_params = ParameterFactory.named_parameters(
	["action", "state"],
	[
		[&"roll", "rolling"],
		[&"attack_light", "attacking"],
		[&"attack_heavy", "charging"],
		[&"jump", "airborne"],
		[&"block", "blocking"],
		[&"parry", "parrying"],
	],
)

# A press made early or late in the pause, as the frames to wait after he falls: late is a few
# frames before the pause is over. The first four are a button that starts something on a free Almos,
# with which of his states shows it.
var press_in_pause_params = ParameterFactory.named_parameters(
	["action", "state", "late"],
	[
		[&"attack_light", "attacking", false],
		[&"attack_light", "attacking", true],
		[&"roll", "rolling", false],
		[&"roll", "rolling", true],
	],
)

var interact_time_params = ParameterFactory.named_parameters(
	["late"],
	[[false], [true]],
)

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_he_is_not_limp_while_he_has_health_left() -> void:
	var almos := _spawn_almos()

	almos.health.take_damage(almos.health.maximum - 1.0)

	assert_false(almos.dead)


func test_he_goes_limp_when_his_health_reaches_zero() -> void:
	var almos := _spawn_almos()

	_kill(almos)

	assert_true(almos.dead)


func test_his_death_is_announced_with_the_place_he_fell() -> void:
	var almos := _spawn_almos()
	almos.global_position = FALL_POINT
	watch_signals(almos)

	_kill(almos)

	assert_signal_emitted_with_parameters(almos, "died", [FALL_POINT])


func test_he_cannot_be_hit_while_limp() -> void:
	var almos := _spawn_almos()
	var hurtbox: Hurtbox = almos.find_child("Hurtbox", true, false)
	_kill(almos)

	var outcome := hurtbox.hurt(AlmosHits.HIT_DAMAGE, almos.global_position + Vector2.RIGHT * AlmosHits.HIT_DISTANCE)

	assert_eq(outcome, Hurtbox.Outcome.MISSED)
	assert_true(almos.untouchable, "he should be untouchable")


func test_a_blow_that_arrives_while_he_is_limp_spends_none_of_his_stamina() -> void:
	var almos := _spawn_almos()
	_almos_input.press_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.blocking, "he should be blocking as he falls, with the button still held")
	_kill(almos)
	var before: float = almos.stamina.current
	var hits := AlmosHits.new(self)
	var hitbox := hits.hitbox_from(almos, almos.facing * AlmosHits.HIT_DISTANCE)
	await wait_physics_frames(PRESS_FRAMES)

	await hits.swing(hitbox, 2)

	assert_almost_eq(almos.stamina.current, before, TOLERANCE)


func test_pressing_a_button_does_nothing_while_he_is_limp(params = use_parameters(action_params)) -> void:
	var almos := _spawn_almos()
	_kill(almos)

	_almos_input.press_action(params.action)
	await wait_physics_frames(WATCH_FRAMES)

	assert_false(almos.get(params.state), "he should not be %s while limp" % params.state)


func test_he_does_not_move_while_limp() -> void:
	var almos := _spawn_almos()
	almos.global_position = FALL_POINT
	_kill(almos)

	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(almos.global_position, FALL_POINT)


func test_he_cannot_rest_while_limp() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	almos.global_position = checkpoint.global_position
	watch_signals(almos)
	_kill(almos)
	assert_gt(tuning.rest_reach, 0.0)

	_almos_input.press_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)

	assert_signal_not_emitted(almos, "rested")


func test_he_cannot_lock_on_while_limp() -> void:
	var almos := _spawn_almos()
	_add_an_enemy_in_lock_on_range(almos)
	_kill(almos)

	_almos_input.press_action(&"lock_on")
	await wait_physics_frames(PRESS_FRAMES)

	assert_false(almos.locked_on)


func test_the_pause_ends_after_the_tuned_number_of_frames() -> void:
	var tuning := _tuning()
	assert_gt(tuning.death_pause, 0.0, "death_pause in the data file should be positive")
	var almos := _spawn_almos()
	var frames: Array[int] = []
	almos.died.connect(func(_place: Vector2) -> void: frames.append(Engine.get_physics_frames()))
	almos.death_pause_over.connect(func() -> void: frames.append(Engine.get_physics_frames()))

	_kill(almos)
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) + PRESS_FRAMES)

	assert_eq(frames.size(), 2, "he should have fallen and the pause should have ended")
	if frames.size() == 2:
		assert_eq(frames[1] - frames[0], _frames_to_reach(tuning.death_pause))


func test_the_pause_does_not_end_a_frame_early() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	watch_signals(almos)

	_kill(almos)
	# Each wait ends before the next frame is processed, so the frame the pause ends in has not been
	# processed after this many: a pause that ended a frame early would have ended by now.
	for i in _frames_to_reach(tuning.death_pause):
		await get_tree().physics_frame

	assert_signal_not_emitted(almos, "death_pause_over")


func test_the_pause_ends_once() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	watch_signals(almos)

	_kill(almos)
	await wait_physics_frames(2 * _frames_to_reach(tuning.death_pause))

	assert_signal_emit_count(almos, "death_pause_over", 1)


func test_a_pause_of_no_time_ends_in_the_first_frame_after_he_falls() -> void:
	var tuning := _tuning().duplicate() as PlayerTuning
	tuning.death_pause = 0.0
	var almos: Almos = _almos_input.spawn_almos(tuning)
	watch_signals(almos)

	_kill(almos)
	await wait_physics_frames(PRESS_FRAMES)

	assert_signal_emit_count(almos, "death_pause_over", 1)


func test_he_stays_limp_after_the_pause_until_he_is_returned() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()

	_kill(almos)
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) + PRESS_FRAMES)

	assert_true(almos.dead)


func test_returning_puts_him_on_his_feet_at_the_point() -> void:
	var almos := _spawn_almos()
	almos.global_position = FALL_POINT
	_kill(almos)

	almos.return_to(RETURN_POINT)

	assert_false(almos.dead)
	assert_eq(almos.global_position, RETURN_POINT)


func test_returning_announces_it() -> void:
	var almos := _spawn_almos()
	_kill(almos)
	watch_signals(almos)

	almos.return_to(RETURN_POINT)

	assert_signal_emit_count(almos, "returned", 1)


func test_returning_refills_his_health_and_stamina() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	almos.stamina.spend(tuning.stamina_maximum)
	_kill(almos)

	almos.return_to(RETURN_POINT)

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)


func test_he_can_be_hit_again_once_returned() -> void:
	var almos := _spawn_almos()
	var hurtbox: Hurtbox = almos.find_child("Hurtbox", true, false)
	_kill(almos)
	almos.return_to(RETURN_POINT)

	var outcome := hurtbox.hurt(AlmosHits.HIT_DAMAGE, almos.global_position + Vector2.RIGHT * AlmosHits.HIT_DISTANCE)

	assert_eq(outcome, Hurtbox.Outcome.LANDED)
	assert_almost_eq(almos.health.current, _tuning().health_maximum - AlmosHits.HIT_DAMAGE, TOLERANCE)


func test_he_can_die_again_after_returning() -> void:
	var almos := _spawn_almos()
	_kill(almos)
	almos.return_to(RETURN_POINT)
	watch_signals(almos)

	_kill(almos)

	assert_true(almos.dead)
	assert_signal_emit_count(almos, "died", 1)


func test_he_moves_again_once_returned() -> void:
	var almos := _spawn_almos()
	_kill(almos)
	almos.return_to(RETURN_POINT)

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WATCH_FRAMES)

	assert_gt(almos.global_position.x, RETURN_POINT.x)


func test_a_death_in_a_roll_comes_back_clean() -> void:
	var almos := _spawn_almos()
	_almos_input.press_action(&"move_right")
	await _tap(&"roll")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.rolling, "he should be in a Roll")

	_kill(almos)
	assert_false(almos.rolling, "the Roll should end as he falls")
	almos.return_to(RETURN_POINT)
	_almos_input.release_action(&"move_right")
	await wait_physics_frames(PRESS_FRAMES)

	_assert_free_and_clean(almos)


func test_a_roll_kept_for_the_end_of_one_when_he_dies_does_not_follow_his_next_roll() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	await _tap(&"roll")
	while not almos.rolling:
		await get_tree().physics_frame
	# Well inside the last of the Roll, where a tap is kept for the end of it: the button goes down
	# in one frame and up in the next, and the tap is read in that one.
	for i in _frames_to_reach(tuning.roll_duration - tuning.roll_buffer_window) + 1:
		await get_tree().physics_frame
	_almos_input.press_action(&"roll")
	await get_tree().physics_frame
	_almos_input.release_action(&"roll")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(almos.rolling, "he should still be in the Roll")
	_kill(almos)
	almos.return_to(RETURN_POINT)
	await _tap(&"roll")

	await wait_physics_frames(_frames_to_reach(tuning.roll_duration) + PRESS_FRAMES)

	assert_false(almos.rolling, "no second Roll should follow the one he rolled after returning")


func test_a_death_in_a_light_swing_comes_back_clean() -> void:
	var almos := _spawn_almos()
	await _tap(&"attack_light")
	assert_true(almos.attacking, "he should be in a swing")

	_kill(almos)
	assert_false(almos.attacking, "the swing should end as he falls")
	almos.return_to(RETURN_POINT)

	_assert_free_and_clean(almos)


func test_a_death_while_charging_a_heavy_attack_comes_back_clean() -> void:
	var almos := _spawn_almos()
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.charging, "he should be charging")

	_kill(almos)
	assert_false(almos.charging, "the charge should end as he falls")
	almos.return_to(RETURN_POINT)
	_almos_input.release_action(&"attack_heavy")
	await wait_physics_frames(PRESS_FRAMES)

	_assert_free_and_clean(almos)


func test_a_death_in_a_block_comes_back_clean() -> void:
	var almos := _spawn_almos()
	_almos_input.press_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.blocking, "he should be blocking")

	_kill(almos)
	assert_false(almos.blocking, "the Block should end as he falls")
	almos.return_to(RETURN_POINT)
	_almos_input.release_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)

	_assert_free_and_clean(almos)


func test_a_death_in_a_guard_break_comes_back_clean() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	# Less Stamina than a blocked hit costs, so that the hit takes the last of it.
	almos.stamina.spend(tuning.stamina_maximum - tuning.block_stamina_cost / 3.0)
	var hits := AlmosHits.new(self)
	var hitbox := hits.hitbox_from(almos, almos.facing * AlmosHits.HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)
	await hits.swing(hitbox, 1)
	await wait_physics_frames(PRESS_FRAMES)
	assert_true(almos.guard_broken, "the blocked hit should have broken his guard")

	_kill(almos)
	assert_false(almos.guard_broken, "the Guard break should end as he falls")
	almos.return_to(RETURN_POINT)
	_almos_input.release_action(&"block")
	await wait_physics_frames(PRESS_FRAMES)

	_assert_free_and_clean(almos)


func test_a_death_in_a_parry_comes_back_clean() -> void:
	var almos := _spawn_almos()
	await _tap(&"parry")
	assert_true(almos.parrying, "he should be in a Parry")

	_kill(almos)
	assert_false(almos.parrying, "the Parry should end as he falls")
	almos.return_to(RETURN_POINT)

	_assert_free_and_clean(almos)


func test_a_death_in_the_recovery_of_a_parry_comes_back_with_his_colour_back() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	await _tap(&"parry")
	await wait_physics_frames(tuning.parry_window_frames)
	assert_true(almos.parrying and not almos.parry_window_open, "he should be in the recovery of a Parry")
	var placeholder: CanvasItem = almos.find_child("Placeholder", true, false)
	assert_ne(placeholder.modulate, Color.WHITE, "the recovery should tint him")

	_kill(almos)
	almos.return_to(RETURN_POINT)

	assert_eq(placeholder.modulate, Color.WHITE)


func test_a_death_in_the_air_comes_back_on_the_ground() -> void:
	var almos := _spawn_almos()
	_almos_input.press_action(&"move_right")
	await _tap(&"jump")
	assert_true(almos.airborne, "he should be in the air")

	_kill(almos)
	assert_false(almos.airborne, "the Jump should end as he falls")
	almos.return_to(RETURN_POINT)

	_assert_free_and_clean(almos)


func test_a_death_in_a_jump_attack_comes_back_clean() -> void:
	var almos := _spawn_almos()
	await _tap(&"jump")
	await _tap(&"attack_heavy")
	assert_true(almos.jump_attacking, "he should be in a Jump attack")

	_kill(almos)
	assert_false(almos.jump_attacking, "the Jump attack should end as he falls")
	almos.return_to(RETURN_POINT)
	await wait_physics_frames(_frames_to_reach(_tuning().jump_duration))

	_assert_free_and_clean(almos)


func test_a_death_under_lock_on_comes_back_free_of_it() -> void:
	var almos := _spawn_almos()
	_add_an_enemy_in_lock_on_range(almos)
	await _tap(&"lock_on")
	assert_true(almos.locked_on, "he should have locked on")

	_kill(almos)
	assert_false(almos.locked_on, "the lock should let go as he falls")
	almos.return_to(RETURN_POINT)

	_assert_free_and_clean(almos)


func test_a_sprint_ends_with_his_death() -> void:
	var almos := _spawn_almos()
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_seconds(_tuning().roll_hold_threshold + 0.1)
	assert_true(almos.sprinting, "he should be sprinting")

	_kill(almos)
	assert_false(almos.sprinting, "the Sprint should end as he falls")
	almos.return_to(RETURN_POINT)
	_almos_input.release_action(&"roll")
	_almos_input.release_action(&"move_right")
	await wait_physics_frames(PRESS_FRAMES)

	_assert_free_and_clean(almos)


func test_a_roll_button_held_through_the_death_sprints_him_only_after_a_new_hold_on_his_return() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_seconds(tuning.roll_hold_threshold + 0.1)
	assert_true(almos.sprinting, "he should be sprinting")
	_kill(almos)
	almos.return_to(RETURN_POINT)

	await wait_physics_frames(PRESS_FRAMES)
	assert_false(almos.sprinting, "the hold before the death should not count")
	await wait_seconds(tuning.roll_hold_threshold + 0.1)
	assert_false(almos.sprinting, "the button held over the return should not sprint him later either")
	_almos_input.release_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.press_action(&"roll")
	await wait_seconds(tuning.roll_hold_threshold + 0.1)

	assert_true(almos.sprinting, "a hold begun after the return should sprint him")


func test_a_roll_button_held_through_the_death_and_let_go_soon_after_the_return_does_not_roll_him() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	_almos_input.press_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)
	_kill(almos)
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) + PRESS_FRAMES)
	almos.return_to(RETURN_POINT)

	# Let go well inside the hold threshold after the return, where a press made then would be a tap.
	assert_lt(float(PRESS_FRAMES) / Engine.physics_ticks_per_second, tuning.roll_hold_threshold)
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)

	assert_false(almos.rolling, "a press made before the death should not roll him after it")
	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)


func test_a_roll_button_pressed_in_the_pause_and_let_go_soon_after_the_return_does_not_roll_him() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	_kill(almos)
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.press_action(&"roll")
	await wait_physics_frames(_frames_to_reach(tuning.death_pause))
	almos.return_to(RETURN_POINT)

	assert_lt(float(PRESS_FRAMES) / Engine.physics_ticks_per_second, tuning.roll_hold_threshold)
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)

	assert_false(almos.rolling, "a press made while he was limp should not roll him after the return")
	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)


func test_a_roll_button_let_go_and_pressed_again_after_the_return_rolls_him() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	_almos_input.press_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)
	_kill(almos)
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) + PRESS_FRAMES)
	almos.return_to(RETURN_POINT)
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)

	await _tap(&"roll")
	await wait_physics_frames(PRESS_FRAMES)

	assert_true(almos.rolling, "a new tap after the return should roll him")


func test_being_out_of_breath_when_he_dies_does_not_stop_a_new_hold_sprinting_him_on_his_return() -> void:
	var tuning := _tuning()
	var almos := _spawn_almos()
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	# Held until the Sprint has used up all his Stamina and dropped him back to a walk.
	await wait_seconds(tuning.stamina_maximum / tuning.sprint_stamina_per_second + 0.5)
	assert_false(almos.sprinting, "he should be out of breath")
	_kill(almos)
	almos.return_to(RETURN_POINT)
	# The hold over the return counts for nothing, so it is let go of and made again.
	_almos_input.release_action(&"roll")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.press_action(&"roll")

	await wait_seconds(tuning.roll_hold_threshold + 0.1)

	assert_true(almos.sprinting, "he should sprint again, with his Stamina back")


func test_death_sends_him_back_to_where_he_started_in_the_room_with_full_bars() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start := almos.global_position
	almos.global_position = DEATH_SPOT
	almos.stamina.spend(tuning.stamina_maximum)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_false(almos.dead, "he should be on his feet")
	assert_eq(almos.global_position, start)
	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)


func test_death_sends_him_back_to_the_checkpoint_he_last_rested_at() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	almos.global_position = checkpoint.global_position
	await _tap(&"interact")
	almos.global_position = DEATH_SPOT

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(almos.global_position, checkpoint.global_position)


func test_he_stays_where_he_fell_for_the_whole_pause() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT

	_kill(almos)
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) - PRESS_FRAMES)

	assert_true(almos.dead, "he should still be limp")
	assert_eq(almos.global_position, DEATH_SPOT)


func test_death_takes_all_his_experience() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var label: Label = room.find_child("ExperienceLabel", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(almos.experience.total, 0)
	assert_true(label.text.ends_with("0"), "the label should show none")


func test_the_fallen_label_is_hidden_while_he_is_on_his_feet() -> void:
	var room := _spawn_room()

	var label: Label = room.find_child("FallenLabel", true, false)

	assert_not_null(label, "the room should have a FallenLabel")
	assert_false(label.visible)


func test_the_fallen_label_shows_for_the_whole_pause() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var label: Label = room.find_child("FallenLabel", true, false)

	_kill(almos)
	assert_true(label.visible, "it should show as he falls")
	assert_string_contains(label.text, "Fallen")
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) - PRESS_FRAMES)

	assert_true(label.visible, "it should show to the end of the pause")


func test_the_fallen_label_goes_when_he_returns() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var label: Label = room.find_child("FallenLabel", true, false)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_false(label.visible)


func test_dying_with_experience_leaves_remains_where_he_fell_holding_it() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)

	_kill(almos)
	await _wait_out_the_pause(almos)

	var remains := _all_remains()
	assert_eq(remains.size(), 1, "there should be one set of Remains")
	if remains.size() == 1:
		assert_eq(remains[0].global_position, DEATH_SPOT)
		assert_eq(remains[0].amount, CARRIED)


func test_the_remains_are_made_when_he_returns_not_before() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.experience.gain(CARRIED)

	_kill(almos)
	await wait_physics_frames(_frames_to_reach(tuning.death_pause) - PRESS_FRAMES)

	assert_eq(_all_remains().size(), 0)


func test_dying_with_no_experience_leaves_no_remains() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(_all_remains().size(), 0)


func test_reaching_the_remains_gives_him_the_experience_back_and_removes_them() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	assert_eq(almos.experience.total, 0, "he should be back with none")

	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)

	assert_eq(almos.experience.total, CARRIED)
	assert_eq(_all_remains().size(), 0, "the Remains should be gone")


func test_dying_at_the_return_point_gives_him_the_experience_straight_back() -> void:
	# The accepted gap: the Remains are made where he fell, which here is where he comes back.
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)

	await wait_physics_frames(PRESS_FRAMES)

	assert_eq(almos.experience.total, CARRIED)
	assert_eq(_all_remains().size(), 0)


func test_the_experience_shown_comes_back_with_the_remains() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var label: Label = room.find_child("ExperienceLabel", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)

	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)

	assert_true(label.text.ends_with(str(CARRIED)), "the label should show the recovered Experience")


func test_dying_again_before_reaching_the_remains_destroys_them_and_leaves_new_ones() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	var old := _all_remains()[0]
	almos.experience.gain(CARRIED_LATER)
	almos.global_position = OTHER_DEATH_SPOT

	_kill(almos)
	await _wait_out_the_pause(almos)

	var remains := _all_remains()
	assert_eq(remains.size(), 1, "there should only ever be one set of Remains")
	assert_false(is_instance_valid(old) and old.is_inside_tree(), "the old Remains should be destroyed")
	if remains.size() == 1:
		assert_eq(remains[0].global_position, OTHER_DEATH_SPOT)
		assert_eq(remains[0].amount, CARRIED_LATER, "they hold what he lost this time, not what the old ones held")


func test_dying_again_with_no_experience_destroys_the_old_remains_and_leaves_none() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	almos.global_position = OTHER_DEATH_SPOT

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(_all_remains().size(), 0)
	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)
	assert_eq(almos.experience.total, 0, "what the old Remains held is lost")


func test_resting_leaves_the_remains_where_they_are() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	almos.global_position = OTHER_DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	var before := _all_remains()[0]
	almos.global_position = checkpoint.global_position

	await _tap(&"interact")

	var remains := _all_remains()
	assert_eq(remains.size(), 1)
	if remains.size() == 1:
		assert_same(remains[0], before)
		assert_eq(remains[0].global_position, OTHER_DEATH_SPOT)
		assert_eq(remains[0].amount, CARRIED)


func test_death_brings_back_a_killed_ordinary_enemy_where_it_started() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start: Vector2 = _enemy(room).global_position
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 0, "the enemy should be dead and gone")

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "one enemy should be back")
	assert_eq(_enemy(room).global_position, start)
	assert_almost_eq(_enemy(room).health.current, enemy_tuning.health_maximum, TOLERANCE)
	assert_eq(_enemy(room).target, almos)


func test_death_puts_a_hurt_ordinary_enemy_back_to_full_health_in_its_place() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var start: Vector2 = _enemy(room).global_position
	_enemy(room).health.take_damage(enemy_tuning.health_maximum / 2.0)
	_enemy(room).global_position = start + Vector2(0.0, 150.0)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "there should be one enemy, not two")
	assert_eq(_enemy(room).global_position, start)
	assert_almost_eq(_enemy(room).health.current, enemy_tuning.health_maximum, TOLERANCE)


func test_death_does_not_bring_back_a_killed_named_enemy() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room_with_a_named_enemy()
	var almos: Almos = room.find_child("Almos", true, false)
	room.find_child("NamedEnemy", true, false).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_null(room.find_child("NamedEnemy", true, false), "the named enemy should stay dead")
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "only the ordinary enemy should be there")


func test_death_leaves_a_living_named_enemy_as_it_is() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room_with_a_named_enemy()
	var almos: Almos = room.find_child("Almos", true, false)
	var named: Node = room.find_child("NamedEnemy", true, false)
	named.health.take_damage(enemy_tuning.health_maximum / 2.0)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_same(room.find_child("NamedEnemy", true, false), named)
	assert_almost_eq(named.health.current, enemy_tuning.health_maximum / 2.0, TOLERANCE)


func test_the_enemies_death_brings_back_are_processed_after_almos() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_gt(_enemy(room).get_index(), almos.get_index(), "Almos must come first in the tree")


func test_the_enemy_a_death_replaces_is_out_of_the_enemies_in_the_frame_he_returns() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var old: Node = _enemy(room)
	var still_in_group: Array[bool] = []
	almos.returned.connect(func() -> void:
		still_in_group.append(get_tree().get_nodes_in_group("enemies").has(old)))

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(still_in_group, [false], "the old enemy should have left the group by then")


func test_an_enemys_blow_can_kill_him_and_he_comes_back_with_the_remains_where_it_landed() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var enemy: Node = _enemy(room)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	almos.health.take_damage(almos.health.maximum - 1.0)
	enemy.global_position = DEATH_SPOT + Vector2.DOWN * ENEMY_STRIKE_DISTANCE
	for i in WAIT_FRAME_LIMIT:
		if almos.dead:
			break
		await get_tree().physics_frame
	assert_true(almos.dead, "the enemy's blow should kill him")

	await _wait_out_the_pause(almos)

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)
	var remains := _all_remains()
	assert_eq(remains.size(), 1)
	if remains.size() == 1:
		assert_eq(remains[0].amount, CARRIED)
		assert_almost_eq(remains[0].global_position.x, DEATH_SPOT.x, 1.0)


func test_a_death_on_the_low_ledge_leaves_the_remains_on_it() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.experience.gain(CARRIED)
	await _jump_onto_the_ledge(room, almos, 0.0)
	assert_eq(almos.height_level, 1, "he should be on the ledge")
	var fall_place := almos.global_position

	_kill(almos)
	await _wait_out_the_pause(almos)

	var remains := _all_remains()
	assert_eq(remains.size(), 1, "there should be one set of Remains")
	if remains.size() == 1:
		assert_eq(remains[0].global_position, fall_place)
		assert_true(_ledge_rect(room).has_point(remains[0].global_position), "they should lie on the ledge")


func test_he_recovers_the_remains_on_the_ledge_by_walking_up_to_them_there() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.experience.gain(CARRIED)
	await _jump_onto_the_ledge(room, almos, 0.0)
	_kill(almos)
	await _wait_out_the_pause(almos)
	assert_eq(almos.height_level, 0, "he should be back on the ground")
	await _jump_onto_the_ledge(room, almos, -LEDGE_WALK)
	assert_eq(_all_remains().size(), 1, "they should be out of reach still")

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(WALK_FRAMES)

	assert_eq(almos.experience.total, CARRIED)
	assert_eq(_all_remains().size(), 0, "the Remains should be gone")


func test_experience_gained_after_a_death_is_added_to_what_the_remains_give_back() -> void:
	var enemy_experience := _enemy_tuning().experience
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	_enemy(room).health.take_damage(_enemy_tuning().health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(almos.experience.total, enemy_experience, "the enemy's Experience should be his")

	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)

	assert_eq(almos.experience.total, CARRIED + enemy_experience)


func test_the_first_remains_are_freed_when_a_second_death_destroys_them() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	var old := _all_remains()[0]
	almos.experience.gain(CARRIED_LATER)
	almos.global_position = OTHER_DEATH_SPOT

	_kill(almos)
	await _wait_out_the_pause(almos)
	await wait_physics_frames(PRESS_FRAMES)

	assert_false(is_instance_valid(old), "the first Remains should be freed, not left about")


func test_the_first_remains_are_out_of_the_remains_group_in_the_frame_of_the_second_set() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = DEATH_SPOT
	almos.experience.gain(CARRIED)
	_kill(almos)
	await _wait_out_the_pause(almos)
	var old_id := _all_remains()[0].get_instance_id()
	almos.experience.gain(CARRIED_LATER)
	almos.global_position = OTHER_DEATH_SPOT
	# Read once the frame's work for the return is done, while a node only queued to be freed is
	# still in the scene.
	var seen: Array[Array] = []
	almos.returned.connect(func() -> void:
		seen.append(_all_remains().map(func(node: Node) -> int: return node.get_instance_id())),
		CONNECT_DEFERRED)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(seen.size(), 1, "the return should be seen once")
	if seen.size() == 1:
		assert_eq(seen[0].size(), 1, "only the new Remains should be among them")
		assert_false(seen[0].has(old_id), "the first Remains should not be among them")


func test_a_death_after_a_rest_brings_back_the_ordinary_enemy_killed_since() -> void:
	var enemy_tuning := _enemy_tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	var start: Vector2 = _enemy(room).global_position
	almos.global_position = checkpoint.global_position
	await _tap(&"interact")
	_enemy(room).health.take_damage(enemy_tuning.health_maximum)
	await wait_physics_frames(PRESS_FRAMES)
	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 0, "the enemy should be dead and gone")

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(get_tree().get_nodes_in_group("enemies").size(), 1, "one enemy should be back")
	assert_eq(_enemy(room).global_position, start)


func test_a_death_after_a_rest_returns_him_to_the_checkpoint_with_full_bars() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	almos.global_position = checkpoint.global_position
	await _tap(&"interact")
	almos.global_position = DEATH_SPOT
	almos.stamina.spend(tuning.stamina_maximum)

	_kill(almos)
	await _wait_out_the_pause(almos)

	assert_eq(almos.global_position, checkpoint.global_position)
	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)


func test_a_press_made_while_limp_does_nothing_then_or_after_his_return(
		params = use_parameters(press_in_pause_params)) -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	_kill(almos)
	await _wait_into_the_pause(params.late)

	_almos_input.press_action(params.action)
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(params.action)

	assert_false(almos.get(params.state), "no %s while limp" % params.state)
	await _wait_out_the_pause(almos)
	await wait_physics_frames(PRESS_FRAMES)
	assert_false(almos.get(params.state), "no %s should follow his return" % params.state)


func test_an_interact_press_made_while_limp_next_to_the_checkpoint_does_not_rest_him_then_or_after_his_return(
		params = use_parameters(interact_time_params)) -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var checkpoint: Node2D = room.find_child("Checkpoint", true, false)
	almos.global_position = checkpoint.global_position
	await _tap(&"interact")
	_kill(almos)
	watch_signals(almos)
	await _wait_into_the_pause(params.late)

	await _tap(&"interact")
	await _wait_out_the_pause(almos)
	await wait_physics_frames(PRESS_FRAMES)

	assert_eq(almos.global_position, checkpoint.global_position, "he comes back beside it")
	assert_signal_not_emitted(almos, "rested")


func test_an_enemy_swinging_at_the_return_point_when_he_falls_cannot_hurt_him_after_he_returns() -> void:
	var tuning := _tuning()
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var old: Node = _enemy(room)
	var swing: AttackData = old.tuning.attack
	old.global_position = almos.global_position + Vector2.DOWN * ENEMY_STRIKE_DISTANCE
	for i in WAIT_FRAME_LIMIT:
		if old.attacking:
			break
		await get_tree().physics_frame
	assert_true(old.attacking, "the enemy should begin a swing")
	_kill(almos)
	await _wait_out_the_pause(almos)

	await wait_physics_frames(swing.total_frames())

	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


# Almos in the scene, with the shipped tuning.
func _spawn_almos() -> Almos:
	var almos: Almos = _almos_input.spawn_almos()
	return almos


func _tuning() -> PlayerTuning:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	return tuning


# Takes all of his Health off in one blow.
func _kill(almos: Almos) -> void:
	almos.health.take_damage(almos.health.maximum)


# Presses this button for a moment, as a tap, and lets it take effect.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(action)


# How many physics frames it takes to reach this many seconds: the first whole number of
# frames whose length is at least that long.
func _frames_to_reach(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second - FRAME_COUNT_ALLOWANCE)


# An enemy within the range of his Lock-on, with no target of its own so that it does nothing.
func _add_an_enemy_in_lock_on_range(almos: Almos) -> void:
	var scene := load(ENEMY_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the training enemy scene should load")
	var enemy = scene.instantiate()
	enemy.position = almos.global_position + Vector2.RIGHT * ENEMY_LOCK_ON_DISTANCE
	add_child_autofree(enemy)


# The test room as shipped. The test frees it.
func _spawn_room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	var room := scene.instantiate()
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
	var named := enemy_scene.instantiate()
	named.name = "NamedEnemy"
	named.named = true
	named.position = Vector2(900.0, 500.0)
	named.target = room.find_child("Almos", true, false)
	room.add_child(named)
	add_child_autofree(room)
	return room


# The ordinary enemy the room comes with, which is the one called TrainingEnemy.
func _enemy(room: Node):
	return room.find_child("TrainingEnemy", true, false)


func _enemy_tuning() -> EnemyTuning:
	var tuning := load(ENEMY_TUNING_PATH) as EnemyTuning
	assert_not_null(tuning, "the training enemy tuning data file should load")
	assert_gt(tuning.health_maximum, 0.0, "health_maximum in the data file should be positive")
	return tuning


# Every set of Remains in the scene.
func _all_remains() -> Array[Node]:
	return get_tree().get_nodes_in_group("remains")


# Waits to a time in the pause of a Death, as frames after he falls: a little after it begins, or
# a few frames before it is over. Press nothing before this.
func _wait_into_the_pause(late: bool) -> void:
	var frames := PRESS_FRAMES
	if late:
		frames = _frames_to_reach(_tuning().death_pause) - LATE_PRESS_BEFORE_END
	await wait_physics_frames(frames)


# Lets the pause of a Death run out, up to the very start of the frame after he is sent back, before
# anything else in that frame has moved. He must be limp when this is called.
func _wait_out_the_pause(almos: Almos) -> void:
	assert_true(almos.dead, "he should be limp")
	for i in _frames_to_reach(_tuning().death_pause) + PRESS_FRAMES:
		if not almos.dead:
			return
		await get_tree().physics_frame
	assert_false(almos.dead, "he should have been sent back by now")


# He has come back with nothing left of what he was in: on his feet at the point, on the ground,
# with full bars, and every state he can be in off. Only what shows from outside is asked.
func _assert_free_and_clean(almos: Almos) -> void:
	var tuning := _tuning()
	assert_false(almos.dead, "he should not be limp")
	assert_eq(almos.global_position, RETURN_POINT, "he should be at the point")
	assert_eq(almos.velocity, Vector2.ZERO, "he should be still")
	assert_false(almos.rolling, "no Roll")
	assert_false(almos.sprinting, "no Sprint")
	assert_false(almos.attacking, "no swing")
	assert_false(almos.charging, "no charge")
	assert_false(almos.jump_attacking, "no Jump attack")
	assert_false(almos.airborne, "no Jump")
	assert_false(almos.blocking, "no Block")
	assert_false(almos.guard_broken, "no Guard break")
	assert_false(almos.parrying, "no Parry")
	assert_false(almos.locked_on, "no Lock-on")
	assert_eq(almos.height_level, 0, "on the ground level")
	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(almos.stamina.current, tuning.stamina_maximum, TOLERANCE)
	assert_eq(almos.collision_layer, AlmosJump.PLAYER_BODY, "his body is as on the ground")
	assert_eq(almos.collision_mask, AlmosJump.GROUND_MASK, "his body is blocked as on the ground")
	assert_false((almos.find_child("Shadow", true, false) as CanvasItem).visible, "no shadow of a Jump")
	assert_eq((almos.find_child("Placeholder", true, false) as CanvasItem).modulate, Color.WHITE, "no tint")
	assert_eq((almos.find_child("Placeholder", true, false) as Node2D).position, Vector2.ZERO, "no height")
	assert_false((almos.find_child("BlockPlaceholder", true, false) as CanvasItem).visible, "no Block shape")
	assert_false((almos.find_child("ParryPlaceholder", true, false) as CanvasItem).visible, "no Parry shape")
	assert_false((almos.find_child("Sword", true, false) as CanvasItem).visible, "no sword")


# He is set down in front of the ledge, out of its reach by the half of a Jump, at this distance
# along it from the middle, and jumps onto it from there, walking down. He is left standing where
# he came down. The press that began it is let go of.
func _jump_onto_the_ledge(room: Node, almos: Almos, along: float) -> void:
	var tuning := _tuning()
	var ledge := room.find_child("Ledge", true, false) as Footprint
	var jump_length := tuning.walk_speed * tuning.jump_duration
	var top := ledge.global_position.y - ledge.size.y / 2.0
	almos.global_position = Vector2(ledge.global_position.x + along, top - jump_length / 2.0)
	_almos_input.press_action(&"move_down")
	_almos_input.press_action(&"jump")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"jump")
	for i in JUMP_FRAME_LIMIT:
		if not almos.airborne:
			break
		await get_tree().physics_frame
	_almos_input.release_action(&"move_down")
	assert_false(almos.airborne, "the Jump should be over")
	assert_eq(almos.height_level, 1, "he should have come down on the ledge")


# The ledge's footprint in the room, in global coordinates.
func _ledge_rect(room: Node) -> Rect2:
	var ledge := room.find_child("Ledge", true, false) as Footprint
	return Rect2(ledge.global_position - ledge.size / 2.0, ledge.size)
