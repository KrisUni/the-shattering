extends GutTest
## The Weapons Almos carries, tested directly through its public interface: picking up, cycling
## in pickup order, dropping, and what is in hand after each. The Weapons are the shipped data
## files, told apart by their names.

const SWORD_PATH := "res://data/sword.tres"
const SPEAR_PATH := "res://data/spear.tres"
const TORCH_PATH := "res://data/torch.tres"
const METAL_BAR_PATH := "res://data/metal_bar.tres"


func test_he_carries_nothing_and_has_empty_hands_at_first() -> void:
	var weapons := _new_weapons()

	assert_eq(weapons.carried.size(), 0)
	assert_null(weapons.in_hand)


func test_the_first_weapon_picked_up_comes_to_hand() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)

	weapons.pick_up(sword)

	assert_same(weapons.in_hand, sword)
	assert_eq(weapons.carried, [sword])


func test_a_weapon_picked_up_with_one_in_hand_is_carried_after_it_and_stays_out_of_hand() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	var spear := _weapon(SPEAR_PATH)
	weapons.pick_up(sword)

	weapons.pick_up(spear)

	assert_eq(weapons.carried, [sword, spear])
	assert_same(weapons.in_hand, sword)


func test_there_is_no_limit_to_how_many_he_carries() -> void:
	var weapons := _new_weapons()
	var all := [_weapon(SWORD_PATH), _weapon(SPEAR_PATH), _weapon(TORCH_PATH), _weapon(METAL_BAR_PATH)]
	for weapon in all:
		weapons.pick_up(weapon)
		weapons.pick_up(weapon)

	assert_eq(weapons.carried.size(), all.size() * 2)


func test_picking_up_nothing_changes_nothing() -> void:
	var weapons := _new_weapons()
	weapons.pick_up(_weapon(SWORD_PATH))
	watch_signals(weapons)

	weapons.pick_up(null)

	assert_eq(weapons.carried.size(), 1)
	assert_signal_not_emitted(weapons, "changed")


func test_changing_the_list_he_is_given_does_not_change_what_he_carries() -> void:
	var weapons := _new_weapons()
	weapons.pick_up(_weapon(SWORD_PATH))

	weapons.carried.clear()

	assert_eq(weapons.carried.size(), 1)


func test_switching_puts_the_next_weapon_in_hand() -> void:
	var weapons := _new_weapons()
	var spear := _weapon(SPEAR_PATH)
	weapons.pick_up(_weapon(SWORD_PATH))
	weapons.pick_up(spear)

	weapons.switch_to_next()

	assert_same(weapons.in_hand, spear)


func test_switching_cycles_in_pickup_order_and_wraps_to_the_first() -> void:
	var weapons := _new_weapons()
	var order := [_weapon(SWORD_PATH), _weapon(SPEAR_PATH), _weapon(TORCH_PATH)]
	for weapon in order:
		weapons.pick_up(weapon)

	var seen := []
	for i in order.size() + 1:
		weapons.switch_to_next()
		seen.append(weapons.in_hand)

	assert_eq(seen, [order[1], order[2], order[0], order[1]])


func test_switching_leaves_what_is_carried_as_it_was() -> void:
	var weapons := _new_weapons()
	var order := [_weapon(SWORD_PATH), _weapon(SPEAR_PATH), _weapon(TORCH_PATH)]
	for weapon in order:
		weapons.pick_up(weapon)

	weapons.switch_to_next()

	assert_eq(weapons.carried, order)


func test_switching_with_one_weapon_changes_nothing() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	weapons.pick_up(sword)
	watch_signals(weapons)

	weapons.switch_to_next()

	assert_same(weapons.in_hand, sword)
	assert_signal_not_emitted(weapons, "changed")


func test_switching_with_empty_hands_changes_nothing() -> void:
	var weapons := _new_weapons()
	watch_signals(weapons)

	weapons.switch_to_next()

	assert_null(weapons.in_hand)
	assert_signal_not_emitted(weapons, "changed")


func test_a_weapon_picked_up_after_a_switch_goes_to_the_end_and_the_one_in_hand_stays() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	var spear := _weapon(SPEAR_PATH)
	var torch := _weapon(TORCH_PATH)
	weapons.pick_up(sword)
	weapons.pick_up(spear)
	weapons.switch_to_next()

	weapons.pick_up(torch)

	assert_eq(weapons.carried, [sword, spear, torch])
	assert_same(weapons.in_hand, spear)


func test_dropping_returns_the_weapon_that_was_in_hand_and_no_longer_carries_it() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	var spear := _weapon(SPEAR_PATH)
	weapons.pick_up(sword)
	weapons.pick_up(spear)

	var dropped := weapons.drop()

	assert_same(dropped, sword)
	assert_eq(weapons.carried, [spear])


func test_after_a_drop_the_next_weapon_in_the_list_after_the_dropped_one_comes_to_hand() -> void:
	var weapons := _new_weapons()
	var order := [_weapon(SWORD_PATH), _weapon(SPEAR_PATH), _weapon(TORCH_PATH)]
	for weapon in order:
		weapons.pick_up(weapon)
	weapons.switch_to_next()

	weapons.drop()

	assert_same(weapons.in_hand, order[2], "the torch follows the spear")
	assert_eq(weapons.carried, [order[0], order[2]])


func test_dropping_the_last_in_the_list_brings_the_first_to_hand() -> void:
	var weapons := _new_weapons()
	var order := [_weapon(SWORD_PATH), _weapon(SPEAR_PATH), _weapon(TORCH_PATH)]
	for weapon in order:
		weapons.pick_up(weapon)
	weapons.switch_to_next()
	weapons.switch_to_next()

	weapons.drop()

	assert_same(weapons.in_hand, order[0])


func test_dropping_the_last_weapon_carried_empties_his_hands() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	weapons.pick_up(sword)

	var dropped := weapons.drop()

	assert_same(dropped, sword)
	assert_null(weapons.in_hand)
	assert_eq(weapons.carried.size(), 0)


func test_dropping_with_empty_hands_returns_nothing_and_changes_nothing() -> void:
	var weapons := _new_weapons()
	watch_signals(weapons)

	var dropped := weapons.drop()

	assert_null(dropped)
	assert_signal_not_emitted(weapons, "changed")


func test_a_weapon_picked_up_with_empty_hands_after_a_drop_comes_to_hand() -> void:
	var weapons := _new_weapons()
	weapons.pick_up(_weapon(SWORD_PATH))
	weapons.drop()
	var torch := _weapon(TORCH_PATH)

	weapons.pick_up(torch)

	assert_same(weapons.in_hand, torch)


func test_the_same_weapon_carried_twice_is_dropped_once_at_a_time() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	var spear := _weapon(SPEAR_PATH)
	weapons.pick_up(sword)
	weapons.pick_up(spear)
	weapons.pick_up(sword)
	weapons.switch_to_next()
	weapons.switch_to_next()

	weapons.drop()

	assert_eq(weapons.carried, [sword, spear], "only the one in hand, the second sword, goes")
	assert_same(weapons.in_hand, sword)


func test_changed_is_emitted_once_for_each_pick_up_switch_and_drop() -> void:
	var weapons := _new_weapons()
	watch_signals(weapons)

	weapons.pick_up(_weapon(SWORD_PATH))
	weapons.pick_up(_weapon(SPEAR_PATH))
	weapons.switch_to_next()
	weapons.drop()

	assert_signal_emit_count(weapons, "changed", 4)


func _new_weapons() -> AlmosWeapons:
	var weapons := AlmosWeapons.new()
	autofree(weapons)
	return weapons


func _weapon(path: String) -> WeaponData:
	var weapon := load(path) as WeaponData
	assert_not_null(weapon, "%s should load as a Weapon" % path)
	return weapon


func test_replacing_the_weapon_in_hand_keeps_its_place_in_the_list_and_in_hand() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	var torch := _weapon(TORCH_PATH)
	var bar := _weapon(METAL_BAR_PATH)
	var spear := _weapon(SPEAR_PATH)
	weapons.pick_up(sword)
	weapons.pick_up(torch)
	weapons.pick_up(bar)
	weapons.switch_to_next()

	weapons.replace_in_hand(spear)

	assert_eq(weapons.carried, [sword, spear, bar])
	assert_same(weapons.in_hand, spear)
	weapons.switch_to_next()
	assert_same(weapons.in_hand, bar, "the cycle goes on from the replacement")


func test_replacing_with_empty_hands_or_with_nothing_changes_nothing() -> void:
	var weapons := _new_weapons()
	var sword := _weapon(SWORD_PATH)
	weapons.replace_in_hand(sword)
	assert_eq(weapons.carried.size(), 0, "empty hands: nothing to replace")
	weapons.pick_up(sword)

	weapons.replace_in_hand(null)

	assert_eq(weapons.carried, [sword])
	assert_same(weapons.in_hand, sword)
