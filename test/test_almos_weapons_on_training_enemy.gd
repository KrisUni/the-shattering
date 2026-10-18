extends GutTest
## Almos swinging a Weapon other than the sword at the real training enemy, a whole scene with a
## Health of its own: the Weapon's own damage comes off the enemy's Health, for a Light swing and for
## a Heavy attack. Input goes in as actions. Every expectation comes from the Weapons' data files,
## never from how the code works them out, and nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")
const StrikeGeometry := preload("res://test/helpers/strike_geometry.gd")

const SETTLE_FRAMES := AlmosInput.SETTLE_FRAMES
# A tap: held this many physics frames, far shorter than a swing, and short of any charge start.
const TAP_FRAMES := 3
# In pixels. The least far below Almos the enemy stands: clear of his body. Almos starts out facing
# down.
const ENEMY_DISTANCE := 30.0
# In Health points. Far more than any run of hits in these tests can take off, so that no retune
# of a Weapon's damage kills the enemy.
const ENEMY_HEALTH := 1000000.0
# In Health points.
const HEALTH_TOLERANCE := 0.0001

# Each Weapon other than the sword, as its data file.
var other_weapon_params = ParameterFactory.named_parameters(
	["path"],
	[["res://data/spear.tres"], ["res://data/greatsword.tres"], ["res://data/torch.tres"], ["res://data/metal_bar.tres"]],
)

var _almos_input: AlmosInput
var _rig: EnemyRig


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_rig = EnemyRig.new(self)


func after_each() -> void:
	_rig.stop_sampling()
	_almos_input.release_everything()


func test_a_light_swing_with_another_weapon_takes_that_weapons_damage_off_the_training_enemy(params = use_parameters(other_weapon_params)) -> void:
	var weapon := _weapon(params.path)
	var swing := weapon.light_attacks[0]
	_spawn_fight(weapon)

	await _tap(&"attack_light")
	await _rig.wait_frames(swing.startup_frames + swing.active_frames)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, swing.damage, HEALTH_TOLERANCE, "damage of the hit")


func test_a_heavy_attack_with_another_weapon_takes_that_weapons_heavy_damage_off_the_training_enemy(params = use_parameters(other_weapon_params)) -> void:
	var weapon := _weapon(params.path)
	var heavy := weapon.heavy_attack
	_spawn_fight(weapon)

	await _tap(&"attack_heavy")
	await _rig.wait_frames(heavy.startup_frames + heavy.active_frames)

	var hits := _rig.drops("enemy_health")
	assert_eq(hits.size(), 1, "the enemy should have been hit once")
	if hits.is_empty():
		return
	assert_almost_eq(hits[0].damage, heavy.damage, HEALTH_TOLERANCE, "damage of the hit")


func _weapon(path: String) -> WeaponData:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s should load" % path)
	return weapon


# Almos with the sword in the scene, handed this Weapon once he is there, and the training enemy
# below him with Health enough to take any hit. The enemy has no target, so it only stands there.
func _spawn_fight(weapon: WeaponData):
	var almos = _almos_input.spawn_almos()
	(almos.get_node("Attacks") as AlmosAttacks).weapon = weapon
	# The strike is a box ending at the Weapon's reach, so the enemy goes to the middle of it,
	# though never closer than it is clear of Almos's body.
	var box_width := StrikeGeometry.box_size_in_scene(AlmosInput.ALMOS_SCENE_PATH, ^"Sword").x
	var distance := maxf(weapon.reach - box_width / 2.0, ENEMY_DISTANCE)
	_rig.spawn_enemy(_rig.tuning_with({"health_maximum": ENEMY_HEALTH}), almos.position + Vector2.DOWN * distance)
	return almos


# Presses the button and lets go again after a few frames, once the press has reached Almos.
func _tap(action: StringName) -> void:
	await _rig.wait_frames(SETTLE_FRAMES)
	_almos_input.press_action(action)
	await _rig.wait_frames(TAP_FRAMES)
	_almos_input.release_action(action)
