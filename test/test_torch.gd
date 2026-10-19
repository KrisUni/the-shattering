extends GutTest
## A Torch on its own: lit at first, put out by drawing its flame, once, and found through the
## group Almos reads, lit again by relight, and lighting the points within its radius while it
## burns. Its light and radius come from data/torch_light.tres.

const TORCH_PATH := "res://scenes/world/torch.tscn"
const TUNING_PATH := "res://data/torch_light.tres"
# In pixels. How far inside or outside the radius a point is put to try it.
const EDGE_MARGIN := 1.0


func before_each() -> void:
	await get_tree().process_frame


func test_a_torch_is_lit_at_first() -> void:
	assert_true(_torch().lit)


func test_drawing_the_flame_puts_the_torch_out() -> void:
	var torch := _torch()

	torch.draw()

	assert_false(torch.lit)


func test_drawing_a_lit_torch_says_there_was_a_flame() -> void:
	assert_true(_torch().draw())


func test_drawing_an_unlit_torch_says_there_was_no_flame() -> void:
	var torch := _torch()
	torch.draw()

	assert_false(torch.draw())


func test_a_torch_announces_that_it_went_out_once() -> void:
	var torch := _torch()
	watch_signals(torch)

	torch.draw()
	torch.draw()

	assert_signal_emit_count(torch, "put_out", 1)


func test_a_torch_in_the_tree_is_found_through_the_group_almos_reads() -> void:
	var torch := _torch()

	assert_true(torch in get_tree().get_nodes_in_group("torches"))


func test_the_placeholder_shows_the_flame_only_while_the_torch_is_lit() -> void:
	var torch := _torch()
	var flame := torch.get_node("Flame") as CanvasItem
	var shown_lit := flame.visible

	torch.draw()

	assert_true(shown_lit, "lit")
	assert_false(flame.visible, "unlit")


func test_relighting_a_torch_that_is_out_lights_it_and_says_it_was_out() -> void:
	var torch := _torch()
	torch.draw()

	var was_out := torch.relight()

	assert_true(was_out, "said it was out")
	assert_true(torch.lit, "lit")


func test_relighting_a_lit_torch_says_it_was_not_out_and_leaves_it_lit() -> void:
	var torch := _torch()

	assert_false(torch.relight(), "said it was not out")
	assert_true(torch.lit, "lit")


func test_a_relit_torch_can_be_drawn_again_and_says_it_went_out_again() -> void:
	var torch := _torch()
	torch.draw()
	torch.relight()
	watch_signals(torch)

	assert_true(torch.draw(), "drawn again")
	assert_signal_emit_count(torch, "put_out", 1)


func test_the_placeholder_shows_the_flame_again_when_the_torch_is_relit() -> void:
	var torch := _torch()
	var flame := torch.get_node("Flame") as CanvasItem
	torch.draw()

	torch.relight()

	assert_true(flame.visible)


func test_a_torch_has_the_light_and_radius_of_its_data() -> void:
	var data := load(TUNING_PATH) as TorchTuning
	assert_not_null(data, "the torch light data file should load")
	var torch := _torch()

	assert_almost_eq(torch.light, data.light, 0.0001, "light")
	assert_almost_eq(torch.radius, data.radius, 0.0001, "radius")


func test_a_lit_torch_lights_the_points_within_its_radius_edge_included() -> void:
	var torch := _torch()
	torch.position = Vector2(200.0, 100.0)
	var radius := torch.radius

	assert_true(torch.lights(torch.global_position), "at the torch")
	assert_true(torch.lights(torch.global_position + Vector2(radius, 0.0)), "at the edge")
	assert_true(torch.lights(torch.global_position + Vector2(0.0, -radius + EDGE_MARGIN)), "just inside")


func test_a_lit_torch_does_not_light_the_points_beyond_its_radius() -> void:
	var torch := _torch()
	torch.position = Vector2(200.0, 100.0)

	assert_false(torch.lights(torch.global_position + Vector2(torch.radius + EDGE_MARGIN, 0.0)), "just outside")
	assert_false(torch.lights(torch.global_position + Vector2(-torch.radius, torch.radius)), "in the corner of its box")


func test_a_torch_that_is_out_lights_nothing_until_it_is_relit() -> void:
	var torch := _torch()
	torch.draw()

	assert_false(torch.lights(torch.global_position), "out")

	torch.relight()

	assert_true(torch.lights(torch.global_position), "relit")


# A torch in the test's tree. The test frees it.
func _torch() -> Torch:
	var torch := (load(TORCH_PATH) as PackedScene).instantiate() as Torch
	add_child_autofree(torch)
	return torch


func test_going_out_quietly_puts_the_torch_out_and_says_nothing() -> void:
	var torch := _torch()
	watch_signals(torch)

	torch.extinguish()

	assert_false(torch.lit)
	assert_signal_not_emitted(torch, "put_out")


func test_a_torch_put_out_quietly_can_be_relit() -> void:
	var torch := _torch()
	torch.extinguish()

	assert_true(torch.relight())
	assert_true(torch.lit)
