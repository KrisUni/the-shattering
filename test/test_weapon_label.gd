extends GutTest
## The Weapon label of the test room's HUD: it names the Weapon in Almos's hand, or says
## "Unarmed" when his hands are empty, and follows him as he picks up, switches and drops. The
## names are those in the Weapons' data files.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const SWORD_PATH := "res://data/sword.tres"
const SPEAR_PATH := "res://data/spear.tres"

# In physics frames. A press held this long is a tap, and the same time is waited after it.
const TAP_FRAMES := 3
# In physics frames. How much longer than the drop takes a hold is held.
const HOLD_MARGIN := 4
const UNARMED := "Unarmed"

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first
	# processed after the first sample and what it presses is seen from the next frame.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_it_names_the_weapon_he_starts_with() -> void:
	var room := _spawn_room()

	assert_eq(_label(room).text, _name_of(SWORD_PATH))


func test_it_is_under_the_experience_label() -> void:
	var room := _spawn_room()
	var experience: Label = room.find_child("ExperienceLabel", true, false)

	assert_gte(_label(room).global_position.y, experience.global_position.y + experience.size.y,
			"the Weapon label should start below the Experience label")


func test_it_follows_a_pick_up_and_a_switch() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = room.find_child("SpearPickup", true, false).global_position
	await _tap(&"interact")
	assert_eq(_label(room).text, _name_of(SWORD_PATH), "the one in hand stays after a pick-up")

	await _tap(&"switch_weapon")

	assert_eq(_label(room).text, _name_of(SPEAR_PATH))


func test_it_follows_a_drop_to_the_next_weapon_and_then_to_unarmed() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	almos.global_position = room.find_child("SpearPickup", true, false).global_position
	await _tap(&"interact")
	almos.global_position = Vector2(600.0, 420.0)

	await _hold_to_drop()
	assert_eq(_label(room).text, _name_of(SPEAR_PATH), "the next one comes to hand")
	await _hold_to_drop()

	assert_eq(_label(room).text, UNARMED)


func _spawn_room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	var room := scene.instantiate()
	add_child_autofree(room)
	(room.find_child("TrainingEnemy", true, false) as Node2D).global_position = Vector2(1100.0, 100.0)
	return room


func _label(room: Node) -> Label:
	var label := room.find_child("WeaponLabel", true, false) as Label
	assert_not_null(label, "the test room should have a Weapon label")
	return label


func _name_of(path: String) -> String:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s should load as a Weapon" % path)
	return weapon.display_name


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


func _hold_to_drop() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	_almos_input.press_action(&"interact")
	await wait_physics_frames(ceili(tuning.drop_hold_time * Engine.physics_ticks_per_second) + HOLD_MARGIN)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
