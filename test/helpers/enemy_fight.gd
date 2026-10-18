extends RefCounted
## Almos facing the training enemy, for the tests that have him Parry its swing or stand
## above it without it swinging at him. It lives under test/helpers without the test_ prefix,
## so GUT does not collect it as a test. It works on an AlmosInput and an EnemyRig the test
## has made.

# In pixels. How far below Almos the enemy stands.
const ENEMY_DISTANCE := 30.0
# In pixels. How far past the enemy's notice range a stand-in is put.
const BEYOND_NOTICE := 50.0
const TOLERANCE := 0.0001
# In physics frames. How long the Parry button is held for a tap.
const TAP_FRAMES := 3
const SETTLE_FRAMES := 3
const WAIT_FRAME_LIMIT := 400

var _test: GutTest
var _almos_input
var _rig


func _init(test: GutTest, almos_input, rig) -> void:
	_test = test
	_almos_input = almos_input
	_rig = rig


## Almos at the origin facing down with the enemy below him, going after a stand-in too far
## off to notice, so that the enemy never swings at Almos. The stand-in is below it if the
## enemy has its back to Almos, and above it, in Almos's direction, if it faces him. Almos
## has this tuning if one is given.
func spawn_almos_above_the_enemy(enemy_has_its_back_to_him: bool, tuning: PlayerTuning = null):
	var almos = _almos_input.spawn_almos(tuning)
	var enemy = _rig.spawn_enemy(null, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	var away := Vector2.DOWN if enemy_has_its_back_to_him else Vector2.UP
	_rig.place_target(enemy.position + away * (enemy.tuning.notice_range + BEYOND_NOTICE))
	return almos


## Parries the swing the enemy is about to make or has begun, with the Parry of this tuning.
## The press is timed so that the window is open over the middle of the enemy's active
## frames. Returns once the hit has been parried and Almos is free.
func parry_the_swing(player: PlayerTuning) -> void:
	var swing: AttackData = _rig.enemy.tuning.attack
	# The wind-up has been seen to begin: the enemy's first frame has been processed. The
	# window opens in the frame the press is seen in, and is open for parry_window_frames.
	for i in WAIT_FRAME_LIMIT:
		if _rig.enemy.winding_up:
			break
		await _test.get_tree().physics_frame
	_test.assert_true(_rig.enemy.winding_up, "the enemy should begin a swing")
	await _rig.wait_frames(swing.startup_frames - player.parry_window_frames / 2 - 1)
	var health_before: float = _rig.target_health.current
	_almos_input.press_action(&"parry")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"parry")
	await _rig.wait_frames(player.parry_window_frames + SETTLE_FRAMES)
	_test.assert_almost_eq(_rig.target_health.current, health_before, TOLERANCE, "the swing should have been parried, not landed")
