extends GutTest
## Almos's Jump attack, seen only through the scenes: the real Almos scene and the real training
## enemy scene run with their shipped tuning, and input goes in as actions. Every physics frame a
## sample of Almos is taken, so what happened can be read back frame by frame: a sample is taken
## at the start of the frame, before anything has moved in it, so it shows how the frame before
## left things. Expected numbers come from the data files the scenes use (or a copy a test
## changes) and plain arithmetic, never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyFight := preload("res://test/helpers/enemy_fight.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
const GAP_SCENE_PATH := "res://scenes/world/gap.tscn"
const LEDGE_SCENE_PATH := "res://scenes/world/ledge.tscn"
# A tap: held this many physics frames, far shorter than a swing or a Jump.
const TAP_FRAMES := 2
# The most game time, in seconds, any wait in these tests may take.
const WAIT_LIMIT := 3.0
# In physics frames. Past the end of something that a test carries on to see what comes of it.
const PAST_THE_END_FRAMES := 12
# In pixels.
const POSITION_TOLERANCE := 0.01
# In Stamina, Health and Stagger points.
const TOLERANCE := 0.0001
# In pixels. How much narrower than his reach a gap is, or how much wider, to be fallen short of.
const REACH_MARGIN := 6.0
# In pixels. Tall enough that no test goes round a gap or a ledge.
const WORLD_HEIGHT := 600.0
# In pixels. How wide a ledge is: far wider than any Jump reaches.
const LEDGE_WIDTH := 300.0
# In pixels. How far before an edge a run starts.
const RUN_UP := 60.0
# In physics frames. Enough to run RUN_UP at walking speed and stand against the edge.
const RUN_UP_FRAMES := 60
# A refill pause longer than any wait in these tests, for tests that need Stamina to stay where
# it was left.
const LONG_REFILL_PAUSE := 10.0
# In pixels. How far from Almos a stand-in enemy to lock on to is put.
const LOCK_ON_DISTANCE := 100.0
# In degrees. A direction that is no multiple of an eighth of a turn, to see that the strike is
# aimed exactly while the facing is one of eight.
const ODD_ANGLE_DEGREES := 33.0
# In pixels. How far the training enemy stands from Almos when his strike is to reach it.
const ENEMY_DISTANCE := 30.0
# In pixels. How far past the enemy's notice range a stand-in is put.
const BEYOND_NOTICE := 50.0
# In pixels. A Hitbox this wide covers the enemy it is put over, and no other.
const NARROW_HITBOX_RADIUS := 12.0
const ANGLE_TOLERANCE := 0.0001
# How many samples show him in the air by the time a press is made that is seen in the very last
# frame of the flight, the one he comes down in. One more and it would be seen on the ground.
const LATE_PRESS_SAMPLES := 25

# The presses that a Jump attack leaves him unable to make until it is over, and what each would
# have started.
var committed_presses_params = ParameterFactory.named_parameters(
	["action", "state"],
	[
		[&"roll", "rolling"],
		[&"jump", "airborne"],
		[&"parry", "parrying"],
		[&"block", "blocking"],
	],
)

# Which side of the enemy Almos is on, and whether the enemy has its back to him.
var side_params = ParameterFactory.named_parameters(
	["side", "from_behind"],
	[["the front", false], ["behind", true]],
)

var _almos_input: AlmosInput
var _fight: EnemyFight
var _rig: EnemyRig
var _almos: Node2D
var _enemy: Node2D
var _samples: Array[Dictionary] = []


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first
	# processed after the first sample and what it presses is seen from the next frame.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)
	_fight = EnemyFight.new(self, _almos_input, _rig)
	_enemy = null
	_samples = []


func after_each() -> void:
	_stop_sampling()
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- The numbers ---

func test_the_jump_attack_builds_more_stagger_than_any_heavy_attack() -> void:
	var jump_attack := _sword().jump_attack
	assert_not_null(jump_attack, "the sword's data file should have a jump_attack")
	if jump_attack == null:
		return
	assert_gt(jump_attack.stagger, _sword().heavy_attack.charged_stagger, "more than a fully charged Heavy attack")
	assert_gt(jump_attack.stagger, _sword().heavy_attack.stagger, "more than a plain Heavy attack")
	assert_gt(jump_attack.damage, 0.0, "it should hurt")
	assert_gt(jump_attack.active_frames, 0, "it should have active frames")
	assert_gt(jump_attack.recovery_frames, 0, "it should have a recovery")
	assert_gt(jump_attack.stamina_cost, 0.0, "it should cost Stamina")
	assert_eq(jump_attack.startup_frames, 0, "its startup is the rest of the Jump, so it has no startup frames")


# --- The timeline ---

func test_he_keeps_flying_and_the_strike_begins_on_the_frame_he_lands_a_miss_included() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)

	await _jump_attack_in_place()

	var swing := _sword().jump_attack
	var landed := _first_sample_where_down_again()
	var attacking := _span("attacking")
	var striking := _span("striking")
	var jump_attacking := _span("jump_attacking")
	assert_eq(attacking.x, landed, "he should be attacking from the frame he lands")
	assert_eq(striking.x, landed, "the sword should be on from the frame he lands")
	assert_eq(striking.y - striking.x, swing.active_frames, "frames the sword stays on")
	assert_eq(attacking.y - attacking.x, swing.total_frames(), "frames he attacks for, with the full recovery")
	assert_lt(jump_attacking.x, landed, "the Jump attack begins at the press, in the air")
	assert_true(_samples[jump_attacking.x].airborne, "he should be in the air as it begins")
	assert_eq(jump_attacking.y, attacking.y, "the Jump attack ends with the recovery")
	for i in _samples.size():
		var sample := _samples[i]
		if sample.airborne:
			assert_false(sample.striking or sample.attacking, "no strike and no attack in the air (sample %d)" % i)
		if i >= jump_attacking.x and i < jump_attacking.y:
			assert_eq(sample.light_swing, 0, "no Light combo under way (sample %d)" % i)
			assert_false(sample.charging, "no charging (sample %d)" % i)


func test_he_flies_the_rest_of_the_jump_unchanged_and_stands_still_to_the_end_of_the_recovery() -> void:
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)

	await _jump_attack_in_place()

	var reach := _tuning().walk_speed * _tuning().jump_duration
	var landed := _first_sample_where_down_again()
	var takeoff := _first_sample_where("airborne") - 1
	assert_almost_eq(_samples[landed].position.x - _samples[takeoff].position.x, reach, POSITION_TOLERANCE, "the whole reach of the walking Jump")
	var attacking := _span("attacking")
	for i in range(landed, attacking.y):
		assert_almost_eq(_samples[i].position, _samples[landed].position, Vector2.ONE * POSITION_TOLERANCE, "he should stand still (sample %d)" % i)


func test_a_press_made_in_the_air_is_the_jump_attack_on_any_frame_of_the_flight(params = use_parameters(ParameterFactory.named_parameters(
	["name", "airborne_samples"],
	[["just after take-off", 1], ["on the last frame of the flight", LATE_PRESS_SAMPLES]],
))) -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_until(func() -> bool: return _samples.filter(func(sample: Dictionary) -> bool: return sample.airborne).size() >= params.airborne_samples, WAIT_LIMIT)
	assert_true(_almos.airborne, "he should still be in the air")

	await _tap(&"attack_heavy")
	await _wait_until_the_jump_attack_is_over()

	assert_eq(_span("attacking").y - _span("attacking").x, _sword().jump_attack.total_frames(), "it should be a Jump attack, %s" % params.name)
	assert_eq(_span("striking").x, _first_sample_where_down_again(), "it should strike as he lands, %s" % params.name)


func test_a_jump_attack_cannot_be_cut_short_by_these_presses(params = use_parameters(committed_presses_params)) -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _jump_attack_until_the_strike_begins()
	await wait_physics_frames(_sword().jump_attack.active_frames + 1)

	# Pressed and let go inside the recovery.
	_almos_input.press_action(params.action)
	await wait_physics_frames(TAP_FRAMES + 2)
	_almos_input.release_action(params.action)
	await _wait_until_the_jump_attack_is_over()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	var landed := _first_sample_where_down_again()
	for i in range(landed, _samples.size()):
		assert_false(_samples[i][params.state], "pressing %s should do nothing (sample %d)" % [params.action, i])
	assert_eq(_span("attacking").y - _span("attacking").x, _sword().jump_attack.total_frames(), "the recovery should run in full")


# --- Presses in the air ---

func test_a_light_press_in_the_air_is_lost() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap(&"attack_light")
	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("attacking") or _any_sample("jump_attacking") or _any_sample("charging") or _any_sample("striking"), "a Light press should do nothing in the air or after")


func test_a_second_heavy_press_during_a_jump_attack_is_lost() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"attack_heavy")
	var after_the_first_press: float = _almos.stamina.current
	# Again in the air, then in the strike, then early in the recovery, before the buffer window.
	await _tap(&"attack_heavy")
	await _wait_until_down()
	await wait_physics_frames(1)
	await _tap(&"attack_heavy")
	await wait_physics_frames(TAP_FRAMES)
	await _tap(&"attack_heavy")
	await _wait_until_the_jump_attack_is_over()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	var swing := _sword().jump_attack
	assert_eq(_span("attacking").y - _span("attacking").x, swing.total_frames(), "one Jump attack and nothing after it")
	assert_false(_any_sample("charging"), "no charge should begin")
	assert_almost_eq(_almos.stamina.current, after_the_first_press, TOLERANCE, "nothing more spent")


func test_a_heavy_press_in_the_last_frames_of_the_recovery_is_kept_as_for_any_attack() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _jump_attack_until_the_strike_begins()
	var swing := _sword().jump_attack
	# The press is seen a frame after the one it is made in, and the window is the last
	# attack_buffer_frames frames of the recovery.
	await wait_physics_frames(swing.total_frames() - _sword().attack_buffer_frames - 1)

	await _tap(&"attack_heavy")
	await _wait_until_the_jump_attack_is_over()
	await wait_while(func() -> bool: return _almos.attacking or _almos.charging, WAIT_LIMIT)

	# The kept press came out as a Heavy attack (a tap, so the plain one), straight after.
	var attacking := _span("attacking")
	assert_eq(attacking.y - attacking.x, swing.total_frames() + _sword().heavy_attack.total_frames(), "frames of the Jump attack and the Heavy attack after it")


func test_a_light_press_in_the_last_frames_of_the_recovery_starts_the_next_swing() -> void:
	_spawn_almos(Vector2.ZERO)
	await wait_physics_frames(SETTLE_FRAMES)
	await _jump_attack_until_the_strike_begins()
	var swing := _sword().jump_attack
	await wait_physics_frames(swing.total_frames() - _sword().attack_buffer_frames - 1)

	await _tap(&"attack_light")
	await _wait_until_the_jump_attack_is_over()
	await wait_physics_frames(1)

	assert_eq(_almos.light_swing, 1, "the kept press should come out as the first swing of the Light combo")


# --- Stamina ---

func test_the_jump_attack_spends_its_stamina_once_at_the_press() -> void:
	_spawn_almos(Vector2.ZERO, _tuning_with({"stamina_refill_pause": LONG_REFILL_PAUSE}))
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	var before_the_press: float = _almos.stamina.current

	await _tap(&"attack_heavy")
	var press_seen: float = _almos.stamina.current

	assert_almost_eq(press_seen, before_the_press - _sword().jump_attack.stamina_cost, TOLERANCE, "spent at the press")
	await _wait_until_the_jump_attack_is_over()
	assert_almost_eq(_almos.stamina.current, press_seen, TOLERANCE, "nothing more spent by the landing, the strike or the recovery")


func test_a_press_at_zero_stamina_is_lost_and_he_just_keeps_jumping() -> void:
	# A Jump that leaves nothing in Stamina: spending succeeds only while there is any left.
	var empty := _tuning_with({"stamina_maximum": _tuning().jump_stamina_cost, "stamina_refill_pause": LONG_REFILL_PAUSE})
	_spawn_almos(Vector2.ZERO, empty)
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")
	assert_almost_eq(_almos.stamina.current, 0.0, TOLERANCE, "the Jump should have taken the last of it")

	await _tap(&"attack_heavy")
	await _wait_until_down()
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("jump_attacking") or _any_sample("attacking") or _any_sample("charging") or _any_sample("striking"), "the press should be lost, not kept for after")
	assert_eq(_almos.stamina.current, 0.0, "nothing was spent")


# --- The aim ---

func test_the_strike_is_aimed_along_his_facing_without_lock_on() -> void:
	_spawn_almos(Vector2.ZERO)
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	_almos_input.release_action(&"move_right")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(_almos.facing, Vector2.RIGHT, Vector2.ONE * TOLERANCE, "he should face right")

	await _jump_attack_in_place()

	assert_almost_eq(_samples[_span("striking").x].aim, 0.0, ANGLE_TOLERANCE, "the strike should be aimed right")


func test_the_strike_is_aimed_at_the_target_at_the_press_under_lock_on() -> void:
	_spawn_almos(Vector2.ZERO)
	var angle := deg_to_rad(ODD_ANGLE_DEGREES)
	var standin := _stand_in_enemy_at(Vector2.from_angle(angle) * LOCK_ON_DISTANCE)
	await _tap(&"lock_on")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.locked_on, "he should be locked on")
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)

	await _tap(&"attack_heavy")
	# The target goes round to the other side in the air, and he turns to face it.
	standin.position = _almos.position + Vector2.from_angle(angle + PI) * LOCK_ON_DISTANCE
	await _wait_until_the_jump_attack_is_over()

	var aim: float = _samples[_span("striking").x].aim
	assert_almost_eq(angle_difference(aim, angle), 0.0, ANGLE_TOLERANCE, "the strike should be aimed at the target's true angle at the press")


# --- Landing places ---

func test_landing_in_a_gap_cancels_the_jump_attack_with_the_jump() -> void:
	var reach := _tuning().walk_speed * _tuning().jump_duration
	var gap := _spawn_world(GAP_SCENE_PATH, reach - _body_radius() + REACH_MARGIN)
	await _stand_against_the_left_edge_of(gap)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"attack_heavy")
	await _wait_until_down()
	_samples.clear()

	await _tap(&"roll")
	await wait_physics_frames(PAST_THE_END_FRAMES)

	assert_false(_any_sample("attacking") or _any_sample("jump_attacking") or _any_sample("striking"), "no strike and no recovery after the landing")
	assert_true(_any_sample("rolling"), "he should be free at once")


func test_a_jump_attack_onto_a_low_ledge_strikes_as_he_lands_on_it() -> void:
	var ledge := _spawn_world(LEDGE_SCENE_PATH, LEDGE_WIDTH)
	await _stand_against_the_left_edge_of(ledge)
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	await _tap(&"attack_heavy")
	await _wait_until_the_jump_attack_is_over()

	assert_eq(_almos.height_level, 1, "he should be on the ledge")
	assert_eq(_span("striking").x, _first_sample_where_down_again(), "the sword should be on from the frame he lands")
	assert_eq(_span("attacking").y - _span("attacking").x, _sword().jump_attack.total_frames(), "frames he attacks for")


# --- On an enemy ---

func test_a_landed_jump_attack_deals_its_damage_and_builds_its_stagger(params = use_parameters(side_params)) -> void:
	_almos = _fight.spawn_almos_above_the_enemy(params.from_behind)
	_enemy = _rig.enemy
	_sample_almos(_almos)
	await wait_physics_frames(SETTLE_FRAMES)
	var health_before: float = _enemy.health.current

	await _jump_attack_in_place()

	var swing := _sword().jump_attack
	var behind: float = _enemy.tuning.behind_stagger if params.from_behind else 0.0
	assert_almost_eq(health_before - _enemy.health.current, swing.damage, TOLERANCE, "Health taken, from %s" % params.side)
	assert_almost_eq(_enemy.stagger.current, swing.stagger + behind, TOLERANCE, "Stagger built, from %s" % params.side)
	var hit := _first_sample_where_enemy_hurt()
	assert_eq(hit, _span("striking").x, "the hit lands in the frame he lands in")


func test_a_jump_attack_is_not_a_critical_hit() -> void:
	_almos = _fight.spawn_almos_above_the_enemy(false)
	_enemy = _rig.enemy
	_sample_almos(_almos)
	await wait_physics_frames(SETTLE_FRAMES)
	var breaker := _rig.hitbox_over(_enemy, 0.0, "enemy_hurtbox")
	breaker.stagger = _enemy.tuning.stagger_capacity
	await wait_physics_frames(SETTLE_FRAMES)
	await _rig.swing(breaker, 1)
	assert_true(_enemy.broken, "the enemy should be broken")
	var health_before: float = _enemy.health.current

	await _jump_attack_in_place()

	assert_true(_enemy.broken, "a Critical hit would have ended the Break")
	assert_almost_eq(health_before - _enemy.health.current, _sword().jump_attack.damage, TOLERANCE, "it takes its own damage, not a Critical hit's")


func test_a_jump_attack_builds_no_stagger_on_a_broken_enemy() -> void:
	_almos = _fight.spawn_almos_above_the_enemy(false)
	_enemy = _rig.enemy
	_sample_almos(_almos)
	await wait_physics_frames(SETTLE_FRAMES)
	var breaker := _rig.hitbox_over(_enemy, 0.0, "enemy_hurtbox")
	breaker.stagger = _enemy.tuning.stagger_capacity
	await wait_physics_frames(SETTLE_FRAMES)
	await _rig.swing(breaker, 1)
	assert_true(_enemy.broken, "the enemy should be broken")
	var stagger_before: float = _enemy.stagger.current

	await _jump_attack_in_place()

	assert_almost_eq(_enemy.stagger.current, stagger_before, TOLERANCE, "no Stagger built on a broken enemy")


# Helpers

func _sword() -> WeaponData:
	var loaded := load(AlmosInput.WEAPON_PATH) as WeaponData
	assert_not_null(loaded, "the sword data file should load")
	return loaded


func _tuning() -> PlayerTuning:
	var loaded := load(AlmosInput.TUNING_PATH) as PlayerTuning
	assert_not_null(loaded, "the player tuning data file should load")
	return loaded


# The tuning data file's numbers, with these properties changed. Nothing is shared with the data
# file.
func _tuning_with(changes: Dictionary) -> PlayerTuning:
	var tuning := _tuning().duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as PlayerTuning
	for property in changes:
		tuning.set(property, changes[property])
	return tuning


func _body_radius() -> float:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	var almos := scene.instantiate()
	var radius := ((almos.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius
	almos.free()
	return radius


# Almos with this tuning, standing here, and sampled from now on. He is put in place before he
# enters the tree.
func _spawn_almos(at: Vector2, tuning: PlayerTuning = null) -> Node2D:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	_almos = scene.instantiate()
	_almos.position = at
	if tuning != null:
		_almos.tuning = tuning
	add_child_autofree(_almos)
	_sample_almos(_almos)
	return _almos


func _sample_almos(almos: Node2D) -> void:
	_samples.clear()
	get_tree().physics_frame.connect(_take_sample)


func _take_sample() -> void:
	if not is_instance_valid(_almos):
		return
	var sword := _almos.get_node("Sword") as Hitbox
	_samples.append({
		"position": _almos.position,
		"airborne": _almos.airborne,
		"attacking": _almos.attacking,
		"jump_attacking": _almos.jump_attacking,
		"charging": _almos.charging,
		"light_swing": _almos.light_swing,
		"rolling": _almos.rolling,
		"parrying": _almos.parrying,
		"blocking": _almos.blocking,
		"striking": sword.active,
		"aim": sword.rotation,
		"enemy_health": _enemy.health.current if is_instance_valid(_enemy) else 0.0,
	})


func _stop_sampling() -> void:
	if get_tree().physics_frame.is_connected(_take_sample):
		get_tree().physics_frame.disconnect(_take_sample)


# A stand-in enemy to lock on to, here relative to Almos. The test frees it.
func _stand_in_enemy_at(offset: Vector2) -> Node2D:
	var standin := Node2D.new()
	standin.position = _almos.position + offset
	standin.add_to_group(&"enemies")
	add_child_autofree(standin)
	return standin


func _spawn_world(scene_path: String, width: float) -> Node2D:
	var scene := load(scene_path) as PackedScene
	assert_not_null(scene, "the scene %s should load" % scene_path)
	var world = scene.instantiate()
	world.size = Vector2(width, WORLD_HEIGHT)
	add_child_autofree(world)
	return world


# Almos run up to the left edge of this gap or ledge, pushing right, and standing against it.
func _stand_against_the_left_edge_of(world: Node2D) -> void:
	var left_edge: float = world.position.x - world.size.x / 2.0
	_spawn_almos(Vector2(left_edge - _body_radius() - RUN_UP, world.position.y))
	_almos_input.press_action(&"move_right")
	await wait_physics_frames(RUN_UP_FRAMES)


# Presses the action and lets go again after a few frames.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# A Jump and, once he is in the air, a Heavy press, and waits until it is all over.
func _jump_attack_in_place() -> void:
	await _jump_attack_until_the_strike_begins()
	await _wait_until_the_jump_attack_is_over()


# A Jump and a Heavy press in the air, and waits until the frame after the one he lands in.
func _jump_attack_until_the_strike_begins() -> void:
	await _tap(&"jump")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_almos.airborne, "he should be in the air")
	await _tap(&"attack_heavy")
	await wait_until(func() -> bool: return _almos.attacking, WAIT_LIMIT, "the strike should begin")


func _wait_until_the_jump_attack_is_over() -> void:
	await wait_until(func() -> bool: return _any_sample("jump_attacking"), WAIT_LIMIT, "the Jump attack should begin")
	await wait_while(func() -> bool: return _almos.jump_attacking, WAIT_LIMIT)


func _wait_until_down() -> void:
	await wait_until(func() -> bool: return _almos.airborne, WAIT_LIMIT, "he should take off")
	await wait_while(func() -> bool: return _almos.airborne, WAIT_LIMIT)


func _first_sample_where(state: String) -> int:
	for i in _samples.size():
		if _samples[i][state]:
			return i
	return -1


func _any_sample(state: String) -> bool:
	return _first_sample_where(state) != -1


# The index of the first sample to show him down again after the Jump.
func _first_sample_where_down_again() -> int:
	var first := _first_sample_where("airborne")
	for i in range(first, _samples.size()):
		if not _samples[i].airborne:
			return i
	fail_test("he should have come down")
	return -1


# The first stretch of samples in which this is true, as Vector2i(first, end): the index of the
# first sample showing it and of the first showing it over, or -1 for either if it has not
# happened yet.
func _span(state: String) -> Vector2i:
	var first := -1
	for i in _samples.size():
		if first == -1 and _samples[i][state]:
			first = i
		elif first != -1 and not _samples[i][state]:
			return Vector2i(first, i)
	return Vector2i(first, -1)


# The index of the first sample to show the enemy's Health lower than the one before.
func _first_sample_where_enemy_hurt() -> int:
	for i in range(1, _samples.size()):
		if _samples[i].enemy_health < _samples[i - 1].enemy_health:
			return i
	return -1
