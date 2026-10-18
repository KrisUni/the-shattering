extends GutTest
## The training enemy's Stagger, seen only through the scenes. The real enemy scene runs with
## its shipped tuning. Almos is the real scene, driven by input: he parries the enemy's real
## swing and swings the sword at it. Where a hit must come from a chosen side, a Hitbox from
## the helpers stands in for the attacker. Every expected number comes from the data files the
## scenes use and plain arithmetic, never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyFight := preload("res://test/helpers/enemy_fight.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

# In Stagger points.
const TOLERANCE := 0.0001
# In pixels. How far below Almos the enemy stands: close enough for his sword to reach it. He
# starts out facing down.
const ENEMY_DISTANCE := 30.0
# In pixels. How far beyond the enemy's notice range the stand-in it goes after stands, so that
# it turns to face it and goes nowhere.
const BEYOND_NOTICE := 50.0
# In pixels. How far from the enemy's centre a stand-in attacker's hit comes from.
const HIT_DISTANCE := 40.0
# A tap: held this many physics frames, far shorter than a swing or a charge.
const TAP_FRAMES := 3
# In Health points. A hit that takes next to nothing off, so that only its Stagger matters.
const NO_DAMAGE := 0.0
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 240
const SETTLE_FRAMES := 3
# In physics frames. How far inside the pause a test looks for the meter not to have moved.
const PAUSE_MARGIN_FRAMES := 10
# In degrees. A direction that is no multiple of a quarter turn, to see that facing is exact.
const ODD_ANGLE_DEGREES := 33.0
# Facing is a unit vector, so it needs a much tighter tolerance than pixels.
const FACING_TOLERANCE := 0.0001

# Which side of the enemy a hit comes from, and whether the enemy has its back to it.
var side_params = ParameterFactory.named_parameters(
	["side", "from_behind"],
	[["the front", false], ["behind", true]],
)

# Which Heavy attack, and from which side of the enemy.
var heavy_params = ParameterFactory.named_parameters(
	["what", "charged", "from_behind"],
	[
		["a plain Heavy attack from the front", false, false],
		["a plain Heavy attack from behind", false, true],
		["a fully charged Heavy attack from the front", true, false],
		["a fully charged Heavy attack from behind", true, true],
	],
)

var _almos_input: AlmosInput
var _rig: EnemyRig
var _fight: EnemyFight
var _tuning: EnemyTuning
var _player: PlayerTuning
var _sword: WeaponData


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)
	_fight = EnemyFight.new(self, _almos_input, _rig)
	_tuning = _rig.tuning_with()
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning
	_sword = load(AlmosInput.WEAPON_PATH) as WeaponData


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- The numbers ---

func test_the_stagger_numbers_make_parries_fill_the_meter_and_a_pause_longer_than_its_swing() -> void:
	assert_gt(_tuning.stagger_capacity, 0.0, "stagger_capacity in the data file should be positive")
	assert_gt(_tuning.stagger_drain_rate, 0.0, "stagger_drain_rate in the data file should be positive")
	assert_gt(_player.parry_stagger, 0.0, "parry_stagger in the data file should be positive")
	assert_gt(_parries_to_fill_the_meter(), 1, "one Parry should not fill the meter")
	# An Unblockable attack cannot be Parried, so the gap it opens between two Parries is the
	# player's to cover with a Roll, not the pause's: only an attack that is followed by another
	# the player can Parry has its gap checked.
	var order := _tuning.attack_pattern
	for i in order.size():
		var kind := order[i]
		var next := order[(i + 1) % order.size()]
		if kind == EnemyTuning.AttackKind.UNBLOCKABLE or next == EnemyTuning.AttackKind.UNBLOCKABLE:
			continue
		var gap_seconds := float(_tuning.attack_of(kind).total_frames()) / Engine.physics_ticks_per_second
		assert_gt(_tuning.stagger_drain_pause, gap_seconds, "the pause should be longer than the gap from each Parryable attack in the order (place %d, kind %d) to the next one, so that Parries alone can fill the meter" % [i, kind])


func test_light_attacks_build_no_stagger_and_a_charged_heavy_builds_more_than_a_plain_one() -> void:
	for swing in _sword.light_attacks:
		assert_almost_eq(swing.stagger, 0.0, TOLERANCE, "a Light attack's stagger in the data file")
	assert_gt(_sword.heavy_attack.stagger, 0.0, "the Heavy attack's stagger in the data file should be positive")
	assert_gt(_sword.heavy_attack.charged_stagger, _sword.heavy_attack.stagger, "a full charge should build more Stagger")


func test_the_enemys_stagger_meter_is_set_from_its_tuning_and_starts_empty() -> void:
	var enemy = _rig.spawn_enemy()

	assert_almost_eq(enemy.stagger.capacity, _tuning.stagger_capacity, TOLERANCE)
	assert_almost_eq(enemy.stagger.drain_rate, _tuning.stagger_drain_rate, TOLERANCE)
	assert_almost_eq(enemy.stagger.drain_pause, _tuning.stagger_drain_pause, TOLERANCE)
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE)


# --- Parries ---

func test_a_parry_of_its_swing_by_almos_builds_the_parry_stagger_and_costs_him_no_health() -> void:
	var almos = _spawn_fight()

	await _fight.parry_the_swing(_player)

	assert_almost_eq(_rig.enemy.stagger.current, _player.parry_stagger, TOLERANCE)
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE, "a parried swing should do no damage")
	assert_almost_eq(_rig.enemy.health.current, _tuning.health_maximum, TOLERANCE, "Stagger should not touch its Health")


func test_the_parries_that_fill_the_meter_break_the_enemy_and_one_fewer_does_not() -> void:
	var needed := _parries_to_fill_the_meter()
	_spawn_fight()

	for i in needed - 1:
		await _fight.parry_the_swing(_player)
	assert_almost_eq(_rig.enemy.stagger.current, (needed - 1) * _player.parry_stagger, TOLERANCE, "after one Parry fewer")
	assert_false(_rig.enemy.stagger.full, "one Parry fewer should not fill the meter")
	assert_false(_rig.enemy.broken, "one Parry fewer should not break it")
	await _fight.parry_the_swing(_player)

	assert_true(_rig.enemy.broken, "the Parries that fill the meter should break it")
	assert_almost_eq(_rig.enemy.stagger.current, 0.0, TOLERANCE, "a Break empties the meter")


func test_a_swing_that_lands_on_almos_builds_no_stagger() -> void:
	_spawn_fight()

	await _rig.wait_frames(_tuning.attack.startup_frames + _tuning.attack.active_frames + SETTLE_FRAMES)

	assert_almost_eq(_rig.enemy.stagger.current, 0.0, TOLERANCE)


# --- Hits ---

func test_a_light_attack_by_almos_builds_none_from_the_front_and_the_behind_stagger_from_behind(params = use_parameters(side_params)) -> void:
	var almos = _fight.spawn_almos_above_the_enemy(params.from_behind)

	await _tap_and_wait_for_the_swing(almos, &"attack_light")

	var expected := _tuning.behind_stagger if params.from_behind else 0.0
	assert_almost_eq(_rig.enemy.stagger.current, expected, TOLERANCE, "Stagger a Light attack builds from %s" % params.side)
	assert_lt(_rig.enemy.health.current, _tuning.health_maximum, "the Light attack should have landed")


func test_a_heavy_attack_by_almos_builds_its_stagger_in_proportion_to_the_charge_and_more_from_behind(params = use_parameters(heavy_params)) -> void:
	var heavy := _sword.heavy_attack
	var almos = _fight.spawn_almos_above_the_enemy(params.from_behind)

	if params.charged:
		_almos_input.press_action(&"attack_heavy")
		await _wait_for_the_swing_to_end(almos)
		_almos_input.release_action(&"attack_heavy")
	else:
		await _tap_and_wait_for_the_swing(almos, &"attack_heavy")

	var own := heavy.charged_stagger if params.charged else heavy.stagger
	var expected := own + (_tuning.behind_stagger if params.from_behind else 0.0)
	assert_almost_eq(_rig.enemy.stagger.current, expected, TOLERANCE, "Stagger of %s" % params.what)


func test_a_partly_charged_heavy_attack_builds_stagger_on_the_straight_line_between_the_two() -> void:
	var heavy := _sword.heavy_attack
	var almos = _fight.spawn_almos_above_the_enemy(false)
	var halfway := heavy.charge_start_frames + (heavy.charge_frames_max - heavy.charge_start_frames) / 2

	_almos_input.press_action(&"attack_heavy")
	await _rig.wait_frames(halfway)
	_almos_input.release_action(&"attack_heavy")
	await _wait_for_the_swing_to_end(almos)

	var expected := (heavy.stagger + heavy.charged_stagger) / 2.0
	# Almos sees the release a frame late, so the charge is a frame past the halfway point.
	var one_frame := (heavy.charged_stagger - heavy.stagger) / (heavy.charge_frames_max - heavy.charge_start_frames)
	assert_almost_eq(_rig.enemy.stagger.current, expected, one_frame * 2.0 + TOLERANCE)
	assert_gt(_rig.enemy.stagger.current, heavy.stagger)
	assert_lt(_rig.enemy.stagger.current, heavy.charged_stagger)


func test_a_hit_from_the_front_builds_just_its_own_stagger_and_one_from_behind_adds_the_behind_stagger(params = use_parameters(side_params)) -> void:
	var enemy = _spawn_facing_down()
	var own := 10.0
	var hitbox := _hitbox_from(enemy, params.from_behind, own)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)

	var expected := own + (_tuning.behind_stagger if params.from_behind else 0.0)
	assert_almost_eq(enemy.stagger.current, expected, TOLERANCE, "Stagger a hit from %s builds" % params.side)


func test_a_hit_from_the_side_that_is_just_inside_or_outside_its_front_is_told_apart() -> void:
	var enemy = _spawn_facing_down()
	var margin := deg_to_rad(5.0)
	var edge := deg_to_rad(_tuning.front_arc_degrees / 2.0)
	var inside := _hitbox_at(enemy, Vector2.DOWN.rotated(edge - margin) * HIT_DISTANCE, 0.0)
	var outside := _hitbox_at(enemy, Vector2.DOWN.rotated(edge + margin) * HIT_DISTANCE, 0.0)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(inside, 1)
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE, "a hit just inside its front")
	await _rig.swing(outside, 1)
	assert_almost_eq(enemy.stagger.current, _tuning.behind_stagger, TOLERANCE, "a hit just outside its front")


func test_a_hit_builds_its_stagger_once_however_long_the_swing_overlaps_it() -> void:
	var enemy = _spawn_facing_down()
	var hitbox := _hitbox_from(enemy, false, 10.0)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 6)

	assert_almost_eq(enemy.stagger.current, 10.0, TOLERANCE)


func test_stagger_never_lowers_its_health_and_a_full_meter_leaves_it_alive() -> void:
	var enemy = _spawn_facing_down()
	var hitbox := _hitbox_from(enemy, true, _tuning.stagger_capacity)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)
	await _rig.wait_frames(_pause_frames() + _drain_frames_to_empty())

	assert_almost_eq(enemy.health.current, _tuning.health_maximum, TOLERANCE)
	assert_false(enemy.dead, "Stagger alone should not kill it")


# --- Draining ---

func test_the_meter_holds_for_the_pause_and_then_drains_at_the_rate() -> void:
	var enemy = _spawn_facing_down()
	var built := _tuning.stagger_capacity * 0.8
	var hitbox := _hitbox_from(enemy, false, built)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)

	await _rig.wait_frames(_pause_frames() - PAUSE_MARGIN_FRAMES)
	assert_almost_eq(enemy.stagger.current, built, TOLERANCE, "it should hold through the pause")

	var draining_for := 30
	await _rig.wait_frames(PAUSE_MARGIN_FRAMES + draining_for)
	var seconds := float(draining_for) / Engine.physics_ticks_per_second
	# A frame or two either way on where the pause ends.
	var slack := 2.0 * _tuning.stagger_drain_rate / Engine.physics_ticks_per_second
	assert_almost_eq(enemy.stagger.current, built - _tuning.stagger_drain_rate * seconds, slack, "Stagger left after draining for %d frames" % draining_for)


func test_the_meter_drains_to_empty_and_no_further() -> void:
	var enemy = _spawn_facing_down()
	var hitbox := _hitbox_from(enemy, false, _tuning.stagger_capacity)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)

	await _rig.wait_frames(_pause_frames() + _drain_frames_to_empty() + PAUSE_MARGIN_FRAMES)

	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE)


func test_every_hit_restarts_the_pause_even_one_that_builds_nothing() -> void:
	var enemy = _spawn_facing_down()
	var built := _tuning.stagger_capacity * 0.5
	var first := _hitbox_from(enemy, false, built)
	var second := _hitbox_from(enemy, false, 0.0)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(first, 1)

	await _rig.wait_frames(_pause_frames() - PAUSE_MARGIN_FRAMES)
	await _rig.swing(second, 1)
	await _rig.wait_frames(_pause_frames() - PAUSE_MARGIN_FRAMES)

	assert_almost_eq(enemy.stagger.current, built, TOLERANCE, "the second hit should have pressed the enemy again, so the pause starts over")


func test_a_parry_restarts_the_pause() -> void:
	_spawn_fight()
	await _fight.parry_the_swing(_player)

	await _rig.wait_frames(_pause_frames() - PAUSE_MARGIN_FRAMES)

	assert_almost_eq(_rig.enemy.stagger.current, _player.parry_stagger, TOLERANCE)


# --- The bar ---

func test_the_bar_is_hidden_while_the_meter_is_empty_and_shows_the_fraction_once_it_is_not() -> void:
	var enemy = _spawn_facing_down()
	var bar := enemy.get_node("StaggerBar") as Node2D
	assert_false(bar.visible, "the bar should be hidden while the meter is empty")
	var built := _tuning.stagger_capacity * 0.4
	var hitbox := _hitbox_from(enemy, false, built)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _rig.swing(hitbox, 1)

	assert_true(bar.visible, "the bar should show once there is Stagger")
	assert_almost_eq(bar.scale.x, 0.4, TOLERANCE, "the fraction of its full length the bar shows")


func test_the_bar_follows_the_meter_down_and_hides_when_it_is_empty() -> void:
	var enemy = _spawn_facing_down()
	var bar := enemy.get_node("StaggerBar") as Node2D
	var hitbox := _hitbox_from(enemy, false, _tuning.stagger_capacity * 0.9)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)
	assert_almost_eq(bar.scale.x, 0.9, TOLERANCE, "the bar shows the fraction the meter is filled to")

	await _rig.wait_frames(_pause_frames() + _drain_frames_to_empty() / 2)
	assert_true(bar.visible)
	assert_almost_eq(bar.scale.x, enemy.stagger.current / _tuning.stagger_capacity, TOLERANCE, "the bar follows the meter as it drains")
	assert_lt(bar.scale.x, 1.0)

	await _rig.wait_frames(_drain_frames_to_empty())
	assert_false(bar.visible, "the bar should hide when the meter is empty")


# --- Facing ---

func test_it_starts_out_facing_its_post_direction_down_unless_set_otherwise() -> void:
	var scene := load(EnemyRig.ENEMY_SCENE_PATH) as PackedScene
	var plain = scene.instantiate()
	add_child_autofree(plain)
	assert_almost_eq(plain.facing, Vector2.DOWN, Vector2.ONE * FACING_TOLERANCE)

	var set_right = scene.instantiate()
	set_right.post_facing = Vector2.RIGHT
	add_child_autofree(set_right)
	assert_almost_eq(set_right.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE)


func test_while_free_and_not_having_noticed_it_keeps_facing_its_post_direction_whatever_its_target_does() -> void:
	var enemy = _rig.spawn_enemy()
	var target := _rig.place_target(Vector2.ZERO)
	enemy.post_facing = Vector2.UP
	target.global_position = Vector2.DOWN * (_tuning.sight_length_full + BEYOND_NOTICE)

	await _rig.wait_frames(SETTLE_FRAMES)

	assert_almost_eq(enemy.facing, Vector2.UP, Vector2.ONE * FACING_TOLERANCE)
	assert_almost_eq(enemy.get_node("Nose").rotation, Vector2.UP.angle(), FACING_TOLERANCE, "the nose turns with it")


func test_while_free_it_turns_to_face_its_target_exactly_wherever_it_goes() -> void:
	# It does not walk, so that the target is where the test puts it, and it has noticed it.
	var enemy = _rig.spawn_enemy(_rig.tuning_with({"move_speed": 0.0}))
	var target := _rig.place_target(Vector2.DOWN * (_tuning.sight_length_full + BEYOND_NOTICE))
	var hit := _rig.hitbox_over(enemy, NO_DAMAGE, "enemy_hurtbox")
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hit, 1)
	for direction in [Vector2.RIGHT.rotated(deg_to_rad(ODD_ANGLE_DEGREES)), Vector2.LEFT.rotated(deg_to_rad(ODD_ANGLE_DEGREES)), Vector2.UP]:
		target.global_position = direction * (_tuning.sight_length_full + BEYOND_NOTICE)
		await _rig.wait_frames(SETTLE_FRAMES)
		assert_almost_eq(enemy.facing, direction, Vector2.ONE * FACING_TOLERANCE, "facing towards the target at %s" % direction)
		assert_almost_eq(enemy.get_node("Nose").rotation, direction.angle(), FACING_TOLERANCE, "the nose turns with it")


func test_while_attacking_it_keeps_the_direction_it_committed_the_swing_to() -> void:
	var enemy = _rig.spawn_enemy()
	var target := _rig.place_target(Vector2.RIGHT * _tuning.attack_range / 2.0)
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(enemy.attacking, "it should have begun to attack")
	assert_almost_eq(enemy.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE)

	target.global_position = Vector2.LEFT * _tuning.attack_range / 2.0
	await _rig.wait_frames(_tuning.attack.total_frames() / 2)
	assert_true(enemy.attacking, "it should still be in the swing")
	assert_almost_eq(enemy.facing, Vector2.RIGHT, Vector2.ONE * FACING_TOLERANCE, "it should keep facing the way it swung")

	await _rig.wait_frames(_tuning.attack.total_frames())
	assert_almost_eq(enemy.facing, Vector2.LEFT, Vector2.ONE * FACING_TOLERANCE, "once free it should face the target again")


# --- Helpers ---

# Almos at the origin, facing down, the enemy a little way below him, after him. The enemy is
# added after him, so he is processed first in a frame.
func _spawn_fight():
	var almos = _almos_input.spawn_almos()
	_rig.spawn_enemy(null, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	return almos


# The enemy at the origin, at its post with no target, facing down.
func _spawn_facing_down():
	var enemy = _rig.spawn_enemy()
	enemy.post_facing = Vector2.DOWN
	return enemy


# A Hitbox switched off, built to hit the enemy, whose hit builds this much Stagger and comes
# from in front of the enemy (the way it faces, down) or from behind it.
func _hitbox_from(enemy: Node2D, from_behind: bool, stagger: float) -> Hitbox:
	var offset := Vector2.UP if from_behind else Vector2.DOWN
	return _hitbox_at(enemy, offset * HIT_DISTANCE, stagger)


func _hitbox_at(enemy: Node2D, offset: Vector2, stagger: float) -> Hitbox:
	var hitbox := _rig.hitbox_over(enemy, NO_DAMAGE, "enemy_hurtbox")
	hitbox.global_position = enemy.global_position + offset
	hitbox.stagger = stagger
	return hitbox


# How many Parries it takes to fill the meter.
func _parries_to_fill_the_meter() -> int:
	return ceili(_tuning.stagger_capacity / _player.parry_stagger)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _tap_and_wait_for_the_swing(almos, action: StringName) -> void:
	await _tap(action)
	await _wait_for_the_swing_to_end(almos)


# Waits for a swing to begin, if one has not, and be over.
func _wait_for_the_swing_to_end(almos) -> void:
	await _rig.wait_frames(SETTLE_FRAMES)
	for i in WAIT_FRAME_LIMIT:
		if not almos.attacking and not almos.charging:
			return
		await get_tree().physics_frame
	fail_test("the swing should be over")


# The pause before the meter drains, in whole physics frames.
func _pause_frames() -> int:
	return ceili(_tuning.stagger_drain_pause * Engine.physics_ticks_per_second)


# How many physics frames it takes a full meter to drain.
func _drain_frames_to_empty() -> int:
	return ceili(_tuning.stagger_capacity / _tuning.stagger_drain_rate * Engine.physics_ticks_per_second)
