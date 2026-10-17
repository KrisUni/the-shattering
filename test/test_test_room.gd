extends GutTest

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"


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
