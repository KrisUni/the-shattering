extends GutTest
## The walls of the test room and the test areas lie on the 32-unit tile grid: north walls are a
## 64-unit face and Almos (radius 12) cannot walk into one, except through the openings in the test
## building's north and south doors.

const TILE := 32.0
const NORTH_FACE := 64.0
const SIDE_THICKNESS := 32.0
const ALMOS_RADIUS := 12.0
# In pixels. Almos's centre while he presses against a north face: his body reaches y 28, inside it.
const INSIDE_FACE_Y := 40.0
const WALLS_LAYER := 1
const PROBE_STEP := 8.0
# In pixels. Each scene's size, the size of the area its walls enclose.
const SCENES := {
	"res://scenes/test_room.tscn": Vector2(1152.0, 648.0),
	"res://scenes/areas/test_building.tscn": Vector2(1152.0, 648.0),
	"res://scenes/areas/test_open_map.tscn": Vector2(2304.0, 1296.0),
	"res://scenes/areas/test_open_map_2.tscn": Vector2(1728.0, 972.0),
	"res://scenes/areas/upper_tree_placeholder.tscn": Vector2(1152.0, 648.0),
}
const TEST_ROOM := "res://scenes/test_room.tscn"
const TEST_BUILDING := "res://scenes/areas/test_building.tscn"
const OPEN_MAPS := [
	"res://scenes/areas/test_open_map.tscn",
	"res://scenes/areas/test_open_map_2.tscn",
]
# In pixels. The north-wall opening of the test building's Room B and the south-wall opening of its
# Room C, centred at x 576 in each Room's own coordinates.
const DOOR_CENTRE_X := 576.0


# Each wall's collision rectangle in its area's coordinates, as [label, Rect2], over every node
# called Walls under the scene root (the test building has one per Room).
func _wall_rects(root: Node) -> Array:
	var rects := []
	for walls in root.find_children("Walls", "Node2D", true, false):
		for body in walls.get_children():
			if not body is StaticBody2D:
				continue
			for child in body.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					var size: Vector2 = child.shape.size
					var centre: Vector2 = body.position + child.position
					var label := "%s/%s" % [walls.get_parent().name, body.name]
					rects.append([label, Rect2(centre - size / 2.0, size)])
	return rects


# Each wall's drawn rectangle (the bounds of its Placeholder polygon) in its area's coordinates, as
# [label, Rect2], in the same order as _wall_rects. A wall with no Placeholder polygon gets an empty
# Rect2.
func _drawn_rects(root: Node) -> Array:
	var rects := []
	for walls in root.find_children("Walls", "Node2D", true, false):
		for body in walls.get_children():
			if not body is StaticBody2D:
				continue
			var has_shape := false
			for child in body.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					has_shape = true
			if not has_shape:
				continue
			var label := "%s/%s" % [walls.get_parent().name, body.name]
			var face := body.get_node_or_null("Placeholder") as Polygon2D
			if face == null or face.polygon.is_empty():
				rects.append([label, Rect2()])
				continue
			var low := face.polygon[0]
			var high := face.polygon[0]
			for point in face.polygon:
				low = low.min(point)
				high = high.max(point)
			rects.append([label, Rect2(body.position + face.position + low, high - low)])
	return rects


func _on_grid(value: float) -> bool:
	return is_equal_approx(fposmod(value, TILE), 0.0)


func _is_side(rect: Rect2) -> bool:
	return rect.size.y > NORTH_FACE and rect.size.x <= SIDE_THICKNESS


func _rects_of(path: String) -> Array:
	var root := (load(path) as PackedScene).instantiate()
	var rects := _wall_rects(root)
	root.free()
	return rects


func test_every_test_area_has_walls_to_check() -> void:
	var empty := []
	for path in SCENES:
		if _rects_of(path).is_empty():
			empty.append(path)
	assert_eq(empty, [], "scenes with no walls found")


func test_every_wall_edge_across_the_test_areas_is_a_multiple_of_32() -> void:
	var off_grid := []
	for path in SCENES:
		for entry in _rects_of(path):
			var rect: Rect2 = entry[1]
			if not (_on_grid(rect.position.x) and _on_grid(rect.end.x)):
				off_grid.append("%s %s" % [path, entry[0]])
	assert_eq(off_grid, [], "walls with an x edge off the 32-unit grid")


func test_every_wall_edge_down_the_test_areas_is_a_multiple_of_32_except_the_bottom() -> void:
	var off_grid := []
	for path in SCENES:
		for entry in _rects_of(path):
			var rect: Rect2 = entry[1]
			var bottom_ok := _on_grid(rect.end.y) or is_equal_approx(rect.end.y, SCENES[path].y)
			if not (_on_grid(rect.position.y) and bottom_ok):
				off_grid.append("%s %s" % [path, entry[0]])
	assert_eq(off_grid, [], "walls with a y edge off the 32-unit grid")


func test_every_wall_on_the_north_edge_of_a_test_area_is_a_64_unit_face() -> void:
	var wrong := []
	for path in SCENES:
		for entry in _rects_of(path):
			var rect: Rect2 = entry[1]
			if is_equal_approx(rect.position.y, 0.0) and not _is_side(rect) \
					and not is_equal_approx(rect.size.y, NORTH_FACE):
				wrong.append("%s %s is %s tall" % [path, entry[0], rect.size.y])
	assert_eq(wrong, [], "north walls not 64 tall")


func test_every_wall_on_the_west_or_east_edge_of_a_test_area_is_32_wide() -> void:
	var wrong := []
	for path in SCENES:
		for entry in _rects_of(path):
			var rect: Rect2 = entry[1]
			var on_side_edge := is_equal_approx(rect.position.x, 0.0) \
					or is_equal_approx(rect.end.x, SCENES[path].x)
			if on_side_edge and rect.size.y > NORTH_FACE and not is_equal_approx(rect.size.x, SIDE_THICKNESS):
				wrong.append("%s %s is %s wide" % [path, entry[0], rect.size.x])
	assert_eq(wrong, [], "side walls not 32 wide")


func test_every_south_wall_of_a_test_area_ends_at_the_bottom_of_the_area() -> void:
	var wrong := []
	for path in SCENES:
		for entry in _rects_of(path):
			var rect: Rect2 = entry[1]
			if rect.position.y > SCENES[path].y / 2.0 and rect.size.x >= 512.0 \
					and not is_equal_approx(rect.end.y, SCENES[path].y):
				wrong.append("%s %s ends at %s" % [path, entry[0], rect.end.y])
	assert_eq(wrong, [], "south walls not reaching the bottom edge")


func test_every_wall_of_a_test_area_is_drawn_where_it_collides() -> void:
	var mismatched := []
	for path in SCENES:
		var root := (load(path) as PackedScene).instantiate()
		var collides := _wall_rects(root)
		var drawn := _drawn_rects(root)
		root.free()
		for i in collides.size():
			if not collides[i][1].is_equal_approx(drawn[i][1]):
				mismatched.append("%s %s collides %s, drawn %s" % [path, collides[i][0], collides[i][1], drawn[i][1]])
	assert_eq(mismatched, [], "walls drawn somewhere other than where they collide")


# Instances the scene in its own viewport (so it has a physics space) and waits for the physics to
# register its walls.
func _scene_in_a_viewport(path: String) -> Node2D:
	var view := SubViewport.new()
	view.size = Vector2i(1152, 648)
	add_child_autofree(view)
	var scene := (load(path) as PackedScene).instantiate() as Node2D
	view.add_child(scene)
	await wait_physics_frames(2)
	return scene


# True when a circle the size of Almos's body, centred at the scene's point, overlaps a wall.
func _blocked_at(scene: Node2D, point: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = ALMOS_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, scene.to_global(point))
	query.collision_mask = 1 << (WALLS_LAYER - 1)
	return not scene.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


# The x positions along the north face where Almos's centre is free to enter it.
func _free_xs_in_the_north_face(scene: Node2D, width: float) -> Array:
	var free_xs := []
	var x := 2.0 * TILE
	while x <= width - 2.0 * TILE:
		if not _blocked_at(scene, Vector2(x, INSIDE_FACE_Y)):
			free_xs.append(x)
		x += PROBE_STEP
	return free_xs


func test_almos_cannot_walk_into_the_north_face_of_the_test_room() -> void:
	var scene := await _scene_in_a_viewport(TEST_ROOM)
	assert_eq(_free_xs_in_the_north_face(scene, 1152.0), [], "x positions where he got into the test room's north face")


func test_almos_cannot_walk_into_the_north_face_of_the_first_open_map() -> void:
	var scene := await _scene_in_a_viewport(OPEN_MAPS[0])
	assert_eq(_free_xs_in_the_north_face(scene, 2304.0), [], "x positions where he got into the first open map's north face")


func test_almos_cannot_walk_into_the_north_face_of_the_second_open_map() -> void:
	var scene := await _scene_in_a_viewport(OPEN_MAPS[1])
	assert_eq(_free_xs_in_the_north_face(scene, 1728.0), [], "x positions where he got into the second open map's north face")


func test_almos_can_stand_just_below_the_north_face_of_the_test_room() -> void:
	var scene := await _scene_in_a_viewport(TEST_ROOM)
	assert_false(_blocked_at(scene, Vector2(576.0, NORTH_FACE + ALMOS_RADIUS + 2.0)), "the floor under the face should be clear")


func test_almos_cannot_walk_into_the_north_face_of_building_room_b_beside_its_door() -> void:
	var scene := await _scene_in_a_viewport(TEST_BUILDING)
	var room_b := scene.get_node("RoomB") as Node2D
	var got_in := []
	var x := 2.0 * TILE
	while x <= 1152.0 - 2.0 * TILE:
		# The opening is x 512..640; his centre is free only strictly inside it.
		var in_opening := x > 512.0 and x < 640.0
		if not in_opening and not _blocked_at(room_b, Vector2(x, INSIDE_FACE_Y)):
			got_in.append(x)
		x += PROBE_STEP
	assert_eq(got_in, [], "x positions where he got into Room B's face away from the door")


func test_almos_can_pass_through_the_north_door_of_building_room_b() -> void:
	var scene := await _scene_in_a_viewport(TEST_BUILDING)
	var room_b := scene.get_node("RoomB") as Node2D
	var blocked := []
	for y in [8.0, INSIDE_FACE_Y, 60.0, 80.0]:
		for dx in [-40.0, 0.0, 40.0]:
			if _blocked_at(room_b, Vector2(DOOR_CENTRE_X + dx, y)):
				blocked.append("x %s y %s" % [DOOR_CENTRE_X + dx, y])
	assert_eq(blocked, [], "points in the north door where Almos is stopped")


func test_almos_can_pass_through_the_south_door_of_building_room_c() -> void:
	var scene := await _scene_in_a_viewport(TEST_BUILDING)
	var room_c := scene.get_node("RoomC") as Node2D
	var blocked := []
	for y in [580.0, 612.0, 628.0]:
		for dx in [-40.0, 0.0, 40.0]:
			if _blocked_at(room_c, Vector2(DOOR_CENTRE_X + dx, y)):
				blocked.append("x %s y %s" % [DOOR_CENTRE_X + dx, y])
	assert_eq(blocked, [], "points in the south door where Almos is stopped")


func test_almos_cannot_walk_into_the_south_wall_of_building_room_c_beside_its_door() -> void:
	var scene := await _scene_in_a_viewport(TEST_BUILDING)
	var room_c := scene.get_node("RoomC") as Node2D
	# Under the left bottom wall (x 0..512), his centre at y 620 puts his body inside y 608..648.
	assert_true(_blocked_at(room_c, Vector2(256.0, 620.0)), "he should be stopped by the south wall")
