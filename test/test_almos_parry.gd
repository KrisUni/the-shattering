extends GutTest
## Almos's Parry, seen only through the scene: input goes in as real input events or action
## events, made between two physics frames so that a press lands in a known frame, and a
## Hitbox made here stands in for an attacker, switched on for a single frame at a known
## distance from the press. Every physics frame a sample of Almos is taken. Frames are numbered
## by the samples: sample i is taken at the start of frame i, before anything has moved in it,
## so it shows how frame i - 1 left things. P is the frame of the press, the first frame of
## the window. Expected numbers come from the tuning data file the scene uses (or a copy a
## test changes), never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
const HIT_DAMAGE := AlmosHits.HIT_DAMAGE
const HIT_DISTANCE := AlmosHits.HIT_DISTANCE
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# In pixels.
const POSITION_TOLERANCE := 0.0001
const FACING_TOLERANCE := AlmosInput.FACING_TOLERANCE
# In degrees. How far inside or beyond the edge of the front a hit is put.
const EDGE_MARGIN_DEGREES := 10.0
# A refill pause longer than any wait in these tests.
const LONG_REFILL_PAUSE := 10.0
# Physics frames a button is held for when it is to be a quick tap.
const TAP_FRAMES := 3
# In frames. Past the end of a Parry that a test keeps looking.
const PAST_THE_END_FRAMES := 12
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 4.0
# In pixels. How far from Almos a stand-in enemy to lock on to stands.
const ENEMY_DISTANCE := 100.0
# How many physics frames a swing stays on when it is to overlap him for many of them.
const LONG_SWING_FRAMES := 10
# How different two colours must be (summed over the channels) to be told apart.
const VISIBLE_DIFFERENCE := 0.5
# How long, as a multiple of the hold threshold, a Roll button is held for to make a Sprint.
const HOLD_THRESHOLD_MULTIPLE := 1.5

var parry_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the E key", func(input: AlmosInput): input.press_key(KEY_E)],
		["the left trigger of a pad", func(input: AlmosInput): input.push_joypad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
	],
)

# Which side of his facing a hit comes from (1 is clockwise on the screen, -1 the other way),
# how many degrees inside the edge of the front or beyond it, and whether it is parried.
var arc_edge_params = ParameterFactory.named_parameters(
	["side", "from_the_edge", "parried"],
	[
		[1.0, -EDGE_MARGIN_DEGREES, true],
		[1.0, EDGE_MARGIN_DEGREES, false],
		[-1.0, -EDGE_MARGIN_DEGREES, true],
		[-1.0, EDGE_MARGIN_DEGREES, false],
	],
)

## Something to lock on to: it is in the enemies group.
class StandInEnemy:
	extends Node2D

	func _init() -> void:
		add_to_group(&"enemies")


var _almos_input: AlmosInput
var _hits: AlmosHits
var _almos: Node2D
var _samples: Array[Dictionary] = []
var _parried_count := 0
var _pressed_actions: Array[StringName] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_hits = AlmosHits.new(self)
	_parried_count = 0


func after_each() -> void:
	if get_tree().physics_frame.is_connected(_take_sample):
		get_tree().physics_frame.disconnect(_take_sample)
	for action in _pressed_actions:
		Input.action_release(action)
	_pressed_actions.clear()
	_almos_input.release_everything()


# --- The tuning and the button ---

func test_the_parry_numbers_are_tuned_to_a_window_and_a_recovery_in_whole_frames_and_a_front() -> void:
	var tuning := _tuning()

	assert_gt(tuning.parry_window_frames, 0, "parry_window_frames in the data file should be positive")
	assert_gt(tuning.parry_recovery_frames, 0, "parry_recovery_frames in the data file should be positive")
	assert_gt(tuning.parry_arc_degrees, 0.0, "parry_arc_degrees in the data file should be positive")
	assert_lte(tuning.parry_arc_degrees, 360.0, "parry_arc_degrees in the data file should be at most a full turn")


func test_the_parry_button_can_be_the_e_key_or_the_left_trigger_of_a_pad(params = use_parameters(parry_binding_params)) -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(_almos.parrying, "he should not be parrying before the button is pressed")

	params.press.call(_almos_input)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.parrying, "%s should start a Parry" % params.name)


# --- The window ---

func test_a_hit_from_the_front_on_the_first_frame_of_the_window_is_parried() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hitbox_in_front()
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p)

	assert_almost_eq(_almos.health.current, tuning.health_maximum, HEALTH_TOLERANCE, "no Health should be lost")
	assert_eq(_parried_count, 1, "the Hitbox should hear of it once")


func test_a_hit_from_the_front_on_the_last_frame_of_the_window_is_parried() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hitbox_in_front()
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p + tuning.parry_window_frames - 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum, HEALTH_TOLERANCE, "no Health should be lost")
	assert_eq(_parried_count, 1, "the Hitbox should hear of it once")


func test_a_hit_from_the_front_on_the_first_frame_after_the_window_lands_in_full() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hitbox_in_front()
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p + tuning.parry_window_frames)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_eq(_parried_count, 0, "nothing should be parried")


func test_a_hit_from_the_front_before_the_press_lands_in_full() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hitbox_in_front()
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)
	await _press(&"parry")

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_eq(_parried_count, 0)


func test_a_hit_during_the_recovery_lands_in_full_even_while_block_is_held() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hitbox_in_front()
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p + tuning.parry_window_frames + 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through, not reduced by Block")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum, STAMINA_TOLERANCE, "no blocked hit should have cost Stamina")
	assert_eq(_parried_count, 0)


func test_a_hit_from_behind_during_the_window_lands_in_full() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hits.hitbox_from(_almos, -_almos.facing * HIT_DISTANCE)
	hitbox.parried.connect(func(_hurtbox: Hurtbox) -> void: _parried_count += 1)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p + 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_eq(_parried_count, 0)


func test_the_front_a_parry_covers_is_the_tuned_arc_centred_on_his_facing(params = use_parameters(arc_edge_params)) -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var angle := deg_to_rad(tuning.parry_arc_degrees / 2.0 + params.from_the_edge)
	var offset: Vector2 = _almos.facing.rotated(params.side * angle) * HIT_DISTANCE
	var hitbox := _hits.hitbox_from(_almos, offset)
	hitbox.parried.connect(func(_hurtbox: Hurtbox) -> void: _parried_count += 1)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p)

	assert_eq(_parried_count, 1 if params.parried else 0, "whether the hit was parried")
	var expected := tuning.health_maximum if params.parried else tuning.health_maximum - HIT_DAMAGE
	assert_almost_eq(_almos.health.current, expected, HEALTH_TOLERANCE)


func test_a_parry_costs_no_stamina() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _until_sample(p + tuning.parry_window_frames + tuning.parry_recovery_frames)

	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum, STAMINA_TOLERANCE)


func test_a_parry_works_at_zero_stamina() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum)
	var hitbox := _hitbox_in_front()
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(hitbox, p + 1)

	assert_true(_samples[p + 1].parrying, "he should have begun a Parry")
	assert_almost_eq(_almos.health.current, tuning.health_maximum, HEALTH_TOLERANCE, "no Health should be lost")
	assert_eq(_parried_count, 1)
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_a_hit_in_the_window_while_blocking_is_parried_not_blocked() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hitbox_in_front()
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.blocking, "he should be blocking to begin with")

	var p := await _press(&"parry")
	await _hit_at(hitbox, p + 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum, HEALTH_TOLERANCE, "no Health should be lost")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum, STAMINA_TOLERANCE, "a parried hit costs no Stamina, as a blocked one would")
	assert_eq(_parried_count, 1)


# --- A caught Parry ---

func test_a_caught_parry_frees_him_from_the_next_frame_and_its_swing_cannot_hit_him_again() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	var hitbox := _hitbox_in_front()

	var p := await _press(&"parry")
	var catch_frame := p + 2
	await _until_sample(catch_frame)
	await _hits.swing(hitbox, LONG_SWING_FRAMES)

	assert_true(_samples[catch_frame].parrying, "he should be in the Parry up to the catch")
	assert_false(_samples[catch_frame + 1].parrying, "he should be free from the frame after the catch")
	assert_false(_samples[catch_frame + 1].parry_shape, "the window should not show any more")
	assert_eq(_samples[catch_frame + 1].position, _samples[p].position, "he stood still up to the catch")
	assert_gt(_samples[catch_frame + 2].position.x, _samples[catch_frame + 1].position.x, "he should walk again in the frame after the catch")
	assert_almost_eq(_almos.health.current, tuning.health_maximum, HEALTH_TOLERANCE, "the same swing cannot hit him again")
	assert_eq(_parried_count, 1, "the Hitbox hears of it once")


func test_after_a_caught_parry_he_can_parry_again_at_once() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var first := _hitbox_in_front()
	var second := _hitbox_in_front()
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _hit_at(first, p + 1)
	await _release(&"parry")
	var again := await _press(&"parry")
	await _hit_at(second, again + 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum, HEALTH_TOLERANCE)
	assert_eq(_parried_count, 2)


# --- The recovery ---

func test_a_window_that_caught_nothing_leaves_him_standing_still_until_the_frame_after_the_recovery() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _until_sample(p + total + 2)

	assert_gt(_samples[p].position.x, _samples[p - 1].position.x, "he was walking before the press")
	for i in range(p + 1, p + total + 1):
		assert_eq(_samples[i].position, _samples[p].position, "where he is in sample %d, in the Parry" % i)
	assert_gt(_samples[p + total + 1].position.x, _samples[p + total].position.x, "he should walk in the frame after the last recovery frame")
	assert_true(_samples[p + 1].parrying, "sample after the press should show a Parry")
	assert_false(_samples[p + total].parrying, "he is free once the last recovery frame is over")


func test_he_cannot_roll_during_the_recovery_and_the_press_is_not_kept() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _tap_at(&"roll", p + tuning.parry_window_frames + 2)
	await _until_sample(p + tuning.parry_window_frames + tuning.parry_recovery_frames + PAST_THE_END_FRAMES)

	assert_false(_any_sample("rolling"), "he should never Roll")


func test_he_cannot_attack_during_the_recovery_and_the_press_is_not_kept(params = use_parameters([[&"attack_light"], [&"attack_heavy"]])) -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _tap_at(params[0], p + tuning.parry_window_frames + 2)
	await _until_sample(p + tuning.parry_window_frames + tuning.parry_recovery_frames + PAST_THE_END_FRAMES)

	assert_false(_any_sample("attacking"), "he should never swing")
	assert_false(_any_sample("charging"), "he should never charge")


func test_he_cannot_block_during_the_recovery_and_blocks_again_after_it_if_block_is_still_held() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.blocking, "he should be blocking to begin with")

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _until_sample(p + total + 2)

	for i in range(p + 1, p + total + 1):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d" % i)
	assert_true(_samples[p + total + 1].blocking, "Block should come back in the frame after the last recovery frame")


func test_he_is_free_to_roll_in_the_frame_after_the_recovery() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _tap_released_at(&"roll", p + total)
	await _until_sample(p + total + 2)

	assert_true(_samples[p + total + 1].rolling, "a Roll pressed in the frame after the last recovery frame should begin")


func test_he_is_not_free_to_roll_in_the_last_recovery_frame() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _tap_released_at(&"roll", p + total - 1)
	await _until_sample(p + total + PAST_THE_END_FRAMES)

	assert_false(_any_sample("rolling"), "a Roll pressed in the last recovery frame should be lost")


func test_a_press_during_the_recovery_is_lost_and_does_not_extend_it() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _tap_at(&"parry", p + tuning.parry_window_frames + 4)
	await _until_sample(p + total + PAST_THE_END_FRAMES)

	assert_gt(_samples[p + total + 1].position.x, _samples[p + total].position.x, "he should walk in the frame after the first Parry's recovery")
	var windows := 0
	for i in range(p + tuning.parry_window_frames + 1, _samples.size()):
		if _samples[i].window_open:
			windows += 1
	assert_eq(windows, 0, "no second window should open")


func test_a_press_in_the_window_is_lost_too() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _tap_at(&"parry", p + 2)
	await _until_sample(p + total + 2)

	assert_gt(_samples[p + total + 1].position.x, _samples[p + total].position.x, "he should walk in the frame after the first Parry's recovery")


# --- Where a Parry cannot start ---

func test_a_press_during_a_roll_is_lost() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var roll_start := _samples.size() + 1
	await _tap_at(&"roll", roll_start)
	await _tap_at(&"parry", roll_start + 3)
	await _until_sample(roll_start + int(ceil(tuning.roll_duration * Engine.physics_ticks_per_second)) + PAST_THE_END_FRAMES)

	assert_true(_any_sample("rolling"), "he should have rolled")
	assert_false(_any_sample("parrying"), "he should never Parry, not even after the Roll")


func test_a_press_during_a_swing_is_lost() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	var swing_start := await _press(&"attack_light")
	await _tap_at(&"parry", swing_start + 2)
	await _until_sample(swing_start + PAST_THE_END_FRAMES * 4)

	assert_true(_any_sample("attacking"), "he should have swung")
	assert_false(_any_sample("parrying"), "he should never Parry, not even after the swing")


func test_a_press_while_charging_a_heavy_attack_is_lost() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	var hold_start := await _press(&"attack_heavy")
	await _tap_at(&"parry", hold_start + 4)
	await _release(&"attack_heavy")
	await _until_sample(hold_start + PAST_THE_END_FRAMES * 4)

	assert_true(_any_sample("charging"), "he should have charged")
	assert_false(_any_sample("parrying"), "he should never Parry")


func test_a_press_during_a_guard_break_is_lost() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum - tuning.block_stamina_cost / 3.0)
	var hitbox := _hitbox_in_front()
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	await _hits.swing(hitbox, 1)
	assert_true(_almos.guard_broken, "the hit should have started a Guard break")

	var start := _samples.size()
	await _tap_at(&"parry", start + 3)
	await _until_sample(start + int(ceil(tuning.guard_break_duration * Engine.physics_ticks_per_second)) + PAST_THE_END_FRAMES)

	assert_false(_any_sample("parrying"), "he should never Parry, not even after the Guard break")


func test_an_attack_and_a_parry_pressed_in_the_same_frame_swing_and_the_parry_is_lost() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	await physics_frame_then_press([&"attack_light", &"parry"])
	await wait_physics_frames(PAST_THE_END_FRAMES * 4)

	assert_true(_any_sample("attacking"), "the attack should win")
	assert_false(_any_sample("parrying"), "the Parry press should be lost")


func test_a_roll_tap_that_ends_in_the_frame_of_a_parry_press_rolls_and_the_parry_is_lost() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	# A Roll is known when its button is let go, so that is the Roll's press for this.
	var frame := _samples.size() + TAP_FRAMES + 1
	_send(&"roll", true)
	await _until_sample(frame - 1)
	_send(&"parry", true)
	await _until_sample(frame)
	_send(&"roll", false)
	await wait_physics_frames(PAST_THE_END_FRAMES * 4)

	assert_true(_any_sample("rolling"), "the Roll should win")
	assert_false(_any_sample("parrying"), "the Parry press should be lost")


# --- Where a Parry can start ---

func test_a_parry_from_a_sprint_stops_the_sprint_and_leaves_him_standing_still() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(ceili(tuning.roll_hold_threshold * HOLD_THRESHOLD_MULTIPLE * Engine.physics_ticks_per_second) + SETTLE_FRAMES)
	assert_true(_almos.sprinting, "he should be sprinting to begin with")

	var p := await _press(&"parry")
	await _until_sample(p + 2)

	assert_true(_samples[p + 1].parrying, "the Parry should begin")
	assert_false(_samples[p + 1].sprinting, "the Sprint should have stopped")
	assert_eq(_samples[p + 2].position, _samples[p + 1].position, "he should stand still")


func test_a_parry_from_a_block_ends_the_block_and_it_comes_back_afterwards() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	await _until_sample(p + 2)
	assert_false(_almos.blocking, "he is not blocking during the Parry")
	assert_true(_almos.parrying)
	await _until_sample(p + tuning.parry_window_frames + tuning.parry_recovery_frames + 2)

	assert_true(_almos.blocking, "Block comes back afterwards, the button still held")


# --- Lock-on ---

func test_under_lock_on_he_keeps_facing_the_target_through_a_parry_but_stays_where_he_is() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	var enemy := StandInEnemy.new()
	enemy.position = _almos.position + Vector2.RIGHT * ENEMY_DISTANCE
	add_child_autofree(enemy)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_at(&"lock_on", _samples.size() + 1)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "a press should lock on")
	_almos_input.press_action(&"move_down")

	var p := await _press(&"parry")
	enemy.global_position = _almos.global_position + Vector2.UP * ENEMY_DISTANCE
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.parrying, "this should be in the Parry")
	assert_almost_eq(_almos.facing, Vector2.UP, Vector2.ONE * FACING_TOLERANCE, "he should turn with the target")
	assert_eq(_almos.position, _samples[p].position, "pushing a direction should not move him")


# --- What is drawn ---

func test_the_parry_shape_shows_only_while_the_window_is_open_and_the_recovery_is_tinted() -> void:
	var tuning := _tuning()
	_spawn_almos(tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	var p := await _press(&"parry")
	var total := tuning.parry_window_frames + tuning.parry_recovery_frames
	await _until_sample(p + total + 3)

	var at_rest: Color = _samples[0].look
	for i in range(0, p + total + 3):
		var in_window: bool = i > p and i <= p + tuning.parry_window_frames
		var recovering: bool = i > p + tuning.parry_window_frames and i < p + total
		assert_eq(_samples[i].parry_shape, in_window, "whether the Parry shape shows in sample %d" % i)
		assert_eq(_samples[i].window_open, in_window, "whether the window is open in sample %d" % i)
		if recovering:
			assert_gte(_difference(_samples[i].look, at_rest), VISIBLE_DIFFERENCE, "what is drawn should be tinted in sample %d" % i)
		else:
			assert_eq(_samples[i].look, at_rest, "what is drawn should be untinted in sample %d" % i)


func test_the_parry_recovery_tint_differs_from_the_guard_break_tint() -> void:
	assert_gte(_difference(AlmosParry.RECOVERY_TINT, AlmosBlock.GUARD_BREAK_TINT), VISIBLE_DIFFERENCE, "the two tints should look clearly different")


# --- Helpers ---

func _spawn_almos(tuning: PlayerTuning = null) -> Node2D:
	_almos = _almos_input.spawn_almos(tuning)
	_samples.clear()
	get_tree().physics_frame.connect(_take_sample)
	return _almos


# Taken at the start of each physics frame, before anything has moved in it.
func _take_sample() -> void:
	if not is_instance_valid(_almos):
		return
	_samples.append({
		"position": _almos.position,
		"parrying": _almos.parrying,
		"window_open": _almos.parry_window_open,
		"parry_shape": _almos.get_node("Look/Facing/ParryShape").visible,
		"blocking": _almos.blocking,
		"rolling": _almos.rolling,
		"attacking": _almos.attacking,
		"charging": _almos.charging,
		"sprinting": _almos.sprinting,
		"look": (_almos.get_node("Look") as Node2D).modulate,
	})


func _tuning() -> PlayerTuning:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	return tuning


func _tuning_with_long_refill_pause() -> PlayerTuning:
	var tuning := _tuning().duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as PlayerTuning
	tuning.stamina_refill_pause = LONG_REFILL_PAUSE
	return tuning


# A Hitbox, switched off, with its origin in front of him, whose parried signal is counted.
func _hitbox_in_front() -> Hitbox:
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	hitbox.parried.connect(func(_hurtbox: Hurtbox) -> void: _parried_count += 1)
	return hitbox


# Switches the hitbox on for one frame, frame number frame.
func _hit_at(hitbox: Hitbox, frame: int) -> void:
	await _until_sample(frame)
	await _hits.swing(hitbox, 1)


# Waits until the sample with this index has been taken, which is the start of that physics
# frame, so that whatever is done next is first seen in that frame.
func _until_sample(index: int) -> void:
	while _samples.size() <= index:
		await get_tree().physics_frame


# Presses the action as an event between two frames. The game reads a press made at the start
# of a physics frame from the frame after it, so this returns that frame's number.
func _press(action: StringName) -> int:
	await get_tree().physics_frame
	_send(action, true)
	return _samples.size()


func physics_frame_then_press(actions: Array) -> void:
	await get_tree().physics_frame
	for action in actions:
		_send(action, true)
	await _until_sample(_samples.size() - 1 + TAP_FRAMES)
	for action in actions:
		_send(action, false)


func _release(action: StringName) -> void:
	await get_tree().physics_frame
	_send(action, false)


# Taps the action so that the game reads the press in this frame number, and lets go TAP_FRAMES
# later.
func _tap_at(action: StringName, frame: int) -> void:
	await _until_sample(frame - 1)
	_send(action, true)
	await _until_sample(frame - 1 + TAP_FRAMES)
	_send(action, false)


# Taps the action so that the game sees the button up in this frame number, which is when a
# Roll tap is known. A release sent at the start of a frame is seen in that frame itself, unlike
# a press, which is seen in the next.
func _tap_released_at(action: StringName, frame: int) -> void:
	await _tap_at(action, frame - TAP_FRAMES + 1)


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		_pressed_actions.append(action)


# Whether any sample so far shows this state.
func _any_sample(state: String) -> bool:
	return _samples.any(func(sample: Dictionary) -> bool: return sample[state])


func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
