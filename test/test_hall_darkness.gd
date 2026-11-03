extends GutTest
## Cell 3 is seen whole, but in Corridor 1, the hall outside, the camera closes in on Almos and
## follows him, and the hall is dark but for a small circle around him and the pools of light that
## lit torches throw.

const DUNGEONS_SCENE := preload("res://scenes/areas/dungeons/dungeons.tscn")

var _dungeons: DungeonsBuilding


func before_each() -> void:
	WorldState.reset()
	_dungeons = DUNGEONS_SCENE.instantiate() as DungeonsBuilding
	add_child_autofree(_dungeons)
	await wait_physics_frames(2)


func _camera() -> Camera2D:
	return _dungeons.find_child("Camera", false, false) as Camera2D


func _put_in(room_id: StringName, at: Vector2) -> Room:
	var room := _dungeons.room(room_id)
	_dungeons.put_almos_at(room.global_position + at)
	return room


func test_the_cell_is_seen_whole() -> void:
	var cell := _put_in(&"cell_3", Vector2(576, 400))
	await wait_process_frames(2)
	assert_false(cell.follows_almos, "the cell keeps its fixed view")
	assert_almost_eq(_camera().get_screen_center_position(), cell.get_view_center(), Vector2(2, 2), "all of it in view")
	assert_eq(cell.find_children("*", "Darkness", true, false).size(), 0, "and nothing dark over it")


func test_in_the_hall_the_camera_closes_in_and_follows_him_inside_the_room() -> void:
	var hall := _put_in(&"corridor_1", Vector2(576, 324))
	await wait_process_frames(2)
	assert_true(hall.follows_almos, "the hall follows him")
	assert_gt(_camera().zoom.x, 0.5, "closer in than a whole Room")
	assert_almost_eq(_camera().global_position, _dungeons.almos.global_position, Vector2(2, 2), "centred on him")
	# Near the Room's corner the view stops at its edges.
	_dungeons.almos.global_position = hall.global_position + Vector2(40, 80)
	await wait_process_frames(2)
	var half := _camera().get_viewport_rect().size / _camera().zoom / 2.0
	assert_gte(_camera().global_position.x - half.x, hall.global_position.x - 0.01, "never past the west edge")
	assert_gte(_camera().global_position.y - half.y, hall.global_position.y - 0.01, "never past the north edge")
	# Back in the cell, the whole view again.
	var cell := _put_in(&"cell_3", Vector2(576, 400))
	await wait_process_frames(2)
	assert_almost_eq(_camera().zoom, Vector2(0.5, 0.5), Vector2(0.01, 0.01), "the cell's zoom")
	assert_almost_eq(_camera().get_screen_center_position(), cell.get_view_center(), Vector2(2, 2), "the cell whole")


func test_the_hall_is_dark_but_round_him_and_under_its_lamps() -> void:
	var hall := _put_in(&"corridor_1", Vector2(576, 150))
	await wait_process_frames(2)
	var darkness := hall.get_node("Darkness") as Darkness
	assert_eq(darkness.target, _dungeons.almos, "it sees by him")
	var almos := _dungeons.almos
	assert_true(darkness.shows(almos.global_position + Vector2(30, 0)), "near him he sees")
	assert_false(darkness.shows(almos.global_position + Vector2(0, 260)), "far off is dark")
	var lamp := hall.get_node("Lamp1") as Torch
	assert_true(darkness.shows(lamp.global_position + Vector2(0, 20)), "a lit lamp shows its pool")
	lamp.extinguish()
	assert_false(darkness.shows(lamp.global_position + Vector2(0, 20)), "a lamp put out leaves it dark")
