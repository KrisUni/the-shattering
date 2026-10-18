extends GutTest
## Almos fighting Unarmed, with empty hands: the real Almos and the real training enemy, as
## whole scenes with their shipped data, driven through Input actions. Light and Heavy attacks
## land with Unarmed's damage and reach, a Heavy attack and a Light attack from behind build
## Stagger, a Parry negates the enemy's Strike and builds its Stagger, and a Critical hit on a
## broken enemy uses Unarmed's numbers. Every expected number is read from the data files, never
## from how the code works it out, and nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyFight := preload("res://test/helpers/enemy_fight.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const UNARMED_PATH := "res://data/unarmed.tres"
const TORCH_PATH := "res://data/torch.tres"

# In Health points and Stagger points.
const TOLERANCE := 0.0001
# In pixels. How far beyond the enemy's notice range the stand-in it goes after stands, so that it
# turns to face it and goes nowhere.
const BEYOND_NOTICE := 50.0
# In pixels. How far inside or outside Unarmed's reach the near edge of the enemy's Hurtbox is put.
const REACH_MARGIN := 2.0
# In Health points. Far more than any run of hits in these tests can take off, so that no retune
# of a damage figure kills the enemy.
const ENEMY_HEALTH := 1000000.0
# In pixels. A Hitbox this wide covers the enemy it is put over, and no other.
const NARROW_HITBOX_RADIUS := 12.0
# Held this many physics frames, a press is a tap: far shorter than a swing or a charge start.
const TAP_FRAMES := 3
# In physics frames. How far past the hold that drops a Weapon the button is held.
const HOLD_MARGIN := 4
const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# The most physics frames any wait in these tests may take.
const WAIT_FRAME_LIMIT := 400

# How his hands came to be empty.
var empty_params = ParameterFactory.named_parameters(
	["how"],
	[["starting with no Weapon"], ["dropping the last Weapon"], ["a Death after dropping the last Weapon"]],
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
var _unarmed: WeaponData
# What Almos stands in, which the test frees. A Weapon he drops lies in it.
var _holder: Node2D


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)
	_fight = EnemyFight.new(self, _almos_input, _rig)
	_tuning = _rig.tuning_with()
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning
	_unarmed = load(UNARMED_PATH) as WeaponData
	assert_not_null(_unarmed, "the Unarmed data file should load")
	_holder = Node2D.new()
	add_child_autofree(_holder)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


# --- Empty hands ---

func test_his_hands_are_empty_and_unarmed_is_what_he_has_however_his_hands_came_to_be_empty(params = use_parameters(empty_params)) -> void:
	var almos := await _empty_handed_almos(params.how)

	assert_null(almos.weapons.in_hand, "Unarmed is not carried")
	assert_eq(almos.weapons.carried.size(), 0, "Unarmed is not carried")
	assert_eq(almos.unarmed.resource_path, UNARMED_PATH, "what he fights with when his hands are empty")


# --- Light and Heavy attacks ---

func test_a_light_attack_with_empty_hands_takes_unarmeds_damage_off_the_enemy(params = use_parameters(empty_params)) -> void:
	var swing := _unarmed.light_attacks[0]
	await _spawn_fight(params.how, _enemy_distance(), false)

	await _tap(&"attack_light")
	await _rig.wait_frames(swing.startup_frames + swing.active_frames + SETTLE_FRAMES)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, swing.damage, TOLERANCE, "damage of the hit")


func test_a_heavy_attack_with_empty_hands_takes_unarmeds_damage_off_the_enemy(params = use_parameters(empty_params)) -> void:
	var heavy := _unarmed.heavy_attack
	var almos := await _spawn_fight(params.how, _enemy_distance(), false)

	await _tap(&"attack_heavy")
	await _wait_for_the_swing_to_end(almos)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, heavy.damage, TOLERANCE, "damage of the hit")


func test_a_light_attack_with_empty_hands_hits_an_enemy_just_inside_unarmeds_reach() -> void:
	var swing := _unarmed.light_attacks[0]
	await _spawn_fight("starting with no Weapon", _unarmed.reach + _enemy_hurtbox_radius() - REACH_MARGIN, false)

	await _tap(&"attack_light")
	await _rig.wait_frames(swing.startup_frames + swing.active_frames + SETTLE_FRAMES)

	assert_eq(_rig.drops("enemy_health").size(), 1, "the enemy just inside the reach should have been hit")


func test_a_light_attack_with_empty_hands_misses_an_enemy_just_outside_unarmeds_reach() -> void:
	var swing := _unarmed.light_attacks[0]
	var almos := await _spawn_fight("starting with no Weapon", _unarmed.reach + _enemy_hurtbox_radius() + REACH_MARGIN, false)

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_gt(swing.startup_frames + swing.active_frames, 0, "the swing should have had frames to hit in")
	assert_eq(_rig.drops("enemy_health").size(), 0, "the enemy just outside the reach should not have been hit")


func test_unarmed_reaches_less_far_than_the_sword() -> void:
	var sword := load(AlmosInput.WEAPON_PATH) as WeaponData
	assert_lt(_unarmed.reach, sword.reach, "Unarmed should reach less far than the sword")


# --- Stagger ---

func test_a_light_attack_from_behind_with_empty_hands_builds_the_behind_stagger() -> void:
	var swing := _unarmed.light_attacks[0]
	var almos := await _spawn_fight("starting with no Weapon", _enemy_distance(), true)

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_almost_eq(_rig.enemy.stagger.current, swing.stagger + _tuning.behind_stagger, TOLERANCE, "Stagger of a Light attack from behind")
	assert_lt(_rig.enemy.health.current, ENEMY_HEALTH, "the Light attack should have landed")


func test_a_heavy_attack_with_empty_hands_builds_unarmeds_stagger_in_proportion_to_the_charge_and_more_from_behind(params = use_parameters(heavy_params)) -> void:
	var heavy := _unarmed.heavy_attack
	var almos := await _spawn_fight("starting with no Weapon", _enemy_distance(), params.from_behind)

	if params.charged:
		_almos_input.press_action(&"attack_heavy")
		await _wait_for_the_swing_to_end(almos)
		_almos_input.release_action(&"attack_heavy")
	else:
		await _tap(&"attack_heavy")
		await _wait_for_the_swing_to_end(almos)

	var own := heavy.charged_stagger if params.charged else heavy.stagger
	var expected := own + (_tuning.behind_stagger if params.from_behind else 0.0)
	assert_almost_eq(_rig.enemy.stagger.current, expected, TOLERANCE, "Stagger of %s" % params.what)


# --- Parry ---

func test_a_parry_with_empty_hands_negates_the_enemys_strike_and_builds_its_stagger(params = use_parameters(empty_params)) -> void:
	var almos := await _empty_handed_almos(params.how)
	var enemy = _rig.spawn_enemy(_rig.tuning_with({"health_maximum": ENEMY_HEALTH}), almos.position + Vector2.DOWN * _enemy_distance())
	_rig.set_target(almos, almos.health)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _fight.parry_the_swing(_player)

	assert_almost_eq(almos.health.current, almos.tuning.health_maximum, TOLERANCE, "a parried Strike should do no damage")
	assert_almost_eq(enemy.stagger.current, _player.parry_stagger, TOLERANCE, "Stagger a Parry builds")


# --- Critical hit ---

func test_a_critical_hit_with_empty_hands_takes_unarmeds_critical_damage_and_ends_the_break(params = use_parameters(empty_params)) -> void:
	var critical := _unarmed.critical_attack
	var almos := await _spawn_fight(params.how, _enemy_distance(), false)
	var enemy = _rig.enemy
	await _break(enemy)
	var health_before: float = enemy.health.current

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_almost_eq(enemy.health.current, health_before - critical.damage, TOLERANCE, "Health the Critical hit takes")
	assert_false(enemy.broken, "a Critical hit ends the Break")


func test_a_light_press_with_empty_hands_beyond_unarmeds_critical_range_is_no_critical_hit() -> void:
	var almos := await _spawn_fight("starting with no Weapon", _unarmed.critical_range + REACH_MARGIN, false)
	var enemy = _rig.enemy
	await _break(enemy)

	await _tap(&"attack_light")
	var swinging := almos.attacking
	var made_critical := almos.critical
	await _wait_for_the_swing_to_end(almos)

	assert_true(swinging, "the press should have made a swing")
	assert_false(made_critical, "the swing should be a Light swing, not the Critical hit")
	assert_true(enemy.broken, "no Critical hit should have ended the Break")


# --- Jump attack ---

func test_a_jump_attack_with_empty_hands_lands_with_unarmeds_jump_attack_damage_and_builds_its_stagger(params = use_parameters(empty_params)) -> void:
	var jump_attack := _unarmed.jump_attack
	var almos := await _spawn_fight(params.how, _enemy_distance(), false)
	var enemy = _rig.enemy

	await _tap(&"jump")
	await _rig.wait_frames(SETTLE_FRAMES)
	assert_true(almos.airborne, "he should be in the air")
	await _tap(&"attack_heavy")
	await _wait_for_the_jump_attack_to_end(almos)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, jump_attack.damage, TOLERANCE, "damage of the hit")
	assert_almost_eq(enemy.stagger.current, jump_attack.stagger, TOLERANCE, "Stagger of the Jump attack")


# --- Switch ---

func test_a_switch_with_empty_hands_keeps_him_unarmed(params = use_parameters(empty_params)) -> void:
	var swing := _unarmed.light_attacks[0]
	var almos := await _spawn_fight(params.how, _enemy_distance(), false)

	await _tap(&"switch_weapon")
	await _rig.wait_frames(SETTLE_FRAMES)
	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	assert_null(almos.weapons.in_hand, "nothing should have come to hand")
	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, swing.damage, TOLERANCE, "damage of the hit, which is still Unarmed's")


# --- A Weapon picked up with empty hands ---

func test_a_weapon_picked_up_with_empty_hands_replaces_unarmed_and_dropping_it_brings_unarmed_back() -> void:
	var torch := load(TORCH_PATH) as WeaponData
	assert_not_null(torch, "the torch data file should load")
	var almos := await _spawn_fight("starting with no Weapon", _enemy_distance(), false)
	almos.weapons.pick_up(torch)
	var torch_swing := torch.light_attacks[0]
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, torch_swing.damage, TOLERANCE, "damage of the torch's hit")

	await _hold_interact_to_drop()
	assert_null(almos.weapons.in_hand, "the torch should be dropped")
	var unarmed_swing := _unarmed.light_attacks[0]
	await _tap(&"attack_light")
	await _wait_for_the_swing_to_end(almos)

	hits = _rig.drops("enemy_health")
	assert_almost_eq(hits[-1].damage, unarmed_swing.damage, TOLERANCE, "damage of the hit once he is Unarmed again")


# --- Helpers ---

# Almos in the holder with his hands empty, in the way named, with no enemy yet. The test frees
# him with the holder. A Weapon he drops lies in the holder too.
func _empty_handed_almos(how: String) -> Almos:
	var scene := load(AlmosInput.ALMOS_SCENE_PATH) as PackedScene
	assert_not_null(scene, "the Almos scene should load")
	var almos := scene.instantiate() as Almos
	if how == "starting with no Weapon":
		almos.weapon = null
	_holder.add_child(almos)
	await _rig.wait_frames(SETTLE_FRAMES)
	if how != "starting with no Weapon":
		await _hold_interact_to_drop()
	if how == "a Death after dropping the last Weapon":
		almos.health.take_damage(almos.health.maximum)
		assert_true(almos.dead, "he should have fallen")
		almos.return_to(almos.global_position)
		await _rig.wait_frames(SETTLE_FRAMES)
	assert_null(almos.weapons.in_hand, "his hands should be empty")
	return almos


# Almos with empty hands, and the training enemy this far below him, its Health far more than any
# hit takes. The enemy has its back to him if from_behind, and faces him otherwise, and goes after a
# stand-in too far off to notice, so that it never swings at Almos. It is added after him, so he is
# processed first in a frame.
func _spawn_fight(how: String, distance: float, from_behind: bool) -> Almos:
	var almos := await _empty_handed_almos(how)
	var enemy = _rig.spawn_enemy(_rig.tuning_with({"health_maximum": ENEMY_HEALTH}), almos.position + Vector2.DOWN * distance)
	var away := Vector2.DOWN if from_behind else Vector2.UP
	_rig.place_target(enemy.position + away * (_tuning.sight_length_full + BEYOND_NOTICE))
	await _rig.wait_frames(SETTLE_FRAMES)
	return almos


# Breaks the enemy with a hit from a stand-in in front of it that builds a full meter.
func _break(enemy) -> void:
	var hitbox := _rig.hitbox_over(enemy, 0.0, "enemy_hurtbox")
	((hitbox.get_child(0) as CollisionShape2D).shape as CircleShape2D).radius = NARROW_HITBOX_RADIUS
	hitbox.global_position = enemy.global_position + Vector2.DOWN * NARROW_HITBOX_RADIUS
	hitbox.stagger = _tuning.stagger_capacity
	# Settled in the physics server before it is switched on.
	await _rig.wait_frames(SETTLE_FRAMES)
	await _rig.swing(hitbox, 1)
	assert_true(enemy.broken, "the hit should have broken it")


# In pixels. How far below Almos the enemy stands when the distance does not matter: its centre
# inside both Unarmed's reach (counting the enemy's Hurtbox radius) and its critical_range, so that
# it is hit however either is tuned. Almos starts out facing down.
func _enemy_distance() -> float:
	return minf(_unarmed.reach + _enemy_hurtbox_radius(), _unarmed.critical_range) - REACH_MARGIN


# The radius of the circle the training enemy is hurt through.
func _enemy_hurtbox_radius() -> float:
	var enemy := (load(EnemyRig.ENEMY_SCENE_PATH) as PackedScene).instantiate()
	var shape := (enemy.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	var radius := shape.radius if shape != null else 0.0
	enemy.free()
	assert_gt(radius, 0.0, "the enemy's Hurtbox should be a circle")
	return radius


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Holds Interact for as long as a drop takes, and lets go.
func _hold_interact_to_drop() -> void:
	var player := load(AlmosInput.TUNING_PATH) as PlayerTuning
	_almos_input.press_action(&"interact")
	await _rig.wait_frames(ceili(player.drop_hold_time * Engine.physics_ticks_per_second) + HOLD_MARGIN)
	_almos_input.release_action(&"interact")
	await _rig.wait_frames(TAP_FRAMES)


# Waits for the Jump attack to begin, and for the Jump and the strike on landing to be over.
func _wait_for_the_jump_attack_to_end(almos: Almos) -> void:
	await _rig.wait_frames(SETTLE_FRAMES)
	for i in WAIT_FRAME_LIMIT:
		if not almos.airborne and not almos.attacking and not almos.jump_attacking:
			return
		await get_tree().physics_frame
	fail_test("the Jump attack should be over")


# Waits for a swing to begin, if one has not, and be over.
func _wait_for_the_swing_to_end(almos: Almos) -> void:
	await _rig.wait_frames(SETTLE_FRAMES)
	for i in WAIT_FRAME_LIMIT:
		if not almos.attacking and not almos.charging:
			return
		await get_tree().physics_frame
	fail_test("the swing should be over")
