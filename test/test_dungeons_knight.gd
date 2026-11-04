extends GutTest
## A stronger, named Nar knight sits asleep at his desk in Radio/Officers, the Room nearest the Main
## entrance. He stays at his post rather than patrolling, and once killed he stays dead: through a
## Death and through a rest at a Checkpoint. Asleep, he notices Almos by Sight as the seated guard in
## Corridor 1 does; he faces his desk. Apart from the ordinary guards patrolling Corridor 1 (see
## test_corridor_1_stealth.gd), no other Room of the Dungeons holds an enemy.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const KNIGHT_ID := &"dungeons/radio_officers/knight"
const KNIGHT_TUNING_PATH := "res://data/nar_knight.tres"
const KNIGHT_PATH := "res://scenes/enemies/nar_knight.tscn"
const NAR_JAILER_TUNING_PATH := "res://data/nar_jailer.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a Checkpoint Almos stands: well inside his reach.
const BESIDE := 5.0
# In pixels. The walls are 16 pixels thick and a knight is about 30 across; he stands clear of a wall
# when he is at least this far from the edge of the Room, and clear of the door's strip likewise.
const CLEARANCE_FROM_WALLS := 48.0
# The least a unit vector's dot product with east may be for it to face his desk.
const FACING_THE_DESK := 0.9
# In physics frames. How long the knight is watched at his post with Almos elsewhere.
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


func test_no_other_room_of_the_dungeons_holds_an_enemy_but_corridor_1s_patrols() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var radio_officers := _room(host, &"radio_officers")
	var corridor_1 := _room(host, &"corridor_1")
	var elsewhere := _enemies_in(host.current_space).filter(func(enemy: Node) -> bool:
		return not radio_officers.is_ancestor_of(enemy) and not corridor_1.is_ancestor_of(enemy))
	assert_eq(elsewhere.size(), 0, "no enemy should stand outside Radio/Officers and Corridor 1")
	for enemy in _enemies_in(corridor_1):
		assert_false(enemy.named, "Corridor 1's guards are ordinary")
	var walking := _enemies_in(corridor_1).filter(func(enemy: Node) -> bool: return enemy.patrol.size() > 0)
	assert_gt(walking.size(), 0, "a guard of Corridor 1 patrols")


func test_the_enemy_in_radio_officers_is_named_with_the_knights_id() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var knight := _knight(host)

	assert_true(knight.named, "he should be a named enemy")
	assert_eq(knight.id, KNIGHT_ID, "he should have the knight's id")


func test_the_knight_uses_the_knight_tuning() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_knight(host).tuning, load(KNIGHT_TUNING_PATH), "he should be tuned by the knight's data")


func test_the_knight_has_more_health_than_a_nar_jailer() -> void:
	var knight := load(KNIGHT_TUNING_PATH) as EnemyTuning
	var nar_jailer := load(NAR_JAILER_TUNING_PATH) as EnemyTuning

	assert_gt(knight.health_maximum, nar_jailer.health_maximum, "he should take more to kill")


func test_the_knight_hits_harder_than_a_nar_jailer_with_each_kind_of_attack() -> void:
	var knight := load(KNIGHT_TUNING_PATH) as EnemyTuning
	var nar_jailer := load(NAR_JAILER_TUNING_PATH) as EnemyTuning

	assert_gt(knight.attack.damage, nar_jailer.attack.damage, "his strike")
	assert_gt(knight.low_attack.damage, nar_jailer.low_attack.damage, "his low attack")
	assert_gt(knight.unblockable_attack.damage, nar_jailer.unblockable_attack.damage, "his unblockable attack")
	assert_eq(knight.combo.size(), nar_jailer.combo.size(), "control: the same swings in his combo")
	for swing in knight.combo.size():
		assert_gt(knight.combo[swing].damage, nar_jailer.combo[swing].damage, "swing %d of his combo" % (swing + 1))


func test_the_knight_is_harder_to_stagger_than_a_nar_jailer() -> void:
	var knight := load(KNIGHT_TUNING_PATH) as EnemyTuning
	var nar_jailer := load(NAR_JAILER_TUNING_PATH) as EnemyTuning

	assert_gt(knight.stagger_capacity, nar_jailer.stagger_capacity, "it should take more Stagger to Break him")


func test_the_knight_stands_clear_of_the_walls_and_the_doors_strip() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var room := _room(host, &"radio_officers")
	var door := room.get_node("Exits/door") as RoomExit

	var knight := _knight(host)

	assert_true(room.get_rect().grow(-CLEARANCE_FROM_WALLS).has_point(knight.global_position), "he should stand clear of the Room's edges")
	var strip := (door.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect()
	var strip_rect := Rect2(door.global_position + strip.position, strip.size).grow(CLEARANCE_FROM_WALLS)
	assert_false(strip_rect.has_point(knight.global_position), "he should stand clear of the door's strip")


func test_the_knight_faces_his_desk_against_the_east_wall_at_his_post() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var desk := _room(host, &"radio_officers").get_node("Desk") as Node2D
	var knight := _knight(host)

	assert_gt(desk.global_position.x, knight.global_position.x, "his desk should stand east of him")
	assert_gt(knight.facing.dot(Vector2.RIGHT), FACING_THE_DESK, "he should face it, east")


func test_the_knight_is_a_nar_knight_seated_and_asleep() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var knight := _knight(host)

	assert_eq(knight.scene_file_path, KNIGHT_PATH, "he should be a Nar knight")
	assert_true(knight.seated, "he should be seated")
	assert_true(knight.asleep, "he should be asleep")
	assert_true(knight.sleeping(), "he should be sleeping at his post")


func test_the_knight_wakes_and_is_after_almos_once_a_shove_moves_him() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var knight := _knight(host)
	host.almos.global_position = knight.global_position + Vector2(-60.0, 40.0)

	knight.slide(Vector2.LEFT, 4.0, 200.0)
	await wait_physics_frames(4)

	assert_true(knight.in_pursuit, "he should be after Almos")
	assert_false(knight.sleeping(), "he should be awake")


func test_the_knight_sees_almos_in_front_of_him_and_wakes() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var knight := _knight(host)

	host.almos.global_position = knight.global_position + Vector2(26.0, 22.0)
	await wait_physics_frames(10)

	assert_true(knight.in_pursuit, "he should have seen Almos")
	assert_false(knight.sleeping(), "he should be awake")


func test_the_knight_sleeps_on_with_almos_behind_him() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var knight := _knight(host)

	host.almos.global_position = knight.global_position + Vector2(-60.0, 40.0)
	await wait_physics_frames(WATCH_FRAMES)

	assert_false(knight.in_pursuit, "he should not have noticed Almos")
	assert_true(knight.sleeping(), "he should sleep on")


func test_the_knight_stays_at_his_post_when_almos_is_elsewhere() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var knight := _knight(host)
	var post := knight.global_position

	await wait_physics_frames(WATCH_FRAMES)

	assert_eq(knight.global_position, post, "he should not have moved")
	assert_false(knight.in_pursuit, "he should not be after anyone")


func test_a_killed_knight_is_not_in_radio_officers_after_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_knight(host)

	await _die_and_wait_for_the_return(host)

	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "he should stay dead")


func test_a_killed_knight_is_not_in_radio_officers_after_a_rest_at_the_lobbys_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_knight(host)

	var before_the_rest := host.current_space
	await _rest_at(host, &"lobby")

	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")
	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "he should stay dead")


func test_a_killed_knight_is_not_in_radio_officers_after_a_rest_and_then_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _kill_the_knight(host)
	var before_the_rest := host.current_space
	await _rest_at(host, &"lobby")
	assert_ne(host.current_space, before_the_rest, "control: the rest rebuilt the space")

	await _die_and_wait_for_the_return(host)

	assert_eq(_enemies_in(_room(host, &"radio_officers")).size(), 0, "he should stay dead")


func test_a_knight_who_was_not_killed_is_still_in_radio_officers_after_a_death() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	await _die_and_wait_for_the_return(host)

	var enemies := _enemies_in(_room(host, &"radio_officers"))
	assert_eq(enemies.size(), 1, "he should still be there")
	if enemies.size() == 1:
		assert_eq(enemies[0].id, KNIGHT_ID, "and he should be the knight")


func test_a_knight_who_was_not_killed_is_still_in_radio_officers_after_a_rest() -> void:
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
func _knight(host: AreaHost) -> Node2D:
	return _enemies_in(_room(host, &"radio_officers"))[0] as Node2D


# His Health is taken to zero, and the test waits until he is gone.
func _kill_the_knight(host: AreaHost) -> void:
	var knight := _knight(host)
	knight.health.take_damage(knight.health.maximum)
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
