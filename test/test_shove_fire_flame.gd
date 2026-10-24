extends GutTest
## A flame Pulled off the burning Curtain and Shoved, in the test room with the real Almos, the real
## training enemy and the shipped numbers, driven through the switch_spell and cast_spell actions.
## It flies along his aim, damages the first enemy it hits (full damage, damage only), lights a
## flammable thing it meets, splashes the other enemies and flammable things near the impact and
## is stopped by a wall, and never hurts Almos. Distances and damage are worked from the data files.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FIREBALL_PATH := "res://data/fireball.tres"
const PULL_PATH := "res://data/pull.tres"
const SHOVE_PATH := "res://data/shove.tres"
const TOLERANCE := 0.0001
const TAP_FRAMES := 2
const MARGIN_FRAMES := 8
# In pixels.
const EDGE_MARGIN := 1.0
const BESIDE_THE_STAND_TORCH := 20.0
const WALL_THICKNESS := 16.0

var _almos_input: AlmosInput
var _spell: SpellData
var _pull: SpellCost
var _shove: SpellCost
var _room: Node
var _almos: Almos
var _enemy
var _curtain: Flammable
var _rig: EnemyRig
var _damage := 0.0


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_spell = load(FIREBALL_PATH) as SpellData
	_pull = load(PULL_PATH) as SpellCost
	_shove = load(SHOVE_PATH) as SpellCost


func after_each() -> void:
	_almos_input.release_everything()
	if _rig != null:
		_rig.stop_sampling()


func test_a_shoved_fire_flame_damages_the_first_enemy_it_hits_for_the_full_damage_and_no_stagger() -> void:
	_set_up_room()
	await _pull_the_curtains_flame()
	_take_the_line_of_fire()
	var before: float = _enemy.health.current

	await _shove_the_flame()

	assert_almost_eq(before - _enemy.health.current, _damage, TOLERANCE, "full damage once")
	assert_almost_eq(_enemy.stagger.current, 0.0, TOLERANCE, "no Stagger")


func test_a_shoved_fire_flame_hits_the_first_enemy_and_not_the_one_behind_it() -> void:
	_set_up_room()
	await _pull_the_curtains_flame()
	_take_the_line_of_fire()
	var behind = _spawn_second_enemy(Vector2.UP * (_spell.splash_radius + 40.0))
	var behind_before: float = behind.health.current

	await _shove_the_flame()

	assert_eq(behind.health.current, behind_before)


func test_a_shoved_fire_flame_lights_a_flammable_thing_it_meets() -> void:
	_set_up_room()
	await _pull_the_curtains_flame()
	_take_the_line_of_fire()
	_enemy.global_position = Vector2(100.0, 100.0)
	_curtain.global_position = _almos.global_position + Vector2.UP * (_spell.fireball_range / 2.0)
	assert_false(_curtain.burning, "unburnt before")

	await _shove_the_flame()

	assert_true(_curtain.burning)


func test_a_shoved_fire_flame_splashes_a_near_enemy_and_a_near_flammable_thing_but_not_a_far_one() -> void:
	_set_up_room()
	await _pull_the_curtains_flame()
	_take_the_line_of_fire()
	var near = _spawn_second_enemy(Vector2.RIGHT * _spell.splash_radius / 2.0)
	var far = _spawn_second_enemy(Vector2.RIGHT * (_spell.splash_radius + 60.0))
	_curtain.global_position = _enemy.global_position + Vector2.LEFT * _spell.splash_radius / 2.0
	var near_before: float = near.health.current
	var far_before: float = far.health.current

	await _shove_the_flame()

	assert_almost_eq(near_before - near.health.current, _damage * _spell.splash_fraction, TOLERANCE, "the splashed enemy")
	assert_eq(far.health.current, far_before, "the far enemy")
	assert_true(_curtain.burning, "the flammable thing within the radius")


func test_a_wall_stops_the_splash_of_a_shoved_fire_flame() -> void:
	_set_up_room()
	await _pull_the_curtains_flame()
	_take_the_line_of_fire()
	var behind = _spawn_second_enemy(Vector2.RIGHT * _spell.splash_radius / 2.0)
	_add_screen(_spell.splash_radius / 4.0)
	var before: float = behind.health.current

	await _shove_the_flame()

	assert_eq(behind.health.current, before)


func test_a_shoved_fire_flame_does_not_hurt_almos_beyond_the_costs() -> void:
	_set_up_room()
	await _pull_the_curtains_flame()
	_take_the_line_of_fire()
	# So near that the splash reaches him.
	_enemy.global_position = _almos.global_position + Vector2.UP * _spell.splash_radius / 2.0
	var health := _almos.health.current

	await _shove_the_flame()

	assert_almost_eq(_almos.health.current, health - _shove.health_cost, TOLERANCE)


# --- setting up ---


# The test room as shipped, without the Sound hunter, the training enemy given no target, and the
# Curtain alight.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	_room = scene.instantiate()
	var hunter := _room.get_node("SoundHunter")
	_room.remove_child(hunter)
	hunter.free()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_curtain = _room.get_node("Curtain/Flammable") as Flammable
	_enemy = _room.get_node("TrainingEnemy")
	_enemy.target = null
	_enemy.global_position = Vector2(300.0, 560.0)
	_curtain.ignite()
	_damage = _spell.damage_for(_almos.tuning.channelling)


# Almos below the Curtain, facing it, within Pull's flame range of its lower edge, taps Pull and waits
# the wind-up out. He then holds the flame. The Stand torch is put out first: from there it is in
# Pull's torch range, and a torch's flame is taken before a Fire's.
func _pull_the_curtains_flame() -> void:
	(_room.get_node("StandTorch") as Torch).extinguish()
	var bottom := _curtain.global_position.y + (((_curtain.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.y / 2.0)
	_almos.global_position = Vector2(_curtain.global_position.x, bottom + _pull.flame_range - EDGE_MARGIN)
	_almos.facing = Vector2.UP
	await _tap(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)
	assert_true(_almos.spell.holding, "holding the Curtain's flame")
	assert_false(_curtain.burning, "the Curtain's flame was taken")


# Almos by the stand torch facing up, the training enemy up the line of fire inside its range. The
# Curtain, no longer burning, is put out of the way.
func _take_the_line_of_fire() -> void:
	var stand_torch := _room.get_node("StandTorch") as Torch
	_almos.global_position = stand_torch.global_position + Vector2.LEFT * BESIDE_THE_STAND_TORCH
	_almos.facing = Vector2.UP
	_enemy.global_position = _almos.global_position + Vector2.UP * (_spell.fireball_range / 2.0)
	_curtain.global_position = Vector2(100.0, 100.0)


func _spawn_second_enemy(offset: Vector2):
	_rig = EnemyRig.new(self)
	return _rig.spawn_enemy(null, _enemy.global_position + offset)


# A tall thin wall beside the line of fire, this far to the right of the training enemy.
func _add_screen(x_from_enemy: float) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4.0, 200.0)
	shape.shape = rectangle
	wall.add_child(shape)
	_room.add_child(wall)
	wall.global_position = _enemy.global_position + Vector2(x_from_enemy, 0.0)


# --- driving ---


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Taps the Spell button to throw the held flame and waits for the flight to end.
func _shove_the_flame() -> void:
	await _tap(&"cast_spell")
	var flight := ceili(_spell.fireball_range / _spell.fireball_speed * Engine.physics_ticks_per_second)
	await wait_physics_frames(flight + MARGIN_FRAMES)
