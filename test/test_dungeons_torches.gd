extends GutTest
## The Dungeons are lit by torches: every Room has at least one, lit. A torch on a north wall
## stands against a wall tile, clear of every doorway, and no torch's bracket is hidden behind a
## south wall. Cell 3's torch stands on the floor within Pull's reach of the spot by the roots.

const DUNGEONS_DIR := "res://scenes/areas/dungeons/"
const PULL_PATH := "res://data/pull.tres"
# In units. The tile of a Room.
const TILE := 32.0
# In units, in Cell 3. Where Almos stands to Pull the torch's flame and Shove it at the roots
# (as in test_dungeons_cell.gd).
const CELL_3_STANDING_SPOT := Vector2(560.0, 340.0)


func _rooms() -> Array[Node2D]:
	var rooms: Array[Node2D] = []
	for file_name in DirAccess.get_files_at(DUNGEONS_DIR):
		if file_name.ends_with(".tscn") and file_name != "dungeons.tscn":
			var room := (load(DUNGEONS_DIR + file_name) as PackedScene).instantiate() as Node2D
			add_child_autofree(room)
			rooms.append(room)
	return rooms


func _torches(room: Node2D) -> Array[Torch]:
	var torches: Array[Torch] = []
	for child in room.get_children():
		if child is Torch:
			torches.append(child as Torch)
	return torches


func _bracket_rect(torch: Torch) -> Rect2:
	var art := torch.get_node("Look/Art") as Sprite2D
	return Rect2(torch.position + art.position, art.texture.get_size() * art.scale)


func test_every_room_has_a_lit_torch() -> void:
	for room in _rooms():
		var torches := _torches(room)
		assert_gt(torches.size(), 0, "%s has a torch" % room.name)
		for torch in torches:
			assert_true(torch.lit, "%s %s is lit" % [room.name, torch.name])
			assert_true(torch.is_in_group(&"torches"), "%s %s can be drawn from" % [room.name, torch.name])


func test_the_corridors_have_more_torches_than_the_rooms() -> void:
	for room in _rooms():
		if String(room.name).contains("Corridor"):
			assert_gte(_torches(room).size(), 3, "%s has at least three torches" % room.name)


func test_a_wall_torch_stands_against_a_north_wall_tile_clear_of_every_doorway() -> void:
	for room in _rooms():
		var back := room.get_node("WallTiles") as TileMapLayer
		for torch in _torches(room):
			if torch.position.y > 2.0 * TILE:
				continue
			var bracket := _bracket_rect(torch)
			for x in range(floori(bracket.position.x / TILE), ceili(bracket.end.x / TILE)):
				var cell := Vector2i(x, 1)
				assert_ne(back.get_cell_source_id(cell), -1, "%s %s has a wall behind it at %d" % [room.name, torch.name, x])
			for exit_node in room.get_node("Exits").get_children():
				var shape := (exit_node.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
				var exit_rect := Rect2((exit_node as Node2D).position - shape.size / 2.0, shape.size)
				assert_false(exit_rect.intersects(bracket), "%s %s is clear of %s" % [room.name, torch.name, exit_node.name])


func test_no_torch_bracket_is_hidden_behind_a_south_wall() -> void:
	for room in _rooms():
		var front := room.get_node("WallTilesFront") as TileMapLayer
		for torch in _torches(room):
			var bracket := _bracket_rect(torch)
			for x in range(floori(bracket.position.x / TILE), ceili(bracket.end.x / TILE)):
				for y in range(floori(bracket.position.y / TILE), ceili(bracket.end.y / TILE)):
					assert_eq(front.get_cell_source_id(Vector2i(x, y)), -1, "%s %s is not behind a south wall at %d, %d" % [room.name, torch.name, x, y])


func test_cell_3s_torch_is_within_pull_reach_of_the_spot_by_the_roots() -> void:
	var cell := (load(DUNGEONS_DIR + "cell_3.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(cell)
	var reach: float = (load(PULL_PATH) as Resource).get("flame_range")
	var nearest := INF
	for torch in _torches(cell):
		nearest = minf(nearest, torch.position.distance_to(CELL_3_STANDING_SPOT))
	assert_lt(nearest, reach, "a torch is within Pull's flame range of the standing spot")
