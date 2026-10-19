extends GutTest
## Setting things alight, in the test room with the real Almos, the real training enemy and the
## shipped numbers, driven through the Interact, Switch, cast_spell, attack_light and move actions:
## a fireball lights the flammable thing it hits and stops there, a lit torch in hand swung into one
## lights it without being drawn, and nothing else lights one: not walking into it, not a sword, not
## an unlit club. Distances and waits are worked from the data files, so nothing here pins a number
## in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const FIRE_PATH := "res://data/fire.tres"
const TORCH_PATH := "res://data/torch.tres"
const UNLIT_TORCH_PATH := "res://data/torch_unlit.tres"
const SWORD_PATH := "res://data/sword.tres"
# In physics frames. How long a button is held for a tap, and how long to let a press take effect.
const TAP_FRAMES := 3
const PRESS_FRAMES := 3
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 6
# In pixels. Half the width of a flammable thing's box.
const HALF_WIDTH := 16.0
# In pixels. How far in front of a flammable thing's near edge Almos stands to swing at it: well
# inside the torch's reach.
const SWING_GAP := 15.0
# In pixels. How far short of the enemy a flammable thing is put when it is to stand between.
const SHORT_OF_ENEMY := 120.0
# In pixels. How far from the stand torch Almos stands to cast, within Flame draw's range.
const BESIDE_THE_STAND_TORCH := 20.0

var _almos_input: AlmosInput
var _spell: SpellData
var _fire: FireTuning
var _room: Node
var _almos: Almos
var _enemy
var _barrel: Flammable
var _bed: Flammable
var _curtain: Flammable
var _fireballs_thrown := 0
var _floor_spot: Vector2


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_spell = load(FLAME_DRAW_PATH) as SpellData
	_fire = load(FIRE_PATH) as FireTuning
	_fireballs_thrown = 0


func after_each() -> void:
	_almos_input.release_everything()


func test_a_fireball_lights_the_curtain_it_hits() -> void:
	_set_up_room()
	var stand_torch := _room.get_node("StandTorch") as Torch
	_almos.global_position = stand_torch.global_position + Vector2.LEFT * BESIDE_THE_STAND_TORCH
	_curtain.global_position = _almos.global_position + Vector2.UP * (_spell.fireball_range / 2.0)
	_almos.facing = Vector2.UP

	await _cast()

	assert_eq(_fireballs_thrown, 1, "a fireball is thrown")
	assert_true(_curtain.burning)


func test_a_fireball_that_hits_no_flammable_thing_lights_none() -> void:
	_set_up_room()
	var stand_torch := _room.get_node("StandTorch") as Torch
	_almos.global_position = stand_torch.global_position + Vector2.LEFT * BESIDE_THE_STAND_TORCH
	_curtain.global_position = _almos.global_position + Vector2.UP * (_spell.fireball_range / 2.0) + Vector2.RIGHT * 100.0
	_almos.facing = Vector2.UP

	await _cast()

	assert_eq(_fireballs_thrown, 1, "a fireball is thrown")
	assert_false(_curtain.burning)


func test_a_fireball_stops_at_a_flammable_thing_between_almos_and_the_enemy() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_almos.global_position = Vector2(300.0, 324.0)
	_enemy.global_position = _almos.global_position + Vector2.RIGHT * (_spell.fireball_range - 40.0)
	_barrel.global_position = _enemy.global_position + Vector2.LEFT * SHORT_OF_ENEMY
	_almos.facing = Vector2.RIGHT
	var health_before: float = _enemy.health.current

	await _cast()

	assert_true(_barrel.burning, "the barrel catches")
	assert_eq(_enemy.health.current, health_before, "the fireball stopped before the enemy")


func test_a_fireball_reaches_the_enemy_when_no_flammable_thing_is_in_the_way() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_almos.global_position = Vector2(300.0, 324.0)
	_enemy.global_position = _almos.global_position + Vector2.RIGHT * (_spell.fireball_range - 40.0)
	_almos.facing = Vector2.RIGHT
	var health_before: float = _enemy.health.current

	await _cast()

	assert_lt(_enemy.health.current, health_before, "the fireball hurts the enemy")


func test_a_fireball_cast_from_inside_a_flammable_thing_flies_on_to_the_enemy_and_does_not_light_it() -> void:
	_set_up_room()
	var enemy_curtain := _room.get_node("EnemyCurtain/Flammable") as Flammable
	await _carry_the_torch_in_hand()
	_almos.global_position = _room.get_node("EnemyCurtain").global_position
	_enemy.global_position = _almos.global_position + Vector2.RIGHT * (_spell.fireball_range - 40.0)
	_enemy.target = null
	_almos.facing = Vector2.RIGHT
	var health_before: float = _enemy.health.current

	await _cast()

	assert_eq(_fireballs_thrown, 1, "control: a fireball is thrown")
	assert_lt(_enemy.health.current, health_before, "the fireball hurts the enemy")
	assert_false(enemy_curtain.burning, "the thing he stands in does not catch")


func test_the_lit_torch_in_hand_swung_at_the_barrel_lights_it() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_to_swing_at(_barrel)

	await _swing_light()

	assert_true(_barrel.burning)


func test_lighting_a_thing_with_the_torch_in_hand_leaves_the_torch_lit_and_in_hand() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_to_swing_at(_barrel)
	watch_signals(_almos.carried_torch)

	await _swing_light()

	assert_true(_barrel.burning, "the barrel caught")
	assert_true(_almos.carried_torch.lit, "the torch is lit")
	assert_signal_not_emitted(_almos.carried_torch, "put_out")
	assert_same(_almos.weapons.in_hand, load(TORCH_PATH), "and still in hand, not the unlit club")


func test_the_torch_that_lit_a_thing_can_still_be_drawn() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_to_swing_at(_barrel)
	await _swing_light()
	_almos.global_position = _floor_spot
	_barrel.global_position = _floor_spot + Vector2.UP * 300.0

	await _cast()

	assert_eq(_fireballs_thrown, 1, "the flame is drawn")
	assert_same(_almos.weapons.in_hand, load(UNLIT_TORCH_PATH))


func test_walking_into_a_flammable_thing_with_the_torch_in_hand_does_not_light_it() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_almos.global_position = _barrel.global_position + Vector2.LEFT * 60.0
	_almos_input.press_action(&"move_right")

	await wait_physics_frames(60)

	assert_gt(_almos.global_position.x, _barrel.global_position.x, "he walked through it")
	assert_false(_barrel.burning)


func test_standing_beside_a_flammable_thing_with_the_torch_in_hand_does_not_light_it() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_to_swing_at(_barrel)

	await wait_physics_frames(60)

	assert_false(_barrel.burning)


func test_a_swing_of_the_sword_does_not_light_a_flammable_thing() -> void:
	_set_up_room()
	await _carry_the_torch()
	_stand_to_swing_at(_barrel)
	assert_same(_almos.weapons.in_hand, load(SWORD_PATH), "the sword is in hand")

	await _swing_light()

	assert_false(_barrel.burning)


func test_a_swing_of_the_unlit_club_does_not_light_a_flammable_thing() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_almos.global_position = _floor_spot
	await _cast()
	_stand_to_swing_at(_barrel)
	assert_same(_almos.weapons.in_hand, load(UNLIT_TORCH_PATH), "the unlit club is in hand")

	await _swing_light()

	assert_false(_barrel.burning)


func test_a_swing_of_the_torch_that_does_not_reach_a_flammable_thing_does_not_light_it() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	var reach := (load(TORCH_PATH) as WeaponData).reach
	_almos.global_position = _barrel.global_position + Vector2.LEFT * (HALF_WIDTH + reach + SWING_GAP)
	_almos.facing = Vector2.RIGHT

	await _swing_light()

	assert_false(_barrel.burning)


func test_fire_beside_almos_does_not_draw_the_torch_in_his_hand() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_barrel.global_position = _almos.global_position
	_barrel.ignite()

	await wait_physics_frames(_frames(_fire.burn_time) - MARGIN_FRAMES)

	assert_true(_barrel.burning)
	assert_true(_almos.carried_torch.lit, "still lit")
	assert_same(_almos.weapons.in_hand, load(TORCH_PATH), "still the torch, not the unlit club")


func test_the_test_rooms_barrel_bed_and_curtain_are_hiding_spots_that_burn() -> void:
	_set_up_room()

	for thing in [_barrel, _bed, _curtain]:
		assert_eq(thing.kind, Flammable.Kind.HIDING_SPOT)
		assert_true(thing.ignite(), "%s catches" % thing.get_parent().name)


func test_a_burnt_out_hiding_spot_can_no_longer_be_entered() -> void:
	_set_up_room()
	_almos.global_position = _barrel.global_position + Vector2.LEFT * 10.0
	_barrel.ignite()
	await wait_physics_frames(_frames(_fire.burn_time) + MARGIN_FRAMES)
	assert_true(_barrel.burnt_out)

	await _tap(&"interact")

	assert_false(_almos.hiding, "he did not get in")


# --- set-up ---


# The test room as shipped, without the Sound hunter, the enemy put out of the way, and Almos with
# his sword in hand. The flammable things of the room are found by name. The test frees it all.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_enemy = _room.get_node("TrainingEnemy")
	_barrel = _room.get_node("Barrel/Flammable") as Flammable
	_bed = _room.get_node("Bed/Flammable") as Flammable
	_curtain = _room.get_node("Curtain/Flammable") as Flammable
	_floor_spot = _room.get_node("TorchPickup").global_position
	_enemy.global_position = Vector2(100.0, 100.0)
	_almos.facing = Vector2.RIGHT
	_almos.spell.fireball_thrown.connect(_on_fireball_thrown)


# Almos picks the torch up from the floor of the room. It is behind the sword in his list, so the
# sword stays in hand.
func _carry_the_torch() -> void:
	_almos.global_position = _floor_spot
	await _tap(&"interact")


# As _carry_the_torch, then a tap of Switch puts the torch in hand.
func _carry_the_torch_in_hand() -> void:
	await _carry_the_torch()
	await _tap(&"switch_weapon")
	assert_same(_almos.weapons.in_hand, load(TORCH_PATH), "the torch is in hand")


# Almos to the left of the thing, facing it, with its near edge inside the reach of the torch.
func _stand_to_swing_at(thing: Flammable) -> void:
	var reach := (load(TORCH_PATH) as WeaponData).reach
	_almos.global_position = thing.global_position + Vector2.LEFT * (HALF_WIDTH + reach / 2.0)
	_almos.facing = Vector2.RIGHT


func _on_fireball_thrown(_fireball: Fireball, _torch: Torch) -> void:
	_fireballs_thrown += 1


# --- driving ---


# Taps the Spell button and waits for the wind-up and the flight to end.
func _cast() -> void:
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	var flight := _frames(_spell.fireball_range / _spell.fireball_speed)
	await wait_physics_frames(_spell.wind_up_frames + flight + MARGIN_FRAMES)


# Taps Light attack and waits until the swing is over, recovery included.
func _swing_light() -> void:
	var weapon: WeaponData = _almos.weapons.in_hand
	var swing := weapon.light_attacks[0]
	_almos_input.press_action(&"attack_light")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	await wait_physics_frames(swing.total_frames() + MARGIN_FRAMES)


# Taps an action and lets the tap take effect.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(PRESS_FRAMES)


# How many physics frames last this long, at the 60 a second the suite runs at.
func _frames(seconds: float) -> int:
	return ceili(seconds * 60.0)
