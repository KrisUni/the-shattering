extends GutTest
## Almos walking, seen only through the scene: input goes in as actions or real
## input events, and we watch where he ends up.

const ALMOS_SCENE_PATH := "res://scenes/almos/almos.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"

# Frames to let a pressed input reach Almos before we start measuring.
const SETTLE_FRAMES := 2
const MEASURED_FRAMES := 5
# In pixels per second.
const TOLERANCE := 0.01
# Facing is a unit vector, so it needs a much tighter tolerance than pixels per second.
const FACING_TOLERANCE := 0.0001

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
		[JOY_BUTTON_DPAD_UP, Vector2.UP], [JOY_BUTTON_DPAD_DOWN, Vector2.DOWN],
	],
)

var _held_actions: Array[StringName] = []
var _held_events: Array[InputEvent] = []


func after_each() -> void:
	_release_everything()


func test_pressing_move_right_walks_right_at_walk_speed() -> void:
	var almos = _spawn_almos()

	_press_action(&"move_right")
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2(_walk_speed(), 0.0), Vector2.ONE * TOLERANCE)


func test_wasd_and_arrow_keys_walk_in_their_direction(params = use_parameters(key_params)) -> void:
	var almos = _spawn_almos()

	_press_key(params.key)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, params.direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_left_stick_walks_in_the_direction_it_is_pushed(direction = use_parameters(stick_directions)) -> void:
	var almos = _spawn_almos()

	_push_left_stick(direction)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_left_stick_pushed_between_axes_walks_that_way_at_full_speed(degrees = use_parameters(stick_angles)) -> void:
	var almos = _spawn_almos()
	var direction := Vector2.from_angle(deg_to_rad(degrees))

	_push_left_stick(direction)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_dpad_walks_in_its_direction(params = use_parameters(dpad_params)) -> void:
	var almos = _spawn_almos()

	_press_dpad(params.button)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, params.direction * _walk_speed(), Vector2.ONE * TOLERANCE)


func test_walking_diagonally_is_no_faster_than_walking_straight() -> void:
	var almos = _spawn_almos()

	_press_key(KEY_W)
	_press_key(KEY_D)
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity.length(), _walk_speed(), TOLERANCE, "diagonal speed should equal walk_speed")
	assert_almost_eq(velocity.normalized(), Vector2(1.0, -1.0).normalized(), Vector2.ONE * FACING_TOLERANCE, "should go up and right")


func test_after_walking_down_left_and_stopping_almos_stands_still_facing_down_left() -> void:
	var almos = _spawn_almos()

	_press_key(KEY_S)
	_press_key(KEY_A)
	await wait_physics_frames(SETTLE_FRAMES)
	_release_everything()
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2.ZERO, Vector2.ONE * TOLERANCE, "should stand still without input")
	assert_almost_eq(almos.facing, Vector2(-1.0, 1.0).normalized(), Vector2.ONE * FACING_TOLERANCE)


func test_facing_is_the_nearest_of_eight_directions_to_where_he_walks(params = use_parameters(facing_params)) -> void:
	var almos = _spawn_almos()

	_push_left_stick(Vector2.from_angle(deg_to_rad(params.stick_degrees)))
	await wait_physics_frames(SETTLE_FRAMES)

	var expected := Vector2.from_angle(deg_to_rad(params.facing_degrees))
	assert_almost_eq(almos.facing, expected, Vector2.ONE * FACING_TOLERANCE)


func test_a_stick_resting_slightly_off_centre_does_not_move_him() -> void:
	var almos = _spawn_almos()

	_push_left_stick(Vector2(0.1, 0.05))
	var velocity: Vector2 = await _measured_velocity(almos)

	assert_almost_eq(velocity, Vector2.ZERO, Vector2.ONE * TOLERANCE)


func _spawn_almos():
	var scene := load(ALMOS_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the Almos scene should load")
	var almos = scene.instantiate()
	add_child_autofree(almos)
	return almos


func _press_action(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)


# A key event as the keyboard delivers it: with the key's character and its position on
# the keyboard both set, so bindings by either would match.
func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	_held_events.append(event)


# A pad on the first device, with the stick pushed to the given (x, y) in -1..1, down being +y.
func _push_left_stick(pushed: Vector2) -> void:
	for axis_and_value in [[JOY_AXIS_LEFT_X, pushed.x], [JOY_AXIS_LEFT_Y, pushed.y]]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis_and_value[0]
		event.axis_value = axis_and_value[1]
		Input.parse_input_event(event)
		_held_events.append(event)


func _press_dpad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	_held_events.append(event)


func _release_everything() -> void:
	for action in _held_actions:
		Input.action_release(action)
	_held_actions.clear()
	for event in _held_events:
		var release := event.duplicate() as InputEvent
		if release is InputEventJoypadMotion:
			release.axis_value = 0.0
		else:
			release.pressed = false
		Input.parse_input_event(release)
	_held_events.clear()
	Input.flush_buffered_events()


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
