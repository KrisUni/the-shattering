extends GutTest
## What a burning Flammable thing does to a Hurtbox inside it, on its own: it ticks the damage
## every tick interval while it burns, the first tick one interval after it catches, to every
## Hurtbox of Almos's side or the enemies' that overlaps it, and to none outside, none before it
## burns and none once it is burnt out. The numbers are a tuning this test makes, so nothing here
## pins the shipped ones.

const FLAMMABLE_PATH := "res://scenes/world/flammable.tscn"
const HURTBOX_SCRIPT_PATH := "res://scripts/combat/hurtbox.gd"
const PLAYER_HURTBOX_LAYER := 2
const ENEMY_HURTBOX_LAYER := 4
# In pixels. Half the width of the Flammable's box, and how far past its edge a body is put to be
# clear of it: further than the radius of a Hurtbox's circle.
const HALF_WIDTH := 16.0
const CLEAR_OF_IT := 60.0
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 3

var _tuning: FireTuning


func before_each() -> void:
	await get_tree().process_frame
	_tuning = FireTuning.new()
	_tuning.spread_radius = 100.0
	_tuning.spread_delay = 10.0
	_tuning.burn_time = 1.5
	_tuning.light = 0.6
	_tuning.light_radius = 70.0
	_tuning.damage_per_tick = 7.0
	_tuning.tick_interval = 0.4


func test_a_burning_thing_hurts_what_stands_in_it_each_tick() -> void:
	var thing := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2.ZERO)
	await wait_physics_frames(MARGIN_FRAMES)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) + MARGIN_FRAMES)
	assert_eq(_lost(body), _tuning.damage_per_tick, "one tick after one interval")
	await wait_physics_frames(_frames(_tuning.tick_interval))

	assert_eq(_lost(body), 2.0 * _tuning.damage_per_tick, "and another after the next")


func test_the_first_tick_comes_one_interval_after_it_catches_not_before() -> void:
	var thing := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2.ZERO)
	await wait_physics_frames(MARGIN_FRAMES)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) - MARGIN_FRAMES)

	assert_eq(_lost(body), 0.0)


func test_it_hurts_an_enemys_hurtbox_as_it_hurts_almos() -> void:
	var thing := _thing()
	var almos := _body(PLAYER_HURTBOX_LAYER, Vector2(-5.0, 0.0))
	var enemy := _body(ENEMY_HURTBOX_LAYER, Vector2(5.0, 0.0))
	await wait_physics_frames(MARGIN_FRAMES)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) + MARGIN_FRAMES)

	assert_eq(_lost(enemy), _tuning.damage_per_tick)
	assert_eq(_lost(enemy), _lost(almos), "the same damage")


func test_it_hurts_nothing_outside_it() -> void:
	var thing := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2(HALF_WIDTH + CLEAR_OF_IT, 0.0))
	await wait_physics_frames(MARGIN_FRAMES)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	assert_eq(_lost(body), 0.0)


func test_it_hurts_nothing_while_it_does_not_burn() -> void:
	var _thing_that_is_not_lit := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2.ZERO)

	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	assert_eq(_lost(body), 0.0)


func test_a_burning_thing_hurts_for_the_burn_time_and_no_longer() -> void:
	var thing := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2.ZERO)
	await wait_physics_frames(MARGIN_FRAMES)
	var ticks := floori(_tuning.burn_time / _tuning.tick_interval)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)
	assert_true(thing.burnt_out, "control: it has burnt out")
	assert_eq(_lost(body), ticks * _tuning.damage_per_tick, "a tick for each whole interval it burned")
	await wait_physics_frames(3 * _frames(_tuning.tick_interval))

	assert_eq(_lost(body), ticks * _tuning.damage_per_tick, "and none after")


func test_each_burning_thing_ticks_on_its_own_so_overlapping_ones_all_hurt() -> void:
	var first := _thing()
	var second := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2.ZERO)
	await wait_physics_frames(MARGIN_FRAMES)

	first.ignite()
	second.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) + MARGIN_FRAMES)

	assert_eq(_lost(body), 2.0 * _tuning.damage_per_tick)


func test_a_tick_misses_whoever_is_untouchable_and_cannot_be_blocked_or_parried() -> void:
	var thing := _thing()
	var untouchable := _body(PLAYER_HURTBOX_LAYER, Vector2(-5.0, 0.0))
	untouchable.is_untouchable = func() -> bool: return true
	var guarded := _body(PLAYER_HURTBOX_LAYER, Vector2(5.0, 0.0))
	guarded.is_parried = func(_from: Vector2) -> bool: return true
	guarded.damage_through = func(_damage: float, _from: Vector2) -> float: return 0.0
	await wait_physics_frames(MARGIN_FRAMES)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) + MARGIN_FRAMES)

	assert_eq(_lost(untouchable), 0.0, "an untouchable body takes nothing")
	assert_eq(_lost(guarded), _tuning.damage_per_tick, "a Parry or a Block takes nothing off it")


func test_a_tick_builds_no_stagger_and_is_heard_as_damage_only() -> void:
	var thing := _thing()
	var body := _body(PLAYER_HURTBOX_LAYER, Vector2.ZERO)
	watch_signals(body)
	await wait_physics_frames(MARGIN_FRAMES)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) + MARGIN_FRAMES)

	assert_signal_emit_count(body, "landed_damage_only", 1)
	assert_signal_not_emitted(body, "landed")


# --- set-up ---


# A Flammable thing at the origin, on the test's tuning. The test frees it.
func _thing() -> Flammable:
	var thing := (load(FLAMMABLE_PATH) as PackedScene).instantiate() as Flammable
	thing.tuning = _tuning
	add_child_autofree(thing)
	return thing


# A Hurtbox on this layer at this point, with a Health of its own. The test frees it.
func _body(layer: int, at: Vector2) -> Hurtbox:
	var health := Health.new()
	health.maximum = 100.0
	add_child_autofree(health)
	var hurtbox := Hurtbox.new()
	hurtbox.health = health
	hurtbox.collision_layer = layer
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	hurtbox.add_child(shape)
	add_child_autofree(hurtbox)
	hurtbox.global_position = at
	return hurtbox


func _lost(body: Hurtbox) -> float:
	return body.health.maximum - body.health.current


# How many physics frames last this long, at the 60 a second the suite runs at.
func _frames(seconds: float) -> int:
	return ceili(seconds * 60.0)
