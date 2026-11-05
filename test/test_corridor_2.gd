extends GutTest
## Corridor 2, the guards' crossing east of the hall. Corridor 1's chasm runs on through it, and its
## two ways in never meet, nor see each other until the last steps before the locked door at its east edge, which the
## Jailer's key opens. The high road is a short strip along the north wall, in from the hall's lane,
## past the Interviews door, with a wall along its south side that hides it from the rest of the
## Room; three Nar jailers keep it, one at his post by the Interviews door, facing south, and two on
## rounds that cross. The low road runs in from the platform along the south wall, past a
## Checkpoint, then winds over the chasm on switchback stairs, up, along, down and up again, to the
## landing before the same door. At the top of the first flight, on his left, is the door to the
## store cupboard. No Jump, not even a sprinting one, carries Almos from one road to the other.

const CORRIDOR_1_PATH := "res://scenes/areas/dungeons/corridor_1.tscn"
const CORRIDOR_2_PATH := "res://scenes/areas/dungeons/corridor_2.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const KEY := &"dungeons/jailers_key"
const TILE := 32.0
# In tiles: how near the landing before the door the low road comes before the high road shows.
const NEAR_THE_DOOR := 4
const COLUMNS := 36
const ROWS := 19

var _room: Node2D
var _hall: Node2D


func before_each() -> void:
	WorldState.reset()
	_room = (load(CORRIDOR_2_PATH) as PackedScene).instantiate() as Node2D
	_hall = (load(CORRIDOR_1_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(_room)
	add_child_autofree(_hall)


func after_each() -> void:
	WorldState.reset()


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


# Firm ground reached a tile at a time from this cell, never into a blocked cell, a wall or off the Room.
func _reached_from(start: Vector2i, blocked: Dictionary) -> Dictionary:
	var reached := {}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if reached.has(cell) or cell.x < 0 or cell.x >= COLUMNS or cell.y < 0 or cell.y >= ROWS:
			continue
		if blocked.has(cell) or _in_a_wall(cell):
			continue
		reached[cell] = true
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			frontier.append(cell + step)
	return reached


# How many steps each cell of this ground is from the start.
func _distances(start: Vector2i, ground: Dictionary) -> Dictionary:
	var distance := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if ground.has(next) and not distance.has(next):
				distance[next] = distance[cell] + 1
				queue.append(next)
	return distance


func _entrance(room: Node2D, exit_name: String) -> Vector2:
	var exit := room.get_node("Exits/" + exit_name) as Node2D
	return exit.position + (exit.get_node("Entrance") as Node2D).position


func _span(room: Node2D, exit_name: String) -> Vector2:
	var exit := room.get_node("Exits/" + exit_name) as Node2D
	var size := ((exit.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	return Vector2(exit.position.y - size.y / 2.0, exit.position.y + size.y / 2.0)


# The landing before the locked door, where the roads meet: the two columns before it, from the
# high road's way down to it to the low road's way up to it.
func _landing() -> Dictionary:
	var door := _cell_of(_entrance(_room, "east"))
	var cells := {}
	for x in range(door.x - 1, door.x + 1):
		for y in range(door.y - 4, door.y + 3):
			cells[Vector2i(x, y)] = true
	return cells


# Each road on its own: what is reached from its way in with the landing before the door shut off.
func _roads() -> Dictionary:
	var blocked := _chasm_cells(_room)
	blocked.merge(_landing())
	return {
		"high": _reached_from(_cell_of(_entrance(_room, "west")), blocked),
		"low": _reached_from(_cell_of(_entrance(_room, "west_low")), blocked),
	}


func test_the_chasm_runs_on_from_the_hall_across_the_rooms_edge() -> void:
	var here := _chasm_cells(_room)
	var hall := _chasm_cells(_hall)
	for row in range(2, 19):
		if _in_a_wall(Vector2i(0, row)):
			assert_true(hall.has(Vector2i(35, row)), "row %d: the wall stands where the hall's chasm meets it" % row)
			continue
		assert_eq(here.has(Vector2i(0, row)), hall.has(Vector2i(35, row)), "row %d meets the hall's east edge" % row)


func test_the_west_exits_line_up_with_the_halls_east_exits() -> void:
	assert_eq(_span(_room, "west"), _span(_hall, "east"), "the high road comes in where the hall's lane goes out")
	assert_eq(_span(_room, "west_low"), _span(_hall, "east_low"), "the low road comes in where the platform goes out")


func test_the_two_roads_never_meet_before_the_door() -> void:
	var roads := _roads()
	for cell in roads["high"]:
		assert_false(roads["low"].has(cell), "the roads share no ground: %s" % cell)
	var chasm := _chasm_cells(_room)
	var door := _cell_of(_entrance(_room, "east"))
	assert_true(_reached_from(_cell_of(_entrance(_room, "west")), chasm).has(door), "the high road leads to the door")
	assert_true(_reached_from(_cell_of(_entrance(_room, "west_low")), chasm).has(door), "and so does the low road")


func test_no_jump_carries_him_from_one_road_to_the_other() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	var longest: float = tuning.sprint_speed * tuning.jump_duration
	var roads := _roads()
	var nearest := INF
	for a: Vector2i in roads["high"]:
		for b: Vector2i in roads["low"]:
			# The gap between the two tiles' facing edges.
			var gap := Vector2(maxf(absi(a.x - b.x) - 1, 0), maxf(absi(a.y - b.y) - 1, 0)) * TILE
			nearest = minf(nearest, gap.length())
	assert_gt(nearest, longest, "the chasm between them is wider than a sprinting Jump")


func test_the_side_doors_are_shared_out_between_the_roads() -> void:
	var roads := _roads()
	assert_true(roads["high"].has(_cell_of(_entrance(_room, "to_interviews"))), "Interviews is off the high road")
	assert_true(roads["low"].has(_cell_of(_entrance(_room, "to_store_cupboard"))), "the store cupboard is off the low road")
	var exits := _room.get_node("Exits").get_children().map(func(exit: Node) -> String: return str(exit.name))
	exits.sort()
	assert_eq(exits, ["east", "to_interviews", "to_store_cupboard", "west", "west_low"], "no other door: the south wall is whole")


func test_the_store_cupboards_door_is_on_his_left_at_the_top_of_the_first_flight() -> void:
	var flight := _room.get_node("Stairs/FlightUp") as Sprite2D
	var top := flight.position + Vector2(flight.texture.get_width() / 2.0, 0.0)
	var door := (_room.get_node("Exits/to_store_cupboard") as Node2D).position
	assert_lt(door.x, flight.position.x, "west of the flight: on his left as he comes up")
	assert_lt(absf(door.y - (top.y - TILE)), TILE * 1.5, "level with the flight's top")
	assert_lt(door.distance_to(top), TILE * 3.0, "a step or two from it")


func test_the_wall_hides_each_road_from_the_other() -> void:
	var darkness := _room.get_node("Darkness") as Darkness
	var eye := Node2D.new()
	_room.add_child(eye)
	darkness.target = eye
	var roads := _roads()
	var hidden := 0
	var landing := _landing()
	for at: Vector2i in roads["low"]:
		# In the last few steps before the landing, where the roads meet, the high road's way down
		# to it comes into sight.
		if landing.keys().any(func(cell: Vector2i) -> bool: return maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= NEAR_THE_DOOR):
			continue
		eye.position = Vector2(at) * TILE + Vector2(TILE / 2.0, TILE / 2.0)
		for cell: Vector2i in roads["high"]:
			var point := _room.to_global(Vector2(cell) * TILE + Vector2(TILE / 2.0, TILE / 2.0))
			assert_false(darkness.shows(point), "from %s on the low road, %s on the high road is out of sight" % [at, cell])
			hidden += 1
	assert_gt(hidden, 0, "control: there was something to hide")
	# The wall hides it: without walls, the dark circle alone would show some of it.
	eye.position = Vector2(14 * TILE, 12.5 * TILE)
	assert_true(eye.global_position.distance_to(_room.to_global(Vector2(14 * TILE, 6 * TILE))) < darkness.sight_radius,
		"control: the high road is within his circle from the stairs")


func test_the_low_road_winds_over_three_flights_of_stairs() -> void:
	var flights := _room.get_node("Stairs").get_children()
	assert_eq(flights.size(), 3, "three flights")
	var chasm := _chasm_cells(_room)
	var low: Dictionary = _roads()["low"]
	var door := _cell_of(_entrance(_room, "east"))
	for flight in flights:
		var sprite := flight as Sprite2D
		var rect := Rect2(sprite.position, sprite.texture.get_size())
		var cells := {}
		for x in range(roundi(rect.position.x / TILE), roundi(rect.end.x / TILE)):
			for y in range(roundi(rect.position.y / TILE), roundi(rect.end.y / TILE)):
				cells[Vector2i(x, y)] = true
				assert_false(chasm.has(Vector2i(x, y)), "%s is firm ground" % sprite.name)
				assert_true(low.has(Vector2i(x, y)), "%s is on the low road" % sprite.name)
		# Each flight is the only way on: without it the low road does not reach the door.
		var blocked := chasm.duplicate()
		blocked.merge(cells)
		assert_false(_reached_from(_cell_of(_entrance(_room, "west_low")), blocked).has(door), "the way goes over %s" % sprite.name)


func test_a_locked_door_shuts_the_way_east_until_the_jailers_key_opens_it() -> void:
	var door := _room.get_node("LockedDoor") as MainEntrance
	assert_eq(door.key, KEY, "it takes the Jailer's key")
	assert_true(door.is_in_group(&"main_entrances"), "Almos opens it as he does the Main entrance")
	var shape := (door.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var body := Rect2(door.position - shape.size / 2.0, shape.size)
	var exit := _room.get_node("Exits/east") as Node2D
	var exit_shape := ((exit.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	assert_true(body.encloses(Rect2(Vector2(body.position.x, exit.position.y - exit_shape.y / 2.0), Vector2(shape.size.x, exit_shape.y))), "it fills the doorway")
	assert_false(door.open, "it stands shut")
	assert_false(door.open_with_key(), "without the key it stays shut")
	WorldState.record_taken(KEY)
	assert_true(door.open_with_key(), "with the key it opens")


func test_a_checkpoint_stands_on_the_low_road_near_where_he_comes_in() -> void:
	var checkpoints := _room.find_children("*", "", true, false).filter(
		func(node: Node) -> bool: return node.is_in_group(&"checkpoints"))
	assert_eq(checkpoints.size(), 1, "one Checkpoint")
	var at := (checkpoints[0] as Node2D).position
	assert_true(_roads()["low"].has(_cell_of(at)), "on the low road")
	assert_lt(at.distance_to(_entrance(_room, "west_low")), 160.0, "a few steps from where he comes in")


func test_the_guards_keep_the_high_road() -> void:
	var high: Dictionary = _roads()["high"]
	var guards := _room.get_node("Guards").get_children()
	assert_eq(guards.size(), 3, "three jailers")
	for guard in guards:
		assert_true(high.has(_cell_of((guard as Node2D).position)), "%s is on the high road" % guard.name)
		for point in guard.patrol:
			assert_true(high.has(_cell_of(point)), "%s walks only the high road" % guard.name)


func test_a_jailer_stands_at_his_post_by_the_interviews_door_facing_south() -> void:
	var guard := _room.get_node("Guards/DoorGuard")
	assert_eq((guard.patrol as PackedVector2Array).size(), 0, "he keeps his post")
	assert_eq(guard.post_facing, Vector2.DOWN, "facing south over the floor")
	assert_lt((guard as Node2D).position.distance_to(_entrance(_room, "to_interviews")), 128.0, "by the Interviews door")


func test_two_jailers_patrol_routes_that_cross() -> void:
	var across: PackedVector2Array = _room.get_node("Guards/CrossGuardEast").patrol
	var down: PackedVector2Array = _room.get_node("Guards/CrossGuardSouth").patrol
	assert_eq(across.size(), 2, "one walks there and back")
	assert_eq(down.size(), 2, "and so does the other")
	assert_eq(across[0].y, across[1].y, "the first walks east and west")
	assert_eq(down[0].x, down[1].x, "the second walks north and south")
	var crossing := Vector2(down[0].x, across[0].y)
	assert_true(crossing.x > minf(across[0].x, across[1].x) and crossing.x < maxf(across[0].x, across[1].x), "their routes cross")
	assert_true(crossing.y > minf(down[0].y, down[1].y) and crossing.y < maxf(down[0].y, down[1].y), "their routes cross")


func test_barrels_to_hide_in_stand_on_the_high_road() -> void:
	var high: Dictionary = _roads()["high"]
	var barrels := _room.get_node("Furniture").get_children()
	assert_eq(barrels.size(), 3, "three barrels")
	for barrel in barrels:
		assert_true(high.has(_cell_of((barrel as Node2D).position)), "%s stands on the high road" % barrel.name)


func test_the_room_is_dark() -> void:
	assert_not_null(_room.get_node_or_null("Darkness"), "he sees only a circle around himself")
