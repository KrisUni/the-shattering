extends GutTest
## Taking the flame off a Flammable thing on its own: it stops burning and is left as it was, not
## burnt out, with no more light, no more ticks and no spread still to come, it can catch again, and
## Fire that already spread from it keeps burning. And how far a point is from its nearest edge. The
## numbers are a tuning this test makes, so nothing here pins the shipped ones.

const FLAMMABLE_PATH := "res://scenes/world/flammable.tscn"
# In pixels. The size of the rectangle in the Flammable scene, read from it, not pinned.
const MARGIN_FRAMES := 3

var _tuning: FireTuning


func before_each() -> void:
	await get_tree().process_frame
	_tuning = FireTuning.new()
	_tuning.spread_radius = 100.0
	_tuning.spread_delay = 0.5
	_tuning.burn_time = 1.5
	_tuning.light = 0.6
	_tuning.light_radius = 70.0
	_tuning.damage_per_tick = 1.0
	_tuning.tick_interval = 0.25


func test_putting_out_a_burning_thing_stops_it_burning_without_burning_it_out() -> void:
	var thing := _thing(Vector2.ZERO)
	thing.ignite()

	assert_true(thing.extinguish(), "it was burning")

	assert_false(thing.burning, "burning")
	assert_false(thing.burnt_out, "burnt out")
	assert_false(thing.is_in_group(&"fires"), "in fires")
	assert_false(thing.lights(Vector2.ZERO), "gives light")
	assert_true(thing.visible, "its look stays")


func test_putting_out_a_thing_that_is_not_burning_does_nothing() -> void:
	var thing := _thing(Vector2.ZERO)

	assert_false(thing.extinguish())
	assert_false(thing.burnt_out)


func test_a_thing_put_out_never_burns_out_later() -> void:
	var thing := _thing(Vector2.ZERO)
	thing.ignite()
	thing.extinguish()

	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	assert_false(thing.burnt_out)
	assert_false(thing.burning)


func test_a_thing_put_out_before_its_spread_delay_spreads_nothing() -> void:
	var thing := _thing(Vector2.ZERO)
	var neighbour := _thing(Vector2(_tuning.spread_radius / 2.0, 0.0))
	thing.ignite()
	await wait_physics_frames(_frames(_tuning.spread_delay / 2.0))
	thing.extinguish()

	await wait_physics_frames(_frames(_tuning.spread_delay + _tuning.burn_time))

	assert_false(neighbour.burning, "the neighbour")


func test_fire_that_already_spread_keeps_burning() -> void:
	var thing := _thing(Vector2.ZERO)
	var neighbour := _thing(Vector2(_tuning.spread_radius / 2.0, 0.0))
	thing.ignite()
	await wait_physics_frames(_frames(_tuning.spread_delay) + MARGIN_FRAMES)
	assert_true(neighbour.burning, "it spread")

	thing.extinguish()

	assert_true(neighbour.burning, "the neighbour burns on")


func test_a_thing_put_out_ticks_no_more() -> void:
	var thing := _thing(Vector2.ZERO)
	thing.ignite()
	await wait_physics_frames(_frames(_tuning.tick_interval) + MARGIN_FRAMES)
	thing.extinguish()
	var ticks := thing.ticks

	await wait_physics_frames(_frames(_tuning.tick_interval * 3.0))

	assert_eq(thing.ticks, ticks)


func test_a_thing_put_out_can_catch_again_and_burns_its_whole_time() -> void:
	var thing := _thing(Vector2.ZERO)
	thing.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time / 2.0))
	thing.extinguish()

	assert_true(thing.ignite(), "catches again")
	await wait_physics_frames(_frames(_tuning.burn_time * 0.75))
	assert_true(thing.burning, "burns for a whole burn time again, not the rest of the old one")
	await wait_physics_frames(_frames(_tuning.burn_time * 0.5))
	assert_true(thing.burnt_out, "and then burns out")


func test_the_distance_to_the_edge_is_zero_inside_and_measured_from_the_edge_outside() -> void:
	var thing := _thing(Vector2(100.0, 50.0))
	var half := ((thing.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size / 2.0

	assert_almost_eq(thing.distance_to_edge(thing.global_position), 0.0, 0.0001, "centre")
	assert_almost_eq(thing.distance_to_edge(thing.global_position + Vector2(half.x + 30.0, 0.0)), 30.0, 0.0001, "beside it")
	assert_almost_eq(thing.distance_to_edge(thing.global_position + Vector2(0.0, -half.y - 20.0)), 20.0, 0.0001, "above it")
	assert_almost_eq(thing.distance_to_edge(thing.global_position + half + Vector2(3.0, 4.0)), 5.0, 0.0001, "off a corner")


func _frames(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


func _thing(at: Vector2) -> Flammable:
	var thing := (load(FLAMMABLE_PATH) as PackedScene).instantiate() as Flammable
	thing.tuning = _tuning
	thing.position = at
	add_child_autofree(thing)
	return thing
