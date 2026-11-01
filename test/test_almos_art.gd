extends GutTest
## Almos is drawn as a hooded figure: an AnimatedSprite2D Art on his Look, driven by AlmosLook,
## that walks while he moves, stands while he stands and turns left or right with him. The torches
## that hang on him (the carried torch and the held flame) show only their flame, never a bracket.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const PALETTE_PATH := "res://assets/palette/master.hex"
const ART_DIR := "res://assets/characters/almos/"

var _almos_input: AlmosInput


func before_each() -> void:
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func _art(almos: Node) -> AnimatedSprite2D:
	return almos.get_node("Look/Art") as AnimatedSprite2D


func test_he_has_a_sprite_with_idle_and_walk_at_scale_2() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	assert_not_null(art, "Almos has an Art sprite on his Look")
	assert_eq(art.scale, Vector2(2, 2), "one art px is 2 units")
	for animation_name in [&"idle", &"walk"]:
		assert_true(art.sprite_frames.has_animation(animation_name), "he has %s" % animation_name)
	var size := art.sprite_frames.get_frame_texture(&"idle", 0).get_size()
	assert_eq(size, Vector2(16, 24), "he is 16 by 24 art px")


func test_his_placeholder_arrow_is_hidden_not_deleted() -> void:
	var almos = _almos_input.spawn_almos()
	var shape := almos.get_node("Look/Facing/Shape") as Polygon2D
	assert_not_null(shape, "the arrow stays for the code and tests that use it")
	assert_false(shape.visible, "the arrow is hidden under the sprite")


func test_the_torches_on_him_draw_no_bracket() -> void:
	var almos = _almos_input.spawn_almos()
	for torch_name in ["CarriedTorch", "HeldFlame"]:
		var bracket := almos.get_node("%s/Look/Art" % torch_name) as CanvasItem
		assert_false(bracket.visible, "%s shows no bracket on Almos" % torch_name)


func test_a_wall_torch_still_draws_its_bracket() -> void:
	var torch := (load("res://scenes/world/torch.tscn") as PackedScene).instantiate()
	add_child_autofree(torch)
	assert_true((torch.get_node("Look/Art") as CanvasItem).visible, "a wall torch keeps its bracket")


func test_he_walks_while_moving_and_stands_while_still() -> void:
	var almos = _almos_input.spawn_almos()
	await wait_physics_frames(2)
	assert_eq(_art(almos).animation, &"idle", "standing, he is idle")

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(4)
	assert_eq(_art(almos).animation, &"walk", "moving, he walks")

	_almos_input.release_everything()
	await wait_physics_frames(30)
	assert_eq(_art(almos).animation, &"idle", "still again, he is idle")


func test_the_sprite_turns_left_and_right_and_keeps_its_side_facing_up_or_down() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)

	_almos_input.press_action(&"move_left")
	await wait_physics_frames(3)
	_almos_input.release_everything()
	assert_true(art.flip_h, "facing left, the sprite is flipped")

	_almos_input.press_action(&"move_up")
	await wait_physics_frames(3)
	_almos_input.release_everything()
	assert_true(art.flip_h, "facing up keeps the left side")

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(3)
	_almos_input.release_everything()
	assert_false(art.flip_h, "facing right, the sprite is not flipped")
	assert_almost_eq(art.global_rotation, 0.0, 0.0001, "the sprite never turns, only flips")


func test_every_pixel_of_his_art_is_a_palette_colour() -> void:
	var palette := {}
	for line in FileAccess.get_file_as_string(PALETTE_PATH).split("\n", false):
		palette[Color(line.strip_edges()).to_html(false)] = true
	var checked := 0
	var off: Array[String] = []
	for file_name in DirAccess.get_files_at(ART_DIR):
		if not file_name.ends_with(".png"):
			continue
		checked += 1
		var image := Image.load_from_file(ProjectSettings.globalize_path(ART_DIR + file_name))
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.0 and (pixel.a < 1.0 or not palette.has(pixel.to_html(false))):
					off.append("%s at %d, %d" % [file_name, x, y])
	assert_gt(checked, 0, "there is art to check")
	assert_eq(off, [] as Array[String], "every opaque pixel is a palette colour")
