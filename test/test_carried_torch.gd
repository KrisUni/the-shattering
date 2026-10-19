extends GutTest
## The torch Almos carries, in the test room with the real Almos, the real training enemy and the
## shipped numbers, driven through the Interact, Switch and cast_spell actions: while it is in his
## hand it lights the way (the light at him, and how far the enemy sees him in the DarkZone); a
## torch carried but not in hand gives no light and cannot be drawn; drawn, it becomes the unlit
## club in the same place in his list, with no light, and a rest does not relight it. Distances
## and waits are worked from the data files, so nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const TORCH_LIGHT_PATH := "res://data/torch_light.tres"
const TORCH_PATH := "res://data/torch.tres"
const UNLIT_TORCH_PATH := "res://data/torch_unlit.tres"
const SWORD_PATH := "res://data/sword.tres"
# In physics frames. How long a button is held for a tap, and how long to let a press take effect.
const TAP_FRAMES := 3
const PRESS_FRAMES := 3
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 6
# In physics frames. How long an enemy is watched to see whether it notices Almos.
const WATCH_FRAMES := 30
# In pixels. How far from the Checkpoint's centre Almos is put when he is to rest.
const BESIDE_THE_CHECKPOINT := 10.0
# As a fraction of Flame draw's range: how far from the stand torch Almos stands, within reach.
const ALMOS_AT_DRAW_FRACTION := 0.5

var _almos_input: AlmosInput
var _spell: SpellData
var _torch_light: TorchTuning
var _enemy_tuning: EnemyTuning
var _room: Node
var _almos: Almos
var _zone: LightZone
var _stand_torch: Torch
var _enemy
var _fireballs_thrown := 0
# Where the torch lies on the floor of the room: clear of every torch on a wall or a stand.
var _floor_spot: Vector2


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_spell = load(FLAME_DRAW_PATH) as SpellData
	_torch_light = load(TORCH_LIGHT_PATH) as TorchTuning
	_enemy_tuning = load(ENEMY_TUNING_PATH) as EnemyTuning
	_fireballs_thrown = 0


func after_each() -> void:
	_almos_input.release_everything()


func test_a_torch_in_hand_lights_the_way_in_the_dark_zone() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_in_the_dark_zone()

	assert_gt(_torch_light.light, _zone.light, "the torch must lift the dark")
	assert_almost_eq(_light_at_almos(), _torch_light.light, 0.0001)


func test_with_the_torch_in_hand_the_enemy_sees_almos_further_in_the_dark_zone() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_in_the_dark_zone()
	_put_the_enemy_in_front_of_almos(_distance_between_the_two_lengths())

	await wait_physics_frames(WATCH_FRAMES)

	assert_true(_enemy.in_pursuit)


func test_with_the_torch_not_in_hand_the_enemy_does_not_see_almos_at_that_distance() -> void:
	_set_up_room()
	await _carry_the_torch()
	_stand_in_the_dark_zone()
	_put_the_enemy_in_front_of_almos(_distance_between_the_two_lengths())

	await wait_physics_frames(WATCH_FRAMES)

	assert_false(_enemy.in_pursuit)


func test_a_torch_carried_but_not_in_hand_gives_no_light() -> void:
	_set_up_room()
	await _carry_the_torch()
	_stand_in_the_dark_zone()

	assert_true(_almos.weapons.carried.has(load(TORCH_PATH)), "the torch is carried")
	assert_ne(_almos.weapons.in_hand, load(TORCH_PATH), "and not in hand")
	assert_almost_eq(_light_at_almos(), _zone.light, 0.0001)


func test_a_torch_carried_but_not_in_hand_cannot_be_drawn() -> void:
	_set_up_room()
	await _carry_the_torch()
	_stand_far_from_every_torch()
	var health_before := _almos.health.current

	await _cast()

	assert_eq(_fireballs_thrown, 0, "no fireball")
	assert_eq(_almos.health.current, health_before, "nothing spent")
	assert_eq(_almos.weapons.carried, [load(SWORD_PATH), load(TORCH_PATH)], "the torch is as it was")


func test_drawing_the_torch_in_hand_throws_a_fireball_and_leaves_the_unlit_club_in_hand() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_far_from_every_torch()

	await _cast()

	assert_eq(_fireballs_thrown, 1, "a fireball is thrown")
	assert_same(_almos.weapons.in_hand, load(UNLIT_TORCH_PATH), "the unlit club is in hand")
	assert_eq(_almos.weapons.carried, [load(SWORD_PATH), load(UNLIT_TORCH_PATH)], "in the torch's place")


func test_the_unlit_club_gives_no_light_and_its_attacks_are_its_own() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_far_from_every_torch()

	await _cast()
	_stand_in_the_dark_zone()

	assert_almost_eq(_light_at_almos(), _zone.light, 0.0001, "no light")
	var attacks := _almos.get_node("Attacks") as AlmosAttacks
	assert_same(attacks.weapon, load(UNLIT_TORCH_PATH), "his attacks are the unlit club's")
	assert_ne(attacks.weapon.light_attacks[0].damage, (load(TORCH_PATH) as WeaponData).light_attacks[0].damage)


func test_the_unlit_club_cannot_be_drawn_again() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_far_from_every_torch()
	await _cast()
	var health_before := _almos.health.current

	await _cast()

	assert_eq(_fireballs_thrown, 1, "still the one fireball")
	assert_eq(_almos.health.current, health_before, "nothing spent")


func test_a_rest_leaves_the_club_unlit_and_the_dark_zone_dark() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_far_from_every_torch()
	await _cast()
	_stand_beside_the_checkpoint()

	await _press_interact()
	_stand_in_the_dark_zone()

	assert_same(_almos.weapons.in_hand, load(UNLIT_TORCH_PATH))
	assert_almost_eq(_light_at_almos(), _zone.light, 0.0001)


func test_a_rest_does_not_put_out_the_torch_in_hand() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_stand_beside_the_checkpoint()

	await _press_interact()
	_stand_in_the_dark_zone()

	assert_same(_almos.weapons.in_hand, load(TORCH_PATH))
	assert_almost_eq(_light_at_almos(), _torch_light.light, 0.0001)


func test_with_a_lit_torch_in_hand_beside_the_stand_torch_the_one_in_hand_is_drawn_first() -> void:
	_set_up_room()
	await _carry_the_torch_in_hand()
	_almos.global_position = _stand_torch.global_position + Vector2(-_spell.draw_range * ALMOS_AT_DRAW_FRACTION, 0.0)

	await _cast()

	assert_same(_almos.weapons.in_hand, load(UNLIT_TORCH_PATH), "the one in hand went out")
	assert_true(_stand_torch.lit, "the stand torch still burns")


# --- set-up ---


# The test room as shipped, without the Sound hunter, and Almos with his sword in hand at the
# torch lying on the floor. The test frees it.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_zone = _room.get_node("DarkZone") as LightZone
	_stand_torch = _room.get_node("StandTorch") as Torch
	_enemy = _room.get_node("TrainingEnemy")
	_floor_spot = _room.get_node("TorchPickup").global_position
	_almos.facing = Vector2.RIGHT
	_almos.spell.fireball_thrown.connect(_on_fireball_thrown)


# Almos picks the torch up from the floor of the room with a tap of Interact. It is behind the
# sword in his list, so the sword stays in hand.
func _carry_the_torch() -> void:
	_almos.global_position = _floor_spot
	await _press_interact()


# As _carry_the_torch, then a tap of Switch puts the torch in hand.
func _carry_the_torch_in_hand() -> void:
	await _carry_the_torch()
	_almos_input.press_action(&"switch_weapon")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"switch_weapon")
	await wait_physics_frames(PRESS_FRAMES)
	assert_same(_almos.weapons.in_hand, load(TORCH_PATH), "the torch is in hand")


func _stand_in_the_dark_zone() -> void:
	_almos.global_position = _zone.global_position


# Beyond Flame draw's range of every torch on a wall or a stand.
func _stand_far_from_every_torch() -> void:
	_almos.global_position = _floor_spot
	for node in get_tree().get_nodes_in_group("torches"):
		if node != _almos.carried_torch:
			assert_gt(node.global_position.distance_to(_floor_spot), _spell.draw_range, "clear of the torch")


func _stand_beside_the_checkpoint() -> void:
	var checkpoint: Node2D = _room.get_node("Checkpoint")
	_almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT


# A distance halfway between how far the enemy sees in the dark and how far it sees in the light
# the torch gives.
func _distance_between_the_two_lengths() -> float:
	var dark := _enemy_tuning.sight_length_at(_zone.light)
	var lit := _enemy_tuning.sight_length_at(_torch_light.light)
	assert_gt(lit, dark, "the torch must lengthen the Sight")
	return (dark + lit) / 2.0


# The enemy this far to Almos's left, facing him.
func _put_the_enemy_in_front_of_almos(distance: float) -> void:
	_enemy.global_position = _almos.global_position + Vector2.LEFT * distance
	_enemy.post_facing = Vector2.RIGHT


func _light_at_almos() -> float:
	return LightZone.light_at(
		get_tree().get_nodes_in_group("light_zones"), _almos.global_position,
		get_tree().get_nodes_in_group("torches"),
	)


func _on_fireball_thrown(_fireball: Fireball, _torch: Torch) -> void:
	_fireballs_thrown += 1


# --- driving ---


# Taps the Spell button and waits for the wind-up to end.
func _cast() -> void:
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)


# Taps Interact and lets the tap take effect.
func _press_interact() -> void:
	_almos_input.press_action(&"interact")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
