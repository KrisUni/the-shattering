extends GutTest
## What the world remembers of each area, tested through the host scene: Open map 1 (a Checkpoint
## and a burnable door) joined to Open map 2 (a Checkpoint, a named enemy and an ordinary one).
## After a rest, burnt openings, Remains and defeated named enemies are as they were on leaving and
## coming back; a Death undoes what was done since the rest, but not the Remains it leaves or the
## deaths of named enemies. The places are data of the scenes, and the numbers here are those of
## their design. Each test resets WorldState first and last.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const BUILDING_PATH := "res://scenes/areas/test_building.tscn"
const FIRE_PATH := "res://data/fire.tres"
const PLAYER_TUNING_PATH := "res://data/player_tuning.tres"
# In pixels. The size of the view the world is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
const MAP_1_ID := &"test_open_map"
const MAP_2_ID := &"test_open_map_2"
# In pixels. Where Almos starts in map 1, and where he is put on arriving at each doorway: 56
# inside the space from the doorway he came through.
const MAP_1_START := Vector2(1152, 648)
const MAP_1_EAST_ENTRANCE := Vector2(2240 - 56, 648)
const MAP_2_WEST_ENTRANCE := Vector2(64 + 56, 486)
# In pixels. How far from its entrance Almos is put before walking into a doorway.
const FROM_DOORWAY := 100.0
# In pixels. How far from a Checkpoint's centre Almos is put to rest: within reach.
const BESIDE_THE_CHECKPOINT := 10.0
# In pixels. Where Almos falls in map 2, clear of the enemies and the doorway.
const MAP_2_FALL_PLACE := Vector2(500, 700)
# In Experience. What he carries when he dies.
const CARRIED := 137
# In physics frames. The longest a walk through a doorway, a rest or a Death may take.
const MOST_FRAMES := 400
# In physics frames. How long to let a press reach Almos and take effect.
const TAP_FRAMES := 3
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 6
const FRAMES_PER_SECOND := 60
# In pixels. "Within a pixel", for the places Almos is put at.
const TOLERANCE := 1.0

var _almos_input: AlmosInput
var _entered: Array[Space] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	WorldState.reset()
	_almos_input = AlmosInput.new(self)
	_entered = []


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


# The host in the test's scene tree, shown in a view of VIEW_SIZE, with loads that fade for this long.
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
	host.space_entered.connect(func(space: Space) -> void: _entered.append(space))
	return host


# Almos put at this place, then walking in the given direction (an input action) until the host
# has loaded another space.
func _walk_through(host: AreaHost, from: Vector2, action: StringName) -> void:
	_entered = []
	host.almos.global_position = from
	_almos_input.press_action(action)
	var frames := 0
	while _entered.is_empty() and frames < MOST_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	_almos_input.release_action(action)
	await wait_physics_frames(MARGIN_FRAMES)


func _go_to_map_2(host: AreaHost) -> void:
	await _walk_through(host, MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0), &"move_right")
	assert_eq(host.current_space.area_id, MAP_2_ID, "control: Almos should be in map 2")


func _go_to_map_1(host: AreaHost) -> void:
	await _walk_through(host, MAP_2_WEST_ENTRANCE + Vector2(FROM_DOORWAY, 0), &"move_left")
	assert_eq(host.current_space.area_id, MAP_1_ID, "control: Almos should be in map 1")


# Almos rests at the Checkpoint of the space he is in, and the test asserts that he did, once.
func _rest(host: AreaHost) -> void:
	var checkpoint := host.current_space.find_child("Checkpoint", true, false) as Node2D
	host.almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT
	var rests: Array[int] = [0]
	var count := func(_rested_at: Checkpoint) -> void: rests[0] += 1
	host.almos.rested.connect(count)
	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(TAP_FRAMES + MARGIN_FRAMES)
	host.almos.rested.disconnect(count)
	assert_eq(rests[0], 1, "control: Almos should have rested once")


# Sets the door of map 1 alight and waits for it to burn out.
func _burn_the_door(host: AreaHost) -> void:
	var door := host.current_space.find_child("Door", true, false) as PathBlocker
	door.flammable.ignite()
	var burn_frames := ceili((load(FIRE_PATH) as FireTuning).burn_time * FRAMES_PER_SECOND) + MARGIN_FRAMES
	await wait_physics_frames(burn_frames)
	assert_true(door.open, "control: the door should have burnt out")


# Almos's Health is taken to zero, and the test waits for the pause of the Death to be over and for
# him to be sent back.
func _die(host: AreaHost) -> void:
	var tuning := load(PLAYER_TUNING_PATH) as PlayerTuning
	host.almos.health.take_damage(host.almos.health.maximum)
	await wait_physics_frames(ceili(tuning.death_pause * FRAMES_PER_SECOND) + MARGIN_FRAMES)


# Almos carries this much Experience, is put at this place, and dies there. As for _die.
func _die_at(host: AreaHost, place: Vector2, carried: int) -> void:
	host.almos.experience.gain(carried)
	host.almos.global_position = place
	await _die(host)


# The sets of Remains in the space Almos is in.
func _remains_in(host: AreaHost) -> Array[Remains]:
	var found: Array[Remains] = []
	for node in get_tree().get_nodes_in_group(&"remains"):
		if host.current_space.is_ancestor_of(node):
			found.append(node as Remains)
	return found


# The enemy of this name in the space Almos is in has its Health taken to zero, and the test waits
# for it to be gone.
func _kill(host: AreaHost, enemy_name: String) -> void:
	var enemy := host.current_space.find_child(enemy_name, true, false)
	assert_not_null(enemy, "control: %s should be there to kill" % enemy_name)
	enemy.health.take_damage(enemy.health.maximum)
	await wait_physics_frames(MARGIN_FRAMES)


func _door_is_open(host: AreaHost) -> bool:
	return (host.current_space.find_child("Door", true, false) as PathBlocker).open


func test_a_door_burnt_before_a_rest_is_still_open_after_going_to_map_2_and_back() -> void:
	var host := _spawn_world()
	await _burn_the_door(host)
	await _rest(host)

	await _go_to_map_2(host)
	await _go_to_map_1(host)

	assert_true(_door_is_open(host))


func test_a_door_burnt_with_no_rest_is_still_open_after_going_to_map_2_and_back() -> void:
	var host := _spawn_world()
	await _burn_the_door(host)

	await _go_to_map_2(host)
	await _go_to_map_1(host)

	assert_true(_door_is_open(host))


func test_a_door_burnt_since_the_last_rest_is_closed_again_after_a_death() -> void:
	var host := _spawn_world()
	await _burn_the_door(host)

	await _die(host)

	assert_false(_door_is_open(host))


func test_a_door_burnt_before_a_rest_is_still_open_after_a_death() -> void:
	var host := _spawn_world()
	await _burn_the_door(host)
	await _rest(host)

	await _die(host)

	assert_true(_door_is_open(host))


func test_a_door_burnt_before_two_rests_in_a_row_is_still_open_after_a_death() -> void:
	var host := _spawn_world()
	await _burn_the_door(host)
	await _rest(host)
	await _rest(host)

	await _die(host)

	assert_true(_door_is_open(host))


func test_a_death_before_any_rest_sends_almos_back_to_where_he_started() -> void:
	var host := _spawn_world()
	host.almos.global_position = MAP_1_START + Vector2(200, 0)

	await _die(host)

	assert_almost_eq(host.almos.global_position, MAP_1_START, Vector2(TOLERANCE, TOLERANCE))


func test_a_death_in_map_2_sends_almos_back_to_the_checkpoint_in_map_1() -> void:
	var host := _spawn_world()
	await _rest(host)
	var checkpoint_at := (host.current_space.find_child("Checkpoint", true, false) as Node2D).global_position
	await _go_to_map_2(host)

	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)

	assert_eq(host.current_space.area_id, MAP_1_ID, "Almos should be in map 1")
	assert_almost_eq(host.almos.global_position, checkpoint_at, Vector2(TOLERANCE, TOLERANCE))


func test_a_death_in_map_2_leaves_remains_there_holding_what_he_carried() -> void:
	var host := _spawn_world()
	await _rest(host)
	await _go_to_map_2(host)
	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)

	await _go_to_map_2(host)

	var remains := _remains_in(host)
	assert_eq(remains.size(), 1, "there should be one set of Remains in map 2")
	assert_eq(remains[0].amount, CARRIED)
	assert_almost_eq(remains[0].global_position, MAP_2_FALL_PLACE, Vector2(TOLERANCE, TOLERANCE))


func test_remains_left_in_map_2_are_where_they_were_after_going_to_map_1_and_back() -> void:
	var host := _spawn_world()
	await _rest(host)
	await _go_to_map_2(host)
	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)
	await _go_to_map_2(host)
	await _go_to_map_1(host)

	await _go_to_map_2(host)

	var remains := _remains_in(host)
	assert_eq(remains.size(), 1, "there should still be one set of Remains in map 2")
	assert_almost_eq(remains[0].global_position, MAP_2_FALL_PLACE, Vector2(TOLERANCE, TOLERANCE))


func test_no_remains_are_in_map_1_when_almos_died_in_map_2() -> void:
	var host := _spawn_world()
	await _rest(host)
	await _go_to_map_2(host)

	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)

	assert_eq(_remains_in(host).size(), 0)


func test_touching_remains_left_in_map_2_gives_almos_the_experience_back() -> void:
	var host := _spawn_world()
	await _rest(host)
	await _go_to_map_2(host)
	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)
	await _go_to_map_2(host)

	host.almos.global_position = MAP_2_FALL_PLACE
	await wait_physics_frames(TAP_FRAMES)

	assert_eq(host.almos.experience.total, CARRIED)
	assert_eq(_remains_in(host).size(), 0, "the Remains should be gone")


func test_remains_recovered_are_not_there_when_map_2_is_loaded_again() -> void:
	var host := _spawn_world()
	await _rest(host)
	await _go_to_map_2(host)
	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)
	await _go_to_map_2(host)
	host.almos.global_position = MAP_2_FALL_PLACE
	await wait_physics_frames(TAP_FRAMES)
	await _go_to_map_1(host)

	await _go_to_map_2(host)

	assert_eq(_remains_in(host).size(), 0)


func test_a_second_death_replaces_the_remains_of_the_first() -> void:
	var host := _spawn_world()
	await _rest(host)
	await _go_to_map_2(host)
	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)
	await _go_to_map_2(host)

	await _die_at(host, MAP_2_FALL_PLACE + Vector2(200, 0), CARRIED + 1)
	await _go_to_map_2(host)

	var remains := _remains_in(host)
	assert_eq(remains.size(), 1, "there should be one set of Remains")
	assert_eq(remains[0].amount, CARRIED + 1)


func test_a_death_in_map_1_leaves_remains_in_map_1_where_he_fell() -> void:
	var host := _spawn_world()
	var fall_place := MAP_1_START + Vector2(300, 100)

	await _die_at(host, fall_place, CARRIED)

	var remains := _remains_in(host)
	assert_eq(remains.size(), 1, "there should be Remains in map 1")
	assert_almost_eq(remains[0].global_position, fall_place, Vector2(TOLERANCE, TOLERANCE))


func test_a_named_enemy_killed_in_map_2_stays_dead_after_going_to_map_1_and_back() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)
	await _kill(host, "Guard")
	await _go_to_map_1(host)

	await _go_to_map_2(host)

	assert_null(host.current_space.find_child("Guard", true, false))


func test_a_named_enemy_killed_in_map_2_stays_dead_after_a_death() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)
	await _kill(host, "Guard")
	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)

	await _go_to_map_2(host)

	assert_null(host.current_space.find_child("Guard", true, false))


func test_a_named_enemy_not_killed_is_in_map_2_when_it_is_loaded() -> void:
	var host := _spawn_world()

	await _go_to_map_2(host)

	assert_not_null(host.current_space.find_child("Guard", true, false))


func test_a_rest_brings_back_an_ordinary_enemy_killed_in_the_area() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)
	var sentry_at := (host.current_space.find_child("Sentry", true, false) as Node2D).global_position
	await _kill(host, "Sentry")
	assert_null(host.current_space.find_child("Sentry", true, false), "control: the Sentry should be dead")

	await _rest(host)

	var sentry := host.current_space.find_child("Sentry", true, false)
	assert_not_null(sentry, "the Sentry should be back")
	assert_almost_eq(sentry.global_position, sentry_at, Vector2(TOLERANCE, TOLERANCE))
	assert_eq(sentry.health.current, sentry.health.maximum, "it should be at full Health")


func test_a_rest_leaves_a_named_enemy_killed_in_the_area_dead() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)
	await _kill(host, "Guard")

	await _rest(host)

	assert_null(host.current_space.find_child("Guard", true, false))


func test_a_rest_leaves_almos_where_he_rested_with_the_camera_on_him() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)

	await _rest(host)

	var checkpoint := host.current_space.find_child("Checkpoint", true, false) as Node2D
	var camera := host.current_space.find_child("Camera", true, false) as Camera2D
	assert_almost_eq(host.almos.global_position, checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT, Vector2(TOLERANCE, TOLERANCE))
	assert_almost_eq(camera.get_screen_center_position(), host.almos.global_position, Vector2(TOLERANCE, TOLERANCE))


func test_an_ordinary_enemy_killed_and_not_rested_is_back_in_map_2_when_it_is_loaded_again() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)
	await _kill(host, "Sentry")
	await _go_to_map_1(host)

	await _go_to_map_2(host)

	assert_not_null(host.current_space.find_child("Sentry", true, false))


func test_a_death_after_a_rest_in_map_2_sends_almos_back_to_that_checkpoint() -> void:
	var host := _spawn_world()
	await _go_to_map_2(host)
	await _rest(host)
	var checkpoint_at := (host.current_space.find_child("Checkpoint", true, false) as Node2D).global_position

	await _die_at(host, MAP_2_FALL_PLACE, CARRIED)

	assert_eq(host.current_space.area_id, MAP_2_ID, "Almos should be in map 2")
	assert_almost_eq(host.almos.global_position, checkpoint_at, Vector2(TOLERANCE, TOLERANCE))


func test_the_enemies_of_map_2_go_after_the_live_almos() -> void:
	var host := _spawn_world()

	await _go_to_map_2(host)

	assert_same(host.current_space.find_child("Sentry", true, false).target, host.almos)


func test_almos_put_at_a_place_in_a_room_of_the_building_is_in_that_room_with_the_camera_on_it() -> void:
	var building := (load(BUILDING_PATH) as PackedScene).instantiate() as Building
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	view.add_child(building)
	var room_b := building.get_node("RoomB") as Room

	building.put_almos_at(room_b.get_rect().get_center() + Vector2(50, 20))

	assert_eq(building.current_room, room_b)
	assert_almost_eq((building.find_child("Camera", true, false) as Camera2D).global_position, room_b.get_view_center(), Vector2(TOLERANCE, TOLERANCE))


# In seconds. A fade long enough to fall in the middle of.
const LONG_FADE_SECONDS := 0.3


func test_a_death_during_the_load_of_map_2_leaves_remains_in_map_1_where_he_fell() -> void:
	var host := _spawn_world(LONG_FADE_SECONDS)
	host.almos.experience.gain(CARRIED)
	host.almos.global_position = MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0)
	_almos_input.press_action(&"move_right")
	var frames := 0
	while not host.loading and frames < MOST_FRAMES:
		await wait_physics_frames(1)
		frames += 1
	_almos_input.release_action(&"move_right")
	assert_true(host.loading, "control: the load of map 2 should have started")
	var fall_place := host.almos.global_position

	host.almos.health.take_damage(host.almos.health.maximum)
	var tuning := load(PLAYER_TUNING_PATH) as PlayerTuning
	await wait_physics_frames(ceili((tuning.death_pause + 4.0 * LONG_FADE_SECONDS) * FRAMES_PER_SECOND) + MARGIN_FRAMES)

	assert_eq(host.current_space.area_id, MAP_1_ID, "control: Almos should be back in map 1")
	var remains := _remains_in(host)
	assert_eq(remains.size(), 1, "there should be Remains in map 1, where he fell")
	assert_eq(remains[0].amount, CARRIED)
	assert_almost_eq(remains[0].global_position, fall_place, Vector2(TOLERANCE, TOLERANCE))


func test_a_doorway_entered_in_the_frame_of_a_death_loads_nothing() -> void:
	var host := _spawn_world()
	host.almos.experience.gain(CARRIED)
	var doorway := host.current_space.doorway(&"ToMap2")
	doorway.used.connect(func(_used: Doorway) -> void:
		_almos_input.release_action(&"move_right")
		host.almos.health.take_damage(host.almos.health.maximum))
	host.almos.global_position = MAP_1_EAST_ENTRANCE - Vector2(FROM_DOORWAY, 0)
	_almos_input.press_action(&"move_right")
	var entered_ids: Array[StringName] = []
	host.space_entered.connect(func(space: Space) -> void: entered_ids.append(space.area_id))
	var tuning := load(PLAYER_TUNING_PATH) as PlayerTuning

	await wait_physics_frames(ceili(tuning.death_pause * FRAMES_PER_SECOND) + MOST_FRAMES)

	assert_eq(entered_ids[0], MAP_1_ID, "the first space loaded after the Death should be the one he is sent back to, not map 2")
	assert_eq(WorldState.remains()["area_id"], MAP_1_ID, "the Remains should be in map 1, where he fell")
