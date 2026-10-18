extends GutTest
## A switch pressed in a swing is made as the swing ends, ahead of a Light attack press kept for
## that frame, so when that press becomes the Critical hit at a broken enemy it is made with the
## Weapon switched to: its damage is that Weapon's critical_attack. The real Almos and the real
## training enemy run with their shipped numbers; the Break is brought on by a stand-in Hitbox.
## Every expected number comes from the Weapons' and the enemy's data files.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AttackRig := preload("res://test/helpers/attack_rig.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const SPEAR_PATH := "res://data/spear.tres"

# In Health points and Stagger. Hits and hit points are compared to this.
const TOLERANCE := 0.0001
# In pixels. Where the enemy waits, far from Almos, and how far below Almos it is put when the
# Critical hit is to reach it: inside the range of both Weapons' Critical hits and their reach.
const FAR_AWAY := Vector2(0.0, 400.0)
const ENEMY_DISTANCE := 30.0
# In pixels. How far beyond the enemy's notice range the stand-in it goes after stands, so that
# it goes nowhere.
const BEYOND_NOTICE := 50.0
# In pixels. A Hitbox this wide covers the enemy it is put over, and no other.
const NARROW_HITBOX_RADIUS := 12.0
# In physics frames. A button pressed this long is a tap, far shorter than a swing.
const TAP_FRAMES := 3
const SETTLE_FRAMES := 3
const WAIT_FRAME_LIMIT := 400

var _almos_input: AlmosInput
var _attack_rig: AttackRig
var _enemy_rig: EnemyRig


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first
	# processed after the first sample and what it presses is seen from the next frame.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_attack_rig = AttackRig.new(self)
	_enemy_rig = EnemyRig.new(self)


func after_each() -> void:
	_attack_rig.stop_sampling()
	_enemy_rig.stop_sampling()
	_almos_input.release_everything()


func test_the_critical_hit_made_after_a_waiting_switch_hurts_as_the_new_weapons_does() -> void:
	var sword := load(AlmosInput.WEAPON_PATH) as WeaponData
	var spear := load(SPEAR_PATH) as WeaponData
	assert_ne(sword.critical_attack.damage, spear.critical_attack.damage, "the Weapons should hurt differently, so that the one swinging shows")
	var tuning := _enemy_rig.tuning_with()
	var almos = _attack_rig.spawn_almos(_almos_input)
	almos.weapons.pick_up(spear)
	var enemy = _enemy_rig.spawn_enemy(tuning, FAR_AWAY)
	_enemy_rig.place_target(enemy.position + Vector2.DOWN * (tuning.notice_range + BEYOND_NOTICE))
	await _attack_rig.wait_frames(SETTLE_FRAMES)
	await _break(enemy, tuning)

	await _tap(&"attack_light")
	await _attack_rig.wait_to_press_for_swing_frame(TAP_FRAMES + 2)
	await _tap(&"switch_weapon")
	await _attack_rig.wait_to_press_for_swing_frame(_swing_frames(sword) - sword.attack_buffer_frames)
	# It comes into range after the first swing has begun, before the press is made.
	enemy.global_position = almos.global_position + Vector2.DOWN * ENEMY_DISTANCE
	await _tap(&"attack_light")
	await _wait_for_the_swings_to_end(almos)

	assert_true(enemy.health.current < tuning.health_maximum, "the Critical hit should have landed")
	assert_almost_eq(enemy.health.current, tuning.health_maximum - spear.critical_attack.damage, TOLERANCE, "Health left after the Critical hit")


# Breaks the enemy with a hit from a stand-in that builds a full meter, in front of it.
func _break(enemy, tuning: EnemyTuning) -> void:
	var hitbox := _enemy_rig.hitbox_over(enemy, 0.0, "enemy_hurtbox")
	((hitbox.get_child(0) as CollisionShape2D).shape as CircleShape2D).radius = NARROW_HITBOX_RADIUS
	hitbox.global_position = enemy.global_position + Vector2.DOWN * NARROW_HITBOX_RADIUS
	hitbox.stagger = tuning.stagger_capacity
	# Settled in the physics server before it is switched on.
	await _enemy_rig.wait_frames(SETTLE_FRAMES)
	await _enemy_rig.swing(hitbox, 1)
	assert_true(enemy.broken, "the hit should have broken it")


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _attack_rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _swing_frames(weapon: WeaponData) -> int:
	var swing := weapon.light_attacks[0]
	return swing.startup_frames + swing.active_frames + swing.recovery_frames


func _wait_for_the_swings_to_end(almos) -> void:
	await _attack_rig.wait_frames(SETTLE_FRAMES)
	for i in WAIT_FRAME_LIMIT:
		if not almos.attacking:
			return
		await get_tree().physics_frame
	fail_test("the swings should be over")
