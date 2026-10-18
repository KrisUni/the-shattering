extends GutTest
## Almos jumping, seen only through the scene: input goes in as actions or real input events,
## and we watch where he lands. Gaps and ledges are built from the world scenes, sized in the
## test. Every physics frame a sample of him is taken, so what happened can be read back frame
## by frame: a sample is taken at the start of the frame, before anything has moved in it, so
## it shows how the frame before left things. Expected numbers come from the tuning data file
## the scene uses (or a copy a test changes), the radius of his body and plain arithmetic.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
const GAP_SCENE_PATH := "res://scenes/world/gap.tscn"
const LEDGE_SCENE_PATH := "res://scenes/world/ledge.tscn"
# In pixels.
const POSITION_TOLERANCE := 0.01
# In pixels. For where a body comes to rest against something, which is a safety margin short
# of it.
const REST_TOLERANCE := 0.5
# In pixels. How much narrower than his reach a gap is, to be cleared, or how much wider, to
# be fallen short of.
const REACH_MARGIN := 6.0
# In pixels. Tall enough that no test goes round a gap or a ledge.
const WORLD_HEIGHT := 600.0
# In pixels. How wide a ledge is: far wider than any Jump reaches.
const LEDGE_WIDTH := 300.0
# In pixels. How wide a gap or ledge is that the training enemy has to get round: narrow
# enough to have its target in sight across it.
const NARROW_WIDTH := 100.0
# In pixels. How far before an edge a run starts.
const RUN_UP := 60.0
# In physics frames. Enough to run RUN_UP at walking speed and stand against the edge.
const RUN_UP_FRAMES := 60
# In physics frames. Enough to cross a whole ledge at walking speed.
const CROSS_LEDGE_FRAMES := 200
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0
# A tap: held this many physics frames, far shorter than any sensible hold threshold.
const TAP_FRAMES := 2
# In physics frames. Past the end of something that a test carries on to see what comes of it.
const PAST_THE_END_FRAMES := 12
# In frames. Keeps a time that is a whole number of frames from being counted as one more.
const FRAME_COUNT_ALLOWANCE := 0.0001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# A refill pause longer than any wait in these tests, for tests that need Stamina to stay
# where it was left.
const LONG_REFILL_PAUSE := 10.0
# In pixels. How far the straight line may be left by a Jump that is meant to keep to it.
const LINE_TOLERANCE := 0.05
# In pixels. How far from Almos a stand-in enemy to lock on to is put.
const ENEMY_DISTANCE := 100.0
# The share of the tuned height that the top of the arc may fall short of: frames do not fall
# exactly on the top.
const PEAK_ALLOWANCE := 0.03
# In pixels. How far from the middle of an enemy Almos comes down, to land half on it.
const LANDING_OFFSET := 6.0

var jump_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the F key", func(input: AlmosInput): input.press_key(KEY_F)],
		["the A button of a pad", func(input: AlmosInput): input.press_joypad_button(JOY_BUTTON_A)],
	],
)

# The world scene whose sides block him on the ground.
var blocking_sides_params = ParameterFactory.named_parameters(
	["name", "scene_path"],
	[["a gap", GAP_SCENE_PATH], ["a low ledge", LEDGE_SCENE_PATH]],
)

# The attack buttons, whose presses are lost in the air.
var attack_button_params = ParameterFactory.named_parameters(
	["action"],
	[[&"attack_light"], [&"attack_heavy"]],
)

var _almos_input: AlmosInput
var _almos: Node2D
var _hits: AlmosHits
var _rig: EnemyRig
var _samples: Array[Dictionary] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first
	# processed after the first sample and what it presses is seen from the next frame.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_hits = AlmosHits.new(self)
	_rig = EnemyRig.new(self)


func after_each() -> void:
	_stop_sampling()
	_rig.stop_sampling()
	_almos_input.release_everything()


# Reach

func test_a_walking_jump_clears_a_gap_narrower_than_the_distance_it_carries_him() -> void:
	var reach := _tuning().walk_speed * _tuning().jump_duration
	var gap := _spawn_gap(reach - _body_radius() - REACH_MARGIN)
	await _stand_against_the_left_edge_of(gap)

	await _jump_while_pushing(&"move_right")

	assert_almost_eq(_landing().x - _takeoff().x, reach, POSITION_TOLERANCE, "he should land the whole reach beyond where he took off")
	assert_gt(_landing().x, _far_edge_of(gap), "he should come down beyond the gap")


func test_a_walking_jump_into_a_gap_wider_than_the_distance_it_carries_him_puts_him_back_where_it_began() -> void:
	var reach := _tuning().walk_speed * _tuning().jump_duration
	var gap := _spawn_gap(reach - _body_radius() + REACH_MARGIN)
	await _stand_against_the_left_edge_of(gap)

	await _jump_while_pushing(&"move_right")

	assert_almost_eq(_landing(), _takeoff(), Vector2.ONE * POSITION_TOLERANCE, "he should be back where the Jump began")


func test_a_sprinting_jump_clears_a_gap_that_a_walking_jump_cannot() -> void:
	var sprint_reach := _tuning().sprint_speed * _tuning().jump_duration
	var gap := _spawn_gap(sprint_reach - _body_radius() - REACH_MARGIN)
	_almos_input.press_action(&"roll")
	await _stand_against_the_left_edge_of(gap)

	await _jump_while_pushing(&"move_right")

	assert_almost_eq(_landing().x - _takeoff().x, sprint_reach, POSITION_TOLERANCE, "he should land the sprinting reach beyond where he took off")
	assert_gt(_landing().x, _far_edge_of(gap), "he should come down beyond the gap")


func test_a_sprinting_jump_into_a_gap_wider_than_its_reach_puts_him_back() -> void:
	var sprint_reach := _tuning().sprint_speed * _tuning().jump_duration
	var gap := _spawn_gap(sprint_reach - _body_radius() + REACH_MARGIN)
	_almos_input.press_action(&"roll")
	await _stand_against_the_left_edge_of(gap)

	await _jump_while_pushing(&"move_right")

	assert_almost_eq(_landing(), _takeoff(), Vector2.ONE * POSITION_TOLERANCE, "he should be back where the Jump began")


func test_a_jump_while_blocking_carries_him_at_the_slow_blocking_walk() -> void:
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"block")
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_jump_and_wait_until_down()

	var expected := _tuning().block_walk_speed * _tuning().jump_duration
	assert_almost_eq(_landing().x - _takeoff().x, expected, POSITION_TOLERANCE)


func test_a_jump_lasts_the_tuned_time() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_jump_and_wait_until_down()

	var frames_in_the_air := _frames_in_the_air()
	assert_eq(frames_in_the_air, ceili(_tuning().jump_duration * Engine.physics_ticks_per_second - FRAME_COUNT_ALLOWANCE))


func test_a_jump_press_in_the_air_is_lost() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")

	await _tap(&"jump")
	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	var frames_in_the_air := _frames_in_the_air()
	assert_eq(frames_in_the_air, ceili(_tuning().jump_duration * Engine.physics_ticks_per_second - FRAME_COUNT_ALLOWANCE), "it should neither restart the Jump nor be kept for after")
	assert_almost_eq(_almos.stamina.current, _tuning().stamina_maximum - _tuning().jump_stamina_cost, STAMINA_TOLERANCE, "only the first press should have been paid for")


func test_a_jump_standing_still_goes_nowhere() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_jump_and_wait_until_down()

	assert_almost_eq(_landing(), _takeoff(), Vector2.ONE * POSITION_TOLERANCE)


func test_a_jump_ends_a_sprint_and_does_not_drain_stamina_while_it_lasts() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_almos_input.press_action(&"roll")
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(_frames_for(_tuning().roll_hold_threshold) + SETTLE_FRAMES)
	assert_true(_almos.sprinting, "he should be sprinting before the Jump")

	await _tap_jump_and_wait_until_down()

	var airborne := _samples.filter(func(sample: Dictionary) -> bool: return sample.airborne)
	assert_false(airborne.any(func(sample: Dictionary) -> bool: return sample.sprinting), "he should not be sprinting in the air")
	assert_almost_eq(airborne.back().stamina, airborne[1].stamina, STAMINA_TOLERANCE, "nothing should drain while he is in the air")


func test_a_jump_under_lock_on_keeps_to_a_straight_line() -> void:
	_spawn_almos(Vector2.ZERO)
	_stand_in_enemy_at(Vector2.UP * ENEMY_DISTANCE)
	await _tap(&"lock_on")
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should be locked on before the Jump")

	await _tap_jump_and_wait_until_down()

	var line := _landing() - _takeoff()
	assert_gt(line.length(), 0.0, "he should have gone somewhere")
	for sample in _samples.filter(func(sample: Dictionary) -> bool: return sample.airborne):
		var off_the_line := absf(line.normalized().cross(sample.position - _takeoff()))
		assert_lt(off_the_line, LINE_TOLERANCE, "he should not circle the target in the air")


func test_jump_is_on_its_own_button(params = use_parameters(jump_binding_params)) -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)

	params.press.call(_almos_input)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.airborne, "pressing %s should make him Jump" % params.name)
	assert_false(_almos.rolling, "pressing %s should not Roll" % params.name)


# Height levels

func test_a_jump_up_onto_a_low_ledge_puts_him_on_it() -> void:
	var ledge := _spawn_ledge(LEDGE_WIDTH)
	await _stand_against_the_left_edge_of(ledge)
	assert_eq(_almos.height_level, 0, "he should start on the ground")

	await _jump_while_pushing(&"move_right")

	var reach := _tuning().walk_speed * _tuning().jump_duration
	assert_eq(_almos.height_level, 1, "he should be on the ledge")
	assert_almost_eq(_landing().x - _takeoff().x, reach, POSITION_TOLERANCE, "he should land the whole reach on")


func test_the_edges_of_a_low_ledge_keep_him_on_it() -> void:
	var ledge := _spawn_ledge(LEDGE_WIDTH)
	await _stand_against_the_left_edge_of(ledge)
	await _jump_while_pushing(&"move_right")

	await wait_physics_frames(CROSS_LEDGE_FRAMES)

	assert_almost_eq(_almos.position.x, _far_edge_of(ledge) - _body_radius(), REST_TOLERANCE, "he should stand against the far edge")
	assert_eq(_almos.height_level, 1, "he should still be on the ledge")


func test_a_jump_off_a_low_ledge_lands_him_on_the_ground() -> void:
	var ledge := _spawn_ledge(LEDGE_WIDTH)
	await _stand_against_the_left_edge_of(ledge)
	await _jump_while_pushing(&"move_right")
	await wait_physics_frames(CROSS_LEDGE_FRAMES)
	var edge_x: float = _almos.position.x
	_samples.clear()

	await _tap_jump_and_wait_until_down()

	var reach := _tuning().walk_speed * _tuning().jump_duration
	assert_eq(_almos.height_level, 0, "he should be on the ground")
	assert_almost_eq(_landing().x, edge_x + reach, POSITION_TOLERANCE, "he should land the whole reach off")
	await wait_physics_frames(RUN_UP_FRAMES)
	assert_gt(_almos.position.x, edge_x + reach, "the edge of the ledge should no longer hold him")


func test_the_sides_of_gaps_and_low_ledges_block_him_on_the_ground(params = use_parameters(blocking_sides_params)) -> void:
	var world := _spawn_world(params.scene_path, LEDGE_WIDTH)
	_spawn_almos(Vector2(world.position.x - LEDGE_WIDTH / 2.0 - _body_radius() - RUN_UP, 0.0))
	_almos_input.press_action(&"move_right")

	await wait_physics_frames(CROSS_LEDGE_FRAMES)

	assert_almost_eq(_almos.position.x, world.position.x - LEDGE_WIDTH / 2.0 - _body_radius(), REST_TOLERANCE, "he should stand against the side of %s" % params.name)
	assert_eq(_almos.height_level, 0, "he should still be on the ground")


func test_real_walls_block_him_in_the_air() -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(16.0, WORLD_HEIGHT)
	shape.shape = box
	wall.add_child(shape)
	var reach := _tuning().walk_speed * _tuning().jump_duration
	wall.position = Vector2(reach / 2.0, 0.0)
	add_child_autofree(wall)
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_jump_and_wait_until_down()

	assert_lt(_landing().x, wall.position.x, "the wall should have stopped him in the air")


func test_the_training_enemy_is_blocked_by_gaps_and_low_ledge_sides_like_a_grounded_almos(params = use_parameters(blocking_sides_params)) -> void:
	var world := _spawn_world(params.scene_path, NARROW_WIDTH)
	var enemy = _rig.spawn_enemy(null, Vector2(world.position.x + NARROW_WIDTH / 2.0 + _body_radius() + RUN_UP, 0.0))
	var notice_range: float = enemy.tuning.notice_range
	_rig.place_target(Vector2(world.position.x - NARROW_WIDTH / 2.0 - 1.0, 0.0))
	assert_lt(enemy.position.x - _rig.target.position.x, notice_range, "the target should be near enough to be noticed")

	await _rig.wait_frames(CROSS_LEDGE_FRAMES)

	assert_almost_eq(enemy.position.x, world.position.x + NARROW_WIDTH / 2.0 + _body_radius(), REST_TOLERANCE, "it should stand against the side of %s" % params.name)


# Landing

func test_landing_on_an_enemy_pushes_him_off_it_and_never_stands_him_on_it() -> void:
	var reach := _tuning().walk_speed * _tuning().jump_duration
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	# He cannot steer in the air, and lands standing still. The enemy is put where he will
	# come down, a little to one side of its middle.
	_almos_input.release_action(&"move_right")
	var enemy = _rig.spawn_enemy(null, _takeoff() + Vector2(reach + LANDING_OFFSET, 0.0))
	_rig.place_target(Vector2(0.0, 5.0 * enemy.tuning.notice_range))

	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	var apart: float = _almos.position.distance_to(enemy.position)
	assert_gte(apart, 2.0 * _body_radius() - REST_TOLERANCE, "he should be pushed out of the enemy")
	assert_eq(_almos.height_level, 0, "he should be on the ground")


func test_an_enemy_does_not_stop_him_in_the_air() -> void:
	var reach := _tuning().walk_speed * _tuning().jump_duration
	_spawn_almos(Vector2.ZERO)
	var enemy = _rig.spawn_enemy(null, Vector2(reach / 2.0, 0.0))
	_rig.place_target(Vector2(0.0, 5.0 * enemy.tuning.notice_range))
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap_jump_and_wait_until_down()

	assert_almost_eq(_landing().x - _takeoff().x, reach, POSITION_TOLERANCE, "he should pass over the enemy")


# The Stamina

func test_a_jump_costs_the_tuned_stamina_once_at_its_start() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _almos.stamina.current

	await _tap_jump_and_wait_until_down()

	var airborne := _samples.filter(func(sample: Dictionary) -> bool: return sample.airborne)
	var expected := before - _tuning().jump_stamina_cost
	assert_almost_eq(airborne[0].stamina, expected, STAMINA_TOLERANCE, "it should be spent as the Jump begins")
	assert_almost_eq(airborne.back().stamina, expected, STAMINA_TOLERANCE, "nothing more should be spent in the air")


func test_a_press_he_cannot_pay_for_is_no_jump() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	_almos.stamina.spend(_tuning().stamina_maximum)
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)

	assert_false(_any_sample("airborne") or _almos.airborne, "he should not leave the ground")


func test_a_jump_that_costs_nothing_works_at_zero_stamina() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE, "jump_stamina_cost": 0.0}))
	_almos.stamina.spend(_tuning().stamina_maximum)
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.airborne, "he should be in the air")


# What he cannot do in the air

func test_a_roll_tap_in_the_air_is_lost() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")

	await _tap(&"roll")
	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("rolling"), "he should not Roll, in the air or after")
	assert_almost_eq(_almos.stamina.current, _tuning().stamina_maximum - _tuning().jump_stamina_cost, STAMINA_TOLERANCE, "only the Jump should have been paid for")


func test_attack_presses_in_the_air_are_lost(params = use_parameters(attack_button_params)) -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")

	await _tap(params.action)
	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("attacking") or _any_sample("charging"), "%s should do nothing in the air or after" % params.action)


func test_a_parry_press_in_the_air_is_lost() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")

	await _tap(&"parry")
	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("parrying"), "he should not Parry, in the air or after")


func test_he_does_not_block_in_the_air_but_blocks_again_once_down() -> void:
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.blocking, "he should be blocking before the Jump")

	await _tap_jump_and_wait_until_down()
	await wait_physics_frames(SETTLE_FRAMES)

	var airborne := _samples.filter(func(sample: Dictionary) -> bool: return sample.airborne)
	assert_false(airborne.any(func(sample: Dictionary) -> bool: return sample.blocking), "he should not block in the air")
	assert_true(_almos.blocking, "he should block again once down, the button still held")


func test_a_hit_lands_on_him_in_the_air() -> void:
	_spawn_almos(Vector2.ZERO)
	var hitbox := _hits.hitbox_from(_almos, Vector2.RIGHT * AlmosHits.HIT_DISTANCE)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")
	assert_false(_almos.untouchable, "the Jump should give no invulnerability")
	var before: float = _almos.health.current

	await _hits.swing(hitbox, 1)

	assert_almost_eq(_almos.health.current, before - AlmosHits.HIT_DAMAGE, HEALTH_TOLERANCE, "the hit should land in full")


# What he cannot start a Jump in

func test_a_jump_press_during_a_roll_is_lost() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"roll")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.rolling, "he should be rolling")

	await _tap(&"jump")
	await _wait_until_free(func() -> bool: return _almos.rolling)
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("airborne"), "the press should be lost, not kept for after the Roll")


func test_a_jump_press_during_a_light_attack_is_lost() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"attack_light")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.attacking, "he should be attacking")

	await _tap(&"jump")
	await _wait_until_free(func() -> bool: return _almos.attacking)
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("airborne"), "the press should be lost, not kept for after the attack")


func test_a_jump_press_while_charging_a_heavy_attack_is_lost() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.charging, "he should be charging")

	await _tap(&"jump")
	_almos_input.release_action(&"attack_heavy")
	await _wait_until_free(func() -> bool: return _almos.attacking or _almos.charging)
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("airborne"), "the press should be lost, not kept for after the attack")


func test_a_jump_press_during_a_parry_is_lost() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"parry")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.parrying, "he should be parrying")

	await _tap(&"jump")
	await _wait_until_free(func() -> bool: return _almos.parrying)
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("airborne"), "the press should be lost, not kept for after the Parry")


func test_a_jump_press_during_a_guard_break_is_lost() -> void:
	# A Jump that costs nothing, so that it is the Guard break that stops it, not an empty bar.
	var tuning := _tuning_with({"jump_stamina_cost": 0.0})
	_spawn_almos(Vector2.ZERO, tuning)
	_almos.stamina.spend(tuning.stamina_maximum - tuning.block_stamina_cost / 3.0)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * AlmosHits.HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	await _hits.swing(hitbox, 1)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.guard_broken, "he should be in a Guard break")

	await _tap(&"jump")
	await _wait_until_free(func() -> bool: return _almos.guard_broken)
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("airborne"), "the press should be lost, not kept for after the Guard break")


# The look

func test_a_shadow_stays_at_his_feet_while_his_placeholder_rises_and_falls() -> void:
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	var shadow := _almos.get_node("Shadow") as Node2D
	var placeholder := _almos.get_node("Placeholder") as Node2D
	assert_false(shadow.visible, "there should be no shadow on the ground")
	var rises: Array[float] = []
	var shadow_offsets: Array[Vector2] = []
	get_tree().physics_frame.connect(func() -> void:
		if is_instance_valid(_almos) and _almos.airborne:
			rises.append(-placeholder.position.y)
			shadow_offsets.append(shadow.global_position - _almos.global_position))

	await _tap_jump_and_wait_until_down()

	assert_gte(rises.max(), _tuning().jump_height * (1.0 - PEAK_ALLOWANCE), "his placeholder should rise to the tuned height")
	assert_lte(rises.max(), _tuning().jump_height + POSITION_TOLERANCE, "and no higher")
	assert_true(shadow_offsets.all(func(offset: Vector2) -> bool: return offset.is_zero_approx()), "the shadow should stay at his feet")
	assert_almost_eq(placeholder.position, Vector2.ZERO, Vector2.ONE * POSITION_TOLERANCE, "his placeholder should be back down")
	assert_false(shadow.visible, "the shadow should be gone once he is down")


# The test room

func test_the_test_room_has_a_gap_and_a_low_ledge_clear_of_the_enemy() -> void:
	var room := (load("res://scenes/test_room.tscn") as PackedScene).instantiate()
	add_child_autofree(room)
	var footprints := room.find_children("*", "Footprint", true, false)
	var gaps := footprints.filter(func(footprint: Footprint) -> bool: return footprint.collision_layer == _rig.layer_bit("gap_edge"))
	var ledges := footprints.filter(func(footprint: Footprint) -> bool: return footprint.collision_layer == _rig.layer_bit("ledge_edge"))
	assert_eq(gaps.size(), 1, "the room should have a gap")
	assert_eq(ledges.size(), 1, "the room should have a low ledge")
	var enemy_position: Vector2 = room.find_child("TrainingEnemy", true, false).position
	for footprint in footprints:
		var near := Rect2(footprint.position - footprint.size / 2.0, footprint.size).grow(_body_radius())
		assert_false(near.has_point(enemy_position), "the enemy should not stand at the %s" % footprint.name)


# Helpers

# A gap of this width, centred on x = 0.
func _spawn_gap(width: float) -> Node2D:
	return _spawn_world(GAP_SCENE_PATH, width)


# A low ledge of this width, centred on x = 0.
func _spawn_ledge(width: float) -> Node2D:
	return _spawn_world(LEDGE_SCENE_PATH, width)


func _spawn_world(scene_path: String, width: float) -> Node2D:
	var scene := load(scene_path) as PackedScene
	assert_not_null(scene, "the scene %s should load" % scene_path)
	var world = scene.instantiate()
	world.size = Vector2(width, WORLD_HEIGHT)
	add_child_autofree(world)
	return world


func _far_edge_of(world: Node2D) -> float:
	return world.position.x + world.size.x / 2.0


# Almos run up to the left edge of this gap or ledge, pushing right (and with the Roll button
# if the test has pressed it), and standing against it.
func _stand_against_the_left_edge_of(world: Node2D) -> void:
	var left_edge: float = world.position.x - world.size.x / 2.0
	_spawn_almos(Vector2(left_edge - _body_radius() - RUN_UP, world.position.y))
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(RUN_UP_FRAMES)


# Taps Jump while pushing this direction, and waits until he is down.
func _jump_while_pushing(direction: StringName) -> void:
	_almos_input.press_action(direction)
	await _tap_jump_and_wait_until_down()


func _tap_jump_and_wait_until_down() -> void:
	await _tap(&"jump")
	await _wait_until_down()


# Presses the action and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _wait_until_down() -> void:
	await wait_until(func() -> bool: return _almos.airborne, WAIT_LIMIT, "he should take off")
	await wait_while(func() -> bool: return _almos.airborne, WAIT_LIMIT)


# Waits for something that holds him to be over, such as an attack.
func _wait_until_free(still_held: Callable) -> void:
	await wait_while(still_held, WAIT_LIMIT)


# Where he was at the start of the frame he took off in: the sample before the first to show
# him in the air.
func _takeoff() -> Vector2:
	var first := _first_sample_where("airborne")
	assert_gt(first, 0, "he should have taken off")
	return _samples[first - 1].position


# Where he came down: his position in the first sample to show him down again after a Jump.
func _landing() -> Vector2:
	var first := _first_sample_where("airborne")
	for i in range(first, _samples.size()):
		if not _samples[i].airborne:
			return _samples[i].position
	fail_test("he should have come down")
	return Vector2.ZERO


func _first_sample_where(state: String) -> int:
	for i in _samples.size():
		if _samples[i][state]:
			return i
	return -1


func _any_sample(state: String) -> bool:
	return _first_sample_where(state) != -1


# How many physics frames he spent in the air. The frame he took off in is the first of them,
# and no sample shows him in the air until the one after it.
func _frames_in_the_air() -> int:
	return _samples.filter(func(sample: Dictionary) -> bool: return sample.airborne).size() + 1


func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


# Almos with this tuning, standing here, and sampled from now on. He is put in place before he
# enters the tree: moved after, he would still count as standing where he entered for the
# first physics frame, and anything solid that overlaps that spot would push him away from it.
func _spawn_almos(at: Vector2, tuning: PlayerTuning = null) -> Node2D:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	_almos = scene.instantiate()
	_almos.position = at
	if tuning != null:
		_almos.tuning = tuning
	add_child_autofree(_almos)
	_samples.clear()
	get_tree().physics_frame.connect(_take_sample)
	return _almos


# Taken at the start of each physics frame, before anything has moved in it, so it shows how
# that frame's predecessor left things.
func _take_sample() -> void:
	if not is_instance_valid(_almos):
		return
	_samples.append({
		"position": _almos.position,
		"airborne": _almos.airborne,
		"rolling": _almos.rolling,
		"blocking": _almos.blocking,
		"parrying": _almos.parrying,
		"attacking": _almos.attacking,
		"charging": _almos.charging,
		"sprinting": _almos.sprinting,
		"stamina": _almos.stamina.current,
	})


func _stop_sampling() -> void:
	if get_tree().physics_frame.is_connected(_take_sample):
		get_tree().physics_frame.disconnect(_take_sample)


# A stand-in enemy to lock on to, this far from Almos. The test frees it.
func _stand_in_enemy_at(offset: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.position = _almos.position + offset
	enemy.add_to_group(&"enemies")
	add_child_autofree(enemy)
	return enemy


# The radius of his body's circle, read off the scene.
func _body_radius() -> float:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	var almos := scene.instantiate()
	var radius := ((almos.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	almos.free()
	return radius


func _tuning() -> PlayerTuning:
	var tuning := load(AlmosInput.TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	return tuning


# The tuning data file's numbers, with these properties changed, for a test that needs a case
# the shipped numbers do not give. Nothing is shared with the data file.
func _tuning_with(changes: Dictionary) -> PlayerTuning:
	var tuning := _tuning().duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as PlayerTuning
	for property in changes:
		tuning.set(property, changes[property])
	return tuning
