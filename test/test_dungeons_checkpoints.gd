extends GutTest
## The Dungeons hold only two Checkpoints: one in the Lobby, at the middle of the main hall, and one in
## Back corridor 1, just past the Back entrance. Reception has none. Until Almos rests at one, a Death
## returns him to Cell 3; resting at one saves the changes made so far and makes it his return point.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const SWORD_PATH := "res://data/sword.tres"
const ARMOUR_PATH := "res://data/almos_armour.tres"
const FIRE_PATH := "res://data/fire.tres"
const ROOTS_ID := &"dungeons/cell_3/roots"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. How far from a Checkpoint or a pickup Almos stands: well inside his reach.
const BESIDE := 5.0
# In pixels. How far from a Checkpoint he may be found when he has been returned to it.
const RETURN_TOLERANCE := 2.0
# In pixels. The walls are 16 pixels thick and Almos is about 30 across; a Checkpoint is clear of a wall
# when it is at least this far from the edge of the Room, and clear of an exit's strip likewise.
const CLEARANCE := 48.0
const TAP_FRAMES := 3
const MARGIN_FRAMES := 8
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


func test_the_dungeons_hold_exactly_two_checkpoints() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_checkpoints_in(host.current_space).size(), 2, "the Dungeons should hold two Checkpoints")


func test_the_lobby_holds_exactly_one_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_checkpoints_in(_room(host, &"lobby")).size(), 1, "the Lobby should hold one Checkpoint")


func test_back_corridor_1_holds_exactly_one_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_checkpoints_in(_room(host, &"back_corridor_1")).size(), 1, "Back corridor 1 should hold one Checkpoint")


func test_reception_holds_no_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	assert_eq(_checkpoints_in(_room(host, &"reception")).size(), 0, "Reception should hold no Checkpoint")


func test_the_lobbys_checkpoint_is_at_the_middle_of_the_room() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var lobby := _room(host, &"lobby")

	var checkpoint := _checkpoints_in(lobby)[0]

	assert_eq(checkpoint.global_position, lobby.get_rect().get_center(), "it should stand at the middle of the Lobby")


func test_back_corridor_1s_checkpoint_is_clear_of_the_walls_and_of_the_back_entrances_strip() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var corridor := _room(host, &"back_corridor_1")
	var back_entrance := corridor.get_node("Exits/back_entrance") as RoomExit

	var checkpoint := _checkpoints_in(corridor)[0]

	var inside := corridor.get_rect().grow(-CLEARANCE)
	assert_true(inside.has_point(checkpoint.global_position), "it should stand clear of the Room's edges")
	var strip := (back_entrance.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect()
	var strip_rect := Rect2(back_entrance.global_position + strip.position, strip.size).grow(CLEARANCE)
	assert_false(strip_rect.has_point(checkpoint.global_position), "it should stand clear of the Back entrance's strip")


func test_the_checkpoint_in_back_corridor_1_is_near_the_back_entrance() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var corridor := _room(host, &"back_corridor_1")
	var back_entrance := corridor.get_node("Exits/back_entrance") as RoomExit
	var checkpoint := _checkpoints_in(corridor)[0]

	var arrival := (back_entrance.get_node("Entrance") as Marker2D).global_position

	assert_lt(checkpoint.global_position.distance_to(arrival), CLEARANCE, "it should be within a step of where Almos arrives")


func test_a_death_before_a_rest_returns_almos_to_cell_3_with_the_roots_whole() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_cell_3s_roots(host)
	assert_true(_roots(host).open, "control: the roots burnt open")

	await _die_and_wait_for_the_return(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"cell_3"), "he should be back in Cell 3")
	assert_false(_roots(host).open, "the roots should be whole")


func test_a_death_after_a_rest_at_the_lobbys_checkpoint_returns_almos_to_it_with_the_roots_open() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_cell_3s_roots(host)
	await _rest_at(host, &"lobby")

	await _die_and_wait_for_the_return(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"lobby"), "he should be back in the Lobby")
	var checkpoint := _checkpoints_in(dungeons.room(&"lobby"))[0]
	assert_lt(host.almos.global_position.distance_to(checkpoint.global_position), RETURN_TOLERANCE, "he should stand at the Checkpoint")
	assert_true(_roots(host).open, "the roots should be open")
	assert_true(WorldState.is_burnt(ROOTS_ID), "the roots should be remembered as burnt")


func test_a_death_after_a_rest_at_back_corridor_1s_checkpoint_returns_almos_to_it() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _rest_at(host, &"back_corridor_1")

	await _die_and_wait_for_the_return(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"back_corridor_1"), "he should be back in Back corridor 1")
	var checkpoint := _checkpoints_in(dungeons.room(&"back_corridor_1"))[0]
	assert_lt(host.almos.global_position.distance_to(checkpoint.global_position), RETURN_TOLERANCE, "he should stand at the Checkpoint")
	assert_false(host.almos.dead, "he should be alive again")


func test_almos_keeps_the_sword_and_the_armour_from_the_store_room_when_he_dies_after_resting_at_the_lobbys_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _take_the_gear(host)
	await _rest_at(host, &"lobby")

	await _die_and_wait_for_the_return(host)

	assert_eq(host.almos.weapons.in_hand, load(SWORD_PATH), "the Sword in his hand")
	assert_eq(host.almos.armour, load(ARMOUR_PATH), "the Armour he wears")
	var store := _room(host, &"store_room")
	assert_eq(_live_pickups(store, &"weapon_pickups").size(), 0, "the Sword does not lie there")
	assert_eq(_live_pickups(store, &"armour_pickups").size(), 0, "the Armour does not lie there")


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


func _roots(host: AreaHost) -> PathBlocker:
	return _room(host, &"cell_3").get_node("Roots") as PathBlocker


# The Checkpoints in the node's subtree.
func _checkpoints_in(node: Node) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for candidate in node.find_children("*", "Node2D", true, false):
		if candidate.is_in_group(&"checkpoints"):
			found.append(candidate)
	return found


func _live_pickups(room: Room, group: StringName) -> Array[Node]:
	return room.find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.is_in_group(group) and not node.is_queued_for_deletion())


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


# Cell 3's roots are set alight and burn out, which is what Pull and Shove at them comes to.
func _burn_cell_3s_roots(host: AreaHost) -> void:
	_roots(host).flammable.ignite()
	var burn_seconds := (load(FIRE_PATH) as FireTuning).burn_time
	await wait_physics_frames(ceili(burn_seconds * Engine.physics_ticks_per_second) + MARGIN_FRAMES)


# Almos takes the Sword and then the Armour in the store room, each with a tap of Interact.
func _take_the_gear(host: AreaHost) -> void:
	for group: StringName in [&"weapon_pickups", &"armour_pickups"]:
		var pickup := _live_pickups(_room(host, &"store_room"), group)[0] as Node2D
		host.almos.global_position = pickup.global_position + Vector2(BESIDE, 0.0)
		await _tap(&"interact")


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
