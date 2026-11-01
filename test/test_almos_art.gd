extends GutTest
## Almos is drawn as a capped adventurer with the dark Seal at his neck: an AnimatedSprite2D Art on
## his Look, driven by AlmosLook, with idle and walk drawn facing down, up and to the side. It walks
## while he moves and stands while he stands, shows the side he faces, and flips for the left. The torches
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
	for animation_name in [&"idle_down", &"walk_down", &"idle_up", &"walk_up", &"idle_side", &"walk_side"]:
		assert_true(art.sprite_frames.has_animation(animation_name), "he has %s" % animation_name)
	var size := art.sprite_frames.get_frame_texture(&"idle_down", 0).get_size()
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
	assert_eq(_art(almos).animation, &"idle_down", "standing, facing down, he is idle")

	_almos_input.press_action(&"move_right")
	await wait_physics_frames(4)
	assert_eq(_art(almos).animation, &"walk_side", "moving right, he walks side on")

	_almos_input.release_everything()
	await wait_physics_frames(30)
	assert_eq(_art(almos).animation, &"idle_side", "still again, he is idle side on")


func test_he_shows_the_side_he_walks_toward_in_every_direction() -> void:
	var almos = _almos_input.spawn_almos()
	var art := _art(almos)
	var expected := {
		&"move_down": [&"walk_down", false],
		&"move_up": [&"walk_up", false],
		&"move_right": [&"walk_side", false],
		&"move_left": [&"walk_side", true],
	}
	for action: StringName in expected:
		_almos_input.press_action(action)
		await wait_physics_frames(4)
		assert_eq(art.animation, expected[action][0], "%s plays %s" % [action, expected[action][0]])
		assert_eq(art.flip_h, expected[action][1], "%s flips: %s" % [action, expected[action][1]])
		_almos_input.release_everything()
		await wait_physics_frames(30)
	assert_almost_eq(art.global_rotation, 0.0, 0.0001, "the sprite never turns, only flips")


func test_a_diagonal_shows_the_side_and_up_or_down_shows_itself() -> void:
	assert_eq(AlmosLook.side_for(Vector2.RIGHT), &"side")
	assert_eq(AlmosLook.side_for(Vector2.LEFT), &"side")
	assert_eq(AlmosLook.side_for(Vector2(1, 1).normalized()), &"side")
	assert_eq(AlmosLook.side_for(Vector2.UP), &"up")
	assert_eq(AlmosLook.side_for(Vector2.DOWN), &"down")
	assert_eq(AlmosLook.side_for(Vector2(0.3, -0.9).normalized()), &"up")


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
