extends GutTest
## Corridor 1 is drawn like Cell 3: a tiled earth floor and root/woven walls on the 16 art px grid
## (a 32-unit tile), every doorway left open, a root-wall strip on the Back entrance seal and a few
## root columns on the north wall. The placeholder floor and wall polygons stay in the scene, hidden.

const CORRIDOR_PATH := "res://scenes/areas/dungeons/corridor_1.tscn"
# In units. The tile of a Room, and its size.
const TILE := 32.0
# In tiles. The Room is 36 by 20 tiles, plus a quarter-tile strip at the south wall.
const COLUMNS := 36
const ROWS := 20
const WALL_NAMES := ["WallTop1", "WallTop2", "WallTop3", "WallTop4", "WallBottom1", "WallBottom2"]

var _room: Node2D


func before_each() -> void:
	_room = (load(CORRIDOR_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(_room)


func _layer(layer_name: String) -> TileMapLayer:
	return _room.get_node(layer_name) as TileMapLayer


func _drawn(cell: Vector2i) -> bool:
	return _layer("WallTiles").get_cell_source_id(cell) != -1 or _layer("WallTilesFront").get_cell_source_id(cell) != -1


func test_corridor_1_has_a_floor_layer_with_used_cells() -> void:
	var floor_layer := _layer("FloorTiles")
	assert_not_null(floor_layer, "Corridor 1 should have a floor TileMapLayer")
	assert_gt(floor_layer.get_used_cells().size(), 0, "the floor layer should have tiles")


func test_corridor_1_has_wall_layers_with_used_cells() -> void:
	for layer_name in ["WallTiles", "WallTilesFront"]:
		var layer := _layer(layer_name)
		assert_not_null(layer, "Corridor 1 should have a %s TileMapLayer" % layer_name)
		assert_gt(layer.get_used_cells().size(), 0, "%s should have tiles" % layer_name)


func test_the_tile_layers_draw_a_tile_of_16_art_px_at_scale_2() -> void:
	for layer_name in ["FloorTiles", "WallTiles", "WallTilesFront"]:
		var layer := _layer(layer_name)
		assert_eq(layer.tile_set.tile_size, Vector2i(16, 16), "%s tile is 16 art px" % layer_name)
		assert_eq(layer.scale, Vector2(2, 2), "%s draws one art px as 2 units" % layer_name)
		assert_eq(layer.position, Vector2.ZERO, "%s starts on the Room's corner" % layer_name)
		assert_eq(layer.tile_set.tile_size.x * layer.scale.x, TILE, "a tile is 32 units")


func test_the_floor_covers_every_tile_of_the_room() -> void:
	var floor_layer := _layer("FloorTiles")
	for x in COLUMNS:
		for y in ROWS:
			assert_ne(floor_layer.get_cell_source_id(Vector2i(x, y)), -1, "floor at %d, %d" % [x, y])


func test_the_floor_stays_inside_the_room_and_its_south_strip() -> void:
	for cell in _layer("FloorTiles").get_used_cells():
		assert_between(cell.x, 0, COLUMNS - 1, "floor column %d inside the Room" % cell.x)
		assert_between(cell.y, 0, ROWS, "floor row %d inside the Room or its strip" % cell.y)


func test_each_wall_is_drawn_by_tiles_where_it_collides() -> void:
	for wall_name in WALL_NAMES:
		var wall := _room.get_node("Walls/" + wall_name) as StaticBody2D
		var shape := wall.get_node("CollisionShape2D") as CollisionShape2D
		var size := (shape.shape as RectangleShape2D).size
		var top_left := wall.position - size / 2.0
		var first := Vector2i(floori(top_left.x / TILE), floori(top_left.y / TILE))
		var last := Vector2i(ceili((top_left.x + size.x) / TILE) - 1, ceili((top_left.y + size.y) / TILE) - 1)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				assert_true(_drawn(Vector2i(x, y)), "%s tile at %d, %d" % [wall_name, x, y])


func test_no_wall_tile_is_drawn_where_nothing_collides() -> void:
	var rects: Array[Rect2] = []
	for wall_name in WALL_NAMES:
		var wall := _room.get_node("Walls/" + wall_name) as StaticBody2D
		var size := ((wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		rects.append(Rect2(wall.position - size / 2.0, size))
	for layer_name in ["WallTiles", "WallTilesFront"]:
		for cell in _layer(layer_name).get_used_cells():
			var tile_rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
			var covered := false
			for rect in rects:
				covered = covered or rect.intersects(tile_rect)
			assert_true(covered, "%s tile at %d, %d sits on a wall" % [layer_name, cell.x, cell.y])


func test_every_doorway_cell_is_empty_of_wall_tiles() -> void:
	for exit_node in _room.get_node("Exits").get_children():
		var shape := (exit_node.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		var top_left: Vector2 = exit_node.position - shape.size / 2.0
		var first := Vector2i(floori(top_left.x / TILE), floori(top_left.y / TILE))
		var last := Vector2i(ceili((top_left.x + shape.size.x) / TILE) - 1, ceili((top_left.y + shape.size.y) / TILE) - 1)
		for x in range(maxi(first.x, 0), mini(last.x, COLUMNS - 1) + 1):
			for y in range(maxi(first.y, 0), mini(last.y, ROWS) + 1):
				# The east and west exits run the full height; only the doorways in a wall matter here.
				if shape.size.y > 100.0:
					continue
				assert_false(_drawn(Vector2i(x, y)), "%s doorway cell %d, %d has no wall tile" % [exit_node.name, x, y])


func test_the_south_walls_draw_in_front_of_almos_and_the_floor_behind_him() -> void:
	var back := _layer("WallTiles")
	assert_lt(_layer("FloorTiles").z_index, back.z_index, "the floor is behind the north walls")
	assert_lt(back.z_index, 0, "the north walls are behind Almos")
	assert_gt(_layer("WallTilesFront").z_index, 0, "the south walls are in front of Almos")


func test_the_placeholder_floor_and_walls_are_hidden_not_deleted() -> void:
	assert_false((_room.get_node("Floor") as Polygon2D).visible, "the placeholder floor is hidden")
	for wall_name in WALL_NAMES:
		var placeholder := _room.get_node("Walls/%s/Placeholder" % wall_name) as Polygon2D
		assert_not_null(placeholder, "%s keeps its Placeholder" % wall_name)
		assert_false(placeholder.visible, "%s Placeholder is hidden" % wall_name)


func test_the_back_entrance_seal_is_drawn_over_its_footprint_and_keeps_its_hidden_shape() -> void:
	var seal := _room.get_node("BackEntranceSeal") as Node2D
	var art := seal.get_node("Look/Art") as Sprite2D
	assert_not_null(art.texture, "the seal has art")
	assert_eq(art.texture.get_size() * art.scale, Vector2(16, 616), "the art covers the 16 by 616 footprint")
	assert_false((seal.get_node("Look/Shape") as Polygon2D).visible, "the placeholder shape is hidden")


func test_root_columns_are_decoration_on_the_north_wall_clear_of_every_doorway() -> void:
	var decor := _room.get_node("Decor") as Node2D
	assert_between(decor.get_child_count(), 1, 4, "a few root columns")
	assert_lt(decor.z_index, 0, "the columns draw behind Almos")
	var wall_top := Rect2(Vector2.ZERO, Vector2(COLUMNS * TILE, 2 * TILE))
	for column in decor.get_children():
		assert_true(column is Sprite2D, "%s is a sprite, with no collision" % column.name)
		var sprite := column as Sprite2D
		var drawn := Rect2(sprite.position - sprite.texture.get_size() * sprite.scale / 2.0, sprite.texture.get_size() * sprite.scale)
		assert_true(wall_top.encloses(drawn), "%s sits on the north wall face" % column.name)
		for x in range(floori(drawn.position.x / TILE), ceili(drawn.end.x / TILE)):
			for y in range(floori(drawn.position.y / TILE), ceili(drawn.end.y / TILE)):
				assert_true(_layer("WallTiles").get_cell_source_id(Vector2i(x, y)) != -1, "%s covers a wall tile at %d, %d" % [column.name, x, y])


func test_the_shared_path_blocker_stays_placeholder() -> void:
	var blocker := (load("res://scenes/world/path_blocker.tscn") as PackedScene).instantiate()
	autofree(blocker)
	assert_null(blocker.get_node_or_null("Look/Art"), "the shared path blocker has no art of its own")
