extends GutTest
## The Jailer's key is kept in a crate in Radio/Officers, not carried by the knight there. Almos takes
## it by standing beside the crate and tapping Interact, with the knight alive and asleep at his desk.
## Once taken Almos has it for good, through a Death and through a rest, and the crate stands open
## and empty. Killing the knight leaves no key where he falls.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const JAILERS_KEY_ID := &"dungeons/jailers_key"
const CHECKPOINT_PATH := "res://scenes/world/checkpoint.tscn"
const HIDING_SPOT_PATH := "res://scenes/world/hiding_spot.tscn"
const SWORD_PATH := "res://data/sword.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a Checkpoint or a pickup Almos stands: well inside his reach.
const BESIDE := 5.0
# In pixels. Beside the crate, to its east: half its width and his body's radius, and a pixel.
const BESIDE_THE_CRATE := Vector2(27.0, 0.0)
# In pixels, in the Room's own coordinates. Where the knight is moved to before he is killed.
const PLACE_OF_DEATH := Vector2(560.0, 330.0)
const TAP_FRAMES := 3
# In physics frames. The most a Death and the return after it is waited for.
const MOST_FRAMES := 600

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_the_key_is_in_the_crate_in_radio_officers() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var keys := _keys_in(_room(host, &"radio_officers"))
	assert_eq(keys.size(), 1, "one key should be in Radio/Officers")
	if keys.size() == 1:
		assert_true(_crate(host).is_ancestor_of(keys[0]), "it should be in the crate")
	assert_false(_crate(host).is_open(), "the crate should be shut")


func test_the_knight_carries_no_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	for key in _keys_in(_room(host, &"radio_officers")):
		assert_false(_knight(host).is_ancestor_of(key), "the knight should not carry it")


func test_a_tap_of_interact_beside_the_crate_takes_the_key_while_the_knight_sleeps() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _take_the_key(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should have the key")
	assert_true(_knight(host).sleeping(), "control: the knight sleeps on")


func test_the_crate_stands_open_and_empty_once_the_key_is_taken() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _take_the_key(host)

	assert_eq(_keys_in(_room(host, &"radio_officers")).size(), 0, "no key should be left")
	assert_true(_crate(host).is_open(), "the crate should stand open")


func test_a_tap_of_interact_far_from_the_crate_does_not_take_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	host.almos.global_position = _crate(host).global_position + Vector2(120.0, -120.0)
	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "Almos should not have the key")


func test_killing_the_knight_leaves_no_key_where_he_falls() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _kill_the_knight_at(host, PLACE_OF_DEATH)

	var keys := _keys_in(_room(host, &"radio_officers"))
	assert_eq(keys.size(), 1, "still only the key in the crate")
	if keys.size() == 1:
		assert_true(_crate(host).is_ancestor_of(keys[0]), "it should still be in the crate")


func test_the_key_can_be_taken_once_the_knight_is_dead_too() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_knight_at(host, PLACE_OF_DEATH)

	await _take_the_key(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should have the key")


func test_almos_keeps_the_key_through_a_death_before_any_rest() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_key(host)

	await _die_and_wait_for_the_return(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should still have the key")
	assert_eq(_keys_in(_room(host, &"radio_officers")).size(), 0, "no key should be in the crate")
	assert_true(_crate(host).is_open(), "the crate should stand open")


func test_almos_keeps_the_key_through_a_rest_and_then_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_key(host)
	var before_the_rest := host.current_space
	await _rest_at_the_lobby(host)
	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")

	await _die_and_wait_for_the_return(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should still have the key")
	assert_eq(_keys_in(_room(host, &"radio_officers")).size(), 0, "no key should be in the crate")


func test_a_key_not_taken_is_still_in_the_crate_after_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _die_and_wait_for_the_return(host)

	assert_eq(_keys_in(_room(host, &"radio_officers")).size(), 1, "the key should be in the crate")
	await _take_the_key(host)
	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should have the key")


func test_a_weapon_in_reach_is_taken_before_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var pickup := (load("res://scenes/world/weapon_pickup.tscn") as PackedScene).instantiate() as WeaponPickup
	pickup.weapon = load(SWORD_PATH)
	_room(host, &"radio_officers").add_child(pickup)
	pickup.global_position = _crate(host).global_position + BESIDE_THE_CRATE + Vector2(BESIDE, 0.0)
	host.almos.global_position = _crate(host).global_position + BESIDE_THE_CRATE

	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "the tap should not have taken the key")
	assert_false(is_instance_valid(pickup), "the tap should have taken the Weapon")


func test_a_checkpoint_in_reach_rests_and_leaves_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	_put_beside_the_crate(host, CHECKPOINT_PATH)
	host.almos.global_position = _crate(host).global_position + BESIDE_THE_CRATE

	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "the tap should not have taken the key")


func test_a_hiding_spot_in_reach_hides_and_leaves_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	_put_beside_the_crate(host, HIDING_SPOT_PATH)
	host.almos.global_position = _crate(host).global_position + BESIDE_THE_CRATE

	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "the tap should not have taken the key")


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


# The enemies in the node's subtree that are not on their way out.
func _enemies_in(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if node.is_ancestor_of(enemy) and not enemy.is_queued_for_deletion():
			found.append(enemy)
	return found


# The keys in the node's subtree that are not on their way out.
func _keys_in(node: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for key in get_tree().get_nodes_in_group(&"key_pickups"):
		if node.is_ancestor_of(key) and not key.is_queued_for_deletion() and key.visible:
			found.append(key)
	return found


# Where the place, given in Radio/Officers's own coordinates, is in the world.
func _at(host: AreaHost, place: Vector2) -> Vector2:
	return _room(host, &"radio_officers").global_position + place


func _knight(host: AreaHost) -> Node2D:
	return _enemies_in(_room(host, &"radio_officers"))[0] as Node2D


func _crate(host: AreaHost) -> KeyCrate:
	return _room(host, &"radio_officers").get_node("KeyCrate") as KeyCrate


# He is moved to the place and his Health is taken to zero; the test waits until he is gone.
func _kill_the_knight_at(host: AreaHost, place: Vector2) -> void:
	var knight := _knight(host)
	knight.global_position = _at(host, place)
	knight.health.take_damage(knight.health.maximum)
	await wait_physics_frames(TAP_FRAMES)
	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "control: he is dead")


# Almos stands beside the crate in Radio/Officers and taps Interact.
func _take_the_key(host: AreaHost) -> void:
	host.almos.global_position = _crate(host).global_position + BESIDE_THE_CRATE
	await _tap(&"interact")


# A scene is put in Radio/Officers just east of where Almos stands beside the crate.
func _put_beside_the_crate(host: AreaHost, path: String) -> void:
	var node := (load(path) as PackedScene).instantiate() as Node2D
	_room(host, &"radio_officers").add_child(node)
	node.global_position = _crate(host).global_position + BESIDE_THE_CRATE + Vector2(10.0, 0.0)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# Almos stands beside the Lobby's Checkpoint and rests at it; this returns when the space is new.
func _rest_at_the_lobby(host: AreaHost) -> void:
	var checkpoint: Node2D
	for candidate in _room(host, &"lobby").find_children("*", "Node2D", true, false):
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
