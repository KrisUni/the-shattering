extends GutTest
## A pursuing enemy following Almos through a Room's exit, tested through the placeholder building
## of three Rooms: A, whose east edge leads to B's west edge. The enemy is the training enemy the
## scene places in Room A. The Rooms' places, the exits' layout and the delay (set by the test, as
## the data file's is only a first value) are data, and the numbers here are those of their design.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const BUILDING_PATH := "res://scenes/areas/test_building.tscn"
# In pixels. The size of the view the building is shown in: the project's default window. The test
# sets it, since a headless run has a window of its own, much smaller.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels. Where Almos is put on arriving, as the scene lays out the exits: 56 inside the Room
# from the edge exit he came through, which is 16 thick.
const A_EAST_ENTRANCE := Vector2(1152 - 8 - 56, 324)
const B_WEST_ENTRANCE := Vector2(1252 + 8 + 56, 324)
# In pixels. The middle of A's east exit, which a pursuer goes to before it follows through it.
const A_EAST_EXIT := Vector2(1152 - 8, 324)
# In pixels. How far from the exit Almos is put before walking out, and how far behind him the
# pursuer starts: close enough to have him in its Sight, far enough not to reach him.
const FROM_EXIT := 100.0
const PURSUER_BEHIND := 120.0
# In pixels. "Within a pixel or two", for the places the pursuer is put at, and for standing on the
# middle of the exit, which it walks to exactly.
const TOLERANCE := 2.0
const ON_THE_EXIT := 0.01
# In seconds, and the physics frames they come to at the fixed 60 frames a second the tests run at.
const DELAY_SECONDS := 0.5
const DELAY_FRAMES := 30
# In physics frames. How far either side of the delay a crossing may fall: the building notices the enemy
# on the exit a frame after it got there, and the sample shows it a frame after it is put in the next Room.
const SLACK_FRAMES := 3
# In physics frames. Long enough for a pursuer to walk to the exit, wait the delay and come out.
const TRIP_FRAMES := 400
# In Health points: what the pursuer is hurt by before the trip, so that its Health is not the default,
# and what it has left of the training enemy's 120. In Stagger points: what it is given, of its 100.
const DAMAGE_BEFORE := 30.0
const HEALTH_AFTER_DAMAGE := 90.0
const STAGGER_BEFORE := 40.0
# In seconds. A delay longer than the training enemy takes to lose sight of Almos (300 frames, five seconds).
const LONG_DELAY_SECONDS := 7.0
# In physics frames. Long enough for a pursuer to walk to the exit, wait that long and come out.
const LONG_TRIP_FRAMES := 900
# In seconds. The delay of the tuned-delay test's second building, and how many frames more than DELAY_SECONDS it is.
const LONGER_DELAY_SECONDS := 1.5
const LONGER_BY_FRAMES := 60
# In physics frames. Enough for a pursuer at its post to have gone after Almos, if it were going to.
const LINGER_FRAMES := 300
# In seconds. A give-up time that no test but those of the give-up reaches.
const GENEROUS_GIVE_UP_SECONDS := 20.0

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


# The test building in the test's scene tree, shown in a view of VIEW_SIZE, with this delay. The test frees it.
func _spawn_building(delay_seconds: float) -> Building:
	var scene := load(BUILDING_PATH) as PackedScene
	assert_not_null(scene, "the test building scene should load")
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var building := scene.instantiate() as Building
	var tuning := RoomPursuitTuning.new()
	tuning.follow_delay_seconds = delay_seconds
	tuning.follow_give_up_seconds = GENEROUS_GIVE_UP_SECONDS
	building.pursuit_tuning = tuning
	view.add_child(building)
	return building


func _room(building: Building, room_name: String) -> Room:
	return building.get_node(room_name) as Room


# The training enemy the scene places in Room A.
func _enemy_of(building: Building):
	return building.get_node("RoomA/TrainingEnemy")


# Almos standing FROM_EXIT inside A's east exit, and the enemy PURSUER_BEHIND him facing him, so that it
# has noticed him by the second physics frame.
func _put_pursuer_behind_almos(building: Building) -> void:
	building.almos.global_position = A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0)
	var enemy = _enemy_of(building)
	enemy.global_position = building.almos.global_position - Vector2(PURSUER_BEHIND, 0)
	enemy.post_facing = Vector2.RIGHT
	await wait_physics_frames(2)
	assert_true(enemy.in_pursuit, "the enemy should be in Pursuit of Almos before he leaves")
	# Hurt and staggered, with the Stagger kept from draining over the trip, so that what it carries can be told.
	enemy.tuning = EnemyRig.new(self).tuning_with({"stagger_drain_pause": 1000.0})
	enemy.stagger.drain_pause = 1000.0
	enemy.health.take_damage(DAMAGE_BEFORE)
	enemy.stagger.add(STAGGER_BEFORE)


# What the enemy is, frame by frame, for this many physics frames from now: {"room": the Room it is in,
# "position", "health", "stagger", "in_pursuit"}.
# It waits on the physics_frame signal itself, as wait_physics_frames(1) takes two frames.
func _watch(enemy, frames: int) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for i in frames:
		await get_tree().physics_frame
		samples.append({
			"room": enemy.get_parent(),
			"position": enemy.global_position,
			"health": enemy.health.current,
			"stagger": enemy.stagger.current,
			"in_pursuit": enemy.in_pursuit,
		})
	return samples


# The index of the first sample the enemy is at the middle of A's east exit in, or -1.
func _first_at_east_exit(samples: Array[Dictionary]) -> int:
	for i in samples.size():
		if (samples[i]["position"] as Vector2).distance_to(A_EAST_EXIT) <= ON_THE_EXIT:
			return i
	return -1


# The index of the first sample the enemy is in this Room in, or -1.
func _first_in(samples: Array[Dictionary], room: Room) -> int:
	for i in samples.size():
		if samples[i]["room"] == room:
			return i
	return -1


# A pursuer put behind Almos, who then walks out by A's east edge and keeps walking east in B;
# what the enemy then does, frame by frame.
func _trip(building: Building, frames: int) -> Array[Dictionary]:
	await _put_pursuer_behind_almos(building)
	_almos_input.press_action(&"move_right")
	return await _watch(_enemy_of(building), frames)


func test_a_pursuer_has_not_come_out_in_room_b_before_the_delay_has_passed() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip(building, TRIP_FRAMES)

	var at_exit := _first_at_east_exit(samples)
	assert_gte(at_exit, 0, "the pursuer should walk to the exit")
	assert_eq(samples[at_exit + DELAY_FRAMES - SLACK_FRAMES]["room"], _room(building, "RoomA"), "the pursuer should still be in Room A")


func test_a_pursuer_comes_out_in_room_b_once_the_delay_has_passed() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip(building, TRIP_FRAMES)

	var at_exit := _first_at_east_exit(samples)
	assert_gte(at_exit, 0, "the pursuer should walk to the exit")
	assert_eq(samples[at_exit + DELAY_FRAMES + SLACK_FRAMES]["room"], _room(building, "RoomB"), "the pursuer should be in Room B")


func test_a_pursuer_comes_out_at_the_west_entrance_of_room_b() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip(building, TRIP_FRAMES)

	var came_out := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out, 0, "the pursuer should come out in Room B")
	assert_almost_eq(samples[came_out]["position"], B_WEST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))


func test_a_pursuer_keeps_its_health_through_the_exit() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip(building, TRIP_FRAMES)

	var came_out := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out, 0, "the pursuer should come out in Room B")
	assert_eq(samples[came_out]["health"], HEALTH_AFTER_DAMAGE)


func test_a_pursuer_keeps_its_stagger_through_the_exit() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip(building, TRIP_FRAMES)

	var came_out := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out, 0, "the pursuer should come out in Room B")
	assert_eq(samples[came_out]["stagger"], STAGGER_BEFORE)


func test_a_pursuer_is_still_in_pursuit_after_the_exit() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip(building, TRIP_FRAMES)

	var came_out := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out, 0, "the pursuer should come out in Room B")
	assert_true(samples[came_out]["in_pursuit"], "the pursuer should still be in Pursuit")


func test_a_pursuer_does_not_lose_pursuit_waiting_out_a_delay_longer_than_losing_sight_takes() -> void:
	var building := _spawn_building(LONG_DELAY_SECONDS)

	var samples := await _trip(building, LONG_TRIP_FRAMES)

	var came_out := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out, 0, "the pursuer should come out in Room B")
	assert_true(samples[came_out]["in_pursuit"], "the pursuer should still be in Pursuit")


func test_an_enemy_at_its_post_stays_in_room_a_when_almos_leaves() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	building.almos.global_position = A_EAST_ENTRANCE - Vector2(FROM_EXIT, 0)
	_almos_input.press_action(&"move_right")

	var samples := await _watch(_enemy_of(building), LINGER_FRAMES)

	assert_eq(building.current_room, _room(building, "RoomB"), "Almos should have left Room A")
	assert_eq(samples[-1]["room"], _room(building, "RoomA"), "the enemy at its post should stay in Room A")


func test_the_delay_is_the_tuned_one() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	var short_trip := await _trip(building, TRIP_FRAMES)
	var longer_building := _spawn_building(LONGER_DELAY_SECONDS)
	_almos_input.release_everything()

	var longer_trip := await _trip(longer_building, TRIP_FRAMES + LONGER_BY_FRAMES)

	var short_crossing := _first_in(short_trip, _room(building, "RoomB"))
	var longer_crossing := _first_in(longer_trip, _room(longer_building, "RoomB"))
	assert_gte(short_crossing, 0, "the pursuer should come out in Room B")
	assert_gte(longer_crossing, 0, "the pursuer should come out in Room B with the longer delay")
	assert_almost_eq(longer_crossing - short_crossing, LONGER_BY_FRAMES, 1)


# A pursuer put behind Almos, who walks out by A's east edge and, as he comes into B, turns straight
# round and walks back out by B's west edge into A, and on north in A out of the pursuer's way,
# long before the pursuer has got to the exit; what the enemy then does, frame by frame.
func _trip_with_almos_straight_back(building: Building, frames: int) -> Array[Dictionary]:
	await _put_pursuer_behind_almos(building)
	var rooms_entered := [0]
	building.room_changed.connect(func(_room: Room) -> void:
		rooms_entered[0] += 1
		if rooms_entered[0] == 1:
			_almos_input.release_action(&"move_right")
			_almos_input.press_action(&"move_left")
		elif rooms_entered[0] == 2:
			_almos_input.release_action(&"move_left")
			_almos_input.press_action(&"move_up")
	)
	_almos_input.press_action(&"move_right")
	return await _watch(_enemy_of(building), frames)


func test_a_pursuer_that_comes_out_after_almos_went_back_follows_him_back_into_room_a() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip_with_almos_straight_back(building, TRIP_FRAMES + DELAY_FRAMES * 2)

	var came_out_in_b := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out_in_b, 0, "the pursuer should come out in Room B first")
	var back_in_a := _first_in(samples.slice(came_out_in_b), _room(building, "RoomA"))
	assert_gte(back_in_a, 0, "the pursuer should follow Almos back into Room A")
	assert_almost_eq(samples[came_out_in_b + back_in_a]["position"], A_EAST_ENTRANCE, Vector2(TOLERANCE, TOLERANCE))


func test_a_pursuer_that_follows_almos_back_waits_the_delay_again() -> void:
	var building := _spawn_building(DELAY_SECONDS)

	var samples := await _trip_with_almos_straight_back(building, TRIP_FRAMES + DELAY_FRAMES * 2)

	var came_out_in_b := _first_in(samples, _room(building, "RoomB"))
	assert_gte(came_out_in_b, 0, "the pursuer should come out in Room B first")
	var back_in_a := _first_in(samples.slice(came_out_in_b), _room(building, "RoomA"))
	assert_gte(back_in_a, 0, "the pursuer should follow Almos back into Room A")
	assert_gte(back_in_a, DELAY_FRAMES - SLACK_FRAMES)


# In physics frames. How long after Almos is back in Room A the pursuer, still on its way to the exit, is hit.
const HIT_AFTER_FRAMES := 5
# In seconds, and the physics frames they come to. How long a pursuer that is held up on its way to the exit
# goes on trying before it gives up the walk.
const GIVE_UP_SECONDS := 1.0
const GIVE_UP_FRAMES := 60
# In physics frames. How far either side of that the giving up may fall, and how long the held-up pursuer
# may take to get to the obstacle first (70 pixels a second over the ~80 pixels to it).
const GIVE_UP_SLACK_FRAMES := 5
const TO_THE_OBSTACLE_FRAMES := 90
# In pixels. The obstacle that holds a pursuer up: a wall across Room A between it and the east exit.
const OBSTACLE_POSITION := Vector2(950, 324)
const OBSTACLE_SIZE := Vector2(20, 648)


# A pursuer put behind Almos, who walks out by A's east edge and straight back into A, where he walks on
# north out of the pursuer's way; returns once he is back in Room A and the pursuer, which has not got to the exit yet, is
# still on its way to it.
func _almos_back_in_room_a_while_the_pursuer_follows(building: Building) -> void:
	await _put_pursuer_behind_almos(building)
	var rooms_entered := [0]
	building.room_changed.connect(func(_room: Room) -> void:
		rooms_entered[0] += 1
		if rooms_entered[0] == 1:
			_almos_input.release_action(&"move_right")
			_almos_input.press_action(&"move_left")
		elif rooms_entered[0] == 2:
			_almos_input.release_action(&"move_left")
			_almos_input.press_action(&"move_up")
	)
	_almos_input.press_action(&"move_right")
	var frames := 0
	while rooms_entered[0] < 2 and frames < TRIP_FRAMES:
		await get_tree().physics_frame
		frames += 1
	await wait_physics_frames(HIT_AFTER_FRAMES)


func test_a_hit_on_a_pursuer_on_its_way_to_the_exit_ends_the_walk() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	await _almos_back_in_room_a_while_the_pursuer_follows(building)
	var enemy = _enemy_of(building)
	assert_eq(building.current_room, _room(building, "RoomA"), "control: Almos should be back in Room A")
	assert_true(enemy.following, "control: the pursuer should still be on its way to the exit")

	enemy.get_node("Hurtbox").landed.emit(0.0, building.almos.global_position, false)
	await wait_physics_frames(1)

	assert_false(enemy.following, "the pursuer should not be following any more")
	assert_true(enemy.in_pursuit, "the pursuer should be in Pursuit")
	assert_eq(enemy.target, building.almos, "the pursuer should be after Almos")


func test_a_pursuer_hit_on_its_way_to_the_exit_does_not_cross_afterwards() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	await _almos_back_in_room_a_while_the_pursuer_follows(building)
	var enemy = _enemy_of(building)

	enemy.get_node("Hurtbox").landed.emit(0.0, building.almos.global_position, false)
	var samples := await _watch(enemy, TRIP_FRAMES)

	assert_eq(_first_in(samples, _room(building, "RoomB")), -1, "the pursuer should stay in Room A")
	assert_eq(_first_at_east_exit(samples), -1, "the pursuer should not go on to the exit")


func test_a_hit_on_a_pursuer_waiting_at_the_exit_ends_the_wait() -> void:
	var building := _spawn_building(LONG_DELAY_SECONDS)
	var enemy = _enemy_of(building)
	await _put_pursuer_behind_almos(building)
	_almos_input.press_action(&"move_right")
	var waited := 0
	while not enemy.follow_arrived and waited < TRIP_FRAMES:
		await get_tree().physics_frame
		waited += 1
	assert_true(enemy.follow_arrived, "control: the pursuer should be waiting at the exit")

	enemy.get_node("Hurtbox").landed.emit(0.0, enemy.global_position, false)
	var samples := await _watch(enemy, LONG_TRIP_FRAMES)

	assert_false(enemy.following, "the pursuer should not be following any more")
	assert_eq(_first_in(samples, _room(building, "RoomB")), -1, "the pursuer should not cross")


# A wall across the whole height of Room A between the pursuer and the east exit, which it cannot get round.
func _put_obstacle_in_room_a(building: Building) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = OBSTACLE_SIZE
	shape.shape = rect
	wall.add_child(shape)
	_room(building, "RoomA").add_child(wall)
	wall.global_position = OBSTACLE_POSITION


# A pursuer held up by a wall on its way to the exit; how many frames after it was sent after Almos it is not
# following any more, or -1 if it still is after this many frames.
func _held_up_pursuer_gives_up_at(building: Building, frames: int) -> int:
	await _put_pursuer_behind_almos(building)
	_put_obstacle_in_room_a(building)
	_almos_input.press_action(&"move_right")
	var enemy = _enemy_of(building)
	var waited := 0
	while not enemy.following and waited < TRIP_FRAMES:
		await get_tree().physics_frame
		waited += 1
	assert_true(enemy.following, "control: the pursuer should be sent after Almos")
	for i in frames:
		await get_tree().physics_frame
		if not enemy.following:
			return i
	return -1


func test_a_pursuer_held_up_on_its_way_to_the_exit_gives_up_the_walk() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	building.pursuit_tuning.follow_give_up_seconds = GIVE_UP_SECONDS

	var gave_up_at := await _held_up_pursuer_gives_up_at(building, TO_THE_OBSTACLE_FRAMES + GIVE_UP_FRAMES + GIVE_UP_SLACK_FRAMES)

	assert_gte(gave_up_at, GIVE_UP_FRAMES - GIVE_UP_SLACK_FRAMES, "the pursuer should have tried for the give-up time")
	assert_eq(_enemy_of(building).get_parent(), _room(building, "RoomA"), "the pursuer should not have crossed")


func test_a_pursuer_that_has_given_up_the_walk_is_in_ordinary_pursuit() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	building.pursuit_tuning.follow_give_up_seconds = GIVE_UP_SECONDS
	var enemy = _enemy_of(building)

	await _held_up_pursuer_gives_up_at(building, TO_THE_OBSTACLE_FRAMES + GIVE_UP_FRAMES + GIVE_UP_SLACK_FRAMES)

	assert_false(enemy.following, "control: the pursuer should have given up the walk")
	assert_true(enemy.in_pursuit, "the pursuer should still be in Pursuit")
	# Without Almos in its Sight it loses him in time, as it does when it is in Pursuit.
	await wait_physics_frames(LINGER_FRAMES * 2)
	assert_false(enemy.in_pursuit, "the pursuer should lose Pursuit in time")


func test_a_pursuer_that_gives_up_does_not_cross_later() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	building.pursuit_tuning.follow_give_up_seconds = GIVE_UP_SECONDS
	var enemy = _enemy_of(building)
	await _held_up_pursuer_gives_up_at(building, TO_THE_OBSTACLE_FRAMES + GIVE_UP_FRAMES + GIVE_UP_SLACK_FRAMES)

	var samples := await _watch(enemy, TRIP_FRAMES)

	assert_eq(_first_in(samples, _room(building, "RoomB")), -1, "the pursuer should stay in Room A")


func test_the_give_up_time_is_the_tuned_one() -> void:
	var building := _spawn_building(DELAY_SECONDS)
	building.pursuit_tuning.follow_give_up_seconds = GIVE_UP_SECONDS
	var short_gave_up_at := await _held_up_pursuer_gives_up_at(building, TO_THE_OBSTACLE_FRAMES + GIVE_UP_FRAMES * 2)
	_almos_input.release_everything()
	var longer_building := _spawn_building(DELAY_SECONDS)
	longer_building.pursuit_tuning.follow_give_up_seconds = GIVE_UP_SECONDS * 2

	var longer_gave_up_at := await _held_up_pursuer_gives_up_at(longer_building, TO_THE_OBSTACLE_FRAMES + GIVE_UP_FRAMES * 3)

	assert_gte(short_gave_up_at, 0, "the pursuer should give up")
	assert_gte(longer_gave_up_at, 0, "the pursuer should give up with the longer time")
	assert_almost_eq(longer_gave_up_at - short_gave_up_at, GIVE_UP_FRAMES, GIVE_UP_SLACK_FRAMES)
