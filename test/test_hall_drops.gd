extends GutTest
## Corridor 1's lane runs above a chasm, crossed by one bridge to the south exit: the chasm is made of
## Drops, open edges Almos can walk off, mirrored either side of the bridge with a ragged lip, and it
## runs off the Room's west, east and south edges with no wall around it. Walking or rolling off one is a Deadly fall (he drops out of sight and dies,
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


func test_the_chasm_is_mirrored_either_side_of_a_bridge_and_runs_off_the_room() -> void:
	var rects := _drop_rects()
	assert_gt(rects.size(), 2, "a ragged lip, made of several Drops")
	for rect in rects:
		var mirrored := Rect2(Vector2(1152.0 - rect.end.x, rect.position.y), rect.size)
		assert_true(rects.has(mirrored), "%s has its mirror image across the bridge" % rect)
		assert_eq(rect.end.y, 648.0, "%s runs off the south edge" % rect)
		assert_gte(rect.position.y, DROP_TOP, "%s leaves the lane whole" % rect)
	assert_true(_in_the_chasm(Vector2(4, 400)), "off the west edge")
	assert_true(_in_the_chasm(Vector2(1148, 400)), "off the east edge")
	for y in range(240, 640, 16):
		assert_false(_in_the_chasm(Vector2(576, y)), "the bridge is solid at %d" % y)
	for wall_name in ["MassWest", "MassEast", "MassWestEdge", "MassEastEdge", "WallBottom1", "WallBottom2"]:
		assert_null(_room.get_node_or_null("Walls/" + wall_name), "no %s framing it" % wall_name)


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
	var almos = _almos_at(ON_THE_LANE + Vector2(0, -70))
	almos.facing = Vector2.DOWN
	var barrel := BARREL_SCENE.instantiate() as HidingSpot
	barrel.position = ON_THE_LANE + Vector2(0, -20)
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
