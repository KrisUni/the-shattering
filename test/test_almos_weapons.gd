extends GutTest
## Almos's attacks taking another Weapon at runtime, seen through the real Almos: a Weapon handed
## to his attacks after he is in the scene moves the sword's reach, and his Light swings then
## use that Weapon's damage, reach and frames. Input goes in as actions, and a target with a
## Health of its own shows when and how hard the sword hit. Every expectation comes from the
## Weapons' data files (or a copy a test changes), never from how the code works them out.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const AttackRig := preload("res://test/helpers/attack_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# A tap: held this many physics frames, far shorter than a swing.
const TAP_FRAMES := 3
# In Health points.
const HEALTH_TOLERANCE := 0.0001
# In pixels.
const POSITION_TOLERANCE := 0.01
# In pixels. How far inside or beyond a Weapon's far edge a target's Hurtbox is put, when the
# Weapon is to catch it or just miss it.
const REACH_MARGIN := 1.0
# In physics frames. How much longer than the sword's the startup of a swing is made, to see
# the new Weapon's frames used.
const STARTUP_LONGER_BY := 5

# Each Weapon other than the sword, as its data file.
var other_weapon_params = ParameterFactory.named_parameters(
	["path"],
	[["res://data/spear.tres"], ["res://data/greatsword.tres"], ["res://data/torch.tres"], ["res://data/metal_bar.tres"]],
)

# Each Weapon other than the sword, and whether a target put just inside its far edge, or just
# beyond it, is hit by its Light swing.
var other_weapon_reach_params = ParameterFactory.named_parameters(
	["path", "beyond_far_edge", "hits"],
	[
		["res://data/spear.tres", -REACH_MARGIN, true], ["res://data/spear.tres", REACH_MARGIN, false],
		["res://data/greatsword.tres", -REACH_MARGIN, true], ["res://data/greatsword.tres", REACH_MARGIN, false],
		["res://data/torch.tres", -REACH_MARGIN, true], ["res://data/torch.tres", REACH_MARGIN, false],
		["res://data/metal_bar.tres", -REACH_MARGIN, true], ["res://data/metal_bar.tres", REACH_MARGIN, false],
	],
)

var _almos_input: AlmosInput
var _rig: AttackRig


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = AttackRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


func test_handing_his_attacks_another_weapon_moves_the_sword_to_its_reach(params = use_parameters(other_weapon_params)) -> void:
	var weapon := _weapon(params.path)
	_rig.spawn_almos(_almos_input)
	var sword := _rig.almos.get_node("Sword") as Hitbox

	_attacks().weapon = weapon

	var real := StrikeGeometry.real_box(sword)
	var drawn := StrikeGeometry.drawn_box(sword)
	assert_almost_eq(real.end.x, weapon.reach, POSITION_TOLERANCE, "how far out the box that hurts ends")
	assert_almost_eq(drawn.end.x, real.end.x, POSITION_TOLERANCE, "how far out the drawn sword ends, against the box that hurts")


func test_handing_his_attacks_the_sword_back_puts_the_sword_at_its_reach_again() -> void:
	var started_with := _weapon("res://data/spear.tres")
	var handed_back := _weapon("res://data/sword.tres")
	_rig.spawn_almos(_almos_input, null, started_with)
	var sword := _rig.almos.get_node("Sword") as Hitbox

	_attacks().weapon = handed_back

	assert_almost_eq(StrikeGeometry.real_box(sword).end.x, handed_back.reach, POSITION_TOLERANCE, "how far out the box that hurts ends")


func test_a_light_swing_with_another_weapon_hurts_for_that_weapons_damage(params = use_parameters(other_weapon_params)) -> void:
	var weapon := _weapon(params.path)
	var swing := weapon.light_attacks[0]
	_rig.spawn_almos(_almos_input)
	_attacks().weapon = weapon
	_stand_target_in_reach_of(weapon)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "the target should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, swing.damage, HEALTH_TOLERANCE, "damage of the hit")


func test_a_light_swing_with_another_weapon_reaches_as_far_as_that_weapon_decides(params = use_parameters(other_weapon_reach_params)) -> void:
	var weapon := _weapon(params.path)
	var swing := weapon.light_attacks[0]
	_rig.spawn_almos(_almos_input)
	_attacks().weapon = weapon
	# He starts out facing down. The nearest edge of the Hurtbox is put this far beyond the
	# Weapon's far edge.
	var distance: float = weapon.reach + AttackRig.TARGET_RADIUS + params.beyond_far_edge
	var probe := _rig.place_target(_rig.almos.global_position + Vector2.DOWN * distance)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	var hurt := probe.health.current < AttackRig.TARGET_HEALTH
	assert_eq(hurt, params.hits, "whether the target was hit")


func test_a_light_swing_with_another_weapon_follows_that_weapons_frames() -> void:
	var weapon := _weapon("res://data/spear.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as WeaponData
	var swing := weapon.light_attacks[0]
	swing.startup_frames += STARTUP_LONGER_BY
	_rig.spawn_almos(_almos_input)
	_attacks().weapon = weapon
	_stand_target_in_reach_of(weapon)
	await _rig.wait_frames(SETTLE_FRAMES)

	await _tap_light()
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	var hits := _rig.hits()
	assert_eq(hits.size(), 1, "the target should have been hit once")
	if hits.is_empty():
		return
	assert_eq(hits[0].sample - _rig.first_sample_where("attacking"), swing.startup_frames, "frames after the swing begins that the hit lands")


func test_a_weapon_handed_over_between_swings_is_used_by_the_next_swing() -> void:
	var weapon := _weapon("res://data/greatsword.tres")
	_rig.spawn_almos(_almos_input)
	var first := _attacks_weapon().light_attacks[0]
	_stand_target_in_reach_of(_attacks_weapon())
	await _rig.wait_frames(SETTLE_FRAMES)
	await _tap_light()
	await _rig.wait_frames(first.startup_frames + first.active_frames + first.recovery_frames)
	assert_false(_rig.almos.attacking, "the first swing should be over")

	_attacks().weapon = weapon
	_stand_target_in_reach_of(weapon)
	await _tap_light()
	await _rig.wait_frames(weapon.light_attacks[0].startup_frames + weapon.light_attacks[0].active_frames)

	var damages: Array[float] = []
	for hit in _rig.hits():
		damages.append(hit.damage)
	assert_eq(damages.size(), 2, "the target should have been hit by each swing")
	if damages.size() == 2:
		assert_almost_eq(damages[0], first.damage, HEALTH_TOLERANCE, "damage of the swing with the first Weapon")
		assert_almost_eq(damages[1], weapon.light_attacks[0].damage, HEALTH_TOLERANCE, "damage of the swing with the new Weapon")


func _weapon(path: String) -> WeaponData:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s should load" % path)
	return weapon


func _attacks() -> AlmosAttacks:
	return _rig.almos.get_node("Attacks") as AlmosAttacks


func _attacks_weapon() -> WeaponData:
	return _attacks().weapon


# Stands the target where this Weapon's strike covers it, whatever the Weapon's reach: the strike
# is a box ending at the reach, so the target goes to the middle of it.
func _stand_target_in_reach_of(weapon: WeaponData) -> void:
	var box_width := StrikeGeometry.box_size_in_scene(AlmosInput.ALMOS_SCENE_PATH, ^"Sword").x
	var distance := weapon.reach - box_width / 2.0
	(_rig.target.hurtbox.get_parent() as Node2D).global_position = _rig.almos.global_position + Vector2.DOWN * distance


# Presses the Light attack button and lets go again after a few frames.
func _tap_light() -> void:
	_almos_input.press_action(&"attack_light")
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
