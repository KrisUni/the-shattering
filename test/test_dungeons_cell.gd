extends GutTest
## Cell 3: Almos wakes in the Dungeons stripped of his Weapon (and Armour) with his Flasks. The only way out of Cell 3 is
## closed by living roots, which burn open when the flame of the Cell's torch, Pulled and Shoved
## at them, or any other flame thrown at them, sets them alight.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const FLAMMABLE_PATH := "res://scenes/world/flammable.tscn"
const FIREBALL_PATH := "res://data/fireball.tres"
const FIRE_PATH := "res://data/fire.tres"
const AREA_LOAD_PATH := "res://data/area_load.tres"
# In pixels. The size of the view the Dungeons is shown in: the project's default window.
const VIEW_SIZE := Vector2i(1152, 648)
# In pixels, in Cell 3. Where Almos stands to Pull the torch's flame and Shove it down at the roots:
# within Pull's flame range of the torch and well clear of the roots.
const STANDING_SPOT := Vector2(560.0, 548.0)
# In pixels, in Cell 3. Far enough from the roots that a Fire there does not spread to them.
const FIRE_SPOT := Vector2(560.0, 440.0)
const TAP_FRAMES := 2
const MARGIN_FRAMES := 8
# In physics frames. Long enough to walk from the standing spot to the door, and to push on after.
const WALK_FRAMES := 240

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func _host_in_the_dungeons() -> AreaHost:
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	add_child_autofree(view)
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	view.add_child(host)
	return host


func test_almos_wakes_in_cell_3_with_no_weapon_in_hand_or_carried() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"cell_3"), "he should wake in Cell 3")
	assert_eq(host.almos.weapons.carried.size(), 0, "he should carry no Weapon")
	assert_null(host.almos.weapons.in_hand, "his hands should be empty")


func test_almos_woken_without_a_weapon_attacks_unarmed() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var attacks := host.almos.get_node("Attacks") as AlmosAttacks
	assert_eq(attacks.weapon, host.almos.unarmed, "with empty hands his attacks should be Unarmed")


func test_almos_wakes_with_his_flasks_full() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)

	var flasks := host.almos.flasks
	assert_gt(flasks.health_charges_maximum, 0, "he should have Flasks")
	assert_eq(flasks.health_charges, flasks.health_charges_maximum, "his Health Flask should be full")
	assert_gt(flasks.mana_charges_maximum, 0, "he should carry the Mana Flask")


func test_almos_walking_at_the_door_while_the_roots_are_whole_stays_in_cell_3() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var dungeons := host.current_space as DungeonsBuilding
	var cell := dungeons.room(&"cell_3")
	host.almos.global_position = cell.to_global(STANDING_SPOT)

	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)

	assert_eq(dungeons.current_room, cell, "the roots should keep him in Cell 3")


func test_almos_pulls_the_torchs_flame_and_shoves_it_at_the_roots_to_burn_them_open_and_walks_out() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var dungeons := host.current_space as DungeonsBuilding
	var cell := dungeons.room(&"cell_3")
	var roots := cell.get_node("Roots") as PathBlocker
	var torch := cell.get_node("Torch") as Torch
	host.almos.global_position = cell.to_global(STANDING_SPOT)
	host.almos.facing = Vector2.DOWN

	await _tap(&"cast_spell")
	await wait_physics_frames((load(FIREBALL_PATH) as SpellData).wind_up_frames + MARGIN_FRAMES)
	assert_true(host.almos.spell.holding, "he should hold the torch's flame")
	assert_false(torch.lit, "the torch's flame was taken")
	assert_false(roots.open, "the roots are whole while he only holds the flame")
	await _tap(&"cast_spell")
	await _wait_for_the_fire_to_burn_out()

	assert_true(roots.open, "the roots should have burnt open")
	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)
	assert_eq(dungeons.current_room, dungeons.room(&"corridor_1"), "he should walk out through the door into the corridor")


func test_a_flame_pulled_from_a_fire_and_shoved_at_the_roots_also_burns_them_open() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	var dungeons := host.current_space as DungeonsBuilding
	var cell := dungeons.room(&"cell_3")
	var roots := cell.get_node("Roots") as PathBlocker
	# The torch is put out: the nearest lit torch's flame is taken before a Fire's.
	(cell.get_node("Torch") as Torch).extinguish()
	var fire := (load(FLAMMABLE_PATH) as PackedScene).instantiate() as Flammable
	cell.add_child(fire)
	fire.global_position = cell.to_global(FIRE_SPOT)
	fire.ignite()
	host.almos.global_position = cell.to_global(STANDING_SPOT)
	host.almos.facing = Vector2.DOWN

	await _tap(&"cast_spell")
	await wait_physics_frames((load(FIREBALL_PATH) as SpellData).wind_up_frames + MARGIN_FRAMES)
	assert_true(host.almos.spell.holding, "he should hold the Fire's flame")
	await _tap(&"cast_spell")
	await _wait_for_the_fire_to_burn_out()

	assert_true(roots.open, "a flame from a Fire should burn the roots open too")


func test_a_death_before_a_checkpoint_returns_almos_to_cell_3_alive() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_roots_out_and_die_in_the_corridor(host)

	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"cell_3"), "he should be back in Cell 3")
	assert_true(dungeons.room(&"cell_3").get_rect().has_point(host.almos.global_position), "he should stand inside Cell 3")
	assert_false(host.almos.dead, "he should be alive again")


func test_a_death_before_a_checkpoint_makes_the_roots_whole_again() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_roots_out_and_die_in_the_corridor(host)

	var roots := (host.current_space as DungeonsBuilding).room(&"cell_3").get_node("Roots") as PathBlocker
	assert_false(roots.open, "the roots should be whole")
	assert_false(WorldState.is_burnt(&"dungeons/cell_3/roots"), "the roots should not be remembered as burnt")


func test_almos_walking_at_the_door_after_a_death_before_a_checkpoint_stays_in_cell_3() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_roots_out_and_die_in_the_corridor(host)
	var dungeons := host.current_space as DungeonsBuilding
	var cell := dungeons.room(&"cell_3")
	host.almos.global_position = cell.to_global(STANDING_SPOT)

	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)

	assert_eq(dungeons.current_room, cell, "the roots should keep him in Cell 3")


func test_almos_burns_the_roots_out_again_after_a_death_before_a_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_roots_out_and_die_in_the_corridor(host)
	var cell := (host.current_space as DungeonsBuilding).room(&"cell_3")
	assert_true((cell.get_node("Torch") as Torch).lit, "the torch should be lit again")

	await _pull_and_shove_the_torchs_flame_at_the_roots(host)

	assert_true((cell.get_node("Roots") as PathBlocker).open, "the roots should burn open again")


func test_almos_carries_no_weapon_after_a_death_before_a_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_roots_out_and_die_in_the_corridor(host)

	assert_eq(host.almos.weapons.carried.size(), 0, "he should carry no Weapon")


func test_almos_hands_are_empty_after_a_death_before_a_checkpoint() -> void:
	var host := _host_in_the_dungeons()
	await wait_physics_frames(2)
	await _burn_the_roots_out_and_die_in_the_corridor(host)

	assert_null(host.almos.weapons.in_hand, "his hands should be empty")


# He burns the roots open, walks out into the corridor, and dies there; this returns when the
# Death's pause is over and he has been sent back.
func _burn_the_roots_out_and_die_in_the_corridor(host: AreaHost) -> void:
	await _pull_and_shove_the_torchs_flame_at_the_roots(host)
	_almos_input.press_action(&"move_down")
	await wait_physics_frames(WALK_FRAMES)
	_almos_input.release_action(&"move_down")
	var dungeons := host.current_space as DungeonsBuilding
	assert_eq(dungeons.current_room, dungeons.room(&"corridor_1"), "he should have walked out into the corridor")

	host.almos.health.take_damage(host.almos.health.maximum)
	var player := load(AlmosInput.TUNING_PATH) as PlayerTuning
	# The Death's pause, then the area load, which fades out and back in.
	var fade_seconds := (load(AREA_LOAD_PATH) as AreaLoadTuning).fade_seconds
	await wait_physics_frames(ceili((player.death_pause + 2.0 * fade_seconds) * Engine.physics_ticks_per_second) + MARGIN_FRAMES)
	assert_false(host.loading, "the return should be done")
	assert_ne(host.current_space, dungeons, "the Dungeons should have been made new")


func _pull_and_shove_the_torchs_flame_at_the_roots(host: AreaHost) -> void:
	var cell := (host.current_space as DungeonsBuilding).room(&"cell_3")
	host.almos.global_position = cell.to_global(STANDING_SPOT)
	host.almos.facing = Vector2.DOWN
	await _tap(&"cast_spell")
	await wait_physics_frames((load(FIREBALL_PATH) as SpellData).wind_up_frames + MARGIN_FRAMES)
	await _tap(&"cast_spell")
	await _wait_for_the_fire_to_burn_out()


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Long enough for the fireball to fly to the roots, and for them to burn for the burn time.
func _wait_for_the_fire_to_burn_out() -> void:
	var fire := load(FIRE_PATH) as FireTuning
	var fireball := load(FIREBALL_PATH) as SpellData
	var flight_seconds := fireball.fireball_range / fireball.fireball_speed
	await wait_physics_frames(ceili((flight_seconds + fire.burn_time) * Engine.physics_ticks_per_second) + MARGIN_FRAMES)
