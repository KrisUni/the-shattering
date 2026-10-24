extends GutTest
## The Room graph as data: what RoomGraph tells of a small graph built here, and that the
## Dungeons' own graph file, data/dungeons_room_graph.tres, has every exit matched and every
## Room reachable.

const GRAPH_PATH := "res://data/dungeons_room_graph.tres"
# The Rooms of the Dungeons, as the floor plan of the issue names them.
const DUNGEONS_ROOMS: Array[StringName] = [
	&"cell_1", &"cell_2", &"cell_3", &"radio_officers",
	&"corridor_1", &"corridor_2", &"corridor_3", &"corridor_4",
	&"interviews", &"interview_surveillance", &"wcs", &"lockers_showers",
	&"kitchenette_staff_mess", &"archives_evidence", &"store_room",
	&"meeting_room_1", &"meeting_room_2", &"chiefs_office", &"officers",
	&"reception", &"lobby",
]


# A graph of the given Rooms and exits, starting in the first Room.
func _graph(rooms: Array[StringName], exits: Dictionary[String, String]) -> RoomGraph:
	var graph := RoomGraph.new()
	graph.start_room = rooms[0]
	for room in rooms:
		graph.rooms[room] = "res://scenes/areas/dungeons/%s.tscn" % room
	graph.exits = exits
	return graph


func test_exits_that_lead_back_to_each_other_are_matched() -> void:
	var graph := _graph([&"a", &"b"], {"a/east": "b/west", "b/west": "a/east"})

	assert_eq(graph.unmatched_exits(), [] as Array[String])


func test_an_exit_without_a_return_exit_is_unmatched() -> void:
	var graph := _graph([&"a", &"b"], {"a/east": "b/west"})

	assert_eq(graph.unmatched_exits(), ["a/east"] as Array[String])


func test_an_exit_to_an_unknown_room_is_unmatched() -> void:
	var graph := _graph([&"a"], {"a/east": "ghost/west", "ghost/west": "a/east"})

	assert_eq(graph.unmatched_exits(), ["a/east", "ghost/west"] as Array[String])


# a/east is the only one: b/west and c/west do lead back to each other.
func test_an_exit_whose_destination_leads_elsewhere_is_unmatched() -> void:
	var graph := _graph([&"a", &"b", &"c"], {
		"a/east": "b/west",
		"b/west": "c/west",
		"c/west": "b/west",
	})

	assert_eq(graph.unmatched_exits(), ["a/east"] as Array[String])


func test_rooms_joined_by_exits_to_the_start_room_are_reachable() -> void:
	var graph := _graph([&"a", &"b", &"c"], {
		"a/east": "b/west", "b/west": "a/east",
		"b/east": "c/west", "c/west": "b/east",
	})

	assert_eq(graph.unreachable_rooms(), [] as Array[StringName])


func test_a_room_without_exits_to_the_rest_is_unreachable() -> void:
	var graph := _graph([&"a", &"b", &"island"], {"a/east": "b/west", "b/west": "a/east"})

	assert_eq(graph.unreachable_rooms(), [&"island"] as Array[StringName])


func test_a_room_that_is_only_led_away_from_is_unreachable() -> void:
	var graph := _graph([&"a", &"b"], {"b/west": "a/east"})

	assert_eq(graph.unreachable_rooms(), [&"b"] as Array[StringName])


func test_a_room_tells_the_names_of_its_exits() -> void:
	var graph := _graph([&"a", &"b", &"c"], {
		"a/east": "b/west", "b/west": "a/east",
		"b/east": "c/west", "c/west": "b/east",
	})

	assert_eq(graph.exits_of(&"b"), [&"west", &"east"] as Array[StringName])


func test_an_exit_tells_the_exit_it_leads_to() -> void:
	var graph := _graph([&"a", &"b"], {"a/east": "b/west", "b/west": "a/east"})

	assert_eq(graph.destination_of(&"a", &"east"), "b/west")


func test_an_exit_the_room_does_not_have_leads_nowhere() -> void:
	var graph := _graph([&"a", &"b"], {"a/east": "b/west", "b/west": "a/east"})

	assert_eq(graph.destination_of(&"a", &"west"), "")


func test_the_dungeons_graph_has_the_rooms_of_the_floor_plan() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	var ids := graph.rooms.keys()
	ids.sort()
	var expected := DUNGEONS_ROOMS.duplicate()
	expected.sort()
	assert_eq(ids, expected)


func test_the_dungeons_start_in_cell_3() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	assert_eq(graph.start_room, &"cell_3")


func test_every_exit_of_the_dungeons_leads_back_from_its_destination() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	assert_eq(graph.unmatched_exits(), [] as Array[String])


func test_every_room_of_the_dungeons_is_reachable_from_the_start() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	assert_eq(graph.unreachable_rooms(), [] as Array[StringName])


func test_the_central_corridor_runs_from_corridor_1_to_corridor_4() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	assert_eq(graph.destination_of(&"corridor_1", &"east"), "corridor_2/west")
	assert_eq(graph.destination_of(&"corridor_3", &"east"), "corridor_4/west")


func test_a_cell_door_opens_on_the_corridor_that_leads_to_it() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	assert_eq(graph.destination_of(&"cell_3", &"door"), "corridor_1/to_cell_3")


func test_the_lobby_is_through_the_reception() -> void:
	var graph: RoomGraph = load(GRAPH_PATH)

	assert_eq(graph.destination_of(&"reception", &"to_lobby"), "lobby/to_reception")
