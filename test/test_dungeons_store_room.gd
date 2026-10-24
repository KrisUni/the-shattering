extends GutTest
## The Store room, off the direct route in the Dungeons, holds Almos's Weapon, a Sword, and his
## Armour, which is a placeholder pickup until Armour and Load is done.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const STORE_ROOM_PATH := "res://scenes/areas/dungeons/store_room.tscn"
const SWORD_PATH := "res://data/sword.tres"
const ARMOUR_PATH := "res://data/almos_armour.tres"
# In pixels. The Room's floor is the project's window; the walls are 16 pixels thick.
const FLOOR_RECT := Rect2(0.0, 0.0, 1152.0, 648.0)
const WALL_THICKNESS := 16.0
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a pickup Almos stands to take it: well inside his reach.
const BESIDE := 5.0
const TAP_FRAMES := 3
const CHECKPOINT_SCENE_PATH := "res://scenes/world/checkpoint.tscn"
# In physics frames. The most a rest, or a Death and the return after it, is waited for.
const MOST_FRAMES := 600

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func _store_room() -> Room:
	return add_child_autofree((load(STORE_ROOM_PATH) as PackedScene).instantiate()) as Room


func _pickups(room: Room, group: StringName) -> Array[Node]:
	return room.find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.is_in_group(group))


func test_the_store_room_holds_exactly_one_weapon_pickup() -> void:
	var room := _store_room()

	assert_eq(_pickups(room, &"weapon_pickups").size(), 1, "it should hold one Weapon pickup")


func test_the_store_rooms_weapon_pickup_holds_the_sword() -> void:
	var room := _store_room()

	var pickup := _pickups(room, &"weapon_pickups")[0] as WeaponPickup
	assert_eq(pickup.weapon, load(SWORD_PATH), "it should hold data/sword.tres")


func test_the_store_room_holds_exactly_one_armour_pickup() -> void:
	var room := _store_room()

	assert_eq(_pickups(room, &"armour_pickups").size(), 1, "it should hold one Armour pickup")


func test_the_store_rooms_armour_pickup_holds_the_placeholder_armour() -> void:
	var room := _store_room()

	var pickup := _pickups(room, &"armour_pickups")[0] as ArmourPickup
	assert_eq(pickup.armour, load(ARMOUR_PATH), "it should hold data/almos_armour.tres")


func test_the_store_rooms_pickups_lie_on_the_floor_clear_of_the_walls() -> void:
	var room := _store_room()
	var inside := FLOOR_RECT.grow(-WALL_THICKNESS)

	for pickup: Node2D in _pickups(room, &"weapon_pickups") + _pickups(room, &"armour_pickups"):
		assert_true(inside.has_point(pickup.position), "%s should lie inside the walls" % pickup.name)


func test_almos_takes_the_sword_with_interact_in_the_store_room_of_the_dungeons() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var store := (host.current_space as DungeonsBuilding).room(&"store_room")
	var pickup := _pickups(store, &"weapon_pickups")[0] as WeaponPickup
	host.almos.global_position = pickup.global_position + Vector2(BESIDE, 0.0)

	await _tap(&"interact")

	assert_eq(host.almos.weapons.in_hand, load(SWORD_PATH), "the Sword should be in his hand")
	assert_true(_is_gone(pickup), "the Sword pickup should be gone")


func test_almos_takes_the_armour_with_interact_in_the_store_room_of_the_dungeons() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var store := (host.current_space as DungeonsBuilding).room(&"store_room")
	var pickup := _pickups(store, &"armour_pickups")[0] as ArmourPickup
	assert_null(host.almos.armour, "he starts without Armour")
	host.almos.global_position = pickup.global_position + Vector2(BESIDE, 0.0)

	await _tap(&"interact")

	assert_eq(host.almos.armour, load(ARMOUR_PATH), "the Armour he wears")
	assert_true(_is_gone(pickup), "the Armour pickup should be gone")


func test_a_death_before_a_rest_puts_the_sword_and_the_armour_back_in_the_store_room() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_gear(host)
	assert_eq(host.almos.weapons.in_hand, load(SWORD_PATH), "control: he took the Sword")
	assert_eq(host.almos.armour, load(ARMOUR_PATH), "control: he took the Armour")

	await _die_and_wait_for_the_return(host)

	assert_null(host.almos.weapons.in_hand, "no Weapon in his hand")
	assert_true(host.almos.weapons.carried.is_empty(), "no Weapon carried")
	assert_null(host.almos.armour, "no Armour worn")
	var store := (host.current_space as DungeonsBuilding).room(&"store_room")
	assert_eq(_live_pickups(store, &"weapon_pickups").size(), 1, "the Sword lies there again")
	assert_eq(_live_pickups(store, &"armour_pickups").size(), 1, "the Armour lies there again")


func test_a_death_after_a_rest_keeps_the_sword_and_the_armour_and_the_pickups_stay_gone() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_gear(host)
	await _rest_at_a_checkpoint_in_the_store_room(host)

	await _die_and_wait_for_the_return(host)

	assert_eq(host.almos.weapons.in_hand, load(SWORD_PATH), "the Sword in his hand")
	assert_eq(host.almos.armour, load(ARMOUR_PATH), "the Armour he wears")
	var store := (host.current_space as DungeonsBuilding).room(&"store_room")
	assert_eq(_live_pickups(store, &"weapon_pickups").size(), 0, "the Sword does not lie there")
	assert_eq(_live_pickups(store, &"armour_pickups").size(), 0, "the Armour does not lie there")


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# Whether the pickup has been taken: freed, or on its way to being freed.
func _is_gone(pickup) -> bool:
	return not is_instance_valid(pickup) or pickup.is_queued_for_deletion()


# The pickups of the group in the room that are not taken.
func _live_pickups(room: Room, group: StringName) -> Array[Node]:
	return _pickups(room, group).filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())


# Almos takes the Sword and then the Armour in the store room, each with a tap of Interact.
func _take_the_gear(host: AreaHost) -> void:
	var store := (host.current_space as DungeonsBuilding).room(&"store_room")
	for group: StringName in [&"weapon_pickups", &"armour_pickups"]:
		var pickup := _pickups(store, group)[0] as Node2D
		host.almos.global_position = pickup.global_position + Vector2(BESIDE, 0.0)
		await _tap(&"interact")


# A Checkpoint is set down beside Almos in the store room, and he rests at it.
func _rest_at_a_checkpoint_in_the_store_room(host: AreaHost) -> void:
	var store := (host.current_space as DungeonsBuilding).room(&"store_room")
	var checkpoint := (load(CHECKPOINT_SCENE_PATH) as PackedScene).instantiate() as Node2D
	store.add_child(checkpoint)
	checkpoint.global_position = host.almos.global_position + Vector2(BESIDE, 0.0)
	await _tap(&"interact")
	await wait_physics_frames(TAP_FRAMES)


# Almos's Health is taken to zero, and the test waits until he is sent back and the load is over.
func _die_and_wait_for_the_return(host: AreaHost) -> void:
	host.almos.health.take_damage(host.almos.health.maximum)
	var frames := 0
	while (host.almos.dead or host.loading or frames < TAP_FRAMES) and frames < MOST_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_lt(frames, MOST_FRAMES, "he should have been sent back")
	await wait_physics_frames(TAP_FRAMES)
