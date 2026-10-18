extends GutTest
## Almos blocking, seen only through the scene: input goes in as actions or real input
## events, and a Hitbox made here stands in for an attacker, with its origin placed in front
## of him or behind him and a strike wide enough to cover him (the real training enemy is
## used once, to see a real strike come from where the enemy stands). Every physics frame a
## sample of Almos is taken, so what happened can be read back frame by frame. Expected numbers
## come from the tuning data file the scene uses (or a copy a test changes) and plain
## arithmetic, never from how the code works them out.
##
## A sample is taken at the start of each physics frame, before anything has moved in it, so
## it shows how its predecessor left things.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
const HIT_DAMAGE := AlmosHits.HIT_DAMAGE
const HIT_DISTANCE := AlmosHits.HIT_DISTANCE
# In degrees. How far inside or beyond the edge of the front a hit is put, to be clearly on one
# side of it.
const EDGE_MARGIN_DEGREES := 10.0
# In pixels per second.
const VELOCITY_TOLERANCE := 0.01
const FACING_TOLERANCE := AlmosInput.FACING_TOLERANCE
const MEASURED_FRAMES := AlmosInput.MEASURED_FRAMES
# A tap: held this many physics frames, far shorter than any sensible hold threshold.
const TAP_FRAMES := 3
# In pixels. How far from the enemy he stands when he circles it.
const CIRCLING_RADIUS := 100.0
# In radians. For the angle he goes round a target by.
const ANGLE_TOLERANCE := 0.001
# A refill pause short enough that the tests do not spend long waiting it out.
const SHORT_REFILL_PAUSE := 0.3
# How far, in seconds, either side of the end of the refill pause a test looks.
const REFILL_MARGIN := 0.05
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0
# How many physics frames a test holds the Heavy attack button for when the amount does not
# matter, short of a full charge.
const SOME_CHARGE_FRAMES := 20
# In pixels. How far from Almos the training enemy stands: close enough to reach him with a
# swing and clear of his body. He starts out facing down.
const ENEMY_DISTANCE := 30.0
# How many physics frames a test lets the training enemy's first strike play out for, after
# its wind-up and its active frames.
const STRIKE_SETTLE_FRAMES := 10
# How long, as a multiple of the hold threshold, a test holds the Roll button for to make
# it a hold and not a tap.
const HOLD_THRESHOLD_MULTIPLE := 1.5
# In radians. For the angle the Block placeholder is turned by.
const BLOCK_PLACEHOLDER_ANGLE_TOLERANCE := 0.0001
# A refill pause longer than any wait in these tests, for tests that need Stamina to stay
# where it was left.
const LONG_REFILL_PAUSE := 10.0
# How many physics frames a swing stays on when it is to overlap him for many of them.
const LONG_SWING_FRAMES := 10

var block_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the left Shift key", func(input: AlmosInput): input.press_key(KEY_SHIFT, false, KEY_LOCATION_LEFT)],
		["the right Shift key", func(input: AlmosInput): input.press_key(KEY_SHIFT, false, KEY_LOCATION_RIGHT)],
		["the L key", func(input: AlmosInput): input.press_key(KEY_L)],
		["the left shoulder button of a pad", func(input: AlmosInput): input.press_joypad_button(JOY_BUTTON_LEFT_SHOULDER)],
	],
)

# How wide the front Block covers is tuned, which side of his facing a hit comes from (1 is
# clockwise on the screen, -1 the other way), how many degrees inside the edge of the front
# or beyond it the hit comes from, and whether it is then blocked. The edge is half the arc
# from his facing.
var arc_edge_params = ParameterFactory.named_parameters(
	["arc", "side", "from_the_edge", "blocked"],
	[
		[90.0, 1.0, -EDGE_MARGIN_DEGREES, true],
		[90.0, 1.0, EDGE_MARGIN_DEGREES, false],
		[90.0, -1.0, -EDGE_MARGIN_DEGREES, true],
		[90.0, -1.0, EDGE_MARGIN_DEGREES, false],
		[180.0, 1.0, -EDGE_MARGIN_DEGREES, true],
		[180.0, 1.0, EDGE_MARGIN_DEGREES, false],
		[180.0, -1.0, -EDGE_MARGIN_DEGREES, true],
		[180.0, -1.0, EDGE_MARGIN_DEGREES, false],
		[300.0, 1.0, -EDGE_MARGIN_DEGREES, true],
		[300.0, 1.0, EDGE_MARGIN_DEGREES, false],
		[300.0, -1.0, -EDGE_MARGIN_DEGREES, true],
		[300.0, -1.0, EDGE_MARGIN_DEGREES, false],
	],
)

# Where a hit comes from, as a direction on the screen, when he is facing up and to the left,
# and whether it is blocked. With the arc a half turn, the front is everything within a
# quarter turn either side of the way he faces.
var diagonal_facing_params = ParameterFactory.named_parameters(
	["name", "from", "blocked"],
	[
		["straight ahead", Vector2(-1.0, -1.0), true],
		["from the left, an eighth of a turn round", Vector2.LEFT, true],
		["from above, an eighth of a turn round", Vector2.UP, true],
		["from below, three eighths of a turn round", Vector2.DOWN, false],
		["from the right, three eighths of a turn round", Vector2.RIGHT, false],
		["straight behind", Vector2(1.0, 1.0), false],
	],
)

# Where the training enemy stands from Almos, who starts out facing down, and whether its
# strike is then blocked.
var enemy_side_params = ParameterFactory.named_parameters(
	["name", "side", "blocked"],
	[
		["in front of him", Vector2.DOWN, true],
		["behind him", Vector2.UP, false],
	],
)

## Something to lock on to: it is in the enemies group.
class StandInEnemy:
	extends Node2D

	func _init() -> void:
		add_to_group(&"enemies")


var _almos_input: AlmosInput
var _enemy_rig: EnemyRig
var _hits: AlmosHits
var _almos: Node2D
var _samples: Array[Dictionary] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_enemy_rig = EnemyRig.new(self)
	_hits = AlmosHits.new(self)


func after_each() -> void:
	_stop_sampling()
	_enemy_rig.stop_sampling()
	_almos_input.release_everything()


# --- The tuning and the button ---

func test_the_block_numbers_are_tuned_so_that_a_blocked_hit_is_reduced_not_negated() -> void:
	var tuning := _tuning()

	assert_gt(tuning.block_damage_reduction, 0.0, "block_damage_reduction in the data file should take something off a blocked hit")
	assert_lt(tuning.block_damage_reduction, 1.0, "block_damage_reduction in the data file should leave something of a blocked hit, or Block would negate it")
	assert_gt(tuning.block_stamina_cost, 0.0, "block_stamina_cost in the data file should be positive")
	assert_gt(tuning.block_arc_degrees, 0.0, "block_arc_degrees in the data file should be positive")
	assert_lte(tuning.block_arc_degrees, 360.0, "block_arc_degrees in the data file should be at most a full turn")
	assert_gt(tuning.block_walk_speed, 0.0, "block_walk_speed in the data file should be positive")
	assert_lte(tuning.block_walk_speed, tuning.walk_speed, "block_walk_speed in the data file should be no faster than walking")
	assert_gte(tuning.block_stamina_refill_factor, 0.0, "block_stamina_refill_factor in the data file should not be negative")
	assert_lt(tuning.block_stamina_refill_factor, 1.0, "block_stamina_refill_factor in the data file should slow the refill")


func test_holding_the_block_action_starts_blocking_and_letting_go_stops_it() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(_almos.blocking, "he should not be blocking before the button is held")

	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.blocking, "he should be blocking while the button is held")

	_almos_input.release_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(_almos.blocking, "he should stop blocking when the button is let go")


func test_the_block_button_can_be_either_shift_key_the_l_key_or_a_pad_shoulder_button(params = use_parameters(block_binding_params)) -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)

	params.press.call(_almos_input)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.blocking, "%s should start him blocking" % params.name)


# --- A hit while blocking ---

func test_a_hit_from_the_front_while_blocking_deals_the_rest_of_its_damage_and_costs_stamina() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	var expected_damage := HIT_DAMAGE * (1.0 - tuning.block_damage_reduction)
	assert_almost_eq(_almos.health.current, tuning.health_maximum - expected_damage, HEALTH_TOLERANCE, "the damage that got through")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum - tuning.block_stamina_cost, STAMINA_TOLERANCE, "the Stamina the blocked hit cost")


func test_a_hit_from_behind_while_blocking_deals_full_damage_and_costs_no_stamina() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hits.hitbox_from(_almos, -_almos.facing * HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum, STAMINA_TOLERANCE, "nothing should be spent")


func test_a_hit_from_the_front_without_the_block_button_held_deals_full_damage_and_costs_no_stamina() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum, STAMINA_TOLERANCE, "nothing should be spent")


func test_blocking_with_no_stamina_left_gives_no_protection() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	assert_true(_almos.blocking, "he is still blocking, it just gives no protection")
	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_a_blocked_hit_with_less_stamina_left_than_it_costs_is_still_blocked_and_empties_it() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum - tuning.block_stamina_cost / 3.0)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE * (1.0 - tuning.block_damage_reduction), HEALTH_TOLERANCE, "the hit should still be blocked")
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE)


func test_the_front_that_block_covers_is_as_wide_as_the_tuned_arc_centred_on_his_facing(params = use_parameters(arc_edge_params)) -> void:
	var tuning := _tuning_with({"block_arc_degrees": params.arc, "stamina_refill_pause": LONG_REFILL_PAUSE})
	_spawn_almos(tuning)
	var degrees_round: float = params.side * (params.arc / 2.0 + params.from_the_edge)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing.rotated(deg_to_rad(degrees_round)) * HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	var expected_damage := HIT_DAMAGE * (1.0 - tuning.block_damage_reduction) if params.blocked else HIT_DAMAGE
	var expected_spent := tuning.block_stamina_cost if params.blocked else 0.0
	assert_almost_eq(_almos.health.current, tuning.health_maximum - expected_damage, HEALTH_TOLERANCE, "the damage that got through")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum - expected_spent, STAMINA_TOLERANCE, "the Stamina the hit cost")


func test_the_front_follows_the_way_he_faces_not_the_way_he_started(params = use_parameters(diagonal_facing_params)) -> void:
	var tuning := _tuning_with({"block_arc_degrees": 180.0, "stamina_refill_pause": LONG_REFILL_PAUSE})
	_spawn_almos(tuning)
	_almos_input.press_action(&"move_up")
	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.release_action(&"move_up")
	_almos_input.release_action(&"move_left")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(_almos.facing, Vector2(-1.0, -1.0).normalized(), Vector2.ONE * AlmosInput.FACING_TOLERANCE, "he should be facing up and to the left")
	var hitbox := _hits.hitbox_from(_almos, (params.from as Vector2).normalized() * HIT_DISTANCE)
	await wait_physics_frames(SETTLE_FRAMES)
	var before: float = _almos.stamina.current

	await _hits.swing(hitbox, 1)

	var expected_damage := HIT_DAMAGE * (1.0 - tuning.block_damage_reduction) if params.blocked else HIT_DAMAGE
	var expected_spent := tuning.block_stamina_cost if params.blocked else 0.0
	assert_almost_eq(_almos.health.current, tuning.health_maximum - expected_damage, HEALTH_TOLERANCE, "%s: the damage that got through" % params.name)
	assert_almost_eq(_almos.stamina.current, before - expected_spent, STAMINA_TOLERANCE, "%s: the Stamina the hit cost" % params.name)


func test_a_hit_from_exactly_his_own_centre_counts_as_from_the_front() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hits.hitbox_from(_almos, Vector2.ZERO)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE * (1.0 - tuning.block_damage_reduction), HEALTH_TOLERANCE, "the hit should be blocked")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum - tuning.block_stamina_cost, STAMINA_TOLERANCE)


func test_one_swing_over_him_is_blocked_once_however_many_frames_it_overlaps_him() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, LONG_SWING_FRAMES)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE * (1.0 - tuning.block_damage_reduction), HEALTH_TOLERANCE, "the damage should get through once")
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum - tuning.block_stamina_cost, STAMINA_TOLERANCE, "the Stamina should be spent once")


func test_a_training_enemy_hitting_him_is_blocked_only_from_the_front(params = use_parameters(enemy_side_params)) -> void:
	var tuning := _tuning_with_long_refill_pause()
	var attack := (load(EnemyRig.TUNING_PATH) as EnemyTuning).attack
	_spawn_almos(tuning)
	_enemy_rig.spawn_enemy(null, _almos.position + (params.side as Vector2) * ENEMY_DISTANCE)
	_enemy_rig.set_target(_almos, _almos.health)
	_almos_input.press_action(&"block")

	await _enemy_rig.wait_frames(attack.startup_frames + attack.active_frames + STRIKE_SETTLE_FRAMES)

	var expected_damage := attack.damage * (1.0 - tuning.block_damage_reduction) if params.blocked else attack.damage
	var expected_spent := tuning.block_stamina_cost if params.blocked else 0.0
	assert_almost_eq(_almos.health.current, tuning.health_maximum - expected_damage, HEALTH_TOLERANCE, "the damage that got through with the enemy %s" % params.name)
	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum - expected_spent, STAMINA_TOLERANCE, "the Stamina it cost with the enemy %s" % params.name)


# --- Moving while blocking ---

func test_walking_while_blocking_is_at_the_tuned_block_walk_speed() -> void:
	var tuning := _tuning()
	assert_gt(tuning.block_walk_speed, 0.0, "block_walk_speed in the data file should be positive")
	_spawn_almos()
	_almos_input.press_action(&"block")
	_almos_input.press_action(&"move_right")

	var velocity: Vector2 = await _measured_velocity()

	assert_true(_almos.blocking, "he should still be blocking")
	assert_almost_eq(velocity, Vector2(tuning.block_walk_speed, 0.0), Vector2.ONE * VELOCITY_TOLERANCE)


func test_walking_while_blocking_turns_him_to_the_nearest_of_eight_directions_as_usual() -> void:
	_spawn_almos()
	_almos_input.press_action(&"block")
	# Between right and down-right, nearer down-right.
	_almos_input.push_left_stick(Vector2.from_angle(deg_to_rad(40.0)))

	var velocity: Vector2 = await _measured_velocity()

	assert_almost_eq(_almos.facing, Vector2.from_angle(deg_to_rad(45.0)), Vector2.ONE * FACING_TOLERANCE)
	assert_almost_eq(velocity.length(), _tuning().block_walk_speed, VELOCITY_TOLERANCE, "diagonal speed should equal block_walk_speed")


func test_circling_a_target_while_blocking_goes_round_at_the_tuned_block_walk_speed() -> void:
	_spawn_almos()
	var enemy := StandInEnemy.new()
	enemy.position = _almos.position + Vector2.RIGHT * CIRCLING_RADIUS
	add_child_autofree(enemy)
	_almos_input.press_action(&"lock_on")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"lock_on")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should have locked on to the enemy")
	_almos_input.press_action(&"block")
	# Across the line to the enemy, which is to his right.
	_almos_input.press_action(&"move_down")
	await wait_physics_frames(SETTLE_FRAMES)
	var start_position: Vector2 = _almos.position
	var start_frame := Engine.get_physics_frames()

	await wait_physics_frames(MEASURED_FRAMES)

	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	var swept := absf((start_position - enemy.position).angle_to(_almos.position - enemy.position))
	assert_almost_eq(swept, _tuning().block_walk_speed * seconds / CIRCLING_RADIUS, ANGLE_TOLERANCE, "the angle he went round the enemy by")


func test_holding_the_roll_button_and_a_direction_while_blocking_does_not_sprint_and_spends_nothing() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	# Some Stamina gone, so that a Sprint's cost would show.
	_almos.stamina.spend(tuning.stamina_maximum / 2.0)
	var before: float = _almos.stamina.current
	_almos_input.press_action(&"block")
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(_frames_to_reach(tuning.roll_hold_threshold) + SETTLE_FRAMES)

	var velocity: Vector2 = await _measured_velocity()

	for i in _samples.size():
		assert_false(_samples[i].sprinting, "he should not be sprinting in sample %d" % i)
	assert_almost_eq(velocity, Vector2(tuning.block_walk_speed, 0.0), Vector2.ONE * VELOCITY_TOLERANCE, "he should walk at block_walk_speed")
	assert_almost_eq(_almos.stamina.current, before, STAMINA_TOLERANCE, "nothing should be spent")


func test_letting_go_of_a_roll_button_held_for_a_hold_while_blocking_does_not_roll() -> void:
	var tuning := _tuning()
	_spawn_almos()
	_almos_input.press_action(&"block")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(_frames_to_reach(tuning.roll_hold_threshold * HOLD_THRESHOLD_MULTIPLE))

	_almos_input.release_action(&"roll")
	await wait_physics_frames(SETTLE_FRAMES + MEASURED_FRAMES)

	assert_eq(_span("rolling").x, -1, "he should not have rolled")
	assert_true(_almos.blocking, "he should still be blocking")


func test_pressing_block_in_a_sprint_does_not_end_it_and_he_starts_blocking_once_it_has_ended() -> void:
	_spawn_almos(_tuning_with_long_refill_pause())
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _wait_until(func(): return _almos.sprinting, "he should start sprinting")

	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES + MEASURED_FRAMES)
	assert_true(_almos.sprinting, "the Sprint should go on")
	assert_false(_almos.blocking, "he should not be blocking in a Sprint")

	_almos_input.release_action(&"roll")
	await _wait_until(func(): return not _almos.sprinting, "the Sprint should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("sprinting")
	for i in range(span.x, span.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the Sprint" % i)
	assert_true(_almos.blocking, "he should start blocking once the Sprint is over")


# --- Stamina while blocking ---

func test_stamina_refills_at_the_tuned_fraction_of_its_usual_rate_while_blocking() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": SHORT_REFILL_PAUSE})
	assert_lt(tuning.block_stamina_refill_factor, 1.0, "block_stamina_refill_factor in the data file should slow the refill")
	_spawn_almos(tuning)
	# Far enough down that the refill does not reach the top within the test.
	_almos.stamina.spend(tuning.stamina_maximum / 2.0)
	_almos_input.press_action(&"block")
	await wait_physics_frames(_frames_to_reach(tuning.stamina_refill_pause + REFILL_MARGIN) + SETTLE_FRAMES)

	var refill := await _stamina_refill_over_measured_frames()

	assert_almost_eq(refill.refilled, tuning.stamina_refill_rate * tuning.block_stamina_refill_factor * refill.seconds, STAMINA_TOLERANCE)


func test_stamina_refills_at_its_usual_rate_when_he_is_not_blocking() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": SHORT_REFILL_PAUSE})
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum / 2.0)
	await wait_physics_frames(_frames_to_reach(tuning.stamina_refill_pause + REFILL_MARGIN) + SETTLE_FRAMES)

	var refill := await _stamina_refill_over_measured_frames()

	assert_almost_eq(refill.refilled, tuning.stamina_refill_rate * refill.seconds, STAMINA_TOLERANCE)


func test_blocking_does_not_lengthen_the_refill_pause() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": SHORT_REFILL_PAUSE})
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum / 2.0)
	var level: float = _almos.stamina.current
	_almos_input.press_action(&"block")

	await wait_physics_frames(_frames_to_reach(tuning.stamina_refill_pause - REFILL_MARGIN))
	assert_almost_eq(_almos.stamina.current, level, STAMINA_TOLERANCE, "nothing should come back during the pause")

	await wait_physics_frames(_frames_to_reach(2.0 * REFILL_MARGIN) + SETTLE_FRAMES)
	assert_gt(_almos.stamina.current, level, "it should have started to come back by the time the pause is over")


# --- Rolls and attacks from Block ---

func test_tapping_roll_while_blocking_rolls_without_blocking_and_starts_blocking_again_after() -> void:
	var tuning := _tuning_with_long_refill_pause()
	_spawn_almos(tuning)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap(&"roll")
	await _wait_until(func(): return _span("rolling").y != -1, "the roll should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("rolling")
	assert_ne(span.x, -1, "he should have rolled")
	assert_almost_eq(_samples[span.y - 1].stamina, tuning.stamina_maximum - tuning.roll_stamina_cost, STAMINA_TOLERANCE, "the roll should have been paid for")
	for i in range(span.x, span.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the roll" % i)
	assert_true(_samples[span.y].blocking, "he should be blocking again in the first sample after the roll")


func test_a_light_attack_press_while_blocking_swings_without_blocking_and_starts_blocking_again_after() -> void:
	_spawn_almos()
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap(&"attack_light")
	await _wait_until(func(): return _span("attacking").y != -1, "the swing should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("attacking")
	assert_ne(span.x, -1, "he should have swung")
	for i in range(span.x, span.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the swing" % i)
	assert_true(_samples[span.y].blocking, "he should be blocking again in the first sample after the swing")


func test_a_heavy_attack_press_while_blocking_charges_and_swings_without_blocking_and_starts_blocking_again_after() -> void:
	_spawn_almos()
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_until(func(): return _span("attacking").y != -1, "the swing should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var charge := _span("charging")
	var swing := _span("attacking")
	assert_ne(charge.x, -1, "he should have charged")
	assert_ne(swing.x, -1, "he should have swung")
	for i in range(charge.x, swing.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the charge or the swing" % i)
	assert_true(_samples[swing.y].blocking, "he should be blocking again in the first sample after the swing")


func test_block_pressed_in_a_roll_waits_for_the_roll_to_end() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"roll")
	await _wait_until(func(): return _almos.rolling, "he should start rolling")

	_almos_input.press_action(&"block")
	await _wait_until(func(): return _span("rolling").y != -1, "the roll should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("rolling")
	for i in range(span.x, span.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the roll" % i)
	assert_true(_samples[span.y].blocking, "he should start blocking in the first sample after the roll")


func test_block_pressed_in_a_swing_waits_for_the_swing_to_end() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"attack_light")
	assert_true(_almos.attacking, "he should still be swinging")

	_almos_input.press_action(&"block")
	await _wait_until(func(): return _span("attacking").y != -1, "the swing should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("attacking")
	for i in range(span.x, span.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the swing" % i)
	assert_true(_samples[span.y].blocking, "he should start blocking in the first sample after the swing")


func test_block_pressed_in_a_heavy_charge_waits_for_the_swing_that_follows_to_end() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.charging, "he should be charging")

	_almos_input.press_action(&"block")
	await wait_physics_frames(SOME_CHARGE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_until(func(): return _span("attacking").y != -1, "the swing should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var charge := _span("charging")
	var swing := _span("attacking")
	for i in range(charge.x, swing.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the charge or the swing" % i)
	assert_true(_samples[swing.y].blocking, "he should start blocking in the first sample after the swing")


# --- What is drawn while he blocks ---

func test_the_block_placeholder_shows_exactly_while_he_is_blocking() -> void:
	_spawn_almos()
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"roll")
	await _wait_until(func(): return _samples.back().rolling == false and _span("rolling").y != -1, "the roll should end")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"attack_light")
	await _wait_until(func(): return _samples.back().attacking == false and _span("attacking").y != -1, "the swing should end")
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.release_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_samples.any(func(sample: Dictionary) -> bool: return sample.blocking), "he should have blocked at some point")
	assert_true(_samples.any(func(sample: Dictionary) -> bool: return not sample.blocking), "he should have not been blocking at some point")
	for i in _samples.size():
		assert_eq(_samples[i].block_placeholder, _samples[i].blocking, "the Block placeholder and blocking in sample %d" % i)


func test_the_block_placeholder_turns_with_the_way_he_faces() -> void:
	_spawn_almos()
	_almos_input.press_action(&"block")
	_almos_input.press_action(&"move_up")
	_almos_input.press_action(&"move_left")
	await wait_physics_frames(SETTLE_FRAMES)

	var drawn := _almos.get_node("Placeholder/BlockPlaceholder") as Node2D
	assert_true(drawn.visible, "the Block placeholder should show")
	assert_almost_eq(Vector2.from_angle(drawn.global_rotation), _almos.facing, Vector2.ONE * BLOCK_PLACEHOLDER_ANGLE_TOLERANCE, "the way the Block placeholder points, against the way he faces")


func _spawn_almos(tuning: PlayerTuning = null) -> Node2D:
	_almos = _almos_input.spawn_almos(tuning)
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
		"blocking": _almos.blocking,
		"block_placeholder": _almos.get_node("Placeholder/BlockPlaceholder").visible,
		"rolling": _almos.rolling,
		"attacking": _almos.attacking,
		"charging": _almos.charging,
		"stamina": _almos.stamina.current,
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


# The tuning data file's numbers, but with a refill pause no test waits out.
func _tuning_with_long_refill_pause() -> PlayerTuning:
	return _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE})


# Almos's average velocity over a few physics frames, worked out from where he ends up
# rather than read from his velocity property. The elapsed frames come from the engine's
# own counter, because waiting for N frames can span N + 1 physics steps.
func _measured_velocity() -> Vector2:
	await wait_physics_frames(SETTLE_FRAMES)
	var start_position := _almos.position
	var start_frame := Engine.get_physics_frames()
	await wait_physics_frames(MEASURED_FRAMES)
	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	return (_almos.position - start_position) / seconds


# How many physics frames it takes to reach this many seconds.
func _frames_to_reach(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


# How much Stamina comes back over a few physics frames from now, as {"refilled": the amount,
# "seconds": how long it took}. The elapsed frames come from the engine's own counter,
# because waiting for N frames can span N + 1 physics steps.
func _stamina_refill_over_measured_frames() -> Dictionary:
	var before: float = _almos.stamina.current
	var start_frame := Engine.get_physics_frames()
	await wait_physics_frames(MEASURED_FRAMES)
	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	return {"refilled": _almos.stamina.current - before, "seconds": seconds}


# Presses the action and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Waits until this is true, for at most WAIT_LIMIT seconds of game time.
func _wait_until(condition: Callable, failure: String) -> void:
	var met: bool = await wait_until(condition, WAIT_LIMIT, failure)
	assert_true(met, failure)


# The first stretch of samples in which this is true, as Vector2i(first, end): the index of
# the first sample showing it and of the first showing it over. Either is -1 if it has not
# happened yet.
func _span(state: String) -> Vector2i:
	var first := -1
	for i in _samples.size():
		if first == -1 and _samples[i][state]:
			first = i
		elif first != -1 and not _samples[i][state]:
			return Vector2i(first, i)
	return Vector2i(first, -1)
