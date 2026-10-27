extends GutTest
## The art drawn inside the Looks of the Torch and the Flammable: each is a sprite under its Look or
## under its Flame, the placeholder polygons are still there but not drawn, and the flame still
## shows and hides with the polygon the code toggles. Also: every drawn pixel of every image under
## assets/ is a colour of the master palette.

const PALETTE_PATH := "res://assets/palette/master.hex"
const ASSETS_PATH := "res://assets"


func before_each() -> void:
	await get_tree().process_frame


func test_a_torch_draws_its_bracket_as_a_sprite_and_hides_the_polygon() -> void:
	var torch: Node = autofree(load("res://scenes/world/torch.tscn").instantiate())
	var art := torch.get_node_or_null("Look/Art") as Sprite2D

	assert_not_null(art, "the Look should hold a Sprite2D")
	if art != null:
		assert_not_null(art.texture, "the sprite should have a texture")
	assert_false((torch.get_node("Look/Bracket") as Polygon2D).visible, "the Bracket polygon is hidden, not deleted")


func test_a_torch_flame_is_an_animated_sprite_that_follows_the_flame_node() -> void:
	var torch := _in_tree("res://scenes/world/torch.tscn") as Torch
	var flame := torch.get_node("Flame") as Polygon2D
	var art := flame.get_node_or_null("Art") as AnimatedSprite2D

	assert_not_null(art, "the Flame should hold an AnimatedSprite2D")
	if art == null:
		return
	assert_eq(flame.color.a, 0.0, "the polygon itself is not drawn")
	assert_true(art.is_playing(), "the flame animates")
	assert_true(art.is_visible_in_tree(), "lit, the flame is drawn")
	torch.extinguish()
	assert_false(art.is_visible_in_tree(), "put out, the flame is not drawn")
	torch.relight()
	assert_true(art.is_visible_in_tree(), "lit again, the flame is drawn")


func test_a_flammable_flame_is_an_animated_sprite_drawn_only_while_it_burns() -> void:
	var flammable := _in_tree("res://scenes/world/flammable.tscn") as Flammable
	var flame := flammable.get_node("Flame") as Polygon2D
	var art := flame.get_node_or_null("Art") as AnimatedSprite2D

	assert_not_null(art, "the Flame should hold an AnimatedSprite2D")
	if art == null:
		return
	assert_eq(flame.color.a, 0.0, "the polygon itself is not drawn")
	assert_true(art.is_playing(), "the flame animates")
	assert_false(art.is_visible_in_tree(), "not burning, no flame")
	flammable.ignite()
	assert_true(art.is_visible_in_tree(), "burning, the flame is drawn")
	flammable.extinguish()
	assert_false(art.is_visible_in_tree(), "put out, no flame")


func test_every_drawn_pixel_of_every_image_under_assets_is_a_palette_colour() -> void:
	var palette := _palette()
	assert_gt(palette.size(), 0, "the palette should load")
	var files := _pngs(ASSETS_PATH)
	assert_gt(files.size(), 0, "there should be images to check")
	for path in files:
		var image := Image.new()
		var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		assert_eq(error, OK, "%s should load" % path)
		if error != OK:
			continue
		var off := 0
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.0 and not palette.has(pixel.to_html(false)):
					off += 1
		assert_eq(off, 0, "%s has %d pixels off the palette" % [path, off])


func _in_tree(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child_autofree(node)
	return node


func _palette() -> Array:
	var colours := []
	var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if file == null:
		return colours
	for line in file.get_as_text().split("\n"):
		var hex := line.strip_edges().trim_prefix("#").to_lower()
		if hex != "":
			colours.append(hex)
	return colours


# Every PNG below dir, except what is waiting in _incoming.
func _pngs(dir: String) -> Array:
	var found := []
	for sub in DirAccess.get_directories_at(dir):
		if sub != "_incoming":
			found.append_array(_pngs(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "png":
			found.append(dir.path_join(file))
	return found
