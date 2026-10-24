extends GutTest
## A stronger, named Nar jailer stands at a post in Radio/Officers, the Room nearest the Main entrance.
## He stays at his post rather than patrolling, and once killed he stays dead: through a Death and
## through a rest at a Checkpoint. No other Room of the Dungeons holds an enemy.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const KEY_JAILER_ID := &"dungeons/radio_officers/key_jailer"
const KEY_JAILER_TUNING_PATH := "res://data/nar_key_jailer.tres"
const NAR_JAILER_TUNING_PATH := "res://data/nar_jailer.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a Checkpoint Almos stands: well inside his reach.
const BESIDE := 5.0
# In pixels. The walls are 16 pixels thick and a jailer is about 30 across; he stands clear of a wall
# when he is at least this far from the edge of the Room, and clear of the door's strip likewise.
const CLEARANCE_FROM_WALLS := 48.0
# The least a unit vector's dot product with the direction to the door may be for it to face the door.
const FACING_THE_DOOR := 0.9
# In physics frames. How long the jailer is watched at his post with Almos elsewhere.
const WATCH_FRAMES := 120
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


func test_radio_officers_holds_exactly_one_enemy() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 1, "Radio/Officers should hold one enemy")


func test_no_other_room_of_the_dungeons_holds_an_enemy() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var elsewhere := _enemies_in(host.current_space).filter(func(enemy: Node) -> bool: return not _room(host, &"radio_officers").is_ancestor_of(enemy))
	assert_eq(elsewhere.size(), 0, "no enemy should stand outside Radio/Officers")


func test_the_enemy_in_radio_officers_is_named_with_the_key_jailers_id() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var jailer := _key_jailer(host)

	assert_true(jailer.named, "he should be a named enemy")
	assert_eq(jailer.id, KEY_JAILER_ID, "he should have the key jailer's id")


func test_the_key_jailer_uses_the_key_jailer_tuning() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_key_jailer(host).tuning, load(KEY_JAILER_TUNING_PATH), "he should be tuned by the key jailer's data")


func test_the_key_jailer_has_more_health_than_a_nar_jailer() -> void:
	var key_jailer := load(KEY_JAILER_TUNING_PATH) as EnemyTuning
	var nar_jailer := load(NAR_JAILER_TUNING_PATH) as EnemyTuning

	assert_gt(key_jailer.health_maximum, nar_jailer.health_maximum, "he should take more to kill")


func test_the_key_jailer_hits_harder_than_a_nar_jailer_with_each_kind_of_attack() -> void:
	var key_jailer := load(KEY_JAILER_TUNING_PATH) as EnemyTuning
	var nar_jailer := load(NAR_JAILER_TUNING_PATH) as EnemyTuning

	assert_gt(key_jailer.attack.damage, nar_jailer.attack.damage, "his strike")
	assert_gt(key_jailer.low_attack.damage, nar_jailer.low_attack.damage, "his low attack")
	assert_gt(key_jailer.unblockable_attack.damage, nar_jailer.unblockable_attack.damage, "his unblockable attack")
	assert_eq(key_jailer.combo.size(), nar_jailer.combo.size(), "control: the same swings in his combo")
	for swing in key_jailer.combo.size():
		assert_gt(key_jailer.combo[swing].damage, nar_jailer.combo[swing].damage, "swing %d of his combo" % (swing + 1))


func test_the_key_jailer_is_harder_to_stagger_than_a_nar_jailer() -> void:
	var key_jailer := load(KEY_JAILER_TUNING_PATH) as EnemyTuning
	var nar_jailer := load(NAR_JAILER_TUNING_PATH) as EnemyTuning

	assert_gt(key_jailer.stagger_capacity, nar_jailer.stagger_capacity, "it should take more Stagger to Break him")


func test_the_key_jailer_stands_clear_of_the_walls_and_the_doors_strip() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var room := _room(host, &"radio_officers")
	var door := room.get_node("Exits/door") as RoomExit

	var jailer := _key_jailer(host)

	assert_true(room.get_rect().grow(-CLEARANCE_FROM_WALLS).has_point(jailer.global_position), "he should stand clear of the Room's edges")
	var strip := (door.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect()
	var strip_rect := Rect2(door.global_position + strip.position, strip.size).grow(CLEARANCE_FROM_WALLS)
	assert_false(strip_rect.has_point(jailer.global_position), "he should stand clear of the door's strip")


func test_the_key_jailer_faces_the_door_at_his_post() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var door := _room(host, &"radio_officers").get_node("Exits/door") as RoomExit
	var jailer := _key_jailer(host)

	var to_door := (door.global_position - jailer.global_position).normalized()

	assert_gt(jailer.facing.dot(to_door), FACING_THE_DOOR, "he should face the door")


func test_the_key_jailer_stays_at_his_post_when_almos_is_elsewhere() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var jailer := _key_jailer(host)
	var post := jailer.global_position

	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(jailer.global_position, post, "he should not have moved")
	assert_false(jailer.in_pursuit, "he should not be after anyone")


func test_a_killed_key_jailer_is_not_in_radio_officers_after_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer(host)

	await _die_and_wait_for_the_return(host)

	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "he should stay dead")


func test_a_killed_key_jailer_is_not_in_radio_officers_after_a_rest_at_the_lobbys_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer(host)

	var before_the_rest := host.current_space
	await _rest_at(host, &"lobby")

	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")
	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "he should stay dead")


func test_a_killed_key_jailer_is_not_in_radio_officers_after_a_rest_and_then_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_key_jailer(host)
	var before_the_rest := host.current_space
	await _rest_at(host, &"lobby")
	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")

	await _die_and_wait_for_the_return(host)

	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "he should stay dead")


func test_a_key_jailer_who_was_not_killed_is_still_in_radio_officers_after_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _die_and_wait_for_the_return(host)

	var enemies := _enemies_in(_room(host, &"radio_officers"))
	assert_eq(enemies.size(), 1, "he should still be there")
	if enemies.size() == 1:
		assert_eq(enemies[0].id, KEY_JAILER_ID, "and he should be the key jailer")


func test_a_key_jailer_who_was_not_killed_is_still_in_radio_officers_after_a_rest() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var before_the_rest := host.current_space
	await _rest_at(host, &"lobby")

	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")
	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 1, "he should still be there")


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


# The one enemy in Radio/Officers, which the other tests have counted.
func _key_jailer(host: AreaHost) -> Node2D:
	return _enemies_in(_room(host, &"radio_officers"))[0] as Node2D


# His Health is taken to zero, and the test waits until he is gone.
func _kill_the_key_jailer(host: AreaHost) -> void:
	var jailer := _key_jailer(host)
	jailer.health.take_damage(jailer.health.maximum)
	await wait_physics_frames(TAP_FRAMES)
	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "control: he is dead")


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# Almos stands beside the Checkpoint in the Room and rests at it with a tap of Interact; this returns
# when the space has been made new.
func _rest_at(host: AreaHost, room_id: StringName) -> void:
	var checkpoint: Node2D
	for candidate in _room(host, room_id).find_children("*", "Node2D", true, false):
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
