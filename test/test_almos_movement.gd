extends GutTest
## Almos walking, seen only through the scene: input goes in as actions or real
## input events, and we watch where he ends up.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TUNING_PATH := AlmosInput.TUNING_PATH
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
const MEASURED_FRAMES := AlmosInput.MEASURED_FRAMES
const FACING_TOLERANCE := AlmosInput.FACING_TOLERANCE
# In pixels per second.
const TOLERANCE := 0.01

var key_params = ParameterFactory.named_parameters(
	["key", "direction"],
	[
		[KEY_A, Vector2.LEFT], [KEY_LEFT, Vector2.LEFT],
		[KEY_D, Vector2.RIGHT], [KEY_RIGHT, Vector2.RIGHT],
		[KEY_W, Vector2.UP], [KEY_UP, Vector2.UP],
		[KEY_S, Vector2.DOWN], [KEY_DOWN, Vector2.DOWN],
	],
)

var stick_directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

# Degrees clockwise from right, none of them along an axis.
var stick_angles = [30.0, 135.0, 250.0]

# Stick angles and the one of the eight compass directions nearest to each, in degrees
# clockwise from right. The 40, 200 and 290 degree rows would be wrong if the angle were
# truncated instead of rounded.
var facing_params = ParameterFactory.named_parameters(
	["stick_degrees", "facing_degrees"],
	[[20.0, 0.0], [40.0, 45.0], [100.0, 90.0], [200.0, 180.0], [290.0, 270.0]],
)

var dpad_params = ParameterFactory.named_parameters(
	["button", "direction"],
	[
		[JOY_BUTTON_DPAD_LEFT, Vector2.LEFT], [JOY_BUTTON_DPAD_RIGHT, Vector2.RIGHT],
		[JOY_BUTTON_DPAD_DOWN, Vector2.DOWN],
	],
)

var _almos_input: AlmosInput


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func test_pressing_move_right_walks_right_at_walk_speed() -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.press_action(&"move_right")
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2(_walk_speed(), 0.0), Vector2.ONE * TOLERANCE)


func test_wasd_and_arrow_keys_walk_in_their_direction(params = use_parameters(key_params)) -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.press_key(params.key)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, params.direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_left_stick_walks_in_the_direction_it_is_pushed(direction = use_parameters(stick_directions)) -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.push_left_stick(direction)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_left_stick_pushed_between_axes_walks_that_way_at_full_speed(degrees = use_parameters(stick_angles)) -> void:
	var almos = _almos_input.spawn_almos()
	var direction := Vector2.from_angle(deg_to_rad(degrees))

	_almos_input.push_left_stick(direction)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_dpad_walks_in_its_direction(params = use_parameters(dpad_params)) -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.press_joypad_button(params.button)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, params.direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_dpad_up_does_not_walk_because_it_switches_the_spell() -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.press_joypad_button(JOY_BUTTON_DPAD_UP)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2.ZERO, Vector2.ONE * TOLERANCE)


func test_walking_diagonally_is_no_faster_than_walking_straight() -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.press_key(KEY_W)
	_almos_input.press_key(KEY_D)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity.length(), _walk_speed(), TOLERANCE, "diagonal speed should equal walk_speed")
	assert_almost_eq(velocity.normalized(), Vector2(1.0, -1.0).normalized(), Vector2.ONE * FACING_TOLERANCE, "should go up and right")


func test_after_walking_down_left_and_stopping_almos_stands_still_facing_down_left() -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.press_key(KEY_S)
	_almos_input.press_key(KEY_A)
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.release_everything()
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2.ZERO, Vector2.ONE * TOLERANCE, "should stand still without input")
	assert_almost_eq(almos.facing, Vector2(-1.0, 1.0).normalized(), Vector2.ONE * FACING_TOLERANCE)


func test_facing_is_the_nearest_of_eight_directions_to_where_he_walks(params = use_parameters(facing_params)) -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.push_left_stick(Vector2.from_angle(deg_to_rad(params.stick_degrees)))
	await wait_physics_frames(SETTLE_FRAMES)

	var expected := Vector2.from_angle(deg_to_rad(params.facing_degrees))
	assert_almost_eq(almos.facing, expected, Vector2.ONE * FACING_TOLERANCE)


func test_a_stick_resting_slightly_off_centre_does_not_move_him() -> void:
	var almos = _almos_input.spawn_almos()

	_almos_input.push_left_stick(Vector2(0.1, 0.05))
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2.ZERO, Vector2.ONE * TOLERANCE)


# Almos's average velocity over a few physics frames, worked out from where he ends up
# rather than read from his velocity property. The elapsed frames come from the engine's
# own counter, because waiting for N frames can span N + 1 physics steps.
func _measured_velocity(almos: Node2D) -> Vector2:
	await wait_physics_frames(SETTLE_FRAMES)
	var start_position := almos.position
	var start_frame := Engine.get_physics_frames()
	await wait_physics_frames(MEASURED_FRAMES)
	var seconds := float(Engine.get_physics_frames() - start_frame) / Engine.physics_ticks_per_second
	return (almos.position - start_position) / seconds


func _walk_speed() -> float:
	var tuning = load(TUNING_PATH)
	assert_not_null(tuning, "the player tuning data file should load")
	if tuning == null:
		return 0.0
	assert_gt(tuning.walk_speed, 0.0, "walk_speed in the data file should be positive")
	return tuning.walk_speed
