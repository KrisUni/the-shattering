extends GutTest
## The training enemy's Unblockable attack, seen only through the scenes. The real enemy scene
## runs with its shipped tuning (or a copy a test changes), with a stand-in target to go after, or
## with the real Almos scene driven through input. Every physics frame a sample is taken, so what
## happened can be read back frame by frame: a sample is taken at the start of the frame, before
## anything has moved in it, so it shows how the frame before left things. Expected numbers come
## from the data files the scenes use and plain arithmetic, never from how the code works them
## out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const STRIKE := EnemyTuning.AttackKind.STRIKE
const LOW := EnemyTuning.AttackKind.LOW
const UNBLOCKABLE := EnemyTuning.AttackKind.UNBLOCKABLE

# In Health points.
const TOLERANCE := 0.0001
# In pixels.
const POSITION_TOLERANCE := 0.01
# In pixels. How far below Almos the enemy stands: close enough for each to reach the other with
# a swing, and clear of each other's bodies. Almos starts out facing down.
const ENEMY_DISTANCE := 30.0
# A tap: held this many physics frames, far shorter than a swing or a Jump.
const TAP_FRAMES := 2
# In physics frames. How many frames after the last of the swing's active frames his Jump ends,
# when it is timed to end just after them.
const JUMP_LANDS_AFTER_BY := 2
# In pixels. How much closer than its attack range he starts, to be sure it swings at him.
const IN_RANGE_BY := 1.0
# In physics frames. How long the test runs after the exchange it is about, to let it play out.
const SETTLE_FRAMES := 10
# In seconds. Slack for the float sums that decide which frame a time falls in.
const FRAME_SLACK := 0.001
# How different, as the sum of the differences in red, green and blue, one look of the enemy
# must be from another for the player to tell them apart.
const VISIBLE_DIFFERENCE := 0.5
# In pixels. How far inside or beyond the Unblockable attack's far edge a target's Hurtbox is put,
# when the swing is to catch it or just miss it.
const REACH_MARGIN := 1.0
# In pixels. How far a test moves the Unblockable attack's reach from the one in the data file.
const REACH_LONGER_BY := 20.0
const REACH_SHORTER_BY := 10.0
# In Stagger points. A Stagger meter this full is far from filling.
const NO_STAGGER := 0.0
# How many attacks the cue is watched for.
const ATTACKS_WATCHED := 2
# How many times round the whole order the cue is watched for.
const ROUNDS_WATCHED := 2
# In physics frames. How far before the swing's first active frame a Roll's last untouchable frame
# is, or how far after its last active frame the Roll's first untouchable frame is, when the Roll
# is to be mistimed: one frame, the narrowest miss.
const ROLL_MISTIMED_BY := 1

# How the Unblockable attack's reach is retuned from the one in the data file, how far beyond its
# far edge the nearest edge of the target's Hurtbox is put (a negative number is inside it), and
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

# How a Roll is mistimed, as how many frames after the start that would just cover the swing's
# active frames it is tapped: a negative number for too early, a positive for too late.
var mistimed_roll_params = ParameterFactory.named_parameters(
	["too_late"],
	[[false], [true]],
)

var _almos_input: AlmosInput
var _rig: EnemyRig
var _tuning: EnemyTuning
var _player: PlayerTuning


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)
	_tuning = _rig.tuning_with()
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- The enemy alone ---

func test_the_shipped_order_has_an_unblockable_attack_in_it_and_does_not_open_with_it() -> void:
	var pattern := _tuning.attack_pattern

	assert_true(pattern.has(UNBLOCKABLE), "the shipped order should have the Unblockable attack in it")
	assert_true(pattern.has(STRIKE), "the shipped order should still have the Strike in it")
	assert_true(pattern.has(LOW), "the shipped order should still have the Low attack in it")
	assert_ne(pattern[0], UNBLOCKABLE, "the Unblockable attack should not come first, before the player has seen any other")


func test_its_unblockable_attack_has_its_own_timeline_and_its_own_damage() -> void:
	var unblockable := _tuning.unblockable_attack
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([UNBLOCKABLE])})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)

	await _rig.wait_frames(unblockable.total_frames() + SETTLE_FRAMES)

	var attacking := _rig.span("attacking")
	var winding := _rig.span("winding_up")
	var striking := _rig.span("striking")
	assert_eq(winding.x, attacking.x, "its wind-up begins with the attack")
	assert_eq(winding.y - winding.x, unblockable.startup_frames, "frames its wind-up lasts")
	assert_eq(striking.x - attacking.x, unblockable.startup_frames, "frames from the start of the attack to the strike")
	assert_eq(striking.y - striking.x, unblockable.active_frames, "frames its Hitbox is on")
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits the target took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, unblockable.damage, TOLERANCE)
		assert_gte(hits[0].sample, striking.x, "the hit lands once its Hitbox is on")
	assert_gt(unblockable.startup_frames, _tuning.attack.startup_frames, "its wind-up should be longer than the Strike's")
	assert_gt(unblockable.startup_frames, _tuning.low_attack.startup_frames, "its wind-up should be longer than the Low attack's")
	assert_gt(unblockable.damage, _tuning.attack.damage, "it should hit harder than the Strike")
	assert_gt(unblockable.damage, _tuning.low_attack.damage, "it should hit harder than the Low attack")


func test_its_unblockable_attack_reaches_as_far_as_the_unblockable_attack_reach_in_the_tuning(params = use_parameters(reach_params)) -> void:
	var reach: float = _tuning.unblockable_attack_reach + params.retune
	# The nearest edge of the target's Hurtbox is this far beyond the swing's far edge. It is in
	# range to swing at, so that nothing but the reach decides the hit.
	var distance: float = reach + EnemyRig.TARGET_RADIUS + params.beyond_far_edge
	var tuning := _rig.tuning_with({"unblockable_attack_reach": reach, "attack_range": distance, "attack_pattern": _pattern([UNBLOCKABLE])})
	_rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * distance)

	await _rig.wait_frames(tuning.unblockable_attack.total_frames())

	assert_eq(_rig.hits().size() == 1, params.hits, "whether the target was hit")


func test_it_swings_its_unblockable_attack_from_close_enough_for_it_to_reach_almos() -> void:
	var almos := autofree((load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene).instantiate()) as Node
	var hurtbox_shape := (almos.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_not_null(hurtbox_shape, "Almos's Hurtbox should be a circle")
	if hurtbox_shape == null:
		return

	assert_lte(_tuning.attack_range - hurtbox_shape.radius, _tuning.unblockable_attack_reach, "how far the nearest edge of Almos's Hurtbox is when it swings, against how far its Unblockable attack reaches")


func test_what_is_drawn_of_its_unblockable_attack_covers_the_box_that_hurts() -> void:
	var reach := _tuning.unblockable_attack_reach + REACH_LONGER_BY
	var enemy = _rig.spawn_enemy(_rig.tuning_with({"unblockable_attack_reach": reach}))
	var hitbox := _unblockable_hitbox_of(enemy)
	var real := StrikeGeometry.real_box(hitbox)
	var drawn := StrikeGeometry.drawn_box(hitbox)

	assert_almost_eq(real.end.x, reach, POSITION_TOLERANCE, "how far out the box that hurts ends")
	assert_almost_eq(drawn.position, real.position, Vector2.ONE * POSITION_TOLERANCE, "where the drawn swing starts, against the box that hurts")
	assert_almost_eq(drawn.size, real.size, Vector2.ONE * POSITION_TOLERANCE, "the size of the drawn swing, against the box that hurts")


func test_only_its_unblockable_attack_hits_with_an_unblockable_hitbox_and_it_is_not_low() -> void:
	var enemy = _rig.spawn_enemy()

	assert_true(_unblockable_hitbox_of(enemy).unblockable, "the Unblockable attack's Hitbox is unblockable")
	assert_false(_unblockable_hitbox_of(enemy).low, "the Unblockable attack is not a Low attack")
	assert_false((enemy.get_node("Hitbox") as Hitbox).unblockable, "the Strike's Hitbox is not")
	assert_false((enemy.get_node("LowHitbox") as Hitbox).unblockable, "the Low attack's Hitbox is not")


func test_it_shows_its_unblockable_swing_only_while_its_hitbox_is_on() -> void:
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([UNBLOCKABLE])})
	var enemy = _rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	var hitbox := _unblockable_hitbox_of(enemy)
	_rig.sample_also("shown", func() -> bool: return hitbox.visible)
	_rig.sample_also("on", func() -> bool: return hitbox.active)
	_rig.sample_also("others_on", func() -> bool: return (enemy.get_node("Hitbox") as Hitbox).active or (enemy.get_node("LowHitbox") as Hitbox).active)

	await _rig.wait_frames(tuning.unblockable_attack.total_frames() + SETTLE_FRAMES)

	var on := _rig.span("on")
	assert_eq(on.y - on.x, tuning.unblockable_attack.active_frames, "frames its Unblockable Hitbox is on")
	var out_of_step := []
	for i in _rig.samples.size():
		if _rig.samples[i].shown != _rig.samples[i].on:
			out_of_step.append(i)
		assert_false(_rig.samples[i].others_on, "the other Hitboxes stay off in an Unblockable attack (sample %d)" % i)
	assert_eq(out_of_step, [], "samples in which the Unblockable swing is shown and its Hitbox is on do not agree")


func test_its_wind_up_flashes_white_at_its_start_and_then_keeps_a_look_of_its_own_and_no_other_attack_does() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	_rig.sample_also("kind", func(): return enemy.attack_kind)
	var round_frames := 0
	for kind in _tuning.attack_pattern:
		round_frames += _tuning.attack_of(kind).total_frames()
	await _rig.wait_frames(round_frames + SETTLE_FRAMES)

	var flash_samples := 0
	var unblockable_winding := 0
	var in_wind_up := 0
	var first := _rig.first_sample_where("attacking")
	for i in range(first, first + round_frames):
		var sample: Dictionary = _rig.samples[i]
		var unblockable_wind_up: bool = sample.winding_up and sample.kind == UNBLOCKABLE
		if unblockable_wind_up:
			in_wind_up += 1
			unblockable_winding += 1
		else:
			in_wind_up = 0
		var flashing: bool = unblockable_wind_up and in_wind_up <= _tuning.unblockable_flash_frames
		flash_samples += 1 if flashing else 0
		assert_eq(sample.look == enemy.UNBLOCKABLE_FLASH_TINT, flashing, "whether it flashes in sample %d" % i)
		assert_eq(sample.look == enemy.UNBLOCKABLE_WIND_UP_TINT, unblockable_wind_up and not flashing, "whether it shows the Unblockable wind-up tint in sample %d" % i)
	assert_eq(unblockable_winding, _tuning.unblockable_attack.startup_frames * _tuning.attack_pattern.count(UNBLOCKABLE), "samples of the Unblockable wind-up in a round")
	assert_eq(flash_samples, _tuning.unblockable_flash_frames * _tuning.attack_pattern.count(UNBLOCKABLE), "samples of the flash in a round")
	assert_gt(_tuning.unblockable_flash_frames, 0, "the flash should last at least a frame")
	assert_lt(_tuning.unblockable_flash_frames, _tuning.unblockable_attack.startup_frames, "the flash is the start of the wind-up, not all of it")


func test_the_flash_is_brighter_than_white_and_clearly_different_from_every_other_look() -> void:
	var enemy = _rig.spawn_enemy()
	var flash: Color = enemy.UNBLOCKABLE_FLASH_TINT
	var tint: Color = enemy.UNBLOCKABLE_WIND_UP_TINT

	assert_true(flash.r > 1.0 and flash.g > 1.0 and flash.b > 1.0, "a white tint of no more than 1 would not show, so the flash should be brighter than white")
	assert_almost_eq(flash.r, flash.g, TOLERANCE, "the flash should be white, not coloured")
	assert_almost_eq(flash.g, flash.b, TOLERANCE, "the flash should be white, not coloured")
	for other in [enemy.WIND_UP_TINT, enemy.LOW_WIND_UP_TINT, enemy.BREAK_TINT, Color.WHITE, tint]:
		assert_gte(_difference(flash, other), VISIBLE_DIFFERENCE, "the flash should look clearly different from %s" % other)
	for other in [enemy.WIND_UP_TINT, enemy.LOW_WIND_UP_TINT, enemy.BREAK_TINT, Color.WHITE]:
		assert_gte(_difference(tint, other), VISIBLE_DIFFERENCE, "the Unblockable wind-up tint should look clearly different from %s" % other)


func test_its_cue_plays_once_as_each_unblockable_wind_up_begins_and_for_no_other_attack() -> void:
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([UNBLOCKABLE])})
	var enemy = _rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	var cues: Array[int] = []
	var playing: Array[bool] = []
	enemy.unblockable_cue_played.connect(func() -> void:
		cues.append(_rig.samples.size())
		playing.append((enemy.get_node("UnblockableCue") as AudioStreamPlayer2D).playing))

	await _rig.wait_frames(tuning.unblockable_attack.total_frames() * (ATTACKS_WATCHED - 1) + SETTLE_FRAMES)

	var first := _rig.first_sample_where("attacking")
	# A sample taken at the start of a frame shows the frame before, so the cue made in the first
	# frame of the attack is counted against the sample that shows that frame, the one after it.
	var expected: Array[int] = []
	for i in ATTACKS_WATCHED:
		expected.append(first + i * tuning.unblockable_attack.total_frames())
	assert_eq(cues, expected, "samples taken so far when the cue played: the attack's first frame, each time")
	assert_eq(playing, [true, true] as Array[bool], "whether the sound was playing as the cue was announced")


func test_its_cue_is_a_sound_that_is_not_empty() -> void:
	var enemy = _rig.spawn_enemy()
	var cue := enemy.get_node("UnblockableCue") as AudioStreamPlayer2D

	assert_not_null(cue, "the enemy should have a player for the cue")
	if cue == null:
		return
	assert_not_null(cue.stream, "the cue should have a sound")
	if cue.stream != null:
		assert_gt(cue.stream.get_length(), 0.0, "length of the cue in seconds")


func test_the_strike_and_the_low_attack_play_no_cue_and_never_flash() -> void:
	var tuning := _rig.tuning_with({"attack_pattern": _pattern([STRIKE, LOW])})
	var enemy = _rig.spawn_enemy(tuning)
	_rig.place_target(Vector2.RIGHT * tuning.attack_range)
	var cues := [0]
	enemy.unblockable_cue_played.connect(func() -> void: cues[0] += 1)
	var round_frames := tuning.attack.total_frames() + tuning.low_attack.total_frames()

	await _rig.wait_frames(round_frames * 2 + SETTLE_FRAMES)

	assert_eq(cues[0], 0, "cues played")
	for i in _rig.samples.size():
		assert_ne(_rig.samples[i].look, enemy.UNBLOCKABLE_FLASH_TINT, "it should not flash in sample %d" % i)
		assert_ne(_rig.samples[i].look, enemy.UNBLOCKABLE_WIND_UP_TINT, "it should not show the Unblockable wind-up tint in sample %d" % i)


# --- Against Almos ---

func test_an_unblockable_attack_hits_almos_who_does_nothing_for_its_full_damage() -> void:
	var unblockable := _tuning.unblockable_attack
	var almos = _spawn_fight_with_unblockable_attacks()

	await _rig.wait_frames(unblockable.total_frames() + SETTLE_FRAMES)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum - unblockable.damage, TOLERANCE)


func test_an_unblockable_attack_goes_through_block_in_full_with_no_stamina_spent_and_no_guard_break() -> void:
	var unblockable := _tuning.unblockable_attack
	var almos = _spawn_fight_with_unblockable_attacks()
	# Just enough Stamina for the hit to take the last of it, if it were blocked.
	almos.stamina.spend(_player.stamina_maximum - _player.block_stamina_cost / 3.0)
	var stamina_before: float = almos.stamina.current
	_rig.sample_also("stamina", func() -> float: return almos.stamina.current)
	_rig.sample_also("guard_broken", func() -> bool: return almos.guard_broken)
	_rig.sample_also("blocking", func() -> bool: return almos.blocking)
	_almos_input.press_action(&"block")

	await _rig.wait_frames(unblockable.total_frames() + SETTLE_FRAMES)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, unblockable.damage, TOLERANCE, "a Block takes nothing off an Unblockable attack")
		assert_true(_rig.samples[hits[0].sample - 1].blocking, "he should have been blocking as it landed")
	var spent := []
	var broken := []
	for i in _rig.samples.size():
		if _rig.samples[i].stamina < stamina_before - TOLERANCE:
			spent.append(i)
		if _rig.samples[i].guard_broken:
			broken.append(i)
	assert_eq(spent, [], "samples in which his Stamina is below what he started with")
	assert_eq(broken, [], "samples in which a Guard break is on him")


func test_an_unblockable_attack_goes_through_a_parry_in_full_and_the_parry_is_not_spent_nor_the_enemy_staggered() -> void:
	var unblockable := _tuning.unblockable_attack
	var almos = _spawn_fight_with_unblockable_attacks()
	var parry: AlmosParry = almos.get_node("Parry")
	_rig.sample_also("window_open", func() -> bool: return parry.window_open)
	_rig.sample_also("parrying", func() -> bool: return parry.parrying)
	await _wait_until_the_enemy_is_winding_up()
	# The window is open over the middle of the active frames, and covers all of them.
	var open_after := unblockable.startup_frames + unblockable.active_frames / 2 - _player.parry_window_frames / 2 - 1
	assert_gte(_player.parry_window_frames, unblockable.active_frames, "his window should be at least as long as the attack's active frames, for a Parry to be tried on every one")
	await _rig.wait_frames(open_after)
	await _tap(&"parry")
	await _rig.wait_frames(_player.parry_window_frames + SETTLE_FRAMES)

	var striking := _rig.span("striking")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].window_open, "his Parry window should be open in sample %d, in which its Hitbox is on" % i)
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, unblockable.damage, TOLERANCE, "a Parry does not negate an Unblockable attack")
		assert_true(_rig.samples[hits[0].sample].window_open, "his window should still be open after the hit: the Parry was not spent")
	assert_almost_eq(_rig.enemy.stagger.current, NO_STAGGER, TOLERANCE, "a failed Parry builds no Stagger")
	assert_false(_rig.enemy.broken, "it should not be broken")


func test_a_hit_inside_the_window_after_an_unblockable_attack_went_through_it_is_still_parried() -> void:
	var unblockable := _tuning.unblockable_attack
	var almos = _spawn_fight_with_unblockable_attacks()
	var parry: AlmosParry = almos.get_node("Parry")
	await _wait_until_the_enemy_is_winding_up()
	var open_after := unblockable.startup_frames + unblockable.active_frames / 2 - _player.parry_window_frames / 2 - 1
	await _rig.wait_frames(open_after)
	await _tap(&"parry")
	# Wait for the Unblockable hit, which lands with the window open.
	for i in unblockable.total_frames():
		if _rig.target_health.current < almos.tuning.health_maximum:
			break
		await get_tree().physics_frame
	assert_lt(_rig.target_health.current, almos.tuning.health_maximum, "the Unblockable hit should have landed")
	assert_true(parry.window_open, "his window should be open as the ordinary hit comes")
	var health_after_unblockable: float = _rig.target_health.current
	# An ordinary hit from the enemy's side, in front of him, inside the window.
	var ordinary := _rig.hitbox_over(_rig.enemy, unblockable.damage, "player_hurtbox")
	var parried: Array[Hurtbox] = []
	ordinary.parried.connect(func(hurtbox: Hurtbox) -> void: parried.append(hurtbox))

	await _rig.swing(ordinary, SETTLE_FRAMES)

	assert_eq(parried.size(), 1, "Parries the ordinary hit met")
	assert_almost_eq(almos.health.current, health_after_unblockable, TOLERANCE, "the ordinary hit should have been parried")
	assert_false(parry.window_open, "the Parry that parried it ends")


func test_a_roll_through_all_of_its_active_frames_avoids_an_unblockable_attack() -> void:
	var unblockable := _tuning.unblockable_attack
	# A Roll that carries him nowhere, so that he stays under the swing for all of it.
	var rolling_on_the_spot := _player.duplicate() as PlayerTuning
	rolling_on_the_spot.roll_distance = 0.0
	var almos = _almos_input.spawn_almos(rolling_on_the_spot)
	_rig.spawn_enemy(_rig.tuning_with({"attack_pattern": _pattern([UNBLOCKABLE])}), almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	_rig.sample_also("untouchable", func() -> bool: return almos.untouchable)
	await _rig.wait_frames(_frames_to_wait_before_tapping_roll(unblockable, rolling_on_the_spot))

	await _tap(&"roll")
	await _play_out_the_first_attack(unblockable)

	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its Hitbox should have gone on")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].untouchable, "he should be untouchable in sample %d, in which its Hitbox is on" % i)
	assert_eq(_rig.hits().size(), 0, "hits Almos took")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE)


func test_a_jump_in_place_does_not_avoid_an_unblockable_attack() -> void:
	var unblockable := _tuning.unblockable_attack
	var almos = _spawn_fight_with_unblockable_attacks()
	# His Jump is centred on the swing's active frames.
	var jump_frames := _jump_frames()
	assert_gt(jump_frames, unblockable.active_frames + 2, "his Jump should outlast the swing's active frames, with a frame to spare each side")
	await _rig.wait_frames(maxi(0, unblockable.startup_frames + unblockable.active_frames / 2 - jump_frames / 2))
	await _tap(&"jump")

	await _play_out_the_first_attack(unblockable)

	var striking := _rig.span("striking")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].airborne, "he should be in the air in sample %d, in which its Hitbox is on" % i)
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, unblockable.damage, TOLERANCE)


func test_a_jump_that_carries_him_out_of_its_reach_through_all_of_its_active_frames_avoids_it() -> void:
	var unblockable := _tuning.unblockable_attack
	# He starts as far from the enemy as it still swings at him, so that the Jump has the least
	# to carry him.
	var distance := _tuning.attack_range - IN_RANGE_BY
	var almos = _spawn_fight_with_unblockable_attacks(null, distance)
	# He is carried away at his walking speed from the take-off to the first active frame, which
	# is the whole Jump but the swing's active frames and the frames he lands after it. A frame
	# less is counted, for the frame the take-off may be late by.
	var frames_carried := _jump_frames() - unblockable.active_frames - JUMP_LANDS_AFTER_BY - 1
	var carried := _player.walk_speed * frames_carried / Engine.physics_ticks_per_second
	var needed := _tuning.unblockable_attack_reach + _hurtbox_radius() - distance
	assert_gt(carried, needed, "the Jump should carry him out of the Unblockable attack's reach by its first active frame, or no Jump can avoid it")

	await _jump_away_through_the_active_frames(almos, unblockable)

	_assert_he_was_in_the_air_and_out_of_reach_while_its_hitbox_was_on(almos, _tuning.unblockable_attack_reach)
	assert_eq(_rig.hits().size(), 0, "hits Almos took")
	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE)


func test_a_roll_whose_untouchable_frames_end_before_the_swing_or_begin_after_it_does_not_avoid_an_unblockable_attack(params = use_parameters(mistimed_roll_params)) -> void:
	var unblockable := _tuning.unblockable_attack
	var rolling_on_the_spot := _player.duplicate() as PlayerTuning
	rolling_on_the_spot.roll_distance = 0.0
	var almos = _almos_input.spawn_almos(rolling_on_the_spot)
	_rig.spawn_enemy(_rig.tuning_with({"attack_pattern": _pattern([UNBLOCKABLE])}), almos.position + Vector2.DOWN * ENEMY_DISTANCE)
	_rig.set_target(almos, almos.health)
	_rig.sample_also("untouchable", func() -> bool: return almos.untouchable)
	var frames_a_second := float(Engine.physics_ticks_per_second)
	var k_open := ceili(rolling_on_the_spot.roll_untouchable_start * frames_a_second - FRAME_SLACK)
	var k_close := ceili((rolling_on_the_spot.roll_untouchable_start + rolling_on_the_spot.roll_untouchable_duration) * frames_a_second - FRAME_SLACK)
	var first_active := unblockable.startup_frames
	var last_active := unblockable.startup_frames + unblockable.active_frames - 1
	# The Roll starts in frame R, and he is untouchable in frames R - 1 + k_open .. R - 1 + k_close - 1
	# (see _frames_to_wait_before_tapping_roll). Too early: the last of those is before the swing's
	# first active frame by the margin. Too late: the first is after its last by the margin.
	var roll_start := last_active + ROLL_MISTIMED_BY + 1 - k_open if params.too_late else first_active - ROLL_MISTIMED_BY + 2 - k_close
	await _rig.wait_frames(roll_start - TAP_FRAMES + 1)

	await _tap(&"roll")
	await _play_out_the_first_attack(unblockable)

	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its Hitbox should have gone on")
	for i in range(striking.x, striking.y):
		assert_false(_rig.samples[i].untouchable, "he should not be untouchable in sample %d, in which its Hitbox is on" % i)
	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "hits Almos took")
	if hits.size() == 1:
		assert_almost_eq(hits[0].damage, unblockable.damage, TOLERANCE)


func test_the_cue_plays_once_for_each_unblockable_wind_up_in_two_rounds_of_the_shipped_order_as_that_wind_up_begins() -> void:
	var enemy = _rig.spawn_enemy()
	_rig.place_target(Vector2.RIGHT * _tuning.attack_range)
	var cues: Array[int] = []
	enemy.unblockable_cue_played.connect(func() -> void: cues.append(_rig.samples.size()))
	var round_frames := 0
	var before_the_unblockable := 0
	for kind in _tuning.attack_pattern:
		if kind == UNBLOCKABLE:
			before_the_unblockable = round_frames
		round_frames += _tuning.attack_of(kind).total_frames()

	await _rig.wait_frames(round_frames * ROUNDS_WATCHED + SETTLE_FRAMES)

	var first := _rig.first_sample_where("attacking")
	var expected: Array[int] = []
	for i in ROUNDS_WATCHED:
		expected.append(first + before_the_unblockable + i * round_frames)
	assert_eq(cues, expected, "samples taken so far when the cue played: the Unblockable attack's first frame, each round")


# The enemy given only Unblockable attacks to make (or this tuning), a little way below Almos,
# after him, and sampled. Almos is sampled too, for whether he is in the air and where he is.
func _spawn_fight_with_unblockable_attacks(tuning: EnemyTuning = null, distance: float = ENEMY_DISTANCE):
	var almos = _almos_input.spawn_almos()
	if tuning == null:
		tuning = _rig.tuning_with({"attack_pattern": _pattern([UNBLOCKABLE])})
	_rig.spawn_enemy(tuning, almos.position + Vector2.DOWN * distance)
	_rig.set_target(almos, almos.health)
	_rig.sample_also("airborne", func() -> bool: return almos.airborne)
	_rig.sample_also("almos_position", func() -> Vector2: return almos.global_position)
	return almos


# He takes off, pushing away from the enemy, so that his Jump ends in the frame after the last
# of the swing's active frames, and plays the first attack out.
func _jump_away_through_the_active_frames(almos, attack: AttackData) -> void:
	var wait := attack.startup_frames + attack.active_frames - _jump_frames() + JUMP_LANDS_AFTER_BY
	assert_gte(wait, 0, "the swing should not begin before his Jump can have started")
	await _rig.wait_frames(maxi(0, wait))
	_almos_input.press_action(&"move_up")
	await _tap(&"jump")
	_almos_input.release_action(&"move_up")
	await _play_out_the_first_attack(attack)


# In every sample in which the enemy's Hitbox is on he is in the air, and the nearest edge of his
# Hurtbox is farther from the enemy than the swing's far edge.
func _assert_he_was_in_the_air_and_out_of_reach_while_its_hitbox_was_on(almos, reach: float) -> void:
	var radius := _hurtbox_radius()
	var striking := _rig.span("striking")
	assert_ne(striking.x, -1, "its Hitbox should have gone on")
	for i in range(striking.x, striking.y):
		assert_true(_rig.samples[i].airborne, "he should be in the air in sample %d, in which its Hitbox is on" % i)
		var gap: float = (_rig.samples[i].almos_position - _rig.enemy.global_position).length() - radius
		assert_gt(gap, reach, "how far the nearest edge of his Hurtbox is from the enemy in sample %d, against how far its swing reaches" % i)


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
	assert_lte(earliest_roll_start, latest_roll_start, "his untouchable window should be at least as long as the Unblockable attack's active frames, or no Roll can cover them")
	var roll_start := floori((earliest_roll_start + latest_roll_start) / 2.0)
	return roll_start - TAP_FRAMES + 1


# The radius of his Hurtbox's circle, read off the scene.
func _hurtbox_radius() -> float:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	var almos := scene.instantiate()
	var radius := ((almos.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	almos.free()
	return radius


# How many physics frames a Jump keeps him in the air, from the tuning.
func _jump_frames() -> int:
	return ceili(_player.jump_duration * Engine.physics_ticks_per_second - 0.0001)


func _pattern(kinds: Array) -> Array[EnemyTuning.AttackKind]:
	var pattern: Array[EnemyTuning.AttackKind] = []
	pattern.assign(kinds)
	return pattern


func _unblockable_hitbox_of(enemy) -> Hitbox:
	return enemy.get_node("UnblockableHitbox") as Hitbox


func _wait_until_the_enemy_is_winding_up() -> void:
	for i in _tuning.unblockable_attack.total_frames():
		if _rig.enemy.winding_up:
			return
		await get_tree().physics_frame
	fail_test("the enemy should be winding up")


# Presses this button and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# How different two colours are: the differences in red, green and blue added up.
func _difference(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
