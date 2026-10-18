extends GutTest
## The Weapons' data files, read as a player's Weapons: each has a display name and a Weight, and
## the four that were made as clones of the sword have its frame data, Stamina costs and Stagger
## with only their reach and damage changed. Every expectation is derived from the sword's own
## data file and the factors settled for the clones, so retuning the sword moves them with it.

const SWORD_PATH := "res://data/sword.tres"
const TOLERANCE := 0.0001

# Each clone's data file, its reach in pixels, and the factor every damage figure in it is
# the sword's scaled by.
var clone_params = ParameterFactory.named_parameters(
	["path", "reach", "damage_factor"],
	[
		["res://data/spear.tres", 60.0, 0.9],
		["res://data/greatsword.tres", 52.0, 1.5],
		["res://data/torch.tres", 34.0, 0.7],
		["res://data/metal_bar.tres", 40.0, 1.1],
	],
)

# Each Weapon's data file, its display name and its Weight.
var identity_params = ParameterFactory.named_parameters(
	["path", "display_name", "weight"],
	[
		["res://data/sword.tres", "Sword", 3.0],
		["res://data/spear.tres", "Spear", 4.0],
		["res://data/greatsword.tres", "Greatsword", 8.0],
		["res://data/torch.tres", "Torch", 1.0],
		["res://data/metal_bar.tres", "Metal bar", 5.0],
	],
)


func test_each_weapon_data_file_has_its_display_name_and_weight(params = use_parameters(identity_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_eq(weapon.display_name, params.display_name, "display name")
	assert_almost_eq(weapon.weight, params.weight, TOLERANCE, "Weight")


func test_a_clone_reaches_as_far_as_the_table_says(params = use_parameters(clone_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_almost_eq(weapon.reach, params.reach, TOLERANCE, "reach")


func test_a_clone_hurts_the_sword_s_damage_times_its_factor_in_every_attack(params = use_parameters(clone_params)) -> void:
	var weapon := _weapon(params.path)
	var sword := _weapon(SWORD_PATH)
	if weapon == null or sword == null:
		return
	var factor: float = params.damage_factor

	assert_eq(weapon.light_attacks.size(), sword.light_attacks.size(), "number of Light attack swings")
	for i in mini(weapon.light_attacks.size(), sword.light_attacks.size()):
		assert_almost_eq(weapon.light_attacks[i].damage, sword.light_attacks[i].damage * factor, TOLERANCE, "damage of Light swing %d" % (i + 1))
	assert_almost_eq(weapon.heavy_attack.damage, sword.heavy_attack.damage * factor, TOLERANCE, "damage of the Heavy attack")
	assert_almost_eq(weapon.heavy_attack.charged_damage, sword.heavy_attack.charged_damage * factor, TOLERANCE, "damage of the charged Heavy attack")
	assert_almost_eq(weapon.jump_attack.damage, sword.jump_attack.damage * factor, TOLERANCE, "damage of the Jump attack")
	assert_almost_eq(weapon.critical_attack.damage, sword.critical_attack.damage * factor, TOLERANCE, "damage of the Critical hit")


func test_a_clone_has_the_sword_s_frame_data_stamina_costs_and_stagger(params = use_parameters(clone_params)) -> void:
	var weapon := _weapon(params.path)
	var sword := _weapon(SWORD_PATH)
	if weapon == null or sword == null:
		return

	assert_eq(weapon.light_attacks.size(), sword.light_attacks.size(), "number of Light attack swings")
	for i in mini(weapon.light_attacks.size(), sword.light_attacks.size()):
		_assert_same_but_damage(weapon.light_attacks[i], sword.light_attacks[i], "Light swing %d" % (i + 1))
	_assert_same_but_damage(weapon.heavy_attack, sword.heavy_attack, "Heavy attack")
	assert_eq(weapon.heavy_attack.charge_start_frames, sword.heavy_attack.charge_start_frames, "Heavy attack charge start")
	assert_eq(weapon.heavy_attack.charge_frames_max, sword.heavy_attack.charge_frames_max, "Heavy attack full charge")
	assert_almost_eq(weapon.heavy_attack.charged_stamina_cost, sword.heavy_attack.charged_stamina_cost, TOLERANCE, "charged Heavy attack Stamina cost")
	assert_almost_eq(weapon.heavy_attack.charged_stagger, sword.heavy_attack.charged_stagger, TOLERANCE, "charged Heavy attack Stagger")
	_assert_same_but_damage(weapon.jump_attack, sword.jump_attack, "Jump attack")
	_assert_same_but_damage(weapon.critical_attack, sword.critical_attack, "Critical hit")
	assert_almost_eq(weapon.critical_range, sword.critical_range, TOLERANCE, "Critical range")
	assert_eq(weapon.attack_buffer_frames, sword.attack_buffer_frames, "attack buffer")


func test_a_clone_shares_no_sub_resource_with_the_sword_or_with_another_clone() -> void:
	var seen := {}
	var paths: Array[String] = [SWORD_PATH]
	for params in clone_params:
		paths.append(params.path)
	for path in paths:
		var weapon := _weapon(path)
		if weapon == null:
			return
		var attacks: Array[AttackData] = []
		attacks.append_array(weapon.light_attacks)
		attacks.append_array([weapon.heavy_attack, weapon.jump_attack, weapon.critical_attack])
		for attack in attacks:
			assert_false(seen.has(attack), "%s should have its own attack data, not one shared with another file" % path)
			seen[attack] = path


func _weapon(path: String) -> WeaponData:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s should load as a WeaponData" % path)
	return weapon


func _assert_same_but_damage(attack: AttackData, sword_attack: AttackData, what: String) -> void:
	assert_eq(attack.startup_frames, sword_attack.startup_frames, "%s startup frames" % what)
	assert_eq(attack.active_frames, sword_attack.active_frames, "%s active frames" % what)
	assert_eq(attack.recovery_frames, sword_attack.recovery_frames, "%s recovery frames" % what)
	assert_almost_eq(attack.stamina_cost, sword_attack.stamina_cost, TOLERANCE, "%s Stamina cost" % what)
	assert_almost_eq(attack.stagger, sword_attack.stagger, TOLERANCE, "%s Stagger" % what)
