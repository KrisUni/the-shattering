extends GutTest
## Cell 3 and the Store room: Almos wakes in the Dungeons stripped of his Weapon (and Armour) with
## his Flasks, and his confiscated Weapon lies in the Store room.

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const SWORD_PATH := "res://data/sword.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame


func after_each() -> void:
	WorldState.reset()


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func test_almos_wakes_in_cell_3_with_no_weapon_in_hand_or_carried() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"cell_3"), "he should wake in Cell 3")
	assert_eq(host.almos.weapons.carried.size(), 0, "he should carry no Weapon")
	assert_null(host.almos.weapons.in_hand, "his hands should be empty")


func test_almos_woken_without_a_weapon_attacks_unarmed() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var attacks := host.almos.get_node("Attacks") as AlmosAttacks
	assert_eq(attacks.weapon, host.almos.unarmed, "with empty hands his attacks should be Unarmed")


func test_almos_wakes_with_his_flasks_full() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var flasks := host.almos.flasks
	assert_gt(flasks.health_charges_maximum, 0, "he should have Flasks")
	assert_eq(flasks.health_charges, flasks.health_charges_maximum, "his Flasks should be full")


func test_the_store_room_holds_his_sword_as_a_pickup() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var dungeons := host.current_space as DungeonsBuilding
	var swords: Array[WeaponPickup] = []
	for child in dungeons.room(&"store_room").find_children("*", "WeaponPickup", true, false):
		var pickup := child as WeaponPickup
		if pickup.weapon == load(SWORD_PATH):
			swords.append(pickup)
	assert_eq(swords.size(), 1, "the Store room should hold one pickup with the sword")
