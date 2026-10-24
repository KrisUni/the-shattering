extends GutTest
## Taking Armour: a tap of Interact within pickup_reach of an Armour pickup makes Almos wear that
## Armour and takes the pickup away. The Armour is a placeholder until Armour and Load is done, so
## wearing it changes nothing else. Interact keeps its priority: a Checkpoint, then a Hiding spot,
## then one pickup, the nearest. Numbers come from the player tuning as shipped.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const ARMOUR_PICKUP_SCENE_PATH := "res://scenes/world/armour_pickup.tscn"
const WEAPON_PICKUP_SCENE_PATH := "res://scenes/world/weapon_pickup.tscn"
const CHECKPOINT_SCENE_PATH := "res://scenes/world/checkpoint.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const ARMOUR_PATH := "res://data/almos_armour.tres"
const SPEAR_PATH := "res://data/spear.tres"

# In physics frames. A press held this long is a tap, and the same time is waited after it.
const TAP_FRAMES := 3
# In pixels. A place well away from anything else in the test.
const OPEN_SPOT := Vector2(600.0, 420.0)
# The shares of pickup_reach at which a nearer and a farther pickup are put: both in reach.
const NEAR_SHARE := 0.25
const FAR_SHARE := 0.75
# In pixels. How far inside or outside the edge of his reach a pickup is put to try it.
const REACH_MARGIN := 1.0
# In pixels. How far from the Checkpoint's centre a pickup is put, to lie beside it.
const BESIDE := 5.0

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, so what the test spawns is first processed after the test begins.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_almos_wears_no_armour_until_he_takes_some() -> void:
	var almos := _almos()

	assert_null(almos.armour, "the Armour he wears")


func test_a_tap_of_interact_beside_an_armour_pickup_makes_him_wear_its_armour_and_removes_it() -> void:
	var almos := _almos()
	var pickup := _armour_pickup_at(almos.global_position)

	await _tap(&"interact")

	assert_eq(almos.armour, load(ARMOUR_PATH), "the Armour he wears")
	assert_true(_is_gone(pickup), "the pickup should be gone")


func test_a_tap_just_inside_his_reach_takes_the_armour_and_just_outside_does_not() -> void:
	var almos := _almos()
	var reach := (load(TUNING_PATH) as PlayerTuning).pickup_reach
	var pickup := _armour_pickup_at(almos.global_position + Vector2(reach + REACH_MARGIN, 0.0))
	await _tap(&"interact")
	assert_null(almos.armour, "just outside his reach")

	pickup.global_position = almos.global_position + Vector2(reach - REACH_MARGIN, 0.0)
	await _tap(&"interact")

	assert_eq(almos.armour, load(ARMOUR_PATH), "just inside his reach")


func test_a_tap_with_a_weapon_pickup_nearer_than_the_armour_pickup_takes_only_the_weapon() -> void:
	var almos := _almos()
	var reach := (load(TUNING_PATH) as PlayerTuning).pickup_reach
	var weapon_pickup := _weapon_pickup_at(almos.global_position + Vector2(reach * NEAR_SHARE, 0.0))
	var armour_pickup := _armour_pickup_at(almos.global_position + Vector2(-reach * FAR_SHARE, 0.0))

	await _tap(&"interact")

	assert_eq(almos.weapons.carried.size(), 2, "the Weapon should be carried")
	assert_null(almos.armour, "the Armour should not be worn")
	assert_false(_is_gone(armour_pickup), "the farther pickup should still lie there")
	assert_true(_is_gone(weapon_pickup), "the nearer pickup should be gone")


func test_a_tap_with_an_armour_pickup_nearer_than_the_weapon_pickup_takes_only_the_armour() -> void:
	var almos := _almos()
	var reach := (load(TUNING_PATH) as PlayerTuning).pickup_reach
	var armour_pickup := _armour_pickup_at(almos.global_position + Vector2(reach * NEAR_SHARE, 0.0))
	var weapon_pickup := _weapon_pickup_at(almos.global_position + Vector2(-reach * FAR_SHARE, 0.0))

	await _tap(&"interact")

	assert_eq(almos.armour, load(ARMOUR_PATH), "the Armour he wears")
	assert_eq(almos.weapons.carried.size(), 1, "no Weapon should be picked up")
	assert_false(_is_gone(weapon_pickup), "the farther pickup should still lie there")
	assert_true(_is_gone(armour_pickup), "the nearer pickup should be gone")


func test_a_tap_with_a_checkpoint_and_an_armour_pickup_both_in_reach_rests_and_leaves_the_armour() -> void:
	var almos := _almos()
	var checkpoint := _checkpoint_at(almos.global_position)
	var pickup := _armour_pickup_at(checkpoint.global_position + Vector2(BESIDE, 0.0))
	watch_signals(almos)

	await _tap(&"interact")

	assert_signal_emitted(almos, "rested")
	assert_null(almos.armour, "the Armour should not be worn")
	assert_false(_is_gone(pickup), "the pickup should lie where it was")


func test_a_tap_of_interact_with_no_pickup_in_reach_wears_nothing() -> void:
	var almos := _almos()

	await _tap(&"interact")

	assert_null(almos.armour, "the Armour he wears")


func _almos() -> Almos:
	var almos := _almos_input.spawn_almos() as Almos
	almos.global_position = OPEN_SPOT
	return almos


func _armour_pickup_at(at: Vector2) -> ArmourPickup:
	var pickup := (load(ARMOUR_PICKUP_SCENE_PATH) as PackedScene).instantiate() as ArmourPickup
	pickup.armour = load(ARMOUR_PATH) as ArmourData
	add_child_autofree(pickup)
	pickup.global_position = at
	return pickup


func _weapon_pickup_at(at: Vector2) -> WeaponPickup:
	var pickup := (load(WEAPON_PICKUP_SCENE_PATH) as PackedScene).instantiate() as WeaponPickup
	pickup.weapon = load(SPEAR_PATH) as WeaponData
	add_child_autofree(pickup)
	pickup.global_position = at
	return pickup


func _checkpoint_at(at: Vector2) -> Checkpoint:
	var checkpoint := (load(CHECKPOINT_SCENE_PATH) as PackedScene).instantiate() as Checkpoint
	add_child_autofree(checkpoint)
	checkpoint.global_position = at
	return checkpoint


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# Whether the pickup has been taken: freed, or on its way to being freed.
func _is_gone(pickup) -> bool:
	return not is_instance_valid(pickup) or pickup.is_queued_for_deletion()
