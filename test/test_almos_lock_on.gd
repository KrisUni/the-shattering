extends GutTest
## Almos's Lock-on, seen only through the scene: input goes in as actions or real input
## events, and stand-in enemies (a Node2D in the enemies group that announces its death) are
## placed around him, apart from the cases that need the real training enemy. Every physics
## frame a sample of Almos is taken, so what happened can be read back frame by frame.
## Expected numbers come from the tuning data files the scenes use and plain arithmetic,
## never from how the code works them out.
##
## Pushing "straight across the line" to the target is done the way a player holds him on the
## circle: the stick is turned a little every frame so that it stays across the line as he
## goes round. A stick held in one fixed direction is split against the line once, when it is
## first held (it is latched), and keeps that mix of closing in and going round as he goes
## round, so one fixed key circles him too. It latches afresh when it is turned past a
## tolerance from the latched direction, or let go of and pressed again, or the lock is made
## afresh.
##
## A sample is taken at the start of each physics frame, before anything has moved in it, so
## it shows how its predecessor left things: a sample's position and facing are the ones the
## previous frame ended with, and the frame that follows moves him from that position to the
## next sample's.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const WEAPON_PATH := AlmosInput.WEAPON_PATH
const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
const FACING_TOLERANCE := AlmosInput.FACING_TOLERANCE
# Almos's sprites show eight facings, so the direction he faces is the nearest of eight.
const FACING_STEP := TAU / 8.0
# A tap: held this many physics frames, far shorter than a swing or a hold.
const TAP_FRAMES := 3
# In pixels.
const POSITION_TOLERANCE := 0.01
# In pixels. Far tighter than the drift of a straight step per frame, which adds up to most
# of a pixel over a second, and far looser than rounding.
const DISTANCE_TOLERANCE := 0.05
# In pixels per second.
const SPEED_TOLERANCE := 0.5
# In radians. For one frame's turn, or the angle of the sword.
const ANGLE_TOLERANCE := 0.0001
# In radians. For the sum of a second's turns.
const TOTAL_ANGLE_TOLERANCE := 0.001
# In Stamina points.
const STAMINA_TOLERANCE := 0.0001
# In pixels. How far inside or outside a range a test puts a target to be clearly on one side.
const RANGE_MARGIN := 2.0
# In seconds. How long a test walks or Sprints when the amount does not matter.
const MOVING_SECONDS := 0.5
const SPRINT_SECONDS := 0.4
# In seconds. How long a test circles for: enough to go a good way round.
const CIRCLING_SECONDS := 1.0
# In pixels. How far from him the top edge of a wall stands.
const WALL_DISTANCE := 40.0
# In pixels. How far short of a wall he may be stopped by it.
const WALL_SLACK := 3.0
# In pixels. How far from the target he starts out in the test of going past halfway round it:
# near, so that it takes little time.
const NEAR_RADIUS := 60.0
# In radians. How far round the target a test takes him to be past halfway (which is PI).
const PAST_HALFWAY := 1.25 * PI
# In degrees. How far inside or past the tolerance for latching afresh a test turns the stick,
# to be clearly on one side of it.
const RELATCH_MARGIN_DEGREES := 5.0
# In degrees. How much each frame turns the stick in the test of a slow turn, and how far it
# turns it in all. Each frame's turn is far within the tolerance, and the whole is far past it.
const SLOW_TURN_DEGREES_PER_FRAME := 3.0
const SLOW_TURN_DEGREES := 90.0
# In degrees. How far the way he is going may be from the way the stick points, once it has
# been turned slowly: the tolerance, plus the few degrees the line to the target turns
# between one latching and the next. Going on round instead would be some 70 degrees off.
const STEP_ANGLE_TOLERANCE_DEGREES := 30.0
# How hard, as a share of full, a stick is pushed in the test of a lighter push.
const HALF_STRENGTH := 0.5
# As a share of a full walking step. For how a frame's step splits into the parts along the
# line to the target and across it.
const SPLIT_TOLERANCE := 0.005
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 240

# Where, in degrees clockwise from right, a target stands, and the nearest of the eight
# compass directions to it. The 40, 200 and 290 degree rows would be wrong if the angle were
# truncated instead of rounded.
var facing_params = ParameterFactory.named_parameters(
	["target_degrees", "facing_degrees"],
	[[20.0, 0.0], [40.0, 45.0], [100.0, 90.0], [200.0, 180.0], [290.0, 270.0]],
)

# Degrees clockwise from right, none of them along one of the eight directions.
var off_axis_degrees = [30.0, 200.0]

# Which side of him the target stands on, and which way round it he is pushed: 1 turns the
# line to him a quarter turn one way, -1 the other.
var circling_params = ParameterFactory.named_parameters(
	["side", "turn"],
	[
		[Vector2.RIGHT, 1.0], [Vector2.RIGHT, -1.0], [Vector2.LEFT, 1.0],
		[Vector2.UP, -1.0], [Vector2.DOWN, 1.0],
	],
)

# The button that pushes him straight towards or straight away from a target on his right,
# and whether that closes the distance.
var along_params = ParameterFactory.named_parameters(
	["action", "closes"],
	[[&"move_right", true], [&"move_left", false]],
)

# How far the stick is turned from the direction it was held in, as a margin inside or past
# the tolerance for latching afresh, and whether it is then latched afresh.
var turn_params = ParameterFactory.named_parameters(
	["name", "margin_degrees", "afresh"],
	[
		["a wobble within the tolerance", -RELATCH_MARGIN_DEGREES, false],
		["a turn past the tolerance", RELATCH_MARGIN_DEGREES, true],
	],
)

# The ways the lock can be lost while a key is held.
var lost_lock_params = ParameterFactory.named_parameters(
	["how"],
	[["the button"], ["the target's death"], ["the break range"]],
)

# Each way to press the Lock-on button other than as the action itself.
var lock_on_binding_params = ParameterFactory.named_parameters(
	["name", "press"],
	[
		["the middle mouse button", func(input: AlmosInput): input.press_mouse_button(MOUSE_BUTTON_MIDDLE)],
		["the Q key", func(input: AlmosInput): input.press_key(KEY_Q)],
		["the right stick of a pad", func(input: AlmosInput): input.press_joypad_button(JOY_BUTTON_RIGHT_STICK)],
	],
)

# How far from the edge of a range a target stands, in pixels, and whether Lock-on picks it.
var lock_on_edge_params = ParameterFactory.named_parameters(
	["offset", "picked"],
	[[-RANGE_MARGIN, true], [RANGE_MARGIN, false]],
)

# Whether the nearer of two enemies in range is added to the scene first.
var order_params = [true, false]

# The ways a target can be freed.
var free_params = ParameterFactory.named_parameters(
	["name", "free"],
	[
		["free", func(node: Node): node.free()],
		["queue_free", func(node: Node): node.queue_free()],
	],
)

var _almos_input: AlmosInput
var _enemy_rig: EnemyRig
var _almos: Node2D
var _samples: Array[Dictionary] = []
# The enemy being circled and which way round, while a test is steering him across the line to it.
var _steering_round: Node2D
var _steering_turn := 0.0


## Something to lock on to: it is in the enemies group and announces its death.
class StandInEnemy:
	extends Node2D
	signal died

	func _init() -> void:
		add_to_group(&"enemies")


func before_each() -> void:
	_almos_input = AlmosInput.new(self)
	_enemy_rig = EnemyRig.new(self)


func after_each() -> void:
	_stop_sampling()
	_stop_steering()
	_enemy_rig.stop_sampling()
	_almos_input.release_everything()


# --- The tuning ---

func test_the_lock_on_ranges_are_tuned_and_the_lock_does_not_break_before_it_could_be_made() -> void:
	var tuning := _tuning()

	assert_gt(tuning.lock_on_range, 0.0, "lock_on_range in the data file should be positive")
	assert_gte(tuning.lock_on_break_range, tuning.lock_on_range, "lock_on_break_range should be at least lock_on_range, so that a lock does not flicker at the edge")


func test_the_tolerance_for_latching_afresh_is_tuned_between_nothing_and_a_half_turn() -> void:
	var tuning := _tuning()

	assert_gt(tuning.lock_on_relatch_degrees, 0.0, "lock_on_relatch_degrees in the data file should be positive, or a held direction would latch afresh every frame")
	assert_lt(tuning.lock_on_relatch_degrees, 180.0, "lock_on_relatch_degrees in the data file should be less than a half turn, or no new direction would ever latch afresh")


# --- Locking on and letting go ---

func test_pressing_lock_on_with_an_enemy_in_range_locks_on_to_it() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _wait_frames(SETTLE_FRAMES)
	assert_false(almos.locked_on, "he should not be locked on before the press")

	await _tap(&"lock_on")

	assert_true(almos.locked_on, "he should be locked on")
	assert_eq(almos.lock_on_target, enemy, "the enemy in range should be the target")


func test_with_two_enemies_in_range_lock_on_picks_the_nearer(nearer_first = use_parameters(order_params)) -> void:
	var almos = _spawn_almos()
	var nearer: StandInEnemy
	var farther: StandInEnemy
	if nearer_first:
		nearer = _place_enemy(Vector2.LEFT, _range() * 0.4)
		farther = _place_enemy(Vector2.RIGHT, _range() * 0.8)
	else:
		farther = _place_enemy(Vector2.RIGHT, _range() * 0.8)
		nearer = _place_enemy(Vector2.LEFT, _range() * 0.4)

	await _tap(&"lock_on")

	assert_eq(almos.lock_on_target, nearer, "the nearer enemy should be the target")


func test_with_no_enemy_in_range_pressing_lock_on_does_nothing() -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _range() + RANGE_MARGIN)

	await _tap(&"lock_on")

	assert_false(almos.locked_on, "he should not be locked on")
	assert_null(almos.lock_on_target, "there should be no target")


func test_lock_on_picks_an_enemy_just_inside_the_range_and_not_one_just_outside(params = use_parameters(lock_on_edge_params)) -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _range() + params.offset)

	await _tap(&"lock_on")

	assert_eq(almos.locked_on, params.picked, "locked on or not")


func test_lock_on_ignores_nodes_that_are_not_in_the_enemies_group() -> void:
	var almos = _spawn_almos()
	var bystander := Node2D.new()
	bystander.position = almos.global_position + Vector2.RIGHT * _range() / 4.0
	add_child_autofree(bystander)
	var enemy := _place_enemy(Vector2.LEFT, _range() * 0.8)

	await _tap(&"lock_on")

	assert_eq(almos.lock_on_target, enemy, "only an enemy can be locked on to, however near something else is")


func test_pressing_lock_on_again_lets_go() -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _lock_on()

	await _tap(&"lock_on")

	assert_false(almos.locked_on, "he should have let go")
	assert_null(almos.lock_on_target, "there should be no target")


func test_one_press_toggles_once_however_long_the_button_is_held() -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _range() / 2.0)

	_almos_input.press_action(&"lock_on")
	await _wait_frames(_frames_for(MOVING_SECONDS))

	assert_true(almos.locked_on, "he should have locked on once and stayed locked on")


func test_the_lock_on_button_can_be_a_mouse_button_a_key_or_a_pad_button(params = use_parameters(lock_on_binding_params)) -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _range() / 2.0)

	params.press.call(_almos_input)
	await _wait_frames(SETTLE_FRAMES)

	assert_true(almos.locked_on, "%s should lock on" % params.name)


func test_the_training_enemy_is_in_the_enemies_group() -> void:
	var enemy = _enemy_rig.spawn_enemy(null, Vector2.ZERO)

	assert_true(enemy.is_in_group(&"enemies"), "the training enemy should be something Lock-on can pick")


func test_in_the_test_room_lock_on_picks_the_training_enemy() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	if scene == null:
		return
	var room := scene.instantiate()
	add_child_autofree(room)
	var almos = room.find_child("Almos", true, false)
	var enemy = room.find_child("TrainingEnemy", true, false)
	assert_not_null(almos, "the test room should contain Almos")
	assert_not_null(enemy, "the test room should contain a TrainingEnemy")
	if almos == null or enemy == null:
		return
	assert_lt(almos.global_position.distance_to(enemy.global_position), _range(), "the training enemy should start within Lock-on range of him")

	await _tap(&"lock_on")

	assert_eq(almos.lock_on_target, enemy, "he should be locked on to the training enemy")


# --- Letting go on its own ---

func test_the_lock_holds_while_the_target_is_beyond_the_range_that_picks_but_within_the_range_that_breaks() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _lock_on()

	enemy.global_position = almos.global_position + Vector2.RIGHT * (_range() + _break_range()) / 2.0
	await _wait_frames(SETTLE_FRAMES)

	assert_true(almos.locked_on, "the lock should still hold")
	assert_eq(almos.lock_on_target, enemy)


func test_the_lock_breaks_when_the_target_gets_beyond_the_break_range_and_he_keeps_his_facing() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _lock_on()
	var facing_before: Vector2 = almos.facing
	assert_almost_eq(facing_before, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "he should be facing the target to begin with")

	# Up, not right, so that he would turn to it if he went on facing it.
	enemy.global_position = almos.global_position + Vector2.UP * (_break_range() + RANGE_MARGIN)
	await _wait_frames(SETTLE_FRAMES)

	assert_false(almos.locked_on, "the lock should have broken")
	assert_null(almos.lock_on_target, "there should be no target")
	assert_almost_eq(almos.facing, facing_before, Vector2.ONE * FACING_TOLERANCE, "he should keep the facing he had")


func test_the_lock_breaks_when_the_target_announces_its_death_and_he_keeps_his_facing() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _lock_on()

	enemy.died.emit()

	assert_false(almos.locked_on, "the lock should break as the target dies")
	await _wait_frames(SETTLE_FRAMES)
	assert_almost_eq(almos.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "he should keep the facing he had")


func test_the_lock_breaks_when_a_training_enemy_dies() -> void:
	var almos = _spawn_almos()
	var enemy = _enemy_rig.spawn_enemy(null, almos.global_position + Vector2.RIGHT * _range() / 2.0)
	await _lock_on()
	assert_eq(almos.lock_on_target, enemy, "he should have locked on to it")

	enemy.health.take_damage(enemy.health.maximum)
	await _wait_frames(SETTLE_FRAMES)

	assert_false(is_instance_valid(enemy), "the enemy should be gone")
	assert_false(almos.locked_on, "the lock should have broken")
	assert_null(almos.lock_on_target, "there should be no target")
	assert_false(_marker(almos).visible, "the marker should be gone")


func test_the_lock_breaks_when_the_target_is_freed(params = use_parameters(free_params)) -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _lock_on()

	params.free.call(enemy)
	await _wait_frames(SETTLE_FRAMES)

	assert_false(almos.locked_on, "the lock should have broken")
	assert_null(almos.lock_on_target, "there should be no target")
	assert_false(_marker(almos).visible, "the marker should be gone")


func test_after_the_target_is_freed_he_can_lock_on_to_another() -> void:
	var almos = _spawn_almos()
	var first := _place_enemy(Vector2.RIGHT, _range() * 0.4)
	var second := _place_enemy(Vector2.LEFT, _range() * 0.8)
	await _lock_on()
	assert_eq(almos.lock_on_target, first, "the first enemy is the nearer")

	first.free()
	await _wait_frames(SETTLE_FRAMES)
	await _tap(&"lock_on")

	assert_eq(almos.lock_on_target, second, "he should lock on to the one that is left")


func test_after_the_lock_breaks_he_moves_in_straight_lines_and_faces_where_he_walks() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _range() / 2.0)
	await _lock_on()
	enemy.died.emit()
	await _wait_frames(SETTLE_FRAMES)
	var start: Vector2 = almos.position

	_almos_input.press_action(&"move_up")
	await _wait_frames(_frames_for(MOVING_SECONDS))

	assert_almost_eq(almos.position.x, start.x, POSITION_TOLERANCE, "he should walk straight up")
	assert_lt(almos.position.y, start.y, "he should have walked up")
	assert_almost_eq(almos.facing, Vector2.UP, Vector2.ONE * FACING_TOLERANCE, "he should face where he walks")


# --- Facing the target ---

func test_he_faces_the_target_as_the_nearest_of_eight_directions(params = use_parameters(facing_params)) -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.from_angle(deg_to_rad(params.target_degrees)), _distance())

	await _lock_on()

	var expected := Vector2.from_angle(deg_to_rad(params.facing_degrees))
	assert_almost_eq(almos.facing, expected, Vector2.ONE * FACING_TOLERANCE)


func test_he_keeps_facing_the_target_while_walking_away_from_it() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	var start_distance: float = almos.position.distance_to(enemy.global_position)

	_almos_input.press_action(&"move_left")
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var walked: float = almos.position.distance_to(enemy.global_position) - start_distance
	assert_gt(walked, _tuning().walk_speed * MOVING_SECONDS / 2.0, "he should have walked away from the target")
	assert_almost_eq(almos.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "he should still face it")
	_assert_facing_the_target_in_every_sample(enemy)


func test_he_keeps_facing_the_target_while_sprinting_away_from_it() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()

	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"roll")
	await _wait_frames(_frames_for(_tuning().roll_hold_threshold + SPRINT_SECONDS))

	assert_ne(_first_sample_where("sprinting"), -1, "he should have sprinted")
	assert_almost_eq(almos.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "he should still face it")
	_assert_facing_the_target_in_every_sample(enemy)


func test_he_faces_the_target_through_an_attack() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()

	await _tap(&"attack_light")
	await _wait_frames(SETTLE_FRAMES)

	assert_true(almos.attacking, "the swing should be under way")
	_assert_facing_the_target_in_every_sample(enemy)


# --- Circling the target ---

func test_pushing_straight_across_the_line_to_the_target_circles_it_at_a_constant_distance(params = use_parameters(circling_params)) -> void:
	_spawn_almos()
	var radius := _distance()
	var enemy := _place_enemy(params.side, radius)
	await _lock_on()
	var begun := _this_frame()

	_steer_round(enemy, params.turn)
	await _wait_frames(_frames_for(CIRCLING_SECONDS))

	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	for i in range(first_move, _samples.size()):
		assert_almost_eq(_samples[i].position.distance_to(center), radius, DISTANCE_TOLERANCE, "his distance to the target in sample %d" % i)
	# Input stays screen-relative: his first step is the way the stick points, which is across
	# the line from the target to him.
	var pushed := (-params.side as Vector2).rotated(params.turn * PI / 2.0)
	var first_step: Vector2 = _samples[first_move + 1].position - _samples[first_move].position
	assert_gt(first_step.normalized().dot(pushed), 0.99, "he should set off the way the stick points")
	var seconds := float(_samples.size() - 1 - first_move) * _frame_seconds()
	var swept := _angle_round(center, _samples[first_move].position, _samples[_samples.size() - 1].position)
	assert_almost_eq(absf(swept), _tuning().walk_speed * seconds / radius, TOTAL_ANGLE_TOLERANCE, "the angle he went round the target by")


func test_circling_goes_round_at_walking_speed_in_every_frame() -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	var begun := _this_frame()

	_steer_round(enemy, 1.0)
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	for j in range(maxi(first_move, 0), _samples.size() - 1):
		assert_almost_eq(_speed_round(enemy.global_position, j), _tuning().walk_speed, SPEED_TOLERANCE, "his speed round the target in frame %d" % j)


func test_sprinting_across_the_line_goes_round_at_sprint_speed_and_costs_stamina_as_before() -> void:
	_spawn_almos()
	var radius := _distance()
	var enemy := _place_enemy(Vector2.RIGHT, radius)
	await _lock_on()
	var tuning := _tuning()

	_steer_round(enemy, 1.0)
	_almos_input.press_action(&"roll")
	await _wait_frames(_frames_for(tuning.roll_hold_threshold + SPRINT_SECONDS))

	var sprint_frames := 0
	for j in range(_samples.size() - 1):
		# The sample after a frame shows the state that frame left him in.
		if _samples[j + 1].sprinting:
			sprint_frames += 1
			assert_almost_eq(_speed_round(enemy.global_position, j), tuning.sprint_speed, SPEED_TOLERANCE, "his speed round the target in frame %d" % j)
			assert_almost_eq(_samples[j].stamina - _samples[j + 1].stamina, tuning.sprint_stamina_per_second * _frame_seconds(), STAMINA_TOLERANCE, "the Stamina the Sprint cost in frame %d" % j)
			assert_almost_eq(_samples[j + 1].position.distance_to(enemy.global_position), radius, DISTANCE_TOLERANCE, "his distance to the target after frame %d" % j)
	assert_gt(sprint_frames, 0, "he should have sprinted")


func test_pushing_towards_the_target_closes_the_distance_and_pushing_away_opens_it(params = use_parameters(along_params)) -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	var begun := _this_frame()

	_almos_input.press_action(params.action)
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	var trend := -1.0 if params.closes else 1.0
	for j in range(maxi(first_move, 0), _samples.size() - 1):
		var change: float = _samples[j + 1].position.distance_to(enemy.global_position) - _samples[j].position.distance_to(enemy.global_position)
		assert_almost_eq(change / _frame_seconds(), trend * _tuning().walk_speed, SPEED_TOLERANCE, "the speed the distance changed at in frame %d" % j)
		assert_almost_eq(_samples[j + 1].position.y, _samples[j].position.y, POSITION_TOLERANCE, "he should stay on the line to the target in frame %d" % j)


# --- Holding a direction keeps him circling ---

func test_holding_one_key_keeps_him_going_round_the_target_at_a_constant_distance() -> void:
	_spawn_almos()
	var radius := _distance()
	var enemy := _place_enemy(Vector2.UP, radius)
	await _lock_on()
	var begun := _this_frame()

	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(CIRCLING_SECONDS))

	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	for i in range(first_move, _samples.size()):
		assert_almost_eq(_samples[i].position.distance_to(center), radius, DISTANCE_TOLERANCE, "his distance to the target in sample %d" % i)
	# Input stays screen-relative: his first step is the way the key points, which is across the
	# line from the target to him.
	var first_step: Vector2 = _samples[first_move + 1].position - _samples[first_move].position
	assert_gt(first_step.normalized().dot(Vector2.RIGHT), 0.99, "he should set off the way the key points")
	var seconds := float(_samples.size() - 1 - first_move) * _frame_seconds()
	assert_almost_eq(absf(_total_angle_round(center, first_move)), _tuning().walk_speed * seconds / radius, TOTAL_ANGLE_TOLERANCE, "the angle he went round the target by")


func test_holding_one_key_past_halfway_round_the_target_keeps_him_circling_as_his_screen_motion_reverses() -> void:
	_spawn_almos()
	var radius := NEAR_RADIUS
	var enemy := _place_enemy(Vector2.UP, radius)
	await _lock_on()
	var begun := _this_frame()

	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(PAST_HALFWAY * radius / _tuning().walk_speed))

	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	for i in range(first_move, _samples.size()):
		assert_almost_eq(_samples[i].position.distance_to(center), radius, DISTANCE_TOLERANCE, "his distance to the target in sample %d" % i)
	assert_gt(absf(_total_angle_round(center, first_move)), PI, "he should have gone past halfway round")
	var first_step: Vector2 = _samples[first_move + 1].position - _samples[first_move].position
	var last_step: Vector2 = _samples[-1].position - _samples[-2].position
	assert_gt(first_step.dot(Vector2.RIGHT), 0.0, "he should set off the way the key points")
	assert_lt(last_step.dot(Vector2.RIGHT), 0.0, "past halfway he should be going the other way on the screen, with the key still held")


func test_a_stick_held_across_and_towards_keeps_the_mix_latched_in_every_frame() -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	var begun := _this_frame()
	var stick := Vector2(1.0, 1.0).normalized()

	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"move_down")
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	# The part of the stick along the line to the target and the part across it, as the line
	# stood when he set off. Every frame moves him that far closer or farther and that far
	# round, though the line turns as he goes.
	var latched := _split_at(first_move, center, stick)
	assert_gt(absf(latched.x), 0.1, "the stick should have a part along the line")
	assert_gt(absf(latched.y), 0.1, "the stick should have a part across the line")
	_assert_split_kept(center, first_move, latched, "his move")
	# By the end the line has turned far enough for a fresh split to be told from the latched one.
	var fresh_at_the_end := _split_at(_samples.size() - 2, center, stick)
	assert_gt((fresh_at_the_end - latched).length(), 0.1, "the line should have turned enough for the test to show anything")


func test_pushing_the_held_direction_less_hard_goes_round_more_slowly_in_the_same_mix() -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.UP, _distance())
	await _lock_on()
	var begun := _this_frame()
	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(MOVING_SECONDS))
	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	var latched := _moved_split(center, first_move)

	# A push past the deadzone reads as the share of the way to full that it covers: this one
	# reads as half. The direction is the same, so the mix is too.
	var deadzone := InputMap.action_get_deadzone(&"move_right")
	Input.action_press(&"move_right", deadzone + HALF_STRENGTH * (1.0 - deadzone))
	var eased := _this_frame()
	await _wait_frames(_frames_for(MOVING_SECONDS))

	_assert_split_kept(center, eased, latched * HALF_STRENGTH, "his move at half strength")


func test_changing_to_another_key_re_latches_against_the_line_at_that_moment() -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.UP, _distance())
	await _lock_on()
	var begun := _this_frame()
	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(MOVING_SECONDS))
	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	var latched := _moved_split(center, first_move)

	# The new key goes down in the frame the old one comes up, so that no frame sees none held.
	_almos_input.release_action(&"move_right")
	_almos_input.press_action(&"move_down")
	var changed := _this_frame()
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var afresh := _split_at(changed, center, Vector2.DOWN)
	assert_gt((afresh - latched).length(), 0.5, "the new key should split differently from the old one against the line now")
	_assert_split_kept(center, changed, afresh, "his move after the change")


func test_turning_the_stick_re_latches_only_when_it_is_past_the_tolerance(params = use_parameters(turn_params)) -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.UP, _distance())
	await _lock_on()
	var begun := _this_frame()
	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(MOVING_SECONDS))
	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	var latched := _moved_split(center, first_move)
	var turned_by: float = _tuning().lock_on_relatch_degrees + params.margin_degrees
	var stick := Vector2.RIGHT.rotated(deg_to_rad(turned_by))

	_hold_stick(stick)
	var turned := _this_frame()
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var afresh := _split_at(turned, center, stick)
	assert_gt((afresh - latched).length(), 0.2, "a fresh split should differ from the latched one, or the test shows nothing")
	_assert_split_kept(center, turned, afresh if params.afresh else latched, "his move after %s" % params.name)


func test_a_stick_turned_slowly_re_latches_once_it_is_past_the_tolerance_from_the_latched_direction() -> void:
	_spawn_almos()
	_place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	assert_lt(SLOW_TURN_DEGREES_PER_FRAME, _tuning().lock_on_relatch_degrees, "each frame's turn should be within the tolerance, or the test shows nothing")
	assert_gt(SLOW_TURN_DEGREES, _tuning().lock_on_relatch_degrees, "the whole turn should be past the tolerance, or the test shows nothing")

	# He starts out going round, with the stick across the line to a target on his right, and
	# the stick is turned a little every frame until it points at the target.
	var stick := Vector2.UP
	_hold_stick(stick)
	await _wait_frames(SETTLE_FRAMES)
	for i in ceili(SLOW_TURN_DEGREES / SLOW_TURN_DEGREES_PER_FRAME):
		stick = stick.rotated(deg_to_rad(SLOW_TURN_DEGREES_PER_FRAME))
		_hold_stick(stick)
		await _wait_frames(1)
	await _wait_frames(SETTLE_FRAMES)

	var last_step: Vector2 = _samples[-1].position - _samples[-2].position
	assert_lt(rad_to_deg(absf(last_step.angle_to(stick))), STEP_ANGLE_TOLERANCE_DEGREES, "degrees between the way he went in the last frame and the way the stick points")


func test_letting_go_of_the_key_and_pressing_it_again_re_latches() -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.UP, _distance())
	await _lock_on()
	var begun := _this_frame()
	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(MOVING_SECONDS))
	var center: Vector2 = enemy.global_position
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	var latched := _moved_split(center, first_move)

	_almos_input.release_action(&"move_right")
	await _wait_frames(SETTLE_FRAMES)
	_almos_input.press_action(&"move_right")
	var pressed_again := _this_frame()
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var afresh := _split_at(pressed_again, center, Vector2.RIGHT)
	assert_gt((afresh - latched).length(), 0.2, "a fresh split should differ from the latched one, or the test shows nothing")
	_assert_split_kept(center, pressed_again, afresh, "his move after the key is pressed again")


func test_a_key_still_held_latches_afresh_when_the_lock_is_made_again_after_being_lost(params = use_parameters(lost_lock_params)) -> void:
	_spawn_almos()
	var enemy := _place_enemy(Vector2.UP, _distance())
	var center := enemy.global_position
	await _lock_on()
	var begun := _this_frame()
	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(MOVING_SECONDS))
	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	if first_move == -1:
		return
	var latched := _moved_split(center, first_move)

	# He goes on holding the key, and walks on in a straight line for a while without the lock,
	# so the line to the target is not what it was when he began to circle.
	await _lose_the_lock(params.how, enemy)
	await _wait_frames(_frames_for(MOVING_SECONDS))
	enemy.global_position = center
	var relocking := _this_frame()
	await _lock_on()

	var made := _first_locked_frame(relocking)
	assert_ne(made, -1, "the lock should have been made")
	if made == -1:
		return
	await _wait_frames(_frames_for(MOVING_SECONDS))
	var afresh := _split_at(made, center, Vector2.RIGHT)
	assert_gt((afresh - latched).length(), 0.2, "a fresh split should differ from the latched one, or the test shows nothing")
	_assert_split_kept(center, made, afresh, "his move after the lock is made again")


func test_without_lock_on_the_same_push_moves_him_in_a_straight_line() -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _distance())
	await _wait_frames(SETTLE_FRAMES)
	var start: Vector2 = almos.position
	var begun := _this_frame()

	_almos_input.press_action(&"move_down")
	await _wait_frames(_frames_for(CIRCLING_SECONDS))

	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	for j in range(maxi(first_move, 0), _samples.size() - 1):
		assert_almost_eq(_samples[j + 1].position.x, start.x, POSITION_TOLERANCE, "he should stay in his column in frame %d" % j)
		assert_almost_eq(_samples[j + 1].position.y - _samples[j].position.y, _tuning().walk_speed * _frame_seconds(), POSITION_TOLERANCE, "he should walk at walking speed in frame %d" % j)


func test_walls_still_stop_him_as_he_circles() -> void:
	var almos = _spawn_almos()
	var radius: float = (almos.get_node("CollisionShape2D") as CollisionShape2D).shape.radius
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(_range() * 4.0, WALL_DISTANCE)
	shape.shape = box
	wall.add_child(shape)
	wall.position = almos.global_position + Vector2.DOWN * (WALL_DISTANCE + box.size.y / 2.0)
	add_child_autofree(wall)
	_place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	var start_y: float = almos.position.y

	_almos_input.press_action(&"move_down")
	await _wait_frames(_frames_for(CIRCLING_SECONDS))

	# Left to circle, he would go well below the wall's top edge.
	var unhindered := _distance() * sin(_tuning().walk_speed * CIRCLING_SECONDS / _distance())
	assert_gt(unhindered, WALL_DISTANCE, "the wall should be in his way")
	assert_lte(almos.position.y, start_y + WALL_DISTANCE - radius + POSITION_TOLERANCE, "he should not get through the wall")
	assert_gt(almos.position.y, start_y + WALL_DISTANCE - radius - WALL_SLACK, "he should have got up to the wall")


func test_on_top_of_the_target_he_moves_as_he_would_without_lock_on() -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, 0.0)
	await _lock_on()
	var start: Vector2 = almos.position
	var begun := _this_frame()

	_almos_input.press_action(&"move_right")
	await _wait_frames(_frames_for(MOVING_SECONDS))

	var first_move := _first_moving_frame(begun)
	assert_ne(first_move, -1, "he should have moved")
	assert_false(is_nan(almos.position.x) or is_nan(almos.position.y), "his position should be a number")
	assert_almost_eq(almos.position.y, start.y, POSITION_TOLERANCE, "he should walk straight")
	var frames := _samples.size() - 1 - first_move
	assert_almost_eq(almos.position.x - start.x, _tuning().walk_speed * _frame_seconds() * frames, POSITION_TOLERANCE * frames, "he should walk at walking speed")


# --- Attacks aim at the target ---

func test_a_light_swing_aims_the_sword_exactly_at_the_target_and_commits_to_it(degrees = use_parameters(off_axis_degrees)) -> void:
	var almos = _spawn_almos()
	var toward := Vector2.from_angle(deg_to_rad(degrees))
	var enemy := _place_enemy(toward, _distance())
	await _lock_on()
	assert_gt(absf(angle_difference(almos.facing.angle(), toward.angle())), ANGLE_TOLERANCE, "the target should stand off his eight-way facing, or this test shows nothing")

	await _tap(&"attack_light")

	assert_true(almos.attacking, "the swing should have begun")
	assert_almost_eq(_sword_angle_off(almos, toward.angle()), 0.0, ANGLE_TOLERANCE, "how far the sword is turned from the target")
	# The swing is committed: the target moving away afterwards does not turn it.
	enemy.global_position = almos.global_position + Vector2.from_angle(toward.angle() + 1.0) * _distance()
	await _wait_frames(SETTLE_FRAMES)
	assert_true(almos.attacking, "the swing should still be under way")
	assert_almost_eq(_sword_angle_off(almos, toward.angle()), 0.0, ANGLE_TOLERANCE, "how far the sword is turned from where the target was")


func test_a_heavy_attack_aims_the_sword_exactly_at_the_target_where_it_is_when_released(degrees = use_parameters(off_axis_degrees)) -> void:
	var almos = _spawn_almos()
	var heavy := (load(WEAPON_PATH) as WeaponData).heavy_attack
	var enemy := _place_enemy(Vector2.from_angle(deg_to_rad(degrees + 90.0)), _distance())
	await _lock_on()
	var toward := Vector2.from_angle(deg_to_rad(degrees))

	_almos_input.press_action(&"attack_heavy")
	await _wait_frames(SETTLE_FRAMES + heavy.charge_frames_max / 4)
	assert_true(almos.charging, "he should be charging")
	# The target moves while he charges, so where it was when the charge began is not where
	# the swing goes.
	enemy.global_position = almos.global_position + toward * _distance()
	await _wait_frames(SETTLE_FRAMES)
	_almos_input.release_action(&"attack_heavy")
	await _wait_frames(SETTLE_FRAMES)

	assert_true(almos.attacking, "the swing should have begun")
	assert_almost_eq(_sword_angle_off(almos, toward.angle()), 0.0, ANGLE_TOLERANCE, "how far the sword is turned from the target")
	enemy.global_position = almos.global_position + Vector2.from_angle(toward.angle() + 1.0) * _distance()
	await _wait_frames(SETTLE_FRAMES)
	assert_true(almos.attacking, "the swing should still be under way")
	assert_almost_eq(_sword_angle_off(almos, toward.angle()), 0.0, ANGLE_TOLERANCE, "how far the sword is turned from where the target was")


# --- Rolls aim relative to the target ---

func test_a_roll_with_a_direction_pushed_goes_straight_that_way_under_lock_on() -> void:
	_spawn_almos()
	_place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	_almos_input.press_action(&"move_up")
	_almos_input.press_action(&"move_left")
	await _wait_frames(SETTLE_FRAMES)

	await _tap(&"roll")
	await _wait_for_the_roll_to_finish()

	var expected := Vector2(-1.0, -1.0).normalized() * _tuning().roll_distance
	assert_almost_eq(_roll_displacement(), expected, Vector2.ONE * POSITION_TOLERANCE)


func test_a_roll_with_nothing_pushed_goes_directly_away_from_the_target(degrees = use_parameters(off_axis_degrees)) -> void:
	_spawn_almos()
	var toward := Vector2.from_angle(deg_to_rad(degrees))
	_place_enemy(toward, _distance())
	await _lock_on()

	await _tap(&"roll")
	await _wait_for_the_roll_to_finish()

	assert_almost_eq(_roll_displacement(), -toward * _tuning().roll_distance, Vector2.ONE * POSITION_TOLERANCE)


func test_he_keeps_facing_the_target_through_a_roll_and_after_it() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	_almos_input.press_action(&"move_up")
	await _wait_frames(SETTLE_FRAMES)

	await _tap(&"roll")
	await _wait_for_the_roll_to_finish()
	await _wait_frames(SETTLE_FRAMES)

	# He went straight up, so the target is now down and to the right of him, and facing it
	# is neither the way he rolled nor the way he faced when he started.
	var after: Vector2 = almos.position
	assert_almost_eq(almos.facing, _eight_way(after, enemy.global_position), Vector2.ONE * FACING_TOLERANCE, "he should face the target after the roll")
	assert_gt((almos.facing - Vector2.UP).length(), FACING_TOLERANCE, "he should not face the way he rolled")
	assert_gt((almos.facing - Vector2.RIGHT).length(), FACING_TOLERANCE, "he should not face the way he did before")
	assert_ne(_roll_span().x, -1, "he should have rolled")
	_assert_facing_the_target_in_every_sample(enemy)


# --- The marker ---

func test_the_marker_is_hidden_until_he_locks_on_and_hidden_again_when_he_lets_go() -> void:
	var almos = _spawn_almos()
	_place_enemy(Vector2.RIGHT, _distance())
	await _wait_frames(SETTLE_FRAMES)
	var marker := _marker(almos)
	if marker == null:
		return
	assert_false(marker.visible, "the marker should be hidden before he locks on")

	await _tap(&"lock_on")
	await _wait_frames(SETTLE_FRAMES)
	assert_true(marker.visible, "the marker should show while the lock holds")

	await _tap(&"lock_on")
	await _wait_frames(SETTLE_FRAMES)
	assert_false(marker.visible, "the marker should be hidden when he lets go")


func test_the_marker_sits_on_the_target_while_he_and_the_target_move() -> void:
	var almos = _spawn_almos()
	var enemy := _place_enemy(Vector2.RIGHT, _distance())
	await _lock_on()
	var marker := _marker(almos)
	if marker == null:
		return
	assert_almost_eq(marker.global_position, enemy.global_position, Vector2.ONE * POSITION_TOLERANCE, "the marker should sit on the target")

	_almos_input.press_action(&"move_down")
	await _wait_frames(_frames_for(MOVING_SECONDS))
	enemy.global_position += Vector2.UP * _distance() / 4.0
	await _wait_frames(SETTLE_FRAMES)

	assert_true(marker.visible, "the marker should still show")
	assert_almost_eq(marker.global_position, enemy.global_position, Vector2.ONE * POSITION_TOLERANCE, "the marker should stay on the target, wherever he and it have gone")


# --- Helpers ---

func _spawn_almos(tuning: PlayerTuning = null):
	_almos = _almos_input.spawn_almos(tuning)
	_samples.clear()
	get_tree().physics_frame.connect(_take_sample)
	return _almos


# A stand-in enemy this far from Almos in this direction. The test frees it. It is put in
# place before it enters the tree.
func _place_enemy(direction: Vector2, distance: float) -> StandInEnemy:
	var enemy := StandInEnemy.new()
	enemy.position = _almos.global_position + direction * distance
	add_child_autofree(enemy)
	return enemy


# Taken at the start of each physics frame, before anything has moved in it, so it shows
# how that frame's predecessor left things.
func _take_sample() -> void:
	if not is_instance_valid(_almos):
		return
	_samples.append({
		"position": _almos.position,
		"facing": _almos.facing,
		"locked": _almos.locked_on,
		"rolling": _almos.rolling,
		"sprinting": _almos.sprinting,
		"stamina": _almos.stamina.current,
	})


func _stop_sampling() -> void:
	if get_tree().physics_frame.is_connected(_take_sample):
		get_tree().physics_frame.disconnect(_take_sample)


func _tuning() -> PlayerTuning:
	var tuning := load(TUNING_PATH) as PlayerTuning
	assert_not_null(tuning, "the player tuning data file should load")
	return tuning


func _range() -> float:
	return _tuning().lock_on_range


func _break_range() -> float:
	return _tuning().lock_on_break_range


# How far from him a test stands a target when the amount does not matter: well within the
# range that picks it, and with room to walk away from it before the lock breaks.
func _distance() -> float:
	return _range() / 2.0


func _frame_seconds() -> float:
	return 1.0 / Engine.physics_ticks_per_second


# How many physics frames it takes to reach this many seconds.
func _frames_for(seconds: float) -> int:
	return ceili(seconds * Engine.physics_ticks_per_second)


# Waits this many physics frames. It waits on the physics_frame signal, which comes before
# Almos is processed in a frame, so whatever the test does next is seen by the very next
# frame to be processed.
func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# Presses this button and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Taps the Lock-on button and lets it settle.
func _lock_on() -> void:
	await _tap(&"lock_on")
	await _wait_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should have locked on")


# From now on, in every frame, pushes the stick straight across the line from this enemy to
# him, a quarter turn one way (turn 1) or the other (-1) from the way he is from it. The
# frame the test resumes in is steered too.
func _steer_round(enemy: Node2D, turn: float) -> void:
	_steering_round = enemy
	_steering_turn = turn
	get_tree().physics_frame.connect(_steer_across_the_line)
	_steer_across_the_line()


# Runs on the physics_frame signal, which comes before Almos is processed in a frame, so he
# is steered by where he stands at the start of the frame.
func _steer_across_the_line() -> void:
	if not is_instance_valid(_almos) or not is_instance_valid(_steering_round):
		return
	var outward := (_almos.position - _steering_round.global_position).normalized()
	_hold_stick(outward.rotated(_steering_turn * PI / 2.0))


func _stop_steering() -> void:
	if get_tree().physics_frame.is_connected(_steer_across_the_line):
		get_tree().physics_frame.disconnect(_steer_across_the_line)
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	_steering_round = null


# Pushes the stick this way, to this strength, until it is pushed another way: each of the
# four move actions is pressed to the part of the vector that points its way, or let go if
# none does. It is run on the physics_frame signal or from a test resumed by it, which comes
# before Almos is processed in a frame, so the very next frame sees it.
func _hold_stick(stick: Vector2) -> void:
	_set_strength(&"move_left", -stick.x)
	_set_strength(&"move_right", stick.x)
	_set_strength(&"move_up", -stick.y)
	_set_strength(&"move_down", stick.y)


# Presses this action to this strength, or lets it go if there is none.
func _set_strength(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


# The nearest of the eight compass directions to the one from here to there.
func _eight_way(from: Vector2, to: Vector2) -> Vector2:
	return Vector2.from_angle(snappedf(from.direction_to(to).angle(), FACING_STEP))


# While the lock held, the facing in every sample was the nearest of eight directions to the
# target, seen from where he stood in that sample: it is worked out at the end of each frame.
func _assert_facing_the_target_in_every_sample(target: Node2D) -> void:
	var seen := 0
	for i in _samples.size():
		if _samples[i].locked:
			seen += 1
			assert_almost_eq(_samples[i].facing, _eight_way(_samples[i].position, target.global_position), Vector2.ONE * FACING_TOLERANCE, "his facing in sample %d" % i)
	assert_gt(seen, 0, "he should have been locked on in some samples")


# The index of the sample taken at the start of the frame a test has just resumed in. What
# the test does now is seen by that frame, so it is the first that can move him.
func _this_frame() -> int:
	return _samples.size() - 1


# The index of the first frame, from this one on, that moved him, or -1.
func _first_moving_frame(from_index: int) -> int:
	for j in range(from_index, _samples.size() - 1):
		if _samples[j + 1].position.distance_to(_samples[j].position) > POSITION_TOLERANCE:
			return j
	return -1


# The part of this unit direction along the line from the target to where he stood in this
# sample (positive is away from the target) and the part across it (positive is a quarter
# turn on from the way away), as Vector2(along, across).
func _split_at(index: int, center: Vector2, direction: Vector2) -> Vector2:
	var outward: Vector2 = (_samples[index].position - center).normalized()
	return Vector2(direction.dot(outward), direction.dot(outward.rotated(PI / 2.0)))


# What the frame that moved him from sample j to sample j + 1 did, as Vector2(along, across):
# how much farther from the target it took him and how far round it took him, each as a share
# of a full walking step.
func _moved_split(center: Vector2, j: int) -> Vector2:
	var from: Vector2 = _samples[j].position - center
	var to: Vector2 = _samples[j + 1].position - center
	var step := _tuning().walk_speed * _frame_seconds()
	return Vector2(to.length() - from.length(), from.angle_to(to) * from.length()) / step


# Checks that every frame from sample from_index on moved him by this split.
func _assert_split_kept(center: Vector2, from_index: int, expected: Vector2, what: String) -> void:
	for j in range(from_index, _samples.size() - 1):
		assert_almost_eq(_moved_split(center, j), expected, Vector2.ONE * SPLIT_TOLERANCE, "%s in frame %d, as a share of a step along the line and across it" % [what, j])


# The signed angle, in radians, that going round this centre sweeps in all, from this sample
# to the last.
func _total_angle_round(center: Vector2, from_index: int) -> float:
	var total := 0.0
	for j in range(from_index, _samples.size() - 1):
		total += (_samples[j].position - center).angle_to(_samples[j + 1].position - center)
	return total


# The index of the first frame, from this one on, that the lock held in, or -1.
func _first_locked_frame(from_index: int) -> int:
	for j in range(from_index, _samples.size() - 1):
		if _samples[j + 1].locked:
			return j
	return -1


# Loses the lock in the way asked for, and lets it settle.
func _lose_the_lock(how: String, enemy: Node2D) -> void:
	match how:
		"the button":
			await _tap(&"lock_on")
		"the target's death":
			enemy.died.emit()
		"the break range":
			enemy.global_position = _almos.global_position + Vector2.UP * (_break_range() + RANGE_MARGIN)
	await _wait_frames(SETTLE_FRAMES)
	assert_false(_almos.locked_on, "the lock should have been lost")


# The signed angle, in radians, that going from the first position to the second sweeps
# round this centre.
func _angle_round(center: Vector2, from: Vector2, to: Vector2) -> float:
	return (from - center).angle_to(to - center)


# How fast he went round this centre in the frame that moved him from sample j to sample
# j + 1, in pixels per second: the length of the arc through his positions, not the chord.
func _speed_round(center: Vector2, j: int) -> float:
	var from: Vector2 = _samples[j].position - center
	var to: Vector2 = _samples[j + 1].position - center
	return absf(from.angle_to(to)) * from.length() / _frame_seconds()


# The index of the first sample in which this state was true, or -1.
func _first_sample_where(state: String) -> int:
	for i in _samples.size():
		if _samples[i][state]:
			return i
	return -1


# How far, in radians, the sword is turned from this angle.
func _sword_angle_off(almos: Node2D, angle: float) -> float:
	var sword := almos.get_node("Sword") as Node2D
	return angle_difference(sword.rotation, angle)


func _marker(almos: Node) -> Node2D:
	var marker := almos.find_child("LockOnMarker", true, false) as Node2D
	assert_not_null(marker, "Almos should have a LockOnMarker")
	return marker


# The first stretch of samples in which Almos was rolling, as Vector2i(first, end): the
# index of the first sample showing him rolling and of the first showing him done. Either
# is -1 if it has not happened yet.
func _roll_span() -> Vector2i:
	var first := -1
	for i in _samples.size():
		if first == -1 and _samples[i].rolling:
			first = i
		elif first != -1 and not _samples[i].rolling:
			return Vector2i(first, i)
	return Vector2i(first, -1)


func _wait_for_the_roll_to_finish() -> void:
	for i in WAIT_FRAME_LIMIT:
		if _roll_span().y != -1:
			return
		await get_tree().physics_frame
	fail_test("the roll should have started and finished")


# How far the roll carried him: from where he stood just before it began to where he stood
# at the last sample that still showed him rolling.
func _roll_displacement() -> Vector2:
	var span := _roll_span()
	if span.x < 1 or span.y == -1:
		return Vector2.INF
	return _samples[span.y - 1].position - _samples[span.x - 1].position
