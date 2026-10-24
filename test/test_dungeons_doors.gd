extends GutTest
## The two ways out of the Dungeons, the Main entrance in the Lobby and the door at the end of the
## Back entrance route in the Cave, are placeholder doors that do nothing: solid and labelled, and
## walking into one leaves Almos in the Room he was in.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
# In pixels. The size of the view the building is shown in: the project's default window, and
# the size of each Room. The test sets it, since a headless run has a window of its own, much smaller.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from the door Almos is put before walking into it: well inside the Room.
const FROM_DOOR := 100.0
# In physics frames. Long enough to walk that far, and to keep pushing against the door for a good while after.
const WALK_FRAMES := 180

# The doors: where each is, as the Room it is in and its name there, and what its label says.
const DOORS := [
	{"room": &"lobby", "name": "MainEntrance", "label": "Main entrance"},
	{"room": &"cave", "name": "ToCatacombs", "label": "To the Catacombs"},
]

var _almos_input: AlmosInput
# The Rooms the building has said Almos came into since the test began.
var _arrivals: Array[Room] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_arrivals = []


func after_each() -> void:
	_almos_input.release_everything()


# The Dungeons in the test's scene tree, shown in a view of VIEW_SIZE. The test frees it.
func _spawn_dungeons() -> DungeonsBuilding:
	var scene := load(DUNGEONS_PATH) as PackedScene
	assert_not_null(scene, "the Dungeons scene should load")
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var dungeons := scene.instantiate() as DungeonsBuilding
	view.add_child(dungeons)
	dungeons.room_changed.connect(func(room: Room) -> void: _arrivals.append(room))
	return dungeons


# The door of the description in its Room of the Dungeons, or null if the Room has none of that name.
func _door(dungeons: DungeonsBuilding, description: Dictionary) -> Node:
	return dungeons.room(description["room"]).get_node_or_null(NodePath(description["name"]))


# The direction from the middle of the Room to its door, along the axis it lies on.
func _way_to(room: Room, door: Node2D) -> Vector2:
	var way := door.global_position - room.get_view_center()
	if absf(way.x) > absf(way.y):
		return Vector2.RIGHT if way.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if way.y > 0.0 else Vector2.UP


func _action_towards(way: Vector2) -> StringName:
	if way == Vector2.RIGHT:
		return &"move_right"
	if way == Vector2.LEFT:
		return &"move_left"
	return &"move_down" if way == Vector2.DOWN else &"move_up"


func test_each_door_is_a_solid_labelled_body_in_its_room() -> void:
	var dungeons := _spawn_dungeons()

	for description in DOORS:
		var door := _door(dungeons, description)
		assert_not_null(door, "the Room '%s' should have a door '%s'" % [description["room"], description["name"]])
		if door == null:
			continue
		assert_true(door is StaticBody2D, "'%s' should be a solid body" % description["name"])
		var labels := door.find_children("*", "Label", true, false)
		assert_eq(labels.size(), 1, "'%s' should have one label" % description["name"])
		if labels.size() == 1:
			assert_eq((labels[0] as Label).text, description["label"])


func test_a_door_is_neither_a_doorway_nor_an_exit() -> void:
	var dungeons := _spawn_dungeons()

	for description in DOORS:
		var door := _door(dungeons, description)
		if door == null:
			fail_test("there should be a door '%s'" % description["name"])
			continue
		assert_false(door is Doorway or door is RoomExit, "'%s' should not be a Doorway or an exit" % description["name"])
		assert_eq(door.find_children("*", "Doorway", true, false).size(), 0, "'%s' should hold no Doorway" % description["name"])
		assert_eq(door.find_children("*", "RoomExit", true, false).size(), 0, "'%s' should hold no exit" % description["name"])


func test_walking_into_a_door_leaves_almos_in_the_room_and_does_not_get_him_past() -> void:
	var dungeons := _spawn_dungeons()

	for description in DOORS:
		var room := dungeons.room(description["room"])
		var door := _door(dungeons, description) as Node2D
		if door == null:
			fail_test("there should be a door '%s'" % description["name"])
			continue
		var way := _way_to(room, door)
		var action := _action_towards(way)
		dungeons.put_almos_at(door.global_position - way * FROM_DOOR)
		await wait_physics_frames(2)
		_arrivals = []

		_almos_input.press_action(action)
		await wait_physics_frames(WALK_FRAMES)
		_almos_input.release_action(action)

		assert_eq(dungeons.current_room, room, "walking into '%s' should leave Almos in the Room" % description["name"])
		assert_eq(_arrivals.size(), 0, "walking into '%s' should be no arrival in a Room" % description["name"])
		assert_true(room.get_rect().has_point(dungeons.almos.global_position), "Almos should still be inside the Room at '%s'" % description["name"])
		assert_lt((dungeons.almos.global_position - door.global_position).dot(way), 0.0, "Almos should not have got past '%s'" % description["name"])
		# He should have come up against it, not stopped short for no reason.
		assert_lt((dungeons.almos.global_position - door.global_position).length(), FROM_DOOR * 0.5, "Almos should have walked up to '%s'" % description["name"])
