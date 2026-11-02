extends GutTest
## Corridor 1's two dark root masses below the lane are Drops: open edges Almos can walk off, where
## the root falls away. Walking or rolling off one is a Deadly fall (he drops out of sight and dies,
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


func test_the_hall_has_two_drops_where_the_root_masses_were() -> void:
	for drop_name in ["DropWest", "DropEast"]:
		var drop := _room.get_node_or_null("Drops/" + drop_name) as Footprint
		assert_not_null(drop, "%s is there" % drop_name)
		assert_almost_eq(drop.position.y - drop.size.y / 2.0, DROP_TOP, 0.01, "%s begins at the lane's south edge" % drop_name)
	assert_null(_room.get_node_or_null("Walls/MassWest"), "no solid root left in its place")
	assert_null(_room.get_node_or_null("Walls/MassEast"), "nor on the east")


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
	assert_lt(_room.to_local(places[0]).y, DROP_TOP, "its Remains place is on the lane, at the edge")
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
	assert_lt(barrel.position.y, DROP_TOP, "back on the lane where it stood")


func test_the_props_on_the_edge_let_him_out_on_the_lane_side() -> void:
	for node in _room.get_node("Furniture").get_children():
		var spot := node as HidingSpot
		if spot == null:
			continue
		var out := spot.position + spot.exit_offset
		assert_lt(out.y, DROP_TOP - 12.0, "%s lets him out on the lane, not down the Drop" % spot.name)
