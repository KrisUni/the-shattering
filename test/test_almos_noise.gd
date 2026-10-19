extends GutTest
## The Noise Almos makes, read from the real Almos and driven by Input actions: Sprinting,
## Rolling and any attack of his make Noise of a tuned radius, and walking, standing, Blocking
## and a Jump on its own make none. Every number is read from the tuning data file.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

# In physics frames. The most a wait for a state may take.
const WAIT_LIMIT := 120
const TAP_FRAMES := 3

var _almos_input: AlmosInput
var _almos
var _tuning: PlayerTuning


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_almos = _almos_input.spawn_almos()
	_tuning = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_the_tuned_noise_radii_are_positive() -> void:
	assert_gt(_tuning.noise_sprint_radius, 0.0)
	assert_gt(_tuning.noise_roll_radius, 0.0)
	assert_gt(_tuning.noise_attack_radius, 0.0)


func test_standing_makes_no_noise() -> void:
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)

	assert_eq(_almos.noise_radius, 0.0)


func test_walking_makes_no_noise() -> void:
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)

	assert_gt(_almos.velocity.length(), 0.0, "he should be walking")
	assert_false(_almos.sprinting)
	assert_eq(_almos.noise_radius, 0.0)


func test_blocking_makes_no_noise() -> void:
	_almos_input.press_action(&"block")
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)

	assert_true(_almos.blocking, "he should be blocking")
	assert_eq(_almos.noise_radius, 0.0)


func test_a_jump_on_its_own_makes_no_noise() -> void:
	_almos_input.press_action(&"jump")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"jump")

	assert_true(_almos.airborne, "he should be in the air")
	assert_eq(_almos.noise_radius, 0.0)


func test_sprinting_makes_the_sprint_noise() -> void:
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _wait_until(func() -> bool: return _almos.sprinting)

	assert_true(_almos.sprinting, "he should be sprinting")
	assert_eq(_almos.noise_radius, _tuning.noise_sprint_radius)


func test_rolling_makes_the_roll_noise_and_it_ends_with_the_roll() -> void:
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)
	assert_true(_almos.rolling, "he should be rolling")
	assert_eq(_almos.noise_radius, _tuning.noise_roll_radius)

	_almos_input.release_action(&"move_right")
	await _wait_until(func() -> bool: return not _almos.rolling)
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)

	assert_eq(_almos.noise_radius, 0.0, "once the Roll is over he is silent again")


func test_a_swing_makes_the_attack_noise_and_it_ends_with_the_swing() -> void:
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	assert_true(_almos.attacking, "he should be swinging")
	assert_eq(_almos.noise_radius, _tuning.noise_attack_radius)

	await _wait_until(func() -> bool: return not _almos.attacking)

	assert_eq(_almos.noise_radius, 0.0, "once the swing is over he is silent again")


func test_charging_a_heavy_attack_makes_the_attack_noise() -> void:
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(AlmosInput.SETTLE_FRAMES)

	assert_true(_almos.charging, "he should be charging")
	assert_eq(_almos.noise_radius, _tuning.noise_attack_radius)


func test_a_jump_attack_makes_the_attack_noise() -> void:
	_almos_input.press_action(&"jump")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"jump")
	_almos_input.press_action(&"attack_heavy")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_heavy")

	assert_true(_almos.jump_attacking, "he should be making a Jump attack")
	assert_eq(_almos.noise_radius, _tuning.noise_attack_radius)


func _wait_until(done: Callable) -> void:
	for i in WAIT_LIMIT:
		if done.call():
			return
		await get_tree().physics_frame
