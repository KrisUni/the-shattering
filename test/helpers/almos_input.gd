extends RefCounted
## What the Almos tests share: spawning him, and driving him with input, pressed either as
## actions or as real input events. It remembers what it pressed so that
## release_everything can undo all of it. It lives under test/helpers without the test_
## prefix, so GUT does not collect it as a test.

const ALMOS_SCENE_PATH := "res://scenes/almos/almos.tscn"
const TUNING_PATH := "res://data/player_tuning.tres"
const WEAPON_PATH := "res://data/sword.tres"

# Frames to let a pressed input reach Almos before we start measuring.
const SETTLE_FRAMES := 2
# How many physics frames a speed is measured over.
const MEASURED_FRAMES := 5
# Facing is a unit vector, so it needs a much tighter tolerance than pixels or pixels per
# second.
const FACING_TOLERANCE := 0.0001

var _test: GutTest
var _held_actions: Array[StringName] = []
var _held_events: Array[InputEvent] = []


func _init(test: GutTest) -> void:
	_test = test


# Almos in the test's scene tree, given this tuning and this weapon data if there are any.
# The test frees him.
func spawn_almos(tuning: PlayerTuning = null, weapon: WeaponData = null):
	var scene := load(ALMOS_SCENE_PATH) as PackedScene
	_test.assert_not_null(scene, "the Almos scene should load")
	var almos = scene.instantiate()
	if tuning != null:
		almos.tuning = tuning
	if weapon != null:
		almos.weapon = weapon
	_test.add_child_autofree(almos)
	return almos


func press_action(action: StringName) -> void:
	Input.action_press(action)
	_held_actions.append(action)


func release_action(action: StringName) -> void:
	Input.action_release(action)
	_held_actions.erase(action)


# A key event as the keyboard delivers it: with the key's character and its position on
# the keyboard both set, so bindings by either would match. An event left to itself is
# taken in at the start of the next frame of the main loop, which can be after several
# physics frames; at_once takes it in now, so that exactly the physics frames processed
# from here on see it, as a real tap between two physics frames would be seen.
func press_key(keycode: Key, at_once := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	if at_once:
		Input.flush_buffered_events()
	_held_events.append(event)


# Lets go of a key pressed with press_key, as the keyboard does. at_once is as for
# press_key.
func release_key(keycode: Key, at_once := false) -> void:
	for event in _held_events:
		var pressed := event as InputEventKey
		if pressed != null and pressed.keycode == keycode:
			var release := pressed.duplicate() as InputEventKey
			release.pressed = false
			Input.parse_input_event(release)
			if at_once:
				Input.flush_buffered_events()
			_held_events.erase(event)
			return


# A pad on the first device, with the stick pushed to the given (x, y) in -1..1, down being +y.
func push_left_stick(pushed: Vector2) -> void:
	for axis_and_value in [[JOY_AXIS_LEFT_X, pushed.x], [JOY_AXIS_LEFT_Y, pushed.y]]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis_and_value[0]
		event.axis_value = axis_and_value[1]
		Input.parse_input_event(event)
		_held_events.append(event)


# A button on a pad on the first device, the d-pad's included.
func press_joypad_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	_held_events.append(event)


# A mouse button, pressed with the pointer at the top left of the window.
func press_mouse_button(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.button_mask = 1 << (button - 1)
	event.pressed = true
	Input.parse_input_event(event)
	_held_events.append(event)


# A pad on the first device, with this axis pushed to this value, such as a trigger pulled
# right in. Letting go puts it back to 0.
func push_joypad_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	_held_events.append(event)


func release_everything() -> void:
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
