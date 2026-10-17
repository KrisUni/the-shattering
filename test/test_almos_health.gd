extends GutTest
## Almos being hurt, seen only through the scene. A Hitbox made here stands in for an
## attacker and is laid over his Hurtbox; then we step physics frames and read his Health.
## Expected numbers come from the damage each test gives its Hitbox and from the tuning
## data file the scene uses, never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# In Health points.
const TOLERANCE := 0.0001
# In Health points. A hit small enough that several of them fit in his Health.
const HIT_DAMAGE := 12.0
# In pixels. A hitbox this wide covers all of Almos and everywhere a Roll takes him.
const HITBOX_RADIUS := 200.0
# How many physics frames a swing stays on when it is to overlap him for many of them.
const LONG_SWING_FRAMES := 10
# How many physics frames a swing stays on when it is to fit inside his untouchable window.
const SHORT_SWING_FRAMES := 2
# A tap: held this many physics frames, far shorter than any sensible hold threshold.
const TAP_FRAMES := 3
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 120

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_almos_starts_with_the_health_maximum_in_the_tuning_data() -> void:
	var tuning := _tuning()
	assert_gt(tuning.health_maximum, 0.0, "health_maximum in the data file should be positive")

	var almos = _almos_input.spawn_almos()

	assert_almost_eq(almos.health.maximum, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_almos_takes_his_health_maximum_from_the_tuning_he_is_given() -> void:
	var tuning := _tuning_with({"health_maximum": _tuning().health_maximum / 2.0})

	var almos = _almos_input.spawn_almos(tuning)

	assert_almost_eq(almos.health.maximum, tuning.health_maximum, TOLERANCE)
	assert_almost_eq(almos.health.current, tuning.health_maximum, TOLERANCE)


func test_a_swing_over_him_takes_its_damage_off_his_health() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)
	await wait_physics_frames(SETTLE_FRAMES)

	await _swing(hitbox, 1)

	assert_almost_eq(almos.health.current, _tuning().health_maximum - HIT_DAMAGE, TOLERANCE)


func test_one_swing_hits_him_once_however_many_frames_it_overlaps_him() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)
	await wait_physics_frames(SETTLE_FRAMES)

	await _swing(hitbox, LONG_SWING_FRAMES)

	assert_almost_eq(almos.health.current, _tuning().health_maximum - HIT_DAMAGE, TOLERANCE)


func test_switching_off_and_on_again_is_a_second_swing_that_hits_again() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)
	await wait_physics_frames(SETTLE_FRAMES)

	await _swing(hitbox, LONG_SWING_FRAMES)
	await _swing(hitbox, LONG_SWING_FRAMES)

	assert_almost_eq(almos.health.current, _tuning().health_maximum - 2.0 * HIT_DAMAGE, TOLERANCE)


func test_switching_on_a_swing_that_is_already_on_does_not_start_another() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)
	await wait_physics_frames(SETTLE_FRAMES)

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)
	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)

	assert_almost_eq(almos.health.current, _tuning().health_maximum - HIT_DAMAGE, TOLERANCE)


func test_a_hitbox_that_is_switched_off_does_no_damage() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)

	await wait_physics_frames(LONG_SWING_FRAMES)

	assert_false(hitbox.active, "a hitbox should start switched off")
	assert_almost_eq(almos.health.current, _tuning().health_maximum, TOLERANCE)


func test_two_hitboxes_swinging_on_the_same_frame_both_hit_him() -> void:
	var almos = _almos_input.spawn_almos()
	var first := _hitbox_over(almos, HIT_DAMAGE)
	var second := _hitbox_over(almos, HIT_DAMAGE * 2.0)
	await wait_physics_frames(SETTLE_FRAMES)

	first.active = true
	second.active = true
	await get_tree().physics_frame
	first.active = false
	second.active = false

	assert_almost_eq(almos.health.current, _tuning().health_maximum - first.damage - second.damage, TOLERANCE)


func test_a_hitbox_that_belongs_to_almos_does_not_hurt_him() -> void:
	var almos = _almos_input.spawn_almos()
	# The same hitbox as in the other tests, aimed at his Hurtbox and wide enough to cover
	# it; the only difference is that it is part of him.
	var hitbox := _new_hitbox(HIT_DAMAGE)
	almos.add_child(hitbox)
	await wait_physics_frames(SETTLE_FRAMES)

	await _swing(hitbox, LONG_SWING_FRAMES)

	assert_almost_eq(almos.health.current, _tuning().health_maximum, TOLERANCE)


func test_a_swing_aimed_at_enemies_passes_through_him() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE, "enemy_hurtbox")
	await wait_physics_frames(SETTLE_FRAMES)

	await _swing(hitbox, LONG_SWING_FRAMES)

	assert_almost_eq(almos.health.current, _tuning().health_maximum, TOLERANCE)


func test_a_swing_while_he_is_untouchable_in_a_roll_does_no_damage() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for(func(): return almos.untouchable, "he should become untouchable")

	await _swing(hitbox, SHORT_SWING_FRAMES)

	assert_true(almos.untouchable, "the whole swing should have fallen inside his untouchable window")
	assert_almost_eq(almos.health.current, _tuning().health_maximum, TOLERANCE)


func test_a_swing_still_on_when_his_untouchable_window_ends_hits_him_then_once() -> void:
	var almos = _almos_input.spawn_almos()
	var hitbox := _hitbox_over(almos, HIT_DAMAGE)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap_roll()
	await _wait_for(func(): return almos.untouchable, "he should become untouchable")

	hitbox.active = true
	for i in WAIT_FRAME_LIMIT:
		if not almos.untouchable:
			break
		assert_almost_eq(almos.health.current, _tuning().health_maximum, TOLERANCE, "nothing should land while he is untouchable")
		await get_tree().physics_frame
	await _wait_for(func(): return not almos.rolling, "his roll should end")
	hitbox.active = false

	assert_almost_eq(almos.health.current, _tuning().health_maximum - HIT_DAMAGE, TOLERANCE)


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


# A Hitbox, switched off, laid over Almos and aimed at the player's Hurtboxes, as an
# enemy's would be, unless it is given another layer to aim at. The test frees it.
func _hitbox_over(almos: Node2D, damage: float, target := "player_hurtbox") -> Hitbox:
	var hitbox := _new_hitbox(damage, target)
	hitbox.global_position = almos.global_position
	add_child_autofree(hitbox)
	return hitbox


# A Hitbox, switched off and in no tree yet, wide enough to cover Almos and aimed at the
# Hurtboxes on this layer, the player's by default.
func _new_hitbox(damage: float, target := "player_hurtbox") -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.damage = damage
	hitbox.collision_mask = _layer_bit(target)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HITBOX_RADIUS
	shape.shape = circle
	hitbox.add_child(shape)
	return hitbox


# Switches the hitbox on for this many physics frames, then off again. It waits on the
# physics_frame signal, which comes before the hitbox is processed in a frame, so the
# hitbox is processed on exactly this many frames while it is on.
func _swing(hitbox: Hitbox, frames: int) -> void:
	hitbox.active = true
	for i in frames:
		await get_tree().physics_frame
	hitbox.active = false


# The collision layer the project calls this, as the bit that sets it in a collision mask.
func _layer_bit(layer_name: String) -> int:
	for layer in range(1, 33):
		if ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "") == layer_name:
			return 1 << (layer - 1)
	fail_test("the project should name a 2D physics layer %s" % layer_name)
	return 0


# Presses the Roll button and lets go again after a few frames.
func _tap_roll() -> void:
	_almos_input.press_action(&"roll")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")


# Waits, a physics frame at a time, until this is true. It checks just before the frame's
# nodes are processed, so it sees how the frame before left things.
func _wait_for(condition: Callable, failure: String) -> void:
	for i in WAIT_FRAME_LIMIT:
		if condition.call():
			return
		await get_tree().physics_frame
	fail_test(failure)
