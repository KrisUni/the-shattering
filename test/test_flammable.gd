extends GutTest
## A Flammable thing on its own: igniting it sets it burning, Fire spreads from it to the flammable
## things within the spread radius after the spread delay and to none beyond it, it burns for the
## burn time and is then gone, and while it burns it gives light, as a lit torch does. Fire never
## touches a torch. The numbers are a tuning this test makes, so nothing here pins the shipped ones.

const FLAMMABLE_PATH := "res://scenes/world/flammable.tscn"
const TORCH_PATH := "res://scenes/world/torch.tscn"
# In pixels. How far inside or beyond the spread radius or the light radius a point is put.
const EDGE_MARGIN := 1.0
# In physics frames. Slack added to a computed wait.
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


func test_a_flammable_thing_is_not_burning_at_first() -> void:
	var thing := _thing(Vector2.ZERO)

	assert_false(thing.burning)
	assert_false(thing.burnt_out)


func test_igniting_a_flammable_thing_sets_it_burning() -> void:
	var thing := _thing(Vector2.ZERO)

	thing.ignite()

	assert_true(thing.burning)


func test_igniting_says_whether_it_caught_and_tells_the_thing_once() -> void:
	var thing := _thing(Vector2.ZERO)
	watch_signals(thing)

	var first := thing.ignite()
	var second := thing.ignite()

	assert_true(first, "the first time it catches")
	assert_false(second, "already burning, nothing happens")
	assert_signal_emit_count(thing, "caught", 1)


func test_fire_spreads_to_a_neighbour_within_the_radius_after_the_delay() -> void:
	var source := _thing(Vector2.ZERO)
	var neighbour := _thing(Vector2(_tuning.spread_radius - EDGE_MARGIN, 0.0))

	source.ignite()
	await wait_physics_frames(_frames(_tuning.spread_delay) + MARGIN_FRAMES)

	assert_true(neighbour.burning)


func test_fire_does_not_spread_before_the_delay() -> void:
	var source := _thing(Vector2.ZERO)
	var neighbour := _thing(Vector2(_tuning.spread_radius - EDGE_MARGIN, 0.0))

	source.ignite()
	await wait_physics_frames(_frames(_tuning.spread_delay) - MARGIN_FRAMES)

	assert_false(neighbour.burning)


func test_fire_does_not_spread_to_a_thing_beyond_the_radius() -> void:
	var source := _thing(Vector2.ZERO)
	var far := _thing(Vector2(_tuning.spread_radius + EDGE_MARGIN, 0.0))

	source.ignite()
	await wait_physics_frames(_frames(_tuning.spread_delay) + MARGIN_FRAMES)

	assert_false(far.burning)


func test_fire_goes_on_from_a_neighbour_to_the_next_thing() -> void:
	var first := _thing(Vector2.ZERO)
	var second := _thing(Vector2(_tuning.spread_radius - EDGE_MARGIN, 0.0))
	var third := _thing(Vector2(2.0 * (_tuning.spread_radius - EDGE_MARGIN), 0.0))

	first.ignite()
	await wait_physics_frames(2 * _frames(_tuning.spread_delay) + 2 * MARGIN_FRAMES)

	assert_true(third.burning, "the neighbour's neighbour burns, though out of the first's reach")
	assert_true(second.burning)


func test_a_thing_burns_for_the_burn_time_and_is_then_burnt_out() -> void:
	var thing := _thing(Vector2.ZERO)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) - MARGIN_FRAMES)
	assert_true(thing.burning, "still burning just before the burn time")
	await wait_physics_frames(2 * MARGIN_FRAMES)

	assert_false(thing.burning)
	assert_true(thing.burnt_out)


func test_a_burnt_out_thing_loses_its_look_and_collision() -> void:
	var thing := _thing(Vector2.ZERO)

	thing.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	assert_false(thing.visible, "its look is gone")
	assert_eq(thing.collision_layer, 0, "and it is on no physics layer")
	assert_false(thing.monitorable, "so nothing can touch it")


func test_a_burnt_out_thing_cannot_be_set_alight_again() -> void:
	var thing := _thing(Vector2.ZERO)
	thing.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	var caught := thing.ignite()

	assert_false(caught)
	assert_false(thing.burning)


func test_fire_does_not_spread_into_a_burnt_out_thing() -> void:
	var source := _thing(Vector2.ZERO)
	var neighbour := _thing(Vector2(_tuning.spread_radius - EDGE_MARGIN, 0.0))
	neighbour.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)
	assert_true(neighbour.burnt_out)

	source.ignite()
	await wait_physics_frames(_frames(_tuning.spread_delay) + MARGIN_FRAMES)

	assert_false(neighbour.burning)


func test_burning_gives_light_within_the_light_radius_only_while_it_burns() -> void:
	var thing := _thing(Vector2.ZERO)
	var inside := Vector2(_tuning.light_radius - EDGE_MARGIN, 0.0)
	var outside := Vector2(_tuning.light_radius + EDGE_MARGIN, 0.0)
	assert_false(thing.lights(inside), "not before it is lit")

	thing.ignite()

	assert_true(thing.lights(inside), "while it burns")
	assert_false(thing.lights(outside), "but not beyond its radius")
	assert_almost_eq(thing.light, _tuning.light, 0.0001)
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)
	assert_false(thing.lights(inside), "and not once it is burnt out")


func test_burning_things_are_read_as_light_like_torches_are() -> void:
	var thing := _thing(Vector2.ZERO)
	var inside := Vector2(_tuning.light_radius - EDGE_MARGIN, 0.0)
	thing.ignite()

	var light := LightZone.light_at([], inside, get_tree().get_nodes_in_group("fires"))

	assert_almost_eq(light, 1.0, 0.0001, "full light outside any zone stays full")
	var dark := LightZone.new()
	dark.light = 0.0
	dark.size = Vector2(1000.0, 1000.0)
	add_child_autofree(dark)
	assert_almost_eq(LightZone.light_at([dark], inside, get_tree().get_nodes_in_group("fires")), _tuning.light, 0.0001, "the fire lifts the dark")


func test_a_burning_thing_is_among_the_fires_and_not_among_the_torches() -> void:
	var thing := _thing(Vector2.ZERO)
	assert_does_not_have(get_tree().get_nodes_in_group("fires"), thing, "not before it burns")

	thing.ignite()

	assert_has(get_tree().get_nodes_in_group("fires"), thing)
	assert_does_not_have(get_tree().get_nodes_in_group("torches"), thing, "Flame draw never finds it")


func test_a_burnt_out_thing_leaves_the_fires() -> void:
	var thing := _thing(Vector2.ZERO)
	thing.ignite()

	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	assert_does_not_have(get_tree().get_nodes_in_group("fires"), thing)


func test_fire_leaves_a_lit_torch_and_an_unlit_one_as_they_are() -> void:
	var source := _thing(Vector2.ZERO)
	var lit := _torch(Vector2(10.0, 0.0))
	var unlit := _torch(Vector2(-10.0, 0.0))
	unlit.extinguish()
	watch_signals(lit)

	source.ignite()
	await wait_physics_frames(_frames(_tuning.burn_time) + MARGIN_FRAMES)

	assert_true(lit.lit, "a lit torch is neither drawn nor put out")
	assert_signal_not_emitted(lit, "put_out")
	assert_false(unlit.lit, "an unlit torch is not relit")


# --- set-up ---


# A flammable thing at this point, on the test's tuning. The test frees it.
func _thing(at: Vector2) -> Flammable:
	var thing := (load(FLAMMABLE_PATH) as PackedScene).instantiate() as Flammable
	thing.tuning = _tuning
	add_child_autofree(thing)
	thing.global_position = at
	return thing


func _torch(at: Vector2) -> Torch:
	var torch := (load(TORCH_PATH) as PackedScene).instantiate() as Torch
	add_child_autofree(torch)
	torch.global_position = at
	return torch


# How many physics frames last this long, at the 60 a second the suite runs at.
func _frames(seconds: float) -> int:
	return ceili(seconds * 60.0)
