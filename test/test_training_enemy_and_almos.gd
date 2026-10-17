extends GutTest
## The training enemy and Almos fighting, both as whole scenes. Almos is driven by real
## input; the enemy goes after him. Every physics frame a sample of the enemy and of Almos's
## Health is taken, so what happened can be read back frame by frame. Expected numbers come
## from the data files the scenes use (or a copy a test changes) and plain arithmetic, never
## from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

# In Health points.
const TOLERANCE := 0.0001
# In pixels. How far below Almos the enemy stands: close enough for each to reach the other
# with a swing, and clear of each other's bodies. Almos starts out facing down.
const ENEMY_DISTANCE := 30.0
# A tap: held this many physics frames, far shorter than a swing or a hold.
const TAP_FRAMES := 3
# How many physics frames after the enemy begins to wind up that a Roll must be tapped, at
# the latest, for his untouchable window to cover the enemy's active frames. The tap is
# held TAP_FRAMES and the Roll's window opens a few frames into it; this puts the middle of
# the window at the middle of the enemy's active frames. Worked out from the tuning data
# files, and checked by the test itself.
const ROLL_LEAD_FRAMES := 6
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 240
# The most Light swings Almos is given to kill the enemy.
const MOST_SWINGS := 10
# How many physics frames the test runs after the exchange it is about, to let it play out.
const SETTLE_FRAMES := 10

var _almos_input: AlmosInput
var _rig: EnemyRig


func before_each() -> void:
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


func test_its_hit_takes_its_damage_off_almos_health() -> void:
	var attack := _rig.tuning_with().attack
	var almos = _spawn_fight()

	await _rig.wait_frames(attack.startup_frames + attack.active_frames + SETTLE_FRAMES)

	assert_almost_eq(almos.health.current, almos.tuning.health_maximum - attack.damage, TOLERANCE)


func test_it_does_not_hit_almos_while_he_is_untouchable_in_a_roll() -> void:
	var attack := _rig.tuning_with().attack
	# A Roll that carries him nowhere, so that he stays under the swing for all of it.
	var rolling_on_the_spot := (load(AlmosInput.TUNING_PATH) as PlayerTuning).duplicate() as PlayerTuning
	rolling_on_the_spot.roll_distance = 0.0
	var almos = _spawn_fight(rolling_on_the_spot)
	_rig.sample_also("untouchable", func(): return almos.untouchable)
	await _rig.wait_frames(attack.startup_frames - ROLL_LEAD_FRAMES)

	await _tap(&"roll")
	await _rig.wait_frames(attack.active_frames + SETTLE_FRAMES)

	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its hitbox should have gone on")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].untouchable, "he should be untouchable in sample %d, in which its hitbox is on" % i)
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE)


func test_almos_light_attacks_can_kill_it() -> void:
	var sword := load(AlmosInput.WEAPON_PATH) as WeaponData
	var almos = _almos_input.spawn_almos()
	var enemy = _rig.spawn_enemy(null, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	var deaths := _rig.record_deaths()
	var health_maximum: float = enemy.health.maximum
	var swings_needed := ceili(health_maximum / sword.light_attacks[0].damage)
	await _rig.wait_frames(AlmosInput.SETTLE_FRAMES)

	var swings := 0
	while swings < MOST_SWINGS and deaths.is_empty():
		await _swing_light(almos)
		swings += 1
		if swings == 1:
			assert_almost_eq(enemy.health.current, health_maximum - sword.light_attacks[0].damage, TOLERANCE, "Health left after the first swing")

	assert_eq(deaths.size(), 1, "it should have died")
	assert_eq(swings, swings_needed, "swings it took to kill it")


func test_almos_and_it_hitting_each_other_in_the_same_frame_both_lose_health() -> void:
	var attack := _rig.tuning_with().attack
	var swing := (load(AlmosInput.WEAPON_PATH) as WeaponData).light_attacks[0]
	var almos = _spawn_fight()

	await _aim_almos_swing_at_the_first_active_frame_of_the_enemy()
	await _rig.wait_frames(attack.active_frames + SETTLE_FRAMES)

	var on_almos := _rig.hits()
	var on_enemy := _rig.drops("enemy_health")
	assert_eq(on_almos.size(), 1, "Almos should have been hit once")
	assert_eq(on_enemy.size(), 1, "it should have been hit once")
	if on_almos.size() == 1 and on_enemy.size() == 1:
		assert_eq(on_almos[0].sample, on_enemy[0].sample, "the sample showing each hit")
		assert_almost_eq(on_almos[0].damage, attack.damage, TOLERANCE)
		assert_almost_eq(on_enemy[0].damage, swing.damage, TOLERANCE)


func test_almos_killing_it_in_the_frame_it_hits_him_does_not_save_him_from_the_hit() -> void:
	var attack := _rig.tuning_with().attack
	var almos = _spawn_fight()
	var deaths := _rig.record_deaths()
	# One hit from the sword is enough.
	_rig.enemy.health.take_damage(_rig.enemy.health.maximum - 1.0)

	await _aim_almos_swing_at_the_first_active_frame_of_the_enemy()
	await _rig.wait_frames(attack.active_frames + SETTLE_FRAMES)

	assert_eq(deaths.size(), 1, "it should have died")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum - attack.damage, TOLERANCE)


# Almos in the test's scene tree with the enemy a little way below him, after him, and
# sampled. The enemy is added after him, so he is processed first in a frame. Almos is
# given this tuning if there is one.
func _spawn_fight(almos_tuning: PlayerTuning = null):
	var almos = _almos_input.spawn_almos(almos_tuning)
	_rig.spawn_enemy(null, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	return almos


# Taps the Light attack button so that Almos's swing is on for its first active frame in the
# very frame the enemy's is. The enemy begins to wind up in the first frame, so its first
# active frame comes startup_frames after that one. A press is seen by Almos a frame after
# it is made, and his swing is active startup_frames of his own after that.
func _aim_almos_swing_at_the_first_active_frame_of_the_enemy() -> void:
	var swing := (load(AlmosInput.WEAPON_PATH) as WeaponData).light_attacks[0]
	var attack := _rig.tuning_with().attack
	await _rig.wait_frames(attack.startup_frames - swing.startup_frames)
	await _tap(&"attack_light")


# Presses this button and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Taps the Light attack button and waits for the swing it starts to be over.
func _swing_light(almos) -> void:
	await _tap(&"attack_light")
	for i in WAIT_FRAME_LIMIT:
		if not almos.attacking:
			return
		await get_tree().physics_frame
	fail_test("the swing should be over")
