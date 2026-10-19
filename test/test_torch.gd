extends GutTest
## A Torch on its own: lit at first, put out by drawing its flame, once, and found through the
## group Almos reads.

const TORCH_PATH := "res://scenes/world/torch.tscn"


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


# A torch in the test's tree. The test frees it.
func _torch() -> Torch:
	var torch := (load(TORCH_PATH) as PackedScene).instantiate() as Torch
	add_child_autofree(torch)
	return torch
