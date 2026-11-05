extends GutTest
## Corridor 1's lane runs above a chasm, crossed by one winding bridge (narrow spans either side of a
## landing) down to a platform out in the chasm and on east to Corridor 2: the chasm is made of Drops, open edges Almos can walk off, with a ragged
## lip mirrored along the lane, and it runs off the Room's west, east and south edges with no wall. Walking or rolling off one is a Deadly fall (he drops out of sight and dies,
## and his Remains are left at the edge); an enemy Shoved or Pulled into one falls to its death and
## no enemy walks into one by itself; a barrel knocked into one is gone until enemies return. A
## wardrobe or barrel on the edge lets him out on the lane side.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const CORRIDOR_PATH := "res://scenes/areas/dungeons/corridor_1.tscn"
const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const BARREL_SCENE := preload("res://scenes/world/barrel.tscn")
const SHOVE_PATH := "res://data/shove.tres"
const TAP_FRAMES := 2
# In Room units: a spot on the lane above the west Drop, and how far below its edge he goes.
const ON_THE_LANE := Vector2(300.0, 190.0)
const DROP_TOP := 224.0

var _almos_input: AlmosInput
var _room: Node2D


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_room = (load(CORRIDOR_PATH) as PackedScene).instantiate() as Node2D
	# The guard is not wanted here: nothing but what each test puts in.
	var guards := _room.get_node("Guards")
	_room.remove_child(guards)
	guards.free()
	add_child_autofree(_room)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _almos_at(point: Vector2):
	var almos = _almos_input.spawn_almos()
	almos.global_position = _room.to_global(point)
	return almos


func _drop_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for drop in _room.get_node("Drops").get_children():
		var footprint := drop as Footprint
		rects.append(Rect2(footprint.position - footprint.size / 2.0, footprint.size))
	return rects


func _in_the_chasm(point: Vector2) -> bool:
	return _drop_rects().any(func(rect: Rect2) -> bool: return rect.has_point(point))


func test_the_chasm_has_a_mirrored_lip_and_runs_off_the_room() -> void:
	var rects := _drop_rects()
	assert_gt(rects.size(), 2, "a ragged lip, made of several Drops")
	for rect in rects:
		assert_gte(rect.position.y, DROP_TOP, "%s leaves the lane whole" % rect)
	# Along the lane, away from the bridge, the lip is the same either side of the centre. Below it
	# the bridge's spur west (the loop round the barricade) has no twin.
	for x in range(16, 480, 32):
		for y in range(232, 288, 16):
			assert_eq(_in_the_chasm(Vector2(x, y)), _in_the_chasm(Vector2(1152 - x, y)), "the lip mirrors at %d, %d" % [x, y])
	assert_true(_in_the_chasm(Vector2(4, 400)), "off the west edge")
	assert_true(_in_the_chasm(Vector2(1148, 400)), "off the east edge")
	assert_true(_in_the_chasm(Vector2(200, 644)), "off the south edge")


func test_a_winding_bridge_crosses_the_chasm_from_the_lane_to_the_east_platform() -> void:
	var exit := _room.get_node("Exits/east_low") as Node2D
	# A walk of firm ground from the lane down to the exit, a tile at a time, never stepping into the chasm.
	var reached := {}
	var frontier := [Vector2i(18, 6)]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if reached.has(cell) or cell.x < 0 or cell.x > 35 or cell.y < 6 or cell.y > 20:
			continue
		if _in_the_chasm(Vector2(cell) * 32.0 + Vector2(16, 16)):
			continue
		reached[cell] = true
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			frontier.append(cell + step)
	var exit_cell := Vector2i(35, floori(exit.position.y / 32.0))
	assert_true(reached.has(exit_cell), "the bridge reaches the platform and the way on to Corridor 2")
	assert_true(reached.has(Vector2i(20, 16)), "the bridge itself turns east to the platform")
	var columns := {}
	for cell: Vector2i in reached:
		if cell.y >= 10:
			columns[cell.x] = true
	assert_gte(columns.size(), 5, "it winds: its spans do not all run down one line")
	var narrowest := 99
	# The bridge alone, between the spur to Radio/Officers (west) and the path down to the east
	# platform.
	for row in range(9, 18):
		var width := 0
		for x in range(13, 24):
			if reached.has(Vector2i(x, row)):
				width += 1
		narrowest = mini(narrowest, width)
	assert_eq(narrowest, 2, "it narrows to a span two tiles wide, room enough to pass")
	for wall_name in ["MassWest", "MassEast", "MassWestEdge", "MassEastEdge", "WallBottom1", "WallBottom2"]:
		assert_null(_room.get_node_or_null("Walls/" + wall_name), "no %s framing it" % wall_name)


func test_a_path_from_the_east_ledge_leads_down_to_a_platform_and_on_to_corridor_2() -> void:
	var exit := _room.get_node("Exits/east_low") as RoomExit
	var entrance := exit.get_node("Entrance") as Node2D
	assert_false(_in_the_chasm(exit.position + entrance.position), "his way in from Corridor 2 is firm ground")
	# Firm ground, a tile at a time, from the lane down the east ledge to the platform and the exit.
	var reached := {}
	var frontier := [Vector2i(28, 6)]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if reached.has(cell) or cell.x < 0 or cell.x > 35 or cell.y < 6 or cell.y > 20:
			continue
		if _in_the_chasm(Vector2(cell) * 32.0 + Vector2(16, 16)):
			continue
		reached[cell] = true
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			frontier.append(cell + step)
	assert_true(reached.has(Vector2i(35, floori(exit.position.y / 32.0))), "the path reaches the east edge")
	var platform := 0
	for x in range(24, 32):
		for y in range(13, 19):
			if reached.has(Vector2i(x, y)):
				platform += 1
	assert_gte(platform, 20, "a small platform out in the chasm on the way")
	var graph := load("res://data/dungeons_room_graph.tres") as RoomGraph
	assert_eq(graph.exits.get("corridor_1/east_low"), "corridor_2/west_low", "it leads into Corridor 2")
	assert_eq(graph.exits.get("corridor_2/west_low"), "corridor_1/east_low", "and back")


func test_walking_off_the_edge_is_a_deadly_fall() -> void:
	var almos = _almos_at(ON_THE_LANE)
	var places: Array = []
	almos.died.connect(func(place: Vector2) -> void: places.append(place))
	await wait_physics_frames(2)
	_almos_input.press_action(&"move_down")
	for i in 60:
		await wait_physics_frames(1)
		if almos.dead:
			break
	_almos_input.release_action(&"move_down")
	assert_true(almos.dead, "he fell to his death")
	assert_eq(places.size(), 1, "one Death")
	assert_false(_in_the_chasm(_room.to_local(places[0])), "its Remains place is on firm ground, at the edge")
	await wait_physics_frames(30)
	assert_lt((almos.get_node("Look") as Node2D).scale.x, 1.0, "he drops out of sight")


func test_he_is_back_to_his_size_when_returned() -> void:
	var almos = _almos_at(ON_THE_LANE)
	await wait_physics_frames(2)
	_almos_input.press_action(&"move_down")
	for i in 60:
		await wait_physics_frames(1)
		if almos.dead:
			break
	_almos_input.release_action(&"move_down")
	await wait_physics_frames(30)
	almos.return_to(_room.to_global(ON_THE_LANE))
	var look := almos.get_node("Look") as Node2D
	assert_eq(look.scale, Vector2.ONE, "full size")
	assert_eq(look.modulate, Color.WHITE, "and seen")
	await wait_physics_frames(10)
	assert_false(almos.dead, "and standing on the lane, alive")


func test_an_enemy_does_not_walk_into_a_drop() -> void:
	var jailer := JAILER_SCENE.instantiate()
	jailer.position = ON_THE_LANE
	jailer.patrol = PackedVector2Array([ON_THE_LANE, ON_THE_LANE + Vector2(0, 200)])
	_room.add_child(jailer)
	await wait_seconds(3.0)
	assert_lt(jailer.position.y, DROP_TOP, "it stopped at the edge")
	assert_false(jailer.dead, "alive")


func test_an_enemy_shoved_into_a_drop_falls_to_its_death() -> void:
	var almos = _almos_at(ON_THE_LANE + Vector2(0, -60))
	almos.facing = Vector2.DOWN
	var jailer := JAILER_SCENE.instantiate()
	jailer.position = ON_THE_LANE + Vector2(0, -10)
	_room.add_child(jailer)
	var died := [false]
	(jailer.get_node("Health") as Health).depleted.connect(func() -> void: died[0] = true)
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_seconds((load(SHOVE_PATH) as SpellCost).distance / (load(SHOVE_PATH) as SpellCost).move_speed + 0.3)
	assert_true(died[0], "it fell down the Drop")


func test_a_barrel_knocked_into_a_drop_is_gone_until_enemies_return() -> void:
	# On the east of the lane, where nothing but chasm is below it: under the west of the lane the
	# spur round the barricade runs close enough to catch a barrel knocked off.
	var east_of_the_lane := Vector2(1152.0 - ON_THE_LANE.x, ON_THE_LANE.y)
	var almos = _almos_at(east_of_the_lane + Vector2(0, -70))
	almos.facing = Vector2.DOWN
	var barrel := BARREL_SCENE.instantiate() as HidingSpot
	barrel.position = east_of_the_lane + Vector2(0, -20)
	_room.add_child(barrel)
	var lift := barrel.get_node("Liftable")
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_seconds(0.8)
	assert_eq(lift.state, Liftable.State.BROKEN, "it fell in and is gone")
	assert_false((barrel.get_node("Look") as CanvasItem).visible, "nothing of it shows")
	barrel.flammable.come_back()
	await wait_physics_frames(2)
	assert_eq(lift.state, Liftable.State.RESTING, "whole again when enemies return")
	assert_false(_in_the_chasm(barrel.position), "back on firm ground where it stood")


func test_the_props_on_the_edge_let_him_out_on_the_lane_side() -> void:
	for node in _room.get_node("Furniture").get_children():
		var spot := node as HidingSpot
		if spot == null:
			continue
		var out := spot.position + spot.exit_offset
		for corner in [Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12), Vector2(12, 12)]:
			assert_false(_in_the_chasm(out + corner), "%s lets him out on firm ground, not down the Drop" % spot.name)
