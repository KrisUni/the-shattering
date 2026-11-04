extends GutTest
## Cell 2 holds a dead prisoner's remains: his skeleton slumped against the wall, a black ring by
## his hand, and writing he cut into the wall above him. Almos looks at each with a tap of Interact
## beside it, and his thought about it shows in a text box: the writing reads I SAW THE SERPENT GOD.
## Far from them, a tap shows nothing.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a spot Almos stands: well inside his reach.
const BESIDE := 6.0
const TAP_FRAMES := 3

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_the_remains_are_inspect_spots_with_art() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	for spot_name in ["Skeleton", "BlackRing", "Carving"]:
		var spot := _room(host).get_node_or_null("Remains/%s" % spot_name) as InspectSpot
		assert_not_null(spot, "Cell 2 has the %s" % spot_name)
		if spot == null:
			continue
		assert_gt(spot.lines.size(), 0, "%s has a thought" % spot_name)
		assert_not_null((spot.get_node("Art") as Sprite2D).texture, "%s is drawn" % spot_name)


func test_a_tap_of_interact_beside_the_carving_reads_it() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _tap_beside(host, "Carving")

	var text := InspectSpot.showing()
	assert_not_null(text, "a text box shows")
	if text != null:
		assert_eq(text.lines, PackedStringArray(["I SAW THE SERPENT GOD"]), "it reads what is cut into the wall")


func test_a_tap_of_interact_beside_the_skeleton_and_the_ring_shows_his_thoughts() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	for spot_name in ["Skeleton", "BlackRing"]:
		await _tap_beside(host, spot_name)
		var text := InspectSpot.showing()
		assert_not_null(text, "a text box shows for the %s" % spot_name)
		if text != null:
			var spot := _room(host).get_node("Remains/%s" % spot_name) as InspectSpot
			assert_eq(text.lines, spot.lines, "it shows the %s's thought, in place of the last" % spot_name)


func test_a_tap_of_interact_far_from_the_remains_shows_nothing() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	host.almos.global_position = _room(host).global_position + Vector2(700.0, 400.0)
	await _tap(&"interact")

	assert_null(InspectSpot.showing(), "no text box shows")


func _tap_beside(host: AreaHost, spot_name: String) -> void:
	var spot := _room(host).get_node("Remains/%s" % spot_name) as Node2D
	host.almos.global_position = spot.global_position + Vector2(BESIDE, BESIDE)
	await wait_physics_frames(1)
	await _tap(&"interact")


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func _room(host: AreaHost) -> Room:
	return (host.current_space as DungeonsBuilding).room(&"cell_2")


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)
