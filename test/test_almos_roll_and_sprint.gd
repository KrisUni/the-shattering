extends GutTest
## Almos rolling and sprinting, seen only through the scene: input goes in as actions or
## real input events, and we watch what he does. Every physics frame a sample of his
## position, state and Stamina is taken, so what happened can be read back frame by
## frame. Expected numbers come from the tuning data file the scene uses and plain
## arithmetic.

const ALMOS_SCENE_PATH := "res://scenes/almos/almos.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"

# Frames to let a pressed input reach Almos before we start measuring.
const SETTLE_FRAMES := 2
# A tap: held this many physics frames, far shorter than any sensible hold threshold.
const TAP_FRAMES := 3
# In pixels.
const POSITION_TOLERANCE := 0.01
# In pixels per second.
const VELOCITY_TOLERANCE := 0.01
# How many physics frames a speed is measured over.
const MEASURED_FRAMES := 5
# Long enough for a drain of Stamina to show well above rounding error.
const SPRINT_MEASURED_FRAMES := 10
# Frames to hold the Roll button for, comfortably past a hold threshold of 12 frames.
const HOLD_PAST_THRESHOLD_FRAMES := 20
# How many frames of sprint a test leaves him the Stamina for.
const SPRINT_FRAMES_LEFT := 6
# A refill pause short enough that the tests do not spend long waiting it out.
const SHORT_REFILL_PAUSE := 0.3
# How long, in seconds, past the end of the refill pause a test carries on.
const SECONDS_PAST_PAUSE := 0.3
# How far, in seconds, either side of the end of the refill pause a test looks.
const REFILL_MARGIN := 0.05
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# Facing is a unit vector, so it needs a much tighter tolerance than pixels.
const FACING_TOLERANCE := 0.0001
# In seconds. Added to one physics frame wherever a time can only be told to the nearest frame.
const TIME_TOLERANCE := 0.0001
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0

# Roll durations and how many physics frames each takes at 60 frames per second. 0.2 s is
# a whole 12 frames, but twelve frame lengths added up fall a hair short of it, which
# once gave the Roll a spare frame. 0.27 s is not a whole number of frames.
var duration_params = ParameterFactory.named_parameters(
	["duration", "frames"],
	[[0.2, 12], [0.27, 17]],
)

# How many physics frames the Roll button is held, standing still, and whether that rolls.
# At 60 frames per second the hold threshold of 0.2 s is 12 frames.
var press_params = ParameterFactory.named_parameters(
	["frames", "rolls"],
	[[8, true], [16, false], [30, false]],
)

var _almos: Node2D
var _samples: Array[Dictionary] = []
var _held_actions: Array[StringName] = []
var _held_events: Array[InputEvent] = []


func after_each() -> void:
	_stop_sampling()
	_release_everything()


func test_tapping_roll_while_pushing_a_direction_rolls_the_tuned_distance_that_way() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), Vector2(_tuning().roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)


func test_tapping_roll_with_nothing_pushed_rolls_the_way_he_faces() -> void:
	_spawn_almos()
	_press_action(&"move_up")
	_press_action(&"move_left")
	await wait_physics_frames(SETTLE_FRAMES)
	_release_action(&"move_up")
	_release_action(&"move_left")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var expected := Vector2(-1.0, -1.0).normalized() * _tuning().roll_distance
	assert_almost_eq(_roll_displacement(), expected, Vector2.ONE * POSITION_TOLERANCE)


func test_a_roll_costs_the_tuned_stamina_once_at_its_start() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _almos.stamina.current

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	var expected := before - _tuning().roll_stamina_cost
	assert_almost_eq(_samples[span.x].stamina, expected, STAMINA_TOLERANCE, "it should be spent as the roll begins")
	assert_almost_eq(_samples[span.y - 1].stamina, expected, STAMINA_TOLERANCE, "nothing more should be spent during the roll")


func test_tapping_roll_at_zero_stamina_does_nothing() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	_almos.stamina.spend(_almos.stamina.maximum)
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(_roll_span().x, -1, "he should not have rolled")
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_a_roll_with_less_stamina_than_it_costs_still_goes_ahead_and_empties_it() -> void:
	_spawn_almos()
	_almos.stamina.spend(_almos.stamina.maximum - _tuning().roll_stamina_cost / 3.0)
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), Vector2.DOWN * _tuning().roll_distance, Vector2.ONE * POSITION_TOLERANCE)
	assert_almost_eq(_samples[_roll_span().y - 1].stamina, 0.0, STAMINA_TOLERANCE)


func test_he_becomes_untouchable_the_tuned_time_into_a_roll() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var untouchable := _untouchable_samples()
	assert_false(untouchable.is_empty(), "he should be untouchable at some point in the roll")
	if untouchable.is_empty():
		return
	assert_almost_eq(_seconds_into_roll(untouchable[0]), _tuning().roll_untouchable_start, _frame_seconds() + TIME_TOLERANCE)


func test_he_stays_untouchable_for_the_tuned_duration() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var untouchable := _untouchable_samples()
	assert_false(untouchable.is_empty(), "he should be untouchable at some point in the roll")
	if untouchable.is_empty():
		return
	assert_eq(untouchable.back() - untouchable[0] + 1, untouchable.size(), "he should be untouchable in one unbroken stretch")
	assert_almost_eq(untouchable.size() * _frame_seconds(), _tuning().roll_untouchable_duration, _frame_seconds() + TIME_TOLERANCE)


func test_he_can_be_hurt_again_before_the_roll_ends() -> void:
	var tuning := _tuning()
	assert_lt(tuning.roll_untouchable_start + tuning.roll_untouchable_duration, tuning.roll_duration, "the untouchable window should end before the roll does")
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var last_rolling_sample := _roll_span().y - 1
	assert_false(_samples[last_rolling_sample].untouchable, "he should be vulnerable again by the end of the roll")


func test_he_is_not_untouchable_when_he_is_not_rolling() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for_the_roll_to_finish()
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _roll_span()
	for i in _samples.size():
		if i < span.x or i >= span.y:
			assert_false(_samples[i].untouchable, "he should not be untouchable in sample %d, outside the roll" % i)


func test_pushing_another_way_during_a_roll_changes_neither_its_direction_nor_its_distance() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for_the_roll_to_start()

	_release_action(&"move_right")
	_press_action(&"move_left")
	_press_action(&"move_up")
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), Vector2(_tuning().roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)


func test_he_faces_the_way_he_rolls_whatever_is_pushed_during_the_roll() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for_the_roll_to_start()

	_release_action(&"move_right")
	_press_action(&"move_up")
	_press_action(&"move_left")
	await _wait_for_the_roll_to_finish()

	var last_rolling_sample := _roll_span().y - 1
	assert_almost_eq(_samples[last_rolling_sample].facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE)


func test_a_tap_early_in_a_roll_is_ignored() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _almos.stamina.current
	await _tap_roll()
	await _wait_for_the_roll_to_start()

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	assert_almost_eq((span.y - span.x) * _frame_seconds(), tuning.roll_duration, _frame_seconds() + TIME_TOLERANCE, "the roll should run its course, neither cut short nor restarted")
	assert_almost_eq(_roll_displacement(), Vector2(tuning.roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)
	assert_almost_eq(_samples[span.y - 1].stamina, before - tuning.roll_stamina_cost, STAMINA_TOLERANCE, "only the first roll should have been paid for")


func test_holding_the_button_through_a_roll_neither_cuts_it_short_nor_makes_him_sprint_in_it() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for_the_roll_to_start()

	_press_action(&"roll")
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	assert_almost_eq((span.y - span.x) * _frame_seconds(), tuning.roll_duration, _frame_seconds() + TIME_TOLERANCE, "the roll should run its course")
	assert_almost_eq(_roll_displacement(), Vector2(tuning.roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)
	for i in range(span.x, span.y):
		assert_false(_samples[i].sprinting, "he should not be sprinting in sample %d, in the middle of the roll" % i)


func test_a_tap_in_the_last_moments_of_a_roll_queues_another_that_starts_as_it_ends() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _almos.stamina.current
	await _tap_roll()
	await _wait_until_into_the_roll(_buffer_window_start() + _frame_seconds())

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	assert_almost_eq((span.y - span.x) * _frame_seconds(), 2.0 * tuning.roll_duration, _frame_seconds() + TIME_TOLERANCE, "the second roll should follow the first without a gap")
	assert_almost_eq(_roll_displacement(), Vector2(2.0 * tuning.roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)
	assert_almost_eq(_samples[span.y - 1].stamina, before - 2.0 * tuning.roll_stamina_cost, STAMINA_TOLERANCE, "both rolls should have been paid for")


func test_taps_in_the_last_moments_of_a_roll_queue_only_one_more_roll() -> void:
	var tuning := _tuning_with({"roll_buffer_window": 0.25})
	_spawn_almos(tuning)
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_until_into_the_roll(tuning.roll_duration - tuning.roll_buffer_window + _frame_seconds())

	await _tap_roll()
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	assert_almost_eq((span.y - span.x) * _frame_seconds(), 2.0 * tuning.roll_duration, _frame_seconds() + TIME_TOLERANCE, "there should be the first roll and one queued roll, no more")


func test_a_queued_roll_needs_stamina_of_its_own() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_press_action(&"move_right")
	_almos.stamina.spend(_almos.stamina.maximum - tuning.roll_stamina_cost)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_until_into_the_roll(_buffer_window_start() + _frame_seconds())

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	assert_almost_eq((span.y - span.x) * _frame_seconds(), tuning.roll_duration, _frame_seconds() + TIME_TOLERANCE, "the queued roll should not start with no stamina left")
	assert_almost_eq(_roll_displacement(), Vector2(tuning.roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)


func test_a_queued_roll_goes_the_way_he_is_pushing_when_it_starts() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for_the_roll_to_start()
	_release_action(&"move_right")
	_press_action(&"move_up")
	await _wait_until_into_the_roll(_buffer_window_start() + _frame_seconds())

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), Vector2(tuning.roll_distance, -tuning.roll_distance), Vector2.ONE * POSITION_TOLERANCE)


func test_a_roll_covers_the_tuned_distance_in_whole_frames_whatever_its_duration(params = use_parameters(duration_params)) -> void:
	var tuning := _tuning_with({"roll_duration": params.duration})
	_spawn_almos(tuning)
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_roll()
	await _wait_for_the_roll_to_finish()

	var span := _roll_span()
	assert_eq(span.y - span.x, params.frames, "it should last until the first whole frame at or after its duration")
	assert_almost_eq(_roll_displacement(), Vector2(tuning.roll_distance, 0.0), Vector2.ONE * POSITION_TOLERANCE)


func test_holding_roll_while_pushing_a_direction_sprints_at_sprint_speed() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	_press_action(&"roll")
	await _wait_for_sprinting()

	var first := _first_sample_where("sprinting")
	if first == -1:
		return
	await _wait_for_samples(MEASURED_FRAMES)

	assert_almost_eq(_average_velocity(first, MEASURED_FRAMES), Vector2(_tuning().sprint_speed, 0.0), Vector2.ONE * VELOCITY_TOLERANCE)


func test_sprint_starts_once_the_button_has_been_held_for_the_threshold() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	var pressed_at := _samples.size()
	_press_action(&"roll")
	await _wait_for_sprinting()

	var started_after := (_first_sample_where("sprinting") - pressed_at) * _frame_seconds()
	assert_almost_eq(started_after, tuning.roll_hold_threshold, 2.0 * _frame_seconds() + TIME_TOLERANCE)


func test_holding_roll_only_sprints_while_he_is_pushing_a_direction() -> void:
	var hold_frames := ceili(_tuning().roll_hold_threshold * Engine.physics_ticks_per_second) + 2 * SETTLE_FRAMES
	_spawn_almos()
	_press_action(&"roll")
	await wait_physics_frames(hold_frames)
	assert_eq(_first_sample_where("sprinting"), -1, "he should not sprint standing still")

	_press_action(&"move_right")
	await _wait_for_sprinting()
	await wait_physics_frames(SETTLE_FRAMES)
	_release_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	assert_false(_samples.back().sprinting, "he should stop sprinting when he stops moving")


func test_sprinting_spends_the_tuned_stamina_per_second() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	_press_action(&"roll")
	await _wait_for_sprinting()
	var first := _first_sample_where("sprinting")
	if first == -1:
		return

	await _wait_for_samples(SPRINT_MEASURED_FRAMES)

	var spent: float = _samples[first].stamina - _samples[first + SPRINT_MEASURED_FRAMES].stamina
	var expected := _tuning().sprint_stamina_per_second * SPRINT_MEASURED_FRAMES * _frame_seconds()
	assert_almost_eq(spent, expected, STAMINA_TOLERANCE)


func test_letting_go_after_a_sprint_does_not_roll() -> void:
	_spawn_almos()
	_press_action(&"move_right")
	_press_action(&"roll")
	await _wait_for_sprinting()
	await wait_physics_frames(SETTLE_FRAMES)

	_release_action(&"roll")
	await wait_physics_frames(SETTLE_FRAMES + 2)

	assert_eq(_first_sample_where("rolling"), -1, "he should not roll when the button that made him sprint is let go")


func test_a_press_shorter_than_the_hold_threshold_is_a_tap_and_a_longer_one_is_not(params = use_parameters(press_params)) -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	_press_action(&"roll")
	await wait_physics_frames(params.frames)
	_release_action(&"roll")
	await wait_physics_frames(SETTLE_FRAMES + 2)

	assert_eq(_first_sample_where("rolling") != -1, params.rolls, "rolled or not")


func test_stamina_does_not_refill_however_long_he_sprints() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": SHORT_REFILL_PAUSE})
	_spawn_almos(tuning)
	_press_action(&"move_right")
	_press_action(&"roll")
	await _wait_for_sprinting()
	var first := _first_sample_where("sprinting")
	if first == -1:
		return

	await _wait_for_samples(ceili((tuning.stamina_refill_pause + SECONDS_PAST_PAUSE) * Engine.physics_ticks_per_second))

	var per_frame := tuning.sprint_stamina_per_second * _frame_seconds()
	for i in range(first, _samples.size() - 1):
		assert_true(_samples[i].sprinting, "he should still be sprinting in sample %d" % i)
		assert_almost_eq(_samples[i].stamina - _samples[i + 1].stamina, per_frame, STAMINA_TOLERANCE, "sample %d: stamina should only ever fall by the sprint's cost" % i)


func test_stamina_refills_once_he_stops_sprinting_and_the_pause_has_passed() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": SHORT_REFILL_PAUSE})
	_spawn_almos(tuning)
	# Far enough down that the refill does not reach the top within the test.
	_almos.stamina.spend(tuning.stamina_maximum / 2.0)
	_press_action(&"move_right")
	_press_action(&"roll")
	await _wait_for_sprinting()
	await _wait_for_samples(SPRINT_MEASURED_FRAMES)
	_release_action(&"roll")
	var stopped: bool = await wait_until(func(): return _samples.back().sprinting == false, WAIT_LIMIT)
	assert_true(stopped, "he should have stopped sprinting")
	var stopped_at := _samples.size() - 1
	var level_when_stopped: float = _samples[stopped_at].stamina

	await _wait_for_samples(ceili((tuning.stamina_refill_pause - REFILL_MARGIN) * Engine.physics_ticks_per_second))
	assert_almost_eq(_samples.back().stamina, level_when_stopped, STAMINA_TOLERANCE, "nothing should come back during the pause")

	await _wait_for_samples(ceili((REFILL_MARGIN + SECONDS_PAST_PAUSE) * Engine.physics_ticks_per_second))
	var seconds_refilling := (_samples.size() - 1 - stopped_at) * _frame_seconds() - tuning.stamina_refill_pause
	assert_almost_eq(_samples.back().stamina - level_when_stopped, tuning.stamina_refill_rate * seconds_refilling, 2.0 * tuning.stamina_refill_rate * _frame_seconds(), "it should refill at the tuned rate once the pause is over")


func test_he_cannot_start_a_sprint_at_zero_stamina() -> void:
	_spawn_almos()
	_almos.stamina.spend(_almos.stamina.maximum)
	_press_action(&"move_right")
	_press_action(&"roll")
	await wait_physics_frames(HOLD_PAST_THRESHOLD_FRAMES)
	await _wait_for_samples(MEASURED_FRAMES)

	assert_eq(_first_sample_where("sprinting"), -1, "he should not sprint with nothing to spend")
	var last := _samples.size() - 1
	assert_almost_eq(_average_velocity(last - MEASURED_FRAMES, MEASURED_FRAMES), Vector2(_tuning().walk_speed, 0.0), Vector2.ONE * VELOCITY_TOLERANCE, "he should walk instead")


func test_he_drops_to_walking_when_stamina_runs_out_mid_sprint_though_the_button_is_still_held() -> void:
	var tuning := _tuning()
	_spawn_almos()
	# Just enough for a few frames of sprint.
	_almos.stamina.spend(_almos.stamina.maximum - tuning.sprint_stamina_per_second * SPRINT_FRAMES_LEFT * _frame_seconds())
	_press_action(&"move_right")
	_press_action(&"roll")
	await _wait_for_sprinting()
	var ran_out: bool = await wait_until(func(): return _samples.back().stamina <= 0.0, WAIT_LIMIT, "stamina should run out")
	assert_true(ran_out, "his stamina should have run out")
	await _wait_for_samples(SETTLE_FRAMES + MEASURED_FRAMES)

	var last := _samples.size() - 1
	for i in range(last - MEASURED_FRAMES, last + 1):
		assert_false(_samples[i].sprinting, "he should not be sprinting in sample %d" % i)
	assert_almost_eq(_average_velocity(last - MEASURED_FRAMES, MEASURED_FRAMES), Vector2(tuning.walk_speed, 0.0), Vector2.ONE * VELOCITY_TOLERANCE, "he should be walking")


func test_tapping_the_space_key_rolls() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	_press_key(KEY_SPACE)
	await wait_physics_frames(TAP_FRAMES)
	_release_everything()
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), Vector2.DOWN * _tuning().roll_distance, Vector2.ONE * POSITION_TOLERANCE)


func test_tapping_the_bottom_right_face_button_of_a_pad_rolls() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	_press_joypad_button(JOY_BUTTON_B)
	await wait_physics_frames(TAP_FRAMES)
	_release_everything()
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), Vector2.DOWN * _tuning().roll_distance, Vector2.ONE * POSITION_TOLERANCE)


func _spawn_almos(tuning: PlayerTuning = null) -> Node2D:
	var scene := load(ALMOS_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the Almos scene should load")
	_almos = scene.instantiate()
	if tuning != null:
		# In almos.tscn Almos and his Stamina share one tuning data file; so do they here.
		_almos.tuning = tuning
		_almos.get_node("Stamina").tuning = tuning
	add_child_autofree(_almos)
	_samples.clear()
	get_tree().physics_frame.connect(_take_sample)
	return _almos


# Taken at the start of each physics frame, before anything has moved in it, so it shows
# how that frame's predecessor left things.
func _take_sample() -> void:
	if not is_instance_valid(_almos):
		return
	_samples.append({
		"position": _almos.position,
		"rolling": _almos.rolling,
		"stamina": _almos.stamina.current,
		"facing": _almos.facing,
		"untouchable": _almos.untouchable,
		"sprinting": _almos.sprinting,
	})


func _stop_sampling() -> void:
	if get_tree().physics_frame.is_connected(_take_sample):
		get_tree().physics_frame.disconnect(_take_sample)


func _tuning() -> PlayerTuning:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	return tuning


# The tuning data file's numbers, with these properties changed, for a test that needs a
# case the shipped numbers do not give.
func _tuning_with(changes: Dictionary) -> PlayerTuning:
	var tuning := _tuning().duplicate() as PlayerTuning
	for property in changes:
		tuning.set(property, changes[property])
	return tuning


func _press_action(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)


# A key event as the keyboard delivers it: with the key's character and its position on
# the keyboard both set, so bindings by either would match.
func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	_held_events.append(event)


# A button on a pad on the first device.
func _press_joypad_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	_held_events.append(event)


func _release_action(action: StringName) -> void:
	Input.action_release(action)
	_held_actions.erase(action)


func _release_everything() -> void:
	for action in _held_actions:
		Input.action_release(action)
	_held_actions.clear()
	for event in _held_events:
		var release := event.duplicate() as InputEvent
		if release is InputEventJoypadMotion:
			release.axis_value = 0.0
		else:
			release.pressed = false
		Input.parse_input_event(release)
	_held_events.clear()
	Input.flush_buffered_events()


# Presses the Roll button and lets go again after a few frames.
func _tap_roll() -> void:
	_press_action(&"roll")
	await wait_physics_frames(TAP_FRAMES)
	_release_action(&"roll")


# The first stretch of samples in which Almos was rolling, as Vector2i(first, end): the
# index of the first sample showing him rolling and of the first showing him done. Either
# is -1 if it has not happened yet.
func _roll_span() -> Vector2i:
	var first := -1
	for i in _samples.size():
		if first == -1 and _samples[i].rolling:
			first = i
		elif first != -1 and not _samples[i].rolling:
			return Vector2i(first, i)
	return Vector2i(first, -1)


func _wait_for_the_roll_to_start() -> void:
	var started: bool = await wait_until(func(): return _roll_span().x != -1, WAIT_LIMIT, "the roll should start")
	assert_true(started, "the roll should have started")


func _wait_until_into_the_roll(seconds: float) -> void:
	var reached: bool = await wait_until(func(): return _roll_span().x != -1 and _seconds_into_roll(_samples.size() - 1) >= seconds, WAIT_LIMIT, "the roll should get that far")
	assert_true(reached, "the roll should have got %s seconds in" % seconds)


func _wait_for_the_roll_to_finish() -> void:
	var finished: bool = await wait_until(func(): return _roll_span().y != -1, WAIT_LIMIT, "the roll should finish")
	assert_true(finished, "the roll should have started and finished")


# How far the roll carried him: from where he stood just before it began to where he
# stood at the last sample that still showed him rolling.
func _roll_displacement() -> Vector2:
	var span := _roll_span()
	if span.x < 1 or span.y == -1:
		return Vector2.INF
	return _samples[span.y - 1].position - _samples[span.x - 1].position


func _frame_seconds() -> float:
	return 1.0 / Engine.physics_ticks_per_second


# How long into the roll the sample at this index was taken: after that many physics
# frames of rolling.
func _seconds_into_roll(index: int) -> float:
	return float(index - _roll_span().x + 1) * _frame_seconds()


# The indices of the samples in which he was untouchable.
func _untouchable_samples() -> Array[int]:
	var indices: Array[int] = []
	for i in _samples.size():
		if _samples[i].untouchable:
			indices.append(i)
	return indices


# How far into a roll, in seconds, a tap has to come to be kept for the next roll.
func _buffer_window_start() -> float:
	var tuning := _tuning()
	return tuning.roll_duration - tuning.roll_buffer_window


func _wait_for_sprinting() -> void:
	var started: bool = await wait_until(func(): return _first_sample_where("sprinting") != -1, WAIT_LIMIT, "he should start sprinting")
	assert_true(started, "he should have started sprinting")


# Waits until this many more samples have been taken.
func _wait_for_samples(count: int) -> void:
	var target := _samples.size() + count
	var reached: bool = await wait_until(func(): return _samples.size() >= target, WAIT_LIMIT)
	assert_true(reached, "%d more samples should have been taken" % count)


# The index of the first sample in which this state was true, or -1.
func _first_sample_where(state: String) -> int:
	for i in _samples.size():
		if _samples[i][state]:
			return i
	return -1


# His average velocity over this many samples from this one on, worked out from where he
# ended up.
func _average_velocity(from_index: int, frames: int) -> Vector2:
	return (_samples[from_index + frames].position - _samples[from_index].position) / (frames * _frame_seconds())
