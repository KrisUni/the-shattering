extends GutTest

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const TOLERANCE := 0.0001


func test_test_room_instantiates() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return

	var room := scene.instantiate()
	add_child_autofree(room)

	assert_not_null(room, "the test room should instantiate")


func test_test_room_contains_a_placeholder_almos() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return

	var room := scene.instantiate()
	add_child_autofree(room)

	assert_not_null(room.find_child("Almos", true, false), "the test room should contain a node named Almos")


func test_the_stamina_bar_follows_the_stamina_almos_has_left() -> void:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	if tuning == null:
		return
	assert_gt(tuning.stamina_maximum, 0.0, "stamina_maximum in the data file should be positive")
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return
	var room := scene.instantiate()
	add_child_autofree(room)
	var almos = room.find_child("Almos", true, false)
	var bar = room.find_child("StaminaBar", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(bar, "the test room should contain a StaminaBar")
	if almos == null or bar == null:
		return
	var cost := tuning.stamina_maximum / 4.0

	almos.stamina.spend(cost)

	assert_almost_eq(bar.value, tuning.stamina_maximum - cost, TOLERANCE)
	assert_almost_eq(bar.max_value, tuning.stamina_maximum, TOLERANCE)
