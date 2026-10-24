extends GutTest
## The key jailer in Radio/Officers drops the Jailer's key where he falls, and Almos takes it with a
## tap of Interact. Until he dies there is no key to take. Once taken Almos has it for good, through
## a Death and through a rest, and the key does not lie there again; if he died and Almos was sent
## back before taking it, it lies at the jailer's post, to be taken.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const JAILERS_KEY_ID := &"dungeons/jailers_key"
const KEY_JAILER_ID := &"dungeons/radio_officers/key_jailer"
const CHECKPOINT_PATH := "res://scenes/world/checkpoint.tscn"
const HIDING_SPOT_PATH := "res://scenes/world/hiding_spot.tscn"
const SWORD_PATH := "res://data/sword.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a Checkpoint or a pickup Almos stands: well inside his reach.
const BESIDE := 5.0
# In pixels, in the Room's own coordinates. Where a key that lies at its own spot lies, which is the
# key jailer's post.
const POST := Vector2(576.0, 320.0)
# In pixels, in the Room's own coordinates. Where the key jailer is moved to before he is killed,
# well away from his post.
const PLACE_OF_DEATH := Vector2(300.0, 500.0)
# In pixels. How near the place of death the key must lie, allowing for a frame's drift.
const NEAR := 2.0
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


func test_no_key_can_be_taken_while_the_key_jailer_lives() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	host.almos.global_position = _key_jailer(host).global_position + Vector2(BESIDE, 0.0)
	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "Almos should not have the key")


func test_the_key_lies_where_the_key_jailer_fell() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)

	var keys := _keys_in(_room(host, &"radio_officers"))
	assert_eq(keys.size(), 1, "one key should lie in Radio/Officers")
	if keys.size() == 1:
		assert_lt(keys[0].global_position.distance_to(_at(host, PLACE_OF_DEATH)), NEAR, "it should lie where he fell")


func test_a_tap_of_interact_beside_the_key_gives_almos_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)

	await _take_the_key(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should have the key")


func test_the_key_is_gone_from_the_floor_once_taken() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)

	await _take_the_key(host)

	assert_eq(_keys_in(_room(host, &"radio_officers")).size(), 0, "no key should lie there")


func test_a_tap_of_interact_far_from_the_key_does_not_take_it() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)

	host.almos.global_position = _at(host, PLACE_OF_DEATH + Vector2(0.0, -200.0))
	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "Almos should not have the key")


func test_almos_keeps_the_key_through_a_death_before_any_rest() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	await _take_the_key(host)

	await _die_and_wait_for_the_return(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should still have the key")


func test_the_key_jailer_stays_dead_and_no_key_lies_after_a_death_with_the_key_taken() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	await _take_the_key(host)

	await _die_and_wait_for_the_return(host)

	var room := _room(host, &"radio_officers")
	assert_eq(_enemies_in(room).size(), 0, "he should stay dead")
	assert_eq(_keys_in(room).size(), 0, "no key should lie there")


func test_almos_keeps_the_key_through_a_rest_and_then_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	await _take_the_key(host)
	var before_the_rest := host.current_space
	await _rest_at_the_lobby(host)
	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")

	await _die_and_wait_for_the_return(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should still have the key")
	assert_eq(_keys_in(_room(host, &"radio_officers")).size(), 0, "no key should lie there")


func test_a_key_not_taken_before_a_death_lies_at_the_key_jailers_post_afterwards() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)

	await _die_and_wait_for_the_return(host)

	var room := _room(host, &"radio_officers")
	assert_eq(_enemies_in(room).size(), 0, "he should stay dead")
	var keys := _keys_in(room)
	assert_eq(keys.size(), 1, "the key should lie in Radio/Officers")
	if keys.size() == 1:
		assert_lt(keys[0].global_position.distance_to(_at(host, POST)), NEAR, "it should lie at his post")


func test_a_key_left_at_the_post_after_a_death_can_be_taken() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	await _die_and_wait_for_the_return(host)

	await _take_the_key(host)

	assert_true(WorldState.is_taken(JAILERS_KEY_ID), "Almos should have the key")


func test_a_weapon_in_reach_is_taken_before_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	var pickup := (load("res://scenes/world/weapon_pickup.tscn") as PackedScene).instantiate() as WeaponPickup
	pickup.weapon = load(SWORD_PATH)
	pickup.position = PLACE_OF_DEATH + Vector2(10.0, 0.0)
	_room(host, &"radio_officers").add_child(pickup)
	host.almos.global_position = _at(host, PLACE_OF_DEATH + Vector2(BESIDE, 0.0))

	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "the tap should not have taken the key")
	assert_false(is_instance_valid(pickup), "the tap should have taken the Weapon")


func test_a_checkpoint_in_reach_rests_and_leaves_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	_put_in_the_room(host, CHECKPOINT_PATH, PLACE_OF_DEATH + Vector2(10.0, 0.0))
	host.almos.global_position = _at(host, PLACE_OF_DEATH + Vector2(BESIDE, 0.0))

	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "the tap should not have taken the key")


func test_a_hiding_spot_in_reach_hides_and_leaves_the_key() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	_put_in_the_room(host, HIDING_SPOT_PATH, PLACE_OF_DEATH + Vector2(10.0, 0.0))
	host.almos.global_position = _at(host, PLACE_OF_DEATH + Vector2(BESIDE, 0.0))

	await _tap(&"interact")

	assert_false(WorldState.is_taken(JAILERS_KEY_ID), "the tap should not have taken the key")


func test_a_key_not_taken_before_a_rest_lies_at_the_key_jailers_post_afterwards() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer_at(host, PLACE_OF_DEATH)
	var before_the_rest := host.current_space
	await _rest_at_the_lobby(host)

	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")
	var room := _room(host, &"radio_officers")
	assert_eq(_enemies_in(room).size(), 0, "he should stay dead")
	var keys := _keys_in(room)
	assert_eq(keys.size(), 1, "the key should lie in Radio/Officers")
	if keys.size() == 1:
		assert_lt(keys[0].global_position.distance_to(_at(host, POST)), NEAR, "it should lie at his post")


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


# The keys in the node's subtree that are not on their way out and that Almos could take.
func _keys_in(node: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for key in get_tree().get_nodes_in_group(&"key_pickups"):
		if node.is_ancestor_of(key) and not key.is_queued_for_deletion() and key.visible:
			found.append(key)
	return found


# Where the place, given in Radio/Officers's own coordinates, is in the world.
func _at(host: AreaHost, place: Vector2) -> Vector2:
	return _room(host, &"radio_officers").global_position + place


func _key_jailer(host: AreaHost) -> Node2D:
	return _enemies_in(_room(host, &"radio_officers"))[0] as Node2D


# He is moved to the place and his Health is taken to zero; the test waits until he is gone.
func _kill_the_key_jailer_at(host: AreaHost, place: Vector2) -> void:
	var jailer := _key_jailer(host)
	jailer.global_position = _at(host, place)
	jailer.health.take_damage(jailer.health.maximum)
	await wait_physics_frames(TAP_FRAMES)
	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "control: he is dead")


# Almos stands beside the key that lies in Radio/Officers and taps Interact.
func _take_the_key(host: AreaHost) -> void:
	var key := _keys_in(_room(host, &"radio_officers"))[0]
	host.almos.global_position = key.global_position + Vector2(BESIDE, 0.0)
	await _tap(&"interact")


# A scene is put in Radio/Officers at the place, given in the Room's own coordinates.
func _put_in_the_room(host: AreaHost, path: String, place: Vector2) -> void:
	var node := (load(path) as PackedScene).instantiate() as Node2D
	node.position = place
	_room(host, &"radio_officers").add_child(node)


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
