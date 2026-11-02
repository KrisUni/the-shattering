extends GutTest
## Corridor 1, the hall Almos comes out into from Cell 3, is a stealth stretch: a lane three
## Almos-widths wide that one guard walks from end to end, with big rocks and barrels spread on both
## sides of it, by the north wall between the cell doors and along the south edge, to hide in while
## he goes by. Here: he patrols the whole length, the route
## and the doorways are clear, and in the real Dungeons he walks his whole round past Almos hidden in
## the barrel by Cell 3 without noticing him, while he catches him standing in the open.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const CORRIDOR_PATH := "res://scenes/areas/dungeons/corridor_1.tscn"
const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const JAILER_PATH := "res://data/nar_jailer.tres"
const WALLS_LAYER := 1
# In units. The radius of Almos's body and of a guard's.
const BODY_RADIUS := 12.0
const TAP_FRAMES := 3

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func _corridor_in_a_viewport() -> Room:
	var view := SubViewport.new()
	view.size = Vector2i(1152, 648)
	add_child_autofree(view)
	var room := (load(CORRIDOR_PATH) as PackedScene).instantiate() as Room
	view.add_child(room)
	await wait_physics_frames(2)
	return room


func _guards(room: Node) -> Array:
	return room.get_node("Guards").get_children()


# Whether a body of BODY_RADIUS moving from a to b (Room coordinates) would hit anything solid.
func _path_blocked(room: Room, a: Vector2, b: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, room.to_global(a))
	query.motion = b - a
	query.collision_mask = WALLS_LAYER
	var result := room.get_world_2d().direct_space_state.cast_motion(query)
	return result[0] < 1.0


func test_one_guard_walks_the_hall_from_one_end_to_the_other() -> void:
	var room := await _corridor_in_a_viewport()
	var guards := _guards(room)
	assert_eq(guards.size(), 1, "one guard")
	var guard = guards[0]
	assert_eq(guard.tuning, load(JAILER_PATH), "a jailer, who Blocks and Parries")
	assert_false(guard.named, "an ordinary guard, back after a rest")
	var xs: Array[float] = []
	for point in guard.patrol:
		xs.append(point.x)
		assert_almost_eq(point.y, 176.0, 0.01, "his route runs down the middle of the lane")
	assert_lt(xs.min(), 128.0, "it reaches the west end")
	assert_gt(xs.max(), 1024.0, "and the east end")


func test_the_furniture_leaves_every_cell_door_clear() -> void:
	var room := await _corridor_in_a_viewport()
	for door in ["to_cell_2", "to_cell_3"]:
		var exit_node := room.get_node("Exits/" + door) as Node2D
		for node in room.get_node("Furniture").get_children():
			# Only what stands in the row along the north wall, where the doors are.
			if not node is Node2D or (node as Node2D).position.y > 140.0:
				continue
			assert_gt(absf((node as Node2D).position.x - exit_node.position.x), 64.0 + 20.0, "%s stands clear of %s" % [node.name, door])


func test_there_are_places_to_hide_along_his_path() -> void:
	var room := await _corridor_in_a_viewport()
	var spots := room.get_node("Furniture").get_children().filter(func(n: Node) -> bool: return n is HidingSpot)
	assert_gte(spots.size(), 4, "barrels to hide in")
	var xs: Array[float] = []
	for spot in spots:
		assert_true(spot.is_in_group(&"hiding_spots"), "%s can be got into" % spot.name)
		xs.append((spot as Node2D).position.x)
		# Each stands off his lane, by the north wall or along the south edge of the hall.
		var y: float = (spot as Node2D).position.y
		var by_the_north_wall := y > 64.0 and y <= 128.0
		# The south edge of the lane, or a ledge reaching out over the chasm.
		var by_the_south_edge := y >= 200.0 and y <= 288.0
		assert_true(by_the_north_wall or by_the_south_edge, "%s stands off his lane, by the north wall or the south edge" % spot.name)
	var sides := spots.map(func(spot: Node) -> bool: return (spot as Node2D).position.y > 140.0)
	assert_true(sides.has(true) and sides.has(false), "spread on both sides of the hall")
	xs.sort()
	for i in range(1, xs.size()):
		assert_lt(xs[i] - xs[i - 1], 400.0, "no long stretch of the hall without a place to hide")


func test_a_hiding_spot_is_beside_cell_3s_door() -> void:
	var room := await _corridor_in_a_viewport()
	var entrance := room.get_node("Exits/to_cell_3/Entrance") as Node2D
	var at := room.to_local(entrance.global_position)
	var near := false
	for node in room.get_node("Furniture").get_children():
		if node is HidingSpot and (node as Node2D).position.distance_to(at) <= 160.0:
			near = true
	assert_true(near, "a spot within a few steps of where he comes out")


func test_every_patrol_route_is_clear_of_walls_and_crates() -> void:
	var room := await _corridor_in_a_viewport()
	for guard in _guards(room):
		var route: PackedVector2Array = guard.patrol
		var points := [guard.position] + Array(route)
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()] if i > 0 else route[0]
			assert_false(_path_blocked(room, a, b), "%s walks clear from %s to %s" % [guard.name, a, b])


func test_nothing_solid_stands_in_a_doorway_or_on_an_entrance() -> void:
	var room := await _corridor_in_a_viewport()
	for exit_node in room.get_node("Exits").get_children():
		var entrance := exit_node.get_node("Entrance") as Node2D
		var at := room.to_local(entrance.global_position)
		assert_false(_path_blocked(room, at, at + Vector2(0.01, 0)), "%s's Entrance is clear" % exit_node.name)


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = Vector2i(1152, 648)
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func test_hidden_in_the_barrel_by_cell_3_a_whole_patrol_round_goes_by_without_noticing_him() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var dungeons := host.current_space as DungeonsBuilding
	var corridor := dungeons.room(&"corridor_1")
	var entrance := corridor.get_node("Exits/to_cell_3/Entrance") as Node2D
	var barrel: HidingSpot = null
	for node in corridor.get_node("Furniture").get_children():
		var spot := node as HidingSpot
		if spot != null and (barrel == null or spot.global_position.distance_to(entrance.global_position) < barrel.global_position.distance_to(entrance.global_position)):
			barrel = spot
	host.current_space.put_almos_at(barrel.global_position + Vector2(0, 8))
	await wait_physics_frames(2)
	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(2)
	assert_true(host.almos.hiding, "he is in the barrel")
	var guard = corridor.get_node("Guards/Guard")
	var tuning := load(JAILER_PATH) as EnemyTuning
	var round_length := 0.0
	for i in guard.patrol.size():
		round_length += guard.patrol[i].distance_to(guard.patrol[(i + 1) % guard.patrol.size()])
	var round_seconds: float = round_length / tuning.patrol_speed + tuning.patrol_pause * guard.patrol.size()
	var noticed := false
	var frames := ceili(round_seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await wait_physics_frames(1)
		for g in corridor.get_node("Guards").get_children():
			noticed = noticed or g.in_pursuit
		if noticed:
			break
	assert_false(noticed, "no guard noticed him in the barrel for a whole round")
	assert_true(host.almos.hiding, "and he is still hidden")


func test_standing_in_the_open_on_a_route_he_is_caught() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var dungeons := host.current_space as DungeonsBuilding
	var corridor := dungeons.room(&"corridor_1")
	var guard = corridor.get_node("Guards/Guard")
	# Ahead of the guard on his route, within his Sight.
	var tuning := load(JAILER_PATH) as EnemyTuning
	var ahead: Vector2 = guard.global_position + guard.facing * (tuning.sight_length_full - 40.0)
	host.current_space.put_almos_at(ahead)
	var noticed := false
	for i in 30:
		await wait_physics_frames(1)
		noticed = noticed or guard.in_pursuit
	assert_true(noticed, "the guard saw him in the open")
