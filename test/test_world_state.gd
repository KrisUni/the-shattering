extends GutTest
## The world state that outlasts resting: which path blockers have burnt and which pickups are taken,
## kept per area. It records a burnt one by its id, reports it, and a reset clears it. A change is
## pending until a commit saves it, and a roll back drops what is pending. A path blocker built with
## its id recorded starts open. Each test resets it first and last, so nothing leaks between tests.

const PATH_BLOCKER_PATH := "res://scenes/world/path_blocker.tscn"
const BLOCKER_ID := &"a_blocker"
const OTHER_ID := &"another_blocker"
const AREA := &"the_first_area"
const OTHER_AREA := &"the_second_area"
const ENEMY_ID := &"a_named_enemy"
# In Experience, and in pixels. What some Remains hold, and where they lie.
const REMAINS_AMOUNT := 137
const REMAINS_PLACE := Vector2(300.0, 200.0)
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


# --- pending and saved ---


func test_a_burnt_path_blocker_is_still_reported_after_a_commit() -> void:
	WorldState.record_burnt(BLOCKER_ID)

	WorldState.commit()

	assert_true(WorldState.is_burnt(BLOCKER_ID))


func test_a_roll_back_forgets_a_burnt_path_blocker_that_was_not_committed() -> void:
	WorldState.record_burnt(BLOCKER_ID)

	WorldState.roll_back()

	assert_false(WorldState.is_burnt(BLOCKER_ID))


func test_a_roll_back_keeps_a_burnt_path_blocker_that_was_committed() -> void:
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.commit()

	WorldState.roll_back()

	assert_true(WorldState.is_burnt(BLOCKER_ID))


func test_a_roll_back_drops_only_what_came_after_the_commit() -> void:
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.commit()
	WorldState.record_burnt(OTHER_ID)

	WorldState.roll_back()

	assert_true(WorldState.is_burnt(BLOCKER_ID), "committed one stays")
	assert_false(WorldState.is_burnt(OTHER_ID), "later one is undone")


func test_a_second_commit_with_nothing_pending_changes_nothing() -> void:
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.record_taken(OTHER_ID)
	WorldState.commit()

	WorldState.commit()

	assert_true(WorldState.is_burnt(BLOCKER_ID), "burnt stays")
	assert_true(WorldState.is_taken(OTHER_ID), "taken stays")
	assert_false(WorldState.is_burnt(OTHER_ID), "nothing else burnt")
	assert_false(WorldState.is_taken(BLOCKER_ID), "nothing else taken")


func test_committing_twice_in_a_row_then_rolling_back_leaves_what_one_commit_left() -> void:
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.record_taken(OTHER_ID)
	WorldState.commit()
	WorldState.commit()

	WorldState.roll_back()

	assert_true(WorldState.is_burnt(BLOCKER_ID), "burnt stays")
	assert_true(WorldState.is_taken(OTHER_ID), "taken stays")
	assert_false(WorldState.is_burnt(OTHER_ID), "nothing else burnt")
	assert_false(WorldState.is_taken(BLOCKER_ID), "nothing else taken")


func test_a_pickup_taken_before_a_commit_stays_taken_through_a_roll_back() -> void:
	WorldState.record_taken(BLOCKER_ID)
	WorldState.commit()

	WorldState.roll_back()

	assert_true(WorldState.is_taken(BLOCKER_ID))


func test_a_pickup_taken_after_the_last_commit_is_back_after_a_roll_back() -> void:
	WorldState.record_taken(BLOCKER_ID)

	WorldState.roll_back()

	assert_false(WorldState.is_taken(BLOCKER_ID))


func test_a_kept_pickup_is_taken_and_survives_a_roll_back_with_no_commit() -> void:
	WorldState.record_kept(BLOCKER_ID)
	assert_true(WorldState.is_taken(BLOCKER_ID), "taken at once")

	WorldState.roll_back()

	assert_true(WorldState.is_taken(BLOCKER_ID))


func test_a_reset_forgets_pending_and_saved_changes() -> void:
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.commit()
	WorldState.record_burnt(OTHER_ID)
	WorldState.record_kept(&"a_kept_pickup")

	WorldState.reset()

	assert_false(WorldState.is_burnt(BLOCKER_ID), "saved")
	assert_false(WorldState.is_burnt(OTHER_ID), "pending")
	assert_false(WorldState.is_taken(&"a_kept_pickup"), "kept")


# --- per area ---


func test_a_burnt_path_blocker_is_not_burnt_in_another_area() -> void:
	WorldState.current_area = AREA
	WorldState.record_burnt(BLOCKER_ID)

	WorldState.current_area = OTHER_AREA

	assert_false(WorldState.is_burnt(BLOCKER_ID))


func test_a_burnt_path_blocker_is_burnt_again_on_returning_to_its_area() -> void:
	WorldState.current_area = AREA
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.current_area = OTHER_AREA

	WorldState.current_area = AREA

	assert_true(WorldState.is_burnt(BLOCKER_ID))


func test_a_commit_saves_the_pending_changes_of_every_area() -> void:
	WorldState.current_area = AREA
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.current_area = OTHER_AREA
	WorldState.record_burnt(OTHER_ID)

	WorldState.commit()
	WorldState.roll_back()

	assert_true(WorldState.is_burnt(OTHER_ID), "second area")
	WorldState.current_area = AREA
	assert_true(WorldState.is_burnt(BLOCKER_ID), "first area")


func test_a_roll_back_drops_the_pending_changes_of_every_area() -> void:
	WorldState.current_area = AREA
	WorldState.record_burnt(BLOCKER_ID)
	WorldState.current_area = OTHER_AREA
	WorldState.record_burnt(OTHER_ID)

	WorldState.roll_back()

	assert_false(WorldState.is_burnt(OTHER_ID), "second area")
	WorldState.current_area = AREA
	assert_false(WorldState.is_burnt(BLOCKER_ID), "first area")


func test_a_taken_pickup_is_kept_per_area() -> void:
	WorldState.current_area = AREA
	WorldState.record_taken(BLOCKER_ID)

	WorldState.current_area = OTHER_AREA

	assert_false(WorldState.is_taken(BLOCKER_ID))


func test_a_reset_returns_to_the_default_area() -> void:
	WorldState.current_area = AREA

	WorldState.reset()

	assert_eq(WorldState.current_area, &"")


func test_there_are_no_remains_until_some_are_set() -> void:
	assert_true(WorldState.remains().is_empty())


func test_set_remains_are_reported_with_their_area_amount_and_place() -> void:
	WorldState.set_remains(AREA, REMAINS_AMOUNT, REMAINS_PLACE)

	var remains := WorldState.remains()

	assert_eq(remains, {"area_id": AREA, "amount": REMAINS_AMOUNT, "place": REMAINS_PLACE})


func test_new_remains_replace_the_old_even_in_another_area() -> void:
	WorldState.set_remains(AREA, REMAINS_AMOUNT, REMAINS_PLACE)

	WorldState.set_remains(OTHER_AREA, REMAINS_AMOUNT + 1, REMAINS_PLACE + Vector2.ONE)

	assert_eq(WorldState.remains()["area_id"], OTHER_AREA)


func test_remains_of_nothing_clear_the_old() -> void:
	WorldState.set_remains(AREA, REMAINS_AMOUNT, REMAINS_PLACE)

	WorldState.set_remains(OTHER_AREA, 0, REMAINS_PLACE)

	assert_true(WorldState.remains().is_empty())


func test_remains_survive_a_commit_and_a_roll_back() -> void:
	WorldState.set_remains(AREA, REMAINS_AMOUNT, REMAINS_PLACE)

	WorldState.commit()
	WorldState.roll_back()

	assert_eq(WorldState.remains()["amount"], REMAINS_AMOUNT)


func test_a_reset_forgets_the_remains() -> void:
	WorldState.set_remains(AREA, REMAINS_AMOUNT, REMAINS_PLACE)

	WorldState.reset()

	assert_true(WorldState.remains().is_empty())


func test_a_named_enemy_is_not_defeated_until_it_is_recorded() -> void:
	assert_false(WorldState.is_defeated(ENEMY_ID))


func test_a_recorded_named_enemy_is_defeated_through_a_roll_back() -> void:
	WorldState.record_defeated(ENEMY_ID)

	WorldState.roll_back()

	assert_true(WorldState.is_defeated(ENEMY_ID))


func test_recording_one_named_enemy_does_not_defeat_another() -> void:
	WorldState.record_defeated(ENEMY_ID)

	assert_false(WorldState.is_defeated(&"another_enemy"))


func test_a_reset_forgets_the_defeated_named_enemies() -> void:
	WorldState.record_defeated(ENEMY_ID)

	WorldState.reset()

	assert_false(WorldState.is_defeated(ENEMY_ID))
