extends GutTest
## Cell 3 is drawn: a tiled earth floor and root/woven walls on the 16 art px grid (a 32-unit tile),
## with its metal Gate and the tile layers drawn in front of or behind Almos by where they stand. The
## placeholder floor and wall polygons stay in the scene, hidden.

const CELL_3_PATH := "res://scenes/areas/dungeons/cell_3.tscn"
# In pixels. The tile of a Room, and its size.
const TILE := 32.0
const ROOM_WIDTH := 1152.0
const ROOM_HEIGHT := 648.0
# In tiles. The Room is 36 by 20 tiles, plus a quarter-tile strip at the south wall.
const COLUMNS := 36
const ROWS := 20
const WALL_NAMES := ["WallTop", "WallBottom1", "WallBottom2", "WallLeft", "WallRight"]

var _room: Node2D


func before_each() -> void:
	_room = (load(CELL_3_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(_room)


func test_cell_3_has_a_floor_layer_with_used_cells() -> void:
	var floor_layer := _room.get_node("FloorTiles") as TileMapLayer
	assert_not_null(floor_layer, "Cell 3 should have a floor TileMapLayer")
	assert_gt(floor_layer.get_used_cells().size(), 0, "the floor layer should have tiles")


func test_cell_3_has_wall_layers_with_used_cells() -> void:
	for layer_name in ["WallTiles", "WallTilesFront"]:
		var layer := _room.get_node(layer_name) as TileMapLayer
		assert_not_null(layer, "Cell 3 should have a %s TileMapLayer" % layer_name)
		assert_gt(layer.get_used_cells().size(), 0, "%s should have tiles" % layer_name)


func test_the_tile_layers_draw_a_tile_of_32_art_px_at_scale_1() -> void:
	for layer_name in ["FloorTiles", "WallTiles", "WallTilesFront"]:
		var layer := _room.get_node(layer_name) as TileMapLayer
		assert_eq(layer.tile_set.tile_size, Vector2i(32, 32), "%s tile is 32 art px" % layer_name)
		assert_eq(layer.scale, Vector2(1, 1), "%s draws one art px as 1 unit" % layer_name)
		assert_eq(layer.position, Vector2.ZERO, "%s starts on the Room's corner" % layer_name)
		assert_eq(layer.tile_set.tile_size.x * layer.scale.x, TILE, "a tile is 32 units")


func test_the_floor_covers_every_tile_of_the_room() -> void:
	var floor_layer := _room.get_node("FloorTiles") as TileMapLayer
	for x in COLUMNS:
		for y in ROWS:
			assert_ne(floor_layer.get_cell_source_id(Vector2i(x, y)), -1, "floor at %d, %d" % [x, y])


func test_the_floor_stays_inside_the_room_and_its_south_strip() -> void:
	var floor_layer := _room.get_node("FloorTiles") as TileMapLayer
	for cell in floor_layer.get_used_cells():
		assert_between(cell.x, 0, COLUMNS - 1, "floor column %d inside the Room" % cell.x)
		assert_between(cell.y, 0, ROWS, "floor row %d inside the Room or its strip" % cell.y)


func test_each_wall_is_drawn_by_tiles_where_it_collides() -> void:
	var back := _room.get_node("WallTiles") as TileMapLayer
	var front := _room.get_node("WallTilesFront") as TileMapLayer
	for wall_name in WALL_NAMES:
		var wall := _room.get_node("Walls/" + wall_name) as StaticBody2D
		var shape := wall.get_node("CollisionShape2D") as CollisionShape2D
		var size := (shape.shape as RectangleShape2D).size
		var top_left := wall.position - size / 2.0
		var first := Vector2i(floori(top_left.x / TILE), floori(top_left.y / TILE))
		var last := Vector2i(ceili((top_left.x + size.x) / TILE) - 1, ceili((top_left.y + size.y) / TILE) - 1)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var cell := Vector2i(x, y)
				var drawn := back.get_cell_source_id(cell) != -1 or front.get_cell_source_id(cell) != -1
				assert_true(drawn, "%s tile at %d, %d" % [wall_name, x, y])


func test_the_south_opening_has_no_wall_tiles() -> void:
	var front := _room.get_node("WallTilesFront") as TileMapLayer
	var door_column := floori(576.0 / TILE)
	assert_eq(front.get_cell_source_id(Vector2i(door_column, 19)), -1, "no wall tile in the doorway")


func test_the_south_walls_draw_in_front_of_almos_and_the_floor_behind_him() -> void:
	var floor_layer := _room.get_node("FloorTiles") as TileMapLayer
	var back := _room.get_node("WallTiles") as TileMapLayer
	var front := _room.get_node("WallTilesFront") as TileMapLayer
	assert_lt(floor_layer.z_index, back.z_index, "the floor is behind the north and side walls")
	assert_lt(back.z_index, 0, "the north and side walls are behind Almos")
	assert_gt(front.z_index, 0, "the south walls are in front of Almos")


func test_the_placeholder_floor_and_walls_are_hidden_not_deleted() -> void:
	assert_false((_room.get_node("Floor") as Polygon2D).visible, "the placeholder floor is hidden")
	for wall_name in WALL_NAMES:
		var placeholder := _room.get_node("Walls/%s/Placeholder" % wall_name) as Polygon2D
		assert_not_null(placeholder, "%s keeps its Placeholder" % wall_name)
		assert_false(placeholder.visible, "%s Placeholder is hidden" % wall_name)


func test_the_gate_is_drawn_across_its_footprint_and_keeps_its_hidden_shape() -> void:
	var gate := _room.get_node("Gate") as MetalGate
	assert_not_null(gate, "a metal gate shuts the doorway")
	var art := gate.get_node("Look/Art") as Sprite2D
	assert_not_null(art.texture, "the gate has art")
	assert_eq(art.texture.get_size().x * art.scale.x, gate.size.x, "the art spans the doorway")
	# Its feet are drawn level with the feet of the cell's bars on either side, below the footprint's
	# foot, down in the doorway.
	var foot := gate.position.y + art.position.y + art.texture.get_size().y * art.scale.y / 2.0
	var bars := _room.get_node("Bars/BarsLeft") as Sprite2D
	var bars_foot := bars.position.y + bars.texture.get_size().y * bars.scale.y / 2.0
	assert_almost_eq(foot, bars_foot, 0.01, "its bars stand level with the cell's bars")
	assert_gte(foot - gate.position.y, gate.size.y / 2.0, "and not above the footprint's foot")
	assert_false((gate.get_node("Look/Shape") as Polygon2D).visible, "the placeholder shape is hidden")


func test_the_test_room_blocker_stays_placeholder() -> void:
	var blocker := (load("res://scenes/world/path_blocker.tscn") as PackedScene).instantiate()
	autofree(blocker)
	assert_null(blocker.get_node_or_null("Look/Art"), "the shared path blocker has no art of its own")
