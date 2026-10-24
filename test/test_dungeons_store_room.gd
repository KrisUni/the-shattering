extends GutTest
## The Store room, off the direct route in the Dungeons, holds Almos's Weapon, a Sword, and his
## Armour, which is a placeholder pickup until Armour and Load is done.

const STORE_ROOM_PATH := "res://scenes/areas/dungeons/store_room.tscn"
const SWORD_PATH := "res://data/sword.tres"
const ARMOUR_PATH := "res://data/almos_armour.tres"
# In pixels. The Room's floor is the project's window; the walls are 16 pixels thick.
const FLOOR_RECT := Rect2(0.0, 0.0, 1152.0, 648.0)
const WALL_THICKNESS := 16.0


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
