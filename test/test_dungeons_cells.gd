extends GutTest
## The Dungeons' three cells are cells: each closes its walkable space in with its own north face and
## side walls and solid root around it, keeps its door, its Entrance and where Almos wakes inside, is
## dressed with root bars either side of the door and a few props, and is lit by a lamp. They differ:
## each has its own size and its own dressing.
##
## And the Dungeons are lit by lamps, not pole torches: a lamp is a Torch (its flame can be Pulled
## and it lights the way as a torch does), drawn as a lantern.

const DUNGEONS_DIR := "res://scenes/areas/dungeons/"
const CELLS := ["cell_1", "cell_2", "cell_3"]
const LAMP_PATH := "res://scenes/world/lamp.tscn"
const STANDING_LAMP_PATH := "res://scenes/world/lamp_standing.tscn"


func _room(room_name: String) -> Node2D:
	var room := (load(DUNGEONS_DIR + room_name + ".tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	return room


func _inner_rect(room: Node2D) -> Rect2:
	var top := room.get_node("Walls/CellWallTop") as Node2D
	var left := room.get_node("Walls/CellWallLeft") as Node2D
	var right := room.get_node("Walls/CellWallRight") as Node2D
	var top_size := ((top.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	var side_size := ((left.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	var x0 := left.position.x + side_size.x / 2.0
	var x1 := right.position.x - side_size.x / 2.0
	var y0 := top.position.y + top_size.y / 2.0
	return Rect2(x0, y0, x1 - x0, 608.0 - y0)


func test_every_cell_is_closed_in_by_its_own_walls_and_solid_root() -> void:
	for cell_name in CELLS:
		var room := _room(cell_name)
		for wall in ["CellWallTop", "CellWallLeft", "CellWallRight", "RootMassTop", "RootMassLeft", "RootMassRight"]:
			assert_not_null(room.get_node_or_null("Walls/" + wall), "%s has %s" % [cell_name, wall])


func test_every_cell_keeps_its_door_and_entrance_inside() -> void:
	for cell_name in CELLS:
		var room := _room(cell_name)
		var inner := _inner_rect(room)
		var door := room.get_node("Exits/door") as Node2D
		var entrance := door.get_node("Entrance") as Node2D
		assert_true(inner.has_point(door.position + entrance.position), "%s's Entrance is inside the cell" % cell_name)
		assert_true(door.position.x - 64.0 >= inner.position.x and door.position.x + 64.0 <= inner.end.x, "%s's door opens from the cell" % cell_name)


func test_almos_wakes_inside_cell_3() -> void:
	var room := _room("cell_3")
	assert_true(_inner_rect(room).has_point(Vector2(576, 324)), "the middle of the Room, where he wakes, is in the cell")


func test_every_cell_has_bars_props_and_a_lit_lamp_inside() -> void:
	for cell_name in CELLS:
		var room := _room(cell_name)
		var inner := _inner_rect(room)
		assert_eq(room.get_node("Bars").get_child_count(), 2, "%s has bars either side of its door" % cell_name)
		assert_gte(room.get_node("Props").get_child_count(), 6, "%s is dressed" % cell_name)
		var lamps := room.get_children().filter(func(child: Node) -> bool: return child is Torch)
		assert_eq(lamps.size(), 1, "%s has one lamp" % cell_name)
		if not lamps.is_empty():
			var lamp := lamps[0] as Torch
			assert_true(lamp.lit, "%s's lamp burns" % cell_name)
			var on_its_face := lamp.position.x > inner.position.x and lamp.position.x < inner.end.x and lamp.position.y >= inner.position.y - 64.0
			assert_true(on_its_face, "%s's lamp is in the cell or on its north face" % cell_name)


func test_the_three_cells_differ() -> void:
	var shapes := {}
	var dressings := {}
	for cell_name in CELLS:
		var room := _room(cell_name)
		shapes[str(_inner_rect(room))] = true
		var names: Array[String] = []
		for prop in room.get_node("Props").get_children():
			names.append(String(prop.name).rstrip("0123456789"))
		names.sort()
		dressings[",".join(names)] = true
	assert_eq(shapes.size(), 3, "each cell has its own size")
	assert_eq(dressings.size(), 3, "each cell has its own dressing")


func test_the_dungeons_are_lit_by_lamps_not_pole_torches() -> void:
	for file_name in DirAccess.get_files_at(DUNGEONS_DIR):
		if not file_name.ends_with(".tscn") or file_name == "dungeons.tscn":
			continue
		var room := _room(file_name.get_basename())
		for child in room.get_children():
			if child is Torch:
				assert_true(child.scene_file_path in [LAMP_PATH, STANDING_LAMP_PATH], "%s %s is a lamp" % [file_name, child.name])


func test_a_lamp_is_a_torch_drawn_as_a_lantern() -> void:
	for path in [LAMP_PATH, STANDING_LAMP_PATH]:
		var lamp := (load(path) as PackedScene).instantiate()
		add_child_autofree(lamp)
		assert_true(lamp is Torch, "%s can be drawn from and lights the way" % path)
		assert_true(lamp.is_in_group(&"torches"), "%s is with the torches" % path)
		var art := lamp.get_node("Look/Art") as Sprite2D
		assert_string_contains(art.texture.resource_path, "assets/shared/lamp/", "%s is drawn as a lantern" % path)
		assert_eq(art.scale, Vector2(2, 2), "one art px is 2 units")
		var flame := lamp.get_node("Flame/Art") as AnimatedSprite2D
		assert_string_contains(flame.sprite_frames.get_frame_texture(&"burn", 0).resource_path, "lamp_lit", "%s's flame glows in its glass" % path)


func test_a_lamp_goes_dark_when_its_flame_is_drawn() -> void:
	var lamp := (load(LAMP_PATH) as PackedScene).instantiate() as Torch
	add_child_autofree(lamp)
	assert_true((lamp.get_node("Flame") as CanvasItem).visible, "lit, its glass glows")
	lamp.draw()
	assert_false(lamp.lit, "its flame is taken")
	assert_false((lamp.get_node("Flame") as CanvasItem).visible, "its glass goes dark")
