extends GutTest
## Almos swinging his Heavy attack, seen only through the scene: input goes in as actions
## or real input events, and a target stands in front of him with a Health of its own that
## shows when and how hard the sword hit. Every physics frame a sample of Almos and the
## target is taken, so what happened can be read back frame by frame. Expected numbers
## come from the sword data file the scene uses (or a copy a test changes) and plain
## arithmetic, never from how the code works them out.
##
## How long the button was held is read from the samples: the number of them that show him
## charging is the number of physics frames the button was held for, which is not the same
## as how much charge it built: that starts only once the button has been held for the
## charge start, so a quick tap builds none.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AttackRig := preload("res://test/helpers/attack_rig.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const WEAPON_PATH := AlmosInput.WEAPON_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# A tap: held this many physics frames, far shorter than a swing or a charge.
const TAP_FRAMES := 3
# The key the Heavy attack button is pressed with when a test needs a real key event.
const HEAVY_KEY := KEY_K
# How many physics frames a test charges for when the amount does not matter, short of a
# full charge.
const SOME_CHARGE_FRAMES := 20
# In pixels.
const POSITION_TOLERANCE := 0.01
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# A refill pause longer than any wait in these tests, for tests that need Stamina to stay
# where it was left.
const LONG_REFILL_PAUSE := 10.0
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0
# The most physics frames any wait for a number of them may take.
const WAIT_FRAME_LIMIT := 240

# Each way to press the Heavy attack button other than as the action itself.
var heavy_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the K key", func(input: AlmosInput): input.press_key(KEY_K)],
		["the right mouse button", func(input: AlmosInput): input.press_mouse_button(MOUSE_BUTTON_RIGHT)],
		["the right trigger of a pad", func(input: AlmosInput): input.push_joypad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
	],
)

# How many physics frames the button is held for when it is let go before the charge starts:
# a single frame, a few, the last one before the charge start, and the charge start itself,
# which has built nothing yet. Each is worked out from the data file when the test runs.
var short_hold_params = [1, TAP_FRAMES, _heavy_data().charge_start_frames - 1, _heavy_data().charge_start_frames]

# How many physics frames the button is held for when it is let go part way up the charge:
# just past the charge start, half way between it and the full charge, and one short of the
# full charge. Each is worked out from the data file when the test runs.
var partial_hold_params = ParameterFactory.named_parameters(
	["where", "frames"],
	[
		["just past the charge start", _heavy_data().charge_start_frames + 1],
		["half way up", _heavy_data().charge_start_frames + (_heavy_data().charge_frames_max - _heavy_data().charge_start_frames) / 2],
		["one short of the full charge", _heavy_data().charge_frames_max - 1],
	],
)

var _almos_input: AlmosInput
var _rig: AttackRig


func before_each() -> void:
	_almos_input = AlmosInput.new(self)
	_rig = AttackRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


func test_letting_go_before_the_charge_starts_gives_the_plain_heavy_attack(frames = use_parameters(short_hold_params)) -> void:
	var heavy := _weapon().heavy_attack
	assert_gt(frames, 0, "the button should be held for some frames")
	assert_true(frames <= heavy.charge_start_frames, "the button should be let go by the time the charge starts")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _hold_heavy_for(frames)
	await _wait_for_the_swing_to_begin()
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames + SETTLE_FRAMES)

	assert_eq(_frames_held(), frames, "frames the button was held for: the test should have held it as long as it meant to")
	var begun := _rig.first_sample_where("attacking")
	assert_gt(begun, 0, "the swing should have begun")
	assert_almost_eq(_rig.samples[begun].stamina, before - heavy.stamina_cost, STAMINA_TOLERANCE, "held for %d frames: stamina spent as the swing begins" % frames)
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "held for %d frames: the target should have been hit once" % frames)
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, heavy.damage, HEALTH_TOLERANCE, "held for %d frames: damage" % frames)
	assert_eq(hits[0].sample - begun, heavy.startup_frames, "frames after the swing begins that the hit lands")


func test_holding_the_heavy_button_charges_to_the_maximum_and_the_swing_comes_out_by_itself() -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	# The button is never let go.
	_almos_input.press_action(&"attack_heavy")
	await _wait_for_the_swing_to_begin()
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames + SETTLE_FRAMES)

	assert_true(Input.is_action_pressed(&"attack_heavy"), "the button should still be held")
	assert_eq(_frames_held(), heavy.charge_frames_max, "frames the button was held for before the swing came out")
	# Holding on past the swing does not start another charge.
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(heavy.charge_frames_max)
	assert_eq(_frames_held(), heavy.charge_frames_max, "he should not start another charge while the button is still held")
	var begun := _rig.first_sample_where("attacking")
	assert_almost_eq(_rig.samples[begun].stamina, before - heavy.charged_stamina_cost, STAMINA_TOLERANCE, "stamina spent as the swing begins")
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "the target should have been hit once")
	if not hits.is_empty():
		assert_almost_eq(hits[0].damage, heavy.charged_damage, HEALTH_TOLERANCE)


func test_letting_go_part_way_up_the_charge_hits_and_costs_in_proportion(params = use_parameters(partial_hold_params)) -> void:
	var heavy := _weapon().heavy_attack
	var frames: int = params.frames
	assert_gt(frames, heavy.charge_start_frames, "the button should be held past the charge start")
	assert_lt(frames, heavy.charge_frames_max, "the button should be let go before the charge is full")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _hold_heavy_for(frames)
	await _wait_for_the_swing_to_begin()
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames + SETTLE_FRAMES)

	assert_eq(_frames_held(), frames, "frames the button was held for: the test should have held it as long as it meant to")
	var expected_damage := _damage_after(heavy, frames)
	var expected_cost := _cost_after(heavy, frames)
	assert_gt(expected_damage, heavy.damage, "%s: a partial charge should hit harder than none" % params.where)
	assert_lt(expected_damage, heavy.charged_damage, "%s: a partial charge should hit softer than a full one" % params.where)
	var begun := _rig.first_sample_where("attacking")
	assert_almost_eq(_rig.samples[begun].stamina, before - expected_cost, STAMINA_TOLERANCE, "%s: stamina spent as the swing begins" % params.where)
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "%s: the target should have been hit once" % params.where)
	if not hits.is_empty():
		assert_almost_eq(hits[0].damage, expected_damage, HEALTH_TOLERANCE, "%s: damage" % params.where)


func test_half_way_between_the_charge_start_and_the_full_charge_hits_and_costs_the_average_of_the_two() -> void:
	var heavy := _weapon().heavy_attack
	var ramp := heavy.charge_frames_max - heavy.charge_start_frames
	assert_eq(ramp % 2, 0, "the frames from the charge start to the full charge should split in half evenly")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _hold_heavy_for(heavy.charge_start_frames + ramp / 2)
	await _wait_for_the_swing_to_begin()
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames + SETTLE_FRAMES)

	var begun := _rig.first_sample_where("attacking")
	assert_almost_eq(_rig.samples[begun].stamina, before - (heavy.stamina_cost + heavy.charged_stamina_cost) / 2.0, STAMINA_TOLERANCE, "stamina spent as the swing begins")
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "the target should have been hit once")
	if not hits.is_empty():
		assert_almost_eq(hits[0].damage, (heavy.damage + heavy.charged_damage) / 2.0, HEALTH_TOLERANCE)


func test_the_sword_data_makes_the_heavy_attack_slower_and_harder_hitting_and_more_so_when_charged() -> void:
	var weapon := _weapon()
	var heavy := weapon.heavy_attack
	for light in weapon.light_attacks:
		assert_gt(heavy.startup_frames, light.startup_frames, "the Heavy attack should start up more slowly than every swing of the Light attack")
		assert_gt(heavy.damage, light.damage, "the Heavy attack should hit harder than every swing of the Light attack")
	assert_gt(heavy.charge_start_frames, 0, "the charge should not start the instant the button is pressed")
	assert_lt(heavy.charge_start_frames, heavy.charge_frames_max, "the charge should start before it is full")
	assert_gt(heavy.charged_damage, heavy.damage, "a full charge should hit harder")
	assert_gt(heavy.charged_stamina_cost, heavy.stamina_cost, "a full charge should cost more Stamina")


func test_a_heavy_press_at_zero_stamina_does_nothing() -> void:
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_rig.almos.stamina.spend(_rig.almos.stamina.maximum)
	await _rig.wait_frames(SETTLE_FRAMES)

	_almos_input.press_action(&"attack_heavy")
	await _rig.wait_frames(SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(_rig.first_sample_where("charging"), -1, "he should not start charging with nothing to spend")
	assert_eq(_rig.first_sample_where("attacking"), -1, "he should not swing with nothing to spend")
	assert_eq(_rig.hits().size(), 0, "the target should not have been hit")


func test_charging_spends_no_stamina_until_the_swing_comes_out() -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	_almos_input.press_action(&"attack_heavy")
	await _wait_until_held_for(SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_for_the_swing_to_begin()

	var span := _rig.charge_span()
	for i in range(span.x, span.y):
		assert_almost_eq(_rig.samples[i].stamina, before, STAMINA_TOLERANCE, "sample %d: nothing should be spent while charging" % i)
	var begun := _rig.first_sample_where("attacking")
	assert_almost_eq(_rig.samples[begun].stamina, before - _cost_after(heavy, SOME_CHARGE_FRAMES), STAMINA_TOLERANCE, "it should be spent as the swing comes out")


func test_a_heavy_swing_lasts_its_startup_active_and_recovery_frames() -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input)
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_heavy()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(heavy), "frames the swing lasts")
	for i in range(span.x, span.y):
		assert_almost_eq(_rig.samples[i].position, _rig.samples[span.x - 1].position, Vector2.ONE * POSITION_TOLERANCE, "sample %d: he should stand still in the swing" % i)


func test_a_swing_with_less_stamina_than_a_heavy_attack_costs_still_goes_ahead_and_empties_it() -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_rig.almos.stamina.spend(_rig.almos.stamina.maximum - heavy.stamina_cost / 3.0)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_heavy()
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames + SETTLE_FRAMES)

	assert_eq(_rig.hits().size(), 1, "the swing should have hit the target")
	assert_almost_eq(_rig.almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_a_heavy_press_in_the_buffer_window_of_a_light_swing_comes_out_as_it_ends() -> void:
	var weapon := _weapon()
	var light := weapon.light_attacks[0]
	var heavy := weapon.heavy_attack
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(light) - weapon.attack_buffer_frames)
	# Let go at once, so the charge is none.
	await _tap_heavy()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(light) + _swing_frames(heavy), "the Heavy attack should follow the Light swing without a gap")
	var hits := _rig.hits()
	assert_eq(hits.size(), 2, "each swing should hit the target once")
	if hits.size() == 2:
		assert_almost_eq(hits[0].damage, light.damage, HEALTH_TOLERANCE)
		assert_almost_eq(hits[1].damage, heavy.damage, HEALTH_TOLERANCE)
		assert_eq(hits[1].sample - span.x, _swing_frames(light) + heavy.startup_frames, "frames after the Light swing begins that the Heavy attack hits")
	assert_almost_eq(_rig.samples[span.y - 1].stamina, before - light.stamina_cost - heavy.stamina_cost, STAMINA_TOLERANCE, "both swings should have been paid for")


func test_a_heavy_button_held_from_a_light_swing_starts_charging_as_its_recovery_ends() -> void:
	var weapon := _weapon()
	var light := weapon.light_attacks[0]
	_rig.spawn_almos(_almos_input)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(light) - weapon.attack_buffer_frames)
	_almos_input.press_action(&"attack_heavy")
	await _wait_until_held_for(SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _rig.wait_frames(SETTLE_FRAMES)

	var attack_span := _rig.attack_span()
	var charge_span := _rig.charge_span()
	assert_eq(attack_span.y - attack_span.x, _swing_frames(light), "the Light swing should run its course")
	assert_eq(charge_span.x, attack_span.y, "he should start charging in the sample that shows the swing over")
	assert_eq(charge_span.y - charge_span.x, SOME_CHARGE_FRAMES, "frames he charged for")


func test_a_light_press_in_the_buffer_window_of_a_heavy_swing_starts_the_combo_over() -> void:
	var weapon := _weapon()
	var light := weapon.light_attacks[0]
	var heavy := weapon.heavy_attack
	assert_ne(weapon.light_attacks[1].damage, light.damage, "the swings should hurt differently, so that the order they come in shows")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)

	# A Light swing, then a Heavy attack kept for its end, then a Light swing kept for the
	# Heavy attack's end.
	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(light) - weapon.attack_buffer_frames)
	await _tap_heavy()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(light) + _swing_frames(heavy) - weapon.attack_buffer_frames)
	await _tap_light()
	await _wait_for_the_swing_to_end()

	var damages: Array[float] = []
	for hit in _rig.hits():
		damages.append(hit.damage)
	assert_eq(damages, [light.damage, heavy.damage, light.damage], "damage of each hit: the combo should start over after the Heavy attack")
	var span := _rig.attack_span()
	assert_eq(span.y - span.x, 2 * _swing_frames(light) + _swing_frames(heavy), "the swings should follow one another without a gap")
	var heavy_start := span.x + _swing_frames(light)
	for i in range(heavy_start, heavy_start + _swing_frames(heavy)):
		assert_eq(_rig.samples[i].light_swing, 0, "sample %d: no swing of the Light combo should be under way in the Heavy attack" % i)


func test_a_heavy_press_outside_the_buffer_window_is_ignored() -> void:
	var weapon := _weapon()
	var light := weapon.light_attacks[0]
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(light.startup_frames)
	await _tap_heavy()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(light), "only the Light swing should have been made")
	assert_eq(_rig.first_sample_where("charging"), -1, "he should not have charged")
	assert_almost_eq(_rig.samples.back().stamina, before - light.stamina_cost, STAMINA_TOLERANCE, "only the Light swing should have been paid for")


func test_the_heavy_attack_button_can_be_a_key_a_mouse_button_or_a_pad_trigger(params = use_parameters(heavy_binding_params)) -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input)
	await _rig.wait_frames(SETTLE_FRAMES)

	params.press.call(_almos_input)
	await _rig.wait_frames(SETTLE_FRAMES)
	_almos_input.release_everything()
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames + SETTLE_FRAMES)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "%s should swing the sword" % params.name)
	if not hits.is_empty():
		assert_gt(hits[0].damage, 0.0)


func test_he_stands_still_while_charging() -> void:
	_rig.spawn_almos(_almos_input)
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)

	_almos_input.press_action(&"attack_heavy")
	await _wait_until_held_for(SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_for_the_swing_to_begin()

	var span := _rig.charge_span()
	assert_eq(span.y - span.x, SOME_CHARGE_FRAMES, "frames he charged for")
	for i in range(span.x, span.y):
		assert_almost_eq(_rig.samples[i].position, _rig.samples[span.x - 1].position, Vector2.ONE * POSITION_TOLERANCE, "sample %d: he should stand still while charging" % i)


func test_tapping_roll_while_charging_does_nothing() -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	_almos_input.press_action(&"attack_heavy")
	await _wait_until_held_for(SOME_CHARGE_FRAMES)
	await _tap_roll()
	await _wait_until_held_for(2 * SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_for_the_swing_to_begin()

	assert_eq(_rig.first_sample_where("rolling"), -1, "he should not roll while charging")
	assert_eq(_frames_held(), 2 * SOME_CHARGE_FRAMES, "the button should have stayed held through the tap")
	var begun := _rig.first_sample_where("attacking")
	assert_almost_eq(_rig.samples[begun].stamina, before - _cost_after(heavy, 2 * SOME_CHARGE_FRAMES), STAMINA_TOLERANCE, "only the swing should have been paid for")


func test_a_light_press_while_charging_is_ignored() -> void:
	var heavy := _weapon().heavy_attack
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	_almos_input.press_action(&"attack_heavy")
	await _wait_until_held_for(SOME_CHARGE_FRAMES)
	await _tap_light()
	await _wait_until_held_for(2 * SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_for_the_swing_to_begin()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(_rig.samples.filter(func(sample): return sample.light_swing != 0).size(), 0, "no swing of the Light combo should have been made")
	assert_eq(_rig.attack_span().y - _rig.attack_span().x, _swing_frames(heavy), "only the Heavy attack should have been swung")
	assert_almost_eq(_rig.samples.back().stamina, before - _cost_after(heavy, 2 * SOME_CHARGE_FRAMES), STAMINA_TOLERANCE, "only the Heavy attack should have been paid for")


func _weapon() -> WeaponData:
	var weapon := load(WEAPON_PATH) as WeaponData
	assert_not_null(weapon, "the sword data file should load")
	return weapon


# The Heavy attack of the sword data file, for the parameters of tests, which are worked out
# before any test runs.
static func _heavy_data() -> HeavyAttackData:
	return (load(WEAPON_PATH) as WeaponData).heavy_attack


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


# The damage and the Stamina cost of a Heavy attack whose button was held for this many
# physics frames. Nothing is charged until the button has been held for the charge start;
# from there the charge grows in a straight line to a full one at charge_frames_max, and
# damage and cost grow with it from the plain ones to those of a full charge.
func _damage_after(heavy: HeavyAttackData, frames_held: int) -> float:
	return heavy.damage + (heavy.charged_damage - heavy.damage) * _charge_after(heavy, frames_held)


func _cost_after(heavy: HeavyAttackData, frames_held: int) -> float:
	return heavy.stamina_cost + (heavy.charged_stamina_cost - heavy.stamina_cost) * _charge_after(heavy, frames_held)


# How much of a full charge, from 0 to 1, the button held for this many physics frames builds.
func _charge_after(heavy: HeavyAttackData, frames_held: int) -> float:
	return clampf(float(frames_held - heavy.charge_start_frames) / (heavy.charge_frames_max - heavy.charge_start_frames), 0.0, 1.0)


# How many physics frames the button was held for: the samples that show him charging,
# which he does from the press, before the charge itself has started.
func _frames_held() -> int:
	var frames := 0
	for sample in _rig.samples:
		if sample.charging:
			frames += 1
	return frames


# Waits until the button has been held for this many frames, so that letting go now ends the
# hold at exactly that many.
func _wait_until_held_for(frames: int) -> void:
	for i in WAIT_FRAME_LIMIT:
		if _frames_held() >= frames:
			return
		await get_tree().physics_frame
	fail_test("the button should have been held for %d frames" % frames)


func _wait_for_the_swing_to_begin() -> void:
	var begun: bool = await wait_until(func(): return _rig.first_sample_where("attacking") != -1, WAIT_LIMIT, "the swing should begin")
	assert_true(begun, "the swing should have begun")


# How many physics frames the swing lasts from beginning to end of its recovery.
func _swing_frames(swing: AttackData) -> int:
	return swing.startup_frames + swing.active_frames + swing.recovery_frames


func _wait_for_the_swing_to_end() -> void:
	var ended: bool = await wait_until(func(): return _rig.attack_span().y != -1, WAIT_LIMIT, "the swing should end")
	assert_true(ended, "the swing should have begun and ended")


# Presses the Light attack button and lets go again after a few frames.
func _tap_light() -> void:
	_almos_input.press_action(&"attack_light")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")


# Presses the Roll button and lets go again after a few frames.
func _tap_roll() -> void:
	_almos_input.press_action(&"roll")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")


# Holds the Heavy attack button down for this many physics frames and lets go, as a keyboard
# does: with real key events that take effect between two physics frames. A script that
# presses and releases an action in the same breath gives the game no such frames to see the
# button down in, which is not how a person taps. The game acts on a press from the physics
# frame after the one it was made in, so the key is let go one frame later than the frames
# it is to be held for; the samples show how long it really was held.
func _hold_heavy_for(frames: int) -> void:
	_almos_input.press_key(HEAVY_KEY, true)
	await _rig.wait_frames(frames + 1)
	_almos_input.release_key(HEAVY_KEY, true)


# Taps the Heavy attack button: holds it for a single physics frame, too soon to build any
# charge.
func _tap_heavy() -> void:
	await _hold_heavy_for(1)
