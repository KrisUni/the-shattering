extends GutTest
## The Dungeons as a building of placeholder Rooms, built from the Room graph in
## data/dungeons_room_graph.tres: every Room of the graph is there, its exits lead where the graph
## says, and Almos can walk through every exit to the Entrance of the one it leads to.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const GRAPH_PATH := "res://data/dungeons_room_graph.tres"
# In pixels. The size of the view the building is shown in: the project's default window, and
# the size of each Room. The test sets it, since a headless run has a window of its own, much smaller.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from the exit Almos is put before walking out: well inside the Room, but near enough that it takes a second or two.
const FROM_EXIT := 100.0
# In physics frames. The longest a walk to an exit may take before the test gives up.
const MOST_FRAMES_TO_EXIT := 180
# In pixels. "Within a pixel", for the places Almos is put at.
const TOLERANCE := 1.0

var _almos_input: AlmosInput
var _graph: RoomGraph
# What the building tells of each arrival: the Room, and where Almos was then.
var _arrivals: Array[Dictionary] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_graph = load(GRAPH_PATH) as RoomGraph
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
	dungeons.room_changed.connect(func(room: Room) -> void: _arrivals.append({"room": room, "at": dungeons.almos.global_position}))
	return dungeons


# The exit "<room>/<exit>" of the Dungeons.
func _exit(dungeons: DungeonsBuilding, exit_id: String) -> RoomExit:
	return dungeons.room(RoomGraph.room_of_exit(exit_id)).get_node("Exits/%s" % RoomGraph.exit_name_of(exit_id)) as RoomExit


# The input action that walks from the Entrance of an exit towards the exit.
func _action_towards(room_exit: RoomExit) -> StringName:
	var way := room_exit.global_position - room_exit.entrance.global_position
	if absf(way.x) > absf(way.y):
		return &"move_right" if way.x > 0.0 else &"move_left"
	return &"move_down" if way.y > 0.0 else &"move_up"


func test_the_dungeons_has_a_room_for_each_room_of_the_graph() -> void:
	var dungeons := _spawn_dungeons()

	for id in _graph.rooms:
		assert_not_null(dungeons.room(id), "there should be a Room '%s'" % id)
	var rooms := dungeons.get_children().filter(func(child: Node) -> bool: return child is Room)
	assert_eq(rooms.size(), _graph.rooms.size(), "there should be no Rooms but the graph's")


func test_the_rooms_come_before_almos_the_camera_and_the_hud_so_that_they_are_drawn_over() -> void:
	var dungeons := _spawn_dungeons()

	_assert_rooms_before_the_rest(dungeons)


# Every Room's place among the building's children is before Almos's, the camera's and the HUD's.
func _assert_rooms_before_the_rest(dungeons: DungeonsBuilding) -> void:
	var rest: Array[Node] = [dungeons.almos, dungeons.find_child("Camera", false, false), dungeons.find_child("Hud", false, false)]
	for node in rest:
		assert_not_null(node, "the Dungeons should have its Almos, Camera and Hud")
		if node == null:
			continue
		for id in _graph.rooms:
			assert_lt(dungeons.room(id).get_index(), node.get_index(), "'%s' should be drawn under %s" % [id, node.name])


func test_every_exit_leads_to_the_exit_the_graph_says() -> void:
	var dungeons := _spawn_dungeons()

	for exit_id in _graph.exits:
		var room_exit := _exit(dungeons, exit_id)
		assert_not_null(room_exit, "there should be an exit %s" % exit_id)
		if room_exit != null:
			assert_eq(room_exit.target, _exit(dungeons, _graph.exits[exit_id]), "%s should lead to %s" % [exit_id, _graph.exits[exit_id]])


func test_every_exit_of_a_room_is_one_the_graph_has() -> void:
	var dungeons := _spawn_dungeons()

	for id in _graph.rooms:
		var names: Array[StringName] = []
		for room_exit in dungeons.room(id).find_children("*", "RoomExit", true, false):
			names.append(room_exit.name)
		names.sort()
		var expected := _graph.exits_of(id)
		expected.sort()
		assert_eq(names, expected, "the exits of '%s' should be the graph's" % id)


func test_no_two_rooms_overlap() -> void:
	var dungeons := _spawn_dungeons()
	var ids := _graph.rooms.keys()

	for i in ids.size():
		for j in range(i + 1, ids.size()):
			assert_false(dungeons.room(ids[i]).get_rect().intersects(dungeons.room(ids[j]).get_rect()), "'%s' and '%s' should not overlap" % [ids[i], ids[j]])


func test_each_room_has_a_floor_and_walls() -> void:
	var dungeons := _spawn_dungeons()

	for id in _graph.rooms:
		var room := dungeons.room(id)
		assert_not_null(room.get_node_or_null("Floor") as Polygon2D, "'%s' should have a floor" % id)
		var walls := room.get_node("Walls").get_children().filter(func(child: Node) -> bool: return child is StaticBody2D)
		assert_gt(walls.size(), 0, "'%s' should have walls" % id)


func test_almos_starts_in_the_graphs_start_room_with_the_camera_on_it() -> void:
	var dungeons := _spawn_dungeons()

	await wait_physics_frames(2)

	var start := dungeons.room(_graph.start_room)
	assert_eq(dungeons.current_room, start, "Almos should start in the start Room")
	assert_eq(start.name, &"cell_3")
	assert_true(start.get_rect().has_point(dungeons.almos.global_position), "Almos should be in the start Room")
	var camera := dungeons.find_child("Camera", false, false) as Camera2D
	assert_almost_eq(camera.get_screen_center_position(), start.get_view_center(), Vector2(TOLERANCE, TOLERANCE))


func test_walking_through_every_exit_comes_to_the_entrance_of_the_exit_it_leads_to() -> void:
	var dungeons := _spawn_dungeons()
	var tolerance := Vector2(TOLERANCE, TOLERANCE)

	for exit_id in _graph.exits:
		var room_exit := _exit(dungeons, exit_id)
		var destination := _exit(dungeons, _graph.exits[exit_id])
		var action := _action_towards(room_exit)
		var from := room_exit.entrance.global_position - (room_exit.global_position - room_exit.entrance.global_position).normalized() * (FROM_EXIT - room_exit.entrance.position.length())
		_arrivals = []
		dungeons.almos.global_position = from
		_almos_input.press_action(action)
		var frames := 0
		while _arrivals.is_empty() and frames < MOST_FRAMES_TO_EXIT:
			await wait_physics_frames(1)
			frames += 1
		_almos_input.release_action(action)

		assert_eq(_arrivals.size(), 1, "walking through %s should come into one Room" % exit_id)
		if _arrivals.is_empty():
			continue
		assert_eq(_arrivals[0]["room"], destination.get_room(), "%s should lead into the Room of %s" % [exit_id, _graph.exits[exit_id]])
		assert_almost_eq(_arrivals[0]["at"], destination.entrance.global_position, tolerance, "%s should put Almos at the Entrance of %s" % [exit_id, _graph.exits[exit_id]])
		assert_eq(dungeons.current_room, destination.get_room(), "the Room of %s should be the current one" % _graph.exits[exit_id])
