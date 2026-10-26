extends GutTest
## Doorways between spaces, tested through the host scene: Open map 1 joined to Open map 2, and to
## the test building (arriving in its Room A). The places are data of the scenes, and the numbers
## here are those of their design.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
# In pixels. The size of the view the world is shown in: the project's default window. The test
# sets it, since a headless run has a window of its own, much smaller.
const VIEW_SIZE := Vector2i(576, 324)
# In pixels. Where Almos is put on arriving, as the scenes lay out the doorways: 56 inside the
# space from the doorway he came through. Map 1's east and west doorways, map 2's west doorway
# and the building's Room A west doorway.
const MAP_1_EAST_ENTRANCE := Vector2(2240 - 56, 648)
const MAP_1_WEST_ENTRANCE := Vector2(64 + 56, 648)
const MAP_2_WEST_ENTRANCE := Vector2(64 + 56, 486)
const ROOM_A_WEST_ENTRANCE := Vector2(64 + 56, 324)
const ROOM_A_CENTER := Vector2(576, 324)
# In pixels. Where the camera is when Almos has just arrived at each of those: on him, but kept a
# half view (576 by 324) inside the map he is in, which is 2304 by 1296 for map 1 and 1728 by 972
# for map 2.
const MAP_1_EAST_VIEW := Vector2(2304 - 576, 648)
const MAP_1_WEST_VIEW := Vector2(576, 648)
const MAP_2_WEST_VIEW := Vector2(576, 486)
# The doorways' scenes, and the spaces they lead to.
const MAP_1_ID := &"test_open_map"
const MAP_2_ID := &"test_open_map_2"
const BUILDING_ID := &"test_building"
# In seconds. The fade of a load, which the test with a fade sets.
const FADE_SECONDS := 0.2
const AREA_LOAD_DATA_PATH := "res://data/area_load.tres"
# In physics frames. A second is that many, at the fixed 60 frames a second the tests run at.
const FRAMES_PER_SECOND := 60
# In pixels. How far from its entrance Almos is put before walking into a doorway: well inside
# the space, but near enough that it takes a second or two.
const FROM_DOORWAY := 100.0
# In physics frames. The longest a walk to a doorway and through the load may take.
const MOST_FRAMES := 240
# In physics frames. Enough for Almos to have been sent back, if arriving were to do that.
const LINGER_FRAMES := 10
# In pixels. "Within a pixel", for the places Almos is put at.
const TOLERANCE := 1.0

var _almos_input: AlmosInput
# What the host tells of each space it loads: the space, and where Almos was then.
var _entered: Array[Dictionary] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_entered = []


func after_each() -> void:
	_almos_input.release_everything()


# The host in the test's scene tree, shown in a view of VIEW_SIZE, with a load that takes this
# long to fade out and in. The test frees it.
func _spawn_world(fade_seconds := 0.0) -> AreaHost:
	var scene := load(WORLD_PATH) as PackedScene
	assert_not_null(scene, "the world scene should load")
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := scene.instantiate() as AreaHost
	var tuning := AreaLoadTuning.new()
	tuning.fade_seconds = fade_seconds
	host.tuning = tuning
	view.add_child(host)
	host.space_entered.connect(func(space: Space) -> void: _entered.append({"space": space, "at": host.almos.global_position}))
	return host


func _camera_centre(host: AreaHost) -> Vector2:
	return (host.current_space.find_child("Camera", true, false) as Camera2D).get_screen_center_position()


# Almos put at this place, then walking in the given direction (an input action) until the host
# has loaded another space.
func _walk_through(host: AreaHost, from: Vector2, action: StringName) -> void:
	host.almos.global_position = from
	_almos_input.press_action(action)
	var frames := 0
	while _entered.is_empty() and frames < MOST_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	_almos_input.release_action(action)


func test_walking_into_the_east_doorway_of_open_map_1_loads_open_map_2() -> void:
	var host := _spawn_world()

	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")

	assert_eq(host.current_space.area_id, &"test_open_map_2", "Open map 2 should be the loaded space")


func test_open_map_2_has_almos_at_its_doorway_entrance_with_the_camera_on_him() -> void:
	var host := _spawn_world()

	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")
	await wait_physics_frames(2)

	assert_almost_eq(_entered[0]["at"], MAP_2_WEST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(_camera_centre(host), MAP_2_WEST_VIEW, Vector2(TOLERANCE, TOLERANCE))


func test_walking_back_through_the_doorway_of_open_map_2_returns_to_open_map_1_at_its_entrance() -> void:
	var host := _spawn_world()
	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")
	_entered = []

	await _walk_through(host, MAP_2_WEST_ENTRANCE + Vector2(FROM_DOORWAY, 0), &"move_left")
	await wait_physics_frames(2)

	assert_eq(host.current_space.area_id, MAP_1_ID, "Open map 1 should be the loaded space again")
	assert_almost_eq(_entered[0]["at"], MAP_1_EAST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(_camera_centre(host), MAP_1_EAST_VIEW, Vector2(TOLERANCE, TOLERANCE))


func test_walking_into_the_west_doorway_of_open_map_1_loads_the_building_in_room_a() -> void:
	var host := _spawn_world()

	await _walk_through(host, MAP_1_WEST_ENTRANCE + Vector2(FROM_DOORWAY, 0), &"move_left")
	await wait_physics_frames(2)

	var building := host.current_space as Building
	assert_not_null(building, "the building should be the loaded space")
	assert_eq(building.area_id, BUILDING_ID)
	assert_eq(building.current_room, building.get_node("RoomA"), "Almos should be in Room A")
	assert_almost_eq(_entered[0]["at"], ROOM_A_WEST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(_camera_centre(host), ROOM_A_CENTER, Vector2(TOLERANCE, TOLERANCE))


func test_walking_back_through_the_doorway_of_room_a_returns_to_open_map_1_at_its_entrance() -> void:
	var host := _spawn_world()
	await _walk_through(host, MAP_1_WEST_ENTRANCE + Vector2(FROM_DOORWAY, 0), &"move_left")
	_entered = []

	await _walk_through(host, ROOM_A_WEST_ENTRANCE + Vector2(FROM_DOORWAY, 0), &"move_left")
	await wait_physics_frames(2)

	assert_eq(host.current_space.area_id, MAP_1_ID, "Open map 1 should be the loaded space again")
	assert_almost_eq(_entered[0]["at"], MAP_1_WEST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(_camera_centre(host), MAP_1_WEST_VIEW, Vector2(TOLERANCE, TOLERANCE))


func test_it_is_the_same_almos_with_his_health_kept_in_the_space_he_comes_to() -> void:
	var host := _spawn_world()
	var almos := host.almos
	var damage := almos.health.maximum / 4.0
	almos.health.take_damage(damage)
	var health_before := almos.health.current

	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")

	assert_same(host.almos, almos, "Almos should be the same node")
	assert_true(almos.is_inside_tree(), "Almos should be in the new space")
	assert_eq(almos.health.current, health_before, "his Health should be kept")
	assert_lt(almos.health.current, almos.health.maximum, "the Health he had was less than full")


func test_the_health_bar_of_the_space_he_comes_to_shows_his_health() -> void:
	var host := _spawn_world()
	host.almos.health.take_damage(host.almos.health.maximum / 4.0)
	var health_before := host.almos.health.current

	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")

	var bar := host.current_space.find_child("HealthBar", true, false) as ProgressBar
	assert_eq(bar.value, health_before, "the bar should show the Health he has")


func test_almos_is_not_sent_straight_back_from_the_space_he_arrives_in() -> void:
	var host := _spawn_world()
	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")

	await wait_physics_frames(LINGER_FRAMES)

	assert_eq(host.current_space.area_id, MAP_2_ID, "Almos should still be in Open map 2")
	assert_eq(_entered.size(), 1, "a space should have been loaded once")


func test_only_the_space_almos_is_in_is_in_the_tree() -> void:
	var host := _spawn_world()
	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")

	await wait_physics_frames(2)

	var spaces := host.get_children().filter(func(child: Node) -> bool: return child is Space)
	assert_eq(spaces.size(), 1, "there should be one space in the host")
	assert_eq(spaces[0], host.current_space)


func test_a_load_takes_the_time_of_the_fade() -> void:
	var host := _spawn_world(FADE_SECONDS)
	host.almos.global_position = MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0)
	_almos_input.press_action(&"move_right")
	var frames := 0
	while not host.loading and frames < MOST_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	assert_true(host.loading, "walking into the doorway should begin a load")

	# Counted by the engine, not by the waits, which can take more than a frame each.
	var load_began := Engine.get_physics_frames()
	while _entered.is_empty() and Engine.get_physics_frames() - load_began < MOST_FRAMES:
		await wait_physics_frames(1)
	var load_frames := Engine.get_physics_frames() - load_began

	# The space is only swapped once the screen has faded out. A frame less for the one the load
	# began in.
	assert_gte(load_frames, int(FADE_SECONDS * FRAMES_PER_SECOND) - 1, "the old space should stay until the fade out is done")


func test_the_fade_is_short_and_is_in_the_data_file() -> void:
	var tuning := load(AREA_LOAD_DATA_PATH) as AreaLoadTuning

	assert_not_null(tuning, "the load tuning data should load")
	assert_between(tuning.fade_seconds, 0.05, 1.0, "the fade should be short")
