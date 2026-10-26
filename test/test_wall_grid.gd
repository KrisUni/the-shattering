extends GutTest
## Every Dungeons Room's walls lie on the 32-unit tile grid: north walls are a 64-unit face, south
## walls 40 thick, side walls 32 wide. Almos (radius 12) cannot walk into a north face, and the
## openings in Cell 3, Corridor 1 and the Lobby are wide enough for him to walk through.

const DUNGEONS_DIR := "res://scenes/areas/dungeons/"
# In pixels. The Room is 1152 x 648 and its tile is 32.
const TILE := 32.0
const ROOM_WIDTH := 1152.0
const ROOM_HEIGHT := 648.0
const NORTH_FACE := 64.0
const SOUTH_THICKNESS := 40.0
const SIDE_THICKNESS := 32.0
const ALMOS_RADIUS := 12.0
# In pixels. Almos's centre while he presses against a north face: 40 is inside the 64-unit face,
# and with his radius of 12 his body reaches y 28, well inside it.
const INSIDE_FACE_Y := 40.0
const WALLS_LAYER := 1
const PROBE_STEP := 8.0
# In pixels. The least an opening must be for Almos (24 across) to pass with room to spare.
const LEAST_OPENING := 128.0
# In pixels, in each Room's own coordinates. The centres of the openings in the north wall, read off
# the Room scenes' Exits.
const NORTH_OPENINGS := {
	"corridor_1": [192.0, 576.0, 960.0],
	"lobby": [576.0],
	"cell_3": [],
}
# In pixels. The centre of the opening in Corridor 1's south wall. (Cell 3's south opening is shut
# by its Roots, a path blocker, so it is not walkable until the Roots are burned.)
const SOUTH_OPENINGS := {
	"corridor_1": [576.0],
}


func _dungeons_room_names() -> Array[String]:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(DUNGEONS_DIR):
		if file.ends_with(".tscn") and file != "dungeons.tscn":
			names.append(file.get_basename())
	names.sort()
	return names


# Each wall's collision rectangle in the Room's own coordinates, as [name, Rect2].
func _wall_rects(room: Node) -> Array:
	var rects := []
	var walls := room.get_node_or_null("Walls")
	if walls == null:
		return rects
	for body in walls.get_children():
		if not body is StaticBody2D:
			continue
		for child in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var size: Vector2 = child.shape.size
				var centre: Vector2 = body.position + child.position
				rects.append([str(body.name), Rect2(centre - size / 2.0, size)])
	return rects


func _on_grid(value: float) -> bool:
	return is_equal_approx(fposmod(value, TILE), 0.0)


# Every Room with Walls, as a dictionary name -> rects.
func _all_rects() -> Dictionary:
	var all := {}
	for room_name in _dungeons_room_names():
		var room := (load(DUNGEONS_DIR + room_name + ".tscn") as PackedScene).instantiate()
		var rects := _wall_rects(room)
		room.free()
		if not rects.is_empty():
			all[room_name] = rects
	return all


func test_every_dungeons_room_has_walls_to_check() -> void:
	assert_eq(_all_rects().size(), 25, "25 Dungeons Rooms should have Walls")


func test_every_wall_edge_across_the_room_is_a_multiple_of_32() -> void:
	var off_grid := []
	var all := _all_rects()
	for room_name in all:
		for entry in all[room_name]:
			var rect: Rect2 = entry[1]
			if not (_on_grid(rect.position.x) and _on_grid(rect.end.x)):
				off_grid.append("%s/%s" % [room_name, entry[0]])
	assert_eq(off_grid, [], "walls with an x edge off the 32-unit grid")


func test_every_wall_edge_down_the_room_is_a_multiple_of_32_except_the_bottom() -> void:
	var off_grid := []
	var all := _all_rects()
	for room_name in all:
		for entry in all[room_name]:
			var rect: Rect2 = entry[1]
			var bottom_ok := _on_grid(rect.end.y) or is_equal_approx(rect.end.y, ROOM_HEIGHT)
			if not (_on_grid(rect.position.y) and bottom_ok):
				off_grid.append("%s/%s" % [room_name, entry[0]])
	assert_eq(off_grid, [], "walls with a y edge off the 32-unit grid")


func test_every_wall_stays_inside_the_room() -> void:
	var outside := []
	var all := _all_rects()
	for room_name in all:
		for entry in all[room_name]:
			if not Rect2(0, 0, ROOM_WIDTH, ROOM_HEIGHT).encloses(entry[1]):
				outside.append("%s/%s" % [room_name, entry[0]])
	assert_eq(outside, [], "walls reaching outside the Room")


func test_every_wall_on_the_north_edge_is_a_64_unit_face() -> void:
	var wrong := []
	var all := _all_rects()
	for room_name in all:
		for entry in all[room_name]:
			var rect: Rect2 = entry[1]
			var is_side := rect.size.y > NORTH_FACE and rect.size.x <= SIDE_THICKNESS
			if is_equal_approx(rect.position.y, 0.0) and not is_side \
					and not is_equal_approx(rect.size.y, NORTH_FACE):
				wrong.append("%s/%s is %s tall" % [room_name, entry[0], rect.size.y])
	assert_eq(wrong, [], "north walls not 64 tall")


func test_every_wall_on_the_south_edge_is_40_thick() -> void:
	var wrong := []
	var all := _all_rects()
	for room_name in all:
		for entry in all[room_name]:
			var rect: Rect2 = entry[1]
			var is_side := rect.size.y > NORTH_FACE and rect.size.x <= SIDE_THICKNESS
			if is_equal_approx(rect.end.y, ROOM_HEIGHT) and not is_side \
					and not is_equal_approx(rect.size.y, SOUTH_THICKNESS):
				wrong.append("%s/%s is %s thick" % [room_name, entry[0], rect.size.y])
	assert_eq(wrong, [], "south walls not 40 thick")


func test_every_wall_on_the_west_or_east_edge_that_runs_down_the_room_is_32_wide() -> void:
	var wrong := []
	var all := _all_rects()
	for room_name in all:
		for entry in all[room_name]:
			var rect: Rect2 = entry[1]
			var on_side_edge := is_equal_approx(rect.position.x, 0.0) \
					or is_equal_approx(rect.end.x, ROOM_WIDTH)
			if on_side_edge and rect.size.y > NORTH_FACE and not is_equal_approx(rect.size.x, SIDE_THICKNESS):
				wrong.append("%s/%s is %s wide" % [room_name, entry[0], rect.size.x])
	assert_eq(wrong, [], "side walls not 32 wide")


# Instances the Room in its own viewport (so it has a physics space) and waits for the physics to
# register its walls.
func _room_in_a_viewport(room_name: String) -> Room:
	var view := SubViewport.new()
	view.size = Vector2i(1152, 648)
	add_child_autofree(view)
	var room := (load(DUNGEONS_DIR + room_name + ".tscn") as PackedScene).instantiate() as Room
	view.add_child(room)
	await wait_physics_frames(2)
	return room


# True when a circle the size of Almos's body, centred at point, overlaps a wall.
func _blocked_at(room: Room, point: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = ALMOS_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, room.to_global(point))
	query.collision_mask = 1 << (WALLS_LAYER - 1)
	return not room.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func test_almos_cannot_walk_into_the_north_face_of_corridor_1_away_from_its_openings() -> void:
	var room := await _room_in_a_viewport("corridor_1")
	var got_in := []
	var x := 2.0 * TILE
	while x <= ROOM_WIDTH - 2.0 * TILE:
		# Corridor 1's three openings are x 128..256, 512..640 and 896..1024.
		var in_opening := (x > 128.0 and x < 256.0) or (x > 512.0 and x < 640.0) or (x > 896.0 and x < 1024.0)
		if not in_opening and not _blocked_at(room, Vector2(x, INSIDE_FACE_Y)):
			got_in.append(x)
		x += PROBE_STEP
	assert_eq(got_in, [], "x positions where he got into the face away from an opening")


func test_almos_cannot_walk_into_the_north_face_of_cell_3_anywhere() -> void:
	var room := await _room_in_a_viewport("cell_3")
	var free_xs := []
	var x := 2.0 * TILE
	while x <= ROOM_WIDTH - 2.0 * TILE:
		if not _blocked_at(room, Vector2(x, INSIDE_FACE_Y)):
			free_xs.append(x)
		x += PROBE_STEP
	assert_eq(free_xs, [], "Cell 3 has no opening in its north wall")


func test_almos_cannot_walk_into_the_north_face_of_the_lobby_beside_its_opening() -> void:
	var room := await _room_in_a_viewport("lobby")
	var free_xs := []
	var x := 2.0 * TILE
	while x <= ROOM_WIDTH - 2.0 * TILE:
		if not _blocked_at(room, Vector2(x, INSIDE_FACE_Y)):
			free_xs.append(x)
		x += PROBE_STEP
	# The Lobby's opening is x 512..640; his centre is free only strictly inside it.
	var outside := free_xs.filter(func(fx): return fx <= 512.0 or fx >= 640.0)
	assert_eq(outside, [], "he got into the face away from the Lobby's opening")


func test_almos_stops_at_the_bottom_of_a_north_face_in_corridor_1() -> void:
	var room := await _room_in_a_viewport("corridor_1")
	# Under the wall at x 64, his centre cannot come above y 64 + 12 = 76.
	assert_true(_blocked_at(room, Vector2(64.0, NORTH_FACE + ALMOS_RADIUS - 2.0)), "he should be stopped by the face")


func test_almos_can_stand_just_below_a_north_face_in_corridor_1() -> void:
	var room := await _room_in_a_viewport("corridor_1")
	assert_false(_blocked_at(room, Vector2(64.0, NORTH_FACE + ALMOS_RADIUS + 2.0)), "the floor under the face should be clear")


func test_almos_can_pass_through_each_north_opening_in_corridor_1_the_lobby_and_cell_3() -> void:
	var blocked := []
	for room_name in NORTH_OPENINGS:
		var room := await _room_in_a_viewport(room_name)
		for centre_x in NORTH_OPENINGS[room_name]:
			for y in [8.0, INSIDE_FACE_Y, 60.0, 80.0]:
				for dx in [-40.0, 0.0, 40.0]:
					if _blocked_at(room, Vector2(centre_x + dx, y)):
						blocked.append("%s x %s y %s" % [room_name, centre_x + dx, y])
	assert_eq(blocked, [], "points in a north opening where Almos is stopped")


func test_almos_can_pass_through_the_south_opening_in_corridor_1() -> void:
	var blocked := []
	for room_name in SOUTH_OPENINGS:
		var room := await _room_in_a_viewport(room_name)
		for centre_x in SOUTH_OPENINGS[room_name]:
			for y in [580.0, 612.0, 628.0]:
				for dx in [-40.0, 0.0, 40.0]:
					if _blocked_at(room, Vector2(centre_x + dx, y)):
						blocked.append("%s x %s y %s" % [room_name, centre_x + dx, y])
	assert_eq(blocked, [], "points in a south opening where Almos is stopped")


func test_every_exit_in_cell_3_corridor_1_and_the_lobby_is_at_least_128_wide() -> void:
	var narrow := []
	for room_name in ["cell_3", "corridor_1", "lobby"]:
		var room := (load(DUNGEONS_DIR + room_name + ".tscn") as PackedScene).instantiate()
		for exit in room.get_node("Exits").get_children():
			var shape := exit.get_node("CollisionShape2D").shape as RectangleShape2D
			if maxf(shape.size.x, shape.size.y) < LEAST_OPENING:
				narrow.append("%s/%s" % [room_name, exit.name])
		room.free()
	assert_eq(narrow, [], "exits narrower than 128")


func test_every_entrance_in_cell_3_corridor_1_and_the_lobby_is_clear_of_walls() -> void:
	var stuck := []
	for room_name in ["cell_3", "corridor_1", "lobby"]:
		var room := await _room_in_a_viewport(room_name)
		for exit in room.get_node("Exits").get_children():
			var entrance := exit.get_node("Entrance") as Marker2D
			if _blocked_at(room, room.to_local(entrance.global_position)):
				stuck.append("%s/%s" % [room_name, exit.name])
	assert_eq(stuck, [], "entrances where Almos would be inside a wall")
