extends GutTest
## Torches and light in the test room with the real Almos, the real training enemy and the shipped
## numbers: drawing the stand torch in the DarkZone through the cast_spell action darkens its
## surroundings for the training enemy's Sight, and a rest at the Checkpoint or the return after a
## Death relights every torch drawn. Distances and waits are worked from the torch's data file,
## Flame draw's data file and the training enemy's tuning, so nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FLAME_DRAW_PATH := "res://data/flame_draw.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
# In physics frames. How long a button is held for a tap, and how long to let a press take effect.
const TAP_FRAMES := 2
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
var _enemy_tuning: EnemyTuning
var _room: Node
var _almos: Almos
var _stand_torch: Torch
var _wall_torch: Torch
var _enemy


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_spell = load(FLAME_DRAW_PATH) as SpellData
	_enemy_tuning = load(ENEMY_TUNING_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_the_stand_torch_is_lit_in_the_dark_zone_and_lights_the_zone_where_almos_stands() -> void:
	_set_up_room()
	var zone := _room.get_node("DarkZone") as LightZone

	assert_true(_stand_torch.lit, "lit at the start")
	assert_true(zone.covers(_stand_torch.global_position), "in the DarkZone")
	assert_almost_eq(_light_at_almos(), _stand_torch.light, 0.0001, "the light at Almos beside it")
	assert_false(_stand_torch.lights(zone.global_position), "the zone's centre is beyond its radius")


func test_drawing_the_stand_torch_drops_the_light_at_almos_to_the_zones_darkness() -> void:
	_set_up_room()
	var zone := _room.get_node("DarkZone") as LightZone

	await _cast()

	assert_false(_stand_torch.lit, "the torch is out")
	assert_almost_eq(_light_at_almos(), zone.light, 0.0001)


func test_with_the_stand_torch_lit_the_enemy_sees_almos_at_a_distance_it_cannot_in_the_dark() -> void:
	_set_up_room()
	var distance := _distance_between_the_two_lengths()

	_put_the_enemy_in_front_of_almos(distance)
	await wait_physics_frames(WATCH_FRAMES)

	assert_true(_enemy.in_pursuit)


func test_with_the_stand_torch_drawn_the_enemy_does_not_see_almos_at_that_distance() -> void:
	_set_up_room()
	var distance := _distance_between_the_two_lengths()
	# The enemy is held still while Almos casts, so that what it sees is judged after the torch is out.
	_enemy.process_mode = Node.PROCESS_MODE_DISABLED

	await _cast()
	_enemy.process_mode = Node.PROCESS_MODE_INHERIT
	_put_the_enemy_in_front_of_almos(distance)
	await wait_physics_frames(WATCH_FRAMES)

	assert_false(_stand_torch.lit, "the torch is out")
	assert_false(_enemy.in_pursuit)


func test_resting_at_the_checkpoint_relights_every_torch_that_was_drawn() -> void:
	_set_up_room()
	_stand_torch.draw()
	_wall_torch.draw()
	_stand_beside_the_checkpoint()

	await _press_interact()

	assert_true(_stand_torch.lit, "the stand torch")
	assert_true(_wall_torch.lit, "the wall torch")


func test_the_return_after_a_death_relights_every_torch_that_was_drawn() -> void:
	_set_up_room()
	_stand_torch.draw()
	_wall_torch.draw()
	var tuning := _almos.tuning

	_almos.health.take_damage(_almos.health.maximum)
	await wait_physics_frames(ceili(tuning.death_pause * Engine.physics_ticks_per_second) + PRESS_FRAMES)

	assert_true(_stand_torch.lit, "the stand torch")
	assert_true(_wall_torch.lit, "the wall torch")


func test_a_torch_still_burning_stays_lit_through_a_rest() -> void:
	_set_up_room()
	_stand_beside_the_checkpoint()

	await _press_interact()

	assert_true(_stand_torch.lit)
	assert_true(_wall_torch.lit)


# --- set-up ---


# The test room as shipped, without the Sound hunter, with Almos beside the stand torch, facing
# right, and the training enemy at its post. The test frees it.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_stand_torch = _room.get_node("StandTorch") as Torch
	_wall_torch = _room.get_node("WallTorch") as Torch
	_enemy = _room.get_node("TrainingEnemy")
	_almos.global_position = _stand_torch.global_position + Vector2(-_spell.draw_range * ALMOS_AT_DRAW_FRACTION, 0.0)
	_almos.facing = Vector2.RIGHT


# A distance halfway between how far the enemy sees in the dark and how far it sees in the light
# the lit stand torch gives.
func _distance_between_the_two_lengths() -> float:
	var dark := _enemy_tuning.sight_length_at(0.0)
	var lit := _enemy_tuning.sight_length_at(_stand_torch.light)
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


func _stand_beside_the_checkpoint() -> void:
	var checkpoint: Node2D = _room.get_node("Checkpoint")
	_almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT


# --- driving ---


# Taps the Spell button to draw the flame and waits for the wind-up, then taps it again to throw.
func _cast() -> void:
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	await wait_physics_frames(MARGIN_FRAMES)


# Taps Interact and lets the tap take effect.
func _press_interact() -> void:
	_almos_input.press_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
	_almos_input.release_action(&"interact")
	await wait_physics_frames(PRESS_FRAMES)
