extends GutTest
## The Spell label of the test room's HUD: it names the Spell Almos has selected, "Pull",
## or "Shove", and follows him as he switches and as the selection changes by itself.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FIREBALL_PATH := "res://data/fireball.tres"
# In physics frames. A press held this long is a tap, and the same time is waited after it.
const TAP_FRAMES := 3

var _almos_input: AlmosInput


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_it_names_pull_to_begin_with() -> void:
	var room := _spawn_room()

	assert_eq(_label(room).text, "Pull")


func test_it_is_under_the_weapon_label() -> void:
	var room := _spawn_room()
	var weapon: Label = room.find_child("WeaponLabel", true, false)

	assert_gte(_label(room).global_position.y, weapon.global_position.y + weapon.size.y,
			"the Spell label should start below the Weapon label")


func test_it_follows_a_switch() -> void:
	var room := _spawn_room()

	await _tap(&"switch_spell")
	assert_eq(_label(room).text, "Shove", "after one switch")
	await _tap(&"switch_spell")
	assert_eq(_label(room).text, "Pull", "after two")


func test_it_says_shove_while_he_holds_a_flame_and_pull_when_it_is_out() -> void:
	var room := _spawn_room()
	var almos: Almos = room.find_child("Almos", true, false)
	var torch: Torch = room.find_child("WallTorch", true, false)
	var spell := load(FIREBALL_PATH) as SpellData
	almos.global_position = torch.global_position + Vector2(0.0, spell.draw_range / 2.0)

	await _tap(&"cast_spell")
	await wait_physics_frames(spell.wind_up_frames + TAP_FRAMES)
	assert_true(almos.spell.holding, "control: holding")
	assert_eq(_label(room).text, "Shove", "holding")
	almos.health.take_damage(1.0)

	assert_eq(_label(room).text, "Pull", "flame out")


func _spawn_room() -> Node:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	var room := scene.instantiate()
	add_child_autofree(room)
	(room.find_child("TrainingEnemy", true, false) as Node2D).global_position = Vector2(1100.0, 100.0)
	return room


func _label(room: Node) -> Label:
	var label := room.find_child("SpellLabel", true, false) as Label
	assert_not_null(label, "the test room should have a Spell label")
	return label


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)
