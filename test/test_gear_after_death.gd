extends GutTest
## What a Death does to the gear Almos took: the Weapons and Armour picked up since his last rest
## lie where they lay again, and he carries and wears what he had at that rest (what he starts
## with, until the first). Resting at a Checkpoint saves what he has taken. Pickups with an id are
## noted in WorldState when taken; one without an id, such as a dropped Weapon, is not.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const ARMOUR_PICKUP_SCENE_PATH := "res://scenes/world/armour_pickup.tscn"
const WEAPON_PICKUP_SCENE_PATH := "res://scenes/world/weapon_pickup.tscn"
const CHECKPOINT_SCENE_PATH := "res://scenes/world/checkpoint.tscn"
const ARMOUR_PATH := "res://data/almos_armour.tres"
const SWORD_PATH := "res://data/sword.tres"
const SPEAR_PATH := "res://data/spear.tres"

const SPEAR_ID := &"test/spear"
const ARMOUR_ID := &"test/armour"

# In physics frames. A press held this long is a tap, and the same time is waited after it.
const TAP_FRAMES := 3
# In pixels. A place well away from anything else in the test.
const OPEN_SPOT := Vector2(600.0, 420.0)
# In pixels. Where Almos is sent back to.
const RETURN_POINT := Vector2(300.0, 200.0)
# In pixels. How far from a pickup or Checkpoint Almos stands: well inside his reach.
const BESIDE := 5.0

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, so what the test spawns is first processed after the test begins.
	await get_tree().process_frame
	WorldState.reset()
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_a_pickup_whose_id_is_taken_is_gone_when_it_is_made() -> void:
	WorldState.record_taken(SPEAR_ID)
	WorldState.record_taken(ARMOUR_ID)

	var weapon_pickup := _weapon_pickup(SPEAR_ID, OPEN_SPOT)
	var armour_pickup := _armour_pickup(ARMOUR_ID, OPEN_SPOT)

	assert_true(_is_gone(weapon_pickup), "the Weapon pickup")
	assert_true(_is_gone(armour_pickup), "the Armour pickup")


func test_a_pickup_without_an_id_is_made_whatever_is_taken() -> void:
	WorldState.record_taken(&"")

	var weapon_pickup := _weapon_pickup(&"", OPEN_SPOT)
	var armour_pickup := _armour_pickup(&"", OPEN_SPOT)

	assert_false(_is_gone(weapon_pickup), "the Weapon pickup")
	assert_false(_is_gone(armour_pickup), "the Armour pickup")


func test_taking_a_weapon_pickup_with_an_id_notes_it_taken_until_a_death() -> void:
	var almos := _almos()
	_weapon_pickup(SPEAR_ID, almos.global_position + Vector2(BESIDE, 0.0))

	await _tap(&"interact")
	assert_true(WorldState.is_taken(SPEAR_ID), "taken after Interact")
	WorldState.roll_back()

	assert_false(WorldState.is_taken(SPEAR_ID), "not taken after the Death")


func test_taking_an_armour_pickup_with_an_id_notes_it_taken_until_a_death() -> void:
	var almos := _almos()
	_armour_pickup(ARMOUR_ID, almos.global_position + Vector2(BESIDE, 0.0))

	await _tap(&"interact")
	assert_true(WorldState.is_taken(ARMOUR_ID), "taken after Interact")
	WorldState.roll_back()

	assert_false(WorldState.is_taken(ARMOUR_ID), "not taken after the Death")


func test_taking_a_pickup_without_an_id_notes_nothing() -> void:
	var almos := _almos()
	_weapon_pickup(&"", almos.global_position + Vector2(BESIDE, 0.0))

	await _tap(&"interact")
	WorldState.roll_back()

	assert_eq(almos.weapons.carried.size(), 2, "he took it all the same")
	assert_false(WorldState.is_taken(&""), "nothing noted")


func test_a_death_before_a_rest_takes_the_weapon_taken_away_again() -> void:
	var almos := _almos()
	await _take_a_weapon(almos, SPEAR_ID)

	_die_and_return(almos)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH], "the Weapons he carries")
	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "the Weapon in hand")


func test_a_death_before_a_rest_takes_the_armour_taken_away_again() -> void:
	var almos := _almos()
	await _take_armour(almos, ARMOUR_ID)

	_die_and_return(almos)

	assert_null(almos.armour, "the Armour he wears")


func test_a_death_before_a_rest_gives_his_attacks_the_weapon_he_had() -> void:
	var almos := _almos()
	await _take_a_weapon(almos, SPEAR_ID)
	almos.weapons.switch_to_next()

	_die_and_return(almos)

	assert_eq((almos.get_node("Attacks") as AlmosAttacks).weapon.resource_path, SWORD_PATH)


func test_a_death_after_a_rest_keeps_the_weapon_taken_before_it() -> void:
	var almos := _almos()
	await _take_a_weapon(almos, SPEAR_ID)
	await _rest(almos)

	_die_and_return(almos)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH, SPEAR_PATH], "the Weapons he carries")
	assert_true(WorldState.is_taken(SPEAR_ID), "the pickup stays taken")


func test_a_death_after_a_rest_keeps_the_armour_taken_before_it() -> void:
	var almos := _almos()
	await _take_armour(almos, ARMOUR_ID)
	await _rest(almos)

	_die_and_return(almos)

	assert_eq(almos.armour, load(ARMOUR_PATH), "the Armour he wears")
	assert_true(WorldState.is_taken(ARMOUR_ID), "the pickup stays taken")


func test_a_death_after_a_rest_puts_back_the_weapon_in_hand_at_the_rest() -> void:
	var almos := _almos()
	await _take_a_weapon(almos, SPEAR_ID)
	almos.weapons.switch_to_next()
	await _rest(almos)
	almos.weapons.switch_to_next()

	_die_and_return(almos)

	assert_eq(almos.weapons.in_hand.resource_path, SPEAR_PATH, "the Weapon in hand")
	assert_eq((almos.get_node("Attacks") as AlmosAttacks).weapon.resource_path, SPEAR_PATH, "the Weapon his attacks make")


func test_a_death_gives_back_a_weapon_he_dropped_since_the_rest() -> void:
	var almos := _almos()

	await _hold_interact(almos)
	assert_null(almos.weapons.in_hand, "he dropped the Sword")
	_die_and_return(almos)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH], "the Weapons he carries")
	assert_eq(almos.weapons.in_hand.resource_path, SWORD_PATH, "the Weapon in hand")


func test_a_death_after_a_rest_without_taking_anything_changes_nothing() -> void:
	var almos := _almos()
	await _rest(almos)

	_die_and_return(almos)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH], "the Weapons he carries")
	assert_null(almos.armour, "the Armour he wears")


func test_a_second_death_returns_to_the_same_rest() -> void:
	var almos := _almos()
	await _rest(almos)
	await _take_a_weapon(almos, SPEAR_ID)
	_die_and_return(almos)
	await _take_a_weapon(almos, &"test/other")

	_die_and_return(almos)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH])


func test_the_gear_he_wears_at_his_first_rest_is_what_a_death_gives_back() -> void:
	var almos := _almos()
	await _take_armour(almos, ARMOUR_ID)
	await _rest(almos)
	await _take_a_weapon(almos, SPEAR_ID)

	_die_and_return(almos)

	assert_eq(_paths(almos.weapons.carried), [SWORD_PATH], "the Weapons he carries")
	assert_eq(almos.armour, load(ARMOUR_PATH), "the Armour he wears")


func _almos() -> Almos:
	var almos := _almos_input.spawn_almos() as Almos
	almos.global_position = OPEN_SPOT
	return almos


func _weapon_pickup(id: StringName, at: Vector2) -> WeaponPickup:
	var pickup := (load(WEAPON_PICKUP_SCENE_PATH) as PackedScene).instantiate() as WeaponPickup
	pickup.weapon = load(SPEAR_PATH) as WeaponData
	pickup.id = id
	add_child_autofree(pickup)
	pickup.global_position = at
	return pickup


func _armour_pickup(id: StringName, at: Vector2) -> ArmourPickup:
	var pickup := (load(ARMOUR_PICKUP_SCENE_PATH) as PackedScene).instantiate() as ArmourPickup
	pickup.armour = load(ARMOUR_PATH) as ArmourData
	pickup.id = id
	add_child_autofree(pickup)
	pickup.global_position = at
	return pickup


func _checkpoint_at(at: Vector2) -> Checkpoint:
	var checkpoint := (load(CHECKPOINT_SCENE_PATH) as PackedScene).instantiate() as Checkpoint
	add_child_autofree(checkpoint)
	checkpoint.global_position = at
	return checkpoint


# Almos takes a Spear lying beside him, noted under this id.
func _take_a_weapon(almos: Almos, id: StringName) -> void:
	_weapon_pickup(id, almos.global_position + Vector2(BESIDE, 0.0))
	await _tap(&"interact")


func _take_armour(almos: Almos, id: StringName) -> void:
	_armour_pickup(id, almos.global_position + Vector2(BESIDE, 0.0))
	await _tap(&"interact")


# Almos rests at a Checkpoint beside him, and the world is saved as the room does it.
func _rest(almos: Almos) -> void:
	var checkpoint := _checkpoint_at(almos.global_position + Vector2(BESIDE, 0.0))
	await _tap(&"interact")
	WorldState.commit()
	checkpoint.queue_free()


# Holds Interact long enough to drop the Weapon in hand.
func _hold_interact(almos: Almos) -> void:
	_almos_input.press_action(&"interact")
	await wait_physics_frames(ceili(almos.tuning.drop_hold_time * Engine.physics_ticks_per_second) + TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)


# Almos dies and is sent back as the room does it: the world is rolled back, then he is returned.
func _die_and_return(almos: Almos) -> void:
	almos.health.take_damage(almos.health.maximum)
	WorldState.roll_back()
	almos.return_to(RETURN_POINT)


func _paths(weapons: Array[WeaponData]) -> Array[String]:
	var paths: Array[String] = []
	for weapon in weapons:
		paths.append(weapon.resource_path)
	return paths


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# Whether the pickup has been taken: freed, or on its way to being freed.
func _is_gone(pickup) -> bool:
	return not is_instance_valid(pickup) or pickup.is_queued_for_deletion()
