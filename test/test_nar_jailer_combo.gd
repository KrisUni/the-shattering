extends GutTest
## The Nar jailer's club combo, seen only through the scenes. The real enemy scene runs with a
## combo set here (a copy of the training enemy's tuning with its attack pattern and combo
## changed, so that the numbers are plain and apart from the data file's), or with the Nar
## jailer's own data file, and a stand-in target to go after. Every physics frame a sample is
## taken, so what happened can be read back frame by frame: a sample is taken at the start of the
## frame, before anything has moved in it, so it shows how the frame before left things. Every
## expected number comes from the numbers set here or the data file, and plain arithmetic, never
## from how the code works them out.

const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const COMBO := EnemyTuning.AttackKind.COMBO
const STRIKE := EnemyTuning.AttackKind.STRIKE
const UNBLOCKABLE := EnemyTuning.AttackKind.UNBLOCKABLE
const JAILER_PATH := "res://data/nar_jailer.tres"

# In Health points.
const TOLERANCE := 0.0001
# In pixels. How far from the enemy a target is put for it to notice him and swing: inside its
# attack range and its Sight, which points to the right.
const TARGET_DISTANCE := 30.0
# In pixels. How far past the enemy's attack range a target is moved, to be out of it and still
# in its Sight.
const BEYOND_RANGE := 40.0
# In physics frames. Slack after the last frame a test is about, to let it play out.
const SETTLE_FRAMES := 10
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 600
# In pixels. How far inside or beyond a swing's far edge the target's Hurtbox is put.
const REACH_MARGIN := 1.0
# In pixels. A walk this short is a walk.
const MOVED := 0.5
# The share of a swing's damage a stand-in Block lets through.
const BLOCKED_SHARE := 0.5
# In Stagger points. What a stand-in Parry builds, short of filling the meter.
const PARRY_STAGGER := 1.0

# The three swings the tests set, each with its own damage and frames: two short ones and a heavy
# one with a longer wind-up and recovery. In physics frames and Health points.
const SWING_DAMAGES: Array[float] = [5.0, 7.0, 11.0]
const SWING_STARTUPS: Array[int] = [10, 12, 20]
const SWING_ACTIVES: Array[int] = [4, 4, 6]
const SWING_RECOVERIES: Array[int] = [6, 8, 30]

var _rig: EnemyRig


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample.
	# GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_rig = EnemyRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()


# --- The chain ---

func test_it_makes_its_swings_in_order_each_for_its_own_damage() -> void:
	_rig.spawn_enemy(_combo_tuning())
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)

	await _rig.wait_frames(_combo_frames() + SETTLE_FRAMES)

	assert_eq(_damages(_rig.hits()).slice(0, 3), SWING_DAMAGES)


func test_each_swing_begins_the_frame_the_one_before_ends_so_the_gaps_are_the_recoveries() -> void:
	_rig.spawn_enemy(_combo_tuning())
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)

	await _rig.wait_frames(_combo_frames() + SETTLE_FRAMES)

	var begun := _rig.first_sample_where("attacking")
	var never_free := true
	for i in range(begun, begun + _combo_frames()):
		never_free = never_free and _rig.samples[i].attacking
	assert_true(never_free, "it should be in an attack in every frame of the three swings")
	var hits := _rig.hits()
	assert_eq(hits[1].sample - hits[0].sample, SWING_ACTIVES[0] + SWING_RECOVERIES[0] + SWING_STARTUPS[1], "frames from the first hit to the second")
	assert_eq(hits[2].sample - hits[1].sample, SWING_ACTIVES[1] + SWING_RECOVERIES[1] + SWING_STARTUPS[2], "frames from the second hit to the third")


func test_the_attack_under_way_is_the_swing_of_the_combo_it_is_in() -> void:
	var enemy = _rig.spawn_enemy(_combo_tuning())
	_rig.sample_also("kind", func() -> int: return enemy.attack_kind)
	_rig.sample_also("damage", func() -> float: return enemy.current_attack.damage)
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)

	await _rig.wait_frames(_combo_frames() + SETTLE_FRAMES)

	var begun := _rig.first_sample_where("attacking")
	var second := begun + SWING_STARTUPS[0] + SWING_ACTIVES[0] + SWING_RECOVERIES[0]
	var third := second + SWING_STARTUPS[1] + SWING_ACTIVES[1] + SWING_RECOVERIES[1]
	assert_eq(_rig.samples[begun].kind, COMBO, "kind of attack in the first swing")
	assert_almost_eq(_rig.samples[begun].damage, SWING_DAMAGES[0], TOLERANCE, "attack in the first swing")
	assert_almost_eq(_rig.samples[second].damage, SWING_DAMAGES[1], TOLERANCE, "attack in the second swing")
	assert_almost_eq(_rig.samples[third].damage, SWING_DAMAGES[2], TOLERANCE, "attack in the third swing")


func test_after_the_last_swing_the_pattern_moves_on_and_the_next_combo_starts_from_the_first() -> void:
	var tuning := _combo_tuning({"attack_pattern": _pattern([COMBO, STRIKE])})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)

	await _rig.wait_frames(_combo_frames() + tuning.attack.total_frames() + SWING_STARTUPS[0] + SWING_ACTIVES[0] + SETTLE_FRAMES)

	var expected: Array[float] = [SWING_DAMAGES[0], SWING_DAMAGES[1], SWING_DAMAGES[2], tuning.attack.damage, SWING_DAMAGES[0]]
	assert_eq(_damages(_rig.hits()), expected)


# --- Dropping it ---

func test_a_target_out_of_attack_range_when_a_swing_ends_drops_the_combo_and_the_next_starts_from_the_first() -> void:
	var tuning := _combo_tuning()
	_rig.spawn_enemy(tuning)
	var target := _rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	await _wait_for_hits(1)

	target.position += Vector2.RIGHT * (tuning.attack_range + BEYOND_RANGE)
	await _wait_for_hits(2)

	assert_eq(_damages(_rig.hits()).slice(0, 2), [SWING_DAMAGES[0], SWING_DAMAGES[0]] as Array[float])


func test_it_walks_to_a_target_that_stepped_out_of_range_instead_of_swinging_the_rest_of_the_combo() -> void:
	var tuning := _combo_tuning()
	var enemy = _rig.spawn_enemy(tuning)
	var target := _rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	await _wait_for_hits(1)
	var left_at: Vector2 = enemy.position

	target.position += Vector2.RIGHT * (tuning.attack_range + BEYOND_RANGE)
	await _rig.wait_frames(SWING_ACTIVES[0] + SWING_RECOVERIES[0] + SETTLE_FRAMES)

	assert_gt(enemy.position.distance_to(left_at), MOVED, "it should walk towards him")
	assert_eq(_rig.hits().size(), 1, "hits the target took")


func test_a_break_drops_the_combo_and_the_next_starts_from_the_first_swing() -> void:
	var enemy = _rig.spawn_enemy(_combo_tuning({"break_frames": 5}))
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	await _wait_for_hits(1)

	var hitbox := _rig.hitbox_over(enemy, 0.0, "enemy_hurtbox")
	hitbox.stagger = enemy.tuning.stagger_capacity
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)
	assert_true(enemy.broken, "the setup should have broken it")
	await _wait_for_hits(2)

	assert_eq(_damages(_rig.hits()).slice(0, 2), [SWING_DAMAGES[0], SWING_DAMAGES[0]] as Array[float])


func test_a_parry_of_a_swing_does_not_drop_the_combo() -> void:
	_rig.spawn_enemy(_combo_tuning())
	var target := _rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	var parried := [false]
	var hurtbox := _hurtbox_of(target)
	hurtbox.parry_stagger = 1.0
	hurtbox.is_parried = func(_from: Vector2) -> bool:
		var parry_this_one: bool = not parried[0]
		parried[0] = true
		return parry_this_one

	await _rig.wait_frames(_combo_frames() + SETTLE_FRAMES)

	assert_eq(_damages(_rig.hits()).slice(0, 2), [SWING_DAMAGES[1], SWING_DAMAGES[2]] as Array[float], "hits the target took, the first swing having been parried")


func test_a_parried_swing_builds_the_parry_stagger_on_the_enemy() -> void:
	var enemy = _rig.spawn_enemy(_combo_tuning())
	var target := _rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	var hurtbox := _hurtbox_of(target)
	hurtbox.parry_stagger = PARRY_STAGGER
	hurtbox.is_parried = func(_from: Vector2) -> bool: return true

	await _wait_frames_until_stagger(enemy)

	assert_almost_eq(enemy.stagger.current, PARRY_STAGGER, TOLERANCE)


func test_a_parry_that_fills_the_stagger_breaks_it_and_the_next_combo_starts_from_the_first_swing() -> void:
	var enemy = _rig.spawn_enemy(_combo_tuning({"break_frames": 5}))
	var target := _rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	var hurtbox := _hurtbox_of(target)
	hurtbox.parry_stagger = enemy.tuning.stagger_capacity
	var parried := [false]
	hurtbox.is_parried = func(_from: Vector2) -> bool:
		var parry_this_one: bool = not parried[0]
		parried[0] = true
		return parry_this_one

	await _wait_for_hits(2)

	assert_eq(_damages(_rig.hits()).slice(0, 2), [SWING_DAMAGES[0], SWING_DAMAGES[1]] as Array[float], "hits the target took, the first swing having been parried and the combo begun again")


# --- The swings as hits ---

func test_a_swing_is_blockable_as_the_strike_is() -> void:
	_rig.spawn_enemy(_combo_tuning())
	var target := _rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	_hurtbox_of(target).damage_through = func(damage: float, _from: Vector2) -> float: return damage * BLOCKED_SHARE

	await _rig.wait_frames(_combo_frames() + SETTLE_FRAMES)

	assert_almost_eq(_rig.hits()[0].damage, SWING_DAMAGES[0] * BLOCKED_SHARE, TOLERANCE)


var reach_params = ParameterFactory.named_parameters(
	["beyond_far_edge", "hits"],
	[[-REACH_MARGIN, true], [REACH_MARGIN, false]],
)


func test_a_swing_reaches_as_far_as_combo_reach_and_no_farther(params = use_parameters(reach_params)) -> void:
	# The nearest edge of the target's Hurtbox, a radius short of where he stands, is put this far
	# beyond the swing's far edge (a negative number is inside it). The Strike's reach is shorter, so
	# it is not the one that decides.
	var reach: float = TARGET_DISTANCE - EnemyRig.TARGET_RADIUS - params.beyond_far_edge
	_rig.spawn_enemy(_combo_tuning({"combo_reach": reach, "attack_reach": 1.0}))
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)

	await _rig.wait_frames(_combo_frames() + SETTLE_FRAMES)

	assert_eq(not _rig.hits().is_empty(), params.hits, "whether the target was hit")


func test_the_strike_keeps_its_own_reach_after_a_combo() -> void:
	# Its Strike falls short of the target, though the swings of its combo reach him.
	var tuning := _combo_tuning({"attack_pattern": _pattern([COMBO, STRIKE]), "attack_reach": 1.0})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)

	await _rig.wait_frames(_combo_frames() + tuning.attack.total_frames() + SETTLE_FRAMES)

	assert_eq(_damages(_rig.hits()), SWING_DAMAGES, "only the swings of the combo hit")


# --- The Nar jailer's data ---

func test_the_nar_jailer_fights_with_a_combo_of_light_light_heavy() -> void:
	var jailer := load(JAILER_PATH) as EnemyTuning
	var swings := jailer.combo

	assert_eq(jailer.attack_pattern, _pattern([COMBO]), "its attack pattern")
	assert_eq(swings.size(), 3, "swings in its combo")
	if swings.size() == 3:
		assert_gt(swings[2].damage, swings[0].damage, "the heavy swing hits harder than the first light one")
		assert_gt(swings[2].damage, swings[1].damage, "the heavy swing hits harder than the second light one")
		assert_gt(swings[2].startup_frames, swings[0].startup_frames, "the heavy swing winds up longer than the first light one")
		assert_gt(swings[2].startup_frames, swings[1].startup_frames, "the heavy swing winds up longer than the second light one")
		assert_gt(swings[2].recovery_frames, swings[0].recovery_frames, "the last swing recovers longer than the first gap")
		assert_gt(swings[2].recovery_frames, swings[1].recovery_frames, "the last swing recovers longer than the second gap")


func test_the_nar_jailer_keeps_its_unblockable_attack_for_the_drag() -> void:
	var jailer := load(JAILER_PATH) as EnemyTuning

	assert_not_null(jailer.unblockable_attack, "its Unblockable attack")
	assert_false(jailer.attack_pattern.has(UNBLOCKABLE), "the Unblockable attack should not be in its fighting pattern")


func test_the_nar_jailer_chains_its_swings_in_a_fight_and_never_grabs() -> void:
	var jailer := load(JAILER_PATH) as EnemyTuning
	var enemy = _rig.spawn_enemy(jailer)
	_rig.sample_also("kind", func() -> int: return enemy.attack_kind)
	_rig.place_target(Vector2.RIGHT * TARGET_DISTANCE)
	var rounds := 2
	var one_combo := 0
	for swing in jailer.combo:
		one_combo += swing.total_frames()

	await _rig.wait_frames(rounds * one_combo + SETTLE_FRAMES)

	var expected: Array[float] = []
	for i in rounds:
		for swing in jailer.combo:
			expected.append(swing.damage)
	assert_eq(_damages(_rig.hits()).slice(0, expected.size()), expected, "hits the target took, round after round")
	var kinds_used := {}
	for sample in _rig.samples:
		kinds_used[sample.kind] = true
	assert_false(kinds_used.has(UNBLOCKABLE), "it should never make its Unblockable attack in a fight")


func test_every_shipped_enemy_whose_pattern_has_a_combo_has_swings_in_it() -> void:
	var checked := 0
	for file in DirAccess.get_files_at("res://data"):
		var tuning := load("res://data/" + file) as EnemyTuning if file.ends_with(".tres") else null
		if tuning != null and tuning.attack_pattern.has(COMBO):
			checked += 1
			assert_false(tuning.combo.is_empty(), "%s has a COMBO in its pattern, so it needs a combo" % file)
	assert_gt(checked, 0, "enemy data files with a combo")


# --- Helpers ---

# A copy of the training enemy's tuning whose pattern is the combo alone, of the three swings set
# above, with these properties changed.
func _combo_tuning(changes := {}) -> EnemyTuning:
	var numbers := {"attack_pattern": _pattern([COMBO]), "combo": _swings(), "combo_reach": 42.0}
	numbers.merge(changes, true)
	return _rig.tuning_with(numbers)


func _swings() -> Array[AttackData]:
	var swings: Array[AttackData] = []
	for i in SWING_DAMAGES.size():
		var swing := AttackData.new()
		swing.startup_frames = SWING_STARTUPS[i]
		swing.active_frames = SWING_ACTIVES[i]
		swing.recovery_frames = SWING_RECOVERIES[i]
		swing.damage = SWING_DAMAGES[i]
		swings.append(swing)
	return swings


func _pattern(kinds: Array) -> Array[EnemyTuning.AttackKind]:
	var pattern: Array[EnemyTuning.AttackKind] = []
	pattern.assign(kinds)
	return pattern


# How many physics frames the three swings take from the first to the end of the last.
func _combo_frames() -> int:
	var total := 0
	for i in SWING_DAMAGES.size():
		total += SWING_STARTUPS[i] + SWING_ACTIVES[i] + SWING_RECOVERIES[i]
	return total


func _damages(hits: Array[Dictionary]) -> Array[float]:
	var damages: Array[float] = []
	for hit in hits:
		damages.append(hit.damage)
	return damages


func _hurtbox_of(node: Node) -> Hurtbox:
	for child in node.get_children():
		if child is Hurtbox:
			return child
	fail_test("the stand-in target should have a Hurtbox")
	return null


# Waits until the enemy has Stagger built on it.
func _wait_frames_until_stagger(enemy) -> void:
	for i in WAIT_FRAME_LIMIT:
		if enemy.stagger.current > 0.0:
			return
		await get_tree().physics_frame
	fail_test("the enemy should have Stagger built on it")


# Waits until the target has taken this many hits.
func _wait_for_hits(count: int) -> void:
	for i in WAIT_FRAME_LIMIT:
		if _rig.hits().size() >= count:
			return
		await get_tree().physics_frame
	fail_test("the target should take %d hits" % count)
