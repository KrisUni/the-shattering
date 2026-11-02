extends GutTest
## The solid root around Corridor 1 and the cells reads as deliberate darkness, so the eye stays on
## where Almos can walk: the root tile next to the walkable floor, a dithered blend one tile further,
## and a deep, near-black root tile with faint strands beyond, like a vignette. A Drop (Corridor 1's
## open edges) is all deep root, right up to the lane, so it reads as a fall and not a wall.

const ROOMS := ["corridor_1", "cell_1", "cell_2", "cell_3"]
const DUNGEONS_DIR := "res://scenes/areas/dungeons/"
const TILES_PATH := "res://assets/shared/dungeon_tiles/dungeon_tiles.png"
const MASS := Vector2i(5, 0)
const BLEND := Vector2i(1, 2)
const DEEP := Vector2i(0, 2)


func _room(room_name: String) -> Node2D:
	var room := (load(DUNGEONS_DIR + room_name + ".tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	return room


# Each Drop's rectangle in the Room, in units.
func _drop_rects(room: Node2D) -> Array:
	var rects := []
	var drops := room.get_node_or_null("Drops")
	if drops != null:
		for drop in drops.get_children():
			var footprint := drop as Footprint
			if footprint != null:
				rects.append(Rect2(footprint.position - footprint.size / 2.0, footprint.size))
	return rects


# How many tiles (counting diagonals as one) the cell is from the nearest walkable floor.
func _distance_to_floor(room: Node2D, cell: Vector2i) -> int:
	var back := room.get_node("WallTiles") as TileMapLayer
	var front := room.get_node("WallTilesFront") as TileMapLayer
	var best := 99
	for x in 36:
		for y in 19:
			var c := Vector2i(x, y)
			if back.get_cell_source_id(c) == -1 and front.get_cell_source_id(c) == -1:
				best = mini(best, maxi(absi(x - cell.x), absi(y - cell.y)))
	return best


func test_the_root_darkens_with_distance_from_the_walkable_floor() -> void:
	for room_name in ROOMS:
		var room := _room(room_name)
		var back := room.get_node("WallTiles") as TileMapLayer
		var deep := 0
		var drops := _drop_rects(room)
		for cell in back.get_used_cells():
			var tile := back.get_cell_atlas_coords(cell)
			if tile != MASS and tile != BLEND and tile != DEEP:
				continue
			var tile_rect := Rect2(Vector2(cell) * 32.0, Vector2(32.0, 32.0))
			if drops.any(func(rect: Rect2) -> bool: return rect.encloses(tile_rect)):
				assert_eq(tile, DEEP, "%s %s in a Drop is deep root" % [room_name, cell])
				deep += 1
				continue
			var d := _distance_to_floor(room, cell)
			if d <= 2:
				assert_eq(tile, MASS, "%s %s beside the floor is the root tile" % [room_name, cell])
			elif d == 3:
				assert_eq(tile, BLEND, "%s %s a step out is the blend" % [room_name, cell])
			else:
				assert_eq(tile, DEEP, "%s %s further out is deep root" % [room_name, cell])
				deep += 1
		assert_gt(deep, 100, "%s is mostly deep root around its walkable space" % room_name)


func test_the_deep_root_is_near_black_and_the_blend_lies_between() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(TILES_PATH))
	var brightness := func(tile: Vector2i) -> float:
		var total := 0.0
		for y in 16:
			for x in 16:
				total += image.get_pixel(tile.x * 16 + x, tile.y * 16 + y).get_luminance()
		return total / 256.0
	var deep: float = brightness.call(DEEP)
	var blend: float = brightness.call(BLEND)
	var mass: float = brightness.call(MASS)
	assert_lt(deep, 0.1, "deep root is near black")
	assert_lt(deep, blend, "the blend is lighter than deep root")
	assert_lt(blend, mass, "and darker than the root tile")
