extends GutTest
## Almos's Guard break, seen only through the scene: input goes in as actions, and a Hitbox
## made here stands in for an attacker, with its origin placed in front of him or behind him
## and a strike wide enough to cover him. Every physics frame a sample of Almos is taken, so
## what happened can be read back frame by frame. Expected numbers come from the tuning data
## file the scene uses (or a copy a test changes) and plain arithmetic, never from how the code
## works them out.
##
## A sample is taken at the start of each physics frame, before anything has moved in it, so
## it shows how its predecessor left things. A hit lands while its Hitbox is processed, after
## Almos is, so the first sample to show a hit's effect on him is the one of the next frame.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const TrainingEnemy := preload("res://scenes/enemies/training_enemy.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
const HIT_DAMAGE := AlmosHits.HIT_DAMAGE
const HIT_DISTANCE := AlmosHits.HIT_DISTANCE
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# A refill pause longer than any wait in these tests, for tests that need Stamina to stay
# where it was left.
const LONG_REFILL_PAUSE := 10.0
# In Stamina points. Stamina left beyond what a blocked hit costs, so that the hit does not
# take the last of it.
const A_LITTLE_STAMINA := 1.0
# In seconds. A refill pause short enough that Stamina is back well within a Guard break.
const QUICK_REFILL_PAUSE := 0.1
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0
# In frames. Keeps a time that is a whole number of frames from being counted as one more.
const FRAME_COUNT_ALLOWANCE := 0.0001
# A tap: held this many physics frames, far shorter than any sensible hold threshold.
const TAP_FRAMES := 3
# How many physics frames into a Guard break a press or a tap that is "early in it" is made,
# after the Stamina has had time to come back and well before the end.
const EARLY_FRAMES := 12
# How many physics frames a test carries on past the end of a Guard break to see whether
# something kept from it comes out.
const PAST_THE_END_FRAMES := 10
# In pixels. How far from Almos a stand-in enemy is put to lock on to: well within the range of
# the lock.
const ENEMY_DISTANCE := 100.0
# In pixels. How far from Almos the training enemy stands: close enough to reach him with a
# swing and clear of his body. He starts out facing down.
const TRAINING_ENEMY_DISTANCE := 30.0
# How many physics frames a test lets the training enemy's first strike play out for, after
# its wind-up and its active frames.
const STRIKE_SETTLE_FRAMES := 10
# In pixels. How far past the range at which a lock breaks a target is put to lose it.
const FAR_BEYOND_THE_BREAK_RANGE := 50.0
# How different, as the sum of the differences in red, green and blue, what is drawn of him
# must be while a Guard break lasts for the player to see it.
const VISIBLE_DIFFERENCE := 0.5
# A refill pause short enough that the tests do not spend long waiting it out.
const SHORT_REFILL_PAUSE := 0.3
# How far, in seconds, either side of the end of the refill pause a test looks.
const REFILL_MARGIN := 0.05
# How many physics frames a refill is measured over.
const MEASURED_FRAMES := AlmosInput.MEASURED_FRAMES
# In pixels.
const POSITION_TOLERANCE := 0.001
# Facing is a unit vector, so it needs a much tighter tolerance than pixels or pixels per
# second.
const FACING_TOLERANCE := AlmosInput.FACING_TOLERANCE

# Guard break durations and how many physics frames each lasts at 60 frames per second. 0.2 s
# is a whole 12 frames, but twelve frame lengths added up fall a hair short of it, which would
# give the Guard break a spare frame. 0.27 s is not a whole number of frames.
var duration_params = ParameterFactory.named_parameters(
	["duration", "frames"],
	[[0.2, 12], [0.27, 17]],
)

# What happens to the target of a Lock-on that was held when the Guard break began, within it.
var target_lost_params = ParameterFactory.named_parameters(
	["name", "lose"],
	[
		["gets too far away", func(enemy: Node2D, almos: Node2D, tuning: PlayerTuning) -> void: enemy.global_position = almos.global_position + Vector2.DOWN * (tuning.lock_on_break_range + FAR_BEYOND_THE_BREAK_RANGE)],
		["is gone", func(enemy: Node2D, _almos_node: Node2D, _the_tuning: PlayerTuning) -> void: enemy.free()],
		["announces its death", func(enemy: Node2D, _almos_node: Node2D, _the_tuning: PlayerTuning) -> void: enemy.died.emit()],
	],
)

# How much Stamina he has left when a blocked hit lands, as a fraction of what a blocked hit
# costs: less than the cost, and exactly the cost. Either way the hit takes the last of it.
var last_stamina_params = ParameterFactory.named_parameters(
	["name", "left_as_fraction_of_cost"],
	[["less than the cost", 1.0 / 3.0], ["exactly the cost", 1.0]],
)

# When a press or tap is made in a Guard break, and whether it is held on past the end of it.
# "Early" is EARLY_FRAMES in, "late" is read in the last frame of the break.
var press_params = ParameterFactory.named_parameters(
	["name", "action", "late", "held_on"],
	[
		["a Light attack press early in the break", &"attack_light", false, false],
		["a Light attack press in the last frame of the break", &"attack_light", true, false],
		["a Heavy attack press early in the break", &"attack_heavy", false, false],
		["a Heavy attack press in the last frame of the break", &"attack_heavy", true, false],
		["a Heavy attack press in the last frame of the break, held on past it", &"attack_heavy", true, true],
	],
)

# When a Roll tap is made in a Guard break: "early" is released EARLY_FRAMES in, "late" is
# released in the last frame of the break, where a tap kept for the end would be taken up.
var tap_params = ParameterFactory.named_parameters(
	["name", "late"],
	[["a Roll tap early in the break", false], ["a Roll tap read in the last frame of the break", true]],
)

## Something to lock on to: it is in the enemies group and announces its death.
class StandInEnemy:
	extends Node2D
	signal died

	func _init() -> void:
		add_to_group(&"enemies")


var _almos_input: AlmosInput
var _enemy_rig: EnemyRig
var _hits: AlmosHits
var _almos: Node2D
var _samples: Array[Dictionary] = []
# The Hitbox that began the Guard break and the index of the first sample to show it, as set by
# _break_the_guard.
var _hitbox: Hitbox
var _first_broken := -1


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


# --- The tuning ---

func test_the_guard_break_duration_is_tuned_to_a_time_he_is_left_open_for() -> void:
	var tuning := _tuning()

	assert_gt(tuning.guard_break_duration, 0.0, "guard_break_duration in the data file should be positive")


# --- How long it lasts ---

func test_a_guard_break_lasts_until_the_first_whole_frame_at_or_after_its_duration(params = use_parameters(duration_params)) -> void:
	var tuning := _tuning_with({"guard_break_duration": params.duration, "stamina_refill_pause": LONG_REFILL_PAUSE})
	var hitbox: Hitbox = await _blocking_with_stamina_left(tuning, tuning.block_stamina_cost / 3.0)

	await _hits.swing(hitbox, 1)
	var first_sample_after_the_hit := _samples.size() - 1
	await wait_physics_frames(params.frames + SETTLE_FRAMES)

	var span := _span("guard_broken")
	assert_eq(span.x, first_sample_after_the_hit, "it should show from the first sample after the hit")
	assert_eq(span.y - span.x, params.frames, "frames it lasts")


# --- What breaks it ---

func test_a_blocked_hit_that_takes_the_last_stamina_starts_a_guard_break_and_deals_the_reduced_damage(params = use_parameters(last_stamina_params)) -> void:
	var tuning := _tuning_with_long_refill_pause()
	var hitbox: Hitbox = await _blocking_with_stamina_left(tuning, tuning.block_stamina_cost * params.left_as_fraction_of_cost)
	assert_false(_almos.guard_broken, "there should be no Guard break before the hit")

	await _hits.swing(hitbox, 1)

	assert_true(_samples.back().guard_broken, "the first sample after the hit should show the Guard break (%s)" % params.name)
	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE * (1.0 - tuning.block_damage_reduction), HEALTH_TOLERANCE, "the breaking hit was blocked, so it deals the reduced damage")
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE, "it took the last of the Stamina")


func test_a_blocked_hit_that_leaves_some_stamina_does_not_start_a_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	# Just a little more than the hit costs: it takes nearly all of it, but not the last.
	var hitbox: Hitbox = await _blocking_with_stamina_left(tuning, tuning.block_stamina_cost + A_LITTLE_STAMINA)

	await _hits.swing(hitbox, 1)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_almost_eq(_almos.stamina.current, A_LITTLE_STAMINA, STAMINA_TOLERANCE, "the hit should have cost what a blocked hit costs")
	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE * (1.0 - tuning.block_damage_reduction), HEALTH_TOLERANCE, "the hit should have been blocked")
	assert_false(_any_sample("guard_broken"), "there should be no Guard break")


func test_a_blocked_hit_at_full_stamina_does_not_start_a_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	var hitbox: Hitbox = await _blocking_with_stamina_left(tuning, tuning.stamina_maximum)

	await _hits.swing(hitbox, 1)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_almost_eq(_almos.stamina.current, tuning.stamina_maximum - tuning.block_stamina_cost, STAMINA_TOLERANCE, "the hit should have been blocked")
	assert_false(_any_sample("guard_broken"), "there should be no Guard break")


func test_a_hit_taken_blocking_with_no_stamina_left_deals_full_damage_and_starts_no_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	var hitbox: Hitbox = await _blocking_with_stamina_left(tuning, 0.0)

	await _hits.swing(hitbox, 1)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.blocking, "he is still blocking, it just gives no protection")
	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_false(_any_sample("guard_broken"), "there should be no Guard break")


func test_a_hit_from_behind_with_less_stamina_left_than_a_blocked_hit_costs_is_not_blocked_and_starts_no_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	var stamina_left := tuning.block_stamina_cost / 3.0
	var hitbox: Hitbox = await _blocking_with_stamina_left(tuning, stamina_left, true)

	await _hits.swing(hitbox, 1)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_almost_eq(_almos.stamina.current, stamina_left, STAMINA_TOLERANCE, "nothing should be spent")
	assert_false(_any_sample("guard_broken"), "there should be no Guard break")


func test_a_hit_taken_without_the_block_button_held_and_with_little_stamina_starts_no_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	var stamina_left := tuning.block_stamina_cost / 3.0
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum - stamina_left)
	var hitbox := _hits.hitbox_from(_almos, _almos.facing * HIT_DISTANCE)
	await wait_physics_frames(SETTLE_FRAMES)

	await _hits.swing(hitbox, 1)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_almost_eq(_almos.stamina.current, stamina_left, STAMINA_TOLERANCE, "nothing should be spent")
	assert_false(_any_sample("guard_broken"), "there should be no Guard break")


func test_a_training_enemys_strike_that_takes_the_last_stamina_starts_a_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	var attack := (load(EnemyRig.TUNING_PATH) as EnemyTuning).attack
	_spawn_almos_with_stamina_left(tuning, tuning.block_stamina_cost / 3.0)
	_enemy_rig.spawn_enemy(null, _almos.position + Vector2.DOWN * TRAINING_ENEMY_DISTANCE)
	_enemy_rig.set_target(_almos, _almos.health)
	_almos_input.press_action(&"block")

	await _enemy_rig.wait_frames(attack.startup_frames + attack.active_frames + STRIKE_SETTLE_FRAMES)

	assert_almost_eq(_almos.health.current, tuning.health_maximum - attack.damage * (1.0 - tuning.block_damage_reduction), HEALTH_TOLERANCE, "the strike was blocked, so it deals the reduced damage")
	assert_true(_almos.guard_broken, "the strike should have started a Guard break")
	assert_gte(_span("guard_broken").x, attack.startup_frames, "it should not begin before the strike is on")


# --- While it lasts ---

func test_holding_block_does_not_make_him_block_during_a_guard_break() -> void:
	await _break_the_guard(_tuning_with_quick_refill())

	await _wait_until(func(): return _span("guard_broken").y != -1, "the Guard break should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("guard_broken")
	for i in range(span.x, span.y):
		assert_false(_samples[i].blocking, "he should not be blocking in sample %d, in the Guard break" % i)
		assert_false(_samples[i].block_shape, "the Block shape should not show in sample %d, in the Guard break" % i)


func test_pushing_a_direction_moves_him_nowhere_and_does_not_turn_him_during_a_guard_break() -> void:
	await _break_the_guard(_tuning_with_quick_refill())
	var start_position: Vector2 = _almos.position
	var start_facing: Vector2 = _almos.facing
	# Not the way he faces, so that turning would show.
	_almos_input.press_action(&"move_right")

	await _wait_until(func(): return _span("guard_broken").y != -1, "the Guard break should end")

	var span := _span("guard_broken")
	for i in range(span.x, span.y):
		assert_almost_eq(_samples[i].position, start_position, Vector2.ONE * POSITION_TOLERANCE, "where he is in sample %d, in the Guard break" % i)
		assert_almost_eq(_samples[i].facing, start_facing, Vector2.ONE * FACING_TOLERANCE, "the way he faces in sample %d, in the Guard break" % i)


func test_a_roll_tap_during_a_guard_break_does_not_roll_and_is_not_kept_for_after_it(params = use_parameters(tap_params)) -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var last_frame := _first_broken + _break_frames(tuning) - 1
	var released_at := last_frame if params.late else _first_broken + EARLY_FRAMES

	await _until_sample(released_at - TAP_FRAMES)
	assert_gt(_almos.stamina.current, 0.0, "some Stamina should be back, so that it is the Guard break that stops the Roll")
	_almos_input.press_action(&"roll")
	await _until_sample(released_at)
	assert_true(_almos.guard_broken, "%s should be made in the Guard break" % params.name)
	_almos_input.release_action(&"roll")
	await _until_sample(last_frame + PAST_THE_END_FRAMES)

	assert_false(_any_sample("rolling"), "he should not roll")
	assert_true(_stamina_never_dropped(), "nothing should be spent")


func test_an_attack_press_during_a_guard_break_does_not_attack_and_is_not_kept_for_after_it(params = use_parameters(press_params)) -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var last_frame := _first_broken + _break_frames(tuning) - 1
	# A press is read as a press in the frame after the one it is made in, so it is made a
	# frame before the one it is to be read in.
	var read_in := last_frame if params.late else _first_broken + EARLY_FRAMES

	await _until_sample(read_in - 1)
	assert_true(_almos.guard_broken, "%s should be made in the Guard break" % params.name)
	assert_gt(_almos.stamina.current, 0.0, "some Stamina should be back, so that it is the Guard break that stops the attack")
	_almos_input.press_action(params.action)
	await _until_sample(read_in + TAP_FRAMES)
	if not params.held_on:
		_almos_input.release_action(params.action)
	await _until_sample(last_frame + PAST_THE_END_FRAMES)

	assert_false(_any_sample("attacking"), "he should not swing")
	assert_false(_any_sample("charging"), "he should not charge")
	assert_true(_stamina_never_dropped(), "nothing should be spent")


func test_holding_roll_and_pushing_a_direction_does_not_sprint_during_a_guard_break() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var start_position: Vector2 = _almos.position
	await _until_sample(_first_broken + EARLY_FRAMES)
	assert_gt(_almos.stamina.current, 0.0, "some Stamina should be back, so that it is the Guard break that stops the Sprint")
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")

	await _until_sample(_first_broken + EARLY_FRAMES + _frames_to_reach(tuning.roll_hold_threshold) + SETTLE_FRAMES)

	assert_true(_almos.guard_broken, "this should all be in the Guard break")
	assert_false(_any_sample("sprinting"), "he should not sprint")
	assert_almost_eq(_almos.position, start_position, Vector2.ONE * POSITION_TOLERANCE, "he should not have moved")
	assert_true(_stamina_never_dropped(), "nothing should be spent")


# --- A hit in a Guard break ---

func test_a_hit_during_a_guard_break_deals_full_damage_and_costs_no_stamina_and_does_not_restart_it() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var health_after_the_first_hit: float = _almos.health.current
	await _until_sample(_first_broken + EARLY_FRAMES)
	var stamina_before: float = _almos.stamina.current
	assert_gt(stamina_before, 0.0, "some Stamina should have come back, so that a blocked hit could spend it")

	await _hits.swing(_hitbox, 1)

	assert_true(_almos.guard_broken, "this should be in the Guard break")
	assert_almost_eq(_almos.health.current, health_after_the_first_hit - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_gte(_almos.stamina.current, stamina_before - STAMINA_TOLERANCE, "nothing should be spent")
	await _wait_until(func(): return _span("guard_broken").y != -1, "the Guard break should end")
	assert_eq(_span("guard_broken").y - _span("guard_broken").x, _break_frames(tuning), "the hit should not lengthen the Guard break")


# --- After a Guard break ---

func test_he_walks_again_from_the_first_frame_after_a_guard_break() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	_almos_input.release_action(&"block")
	_almos_input.press_action(&"move_right")
	var end := _first_broken + _break_frames(tuning)

	await _until_sample(end + 2)

	assert_eq(_span("guard_broken").y, end, "the first sample past the Guard break")
	var step := Vector2(tuning.walk_speed / Engine.physics_ticks_per_second, 0.0)
	assert_almost_eq(_samples[end].position, _samples[end - 1].position, Vector2.ONE * POSITION_TOLERANCE, "he should not have moved in the last frame of the Guard break")
	assert_almost_eq(_samples[end + 1].position - _samples[end].position, step, Vector2.ONE * POSITION_TOLERANCE, "how far he walked in the first frame after it")
	assert_almost_eq(_samples[end + 1].facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "he should have turned the way he walked")


func test_he_rolls_again_after_a_guard_break() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var end := _first_broken + _break_frames(tuning)

	await _until_sample(end)
	_almos_input.press_action(&"roll")
	await _until_sample(end + TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _until_sample(end + TAP_FRAMES + SETTLE_FRAMES)

	assert_true(_any_sample("rolling"), "he should have rolled")


func test_a_light_attack_press_read_in_the_first_frame_after_a_guard_break_swings() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var end := _first_broken + _break_frames(tuning)

	# A press is read as a press in the frame after the one it is made in.
	await _until_sample(end - 1)
	_almos_input.press_action(&"attack_light")
	await _until_sample(end + TAP_FRAMES)
	_almos_input.release_action(&"attack_light")

	assert_false(_samples[end].attacking, "he should not be swinging before the first frame after the Guard break")
	assert_true(_samples[end + 1].attacking, "he should be swinging from the first frame after it")


func test_he_is_blocking_again_from_the_first_frame_after_a_guard_break_if_block_is_still_held() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var end := _first_broken + _break_frames(tuning)

	await _until_sample(end + 2)

	assert_eq(_span("guard_broken").y, end, "the first sample past the Guard break")
	assert_true(_samples[end + 1].blocking, "he should be blocking in the first frame after it")
	assert_true(_samples[end + 1].block_shape, "the Block shape should show with it")


func test_with_no_stamina_back_by_the_end_he_is_blocking_again_but_a_hit_deals_full_damage_and_starts_no_new_guard_break() -> void:
	var tuning := _tuning_with_long_refill_pause()
	await _break_the_guard(tuning)
	var health_after_the_first_hit: float = _almos.health.current
	var end := _first_broken + _break_frames(tuning)
	await _until_sample(end + 2)
	assert_true(_almos.blocking, "he should be blocking again")
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE, "no Stamina should have come back")

	await _hits.swing(_hitbox, 1)
	await _until_sample(_samples.size() + SETTLE_FRAMES)

	assert_almost_eq(_almos.health.current, health_after_the_first_hit - HIT_DAMAGE, HEALTH_TOLERANCE, "all the damage should get through")
	assert_false(_almos.guard_broken, "no new Guard break should have begun")
	assert_eq(_span("guard_broken").y, end, "the first Guard break should be the only one")


func test_a_second_guard_break_lasts_as_long_as_the_first() -> void:
	var tuning := _tuning_with({"guard_break_duration": 0.27, "stamina_refill_pause": LONG_REFILL_PAUSE})
	await _break_the_guard(tuning)
	var end := _first_broken + _break_frames(tuning)
	await _until_sample(end + SETTLE_FRAMES)
	# Some Stamina back, but less than a blocked hit costs.
	_almos.stamina.advance(tuning.stamina_refill_pause + 0.1)
	assert_between(_almos.stamina.current, 0.0, tuning.block_stamina_cost, "some Stamina, but less than a blocked hit costs")

	await _hits.swing(_hitbox, 1)
	var second_start := _samples.size() - 1
	await _until_sample(second_start + _break_frames(tuning) + SETTLE_FRAMES)

	var second := _span("guard_broken", second_start)
	assert_eq(second.x, second_start, "the second Guard break should begin with the hit")
	assert_eq(second.y - second.x, _break_frames(tuning), "frames the second one lasts")


# --- Lock-on in a Guard break ---

func test_the_lock_on_button_still_toggles_lock_on_during_a_guard_break() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	_stand_in_enemy_at(Vector2.DOWN * ENEMY_DISTANCE)
	await _until_sample(_first_broken + EARLY_FRAMES)

	await _tap(&"lock_on")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "a press should lock on")

	await _tap(&"lock_on")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(_almos.locked_on, "another press should let go")
	assert_true(_almos.guard_broken, "this should all be in the Guard break")


func test_under_lock_on_he_still_turns_to_face_the_target_but_goes_nowhere_during_a_guard_break() -> void:
	var tuning := _tuning_with_quick_refill()
	await _break_the_guard(tuning)
	var start_position: Vector2 = _almos.position
	var enemy := _stand_in_enemy_at(Vector2.RIGHT * ENEMY_DISTANCE)
	await _until_sample(_first_broken + EARLY_FRAMES)
	_almos_input.press_action(&"move_down")

	await _tap(&"lock_on")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "a press should lock on")
	assert_almost_eq(_almos.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "he should face the target")

	enemy.global_position = _almos.global_position + Vector2.UP * ENEMY_DISTANCE
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(_almos.facing, Vector2.UP, Vector2.ONE * FACING_TOLERANCE, "he should turn with the target")
	assert_true(_almos.guard_broken, "this should all be in the Guard break")
	assert_almost_eq(_almos.position, start_position, Vector2.ONE * POSITION_TOLERANCE, "pushing a direction should not circle the target")


func test_a_lock_on_held_when_the_guard_break_began_lets_go_on_its_own_when_the_target_is_lost(params = use_parameters(target_lost_params)) -> void:
	var tuning := _tuning_with_quick_refill()
	_spawn_almos_with_stamina_left(tuning, tuning.block_stamina_cost / 3.0)
	# In front of him, the way he faces, so that locking on to it does not turn him from the hit.
	var enemy := _stand_in_enemy_at(Vector2.DOWN * ENEMY_DISTANCE)
	await _tap(&"lock_on")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should have locked on")
	_hitbox = await _take_up_blocking()
	await _hits.swing(_hitbox, 1)
	assert_true(_almos.guard_broken, "the hit should have started a Guard break")
	assert_true(_almos.locked_on, "he should still be locked on")

	params.lose.call(enemy, _almos, tuning)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_true(_almos.guard_broken, "this should be in the Guard break")
	assert_false(_almos.locked_on, "the lock should let go when the target %s" % params.name)


# --- Stamina in a Guard break ---

func test_stamina_refills_at_its_usual_rate_during_a_guard_break_once_the_pause_the_hit_began_is_over() -> void:
	var tuning := _tuning_with({"stamina_refill_pause": SHORT_REFILL_PAUSE})
	await _break_the_guard(tuning)

	await _until_sample(_first_broken + _frames_to_reach(tuning.stamina_refill_pause - REFILL_MARGIN))
	assert_almost_eq(_almos.stamina.current, 0.0, STAMINA_TOLERANCE, "nothing should come back during the pause")

	await _until_sample(_first_broken + _frames_to_reach(tuning.stamina_refill_pause + REFILL_MARGIN) + SETTLE_FRAMES)
	var before: float = _almos.stamina.current
	var start_frame := Engine.get_physics_frames()
	await wait_physics_frames(MEASURED_FRAMES)
	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second

	assert_true(_almos.guard_broken, "this should all be in the Guard break")
	assert_almost_eq(_almos.stamina.current - before, tuning.stamina_refill_rate * seconds, STAMINA_TOLERANCE, "how much came back, at the usual rate and not the rate while blocking")


# --- What is drawn ---

func test_what_is_drawn_of_him_is_tinted_for_exactly_the_frames_of_a_guard_break() -> void:
	await _break_the_guard(_tuning_with_quick_refill())
	await _wait_until(func(): return _span("guard_broken").y != -1, "the Guard break should end")
	await wait_physics_frames(SETTLE_FRAMES)

	var span := _span("guard_broken")
	var at_rest: Color = _samples[0].look
	var unclear := []
	for i in range(span.x, span.y):
		if _difference(_samples[i].look, at_rest) < VISIBLE_DIFFERENCE:
			unclear.append(i)
	assert_eq(unclear, [], "samples of the Guard break in which what is drawn hardly differs from how it looks at rest")
	var tinted_outside := []
	for i in _samples.size():
		if (i < span.x or i >= span.y) and _samples[i].look != at_rest:
			tinted_outside.append(i)
	assert_eq(tinted_outside, [], "samples outside the Guard break in which what is drawn differs from how it looks at rest")


func test_the_guard_break_tint_differs_from_the_training_enemys_wind_up_tint() -> void:
	assert_gte(_difference(AlmosBlock.GUARD_BREAK_TINT, TrainingEnemy.WIND_UP_TINT), VISIBLE_DIFFERENCE, "the two tints should look clearly different")


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
		"block_shape": _almos.get_node("Look/BlockShape").visible,
		"guard_broken": _almos.guard_broken,
		"rolling": _almos.rolling,
		"attacking": _almos.attacking,
		"charging": _almos.charging,
		"sprinting": _almos.sprinting,
		"stamina": _almos.stamina.current,
		"facing": _almos.facing,
		"look": (_almos.get_node("Look") as Node2D).modulate,
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


# Spawns Almos with this tuning, with just this much Stamina left and the Block button held,
# and settled. Returns a Hitbox switched off, with its origin in front of him, or behind him.
func _blocking_with_stamina_left(tuning: PlayerTuning, stamina_left: float, from_behind := false) -> Hitbox:
	_spawn_almos_with_stamina_left(tuning, stamina_left)
	return await _take_up_blocking(from_behind)


# Spawns Almos with this tuning, with just this much Stamina left. He was spawned a moment
# ago, so the refill pause is on whatever the tuning says.
func _spawn_almos_with_stamina_left(tuning: PlayerTuning, stamina_left: float) -> void:
	_spawn_almos(tuning)
	_almos.stamina.spend(tuning.stamina_maximum - stamina_left)


# Holds the Block button, and lets that settle. Returns a Hitbox switched off, with its origin
# in front of him, or behind him.
func _take_up_blocking(from_behind := false) -> Hitbox:
	var hit_origin: Vector2 = _almos.facing * HIT_DISTANCE
	var hitbox := _hits.hitbox_from(_almos, -hit_origin if from_behind else hit_origin)
	_almos_input.press_action(&"block")
	await wait_physics_frames(SETTLE_FRAMES)
	return hitbox


# The tuning data file's numbers, but with a refill pause short enough that Stamina is back
# soon after the Guard break begins, for tests of what he cannot do with Stamina to do it with.
func _tuning_with_quick_refill() -> PlayerTuning:
	return _tuning_with({"stamina_refill_pause": QUICK_REFILL_PAUSE})


# Spawns Almos blocking with less Stamina than a blocked hit costs, and has a hit from the front
# begin a Guard break. Returns at the first sample after the hit, which is the first to show
# it (_first_broken); _hitbox is the Hitbox that hit him, switched off, to hit him again with.
func _break_the_guard(tuning: PlayerTuning) -> void:
	_hitbox = await _blocking_with_stamina_left(tuning, tuning.block_stamina_cost / 3.0)
	await _hits.swing(_hitbox, 1)
	_first_broken = _samples.size() - 1
	assert_true(_samples[_first_broken].guard_broken, "the hit should have started a Guard break")


# How many physics frames this tuning's Guard break lasts: the first whole number of frames
# whose length is at least its duration.
func _break_frames(tuning: PlayerTuning) -> int:
	return ceili(tuning.guard_break_duration * Engine.physics_ticks_per_second - FRAME_COUNT_ALLOWANCE)


# Waits until this is true, for at most WAIT_LIMIT seconds of game time.
func _wait_until(condition: Callable, failure: String) -> void:
	var met: bool = await wait_until(condition, WAIT_LIMIT, failure)
	assert_true(met, failure)


# Waits until the sample with this index has been taken, which is the start of that physics
# frame, so that whatever is done next is first seen in that frame.
func _until_sample(index: int) -> void:
	while _samples.size() <= index:
		await get_tree().physics_frame


# How many physics frames it takes to reach this many seconds.
func _frames_to_reach(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second - FRAME_COUNT_ALLOWANCE)


# Whether his Stamina has not dropped from one sample to the next since the Guard break began:
# it only refills in it, so anything spent shows.
func _stamina_never_dropped() -> bool:
	for i in range(_first_broken + 1, _samples.size()):
		if _samples[i].stamina < _samples[i - 1].stamina - STAMINA_TOLERANCE:
			return false
	return true


# A stand-in enemy to lock on to, this far from Almos. The test frees it.
func _stand_in_enemy_at(offset: Vector2) -> Node2D:
	var enemy := StandInEnemy.new()
	enemy.position = _almos.position + offset
	add_child_autofree(enemy)
	return enemy


# Presses the action and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Whether any sample so far shows this state.
func _any_sample(state: String) -> bool:
	return _samples.any(func(sample: Dictionary) -> bool: return sample[state])


# The first stretch of samples, from the one with index from on, in which this is true, as
# Vector2i(first, end): the index of the first sample showing it and of the first showing it
# over. Either is -1 if it has not happened yet.
func _span(state: String, from := 0) -> Vector2i:
	var first := -1
	for i in range(from, _samples.size()):
		if first == -1 and _samples[i][state]:
			first = i
		elif first != -1 and not _samples[i][state]:
			return Vector2i(first, i)
	return Vector2i(first, -1)


# How different two colours are: the differences in red, green and blue added up.
func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
