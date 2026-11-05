extends GutTest
## Corridor 2, the guards' crossing east of the hall. Corridor 1's chasm runs on into its west third, so
## the two ways in from the hall stay apart: the high road along the north wall, in from the hall's
## lane, and the low road along the south wall, in from the platform, past the WCs' door and the
## Checkpoint, to where the chasm ends and the roads meet on the main floor. Three Nar jailers keep
## the floor: one at his post by the Interviews door, facing south, and two on patrols that cross in
## front of the way on east to Corridor 3. Barrels to hide in stand on both roads and by the Lockers.

const CORRIDOR_1_PATH := "res://scenes/areas/dungeons/corridor_1.tscn"
const CORRIDOR_2_PATH := "res://scenes/areas/dungeons/corridor_2.tscn"
const TILE := 32.0
const COLUMNS := 36
const ROWS := 19

var _room: Node2D
var _hall: Node2D


func before_each() -> void:
	_room = (load(CORRIDOR_2_PATH) as PackedScene).instantiate() as Node2D
	_hall = (load(CORRIDOR_1_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(_room)
	add_child_autofree(_hall)


func _chasm_cells(room: Node2D) -> Dictionary:
	var cells := {}
	for drop in room.get_node("Drops").get_children():
		var footprint := drop as Footprint
		var rect := Rect2(footprint.position - footprint.size / 2.0, footprint.size)
		for x in range(roundi(rect.position.x / TILE), roundi(rect.end.x / TILE)):
			for y in range(roundi(rect.position.y / TILE), ceili(rect.end.y / TILE)):
				cells[Vector2i(x, y)] = true
	return cells


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))


func _in_a_wall(cell: Vector2i) -> bool:
	var tile := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	for wall in _room.get_node("Walls").get_children():
		var shape := (wall.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		if Rect2((wall as Node2D).position - shape.size / 2.0, shape.size).intersects(tile):
			return true
	return false


# Firm ground reached a tile at a time from this cell, never into the chasm or a wall.
func _reached_from(start: Vector2i, chasm: Dictionary) -> Dictionary:
	var reached := {}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if reached.has(cell) or cell.x < 0 or cell.x >= COLUMNS or cell.y < 0 or cell.y >= ROWS:
			continue
		if chasm.has(cell) or _in_a_wall(cell):
			continue
		reached[cell] = true
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			frontier.append(cell + step)
	return reached


func _entrance(room: Node2D, exit_name: String) -> Vector2:
	var exit := room.get_node("Exits/" + exit_name) as Node2D
	return exit.position + (exit.get_node("Entrance") as Node2D).position


func _span(room: Node2D, exit_name: String) -> Vector2:
	var exit := room.get_node("Exits/" + exit_name) as Node2D
	var size := ((exit.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	return Vector2(exit.position.y - size.y / 2.0, exit.position.y + size.y / 2.0)


func test_the_chasm_runs_on_from_the_hall_across_the_rooms_edge() -> void:
	var here := _chasm_cells(_room)
	var hall := _chasm_cells(_hall)
	for row in range(2, 19):
		assert_eq(here.has(Vector2i(0, row)), hall.has(Vector2i(35, row)), "row %d meets the hall's east edge" % row)


func test_the_west_exits_line_up_with_the_halls_east_exits() -> void:
	assert_eq(_span(_room, "west"), _span(_hall, "east"), "the high road comes in where the hall's lane goes out")
	assert_eq(_span(_room, "west_low"), _span(_hall, "east_low"), "the low road comes in where the platform goes out")


func test_both_ways_in_land_on_firm_ground() -> void:
	var chasm := _chasm_cells(_room)
	for exit_name in ["west", "west_low"]:
		assert_false(chasm.has(_cell_of(_entrance(_room, exit_name))), "%s's Entrance is on firm ground" % exit_name)


func test_the_chasm_keeps_the_roads_apart_until_they_meet_on_the_main_floor() -> void:
	var chasm := _chasm_cells(_room)
	var high := _cell_of(_entrance(_room, "west"))
	var low := _cell_of(_entrance(_room, "west_low"))
	# Fenced to the west third, no firm ground joins the lane to the ledge.
	var fenced := chasm.duplicate()
	for y in range(0, ROWS):
		fenced[Vector2i(12, y)] = true
	assert_false(_reached_from(high, fenced).has(low), "the lane does not reach the low road in the west third")
	for y in range(7, 17):
		assert_true(chasm.has(Vector2i(0, y)), "the chasm divides them at the west edge, row %d" % y)
	assert_true(_reached_from(low, chasm).has(high), "the two roads meet further east")


func test_every_way_out_is_reached_from_both_ways_in() -> void:
	var chasm := _chasm_cells(_room)
	for start_exit in ["west", "west_low"]:
		var reached := _reached_from(_cell_of(_entrance(_room, start_exit)), chasm)
		for exit_name in ["east", "to_interviews", "to_wcs", "to_lockers_showers"]:
			assert_true(reached.has(_cell_of(_entrance(_room, exit_name))), "%s reaches %s" % [start_exit, exit_name])


func test_a_checkpoint_stands_on_the_low_road_by_the_wcs_door() -> void:
	var checkpoints := _room.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node.is_in_group(&"checkpoints"))
	assert_eq(checkpoints.size(), 1, "one Checkpoint")
	var at := (checkpoints[0] as Node2D).position
	var chasm := _chasm_cells(_room)
	assert_false(chasm.has(_cell_of(at)), "it stands on firm ground")
	assert_lt(at.distance_to(_entrance(_room, "to_wcs")), 128.0, "by the WCs' door")
	var high := _reached_from(_cell_of(_entrance(_room, "west")), chasm)
	var low := _reached_from(_cell_of(_entrance(_room, "west_low")), chasm)
	assert_true(low.has(_cell_of(at)), "on the low road")
	assert_true(high.has(_cell_of(at)), "and reached from the high road once the roads meet")


func test_a_jailer_stands_at_his_post_by_the_interviews_door_facing_south() -> void:
	var guard := _room.get_node("Guards/DoorGuard")
	assert_eq((guard.patrol as PackedVector2Array).size(), 0, "he keeps his post")
	assert_eq(guard.post_facing, Vector2.DOWN, "facing south over the floor")
	assert_lt((guard as Node2D).position.distance_to(_entrance(_room, "to_interviews")), 128.0, "by the Interviews door")


func test_two_jailers_patrol_routes_that_cross_in_front_of_the_way_east() -> void:
	var east := _room.get_node("Guards/CrossGuardEast")
	var south := _room.get_node("Guards/CrossGuardSouth")
	var across: PackedVector2Array = east.patrol
	var down: PackedVector2Array = south.patrol
	assert_eq(across.size(), 2, "one walks there and back")
	assert_eq(down.size(), 2, "and so does the other")
	assert_eq(across[0].y, across[1].y, "the first walks east and west")
	assert_eq(down[0].x, down[1].x, "the second walks north and south")
	var crossing := Vector2(down[0].x, across[0].y)
	assert_true(crossing.x > minf(across[0].x, across[1].x) and crossing.x < maxf(across[0].x, across[1].x), "their routes cross")
	assert_true(crossing.y > minf(down[0].y, down[1].y) and crossing.y < maxf(down[0].y, down[1].y), "their routes cross")
	assert_almost_eq(across[0].distance_to(across[1]), down[0].distance_to(down[1]), 0.5, "their rounds take as long, so the crossing keeps a rhythm")
	var chasm := _chasm_cells(_room)
	for point in [across[0], across[1], down[0], down[1]]:
		assert_false(chasm.has(_cell_of(point)), "no patrol point is over the chasm")
		assert_false(_in_a_wall(_cell_of(point)), "nor in a wall")


func test_barrels_to_hide_in_stand_on_both_roads_and_by_the_lockers() -> void:
	var chasm := _chasm_cells(_room)
	var barrels := _room.get_node("Furniture").get_children()
	assert_eq(barrels.size(), 3, "three barrels")
	for barrel in barrels:
		assert_false(chasm.has(_cell_of((barrel as Node2D).position)), "%s stands on firm ground" % barrel.name)
	assert_lt((_room.get_node("Furniture/BarrelLockers") as Node2D).position.distance_to(_entrance(_room, "to_lockers_showers")), 200.0, "one by the Lockers")


func test_the_room_is_dark() -> void:
	assert_not_null(_room.get_node_or_null("Darkness"), "he sees only a circle around himself")
