extends GutTest
## A building of Rooms, tested through its placeholder scene of three: A, whose east edge leads
## to B's west edge, and B, whose north door leads to C's south door. The Rooms' places and the
## exits' layout are data of the scene, and the numbers here are those of its design.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const BUILDING_PATH := "res://scenes/areas/test_building.tscn"
# In pixels. The size of the view the building is shown in: the project's default window, and
# the size of each Room. The test sets it, since a headless run has a window of its own, much smaller.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. Where the Rooms are, as the scene lays them out: B beside A with a gap between,
# C above B with a gap between.
const ROOM_A_CENTER := Vector2(576, 324)
const ROOM_B_CENTER := Vector2(1828, 324)
const ROOM_C_CENTER := Vector2(1828, -424)
# In pixels. Where Almos is put on arriving, as the scene lays out the exits: 56 inside the Room
# from the edge exit or the door he came through, 16 thick.
const A_EAST_ENTRANCE := Vector2(1152 - 8 - 56, 324)
const B_WEST_ENTRANCE := Vector2(1252 + 8 + 56, 324)
const B_NORTH_ENTRANCE := Vector2(1828, 8 + 56)
const C_SOUTH_ENTRANCE := Vector2(1828, -748 + 648 - 8 - 56)
# In pixels. How far from the exit Almos is put before walking out: well inside the Room, but near enough that it takes a second or two.
const FROM_EXIT := 100.0
# In physics frames. Long enough to walk 100 pixels at the walking speed, with room to spare.
const WALK_FRAMES := 30
# In physics frames. The longest a walk to an exit may take before the test gives up.
const MOST_FRAMES_TO_EXIT := 180
# In physics frames. Enough for Almos to have been sent back, if arriving were to do that.
const LINGER_FRAMES := 10
# In pixels. "Within a pixel", for the places Almos is put at.
const TOLERANCE := 1.0

var _almos_input: AlmosInput
# What the building tells of each arrival: the Room, and where Almos was then.
var _arrivals: Array[Dictionary] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_arrivals = []


func after_each() -> void:
	_almos_input.release_everything()


# The test building in the test's scene tree, shown in a view of VIEW_SIZE. The test frees it.
func _spawn_building() -> Building:
	var scene := load(BUILDING_PATH) as PackedScene
	assert_not_null(scene, "the test building scene should load")
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var building := scene.instantiate() as Building
	view.add_child(building)
	building.room_changed.connect(func(room: Room) -> void: _arrivals.append({"room": room, "at": building.almos.global_position}))
	return building


func _camera_centre(building: Building) -> Vector2:
	return (building.find_child("Camera", false, false) as Camera2D).get_screen_center_position()


func _room(building: Building, room_name: String) -> Room:
	return building.get_node(room_name) as Room


# Almos put at this place, then walking in the given direction (an input action) until he has
# come into another Room, which the building tells.
func _walk_through(building: Building, from: Vector2, action: StringName) -> void:
	building.almos.global_position = from
	_almos_input.press_action(action)
	var frames := 0
	while _arrivals.is_empty() and frames < MOST_FRAMES_TO_EXIT:
		await wait_physics_frames(1)
		frames += 1
	_almos_input.release_action(action)


func test_almos_starts_in_room_a_with_the_camera_on_it() -> void:
	var building := _spawn_building()

	await wait_physics_frames(2)

	assert_eq(building.current_room, _room(building, "RoomA"), "Almos should start in Room A")
	assert_almost_eq(_camera_centre(building), ROOM_A_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_camera_stays_on_the_room_while_almos_walks_in_it() -> void:
	var building := _spawn_building()
	var start_x := building.almos.global_position.x
	_almos_input.press_action(&"move_right")

	await wait_physics_frames(WALK_FRAMES)

	assert_gt(building.almos.global_position.x, start_x + 20.0, "Almos should have walked")
	assert_almost_eq(_camera_centre(building), ROOM_A_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_leaving_room_a_by_its_east_edge_shows_room_b() -> void:
	var building := _spawn_building()

	await _walk_through(building, A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0), &"move_right")

	assert_eq(building.current_room, _room(building, "RoomB"), "Almos should be in Room B")
	assert_almost_eq(_camera_centre(building), ROOM_B_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_leaving_room_a_by_its_east_edge_puts_almos_at_the_west_entrance_of_room_b() -> void:
	var building := _spawn_building()

	await _walk_through(building, A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0), &"move_right")

	assert_almost_eq(_arrivals[0]["at"], B_WEST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))


func test_leaving_room_b_by_its_north_door_puts_almos_at_the_south_door_of_room_c() -> void:
	var building := _spawn_building()

	await _walk_through(building, B_NORTH_ENTRANCE + Vector2(0, FROM_EXIT), &"move_up")

	assert_eq(_arrivals[0]["room"], _room(building, "RoomC"), "Almos should come into Room C")
	assert_almost_eq(_arrivals[0]["at"], C_SOUTH_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))


func test_leaving_room_b_by_its_north_door_shows_room_c() -> void:
	var building := _spawn_building()

	await _walk_through(building, B_NORTH_ENTRANCE + Vector2(0, FROM_EXIT), &"move_up")

	assert_almost_eq(_camera_centre(building), ROOM_C_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_walking_back_through_the_door_of_room_c_returns_to_room_b_at_its_door() -> void:
	var building := _spawn_building()
	await _walk_through(building, B_NORTH_ENTRANCE + Vector2(0, FROM_EXIT), &"move_up")
	_arrivals = []

	await _walk_through(building, C_SOUTH_ENTRANCE - Vector2(0, FROM_EXIT), &"move_down")

	assert_eq(_arrivals[0]["room"], _room(building, "RoomB"), "Almos should come back into Room B")
	assert_almost_eq(_arrivals[0]["at"], B_NORTH_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(_camera_centre(building), ROOM_B_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_walking_back_through_the_west_edge_of_room_b_returns_to_room_a_at_its_east_edge() -> void:
	var building := _spawn_building()
	await _walk_through(building, A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0), &"move_right")
	_arrivals = []

	await _walk_through(building, B_WEST_ENTRANCE + Vector2(FROM_EXIT, 0), &"move_left")

	assert_eq(_arrivals[0]["room"], _room(building, "RoomA"), "Almos should come back into Room A")
	assert_almost_eq(_arrivals[0]["at"], A_EAST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(_camera_centre(building), ROOM_A_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_almos_is_not_sent_straight_back_from_the_room_he_arrives_in() -> void:
	var building := _spawn_building()
	await _walk_through(building, A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0), &"move_right")

	await wait_physics_frames(LINGER_FRAMES)

	assert_eq(building.current_room, _room(building, "RoomB"), "Almos should still be in Room B")
	assert_eq(_arrivals.size(), 1, "Almos should have come into a Room once")


func test_the_camera_stays_on_the_room_while_almos_walks_in_the_room_he_arrived_in() -> void:
	var building := _spawn_building()
	await _walk_through(building, A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0), &"move_right")
	_almos_input.press_action(&"move_right")

	await wait_physics_frames(WALK_FRAMES)

	assert_gt(building.almos.global_position.x, B_WEST_ENTRANCE.x + 20.0, "Almos should have walked on in Room B")
	assert_almost_eq(_camera_centre(building), ROOM_B_CENTER, Vector2(TOLERANCE, TOLERANCE))
