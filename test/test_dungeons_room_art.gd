extends GutTest
## Every Room of the Dungeons is drawn like Cell 3 and Corridor 1: a tiled earth floor and root and
## woven walls on the 16 art px grid (a 32-unit tile), drawn exactly where the walls collide, every
## doorway left open, the south walls in front of Almos, and the placeholder floor and wall polygons
## kept in the scene, hidden. Root columns, where a Room has them, sit on its north wall face.

const DUNGEONS_DIR := "res://scenes/areas/dungeons/"
# In units. The tile of a Room.
const TILE := 32.0
# In tiles. A Room is 36 by 20 tiles, plus a quarter-tile strip at the south wall.
const COLUMNS := 36
const ROWS := 20


func _room_paths() -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(DUNGEONS_DIR):
		if file_name.ends_with(".tscn") and file_name != "dungeons.tscn":
			paths.append(DUNGEONS_DIR + file_name)
	return paths


func _rooms() -> Array[Node2D]:
	var rooms: Array[Node2D] = []
	for path in _room_paths():
		var room := (load(path) as PackedScene).instantiate() as Node2D
		add_child_autofree(room)
		rooms.append(room)
	return rooms


func _wall_rects(room: Node2D) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for wall in room.get_node("Walls").get_children():
		var size := ((wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
		rects.append(Rect2((wall as Node2D).position - size / 2.0, size))
	# A Drop is drawn in root tiles too: the dark falling away below its open edge.
	var drops := room.get_node_or_null("Drops")
	if drops != null:
		for drop in drops.get_children():
			var footprint := drop as Footprint
			if footprint != null:
				rects.append(Rect2(footprint.position - footprint.size / 2.0, footprint.size))
	return rects


func _drawn(room: Node2D, cell: Vector2i) -> bool:
	return (room.get_node("WallTiles") as TileMapLayer).get_cell_source_id(cell) != -1 \
		or (room.get_node("WallTilesFront") as TileMapLayer).get_cell_source_id(cell) != -1


func test_there_are_all_the_rooms() -> void:
	assert_eq(_room_paths().size(), 25, "the Dungeons have 25 Rooms")


func test_every_room_has_the_three_tile_layers_at_scale_2_in_the_right_order() -> void:
	for room in _rooms():
		var floor_layer := room.get_node_or_null("FloorTiles") as TileMapLayer
		var back := room.get_node_or_null("WallTiles") as TileMapLayer
		var front := room.get_node_or_null("WallTilesFront") as TileMapLayer
		assert_not_null(floor_layer, "%s has a floor layer" % room.name)
		assert_not_null(back, "%s has a wall layer" % room.name)
		assert_not_null(front, "%s has a front wall layer" % room.name)
		if floor_layer == null or back == null or front == null:
			continue
		for layer in [floor_layer, back, front]:
			assert_eq(layer.scale, Vector2(2, 2), "%s %s draws one art px as 2 units" % [room.name, layer.name])
			assert_eq(layer.position, Vector2.ZERO, "%s %s starts on the Room's corner" % [room.name, layer.name])
			assert_eq(layer.tile_set.tile_size, Vector2i(16, 16), "%s %s tile is 16 art px" % [room.name, layer.name])
		assert_lt(floor_layer.z_index, back.z_index, "%s floor is behind the north walls" % room.name)
		assert_lt(back.z_index, 0, "%s north walls are behind Almos" % room.name)
		assert_gt(front.z_index, 0, "%s south walls are in front of Almos" % room.name)


func test_every_room_has_floor_on_every_tile_and_nowhere_outside() -> void:
	for room in _rooms():
		var floor_layer := room.get_node("FloorTiles") as TileMapLayer
		var missing := 0
		for x in COLUMNS:
			for y in ROWS:
				if floor_layer.get_cell_source_id(Vector2i(x, y)) == -1:
					missing += 1
		assert_eq(missing, 0, "%s has floor on every tile" % room.name)
		for cell in floor_layer.get_used_cells():
			assert_true(cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y <= ROWS, "%s floor at %s is inside the Room" % [room.name, cell])


func test_every_wall_is_drawn_where_it_collides_and_nowhere_else() -> void:
	for room in _rooms():
		var rects := _wall_rects(room)
		var undrawn: Array[String] = []
		for rect in rects:
			for x in range(floori(rect.position.x / TILE), ceili(rect.end.x / TILE)):
				for y in range(floori(rect.position.y / TILE), ceili(rect.end.y / TILE)):
					if not _drawn(room, Vector2i(x, y)):
						undrawn.append("%d,%d" % [x, y])
		assert_eq(undrawn, [] as Array[String], "%s draws every wall tile" % room.name)
		var stray: Array[String] = []
		for layer_name in ["WallTiles", "WallTilesFront"]:
			for cell in (room.get_node(layer_name) as TileMapLayer).get_used_cells():
				var tile_rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
				if not rects.any(func(rect: Rect2) -> bool: return rect.intersects(tile_rect)):
					stray.append("%s %d,%d" % [layer_name, cell.x, cell.y])
		assert_eq(stray, [] as Array[String], "%s draws no wall tile where nothing collides" % room.name)


func test_every_doorway_in_a_wall_is_left_open() -> void:
	for room in _rooms():
		for exit_node in room.get_node("Exits").get_children():
			var shape := (exit_node.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
			# The east and west exits run the full height; only the doorways in a wall matter here.
			if shape.size.y > 100.0:
				continue
			var top_left: Vector2 = exit_node.position - shape.size / 2.0
			for x in range(maxi(floori(top_left.x / TILE), 0), mini(ceili((top_left.x + shape.size.x) / TILE), COLUMNS)):
				for y in range(maxi(floori(top_left.y / TILE), 0), mini(ceili((top_left.y + shape.size.y) / TILE), ROWS + 1)):
					assert_false(_drawn(room, Vector2i(x, y)), "%s %s doorway cell %d, %d is open" % [room.name, exit_node.name, x, y])


func test_every_placeholder_floor_and_wall_is_hidden_not_deleted() -> void:
	for room in _rooms():
		assert_false((room.get_node("Floor") as Polygon2D).visible, "%s placeholder floor is hidden" % room.name)
		for wall in room.get_node("Walls").get_children():
			var placeholder := wall.get_node_or_null("Placeholder") as Polygon2D
			assert_not_null(placeholder, "%s %s keeps its Placeholder" % [room.name, wall.name])
			if placeholder != null:
				assert_false(placeholder.visible, "%s %s Placeholder is hidden" % [room.name, wall.name])


func test_root_columns_sit_on_a_north_wall_face_with_no_collision() -> void:
	for room in _rooms():
		var decor := room.get_node_or_null("Decor") as Node2D
		if decor == null:
			continue
		assert_lt(decor.z_index, 0, "%s columns draw behind Almos" % room.name)
		var back := room.get_node("WallTiles") as TileMapLayer
		for column in decor.get_children():
			assert_true(column is Sprite2D, "%s %s is a sprite, with no collision" % [room.name, column.name])
			var sprite := column as Sprite2D
			var size := sprite.texture.get_size() * sprite.scale
			var drawn := Rect2(sprite.position - size / 2.0, size)
			for x in range(floori(drawn.position.x / TILE), ceili(drawn.end.x / TILE)):
				for y in range(floori(drawn.position.y / TILE), ceili(drawn.end.y / TILE)):
					assert_ne(back.get_cell_source_id(Vector2i(x, y)), -1, "%s %s covers a wall tile at %d, %d" % [room.name, column.name, x, y])
