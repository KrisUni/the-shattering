extends GutTest
## The Weapon pickup: a placeholder Weapon lying in a room, holding the Weapon's data file, and
## where the test room lays the four Weapons Almos does not start with. Picking one up comes
## later. Expectations about the room are derived from the nodes and data files it is made of.

const PICKUP_SCENE_PATH := "res://scenes/world/weapon_pickup.tscn"
const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const GROUP := &"weapon_pickups"
# In pixels. How far a pickup must lie from anything it should be clear of, beyond the edge.
const CLEARANCE := 8.0

# The data file of each Weapon the test room lays out as a pickup.
var lying_weapon_params = ParameterFactory.named_parameters(
	["path"],
	[["res://data/spear.tres"], ["res://data/greatsword.tres"], ["res://data/torch.tres"], ["res://data/metal_bar.tres"]],
)


func before_each() -> void:
	# Start between two physics frames, so what the test spawns is first processed after the test begins.
	await get_tree().process_frame


func test_a_pickup_is_in_the_weapon_pickups_group_and_holds_the_weapon_it_is_given() -> void:
	var pickup := _pickup()
	if pickup == null:
		return
	var weapon := load("res://data/spear.tres") as WeaponData

	pickup.weapon = weapon

	assert_true(pickup.is_in_group(GROUP), "the pickup should be in the group")
	assert_same(pickup.weapon, weapon, "the Weapon it holds")


func test_a_pickup_has_no_physics_body_and_shows_a_placeholder() -> void:
	var pickup := _pickup()
	if pickup == null:
		return

	var bodies := pickup.find_children("*", "CollisionObject2D", true, false)
	var shapes := pickup.find_children("*", "CollisionShape2D", true, false)
	var looks := pickup.find_children("*", "Polygon2D", true, false)

	assert_eq(bodies.size(), 0, "collision objects in the pickup, so that Almos walks through it")
	assert_eq(shapes.size(), 0, "collision shapes in the pickup")
	assert_gt(looks.size(), 0, "the pickup should draw a placeholder")


func test_the_test_room_has_one_pickup_for_each_weapon_almos_does_not_start_with() -> void:
	var room := _room()
	if room == null:
		return
	var held: Array[String] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var pickup := node as WeaponPickup
		if pickup != null and room.is_ancestor_of(pickup) and pickup.weapon != null:
			held.append(pickup.weapon.resource_path)
	held.sort()

	var expected: Array[String] = []
	for params in lying_weapon_params:
		expected.append(params.path)
	expected.sort()

	assert_eq(held, expected, "the data files the pickups in the test room hold")


func test_no_pickup_in_the_test_room_holds_the_weapon_almos_starts_with() -> void:
	var room := _room()
	if room == null:
		return
	var almos := room.get_node("Almos") as Almos
	var pickups := room.find_children("*", "WeaponPickup", true, false)

	for pickup in pickups:
		assert_ne(pickup.weapon.resource_path, almos.weapon.resource_path, "a pickup should not hold the Weapon he starts with")


func test_every_pickup_lies_clear_of_the_gap_the_ledge_the_checkpoint_and_the_enemys_notice_range(params = use_parameters(lying_weapon_params)) -> void:
	var room := _room()
	if room == null:
		return
	var pickup := _pickup_holding(room, params.path)
	if pickup == null:
		return
	var at := pickup.global_position
	var enemy := room.get_node("TrainingEnemy") as Node2D
	var notice_range := (load(ENEMY_TUNING_PATH) as EnemyTuning).notice_range

	for footprint_name in ["Gap", "Ledge"]:
		var footprint := room.get_node(footprint_name) as Footprint
		var area := Rect2(footprint.global_position - footprint.size / 2.0, footprint.size).grow(CLEARANCE)
		assert_false(area.has_point(at), "the pickup should lie clear of the %s" % footprint_name)
	assert_gt(at.distance_to(room.get_node("Checkpoint").global_position), CLEARANCE * 4.0, "distance from the Checkpoint")
	assert_gt(at.distance_to(enemy.global_position), notice_range + CLEARANCE, "distance from the enemy, against its notice range")
	var floor_area := Rect2(Vector2.ZERO, _floor_size(room)).grow(-CLEARANCE * 4.0)
	assert_true(floor_area.has_point(at), "the pickup should lie on the floor, away from the walls")


func test_pickups_in_the_test_room_do_not_lie_on_one_another() -> void:
	var room := _room()
	if room == null:
		return
	var pickups := room.find_children("*", "WeaponPickup", true, false)

	for i in pickups.size():
		for j in range(i + 1, pickups.size()):
			assert_gt(pickups[i].global_position.distance_to(pickups[j].global_position), CLEARANCE * 2.0, "distance between pickups %d and %d" % [i, j])


func _pickup() -> WeaponPickup:
	var scene := load(PICKUP_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the pickup scene should load")
	if scene == null:
		return null
	var pickup := scene.instantiate() as WeaponPickup
	assert_not_null(pickup, "the pickup scene's root should be a WeaponPickup")
	if pickup == null:
		return null
	add_child_autofree(pickup)
	return pickup


func _room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return null
	var room := scene.instantiate()
	add_child_autofree(room)
	return room


func _pickup_holding(room: Node, path: String) -> WeaponPickup:
	for pickup in room.find_children("*", "WeaponPickup", true, false):
		if pickup.weapon != null and pickup.weapon.resource_path == path:
			return pickup
	fail_test("the test room should have a pickup holding %s" % path)
	return null


# The floor's width and height, from its polygon.
func _floor_size(room: Node) -> Vector2:
	var points := (room.get_node("Floor") as Polygon2D).polygon
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	return box.size
