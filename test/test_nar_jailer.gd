extends GutTest
## The Nar jailer, seen only through the scenes: the real enemy scene runs with the guard
## numbers set here (a copy of the training enemy's tuning with its guard turned on), and a
## Hitbox from the helpers stands in for Almos's attack, placed in front of the enemy (the way it
## faces, down) or behind it. Almos is the real scene, driven by input, where his recoil is
## concerned. Every expected number comes from the numbers set here and plain arithmetic, never
## from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AlmosHits := preload("res://test/helpers/almos_hits.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

# In Health and Stagger points.
const TOLERANCE := 0.0001
# In pixels. How far from the enemy's centre a stand-in attacker's hit comes from.
const HIT_DISTANCE := 40.0
const SETTLE_FRAMES := 3

# The guard numbers these tests set, which the data file need not share.
const SHARE := 0.25
const BLOCK_STAGGER := 12.0
const PARRY_EVERY := 3
# In Health points and Stagger points. What a stand-in hit deals and builds.
const HIT_DAMAGE := 20.0
const HIT_STAGGER := 4.0
# In physics frames. A Break far longer than any test waits, and one short enough to wait out.
const LONG_BREAK := 100000
const SHORT_BREAK := 5
# In physics frames. A Break long enough to land a few hits in.
const BREAK_WITH_ROOM := 90
const JAILER_PATH := "res://data/nar_jailer.tres"
# In pixels. How far from a jailer a target is put for it to notice him and swing: inside its
# attack range and its Sight, which points down.
const TARGET_DISTANCE := 30.0
# In pixels. How far a target is moved to be out of reach and out of Sight.
const FAR_AWAY := 500.0
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 400
# In pixels. How far below Almos the jailer stands: close enough for his sword to reach it.
const ENEMY_DISTANCE := 30.0
# A tap: held this many physics frames, far shorter than a swing or a charge.
const TAP_FRAMES := 3
# In physics frames. Enough for a Light swing to reach the jailer and the Parry to be seen.
const SWING_WAIT_FRAMES := 30
# In physics frames. How many a test goes on past the end of a recoil to see whether something
# kept from it comes out.
const PAST_THE_END_FRAMES := 10
# In pixels. A walk this short in a recoil is a walk.
const MOVED := 0.5
const SPEAR_PATH := "res://data/spear.tres"
const WEAPON_PICKUP_PATH := "res://scenes/world/weapon_pickup.tscn"
# Far more hits than any test lands, so that it never Parries.
const NEVER := 1000

# The buttons he cannot use in a recoil, and what each would show of him if it were used.
var press_params = ParameterFactory.named_parameters(
	["action", "shows"],
	[
		[&"attack_light", func(almos: Node) -> bool: return almos.attacking],
		[&"attack_heavy", func(almos: Node) -> bool: return almos.attacking or almos.charging],
		[&"roll", func(almos: Node) -> bool: return almos.rolling],
		[&"parry", func(almos: Node) -> bool: return almos.parrying],
		[&"jump", func(almos: Node) -> bool: return almos.airborne],
		[&"cast_spell", func(almos: Node) -> bool: return almos.spell.winding_up],
	],
)

var _rig: EnemyRig
var _almos_input: AlmosInput
var _hits: AlmosHits


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_rig = EnemyRig.new(self)
	_almos_input = AlmosInput.new(self)
	_hits = AlmosHits.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- Block ---

func test_a_hit_from_the_front_deals_only_the_blocked_share_of_its_damage() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER})

	await _hit(enemy, true)

	assert_almost_eq(enemy.health.current, enemy.tuning.health_maximum - HIT_DAMAGE * SHARE, TOLERANCE)


func test_a_blocked_hit_builds_its_own_stagger_and_the_block_stagger() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER})

	await _hit(enemy, true)

	assert_almost_eq(enemy.stagger.current, HIT_STAGGER + BLOCK_STAGGER, TOLERANCE)


func test_a_hit_that_builds_no_stagger_still_builds_the_block_stagger_when_blocked() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER})

	await _hit(enemy, true, HIT_DAMAGE, 0.0)

	assert_almost_eq(enemy.stagger.current, BLOCK_STAGGER, TOLERANCE)


func test_a_hit_from_behind_deals_all_its_damage_and_builds_the_behind_stagger_only() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER})

	await _hit(enemy, false)

	assert_almost_eq(enemy.health.current, enemy.tuning.health_maximum - HIT_DAMAGE, TOLERANCE, "Health left")
	assert_almost_eq(enemy.stagger.current, HIT_STAGGER + enemy.tuning.behind_stagger, TOLERANCE, "Stagger built")


func test_a_hit_while_it_swings_is_not_blocked() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER})
	_place_target_in_reach(enemy)
	await _wait_until_swinging(enemy)

	await _hit(enemy, true)

	assert_almost_eq(enemy.health.current, enemy.tuning.health_maximum - HIT_DAMAGE, TOLERANCE, "Health left")
	assert_almost_eq(enemy.stagger.current, HIT_STAGGER, TOLERANCE, "Stagger built")


func test_blocked_hits_that_fill_the_meter_break_the_enemy_and_one_fewer_does_not() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER})
	var per_hit := HIT_STAGGER + BLOCK_STAGGER
	var needed := ceili(enemy.tuning.stagger_capacity / per_hit)

	for i in needed - 1:
		await _hit(enemy, true)
	assert_false(enemy.broken, "one blocked hit fewer should not break it")
	await _hit(enemy, true)

	assert_true(enemy.broken, "the blocked hits that fill the meter should break it")


func test_a_hit_on_a_broken_jailer_lands_in_full() -> void:
	var enemy = _spawn_jailer({"parry_every": NEVER, "break_frames": LONG_BREAK})
	await _hit(enemy, true, 0.0, enemy.tuning.stagger_capacity)
	assert_true(enemy.broken, "the setup should have broken it")
	var health_before: float = enemy.health.current

	await _hit(enemy, true)

	assert_almost_eq(enemy.health.current, health_before - HIT_DAMAGE, TOLERANCE)


# --- Parry ---

func test_every_nth_hit_from_the_front_in_a_row_is_parried_and_the_others_blocked() -> void:
	var enemy = _spawn_jailer()
	var outcomes: Array[float] = []

	for i in 2 * PARRY_EVERY:
		var before: float = enemy.health.current
		await _hit(enemy, true)
		outcomes.append(before - enemy.health.current)

	var blocked := HIT_DAMAGE * SHARE
	assert_eq(outcomes.size(), 6)
	assert_almost_eq(outcomes[0], blocked, TOLERANCE, "first hit")
	assert_almost_eq(outcomes[1], blocked, TOLERANCE, "second hit")
	assert_almost_eq(outcomes[2], 0.0, TOLERANCE, "third hit, parried")
	assert_almost_eq(outcomes[3], blocked, TOLERANCE, "fourth hit")
	assert_almost_eq(outcomes[4], blocked, TOLERANCE, "fifth hit")
	assert_almost_eq(outcomes[5], 0.0, TOLERANCE, "sixth hit, parried")


func test_a_parried_hit_builds_no_stagger_on_the_jailer() -> void:
	var enemy = _spawn_jailer({"parry_every": 1})

	await _hit(enemy, true)

	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE)


func test_a_parried_hit_is_reported_to_the_attacker_as_parried() -> void:
	var enemy = _spawn_jailer({"parry_every": 1})
	var hitbox := _rig.hitbox_over(enemy, HIT_DAMAGE, "enemy_hurtbox")
	hitbox.global_position = enemy.global_position + Vector2.DOWN * HIT_DISTANCE
	var parried := []
	hitbox.parried.connect(func(hurtbox: Hurtbox) -> void: parried.append(hurtbox))
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)

	assert_eq(parried.size(), 1)


func test_hits_from_behind_do_not_count_toward_the_parry() -> void:
	var enemy = _spawn_jailer()
	for i in PARRY_EVERY - 1:
		await _hit(enemy, true)
	for i in PARRY_EVERY:
		await _hit(enemy, false)
	var before: float = enemy.health.current

	await _hit(enemy, true)

	assert_almost_eq(before - enemy.health.current, 0.0, TOLERANCE, "the hit from the front that makes the Nth should be parried")


func test_a_hit_from_behind_is_never_parried() -> void:
	var enemy = _spawn_jailer({"parry_every": 1})

	await _hit(enemy, false)

	assert_almost_eq(enemy.health.current, enemy.tuning.health_maximum - HIT_DAMAGE, TOLERANCE)


func test_a_hit_that_finds_it_swinging_does_not_count_toward_the_parry() -> void:
	var enemy = _spawn_jailer()
	var target := _place_target_in_reach(enemy)
	await _wait_until_swinging(enemy)
	for i in PARRY_EVERY:
		await _hit(enemy, true)
	assert_true(enemy.attacking, "the setup should still have it swinging")
	# Out of its reach, so that it does not go on to swing again as this swing ends.
	target.global_position += Vector2.DOWN * FAR_AWAY
	await _wait_until_free(enemy)
	for i in PARRY_EVERY - 1:
		await _hit(enemy, true)
	var before: float = enemy.health.current

	await _hit(enemy, true)

	assert_almost_eq(before - enemy.health.current, 0.0, TOLERANCE, "the Nth hit it guarded against should be parried")


func test_a_break_starts_the_count_toward_the_parry_again() -> void:
	var enemy = _spawn_jailer({"break_frames": SHORT_BREAK})
	# It only comes out of a Break while it has a target.
	_rig.place_target(enemy.global_position + Vector2.DOWN * FAR_AWAY)
	for i in PARRY_EVERY - 1:
		await _hit(enemy, true)
	await _hit(enemy, false, 0.0, enemy.tuning.stagger_capacity)
	assert_true(enemy.broken, "the setup should have broken it")
	await _rig.wait_frames(SHORT_BREAK + SETTLE_FRAMES)
	assert_false(enemy.broken, "the Break should be over")
	var before: float = enemy.health.current

	await _hit(enemy, true)

	assert_almost_eq(before - enemy.health.current, HIT_DAMAGE * SHARE, TOLERANCE, "the first hit after the Break should be blocked, not parried")


func test_hits_that_land_in_a_break_do_not_count_toward_the_parry() -> void:
	var enemy = _spawn_jailer({"break_frames": BREAK_WITH_ROOM})
	# It only comes out of a Break while it has a target.
	_rig.place_target(enemy.global_position + Vector2.DOWN * FAR_AWAY)
	await _hit(enemy, false, 0.0, enemy.tuning.stagger_capacity)
	assert_true(enemy.broken, "the setup should have broken it")
	for i in PARRY_EVERY - 1:
		await _hit(enemy, true, 0.0, 0.0)
	assert_true(enemy.broken, "the hits should have landed inside the Break")
	await _rig.wait_frames(BREAK_WITH_ROOM)
	assert_false(enemy.broken, "the Break should be over")
	var before: float = enemy.health.current

	await _hit(enemy, true)

	assert_almost_eq(before - enemy.health.current, HIT_DAMAGE * SHARE, TOLERANCE, "the first hit after the Break should be blocked, not parried")


# --- Enemies that do not guard ---

func test_an_enemy_that_does_not_guard_takes_every_hit_as_it_lands() -> void:
	var enemy = _rig.spawn_enemy(_rig.tuning_with())
	enemy.post_facing = Vector2.DOWN

	for i in 4:
		await _hit(enemy, true)

	assert_almost_eq(enemy.health.current, enemy.tuning.health_maximum - 4 * HIT_DAMAGE, TOLERANCE, "Health left")
	assert_almost_eq(enemy.stagger.current, 4 * HIT_STAGGER, TOLERANCE, "Stagger built")


func test_the_nar_jailers_data_file_makes_it_guard() -> void:
	var loaded := load(JAILER_PATH) as EnemyTuning
	assert_not_null(loaded, "the Nar jailer's data file should load")
	if loaded == null:
		return
	assert_true(loaded.guards)
	assert_gt(loaded.parry_every, 1, "it should Block more than it Parries")
	assert_gt(loaded.block_damage_share, 0.0, "a Blocked hit should still hurt")
	assert_lt(loaded.block_damage_share, 1.0, "Blocking should take something off")


# --- Almos recoils ---

func test_almos_recoils_for_the_tuned_frames_when_a_jailer_parries_his_swing() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	var frames: int = almos.tuning.parried_recoil_frames

	await _tap(&"attack_light")
	await _rig.wait_frames(SWING_WAIT_FRAMES + frames)

	var span := _span("recoiling")
	assert_ne(span.x, -1, "he should recoil")
	assert_eq(span.y - span.x, frames, "frames it lasts")


func test_the_swing_that_was_parried_is_over_at_once() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	_rig.sample_also("attacking", func() -> bool: return almos.attacking)

	await _tap(&"attack_light")
	await _rig.wait_frames(SWING_WAIT_FRAMES)

	var first := _rig.first_sample_where("recoiling")
	assert_ne(first, -1, "he should recoil")
	assert_false(_rig.samples[first].attacking, "the swing should be over in the first sample that shows the recoil")


func test_a_press_in_a_recoil_is_lost(params = use_parameters(press_params)) -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	_rig.sample_also("shows", func() -> bool: return params.shows.call(almos))
	await _tap(&"attack_light")
	await _wait_until_recoiling(almos)

	await _tap(params.action)
	await _rig.wait_frames(almos.tuning.parried_recoil_frames + PAST_THE_END_FRAMES)

	var first := _rig.first_sample_where("recoiling")
	var shown := false
	for i in range(first, _rig.samples.size()):
		shown = shown or _rig.samples[i].shows
	assert_false(shown, "the press of %s should have done nothing, in the recoil or after it" % params.action)


func test_a_press_of_interact_in_a_recoil_picks_up_nothing() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	var pickup := (load(WEAPON_PICKUP_PATH) as PackedScene).instantiate()
	pickup.weapon = load(SPEAR_PATH)
	pickup.position = almos.position
	add_child_autofree(pickup)
	var carried_before: int = almos.weapons.carried.size()
	await _tap(&"attack_light")
	await _wait_until_recoiling(almos)

	await _tap(&"interact")
	await _rig.wait_frames(almos.tuning.parried_recoil_frames + PAST_THE_END_FRAMES)

	assert_eq(almos.weapons.carried.size(), carried_before, "Weapons carried")
	assert_true(is_instance_valid(pickup), "the pickup should still lie there")


func test_he_stands_still_in_a_recoil() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	await _tap(&"attack_light")
	await _wait_until_recoiling(almos)
	var held_at: Vector2 = almos.position

	_almos_input.press_action(&"move_right")
	await _rig.wait_frames(almos.tuning.parried_recoil_frames - 2)

	assert_lt(almos.position.distance_to(held_at), MOVED)


func test_a_hit_on_him_in_a_recoil_lands_in_full_even_with_block_held() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	var hitbox := _hits.hitbox_from(almos, Vector2.DOWN * AlmosHits.HIT_DISTANCE)
	_almos_input.press_action(&"block")
	await _tap(&"attack_light")
	await _wait_until_recoiling(almos)
	var health_before: float = almos.health.current

	await _hits.swing(hitbox, 1)

	assert_true(almos.recoiling, "he should still be in the recoil")
	assert_almost_eq(almos.health.current, health_before - AlmosHits.HIT_DAMAGE, TOLERANCE)


func test_he_can_attack_again_once_the_recoil_is_over() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer()
	await _tap(&"attack_light")
	await _wait_until_recoiling(almos)
	await _rig.wait_frames(almos.tuning.parried_recoil_frames + SETTLE_FRAMES)
	assert_false(almos.recoiling, "the recoil should be over")

	await _tap(&"attack_light")

	assert_true(almos.attacking)


func test_a_swing_the_jailer_blocks_does_not_make_him_recoil() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer({"parry_every": NEVER})

	await _tap(&"attack_light")
	await _rig.wait_frames(SWING_WAIT_FRAMES)

	assert_eq(_rig.first_sample_where("recoiling"), -1)


func test_a_swing_that_lands_on_the_jailers_back_does_not_make_him_recoil() -> void:
	var almos = _almos_swinging_at_a_parrying_jailer({"parry_every": 1}, Vector2.DOWN)

	await _tap(&"attack_light")
	await _rig.wait_frames(SWING_WAIT_FRAMES)

	assert_eq(_rig.first_sample_where("recoiling"), -1)
	assert_lt(_rig.enemy.health.current, _rig.enemy.tuning.health_maximum, "the swing should have landed")


# --- Helpers ---

# A jailer facing down, with these guard numbers changed.
func _spawn_jailer(changes := {}):
	var enemy = _rig.spawn_enemy(_rig.tuning_with(_guard_numbers(changes)))
	enemy.post_facing = Vector2.DOWN
	return enemy


# The properties that make a copy of the training enemy's tuning guard, with these changed.
func _guard_numbers(changes := {}) -> Dictionary:
	var numbers := {"guards": true, "block_damage_share": SHARE, "block_stagger": BLOCK_STAGGER, "parry_every": PARRY_EVERY}
	numbers.merge(changes, true)
	return numbers


# One hit on the enemy from in front of it or behind it, which lands once.
func _hit(enemy: Node2D, from_front: bool, damage := HIT_DAMAGE, stagger := HIT_STAGGER) -> void:
	var offset := Vector2.DOWN if from_front else Vector2.UP
	var hitbox := _rig.hitbox_over(enemy, damage, "enemy_hurtbox")
	hitbox.global_position = enemy.global_position + offset * HIT_DISTANCE
	hitbox.stagger = stagger
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)


# A target standing in the jailer's attack range, in front of it, which it goes for.
func _place_target_in_reach(enemy: Node2D) -> Node2D:
	return _rig.place_target(enemy.global_position + Vector2.DOWN * TARGET_DISTANCE)


func _wait_until_swinging(enemy) -> void:
	for i in WAIT_FRAME_LIMIT:
		if enemy.attacking:
			return
		await get_tree().physics_frame
	fail_test("the enemy should begin a swing")


func _wait_until_free(enemy) -> void:
	for i in WAIT_FRAME_LIMIT:
		if not enemy.attacking:
			return
		await get_tree().physics_frame
	fail_test("the enemy's swing should end")


# Almos above a jailer that Parries every hit from the front and faces him, with every physics
# frame sampled for whether he recoils.
func _almos_swinging_at_a_parrying_jailer(changes := {"parry_every": 1}, jailer_faces := Vector2.UP):
	var almos = _almos_input.spawn_almos()
	var enemy = _rig.spawn_enemy(_rig.tuning_with(_guard_numbers(changes)), almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	enemy.post_facing = jailer_faces
	_rig.sample_also("recoiling", func() -> bool: return almos.recoiling)
	return almos


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# The first stretch of samples in which this is true, as Vector2i(first, end), as the rig has it.
func _span(key: String) -> Vector2i:
	return _rig.span(key)


func _wait_until_recoiling(almos) -> void:
	for i in WAIT_FRAME_LIMIT:
		if almos.recoiling:
			return
		await get_tree().physics_frame
	fail_test("he should recoil")
