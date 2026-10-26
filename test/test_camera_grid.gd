extends GutTest
## The cameras sit on the art pixel grid (a multiple of OpenMapCamera.ART_PIXEL world units), and an
## Open map's view stays inside its bounds, at the 576×324 view the game is drawn in.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const BUILDING_PATH := "res://scenes/areas/test_building.tscn"
# In pixels. The size of the view the game is drawn in.
const VIEW_SIZE := Vector2i(576, 324)
# The zoom that shows 1152×648 world units in that view.
const ZOOM := Vector2(0.5, 0.5)
# In world units. The map: big enough for the view to move in, on whole units.
const BOUNDS := Rect2(-400, -300, 2000, 1500)
# In world units. Where the target is put: off the grid, and near each edge and corner of the
# bounds (the view's half is 576×324, so these are at and beyond where it stops).
const TARGETS: Array[Vector2] = [
	Vector2(0.3, 0.7), Vector2(123.456, -77.77), Vector2(-399.9, 500.1), Vector2(1599.9, 500.1),
	Vector2(500.1, -299.9), Vector2(500.1, 1199.9), Vector2(-399.9, -299.9), Vector2(1599.9, -299.9),
	Vector2(-399.9, 1199.9), Vector2(1599.9, 1199.9), Vector2(-1000.5, -1000.5), Vector2(5000.3, 5000.3),
	Vector2(575.99, 323.99), Vector2(577.01, 325.01),
]
# In world units. A map whose edges, and so whose clamp limits, are on odd units: the limits must
# move inward to the grid for the view to stay inside after the position is snapped.
const ODD_BOUNDS := Rect2(-401, -301, 2002, 1502)
# In world units. "The same place", for the view's edges.
const TOLERANCE := 0.001
# In world units. How far a Room of the test building is moved, to put its view centre off the grid.
const ROOM_OFFSET := Vector2(0.3, 0.7)
# As the existing building tests have it.
const A_EAST_ENTRANCE := Vector2(1152 - 8 - 56, 324)
const FROM_EXIT := 100.0
const MOST_FRAMES_TO_EXIT := 180

var _almos_input: AlmosInput


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


# An OpenMapCamera at zoom 0.5 in a view of VIEW_SIZE, following a target. The test frees them.
func _spawn_camera(bounds := BOUNDS) -> OpenMapCamera:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var target := Node2D.new()
	view.add_child(target)
	var camera := OpenMapCamera.new()
	camera.zoom = ZOOM
	camera.bounds = bounds
	camera.target = target
	view.add_child(camera)
	return camera


func _on_grid(value: float) -> bool:
	return is_equal_approx(fposmod(value, OpenMapCamera.ART_PIXEL), 0.0) or is_equal_approx(fposmod(value, OpenMapCamera.ART_PIXEL), OpenMapCamera.ART_PIXEL)


func test_open_map_camera_sits_on_the_art_grid_for_every_off_grid_target() -> void:
	var camera := _spawn_camera()
	var off_grid: Array[Vector2] = []

	for place in TARGETS:
		camera.target.global_position = place
		camera.snap_to_target()
		if not (_on_grid(camera.global_position.x) and _on_grid(camera.global_position.y)):
			off_grid.append(camera.global_position)

	assert_eq(off_grid, [] as Array[Vector2], "no camera position should be between two art pixels")


func test_open_map_camera_view_stays_inside_the_bounds_for_every_off_grid_target() -> void:
	var camera := _spawn_camera()
	var outside: Array[Vector2] = []
	var half_view := Vector2(VIEW_SIZE) / ZOOM / 2.0

	for place in TARGETS:
		camera.target.global_position = place
		camera.snap_to_target()
		var view := Rect2(camera.global_position - half_view, half_view * 2.0)
		if not BOUNDS.grow(TOLERANCE).encloses(view):
			outside.append(place)

	assert_eq(outside, [] as Array[Vector2], "the view should never show beyond the map")


func test_open_map_camera_view_stays_inside_odd_bounds_on_the_art_grid() -> void:
	var camera := _spawn_camera(ODD_BOUNDS)
	var half_view := Vector2(VIEW_SIZE) / ZOOM / 2.0
	var places: Array[Vector2] = []
	for x in [ODD_BOUNDS.position.x - 50.0, ODD_BOUNDS.position.x + 0.5, 300.3, ODD_BOUNDS.end.x - 0.5, ODD_BOUNDS.end.x + 50.0]:
		for y in [ODD_BOUNDS.position.y - 50.0, ODD_BOUNDS.position.y + 0.5, 200.7, ODD_BOUNDS.end.y - 0.5, ODD_BOUNDS.end.y + 50.0]:
			places.append(Vector2(x, y))
	var bad: Array[Vector2] = []

	for place in places:
		camera.target.global_position = place
		camera.snap_to_target()
		var at := camera.global_position
		var view := Rect2(at - half_view, half_view * 2.0)
		if not (_on_grid(at.x) and _on_grid(at.y) and ODD_BOUNDS.grow(0.0).encloses(view)):
			bad.append(place)

	assert_eq(bad, [] as Array[Vector2], "the view should be on the grid and inside the odd bounds")


func test_open_map_camera_follows_a_target_in_the_middle_to_the_nearest_art_pixel() -> void:
	var camera := _spawn_camera()
	camera.target.global_position = Vector2(500.6, 300.2)

	camera.snap_to_target()

	assert_eq(camera.global_position, Vector2(500, 300), "500.6 and 300.2 should land on 500 and 300")


func test_building_camera_sits_on_the_art_grid_at_a_room_whose_view_centre_is_off_grid() -> void:
	var scene := load(BUILDING_PATH) as PackedScene
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var building := scene.instantiate() as Building
	(building.get_node("RoomA") as Node2D).position += ROOM_OFFSET
	view.add_child(building)
	await wait_physics_frames(2)

	var at := (building.find_child("Camera", false, false) as Camera2D).global_position

	assert_true(_on_grid(at.x) and _on_grid(at.y), "the camera at %s should be on the art grid" % at)


func test_building_camera_sits_on_the_art_grid_after_entering_a_room_whose_view_centre_is_off_grid() -> void:
	var scene := load(BUILDING_PATH) as PackedScene
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var building := scene.instantiate() as Building
	(building.get_node("RoomB") as Node2D).position += ROOM_OFFSET
	view.add_child(building)
	var entered := []
	building.room_changed.connect(func(room: Room) -> void: entered.append(room))
	building.almos.global_position = A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0)
	_almos_input.press_action(&"move_right")
	var frames := 0
	while entered.is_empty() and frames < MOST_FRAMES_TO_EXIT:
		await wait_physics_frames(1)
		frames += 1
	_almos_input.release_action(&"move_right")

	var at := (building.find_child("Camera", false, false) as Camera2D).global_position

	assert_eq(entered.size(), 1, "Almos should have come into Room B")
	assert_true(_on_grid(at.x) and _on_grid(at.y), "the camera at %s should be on the art grid" % at)
