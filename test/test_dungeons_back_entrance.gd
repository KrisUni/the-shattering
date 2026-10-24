extends GutTest
## The Back entrance, the west exit of Corridor 1, is hidden behind a seal of rotting boards. While the
## seal is whole Almos cannot walk out by it; once it has burnt out the way to Back corridor 1 is open.
## Burning it is a change to the world like any other: a Death undoes it unless Almos has rested since.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const FIRE_PATH := "res://data/fire.tres"
const SEAL_ID := &"dungeons/corridor_1/back_entrance_seal"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from the Back entrance's end of Corridor 1 Almos is put before walking west.
const FROM_WEST_END := 200.0
# In pixels. How far from a Checkpoint Almos stands: well inside his reach.
const BESIDE := 5.0
const TAP_FRAMES := 3
const MARGIN_FRAMES := 8
# In physics frames. Long enough to walk the length of the walk west, and then keep walking.
const WALK_FRAMES := 240
# In physics frames. The most a rest, or a Death and the return after it, is waited for.
const MOST_FRAMES := 600

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_corridor_1_holds_a_seal_of_its_own_over_the_back_entrance() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var seal := _seal(host)

	assert_not_null(seal, "Corridor 1 should hold a seal")
	assert_eq(seal.id, SEAL_ID, "the seal should be called by its own id")
	assert_false(seal.open, "the seal should be whole")


func test_a_whole_seal_keeps_almos_in_corridor_1_when_he_walks_west() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _walk_west_from_the_middle_of_corridor_1(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"corridor_1"), "he should still be in Corridor 1")


func test_a_seal_burnt_out_lets_almos_walk_west_into_back_corridor_1() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_seal(host)
	assert_true(_seal(host).open, "control: the seal burnt open")

	await _walk_west_from_the_middle_of_corridor_1(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"back_corridor_1"), "he should have come into Back corridor 1")


func test_a_death_before_a_rest_makes_the_burnt_seal_whole_again() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_seal(host)
	assert_true(_seal(host).open, "control: the seal burnt open")

	await _die_and_wait_for_the_return(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"cell_3"), "he should be back in Cell 3")
	assert_false(_seal(host).open, "the seal should be whole")
	assert_false(WorldState.is_burnt(SEAL_ID), "the seal should not be remembered as burnt")


func test_a_death_after_a_rest_at_back_corridor_1s_checkpoint_leaves_the_burnt_seal_open() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_seal(host)
	await _rest_at(host, &"back_corridor_1")

	await _die_and_wait_for_the_return(host)

	assert_true(_seal(host).open, "the seal should be open")
	assert_true(WorldState.is_burnt(SEAL_ID), "the seal should be remembered as burnt")


func test_a_death_after_a_rest_at_the_lobbys_checkpoint_leaves_the_burnt_seal_open() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_seal(host)
	await _rest_at(host, &"lobby")

	await _die_and_wait_for_the_return(host)

	assert_true(_seal(host).open, "the seal should be open")


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func _room(host: AreaHost, id: StringName) -> Room:
	return (host.current_space as DungeonsBuilding).room(id)


# The path blocker over the Back entrance in Corridor 1, or null if there is none.
func _seal(host: AreaHost) -> PathBlocker:
	return _room(host, &"corridor_1").get_node_or_null("BackEntranceSeal") as PathBlocker


func _checkpoints_in(node: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for candidate in node.find_children("*", "Node2D", true, false):
		if candidate.is_in_group(&"checkpoints"):
			found.append(candidate)
	return found


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# The seal is set alight and burns out, which is what a swing of Fire at it comes to.
func _burn_the_seal(host: AreaHost) -> void:
	_seal(host).flammable.ignite()
	var burn_seconds := (load(FIRE_PATH) as FireTuning).burn_time
	await wait_physics_frames(ceili(burn_seconds * Engine.physics_ticks_per_second) + MARGIN_FRAMES)


# Almos is put in Corridor 1, level with the Back entrance and some way east of it, and walks west.
func _walk_west_from_the_middle_of_corridor_1(host: AreaHost) -> void:
	var dungeons := host.current_space as DungeonsBuilding
	var exit_strip := _room(host, &"corridor_1").get_node("Exits/back_entrance") as Node2D
	dungeons.put_almos_at(exit_strip.global_position + Vector2(FROM_WEST_END, 0.0))
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.press_action(&"move_left")
	await wait_physics_frames(WALK_FRAMES)
	_almos_input.release_action(&"move_left")


# Almos stands beside the Checkpoint in the Room and rests at it with a tap of Interact; this returns
# when the space has been made new.
func _rest_at(host: AreaHost, room_id: StringName) -> void:
	var checkpoint := _checkpoints_in(_room(host, room_id))[0]
	host.almos.global_position = checkpoint.global_position + Vector2(BESIDE, 0.0)
	await _tap(&"interact")
	var frames := 0
	while host.loading and frames < MOST_FRAMES:
		await get_tree().physics_frame
		frames += 1
	await wait_physics_frames(TAP_FRAMES)


# Almos's Health is taken to zero, and the test waits until he is sent back and the load is over.
func _die_and_wait_for_the_return(host: AreaHost) -> void:
	host.almos.health.take_damage(host.almos.health.maximum)
	var frames := 0
	while (host.almos.dead or host.loading or frames < TAP_FRAMES) and frames < MOST_FRAMES:
		await get_tree().physics_frame
		frames += 1
	assert_lt(frames, MOST_FRAMES, "he should have been sent back")
	await wait_physics_frames(TAP_FRAMES)
