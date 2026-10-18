extends GutTest
## The training enemy's Low attack, seen only through the scenes. The real enemy scene runs with
## its shipped tuning (or a copy a test changes), with a stand-in target to go after, or with the
## real Almos scene driven through input. Every physics frame a sample is taken, so what
## happened can be read back frame by frame: a sample is taken at the start of the frame, before
## anything has moved in it, so it shows how the frame before left things. Expected numbers come
## from the data files the scenes use and plain arithmetic, never from how the code works them
## out. The Strike is the enemy's existing attack, in the tuning as attack and attack_reach.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyFight := preload("res://test/helpers/enemy_fight.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const STRIKE := EnemyTuning.AttackKind.STRIKE
const LOW := EnemyTuning.AttackKind.LOW

# In Health points.
const TOLERANCE := 0.0001
# In pixels.
const POSITION_TOLERANCE := 0.01
# In pixels. How far below Almos the enemy stands: close enough for each to reach the other with
# a swing, and clear of each other's bodies. Almos starts out facing down.
const ENEMY_DISTANCE := 30.0
# A tap: held this many physics frames, far shorter than a swing or a Jump.
const TAP_FRAMES := 2
# In physics frames. How long the test runs after the exchange it is about, to let it play out.
const SETTLE_FRAMES := 10
# In seconds. Slack for the float sums that decide which frame a time falls in.
const FRAME_SLACK := 0.001
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 400
# How different, as the sum of the differences in red, green and blue, one look of the enemy
# must be from another for the player to tell them apart.
const VISIBLE_DIFFERENCE := 0.5
# In pixels. How far inside or beyond the Low attack's far edge a target's Hurtbox is put, when
# the swing is to catch it or just miss it.
const REACH_MARGIN := 1.0
# In pixels. How far a test moves the Low attack's reach from the one in the data file.
const REACH_LONGER_BY := 20.0
const REACH_SHORTER_BY := 10.0
# How many attacks the order is watched for: a few rounds of the shipped order.
const ATTACKS_WATCHED := 5

# How the Low attack's reach is retuned from the one in the data file, how far beyond its far
# edge the nearest edge of the target's Hurtbox is put (a negative number is inside it), and
# whether the target is then hit.
var reach_params = ParameterFactory.named_parameters(
	["retune", "beyond_far_edge", "hits"],
	[
		[REACH_LONGER_BY, -REACH_MARGIN, true],
		[REACH_LONGER_BY, REACH_MARGIN, false],
		[-REACH_SHORTER_BY, -REACH_MARGIN, true],
		[-REACH_SHORTER_BY, REACH_MARGIN, false],
	],
)

# Which place in the shipped order a Break comes in the wind-up of: the first attack or the
# second. Which attack the enemy makes next is read from the order.
var break_params = ParameterFactory.named_parameters(
	["place"],
	[[0], [1]],
)

var _almos_input: AlmosInput
var _rig: EnemyRig
var _fight: EnemyFight
var _tuning: EnemyTuning
var _player: PlayerTuning


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)
	_fight = EnemyFight.new(self, _almos_input, _rig)
	_tuning = _rig.tuning_with()
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- The enemy alone ---

func test_it_makes_a_strike_and_a_low_attack_in_turn_over_and_over() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	_rig.sample_also("kind", func(): return enemy.attack_kind)
	# Two rounds of the shipped order and the start of a third, whatever the order is.
	var pattern := _tuning.attack_pattern
	assert_gt(pattern.size(), 0, "the shipped order should not be empty")
	var order: Array[EnemyTuning.AttackKind] = []
	for i in pattern.size() * 2 + 1:
		order.append(pattern[i % pattern.size()])
	var length := 0
	for kind in order:
		length += _tuning.attack_of(kind).total_frames()

	await _rig.wait_frames(length + SETTLE_FRAMES)

	# Each attack begins the very frame the one before it ends. The sample showing the first
	# frame of an attack is the one after the frame it began in.
	var first := _rig.first_sample_where("attacking")
	assert_ne(first, -1, "it should have attacked")
	var began := first
	var damages: Array[float] = []
	for kind in order:
		assert_eq(_rig.samples[began].kind, kind, "the kind of the attack that began in sample %d" % began)
		damages.append(_tuning.attack_of(kind).damage)
		began += _tuning.attack_of(kind).total_frames()
	var taken: Array[float] = []
	for hit in _rig.hits():
		taken.append(hit.damage)
	assert_eq(taken, damages, "the hits the target took, one for each attack")


func test_the_shipped_order_has_a_low_attack_in_it_and_the_two_attacks_differ_in_damage() -> void:
	assert_true(_tuning.attack_pattern.has(LOW), "the shipped order should have the Low attack in it")
	assert_true(_tuning.attack_pattern.has(STRIKE), "the shipped order should have the Strike in it")
	assert_ne(_tuning.attack.damage, _tuning.low_attack.damage, "the two attacks should be told apart by their damage")


func test_a_break_leaves_the_order_where_it_was(params = use_parameters(break_params)) -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range / 2.0)
	_rig.sample_also("kind", func(): return enemy.attack_kind)
	_rig.sample_also("broken", func() -> bool: return enemy.broken)
	# The Hitbox that breaks it is in the tree after the enemy, so it is processed after the
	# enemy in a frame.
	var breaker := _rig.hitbox_over(enemy, 0.0, "enemy_hurtbox")
	breaker.stagger = _tuning.stagger_capacity
	var pattern := _tuning.attack_pattern
	assert_gt(pattern.size(), 1, "the shipped order should have more than one attack for a Break to leave it in the middle of")
	await _wait_until_the_enemy_is(enemy, "winding_up")
	for i in params.place:
		await _rig.wait_frames(_tuning.attack_of(pattern[i]).total_frames())
	var next_kind := pattern[(params.place + 1) % pattern.size()]
	assert_eq(enemy.attack_kind, pattern[params.place], "the attack it is winding up")
	assert_true(enemy.winding_up, "it should be winding up the attack the Break is to come in")
	await _rig.wait_frames(1)

	await _rig.swing(breaker, 1)
	await _rig.wait_frames(_tuning.break_frames + _tuning.attack_of(next_kind).total_frames())

	var broken := _rig.span("broken")
	assert_ne(broken.x, -1, "it should have been broken")
	assert_true(_rig.samples[broken.y].attacking, "it attacks again once the Break is over")
	assert_eq(_rig.samples[broken.y].kind, next_kind, "the kind of attack it makes once the Break is over")


func test_its_low_attack_has_its_own_timeline_and_its_own_damage() -> void:
	var low := _tuning.low_attack
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([LOW])})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(low.total_frames() + SETTLE_FRAMES)

	var attacking := _rig.span("attacking")
	var winding := _rig.span("winding_up")
	var striking := _rig.span("striking")
	assert_eq(winding.x, attacking.x, "its wind-up begins with the attack")
	assert_eq(winding.y - winding.x, low.startup_frames, "frames its wind-up lasts")
	assert_eq(striking.x - attacking.x, low.startup_frames, "frames from the start of the attack to the strike")
	assert_eq(striking.y - striking.x, low.active_frames, "frames its Hitbox is on")
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits the target took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, low.damage, TOLERANCE)
		assert_gte(hits[0].sample, striking.x, "the hit lands once its Hitbox is on")
	assert_ne(low.total_frames(), _tuning.attack.total_frames(), "the two timelines should differ for this test to tell them apart")


func test_its_low_attack_reaches_as_far_as_the_low_attack_reach_in_the_tuning(params = use_parameters(reach_params)) -> void:
	var reach: float = _tuning.low_attack_reach + params.retune
	# The nearest edge of the target's Hurtbox is this far beyond the swing's far edge. It is in
	# range to swing at, so that nothing but the reach decides the hit.
	var distance: float = reach + EnemyRig.TARGET_RADIUS + params.beyond_far_edge
	var tuning := _rig.tuning_with({"low_attack_reach": reach, "attack_range": distance, "attack_pattern": _pattern([LOW])})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * distance)

	await _rig.wait_frames(tuning.low_attack.total_frames())

	assert_eq(_rig.hits().size() == 1, params.hits, "whether the target was hit")


func test_it_swings_its_low_attack_from_close_enough_for_it_to_reach_almos() -> void:
	var almos := autofree((load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene).instantiate()) as Node
	var hurtbox_shape := (almos.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_not_null(hurtbox_shape, "Almos's Hurtbox should be a circle")
	if hurtbox_shape == null:
		return

	assert_lte(_tuning.attack_range - hurtbox_shape.radius, _tuning.low_attack_reach, "how far the nearest edge of Almos's Hurtbox is when it swings, against how far its Low attack reaches")


func test_what_is_drawn_of_its_low_attack_covers_the_box_that_hurts_and_is_wider_than_the_strikes() -> void:
	var reach := _tuning.low_attack_reach + REACH_LONGER_BY
	var enemy = _rig.spawn_enemy(_rig.tuning_with({"low_attack_reach": reach}))
	var low_hitbox := _low_hitbox_of(enemy)
	var real := StrikeGeometry.real_box(low_hitbox)
	var drawn := StrikeGeometry.drawn_box(low_hitbox)
	var strike_box := StrikeGeometry.real_box(enemy.get_node("Hitbox") as Hitbox)

	assert_almost_eq(real.end.x, reach, POSITION_TOLERANCE, "how far out the box that hurts ends")
	assert_almost_eq(drawn.position, real.position, Vector2.ONE * POSITION_TOLERANCE, "where the drawn swing starts, against the box that hurts")
	assert_almost_eq(drawn.size, real.size, Vector2.ONE * POSITION_TOLERANCE, "the size of the drawn swing, against the box that hurts")
	assert_gt(real.size.y, strike_box.size.y, "the Low attack should sweep a wider box than the Strike")


func test_only_its_low_attack_hits_with_a_low_hitbox() -> void:
	var enemy = _rig.spawn_enemy()

	assert_true(_low_hitbox_of(enemy).low, "the Low attack's Hitbox is low")
	assert_false((enemy.get_node("Hitbox") as Hitbox).low, "the Strike's Hitbox is not")


func test_its_low_wind_up_has_a_tint_of_its_own_that_shows_only_in_a_low_wind_up() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	_rig.sample_also("kind", func(): return enemy.attack_kind)
	var cycle := 0
	for kind in _tuning.attack_pattern:
		cycle += _tuning.attack_of(kind).total_frames()
	await _rig.wait_frames(cycle + SETTLE_FRAMES)

	var low_winding := 0
	var strike_winding := 0
	# One round of the order: from the first frame of the first attack to the last of the last.
	var first := _rig.first_sample_where("attacking")
	for i in range(first, first + cycle):
		var sample: Dictionary = _rig.samples[i]
		var in_low_wind_up: bool = sample.winding_up and sample.kind == LOW
		var in_strike_wind_up: bool = sample.winding_up and sample.kind == STRIKE
		low_winding += 1 if in_low_wind_up else 0
		strike_winding += 1 if in_strike_wind_up else 0
		assert_eq(sample.look == enemy.LOW_WIND_UP_TINT, in_low_wind_up, "whether it shows the Low wind-up tint in sample %d" % i)
		assert_eq(sample.look == enemy.WIND_UP_TINT, in_strike_wind_up, "whether it shows the Strike wind-up tint in sample %d" % i)
	assert_eq(low_winding, _tuning.low_attack.startup_frames * _tuning.attack_pattern.count(LOW), "samples of the Low wind-up in a round")
	assert_eq(strike_winding, _tuning.attack.startup_frames * _tuning.attack_pattern.count(STRIKE), "samples of the Strike wind-up in a round")
	assert_eq(_rig.samples[first - 1].look, Color.WHITE, "it looks as at rest before it attacks")
	assert_gte(_difference(enemy.LOW_WIND_UP_TINT, enemy.WIND_UP_TINT), VISIBLE_DIFFERENCE, "the Low tint should look clearly different from the Strike's")
	assert_gte(_difference(enemy.LOW_WIND_UP_TINT, enemy.BREAK_TINT), VISIBLE_DIFFERENCE, "the Low tint should look clearly different from the Break's")
	assert_gte(_difference(enemy.LOW_WIND_UP_TINT, Color.WHITE), VISIBLE_DIFFERENCE, "the Low tint should look clearly different from none")


func test_it_shows_its_low_swing_only_while_its_hitbox_is_on() -> void:
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([LOW])})
	var enemy = _rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	var low_hitbox := _low_hitbox_of(enemy)
	_rig.sample_also("low_shown", func() -> bool: return low_hitbox.visible)
	_rig.sample_also("low_on", func() -> bool: return low_hitbox.active)
	_rig.sample_also("strike_on", func() -> bool: return (enemy.get_node("Hitbox") as Hitbox).active)

	await _rig.wait_frames(tuning.low_attack.total_frames() + SETTLE_FRAMES)

	var on := _rig.span("low_on")
	assert_eq(on.y - on.x, tuning.low_attack.active_frames, "frames its Low Hitbox is on")
	var out_of_step := []
	for i in _rig.samples.size():
		if _rig.samples[i].low_shown != _rig.samples[i].low_on:
			out_of_step.append(i)
		assert_false(_rig.samples[i].strike_on, "the Strike's Hitbox stays off in a Low attack (sample %d)" % i)
	assert_eq(out_of_step, [], "samples in which the Low swing is shown and its Hitbox is on do not agree")


func test_it_commits_its_low_attack_to_the_direction_it_began_it_in() -> void:
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([LOW])})
	_rig.spawn_enemy(tuning)
	var target := _rig.place_target(Vector2.RIGHT * tuning.attack_range)
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(_rig.enemy.winding_up, "it should be winding up")

	# The target goes round behind it, still in its attack range, before the swing is on.
	target.global_position = Vector2.LEFT * tuning.attack_range
	await _rig.wait_frames(tuning.low_attack.total_frames())

	assert_eq(_rig.hits().size(), 0, "the swing goes where the target was, not where it is")


# --- Against Almos ---

func test_a_low_attack_hits_almos_when_he_is_on_the_ground() -> void:
	var low := _tuning.low_attack
	var almos = _spawn_fight_with_low_attacks()

	await _rig.wait_frames(low.total_frames() + SETTLE_FRAMES)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum - low.damage, TOLERANCE)


func test_a_low_attack_misses_almos_who_is_in_the_air_through_all_of_its_active_frames() -> void:
	var low := _tuning.low_attack
	var almos = _spawn_fight_with_low_attacks()
	# His Jump is centred on the swing's active frames.
	var jump_frames := _jump_frames()
	assert_gt(jump_frames, low.active_frames + 2, "his Jump should outlast the swing's active frames, with a frame to spare each side")
	await _rig.wait_frames(maxi(0, low.startup_frames + low.active_frames / 2 - jump_frames / 2))
	await _tap(&"jump")

	await _play_out_the_first_attack(low)

	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its Hitbox should have gone on")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].airborne, "he should be in the air in sample %d, in which its Hitbox is on" % i)
	assert_eq(_rig.hits().size(), 0, "hits Almos took")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE)


func test_a_low_attack_still_on_catches_almos_who_lands_while_it_is_active() -> void:
	var low := _tuning.low_attack
	var almos = _spawn_fight_with_low_attacks()
	# His Jump ends in the middle of the swing's active frames.
	var jump_frames := _jump_frames()
	var press_after := low.startup_frames + low.active_frames / 2 - jump_frames
	assert_gte(press_after, 0, "the swing should not begin before his Jump can have started")
	await _rig.wait_frames(maxi(0, press_after))
	await _tap(&"jump")

	await _play_out_the_first_attack(low)

	var striking := _rig.span("striking")
	assert_true(_rig.samples[striking.x].airborne, "he should be in the air when its Hitbox goes on")
	assert_false(_rig.samples[striking.y - 1].airborne, "he should be on the ground before its Hitbox goes off")
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, low.damage, TOLERANCE)
		var landed_at: int = hits[0].sample
		assert_true(landed_at >= striking.x and landed_at <= striking.y, "the hit should land while its Hitbox is on, in sample %d (on from %d to %d)" % [landed_at, striking.x, striking.y])
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum - low.damage, TOLERANCE)


func test_the_strike_still_hits_almos_in_the_air() -> void:
	var strike := _tuning.attack
	var almos = _almos_input.spawn_almos()
	_rig.spawn_enemy(_rig.tuning_with({"attack_pattern": _pattern([STRIKE])}), almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	_rig.sample_also("airborne", func() -> bool: return almos.airborne)
	var jump_frames := _jump_frames()
	await _rig.wait_frames(maxi(0, strike.startup_frames + strike.active_frames / 2 - jump_frames / 2))
	await _tap(&"jump")

	await _play_out_the_first_attack(strike)

	var striking := _rig.span("striking")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].airborne, "he should be in the air in sample %d, in which its Hitbox is on" % i)
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum - strike.damage, TOLERANCE, "a Jump is no defence against anything but a Low attack")


func test_a_low_attack_misses_almos_who_is_untouchable_in_a_roll_through_all_of_its_active_frames() -> void:
	var low := _tuning.low_attack
	# A Roll that carries him nowhere, so that he stays under the swing for all of it.
	var rolling_on_the_spot := _player.duplicate() as PlayerTuning
	rolling_on_the_spot.roll_distance = 0.0
	var almos = _almos_input.spawn_almos(rolling_on_the_spot)
	_rig.spawn_enemy(_rig.tuning_with({"attack_pattern": _pattern([LOW])}), almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	_rig.sample_also("untouchable", func() -> bool: return almos.untouchable)
	await _rig.wait_frames(_frames_to_wait_before_tapping_roll(low, rolling_on_the_spot))

	await _tap(&"roll")
	await _play_out_the_first_attack(low)

	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its Hitbox should have gone on")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].untouchable, "he should be untouchable in sample %d, in which its Hitbox is on" % i)
	assert_eq(_rig.hits().size(), 0, "hits Almos took")


func test_a_blocked_low_attack_deals_the_reduced_damage() -> void:
	var low := _tuning.low_attack
	var almos = _spawn_fight_with_low_attacks()
	_almos_input.press_action(&"block")

	await _rig.wait_frames(low.total_frames() + SETTLE_FRAMES)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, low.damage * (1.0 - _player.block_damage_reduction), TOLERANCE)


func test_a_parried_low_attack_is_negated_and_builds_the_parry_stagger() -> void:
	var almos = _spawn_fight_with_low_attacks()

	await _fight.parry_the_swing(_player)

	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE, "a parried Low attack should do no damage")
	assert_almost_eq(_rig.enemy.stagger.current, _player.parry_stagger, TOLERANCE, "Stagger the Parry built")


# The enemy given only Low attacks to make, a little way below Almos, after him, and sampled.
# Almos is sampled too, for whether he is in the air.
func _spawn_fight_with_low_attacks():
	var almos = _almos_input.spawn_almos()
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([LOW])})
	_rig.spawn_enemy(tuning, almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	_rig.sample_also("airborne", func() -> bool: return almos.airborne)
	return almos


# Waits until the first attack of the enemy is over and a few frames more, but not so long that
# the next has struck, counting the frames from the start of the test.
func _play_out_the_first_attack(attack: AttackData) -> void:
	while _rig.samples.size() < attack.total_frames() + SETTLE_FRAMES:
		await get_tree().physics_frame


# How many physics frames to wait before tapping Roll so that his untouchable window covers all
# the frames the attack's Hitbox is on. A tap is TAP_FRAMES of the button held; after n waits the
# test is at the start of frame n - 1, so the Roll starts in frame R = n - 1 + TAP_FRAMES, and
# he is untouchable in frames R - 1 + k_open .. R - 1 + k_close - 1, where k_open and k_close
# are the Roll steps (a frame each) the window opens and closes after. The Hitbox is on in
# frames startup .. startup + active - 1. R is taken in the middle of what covers them.
func _frames_to_wait_before_tapping_roll(attack: AttackData, player: PlayerTuning) -> int:
	var frames_a_second := float(Engine.physics_ticks_per_second)
	var k_open := ceili(player.roll_untouchable_start * frames_a_second - FRAME_SLACK)
	var k_close := ceili((player.roll_untouchable_start + player.roll_untouchable_duration) * frames_a_second - FRAME_SLACK)
	var first_active := attack.startup_frames
	var last_active := attack.startup_frames + attack.active_frames - 1
	var latest_roll_start := first_active + 1 - k_open
	var earliest_roll_start := last_active + 2 - k_close
	assert_lte(earliest_roll_start, latest_roll_start, "his untouchable window should be at least as long as the Low attack's active frames, or no Roll can cover them")
	var roll_start := floori((earliest_roll_start + latest_roll_start) / 2.0)
	return roll_start - TAP_FRAMES + 1


# How many physics frames a Jump keeps him in the air, from the tuning.
func _jump_frames() -> int:
	return ceili(_player.jump_duration * Engine.physics_ticks_per_second - 0.0001)


func _pattern(kinds: Array) -> Array[EnemyTuning.AttackKind]:
	var pattern: Array[EnemyTuning.AttackKind] = []
	pattern.assign(kinds)
	return pattern


func _low_hitbox_of(enemy) -> Hitbox:
	return enemy.get_node("LowHitbox") as Hitbox


func _wait_until_the_enemy_is(enemy, state: String) -> void:
	for i in WAIT_FRAME_LIMIT:
		if enemy.get(state):
			return
		await get_tree().physics_frame
	fail_test("the enemy should be %s" % state)


# Presses this button and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# How different two colours are: the differences in red, green and blue added up.
func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
