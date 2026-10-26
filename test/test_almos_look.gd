extends GutTest
## How Almos is drawn, seen through the scene: his drawing hangs on Look nodes, so that art can
## later be added under a Look with no change to the code or the tests. No node of him or of his
## Sword is a Placeholder any more.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

var _almos_input: AlmosInput


func before_each() -> void:
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_almos_has_a_look_and_no_placeholder() -> void:
	var almos = _almos_input.spawn_almos()

	assert_true(almos.get_node_or_null("Look") is Node2D, "he should have a Look")
	assert_null(almos.find_child("Placeholder", true, false), "he should have no Placeholder")
	assert_null(almos.find_child("BlockPlaceholder", true, false), "he should have no Block placeholder")
	assert_null(almos.find_child("ParryPlaceholder", true, false), "he should have no Parry placeholder")


func test_his_block_and_parry_shapes_hang_on_his_look_and_are_hidden_at_first() -> void:
	var almos = _almos_input.spawn_almos()

	assert_false((almos.get_node("Look/Facing/BlockShape") as CanvasItem).visible, "no Block shape")
	assert_false((almos.get_node("Look/Facing/ParryShape") as CanvasItem).visible, "no Parry shape")


func test_his_sword_and_his_shadow_hang_on_looks() -> void:
	var almos = _almos_input.spawn_almos()

	assert_true(almos.get_node_or_null("Sword/Look") is Node2D, "the Sword should have a Look")
	assert_null(almos.get_node("Sword").find_child("Placeholder", true, false), "no Placeholder on the Sword")
	assert_true(almos.get_node_or_null("Shadow/Look") is Node2D, "the shadow should hold a Look")
	assert_false((almos.get_node("Shadow") as CanvasItem).visible, "the shadow is hidden on the ground")


func test_the_look_of_the_sword_moves_with_the_strike_shift() -> void:
	var almos = _almos_input.spawn_almos()
	var sword := almos.get_node("Sword") as Hitbox
	var look := sword.get_node("Look") as Node2D
	var look_before := look.position.x
	var drawn_before := StrikeGeometry.drawn_box(sword).end.x

	sword.set_reach(StrikeGeometry.real_box(sword).end.x + 10.0)

	assert_almost_eq(look.position.x, look_before + 10.0, 0.01, "the Look of the Sword should have moved with the box")
	assert_almost_eq(StrikeGeometry.drawn_box(sword).end.x, drawn_before + 10.0, 0.01, "and what is drawn is read from the Look")


func test_a_sprite_on_his_look_stays_upright_while_the_shapes_turn_with_his_facing() -> void:
	var almos = _almos_input.spawn_almos()
	var sprite := Sprite2D.new()
	(almos.get_node("Look") as Node2D).add_child(sprite)
	var moves := {&"move_left": Vector2.LEFT, &"move_right": Vector2.RIGHT, &"move_up": Vector2.UP, &"move_down": Vector2.DOWN}

	for action: StringName in moves:
		_almos_input.press_action(action)
		await wait_physics_frames(3)
		_almos_input.release_everything()

		assert_almost_eq(almos.facing, moves[action], Vector2.ONE * 0.0001, "he should face %s" % action)
		assert_almost_eq(sprite.global_rotation, 0.0, 0.0001, "a sprite on his Look should not turn when he faces %s" % action)
		assert_almost_eq((almos.get_node("Look/Facing/Shape") as Node2D).global_rotation, almos.facing.angle(), 0.0001, "his shape should turn to face %s" % action)
