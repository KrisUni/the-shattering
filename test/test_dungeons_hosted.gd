extends GutTest
## The Dungeons as the host and the rest of the game use it: loaded by the AreaHost as its first
## space, given a live Almos before it is in the tree, and having Almos put at a place in it.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const ALMOS_PATH := "res://scenes/almos/almos.tscn"
const GRAPH_PATH := "res://data/dungeons_room_graph.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window, set by the test.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from the exit Almos is put before walking out.
const FROM_EXIT := 100.0
# In physics frames. The longest a walk to an exit may take before the test gives up.
const MOST_FRAMES_TO_EXIT := 180

var _almos_input: AlmosInput
var _graph: RoomGraph


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_graph = load(GRAPH_PATH) as RoomGraph


func after_each() -> void:
	_almos_input.release_everything()


func _view() -> SubViewport:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	return view


func test_the_host_starts_in_the_dungeons_in_cell_3() -> void:
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	_view().add_child(host)

	await wait_physics_frames(2)

	assert_eq(WorldState.current_area, &"dungeons", "the host should be in the Dungeons")
	var dungeons := host.current_space as DungeonsBuilding
	assert_not_null(dungeons, "the host's space should be the Dungeons")
	if dungeons != null:
		assert_eq(dungeons.current_room, dungeons.room(&"cell_3"), "Almos should be in cell_3")


func test_a_live_almos_given_to_the_dungeons_is_the_one_that_walks_through_an_exit() -> void:
	# A live Almos, as the host has one: already in the tree, from another space.
	var live := (load(ALMOS_PATH) as PackedScene).instantiate() as Almos
	_view().add_child(live)
	await wait_physics_frames(1)
	live.get_parent().remove_child(live)
	var dungeons := (load(DUNGEONS_PATH) as PackedScene).instantiate() as DungeonsBuilding
	dungeons.adopt_almos(live)
	assert_eq(dungeons.almos, live, "the given Almos should be the Dungeons' Almos")
	_view().add_child(dungeons)
	var arrivals: Array[Room] = []
	dungeons.room_changed.connect(func(room: Room) -> void: arrivals.append(room))
	var exit_id: String = _graph.exits.keys()[0]
	var room_exit := dungeons.room(RoomGraph.room_of_exit(exit_id)).get_node("Exits/%s" % RoomGraph.exit_name_of(exit_id)) as RoomExit
	var way := (room_exit.global_position - room_exit.entrance.global_position).normalized()
	var action: StringName
	if absf(way.x) > absf(way.y):
		action = &"move_right" if way.x > 0.0 else &"move_left"
	else:
		action = &"move_down" if way.y > 0.0 else &"move_up"
	live.global_position = room_exit.entrance.global_position - way * (FROM_EXIT - room_exit.entrance.position.length())

	_almos_input.press_action(action)
	var frames := 0
	while arrivals.is_empty() and frames < MOST_FRAMES_TO_EXIT:
		await wait_physics_frames(1)
		frames += 1
	_almos_input.release_action(action)

	assert_almost_eq(live.global_position, room_exit.target.entrance.global_position, Vector2(1.0, 1.0), "the given Almos should be at the Entrance of the next Room")


func test_the_rooms_stay_before_the_live_almos_the_camera_and_the_hud() -> void:
	# A live Almos, as the host has one: already in the tree, from another space.
	var live := (load(ALMOS_PATH) as PackedScene).instantiate() as Almos
	_view().add_child(live)
	await wait_physics_frames(1)
	live.get_parent().remove_child(live)
	var dungeons := (load(DUNGEONS_PATH) as PackedScene).instantiate() as DungeonsBuilding
	dungeons.adopt_almos(live)
	_view().add_child(dungeons)

	assert_eq(dungeons.almos, live)
	var rest: Array[Node] = [live, dungeons.find_child("Camera", false, false), dungeons.find_child("Hud", false, false)]
	for node in rest:
		for id in _graph.rooms:
			assert_lt(dungeons.room(id).get_index(), node.get_index(), "'%s' should be drawn under %s" % [id, node.name])


func test_putting_almos_in_another_room_makes_it_the_current_room() -> void:
	var dungeons := (load(DUNGEONS_PATH) as PackedScene).instantiate() as DungeonsBuilding
	_view().add_child(dungeons)
	await wait_physics_frames(2)
	var arrivals: Array[Room] = []
	dungeons.room_changed.connect(func(room: Room) -> void: arrivals.append(room))
	var other: Room = null
	for id in _graph.rooms:
		if id != _graph.start_room:
			other = dungeons.room(id)
			break

	dungeons.put_almos_at(other.get_view_center())

	assert_eq(dungeons.current_room, other, "the Room Almos was put in should be the current one")
	assert_eq(arrivals, [other] as Array[Room], "the Dungeons should tell of coming into that Room")
