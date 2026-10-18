extends GutTest
## The Break of the training enemy and Almos's Critical hit, seen only through the scenes. The
## real enemy scene and the real Almos scene run with their shipped tuning, Almos driven by
## input. Where a Break must come at a chosen moment, a Hitbox from the helpers stands in for
## the attacker. Every expected number comes from the data files the scenes use and plain
## arithmetic, never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

# In Stagger and Health points.
const TOLERANCE := 0.0001
# In pixels. How far below Almos an enemy stands when his sword is to reach it: inside the
# Critical hit's range, and inside the sword's reach.
const ENEMY_DISTANCE := 30.0
# In pixels. How far beyond the enemy's notice range the stand-in it goes after stands, so that
# it turns to face it and goes nowhere.
const BEYOND_NOTICE := 50.0
# In pixels. How far inside or beyond the Critical hit's range an enemy is put, when the
# Critical hit is to be made or just not.
const RANGE_MARGIN := 2.0
# In pixels. A Hitbox this wide covers the enemy it is put over, and no other.
const NARROW_HITBOX_RADIUS := 12.0
# A tap: held this many physics frames, far shorter than a swing or a charge.
const TAP_FRAMES := 3
# In Health points. A hit that takes next to nothing off, so that only its Stagger matters.
const NO_DAMAGE := 0.0
# In Health points. A hit that takes a little off, to see that a Break does not stop it.
const SOME_DAMAGE := 7.0
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 400
const SETTLE_FRAMES := 3
# In degrees. A direction that is no multiple of a quarter turn nor of an eighth, to see that
# the swing is aimed exactly while the facing is one of eight.
const ODD_ANGLE_DEGREES := 33.0
# In degrees. The nearest of eight facings to ODD_ANGLE_DEGREES.
const SNAPPED_ANGLE_DEGREES := 45.0
const ANGLE_TOLERANCE := 0.0001
const FACING_TOLERANCE := 0.0001
# A refill pause longer than any wait in these tests, so that Stamina stays where it was left.
const LONG_REFILL_PAUSE := 10.0

var _almos_input: AlmosInput
var _rig: EnemyRig
var _tuning: EnemyTuning
var _player: PlayerTuning
var _sword: WeaponData
# What was true of Almos in each physics frame, as it was at the start of it.
var _almos_samples: Array[Dictionary] = []
var _sampled_almos

# Which side of the enemy Almos is on, and whether the enemy has its back to him.
var side_params = ParameterFactory.named_parameters(
	["side", "from_behind"],
	[["the front", false], ["behind", true]],
)

# Where an enemy is put, in relation to the Critical hit's range, and whether he makes it.
var range_params = ParameterFactory.named_parameters(
	["where", "offset", "critical"],
	[
		["just inside the range", -RANGE_MARGIN, true],
		["just outside the range", RANGE_MARGIN, false],
	],
)

# At which moment of the enemy's swing the Break comes.
var interrupt_params = ParameterFactory.named_parameters(
	["moment", "wind_up"],
	[["during its wind-up", true], ["during its active frames", false]],
)


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)
	_tuning = _rig.tuning_with()
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning
	_sword = load(AlmosInput.WEAPON_PATH) as WeaponData
	_almos_samples = []
	_sampled_almos = null


func after_each() -> void:
	_rig.stop_sampling()
	if get_tree().physics_frame.is_connected(_take_almos_sample):
		get_tree().physics_frame.disconnect(_take_almos_sample)
	_almos_input.release_everything()


# --- The numbers ---

func test_the_break_and_critical_hit_numbers_are_in_the_data_files() -> void:
	var critical := _sword.critical_attack
	assert_gt(_tuning.break_frames, 0, "break_frames in the enemy's data file should be positive")
	assert_gt(_sword.critical_range, 0.0, "critical_range in the sword's data file should be positive")
	assert_not_null(critical, "the sword's data file should have a critical_attack")
	assert_almost_eq(critical.stamina_cost, 0.0, TOLERANCE, "the Critical hit costs no Stamina")
	assert_almost_eq(critical.stagger, 0.0, TOLERANCE, "the Critical hit builds no Stagger")
	assert_gt(critical.damage, _sword.heavy_attack.charged_damage, "the Critical hit should hit harder than any other attack")
	assert_lt(critical.startup_frames, _tuning.break_frames, "the Critical hit should be able to land within the Break")


# --- Breaking ---

func test_a_full_meter_breaks_it_and_the_meter_is_empty_at_once() -> void:
	var enemy = _spawn_idle_enemy()
	assert_false(enemy.broken, "it starts out free")

	await _break(enemy)

	assert_true(enemy.broken)
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE, "the meter resets as the Break begins")
	assert_false((enemy.get_node("StaggerBar") as Node2D).visible, "the bar over an empty meter is hidden")


func test_a_hit_that_builds_more_than_the_capacity_breaks_it_just_the_same() -> void:
	var enemy = _spawn_idle_enemy()

	await _swing_standin(enemy, _tuning.stagger_capacity * 3.0)

	assert_true(enemy.broken)
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE)


func test_a_hit_that_leaves_the_meter_short_of_full_does_not_break_it() -> void:
	var enemy = _spawn_idle_enemy()

	await _swing_standin(enemy, _tuning.stagger_capacity * 0.9)

	assert_false(enemy.broken)
	assert_almost_eq(enemy.stagger.current, _tuning.stagger_capacity * 0.9, TOLERANCE)


func test_three_parries_of_its_swing_by_almos_break_it_with_the_swing_over() -> void:
	var almos = _almos_input.spawn_almos()
	var enemy = _rig.spawn_enemy(null, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)

	for i in 3:
		assert_false(enemy.broken, "it should not be broken before the third Parry (Parry %d)" % (i + 1))
		await _parry_the_swing()

	assert_true(enemy.broken, "the third Parry should fill the meter and break it")
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE)
	assert_false(enemy.attacking, "the swing that was parried is over")
	assert_false(enemy.striking, "its Hitbox is off")
	assert_eq(enemy.modulate, enemy.BREAK_TINT, "it shows it is broken")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE, "no hit landed on Almos")


func test_heavy_attacks_from_behind_break_it_when_they_fill_the_meter() -> void:
	var almos = _spawn_almos_above_the_enemy(true)
	var enemy = _rig.enemy
	var heavy := _sword.heavy_attack
	var plain := heavy.stagger + _tuning.behind_stagger
	var charged := heavy.charged_stagger + _tuning.behind_stagger
	assert_lt(charged + plain, _tuning.stagger_capacity, "a full charge and a plain Heavy attack should not fill the meter")
	assert_gte(charged + 2.0 * plain, _tuning.stagger_capacity, "with a second plain one they should")
	assert_lt(heavy.charged_damage + 2.0 * heavy.damage, _tuning.health_maximum, "and the enemy should live through them")

	_almos_input.press_action(&"attack_heavy")
	await _wait_for_the_swing_to_end(almos)
	_almos_input.release_action(&"attack_heavy")
	assert_false(enemy.broken)
	await _tap(&"attack_heavy")
	await _wait_for_the_swing_to_end(almos)
	assert_false(enemy.broken, "a full charge and a plain Heavy attack do not break it")
	await _tap(&"attack_heavy")
	await _wait_for_the_swing_to_end(almos)

	assert_true(enemy.broken)
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE)


func test_a_break_interrupts_its_swing_and_no_hit_lands_from_it(params = use_parameters(interrupt_params)) -> void:
	var attack := _tuning.attack
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range / 2.0)
	# The Hitbox that breaks it is in the tree after the enemy, so it is processed after the
	# enemy in a frame, when the enemy has done its own processing for it.
	var breaker := _rig.hitbox_over(enemy, NO_DAMAGE, "enemy_hurtbox")
	breaker.stagger = _tuning.stagger_capacity
	await _wait_until_the_enemy_is(enemy, "winding_up")

	if params.wind_up:
		await _rig.wait_frames(attack.startup_frames / 2)
	else:
		await _rig.wait_frames(attack.startup_frames + attack.active_frames / 2)
		assert_true(enemy.striking, "its Hitbox should be on when the Break comes")
	var hits_before := _rig.hits().size()
	await _rig.swing(breaker, 1)
	# The frame the Break came in is over, and nothing has been processed since.
	assert_false(enemy.striking, "its Hitbox is off in the moment of the Break")
	assert_false(enemy.winding_up, "its wind-up is over in that moment")
	assert_eq(enemy.modulate, enemy.BREAK_TINT, "and its wind-up tint has gone in that moment")
	await _rig.wait_frames(attack.total_frames())

	assert_true(enemy.broken)
	assert_false(enemy.attacking, "the swing is over")
	assert_false(enemy.winding_up)
	assert_false(enemy.striking, "its Hitbox is off")
	assert_eq(_rig.hits().size(), hits_before, "no hit lands after the Break")
	assert_eq(enemy.modulate, enemy.BREAK_TINT, "its wind-up tint has gone")
	if params.wind_up:
		assert_eq(_rig.hits().size(), 0, "a swing broken in its wind-up never lands")


func test_a_break_in_the_frame_its_hitbox_would_first_be_on_stops_the_strike() -> void:
	var attack := _tuning.attack
	# The Hitbox that breaks it is in the tree before the enemy, so it is processed first in a
	# frame: the Break comes before the enemy's own processing, as Almos's blow would.
	var marker := Node2D.new()
	add_child_autofree(marker)
	var breaker := _rig.hitbox_over(marker, NO_DAMAGE, "enemy_hurtbox")
	breaker.stagger = _tuning.stagger_capacity
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range / 2.0)
	await _wait_until_the_enemy_is(enemy, "winding_up")
	# The wind-up has begun in the frame before this one; the first active frame is this many on.
	await _rig.wait_frames(attack.startup_frames - 1)

	await _rig.swing(breaker, 1)
	await _rig.wait_frames(attack.total_frames())

	assert_true(enemy.broken)
	assert_eq(_rig.hits().size(), 0, "the strike due in that frame does not land")


func test_no_stagger_builds_during_a_break_but_hits_still_take_health() -> void:
	var enemy = _spawn_idle_enemy()
	await _break(enemy)
	var health_before: float = enemy.health.current

	await _swing_standin(enemy, _tuning.stagger_capacity * 0.5, SOME_DAMAGE, true)
	await _swing_standin(enemy, _tuning.stagger_capacity * 0.5, SOME_DAMAGE, false)

	assert_true(enemy.broken, "hits do not end the Break")
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE, "no Stagger builds, from the front or from behind")
	assert_almost_eq(enemy.health.current, health_before - 2.0 * SOME_DAMAGE, TOLERANCE, "the hits still take Health")


func test_it_stands_still_starts_nothing_and_does_not_turn_while_broken() -> void:
	var enemy = _rig.spawn_enemy()
	var target := _rig.place_target(Vector2.RIGHT * _tuning.attack_range / 2.0)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _break(enemy)
	var facing_before: Vector2 = enemy.facing
	var position_before: Vector2 = enemy.global_position
	# The target moves to the other side, still noticed but out of attack range: it would turn
	# to it and walk, if it were free.
	target.global_position = Vector2.LEFT * (_tuning.attack_range + _tuning.notice_range) / 2.0

	for i in _tuning.break_frames - SETTLE_FRAMES:
		await get_tree().physics_frame
		assert_false(enemy.attacking, "it starts no attack (frame %d)" % i)
		assert_almost_eq(enemy.global_position, position_before, Vector2.ONE * TOLERANCE, "it does not walk (frame %d)" % i)
		assert_almost_eq(enemy.facing, facing_before, Vector2.ONE * FACING_TOLERANCE, "it does not turn (frame %d)" % i)


func test_it_lasts_exactly_break_frames_and_is_free_to_attack_on_the_frame_after() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range / 2.0)
	_rig.sample_also("broken", func() -> bool: return enemy.broken)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _break(enemy)
	await _rig.wait_frames(_tuning.break_frames + _tuning.attack.total_frames())

	var broken := _rig.span("broken")
	assert_ne(broken.x, -1, "it should have been broken")
	assert_eq(broken.y - broken.x, _tuning.break_frames, "frames the Break lasts")
	for i in range(broken.x, broken.y):
		assert_false(_rig.samples[i].attacking, "it starts nothing in sample %d of the Break" % i)
	assert_true(_rig.samples[broken.y].attacking, "it attacks again on the frame after the Break")
	assert_false(_rig.samples[broken.y].broken)


func test_it_is_tinted_while_broken_and_not_after() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range * 4.0)
	_rig.sample_also("broken", func() -> bool: return enemy.broken)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _break(enemy)
	await _rig.wait_frames(_tuning.break_frames + SETTLE_FRAMES)

	var broken := _rig.span("broken")
	for i in range(broken.x, broken.y):
		assert_eq(_rig.samples[i].look, enemy.BREAK_TINT, "tint in sample %d of the Break" % i)
	assert_ne(enemy.BREAK_TINT, enemy.WIND_UP_TINT, "the two tints should be told apart")
	assert_ne(_rig.samples[broken.y].look, enemy.BREAK_TINT, "the tint is gone once the Break is over")


func test_stagger_builds_again_after_the_break_is_over() -> void:
	var enemy = _spawn_idle_enemy()
	await _break(enemy)
	await _rig.wait_frames(_tuning.break_frames + SETTLE_FRAMES)
	assert_false(enemy.broken)

	await _swing_standin(enemy, 10.0)

	assert_almost_eq(enemy.stagger.current, 10.0, TOLERANCE)
	assert_false(enemy.broken)


func test_it_can_be_broken_again_after_a_break() -> void:
	var enemy = _spawn_idle_enemy()
	await _break(enemy)
	await _rig.wait_frames(_tuning.break_frames + SETTLE_FRAMES)

	await _break(enemy)

	assert_true(enemy.broken)


# --- The Critical hit ---

func test_a_light_press_near_a_broken_enemy_makes_the_critical_hit_on_its_timeline() -> void:
	var swing := _sword.critical_attack
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false)
	var enemy = _rig.enemy
	var sword_hitbox := almos.get_node("Sword") as Hitbox

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	var span := _span_of("attacking")
	assert_eq(span.y - span.x, swing.total_frames(), "frames the Critical hit lasts")
	for i in range(span.x, span.y):
		assert_true(_almos_samples[i].critical, "sample %d should be the Critical hit" % i)
		assert_eq(_almos_samples[i].light_swing, 0, "it is no swing of the Light combo")
	var striking := _span_of("striking")
	assert_eq(striking.x - span.x, swing.startup_frames, "frames after it begins that the Hitbox goes on")
	assert_eq(striking.y - striking.x, swing.active_frames, "frames the Hitbox is on")
	assert_false(almos.critical, "it is over")
	assert_false(sword_hitbox.critical, "the next swing is not marked as a Critical hit")
	assert_almost_eq(enemy.health.current, _tuning.health_maximum - swing.damage, TOLERANCE, "Health the Critical hit takes")
	assert_false(enemy.broken, "a Critical hit ends the Break at once")
	assert_eq(enemy.modulate, Color.WHITE, "and the tint with it")


func test_the_critical_hit_ends_the_break_in_the_frame_it_lands() -> void:
	var swing := _sword.critical_attack
	await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false)
	var enemy = _rig.enemy
	_rig.sample_also("broken", func() -> bool: return enemy.broken)

	await _tap(&"attack_light")
	await _rig.wait_frames(swing.startup_frames + swing.active_frames + SETTLE_FRAMES)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the Critical hit lands once")
	assert_false(_rig.samples[hits[0].sample].broken, "the Break is over in the sample that first shows the hit")
	assert_true(_rig.samples[hits[0].sample - 1].broken, "and it was not over before it")


func test_the_critical_hit_builds_no_stagger_from_any_side(params = use_parameters(side_params)) -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, params.from_behind)
	var enemy = _rig.enemy

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE, "Stagger the Critical hit builds from %s" % params.side)
	assert_lt(enemy.health.current, _tuning.health_maximum, "the Critical hit should have landed")


func test_the_critical_hit_costs_no_stamina() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false, _tuning_with_long_refill_pause())
	var before: float = almos.stamina.current

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_true(_almos_samples.any(func(sample: Dictionary) -> bool: return sample.critical), "the Critical hit should have been made")
	assert_almost_eq(almos.stamina.current, before, TOLERANCE)


func test_the_critical_hit_is_made_at_zero_stamina() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false, _tuning_with_long_refill_pause())
	almos.stamina.spend(almos.stamina.maximum)
	assert_almost_eq(almos.stamina.current, 0.0, TOLERANCE)

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_true(_almos_samples.any(func(sample: Dictionary) -> bool: return sample.critical), "the Critical hit should have been made")
	assert_almost_eq(_rig.enemy.health.current, _tuning.health_maximum - _sword.critical_attack.damage, TOLERANCE)


func test_a_light_press_near_a_broken_enemy_is_the_critical_hit_just_inside_the_range_and_a_light_swing_just_outside(params = use_parameters(range_params)) -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * (_sword.critical_range + params.offset), false)

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	var began := _span_of("attacking").x
	assert_ne(began, -1, "he should have swung")
	assert_eq(_almos_samples[began].critical, params.critical, "whether the swing is the Critical hit, %s" % params.where)
	assert_eq(_almos_samples[began].light_swing, 0 if params.critical else 1, "which swing of the combo, %s" % params.where)
	assert_eq(_rig.enemy.broken, not params.critical, "whether the Break was ended, %s" % params.where)
	assert_eq(_span_of("attacking").y - began, (_sword.critical_attack if params.critical else _sword.light_attacks[0]).total_frames(), "frames the swing lasts, %s" % params.where)


func test_a_light_press_near_an_enemy_that_is_not_broken_is_an_ordinary_light_swing() -> void:
	var almos = _spawn_almos_above_the_enemy(false)

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	var began := _span_of("attacking").x
	assert_false(_almos_samples[began].critical)
	assert_eq(_almos_samples[began].light_swing, 1)
	assert_almost_eq(_rig.enemy.health.current, _tuning.health_maximum - _sword.light_attacks[0].damage, TOLERANCE)


func test_a_heavy_press_near_a_broken_enemy_is_an_ordinary_heavy_attack() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false)
	var enemy = _rig.enemy

	await _tap(&"attack_heavy")
	await _wait_for_the_swing_to_end(almos)

	assert_false(_almos_samples.any(func(sample: Dictionary) -> bool: return sample.critical), "no Critical hit was made")
	assert_true(enemy.broken, "an ordinary Heavy attack does not end the Break")
	assert_almost_eq(enemy.health.current, _tuning.health_maximum - _sword.heavy_attack.damage, TOLERANCE, "it hits as a Heavy attack does")
	assert_almost_eq(enemy.stagger.current, 0.0, TOLERANCE, "and builds no Stagger in a Break")


func test_a_light_press_kept_in_the_buffer_window_becomes_the_critical_hit_when_a_broken_enemy_is_in_range() -> void:
	var swing := _sword.light_attacks[0]
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * (_sword.critical_range * 3.0), false)
	var enemy = _rig.enemy
	await _tap(&"attack_light")
	await _wait_for_a_swing_frame(swing.total_frames() - _sword.attack_buffer_frames)
	# It comes into range after the swing has begun, before the press is made.
	enemy.global_position = almos.global_position + Vector2.DOWN * ENEMY_DISTANCE

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	var begun := _span_of("attacking").x
	var critical_began := _span_of("critical").x
	assert_false(_almos_samples[begun].critical, "the first swing is an ordinary Light swing")
	assert_eq(critical_began - begun, swing.total_frames(), "the kept press makes the Critical hit as the first swing ends")
	assert_eq(_almos_samples[critical_began].light_swing, 0)
	assert_almost_eq(enemy.health.current, _tuning.health_maximum - _sword.critical_attack.damage, TOLERANCE, "Health left after the Critical hit")
	assert_false(enemy.broken)


func test_the_critical_hit_restarts_the_light_combo() -> void:
	var first := _sword.light_attacks[0]
	var second := _sword.light_attacks[1]
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * (_sword.critical_range * 3.0), false)
	var enemy = _rig.enemy
	await _tap(&"attack_light")
	await _wait_for_a_swing_frame(first.total_frames() - _sword.attack_buffer_frames)
	await _tap(&"attack_light")
	await _wait_for_a_swing_frame(first.total_frames() + second.total_frames() - _sword.attack_buffer_frames)
	assert_eq(almos.light_swing, 2, "the second swing of the combo should be under way")
	enemy.global_position = almos.global_position + Vector2.DOWN * ENEMY_DISTANCE

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)
	assert_true(_almos_samples.any(func(sample: Dictionary) -> bool: return sample.critical), "the Critical hit should have been made")
	assert_eq(almos.light_swing, 0)
	await _tap(&"attack_light")
	await _rig.wait_frames(SETTLE_FRAMES)

	assert_eq(almos.light_swing, 1, "the next Light attack starts the combo over")
	assert_false(almos.critical)


func test_with_two_broken_enemies_in_range_it_goes_for_the_nearer_at_its_true_angle_and_faces_it() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.RIGHT.rotated(deg_to_rad(ODD_ANGLE_DEGREES)) * ENEMY_DISTANCE, false)
	var nearer = _rig.enemy
	var farther = _spawn_idle_enemy_at(-nearer.position.normalized() * (ENEMY_DISTANCE + 10.0))
	await _break(farther)
	assert_true(farther.broken)
	var sword_hitbox := almos.get_node("Sword") as Hitbox

	await _tap(&"attack_light")
	await _rig.wait_frames(_sword.critical_attack.startup_frames)

	assert_almost_eq(sword_hitbox.rotation, deg_to_rad(ODD_ANGLE_DEGREES), ANGLE_TOLERANCE, "the swing is aimed at the enemy exactly")
	assert_almost_eq(almos.facing, Vector2.from_angle(deg_to_rad(SNAPPED_ANGLE_DEGREES)), Vector2.ONE * FACING_TOLERANCE, "he faces it, to the nearest of eight directions")
	await _wait_for_the_swing_to_end(almos)
	assert_false(nearer.broken, "the nearer one is the one that was hit")
	assert_almost_eq(nearer.health.current, _tuning.health_maximum - _sword.critical_attack.damage, TOLERANCE)


func test_with_two_broken_enemies_the_nearer_is_chosen_whichever_comes_first_in_the_tree() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * (ENEMY_DISTANCE + 10.0), false)
	var farther = _rig.enemy
	var nearer = _spawn_idle_enemy_at(Vector2.UP * ENEMY_DISTANCE)
	await _break(nearer)
	var sword_hitbox := almos.get_node("Sword") as Hitbox

	await _tap(&"attack_light")
	await _rig.wait_frames(_sword.critical_attack.startup_frames)

	assert_almost_eq(sword_hitbox.rotation, -PI / 2.0, ANGLE_TOLERANCE, "the swing is aimed at the nearer, above him")
	await _wait_for_the_swing_to_end(almos)
	assert_false(nearer.broken)
	assert_true(farther.broken, "the farther one is left alone, out of the swing's way")


func test_under_lock_on_to_another_enemy_it_still_goes_for_the_broken_one() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false)
	var broken = _rig.enemy
	var locked_on = _spawn_idle_enemy_at(Vector2.UP * (ENEMY_DISTANCE - 10.0))
	var sword_hitbox := almos.get_node("Sword") as Hitbox
	await _tap(&"lock_on")
	assert_eq(almos.lock_on_target, locked_on, "he should have locked on to the nearer enemy, which is not broken")

	await _tap(&"attack_light")
	await _rig.wait_frames(_sword.critical_attack.startup_frames)

	assert_almost_eq(sword_hitbox.rotation, PI / 2.0, ANGLE_TOLERANCE, "the swing is aimed at the broken enemy, not the locked one")
	await _wait_for_the_swing_to_end(almos)
	assert_false(broken.broken)
	assert_almost_eq(broken.health.current, _tuning.health_maximum - _sword.critical_attack.damage, TOLERANCE)
	assert_almost_eq(locked_on.health.current, _tuning.health_maximum, TOLERANCE, "the locked enemy is not hit")
	assert_true(almos.locked_on, "the lock holds")


func test_under_lock_on_he_faces_the_broken_enemy_for_the_whole_critical_hit_and_the_locked_one_after() -> void:
	var almos = await _spawn_almos_and_broken_enemy(Vector2.DOWN * ENEMY_DISTANCE, false)
	_spawn_idle_enemy_at(Vector2.UP * (ENEMY_DISTANCE - 10.0))
	await _tap(&"lock_on")
	assert_almost_eq(almos.facing, Vector2.UP, Vector2.ONE * FACING_TOLERANCE, "locked on, he faces the enemy above him")
	var swing := _sword.critical_attack

	await _tap(&"attack_light")
	await _rig.wait_frames(swing.startup_frames)
	assert_true(almos.critical)
	assert_almost_eq(almos.facing, Vector2.DOWN, Vector2.ONE * FACING_TOLERANCE, "mid-swing he faces the broken enemy")
	# Every frame to the last of the recovery, he still faces the broken enemy.
	var frames := 0
	while almos.critical and frames < WAIT_FRAME_LIMIT:
		assert_almost_eq(almos.facing, Vector2.DOWN, Vector2.ONE * FACING_TOLERANCE, "facing %d frames in" % frames)
		await get_tree().physics_frame
		frames += 1
	assert_false(almos.critical, "the swing should end")
	assert_true(almos.locked_on, "the lock holds")
	assert_almost_eq(almos.facing, Vector2.UP, Vector2.ONE * FACING_TOLERANCE, "he faces the locked enemy again once the swing is over")


# --- Helpers ---

# An enemy at the origin, turned to face down towards a stand-in too far off to notice, so that
# it attacks no one. It is sampled.
func _spawn_idle_enemy():
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.DOWN * (_tuning.notice_range + BEYOND_NOTICE))
	return enemy


# Another enemy, not sampled, standing here and facing down towards a stand-in too far off to
# notice.
func _spawn_idle_enemy_at(at: Vector2):
	var scene := load(EnemyRig.ENEMY_SCENE_PATH) as PackedScene
	var enemy = scene.instantiate()
	enemy.position = at
	var far := Node2D.new()
	far.position = at + Vector2.DOWN * (_tuning.notice_range + BEYOND_NOTICE)
	add_child_autofree(far)
	enemy.target = far
	add_child_autofree(enemy)
	return enemy


# Almos at the origin facing down with the enemy below him, going after a stand-in too far off
# to notice, so that the enemy never swings at Almos. The stand-in is below it if the enemy has
# its back to Almos, and above it, in Almos's direction, if it faces him.
func _spawn_almos_above_the_enemy(enemy_has_its_back_to_him: bool, tuning: PlayerTuning = null):
	var almos = _almos_input.spawn_almos(tuning)
	var enemy = _rig.spawn_enemy(null, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	var away := Vector2.DOWN if enemy_has_its_back_to_him else Vector2.UP
	_rig.place_target(enemy.position + away * (_tuning.notice_range + BEYOND_NOTICE))
	_sample_almos(almos)
	return almos


# As above, with the enemy at this offset from Almos, and broken.
func _spawn_almos_and_broken_enemy(offset: Vector2, enemy_has_its_back_to_him: bool, tuning: PlayerTuning = null):
	var almos = _almos_input.spawn_almos(tuning)
	var enemy = _rig.spawn_enemy(null, almos.position + offset)
	var away := Vector2.DOWN if enemy_has_its_back_to_him else Vector2.UP
	_rig.place_target(enemy.position + away * (_tuning.notice_range + BEYOND_NOTICE))
	_sample_almos(almos)
	await _rig.wait_frames(SETTLE_FRAMES)
	await _break(enemy)
	return almos


func _tuning_with_long_refill_pause() -> PlayerTuning:
	var changed := _player.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as PlayerTuning
	changed.stamina_refill_pause = LONG_REFILL_PAUSE
	return changed


# Breaks the enemy with a hit from a stand-in that builds a full meter, in front of it.
func _break(enemy) -> void:
	await _swing_standin(enemy, _tuning.stagger_capacity)
	assert_true(enemy.broken, "the hit should have broken it")


# A stand-in Hitbox that covers only this enemy lands a hit on it that builds this much
# Stagger and takes this much Health, from in front of it (the way it faces, down) or from
# behind.
func _swing_standin(enemy, stagger: float, damage := NO_DAMAGE, from_behind := false) -> void:
	var hitbox := _standin_over(enemy, stagger, damage, from_behind)
	# Settled in the physics server before it is switched on.
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)


func _standin_over(enemy, stagger: float, damage: float, from_behind: bool) -> Hitbox:
	var hitbox := _rig.hitbox_over(enemy, damage, "enemy_hurtbox")
	((hitbox.get_child(0) as CollisionShape2D).shape as CircleShape2D).radius = NARROW_HITBOX_RADIUS
	hitbox.global_position = enemy.global_position + (Vector2.UP if from_behind else Vector2.DOWN) * NARROW_HITBOX_RADIUS
	hitbox.stagger = stagger
	return hitbox


# Parries the swing the enemy is about to make or has begun. The press is timed so that the
# window is open over the middle of the enemy's active frames. Returns once the hit has been
# parried and Almos is free.
func _parry_the_swing() -> void:
	var swing := _tuning.attack
	await _wait_until_the_enemy_is(_rig.enemy, "winding_up")
	await _rig.wait_frames(swing.startup_frames - _player.parry_window_frames / 2 - 1)
	var health_before := _rig.target_health.current
	await _tap(&"parry")
	await _rig.wait_frames(_player.parry_window_frames + SETTLE_FRAMES)
	assert_almost_eq(_rig.target_health.current, health_before, TOLERANCE, "the swing should have been parried, not landed")


func _wait_until_the_enemy_is(enemy, state: String) -> void:
	for i in WAIT_FRAME_LIMIT:
		if enemy.get(state):
			return
		await get_tree().physics_frame
	fail_test("the enemy should be %s" % state)


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Waits for a swing to begin, if one has not, and be over.
func _wait_for_the_swing_to_end(almos) -> void:
	await _rig.wait_frames(SETTLE_FRAMES)
	for i in WAIT_FRAME_LIMIT:
		if not almos.attacking and not almos.charging:
			return
		await get_tree().physics_frame
	fail_test("the swing should be over")


# Waits until a press made now is seen at this frame of the run of swings under way, the first
# frame of the first swing being 0. In a combo the count runs on from one swing into the next.
# A button pressed by a test is seen as just pressed by the frame after the one it was pressed in.
func _wait_for_a_swing_frame(swing_frame: int) -> void:
	var begun := _span_of("attacking").x
	assert_ne(begun, -1, "the swing should have begun")
	for i in WAIT_FRAME_LIMIT:
		if _almos_samples.size() - 1 >= begun - 2 + swing_frame:
			return
		await get_tree().physics_frame
	fail_test("the swing should have got to frame %d" % swing_frame)


func _sample_almos(almos) -> void:
	_sampled_almos = almos
	get_tree().physics_frame.connect(_take_almos_sample)


func _take_almos_sample() -> void:
	if not is_instance_valid(_sampled_almos):
		return
	_almos_samples.append({
		"attacking": _sampled_almos.attacking,
		"critical": _sampled_almos.critical,
		"light_swing": _sampled_almos.light_swing,
		"striking": (_sampled_almos.get_node("Sword") as Hitbox).active,
	})


# The first stretch of Almos's samples in which this is true, as Vector2i(first, end): the
# index of the first sample showing it and of the first showing it over, or -1 for either if it
# has not happened yet.
func _span_of(state: String) -> Vector2i:
	var first := -1
	for i in _almos_samples.size():
		if first == -1 and _almos_samples[i][state]:
			first = i
		elif first != -1 and not _almos_samples[i][state]:
			return Vector2i(first, i)
	return Vector2i(first, -1)
