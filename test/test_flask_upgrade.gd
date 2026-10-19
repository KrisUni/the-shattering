extends GutTest
## The Flask upgrade: Almos takes it by walking over it, it adds one charge to both Flasks, and
## it stays taken for good. Seen with the real Almos and, for the placement, the real test room,
## walked with the move action. Expected numbers come from the Flask tuning file. Each test resets
## WorldState first and last, so nothing leaks between tests.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const UPGRADE_SCENE_PATH := "res://scenes/world/flask_upgrade.tscn"
const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLASK_TUNING_PATH := "res://data/flasks.tres"
const UPGRADE_ID := &"an_upgrade"
const ROOM_UPGRADE_ID := &"test_room_flask_upgrade"
const TAP_FRAMES := 3
# In physics frames. Slack for a touch to be noticed.
const SETTLE_FRAMES := 4
# In physics frames. The most a walk may take.
const WALK_FRAME_LIMIT := 300
# In pixels. How far from the Checkpoint's centre Almos is put to rest.
const BESIDE_THE_CHECKPOINT := 10.0
# In pixels. How far left of the placed upgrade Almos starts his walk.
const WALK_START_BEFORE := 60.0

var _almos_input: AlmosInput
var _tuning: FlaskTuning
var _almos: Almos
var _room: Node


func before_each() -> void:
	await get_tree().process_frame
	WorldState.reset()
	_almos_input = AlmosInput.new(self)
	_tuning = load(FLASK_TUNING_PATH) as FlaskTuning


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_touching_it_adds_a_charge_to_both_flasks() -> void:
	_almos = _almos_input.spawn_almos()
	_place_upgrade(UPGRADE_ID, _almos.position)

	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(_almos.flasks.health_charges_maximum, _tuning.health_charges + 1, "Health Flask maximum")
	assert_eq(_almos.flasks.mana_charges_maximum, _tuning.mana_charges + 1, "Mana Flask maximum")


func test_the_new_health_charge_is_usable_at_once_and_the_mana_flask_stays_empty() -> void:
	_almos = _almos_input.spawn_almos()
	_place_upgrade(UPGRADE_ID, _almos.position)

	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(_almos.flasks.health_charges, _tuning.health_charges + 1)
	assert_eq(_almos.flasks.mana_charges, 0)


func test_it_is_gone_once_taken_and_recorded_for_good() -> void:
	_almos = _almos_input.spawn_almos()
	var upgrade := _place_upgrade(UPGRADE_ID, _almos.position)

	await wait_physics_frames(SETTLE_FRAMES)

	assert_false(is_instance_valid(upgrade), "the upgrade should be gone")
	assert_true(WorldState.is_taken(UPGRADE_ID))


func test_it_cannot_be_taken_a_second_time() -> void:
	_almos = _almos_input.spawn_almos()
	_place_upgrade(UPGRADE_ID, _almos.position)
	await wait_physics_frames(SETTLE_FRAMES)
	_almos.position += Vector2.RIGHT * 100.0
	await wait_physics_frames(SETTLE_FRAMES)
	_almos.position -= Vector2.RIGHT * 100.0
	await wait_physics_frames(SETTLE_FRAMES)

	assert_eq(_almos.flasks.health_charges_maximum, _tuning.health_charges + 1)


func test_one_whose_id_is_already_taken_is_not_there() -> void:
	WorldState.record_taken(UPGRADE_ID)
	_almos = _almos_input.spawn_almos()
	var upgrade := _place_upgrade(UPGRADE_ID, _almos.position)

	await wait_physics_frames(SETTLE_FRAMES)

	assert_false(is_instance_valid(upgrade), "the upgrade should not appear")
	assert_eq(_almos.flasks.health_charges_maximum, _tuning.health_charges)


func test_walking_onto_the_upgrade_in_the_test_room_takes_it() -> void:
	_set_up_room()
	var upgrade := _room.get_node("FlaskUpgrade") as Node2D
	_almos.global_position = upgrade.global_position + Vector2.LEFT * WALK_START_BEFORE

	_almos_input.press_action(&"move_right")
	for i in WALK_FRAME_LIMIT:
		if WorldState.is_taken(ROOM_UPGRADE_ID):
			break
		await get_tree().physics_frame

	assert_true(WorldState.is_taken(ROOM_UPGRADE_ID), "walking onto it should take it")
	assert_eq(_almos.flasks.health_charges_maximum, _tuning.health_charges + 1)


func test_resting_refills_to_the_raised_maximum_and_the_upgrade_stays_taken() -> void:
	_set_up_room()
	_take_the_room_upgrade()
	await wait_physics_frames(SETTLE_FRAMES)
	_almos.flasks.sip()
	assert_eq(_almos.flasks.health_charges, _tuning.health_charges)
	var checkpoint := _room.find_child("Checkpoint", true, false) as Node2D
	_almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT
	_almos.flasks.reset()

	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(_almos.flasks.health_charges, _tuning.health_charges + 1)
	assert_eq(_almos.flasks.health_charges_maximum, _tuning.health_charges + 1)
	assert_eq(_almos.flasks.mana_charges, 0)
	assert_true(WorldState.is_taken(ROOM_UPGRADE_ID))


func test_the_return_after_a_death_keeps_the_raised_maximum() -> void:
	_set_up_room()
	_take_the_room_upgrade()
	await wait_physics_frames(SETTLE_FRAMES)
	var player := load(AlmosInput.TUNING_PATH) as PlayerTuning

	_almos.health.take_damage(_almos.health.maximum)
	await wait_seconds(player.death_pause + 0.5)

	assert_false(_almos.dead, "he should be back")
	assert_eq(_almos.flasks.health_charges_maximum, _tuning.health_charges + 1)
	assert_eq(_almos.flasks.health_charges, _tuning.health_charges + 1)
	assert_true(WorldState.is_taken(ROOM_UPGRADE_ID))


func test_a_room_built_again_has_no_upgrade_to_take() -> void:
	_set_up_room()
	_take_the_room_upgrade()
	await wait_physics_frames(SETTLE_FRAMES)

	var scene := load(TEST_ROOM_PATH) as PackedScene
	var again := scene.instantiate()
	add_child_autofree(again)
	await wait_physics_frames(SETTLE_FRAMES)

	assert_null(again.get_node_or_null("FlaskUpgrade"), "it should not be there")


func test_the_hud_label_shows_the_raised_maximums() -> void:
	_set_up_room()
	_take_the_room_upgrade()
	await wait_physics_frames(SETTLE_FRAMES)
	var label := _room.get_node("Hud/FlaskLabel") as Label

	assert_eq(label.text, "Health Flask %d/%d · Mana Flask 0/%d" % [_tuning.health_charges + 1, _tuning.health_charges + 1, _tuning.mana_charges + 1])


func _place_upgrade(id: StringName, at: Vector2) -> Node2D:
	var upgrade := (load(UPGRADE_SCENE_PATH) as PackedScene).instantiate() as FlaskUpgrade
	upgrade.id = id
	upgrade.position = at
	add_child_autofree(upgrade)
	return upgrade


func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null


# Puts Almos on the room's upgrade so that he takes it.
func _take_the_room_upgrade() -> void:
	_almos.global_position = (_room.get_node("FlaskUpgrade") as Node2D).global_position
