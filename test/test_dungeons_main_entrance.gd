extends GutTest
## The Main entrance in the Lobby is locked. A tap of Interact beside it while Almos has the Jailer's
## key opens it, and a tap without the key does nothing. Through it a Doorway leads to a placeholder
## Upper tree space, which has a Doorway back to the Lobby. The opening is not kept: whenever the
## Lobby is built the door stands shut, and with the key a tap opens it again, after a Death too.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const JAILERS_KEY_ID := &"dungeons/jailers_key"
const UPPER_TREE_ID := &"upper_tree_placeholder"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels, in the Lobby's own coordinates. Where Almos stands against the Main entrance, inside
# the Room: the door is a 16-pixel wall at y 640 and his body is 12 pixels in radius.
const AGAINST_THE_DOOR := Vector2(576.0, 619.0)
# In pixels, in the Lobby's own coordinates. Well away from the door, in the middle of the Room.
const FAR_FROM_THE_DOOR := Vector2(576.0, 440.0)
const CHECKPOINT_PATH := "res://scenes/world/checkpoint.tscn"
const TAP_FRAMES := 3
const TUNING_PATH := "res://data/player_tuning.tres"
# In pixels, in the Lobby's own coordinates. The top edge of the Main entrance: it is at y 640 and 16 thick.
const DOOR_TOP := 632.0
# In pixels. How much farther than door_reach from the door's edge Almos stands.
const BEYOND_REACH := 6.0
# In pixels. How far from a Checkpoint or a key Almos stands: well inside his reach.
const BESIDE := 5.0
# In pixels, in Radio/Officers's own coordinates. Where the key jailer is moved to before he is killed.
const PLACE_OF_DEATH := Vector2(300.0, 500.0)
# In physics frames. Long enough to walk through the door from where Almos stands against it, and
# to keep pushing against a shut one for a good while.
const WALK_FRAMES := 120
# In physics frames. The most a walk, a Death or a load is waited for.
const MOST_FRAMES := 600

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_the_main_entrance_is_shut_when_the_lobby_is_built() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_false(_door(host).open, "the door should be shut")


func test_a_tap_of_interact_beside_the_door_without_the_key_leaves_it_shut() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")

	assert_false(_door(host).open, "the door should still be shut")


func test_a_tap_of_interact_beside_the_door_with_the_key_opens_it() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	WorldState.record_kept(JAILERS_KEY_ID)

	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")

	assert_true(_door(host).open, "the door should be open")


func test_walking_into_the_shut_door_without_the_key_does_not_leave_the_dungeons() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _walk_down_for(WALK_FRAMES)

	assert_eq(WorldState.current_area, &"dungeons", "Almos should still be in the Dungeons")


func test_walking_into_the_door_after_a_tap_without_the_key_does_not_leave_the_dungeons() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")
	await _walk_down_for(WALK_FRAMES)

	assert_eq(WorldState.current_area, &"dungeons", "Almos should still be in the Dungeons")


func test_walking_through_the_open_door_reaches_the_upper_tree() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	WorldState.record_kept(JAILERS_KEY_ID)
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")

	await _walk_down_for(WALK_FRAMES)
	await _wait_for_the_load(host)

	assert_eq(WorldState.current_area, UPPER_TREE_ID, "Almos should be in the Upper tree placeholder")


func test_the_way_back_from_the_upper_tree_returns_almos_to_the_lobby() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _go_through_the_open_door(host)

	_almos_input.press_action(&"move_left")
	await wait_physics_frames(WALK_FRAMES)
	_almos_input.release_action(&"move_left")
	await _wait_for_the_load(host)

	assert_eq(WorldState.current_area, &"dungeons", "Almos should be in the Dungeons")
	var dungeons := host.current_space as DungeonsBuilding
	assert_not_null(dungeons, "the host's space should be the Dungeons")
	if dungeons != null:
		assert_eq(dungeons.current_room, dungeons.room(&"lobby"), "Almos should be in the Lobby")
		assert_true(dungeons.room(&"lobby").get_rect().has_point(host.almos.global_position), "Almos should stand inside the Lobby")


func test_the_door_stands_shut_again_when_almos_comes_back_through_the_way_back() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _go_through_the_open_door(host)

	_almos_input.press_action(&"move_left")
	await wait_physics_frames(WALK_FRAMES)
	_almos_input.release_action(&"move_left")
	await _wait_for_the_load(host)

	assert_false(_door(host).open, "the door should be shut")


func test_the_door_is_shut_again_after_a_death_and_a_tap_opens_it_again() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_key_from_the_key_jailer(host)
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")
	assert_true(_door(host).open, "control: the door is open")

	await _die_and_wait_for_the_return(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should still have the key")
	assert_false(_door(host).open, "the door should be shut")
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")
	assert_true(_door(host).open, "a tap should open it again")


func test_the_door_is_shut_again_after_a_rest_and_a_death_and_a_tap_opens_it_again() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_key_from_the_key_jailer(host)
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")
	assert_true(_door(host).open, "control: the door is open")
	var before_the_rest := host.current_space
	await _rest_at_the_lobby(host)
	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")

	await _die_and_wait_for_the_return(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should still have the key")
	assert_false(_door(host).open, "the door should be shut")
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")
	assert_true(_door(host).open, "a tap should open it again")


func test_the_key_jailer_stays_dead_after_a_death_with_the_door_open() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_key_from_the_key_jailer(host)
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")

	await _die_and_wait_for_the_return(host)

	assert_eq(_enemies_in((host.current_space as DungeonsBuilding).room(&"radio_officers")).size(), 0, "he should stay dead")


func test_a_checkpoint_in_reach_is_rested_at_before_the_door_is_opened() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	WorldState.record_kept(JAILERS_KEY_ID)
	var checkpoint := (load(CHECKPOINT_PATH) as PackedScene).instantiate() as Node2D
	checkpoint.position = AGAINST_THE_DOOR + Vector2(10.0, 0.0)
	_lobby(host).add_child(checkpoint)
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)

	await _tap(&"interact")

	assert_false(_door(host).open, "the tap should have rested, not opened the door")


func test_walking_into_the_shut_door_with_the_key_but_no_tap_does_not_leave_the_dungeons() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	WorldState.record_kept(JAILERS_KEY_ID)

	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _walk_down_for(WALK_FRAMES)

	assert_eq(WorldState.current_area, &"dungeons", "Almos should still be in the Dungeons")


func test_a_tap_of_interact_with_the_key_from_beyond_the_door_reach_leaves_it_shut() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	WorldState.record_kept(JAILERS_KEY_ID)
	var reach := (load(TUNING_PATH) as PlayerTuning).door_reach

	host.almos.global_position = _in_the_lobby(host, Vector2(576.0, DOOR_TOP - reach - BEYOND_REACH))
	await _tap(&"interact")

	assert_false(_door(host).open, "the door should still be shut")


func test_a_jailers_key_in_reach_is_taken_before_the_door_is_opened() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var room := (host.current_space as DungeonsBuilding).room(&"radio_officers")
	var jailer := _enemies_in(room)[0] as Node2D
	jailer.health.take_damage(jailer.health.maximum)
	await wait_physics_frames(TAP_FRAMES)
	var key := room.get_node("JailersKey") as Node2D
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	key.global_position = host.almos.global_position + Vector2(BESIDE, 0.0)
	WorldState.record_kept(JAILERS_KEY_ID)

	await _tap(&"interact")

	assert_false(_door(host).open, "the tap should have taken the key, not opened the door")


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func _lobby(host: AreaHost) -> Room:
	return (host.current_space as DungeonsBuilding).room(&"lobby")


func _door(host: AreaHost) -> MainEntrance:
	return _lobby(host).get_node("MainEntrance") as MainEntrance


# Where the place, given in the Lobby's own coordinates, is in the world.
func _in_the_lobby(host: AreaHost, place: Vector2) -> Vector2:
	return _lobby(host).global_position + place


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# With the Jailer's key, Almos opens the Main entrance and walks through it into the Upper tree.
func _go_through_the_open_door(host: AreaHost) -> void:
	WorldState.record_kept(JAILERS_KEY_ID)
	host.almos.global_position = _in_the_lobby(host, AGAINST_THE_DOOR)
	await _tap(&"interact")
	# He stops walking as soon as the load begins, so that he arrives at the Entrance and stays there.
	_almos_input.press_action(&"move_down")
	var frames := 0
	while not host.loading and frames < MOST_FRAMES:
		await get_tree().physics_frame
		frames += 1
	_almos_input.release_action(&"move_down")
	await _wait_for_the_load(host)
	assert_eq(WorldState.current_area, UPPER_TREE_ID, "control: Almos is in the Upper tree placeholder")


# Almos walks down, towards the Main entrance, for this many physics frames.
func _walk_down_for(frames: int) -> void:
	_almos_input.press_action(&"move_down")
	await wait_physics_frames(frames)
	_almos_input.release_action(&"move_down")


# Waits until the host is not loading a space.
func _wait_for_the_load(host: AreaHost) -> void:
	var frames := 0
	while (host.loading or frames < TAP_FRAMES) and frames < MOST_FRAMES:
		await get_tree().physics_frame
		frames += 1
	await wait_physics_frames(TAP_FRAMES)


# The enemies in the node's subtree that are not on their way out.
func _enemies_in(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if node.is_ancestor_of(enemy) and not enemy.is_queued_for_deletion():
			found.append(enemy)
	return found


# Almos kills the key jailer in Radio/Officers and takes the key he drops with a tap of Interact.
func _take_the_key_from_the_key_jailer(host: AreaHost) -> void:
	var room := (host.current_space as DungeonsBuilding).room(&"radio_officers")
	var jailer := _enemies_in(room)[0] as Node2D
	jailer.global_position = room.global_position + PLACE_OF_DEATH
	jailer.health.take_damage(jailer.health.maximum)
	await wait_physics_frames(TAP_FRAMES)
	host.almos.global_position = room.global_position + PLACE_OF_DEATH + Vector2(BESIDE, 0.0)
	await _tap(&"interact")
	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "control: Almos has the key")


# Almos stands beside the Lobby's Checkpoint and rests at it; this returns when the space is new.
func _rest_at_the_lobby(host: AreaHost) -> void:
	var checkpoint: Node2D
	for candidate in _lobby(host).find_children("*", "Node2D", true, false):
		if candidate.is_in_group(&"checkpoints"):
			checkpoint = candidate
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
