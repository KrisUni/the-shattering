extends GutTest
## Almos swinging his Light attack, seen only through the scene: input goes in as actions
## or real input events, and a target stands in front of him with a Health of its own that
## shows when and how hard the sword hit. Every physics frame a sample of Almos and the
## target is taken, so what happened can be read back frame by frame. Expected numbers
## come from the sword data file the scene uses (or a copy a test changes) and plain
## arithmetic, never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AttackRig := preload("res://test/helpers/attack_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const WEAPON_PATH := AlmosInput.WEAPON_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# A tap: held this many physics frames, far shorter than a swing.
const TAP_FRAMES := 3
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# In pixels.
const POSITION_TOLERANCE := 0.01
const FACING_TOLERANCE := AlmosInput.FACING_TOLERANCE
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0
# A refill pause longer than any wait in these tests, for tests that need Stamina to stay
# where it was left.
const LONG_REFILL_PAUSE := 10.0
# How many physics frames a target is watched for when the sword is not to touch it.
const UNTOUCHED_FRAMES := 30
# In pixels. How far a test moves the sword's reach from the one in the data file, to see the
# sword follow it.
const REACH_LONGER_BY := 20.0
const REACH_SHORTER_BY := 10.0
# In pixels. How far inside or beyond the sword's far edge a target's Hurtbox is put, when the
# sword is to catch it or just miss it.
const REACH_MARGIN := 1.0

# How many physics frames after a swing's last active frame the target stops shrugging off
# hits, and whether the swing then still hits it. The sword is on for the last active frame
# and off for the one after.
var active_edge_params = ParameterFactory.named_parameters(
	["frames_after_last_active", "hits"],
	[[0, true], [1, false]],
)

# How the sword's reach is retuned from the one in the data file, how far beyond its far edge
# the nearest edge of the target's Hurtbox is put (a negative number is inside it), and whether
# the target is then hit.
var reach_params = ParameterFactory.named_parameters(
	["retune", "beyond_far_edge", "hits"],
	[
		[REACH_LONGER_BY, -REACH_MARGIN, true],
		[REACH_LONGER_BY, REACH_MARGIN, false],
		[-REACH_SHORTER_BY, -REACH_MARGIN, true],
		[-REACH_SHORTER_BY, REACH_MARGIN, false],
	],
)

# Where in the first swing a second press comes: in the last frame of its startup, in the
# first of its active frames, in the first of its recovery, and in the last frame of the
# recovery before the buffer window opens. None of them is kept. Each is worked out from
# the data file when the test runs.
var outside_window_params = ParameterFactory.named_parameters(
	["where"],
	[["last frame of startup"], ["first active frame"], ["first frame of recovery"], ["frame before the buffer window"]],
)

# Where in the first swing a second press comes when the buffer window is longer than the
# whole swing, and whether it chains into a second swing. The window does not reach back
# before the recovery.
var long_window_params = ParameterFactory.named_parameters(
	["where", "chains"],
	[["last frame of startup", false], ["first active frame", false], ["first frame of recovery", true]],
)

# Each way to press the Light attack button other than as the action itself.
var light_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the J key", func(input: AlmosInput): input.press_key(KEY_J)],
		["the left mouse button", func(input: AlmosInput): input.press_mouse_button(MOUSE_BUTTON_LEFT)],
		["the right bumper of a pad", func(input: AlmosInput): input.press_joypad_button(JOY_BUTTON_RIGHT_SHOULDER)],
	],
)

var _almos_input: AlmosInput
var _rig: AttackRig


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = AttackRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


func test_a_light_press_hits_the_target_for_the_first_swings_damage_after_its_startup_frames() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "the target should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, swing.damage, HEALTH_TOLERANCE)
	assert_eq(hits[0].sample - _rig.first_sample_where("attacking"), swing.startup_frames, "frames after the swing begins that the hit lands")


func test_the_sword_hurts_up_to_its_last_active_frame_and_no_later(params = use_parameters(active_edge_params)) -> void:
	var swing := _weapon().light_attacks[0]
	var last_active := swing.startup_frames + swing.active_frames - 1
	_rig.spawn_almos(_almos_input)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _tap_light()
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(_rig.almos.attacking, "the swing should have begun")
	_rig.shrug_off_hits_until_swing_frame(last_active + params.frames_after_last_active)

	await _rig.wait_frames(swing.startup_frames + swing.active_frames + swing.recovery_frames)

	var hits := _rig.hits()
	assert_eq(hits.size() == 1, params.hits, "hit or not")
	if params.hits and not hits.is_empty():
		assert_eq(hits[0].sample - _rig.first_sample_where("attacking"), last_active, "frames after the swing begins that the hit lands")


func test_a_light_swing_costs_its_stamina_once_at_its_start() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames + swing.recovery_frames)

	var begun := _rig.first_sample_where("attacking")
	assert_gt(begun, 0, "the swing should have begun")
	assert_almost_eq(_rig.samples[begun - 1].stamina, before, STAMINA_TOLERANCE, "nothing should be spent before the swing begins")
	assert_almost_eq(_rig.samples[begun].stamina, before - swing.stamina_cost, STAMINA_TOLERANCE, "it should be spent as the swing begins")
	assert_almost_eq(_rig.samples.back().stamina, before - swing.stamina_cost, STAMINA_TOLERANCE, "nothing more should be spent during the swing")


func test_a_swing_lasts_its_startup_active_and_recovery_frames_and_he_stands_still_through_it() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input)
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, swing.startup_frames + swing.active_frames + swing.recovery_frames, "frames the swing lasts")
	for i in range(span.x, span.y):
		assert_almost_eq(_rig.samples[i].position, _rig.samples[span.x - 1].position, Vector2.ONE * POSITION_TOLERANCE, "sample %d: he should stand still in the swing" % i)


func test_he_walks_again_the_frame_a_swings_recovery_ends() -> void:
	_rig.spawn_almos(_almos_input)
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	var end := _rig.attack_span().y
	var walked: float = _rig.samples[end].position.x - _rig.samples[end - 1].position.x
	assert_almost_eq(walked, _tuning().walk_speed / Engine.physics_ticks_per_second, POSITION_TOLERANCE, "pixels he walks in the first frame after the swing")


func test_tapping_roll_during_a_swing_does_nothing() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current
	await _tap_light()
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(_rig.almos.attacking, "he should still be in the swing when he taps the Roll button")

	await _tap_roll()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(_rig.first_sample_where("rolling"), -1, "he should not roll in the swing or after it")
	var span := _rig.attack_span()
	assert_almost_eq(_rig.samples[span.y - 1].stamina, before - swing.stamina_cost, STAMINA_TOLERANCE, "only the swing should have been paid for")
	assert_almost_eq(_rig.samples[span.y - 1].position, _rig.samples[span.x - 1].position, Vector2.ONE * POSITION_TOLERANCE, "he should have stood still through the swing")


func test_a_light_press_during_a_roll_is_ignored() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE})
	_rig.spawn_almos(_almos_input, tuning)
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current
	await _tap_roll()
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(_rig.almos.rolling, "he should still be rolling when he taps the Light attack button")

	await _tap_light()
	var finished: bool = await wait_until(func(): return not _rig.almos.rolling, WAIT_LIMIT, "the roll should finish")
	assert_true(finished, "the roll should have finished")
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(_rig.first_sample_where("attacking"), -1, "he should not swing, in the roll or after it")
	assert_almost_eq(_rig.samples.back().stamina, before - tuning.roll_stamina_cost, STAMINA_TOLERANCE, "only the roll should have been paid for")


func test_a_light_press_in_the_buffer_window_chains_into_the_second_swing_as_the_first_ends() -> void:
	var weapon := _weapon()
	var first := weapon.light_attacks[0]
	var second := weapon.light_attacks[1]
	assert_ne(first.damage, second.damage, "the swings should hurt differently, so that the order they come in shows")
	assert_ne(first.stamina_cost, second.stamina_cost, "the swings should cost differently, so that the order they come in shows")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(first) - weapon.attack_buffer_frames)
	await _tap_light()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(first) + _swing_frames(second), "the second swing should follow the first without a gap, and nothing follow it")
	var hits := _rig.hits()
	assert_eq(hits.size(), 2, "each swing should hit the target once")
	if hits.size() == 2:
		assert_almost_eq(hits[0].damage, first.damage, HEALTH_TOLERANCE)
		assert_almost_eq(hits[1].damage, second.damage, HEALTH_TOLERANCE)
		assert_eq(hits[1].sample - span.x, _swing_frames(first) + second.startup_frames, "frames after the first swing begins that the second hits")
	assert_almost_eq(_rig.samples[span.y - 1].stamina, before - first.stamina_cost - second.stamina_cost, STAMINA_TOLERANCE, "both swings should have been paid for")


func test_the_combo_chains_up_to_three_swings_and_then_starts_over() -> void:
	var weapon := _weapon()
	assert_eq(weapon.light_attacks.size(), 3, "the Light attack should chain three swings")
	var swings := [weapon.light_attacks[0], weapon.light_attacks[1], weapon.light_attacks[2]]
	assert_ne(swings[0].damage, swings[1].damage, "the swings should hurt differently, so that the order they come in shows")
	assert_ne(swings[1].damage, swings[2].damage, "the swings should hurt differently, so that the order they come in shows")
	assert_ne(swings[0].damage, swings[2].damage, "the swings should hurt differently, so that the order they come in shows")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	var run_frames := 0
	for swing in swings:
		run_frames += _swing_frames(swing)
		await _rig.wait_to_press_for_swing_frame(run_frames - weapon.attack_buffer_frames)
		await _tap_light()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, run_frames + _swing_frames(swings[0]), "the fourth swing should follow the third, and nothing follow it")
	var damages: Array[float] = []
	for hit in _rig.hits():
		damages.append(hit.damage)
	assert_eq(damages, [swings[0].damage, swings[1].damage, swings[2].damage, swings[0].damage], "damage of each hit")
	assert_eq(_light_swings_seen(), [1, 2, 3, 1], "the swing of the combo that was under way, in turn")


func test_a_light_press_outside_the_buffer_window_is_ignored(params = use_parameters(outside_window_params)) -> void:
	var weapon := _weapon()
	var swing := weapon.light_attacks[0]
	var press_frame := _press_frame_outside_the_window(params.where, weapon)
	assert_gt(press_frame, TAP_FRAMES, "the second press should come after the first has been let go")
	assert_lt(press_frame, _swing_frames(swing) - weapon.attack_buffer_frames, "the second press should come before the buffer window")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	var before: float = _rig.almos.stamina.current

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(press_frame)
	await _tap_light()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(swing), "press in the %s: only the first swing should have been made" % params.where)
	assert_eq(_rig.hits().size(), 1, "press in the %s: the target should have been hit once" % params.where)
	assert_almost_eq(_rig.samples.back().stamina, before - swing.stamina_cost, STAMINA_TOLERANCE, "press in the %s: only the first swing should have been paid for" % params.where)


func test_a_light_press_after_the_recovery_has_ended_starts_the_combo_over_at_the_first_swing() -> void:
	var weapon := _weapon()
	var first := weapon.light_attacks[0]
	var second := weapon.light_attacks[1]
	assert_ne(first.damage, second.damage, "the swings should hurt differently, so that the order they come in shows")
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await _rig.wait_frames(SETTLE_FRAMES)
	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(first) - weapon.attack_buffer_frames)
	await _tap_light()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_eq(_rig.almos.light_swing, 0, "no swing of the combo should be under way once it has ended")

	await _tap_light()
	await _rig.wait_frames(_swing_frames(first) + SETTLE_FRAMES)

	var damages: Array[float] = []
	for hit in _rig.hits():
		damages.append(hit.damage)
	assert_eq(damages, [first.damage, second.damage, first.damage], "damage of each hit")
	assert_eq(_light_swings_seen(), [1, 2, 1], "the swing of the combo that was under way, in turn")


func test_a_light_press_at_zero_stamina_does_nothing() -> void:
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_rig.almos.stamina.spend(_rig.almos.stamina.maximum)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(_rig.first_sample_where("attacking"), -1, "he should not swing with nothing to spend")
	assert_eq(_rig.hits().size(), 0, "the target should not have been hit")
	assert_almost_eq(_rig.almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_a_swing_with_less_stamina_than_it_costs_still_goes_ahead_and_empties_it() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_rig.almos.stamina.spend(_rig.almos.stamina.maximum - swing.stamina_cost / 3.0)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	assert_eq(_rig.hits().size(), 1, "the swing should have hit the target")
	assert_almost_eq(_rig.almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_the_next_swing_of_the_combo_needs_stamina_of_its_own() -> void:
	var weapon := _weapon()
	var first := weapon.light_attacks[0]
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	# Just enough for the first swing.
	_rig.almos.stamina.spend(_rig.almos.stamina.maximum - first.stamina_cost)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(_swing_frames(first) - weapon.attack_buffer_frames)
	await _tap_light()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(first), "the second swing should not begin with no stamina left")
	assert_eq(_rig.almos.light_swing, 0, "the combo should be over")


func test_the_light_attack_button_can_be_a_key_a_mouse_button_or_a_pad_button(params = use_parameters(light_binding_params)) -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input)
	await _rig.wait_frames(SETTLE_FRAMES)

	params.press.call(_almos_input)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_everything()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames + SETTLE_FRAMES)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "%s should swing the sword" % params.name)
	if not hits.is_empty():
		assert_almost_eq(hits[0].damage, swing.damage, HEALTH_TOLERANCE)


func test_a_light_press_while_sprinting_starts_a_swing_and_ends_the_sprint() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input)
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	var sprinting: bool = await wait_until(func(): return _rig.first_sample_where("sprinting") != -1, WAIT_LIMIT, "he should start sprinting")
	assert_true(sprinting, "he should have started sprinting")

	await _tap_light()
	await _wait_for_the_swing_to_end()

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, _swing_frames(swing), "the swing should have been made")
	for i in range(span.x, span.y):
		assert_false(_rig.samples[i].sprinting, "sample %d: he should not be sprinting in the swing" % i)
		assert_almost_eq(_rig.samples[i].position, _rig.samples[span.x - 1].position, Vector2.ONE * POSITION_TOLERANCE, "sample %d: he should stand still in the swing" % i)


func test_the_sword_swings_the_way_he_faces() -> void:
	var swing := _weapon().light_attacks[0]
	_rig.spawn_almos(_almos_input)
	# He starts out facing down, where the rig's target stands. He turns right by walking.
	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)
	_almos_input.release_action(&"move_right")
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_almost_eq(_rig.almos.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE)
	var ahead := _rig.place_target(_rig.almos.global_position + Vector2.RIGHT * AttackRig.TARGET_DISTANCE)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	assert_almost_eq(ahead.health.current, AttackRig.TARGET_HEALTH - swing.damage, HEALTH_TOLERANCE, "the target in front of him should be hit")
	assert_almost_eq(_rig.target.health.current, AttackRig.TARGET_HEALTH, HEALTH_TOLERANCE, "the target he is not facing should not be")


func test_the_sword_reaches_as_far_as_the_reach_in_its_weapon_data(params = use_parameters(reach_params)) -> void:
	var swing := _weapon().light_attacks[0]
	var weapon := _weapon().duplicate() as WeaponData
	weapon.reach = _weapon().reach + params.retune
	_rig.spawn_almos(_almos_input, null, weapon)
	# He starts out facing down. The nearest edge of the Hurtbox is put this far beyond the
	# sword's far edge.
	var distance: float = weapon.reach + AttackRig.TARGET_RADIUS + params.beyond_far_edge
	var probe := _rig.place_target(_rig.almos.global_position + Vector2.DOWN * distance)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	var hurt := probe.health.current < AttackRig.TARGET_HEALTH
	assert_eq(hurt, params.hits, "whether the target was hit")


func test_what_is_drawn_of_the_sword_covers_the_box_that_hurts_wherever_the_reach_is_tuned_to() -> void:
	var weapon := _weapon().duplicate() as WeaponData
	weapon.reach = _weapon().reach + REACH_LONGER_BY
	_rig.spawn_almos(_almos_input, null, weapon)
	var sword := _rig.almos.get_node("Sword") as Hitbox
	var box_in_scene := StrikeGeometry.box_size_in_scene(AlmosInput.ALMOS_SCENE_PATH, "Sword")

	var real := StrikeGeometry.real_box(sword)
	var drawn := StrikeGeometry.drawn_box(sword)

	assert_almost_eq(real.end.x, weapon.reach, POSITION_TOLERANCE, "how far out the box that hurts ends")
	assert_almost_eq(real.size, box_in_scene, Vector2.ONE * POSITION_TOLERANCE, "the width and height of the box that hurts should be the scene's")
	assert_almost_eq(drawn.position, real.position, Vector2.ONE * POSITION_TOLERANCE, "where the drawn sword starts, against the box that hurts")
	assert_almost_eq(drawn.size, real.size, Vector2.ONE * POSITION_TOLERANCE, "the size of the drawn sword, against the box that hurts")


func test_the_sword_is_off_and_hidden_once_a_swing_ends_even_when_it_has_no_recovery() -> void:
	var weapon := _weapon_with_no_recovery()
	var swing := weapon.light_attacks[0]
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}), weapon)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	var span := _rig.attack_span()
	assert_eq(span.y - span.x, swing.startup_frames + swing.active_frames, "a swing with no recovery should end with its active frames")
	var sword := _rig.almos.get_node("Sword") as Hitbox
	assert_false(sword.active, "the sword should be off once the swing has ended")
	assert_false(sword.visible, "the sword should be hidden once the swing has ended")
	# Someone walking into where it was, long after the swing, is not hurt.
	var late := _rig.place_target(_rig.almos.global_position + Vector2.DOWN * AttackRig.TARGET_DISTANCE)
	await _rig.wait_frames(UNTOUCHED_FRAMES)
	assert_almost_eq(late.health.current, AttackRig.TARGET_HEALTH, HEALTH_TOLERANCE, "a target that comes into the sword after the swing should not be hurt")


func test_the_buffer_window_never_reaches_back_before_the_recovery(params = use_parameters(long_window_params)) -> void:
	var weapon := _weapon().duplicate() as WeaponData
	var first := weapon.light_attacks[0]
	var second := weapon.light_attacks[1]
	weapon.attack_buffer_frames = _swing_frames(first) + _swing_frames(second)
	var press_frame := _press_frame_outside_the_window(params.where, weapon)
	_rig.spawn_almos(_almos_input, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}), weapon)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_to_press_for_swing_frame(press_frame)
	await _tap_light()
	await _wait_for_the_swing_to_end()
	await _rig.wait_frames(SETTLE_FRAMES)

	var span := _rig.attack_span()
	var expected := _swing_frames(first) + (_swing_frames(second) if params.chains else 0)
	assert_eq(span.y - span.x, expected, "press in the %s: frames attacked for" % params.where)


# How many frames into the first swing a press comes for this place in the swing.
func _press_frame_outside_the_window(where: String, weapon: WeaponData) -> int:
	var swing := weapon.light_attacks[0]
	match where:
		"last frame of startup":
			return swing.startup_frames - 1
		"first active frame":
			return swing.startup_frames
		"first frame of recovery":
			return swing.startup_frames + swing.active_frames
		_:
			return _swing_frames(swing) - weapon.attack_buffer_frames - 1


func _weapon() -> WeaponData:
	var weapon := load(WEAPON_PATH) as WeaponData
	assert_not_null(weapon, "the sword data file should load")
	return weapon


# The sword data file's attacks, with no recovery frames on any of them, for a test that needs
# a swing that ends the moment its active frames do. Nothing is shared with the data file.
func _weapon_with_no_recovery() -> WeaponData:
	var weapon := _weapon().duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as WeaponData
	for swing in weapon.light_attacks:
		swing.recovery_frames = 0
	weapon.heavy_attack.recovery_frames = 0
	return weapon


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


# How many physics frames the swing lasts from beginning to end of its recovery.
func _swing_frames(swing: AttackData) -> int:
	return swing.startup_frames + swing.active_frames + swing.recovery_frames


# The numbers the combo went through, as the samples show them: each swing number once,
# in the order they came, however many frames it was under way for.
func _light_swings_seen() -> Array[int]:
	var seen: Array[int] = []
	for sample in _rig.samples:
		if sample.light_swing != 0 and (seen.is_empty() or seen.back() != sample.light_swing):
			seen.append(sample.light_swing)
	return seen


func _wait_for_the_swing_to_end() -> void:
	var ended: bool = await wait_until(func(): return _rig.attack_span().y != -1, WAIT_LIMIT, "the swing should end")
	assert_true(ended, "the swing should have begun and ended")


# Presses the Roll button and lets go again after a few frames.
func _tap_roll() -> void:
	_almos_input.press_action(&"roll")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")


# Presses the Light attack button and lets go again after a few frames.
func _tap_light() -> void:
	_almos_input.press_action(&"attack_light")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
