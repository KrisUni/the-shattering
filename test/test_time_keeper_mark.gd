extends GutTest
## The Time Keeper's mark and the Mana bar it grants, seen in the real test room with the real
## Almos, walked with the move action. The bar's size is worked from literals in a retuned copy of
## the shipped tuning, so that the points waiting in the Mana stat show. Each test resets
## WorldState first and last, so nothing leaks between tests.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLASK_TUNING_PATH := "res://data/flasks.tres"
const MARK_NAME := "TimeKeeperMark"
const TOLERANCE := 0.0001
const TAP_FRAMES := 3
# In physics frames. The most a walk may take.
const WALK_FRAME_LIMIT := 300
# In pixels. How far left of the mark Almos starts his walk.
const WALK_START_BEFORE := 60.0
# In pixels. How far from the Checkpoint's centre Almos is put to rest.
const BESIDE_THE_CHECKPOINT := 10.0
# A bar worked by hand: 30 + 7 * 9 = 93.
const WORKED_BASE := 30.0
const WORKED_PER_POINT := 7.0
const WORKED_POINTS := 9
const WORKED_MAXIMUM := 93.0

var _almos_input: AlmosInput
var _flasks: FlaskTuning
var _player: PlayerTuning
var _room: Node
var _almos: Almos


func before_each() -> void:
	await get_tree().process_frame
	WorldState.reset()
	_almos_input = AlmosInput.new(self)
	_flasks = load(FLASK_TUNING_PATH) as FlaskTuning
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_the_bar_is_base_plus_each_point_of_the_mana_stat() -> void:
	var tuning := PlayerTuning.new()
	tuning.mana_base = WORKED_BASE
	tuning.mana_per_point = WORKED_PER_POINT
	tuning.mana = WORKED_POINTS

	assert_almost_eq(tuning.mana_maximum(), WORKED_MAXIMUM, TOLERANCE)


func test_almos_has_no_mana_bar_at_the_start() -> void:
	_set_up_room()

	assert_false(_almos.mana.granted)


func test_walking_into_the_mark_grants_the_bar_full() -> void:
	_set_up_room()

	await _walk_into_the_mark()

	assert_true(_almos.mana.granted, "granted")
	assert_almost_eq(_almos.mana.current, _almos.mana.maximum, TOLERANCE, "full")


func test_the_bar_is_sized_by_the_shipped_mana_stat() -> void:
	_set_up_room()

	await _walk_into_the_mark()

	assert_almost_eq(_almos.mana.maximum, _player.mana_base + _player.mana_per_point * _player.mana, TOLERANCE)


func test_points_bought_before_the_bar_are_waiting_in_it() -> void:
	var tuning := _player.duplicate() as PlayerTuning
	tuning.mana_base = WORKED_BASE
	tuning.mana_per_point = WORKED_PER_POINT
	tuning.mana = WORKED_POINTS
	_set_up_room(tuning)

	await _walk_into_the_mark()

	assert_almost_eq(_almos.mana.maximum, WORKED_MAXIMUM, TOLERANCE)


func test_the_mark_is_gone_once_it_has_given_the_bar() -> void:
	_set_up_room()

	await _walk_into_the_mark()
	await wait_physics_frames(TAP_FRAMES)

	assert_null(_room.get_node_or_null(MARK_NAME))


func test_a_second_entry_grants_nothing_more() -> void:
	_set_up_room()
	await _walk_into_the_mark()
	_almos.mana.spend(30.0)
	var left := _almos.mana.current
	var maximum := _almos.mana.maximum

	await _walk_into_where_the_mark_was()

	assert_almost_eq(_almos.mana.current, left, TOLERANCE, "amount")
	assert_almost_eq(_almos.mana.maximum, maximum, TOLERANCE, "maximum")


func test_the_mark_is_not_there_when_the_room_is_built_again() -> void:
	_set_up_room()
	await _walk_into_the_mark()
	_room.free()

	_set_up_room()
	await wait_physics_frames(TAP_FRAMES)

	assert_null(_room.get_node_or_null(MARK_NAME))


func test_the_mark_overlaps_no_other_object_of_the_room() -> void:
	_set_up_room()
	var mark := _room.get_node(MARK_NAME) as Area2D
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(mark.get_overlapping_bodies().size(), 0, "bodies")
	assert_eq(mark.get_overlapping_areas().size(), 0, "areas")


func test_resting_refills_the_mana_bar() -> void:
	_set_up_room()
	await _walk_into_the_mark()
	_almos.mana.spend(40.0)
	_almos.global_position = _checkpoint().global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT

	await _tap(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_almost_eq(_almos.mana.current, _almos.mana.maximum, TOLERANCE)


func test_the_return_after_a_death_refills_the_mana_bar() -> void:
	_set_up_room()
	await _walk_into_the_mark()
	_almos.mana.spend(40.0)

	_almos.health.take_damage(_almos.health.maximum)
	await wait_seconds(_player.death_pause + 0.5)

	assert_false(_almos.dead, "he should be back")
	assert_almost_eq(_almos.mana.current, _almos.mana.maximum, TOLERANCE)


func test_the_mark_stays_taken_through_a_death_with_no_rest() -> void:
	_set_up_room()
	await _walk_into_the_mark()
	assert_true(_almos.flasks.has_mana_bar, "control: he has the bar")

	_almos.health.take_damage(_almos.health.maximum)
	await wait_seconds(_player.death_pause + 0.5)
	_room.free()
	_set_up_room()
	await wait_physics_frames(TAP_FRAMES)

	assert_null(_room.get_node_or_null(MARK_NAME), "the mark is not there again")


func test_the_mana_flask_fills_at_the_next_checkpoint() -> void:
	_set_up_room()
	await _walk_into_the_mark()
	_almos.global_position = _checkpoint().global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT

	await _tap(&"interact")
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(_almos.flasks.mana_charges, _flasks.mana_charges)


func test_the_mana_flask_holds_its_charges_only_from_the_next_checkpoint() -> void:
	_set_up_room()

	await _walk_into_the_mark()

	assert_eq(_almos.flasks.mana_charges, 0)


func test_the_mana_bar_is_in_the_hud_only_once_granted() -> void:
	_set_up_room()
	var bar := _room.get_node("Hud/ManaBar") as ProgressBar
	var hidden_before := not bar.visible

	await _walk_into_the_mark()

	assert_true(hidden_before, "hidden before")
	assert_true(bar.visible, "shown after")


func _set_up_room(tuning: PlayerTuning = null) -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	if tuning != null:
		(_room.get_node("Almos") as Almos).tuning = tuning
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null


func _checkpoint() -> Node2D:
	return _room.find_child("Checkpoint", true, false) as Node2D


# Puts Almos left of the mark and holds right until the bar is granted or the limit is reached.
func _walk_into_the_mark() -> void:
	var mark := _room.get_node(MARK_NAME) as Node2D
	await _walk_into(mark.global_position)


func _walk_into_where_the_mark_was() -> void:
	await _walk_into(_mark_place)


var _mark_place := Vector2.ZERO


func _walk_into(place: Vector2) -> void:
	_mark_place = place
	_almos.global_position = place - Vector2.RIGHT * WALK_START_BEFORE
	_almos_input.press_action(&"move_right")
	for i in WALK_FRAME_LIMIT:
		if _almos.global_position.x > place.x + WALK_START_BEFORE / 2.0:
			break
		await wait_physics_frames(1)
	_almos_input.release_action(&"move_right")
	await wait_physics_frames(TAP_FRAMES)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
