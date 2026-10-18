extends GutTest
## The Weapons' data files, read as a player's Weapons: each of the five, and Unarmed, loads as a
## WeaponData that has a name, a reach and every kind of attack, and owns its attacks outright, so
## that the owner can retune one Weapon without touching another. Each of the five carried Weapons
## has a Weight; Unarmed is not carried, so it has none. No number in a file is pinned here: the
## Weapons' numbers are the owner's to change, and only what must hold of any sensible retune is
## asserted.

# Each carried Weapon's data file.
var carried_weapon_params = ParameterFactory.named_parameters(
	["path"],
	[
		["res://data/sword.tres"],
		["res://data/spear.tres"],
		["res://data/greatsword.tres"],
		["res://data/torch.tres"],
		["res://data/metal_bar.tres"],
	],
)

# Each Weapon's data file, Unarmed included.
var weapon_params = ParameterFactory.named_parameters(
	["path"],
	[
		["res://data/sword.tres"],
		["res://data/spear.tres"],
		["res://data/greatsword.tres"],
		["res://data/torch.tres"],
		["res://data/metal_bar.tres"],
		["res://data/unarmed.tres"],
	],
)


func test_each_weapon_data_file_loads_as_a_weapon_with_a_name(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_ne(weapon.display_name.strip_edges(), "", "display name")


func test_each_carried_weapon_has_a_weight_above_zero(params = use_parameters(carried_weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_gt(weapon.weight, 0.0, "Weight")


func test_unarmed_has_no_weight_as_it_is_not_carried() -> void:
	var weapon := _weapon("res://data/unarmed.tres")
	if weapon == null:
		return

	assert_almost_eq(weapon.weight, 0.0, 0.0001, "Weight")


func test_each_weapon_has_a_reach_above_zero(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_gt(weapon.reach, 0.0, "reach")


func test_each_weapon_has_at_least_one_light_attack(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_gt(weapon.light_attacks.size(), 0, "number of Light attack swings")


func test_each_weapon_has_every_light_swing_filled_in(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_does_not_have(weapon.light_attacks, null, "a Light swing left empty")


func test_each_weapon_has_a_heavy_attack(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_not_null(weapon.heavy_attack, "Heavy attack")


func test_each_weapon_has_a_jump_attack(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_not_null(weapon.jump_attack, "Jump attack")


func test_each_weapon_has_a_critical_hit(params = use_parameters(weapon_params)) -> void:
	var weapon := _weapon(params.path)
	if weapon == null:
		return

	assert_not_null(weapon.critical_attack, "Critical hit")


func test_no_weapon_shares_an_attack_with_another_weapon_or_with_one_of_its_own_swings() -> void:
	var seen := {}
	for params in weapon_params:
		var weapon := _weapon(params.path)
		if weapon == null:
			return
		var attacks: Array[AttackData] = []
		attacks.append_array(weapon.light_attacks)
		attacks.append_array([weapon.heavy_attack, weapon.jump_attack, weapon.critical_attack])
		for attack in attacks:
			assert_false(seen.has(attack), "%s should have its own attack data, not one shared with %s" % [params.path, seen.get(attack, "")])
			seen[attack] = params.path


func _weapon(path: String) -> WeaponData:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s should load as a WeaponData" % path)
	return weapon
