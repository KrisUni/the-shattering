extends GutTest
## Cell 3 is seen whole, and so is Corridor 1, the hall outside, at the same scale; but the hall is
## dark but for a circle around Almos, and its torches show no light through the dark.

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


func test_the_hall_is_seen_at_the_cells_scale() -> void:
	var hall := _put_in(&"corridor_1", Vector2(576, 150))
	await wait_process_frames(2)
	assert_almost_eq(_camera().zoom, Vector2(0.5, 0.5), Vector2(0.01, 0.01), "no closer than the cell")
	assert_almost_eq(_camera().get_screen_center_position(), hall.get_view_center(), Vector2(2, 2), "the room in view")


func test_the_hall_is_dark_but_round_him_and_flames_give_no_light() -> void:
	var hall := _put_in(&"corridor_1", Vector2(576, 150))
	await wait_process_frames(2)
	var darkness := hall.get_node("Darkness") as Darkness
	assert_eq(darkness.target, _dungeons.almos, "it sees by him")
	var almos := _dungeons.almos
	assert_true(darkness.shows(almos.global_position + Vector2(150, 0)), "he sees a fair way round himself")
	assert_false(darkness.shows(almos.global_position + Vector2(0, 400)), "far off is dark")
	var lamp := hall.get_node("Lamp1") as Torch
	assert_true(lamp.lit, "control: the lamp burns")
	assert_false(darkness.shows(lamp.global_position + Vector2(0, 20)), "but shows no light through the dark")
