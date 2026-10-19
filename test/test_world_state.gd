extends GutTest
## The world state that outlasts resting: which path blockers have burnt. It records a burnt one
## by its id, reports it, and a reset clears it. A path blocker built with its id recorded starts
## open. Each test resets it first and last, so nothing leaks between tests.

const PATH_BLOCKER_PATH := "res://scenes/world/path_blocker.tscn"
const BLOCKER_ID := &"a_blocker"
const OTHER_ID := &"another_blocker"
# In pixels. Where the blocker is put, and how big.
const BLOCKER_SIZE := Vector2(16.0, 80.0)


func before_each() -> void:
	await get_tree().process_frame
	WorldState.reset()


func after_each() -> void:
	WorldState.reset()


func test_a_path_blocker_is_not_burnt_until_it_is_recorded() -> void:
	assert_false(WorldState.is_burnt(BLOCKER_ID))


func test_a_recorded_path_blocker_is_reported_burnt() -> void:
	WorldState.record_burnt(BLOCKER_ID)

	assert_true(WorldState.is_burnt(BLOCKER_ID))


func test_recording_one_path_blocker_does_not_burn_another() -> void:
	WorldState.record_burnt(BLOCKER_ID)

	assert_false(WorldState.is_burnt(OTHER_ID))


func test_a_reset_forgets_every_burnt_path_blocker() -> void:
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.record_burnt(OTHER_ID)

	WorldState.reset()

	assert_false(WorldState.is_burnt(BLOCKER_ID), "first")
	assert_false(WorldState.is_burnt(OTHER_ID), "second")


func test_a_path_blocker_built_with_its_id_recorded_starts_open() -> void:
	WorldState.record_burnt(BLOCKER_ID)

	var blocker := _blocker(BLOCKER_ID)

	assert_true(blocker.open)


func test_a_path_blocker_built_with_its_id_not_recorded_starts_closed() -> void:
	var blocker := _blocker(BLOCKER_ID)

	assert_false(blocker.open)


func test_a_path_blocker_that_catches_is_recorded() -> void:
	var blocker := _blocker(BLOCKER_ID)

	blocker.flammable.ignite()

	assert_true(WorldState.is_burnt(BLOCKER_ID))


func _blocker(id: StringName) -> PathBlocker:
	var blocker := (load(PATH_BLOCKER_PATH) as PackedScene).instantiate() as PathBlocker
	blocker.id = id
	blocker.size = BLOCKER_SIZE
	add_child_autofree(blocker)
	return blocker


func test_a_pickup_is_not_taken_until_it_is_recorded() -> void:
	assert_false(WorldState.is_taken(BLOCKER_ID))


func test_a_recorded_pickup_is_taken_and_another_is_not() -> void:
	WorldState.record_taken(BLOCKER_ID)

	assert_true(WorldState.is_taken(BLOCKER_ID))
	assert_false(WorldState.is_taken(OTHER_ID))


func test_resetting_forgets_taken_pickups() -> void:
	WorldState.record_taken(BLOCKER_ID)

	WorldState.reset()

	assert_false(WorldState.is_taken(BLOCKER_ID))
