extends GutTest

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const OPEN_MAP_PATH := "res://scenes/areas/test_open_map.tscn"
# In physics frames. Long enough for Almos to walk a clear distance, short enough that he stays
# well away from every edge of the map when he starts at its centre.
const WALK_FRAMES := 30
# In world units. The extent of the view: the map's camera is at zoom 0.5, so the test's SubViewport
# is half this size (576×324, as the game is drawn). The test sets it, since a headless run has a
# window of its own, much smaller.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far Almos is put from the map's left edge, close enough that centring the view
# on him would show beyond it.
const NEAR_LEFT_EDGE := 100.0
# In pixels. How far Almos is put from the map's bottom right corner.
const NEAR_BOTTOM_RIGHT_CORNER := Vector2(60.0, 40.0)
# The least, in pixels, he must walk, so that a test where he never moved cannot pass.
const LEAST_PROGRESS := 20.0
const TOLERANCE := 0.01

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


# The test Open map in the test's scene tree, shown in a view of VIEW_SIZE. The test frees it.
func _spawn_map() -> TestOpenMap:
	var scene := load(OPEN_MAP_PATH) as PackedScene
	assert_not_null(scene, "the test Open map scene should load")
	var view := SubViewport.new()
	view.size = VIEW_SIZE / 2
	add_child_autofree(view)
	var map := scene.instantiate() as TestOpenMap
	view.add_child(map)
	return map


func test_camera_centre_is_on_almos_away_from_the_edges() -> void:
	var map := _spawn_map()
	var almos := map.find_child("Almos", true, false) as Almos
	var camera := map.find_child("Camera", true, false) as Camera2D
	var start_x := almos.global_position.x
	_almos_input.press_action(&"move_right")

	await wait_physics_frames(WALK_FRAMES)

	assert_gt(almos.global_position.x, start_x + LEAST_PROGRESS, "Almos should have walked")
	assert_almost_eq(camera.get_screen_center_position(), almos.global_position, Vector2(TOLERANCE, TOLERANCE))


func test_camera_centre_stays_a_half_view_inside_the_left_edge() -> void:
	var map := _spawn_map()
	var almos := map.find_child("Almos", true, false) as Almos
	var camera := map.find_child("Camera", true, false) as Camera2D
	almos.global_position = Vector2(NEAR_LEFT_EDGE, map.bounds.get_center().y)

	await wait_physics_frames(WALK_FRAMES)

	var half_view := Vector2(VIEW_SIZE) / 2.0
	assert_almost_eq(camera.get_screen_center_position(), Vector2(map.bounds.position.x + half_view.x, almos.global_position.y), Vector2(TOLERANCE, TOLERANCE))


func test_camera_view_stays_inside_the_map_at_the_bottom_right_corner() -> void:
	var map := _spawn_map()
	var almos := map.find_child("Almos", true, false) as Almos
	var camera := map.find_child("Camera", true, false) as Camera2D
	almos.global_position = map.bounds.end - NEAR_BOTTOM_RIGHT_CORNER

	await wait_physics_frames(WALK_FRAMES)

	var view := Rect2(camera.get_screen_center_position() - Vector2(VIEW_SIZE) / 2.0, VIEW_SIZE)
	assert_eq(view.end, map.bounds.end, "the view should end exactly at the corner of the map")


func test_open_map_is_bigger_than_the_game_window() -> void:
	var map := _spawn_map()
	var window := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1152),
		ProjectSettings.get_setting("display/window/size/viewport_height", 648),
	)

	assert_true(map.bounds.size.x > window.x and map.bounds.size.y > window.y, "the map should be bigger than the window both ways, so that it scrolls")


func test_camera_view_stays_inside_the_map_at_the_top_right_corner() -> void:
	var map := _spawn_map()
	var almos := map.find_child("Almos", true, false) as Almos
	var camera := map.find_child("Camera", true, false) as Camera2D
	almos.global_position = Vector2(map.bounds.end.x, map.bounds.position.y) + Vector2(-NEAR_BOTTOM_RIGHT_CORNER.x, NEAR_BOTTOM_RIGHT_CORNER.y)

	await wait_physics_frames(WALK_FRAMES)

	var view := Rect2(camera.get_screen_center_position() - Vector2(VIEW_SIZE) / 2.0, VIEW_SIZE)
	assert_eq(view.position.y, map.bounds.position.y, "the view should start exactly at the top of the map")


func test_camera_view_stays_inside_the_map_at_the_right_edge() -> void:
	var map := _spawn_map()
	var almos := map.find_child("Almos", true, false) as Almos
	var camera := map.find_child("Camera", true, false) as Camera2D
	almos.global_position = Vector2(map.bounds.end.x - NEAR_LEFT_EDGE, map.bounds.get_center().y)

	await wait_physics_frames(WALK_FRAMES)

	var view_end_x := camera.get_screen_center_position().x + VIEW_SIZE.x / 2.0
	assert_eq(view_end_x, map.bounds.end.x, "the view should end exactly at the right edge of the map")


func test_camera_view_stays_inside_the_map_when_zoomed_in() -> void:
	var map := _spawn_map()
	var almos := map.find_child("Almos", true, false) as Almos
	var camera := map.find_child("Camera", true, false) as Camera2D
	camera.zoom = Vector2(1.0, 1.0)
	almos.global_position = Vector2(NEAR_LEFT_EDGE, map.bounds.get_center().y)

	await wait_physics_frames(WALK_FRAMES)

	# Zoomed in twice, the view is half as wide in the map: 576 pixels, so its centre stops 288 from the edge.
	assert_almost_eq(camera.get_screen_center_position().x, map.bounds.position.x + 288.0, TOLERANCE)
