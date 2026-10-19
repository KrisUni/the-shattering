extends GutTest
## The Mana Flask, seen only through the scenes: carried from the start but empty and unusable
## while Almos has no Mana bar, which nothing gives him yet. The real Almos is driven by the
## Mana Sip action with the shipped tuning, and the test room serves for the Checkpoint, the
## Death and the HUD.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLASK_TUNING_PATH := "res://data/flasks.tres"
const TOLERANCE := 0.0001
const TAP_FRAMES := 3
# In pixels per second. How exactly a measured speed has to match.
const SPEED_TOLERANCE := 0.01
# In pixels. How far from the Checkpoint's centre Almos is put to rest.
const BESIDE_THE_CHECKPOINT := 10.0

var _almos_input: AlmosInput
var _flasks: FlaskTuning
var _player: PlayerTuning
var _room: Node
var _almos: Almos


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_flasks = load(FLASK_TUNING_PATH) as FlaskTuning
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_he_carries_the_mana_flask_empty_from_the_start() -> void:
	_almos = _almos_input.spawn_almos()

	assert_eq(_almos.flasks.mana_charges_maximum, _flasks.mana_charges)
	assert_eq(_almos.flasks.mana_charges, 0)


func test_a_mana_sip_press_does_not_slow_him() -> void:
	_almos = _almos_input.spawn_almos()
	_almos_input.press_action(&"move_right")
	await _tap(&"sip_mana")

	var velocity: Vector2 = await _measured_velocity()

	assert_false(_almos.sipping, "there should be no Sip")
	assert_almost_eq(velocity, Vector2(_player.walk_speed, 0.0), Vector2.ONE * SPEED_TOLERANCE)


func test_a_mana_sip_press_leaves_the_flasks_and_health_as_they_were() -> void:
	_almos = _almos_input.spawn_almos()
	_almos.health.take_damage(40.0)
	var health := _almos.health.current

	await _tap(&"sip_mana")
	await wait_seconds(_flasks.sip_duration + 0.2)

	assert_eq(_almos.flasks.mana_charges, 0)
	assert_eq(_almos.flasks.health_charges, _flasks.health_charges)
	assert_almost_eq(_almos.health.current, health, TOLERANCE)


func test_actions_stay_free_after_a_mana_sip_press() -> void:
	_almos = _almos_input.spawn_almos()
	await _tap(&"sip_mana")

	_almos_input.press_action(&"jump")
	await wait_physics_frames(TAP_FRAMES)

	assert_true(_almos.airborne, "he should be able to jump")


func test_resting_leaves_the_mana_flask_empty() -> void:
	_set_up_room()
	var checkpoint := _room.find_child("Checkpoint", true, false) as Node2D
	_almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT

	await _tap(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(_almos.flasks.mana_charges, 0)


func test_the_return_after_a_death_leaves_the_mana_flask_empty() -> void:
	_set_up_room()

	_almos.health.take_damage(_almos.health.maximum)
	await wait_seconds(_player.death_pause + 0.5)

	assert_false(_almos.dead, "he should be back")
	assert_eq(_almos.flasks.mana_charges, 0)


func test_the_hud_label_shows_both_flasks() -> void:
	_set_up_room()
	var label := _room.get_node("Hud/FlaskLabel") as Label

	assert_eq(label.text, "Health Flask %d/%d · Mana Flask 0/%d" % [_flasks.health_charges, _flasks.health_charges, _flasks.mana_charges])


func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _measured_velocity() -> Vector2:
	var start := _almos.position
	var start_frame := Engine.get_physics_frames()
	await wait_physics_frames(AlmosInput.MEASURED_FRAMES)
	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	return (_almos.position - start) / seconds
