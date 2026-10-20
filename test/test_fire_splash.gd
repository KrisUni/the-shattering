extends GutTest
## A fireball's splash, in the test room with the real Almos, the real training enemy and the
## shipped numbers, driven through the cast_spell action: where it stops on an enemy, a flammable
## thing or a wall, every other enemy within the splash radius takes the splash fraction of its
## damage, damage only, and every flammable thing within it catches. The enemy it hit takes its full
## damage once. Distances and damage are worked from the data file, so nothing here pins a number
## in it.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const EnemyRig := preload("res://test/helpers/enemy_rig.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const PATH_BLOCKER_PATH := "res://scenes/world/path_blocker.tscn"
const FIREBALL_PATH := "res://data/fireball.tres"
const TOLERANCE := 0.0001
# In physics frames.
const TAP_FRAMES := 2
const MARGIN_FRAMES := 6
# In pixels. The radius of an enemy's Hurtbox, which a splash reaches when it touches it.
const HURTBOX_RADIUS := 12.0
# In pixels. Slack put between a thing and the edge of the splash when it is to stand clear.
const CLEAR_OF_THE_SPLASH := 20.0
# In pixels. The thickness of the walls the tests build.
const WALL_THICKNESS := 16.0
# In pixels. How far from the stand torch Almos stands to cast, within the Pull's draw range.
const BESIDE_THE_STAND_TORCH := 20.0

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
	_pull = load("res://data/pull.tres") as SpellCost
	_shove = load("res://data/shove.tres") as SpellCost


func after_each() -> void:
	_almos_input.release_everything()
	if _rig != null:
		_rig.stop_sampling()


func test_an_enemy_within_the_splash_radius_takes_the_splash_fraction_of_the_damage() -> void:
	_set_up_room()
	var near = _spawn_second_enemy(Vector2.RIGHT * _spell.splash_radius / 2.0)
	var near_before: float = near.health.current
	var hit_before: float = _enemy.health.current

	await _cast()

	assert_almost_eq(near_before - near.health.current, _damage * _spell.splash_fraction, TOLERANCE, "the splashed enemy")
	assert_almost_eq(hit_before - _enemy.health.current, _damage, TOLERANCE, "the enemy hit takes its full damage once")


func test_an_enemy_beyond_the_splash_radius_takes_none() -> void:
	_set_up_room()
	var far = _spawn_second_enemy(Vector2.RIGHT * (_spell.splash_radius + 2.0 * HURTBOX_RADIUS + CLEAR_OF_THE_SPLASH))
	var far_before: float = far.health.current

	await _cast()

	assert_eq(far.health.current, far_before)


func test_a_splash_builds_no_stagger_on_either_enemy() -> void:
	_set_up_room()
	var near = _spawn_second_enemy(Vector2.RIGHT * _spell.splash_radius / 2.0)

	await _cast()

	assert_almost_eq(near.stagger.current, 0.0, TOLERANCE, "the splashed enemy")
	assert_almost_eq(_enemy.stagger.current, 0.0, TOLERANCE, "the enemy hit")


func test_almos_within_the_splash_radius_is_not_hurt_by_it() -> void:
	_set_up_room()
	# A wall closer to Almos than the splash radius reaches.
	_add_wall(-_spell.splash_radius / 2.0)
	var health_before: float = _almos.health.current

	await _cast()

	assert_almost_eq(_almos.health.current, health_before - _pull.health_cost - _shove.health_cost, TOLERANCE, "he lost only the cost of the cast")


func test_a_fireball_hitting_a_wall_lights_a_flammable_thing_within_the_radius() -> void:
	_set_up_room()
	_enemy.global_position = Vector2(100.0, 100.0)
	var wall_y := -_spell.fireball_range / 2.0
	_add_wall(wall_y)
	# On the fireball's side of the wall, not inside it.
	_curtain.global_position = _almos.global_position + Vector2(_spell.splash_radius / 2.0, wall_y + WALL_THICKNESS)

	await _cast()

	assert_true(_curtain.burning)


func test_an_enemy_within_the_radius_behind_a_wall_from_the_impact_takes_no_splash() -> void:
	_set_up_room()
	var behind = _spawn_second_enemy(Vector2.RIGHT * _spell.splash_radius / 2.0)
	_add_screen(_spell.splash_radius / 4.0)
	var before: float = behind.health.current

	await _cast()

	assert_eq(behind.health.current, before)


func test_a_flammable_thing_within_the_radius_behind_a_wall_is_not_lit() -> void:
	_set_up_room()
	_curtain.global_position = _enemy.global_position + Vector2.RIGHT * _spell.splash_radius / 2.0
	_add_screen(_spell.splash_radius / 4.0)

	await _cast()

	assert_false(_curtain.burning)


func test_a_wall_hit_lights_a_whole_path_blocker_within_the_radius_whose_own_body_is_in_the_line() -> void:
	WorldState.reset()
	_set_up_room()
	var wall_y := -_spell.fireball_range / 2.0
	_add_wall(wall_y)
	var blocker := (load(PATH_BLOCKER_PATH) as PackedScene).instantiate() as PathBlocker
	blocker.id = &"test_splash_blocker"
	_room.add_child(blocker)
	# On the fireball's side of the wall, its body between the impact and its middle.
	blocker.global_position = _almos.global_position + Vector2(_spell.splash_radius / 2.0, wall_y + blocker.size.y / 2.0)

	await _cast()

	assert_true(blocker.flammable.burning)
	WorldState.reset()


func test_a_flammable_thing_beyond_the_splash_radius_is_not_lit() -> void:
	_set_up_room()
	_enemy.global_position = Vector2(100.0, 100.0)
	var wall_y := -_spell.fireball_range / 2.0
	_add_wall(wall_y)
	_curtain.global_position = _almos.global_position + Vector2(_spell.splash_radius + 2.0 * 16.0 + CLEAR_OF_THE_SPLASH, wall_y)

	await _cast()

	assert_false(_curtain.burning)


func test_a_fireball_that_runs_out_of_range_in_open_air_splashes_nothing() -> void:
	_set_up_room()
	_enemy.global_position = Vector2(100.0, 100.0)
	# Beside where the fireball dies out, within the radius of it.
	var dies_at := _almos.global_position + Vector2.UP * _spell.fireball_range
	_curtain.global_position = dies_at + Vector2(_spell.splash_radius / 2.0, 0.0)
	var near = _spawn_second_enemy(Vector2.ZERO)
	near.global_position = dies_at + Vector2(-_spell.splash_radius / 2.0, 0.0)
	var before: float = near.health.current

	await _cast()

	assert_false(_curtain.burning, "the flammable thing")
	assert_eq(near.health.current, before, "the enemy")


# --- setting up ---


# The room with Almos by the stand torch facing up, and the training enemy up the line of fire,
# well inside the fireball's range. No sound hunter, and the enemy has no target, so neither goes
# after him.
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
	_curtain = _room.get_node("Curtain/Flammable") as Flammable
	var stand_torch := _room.get_node("StandTorch") as Torch
	_almos.global_position = stand_torch.global_position + Vector2.LEFT * BESIDE_THE_STAND_TORCH
	_almos.facing = Vector2.UP
	_enemy.target = null
	_enemy.global_position = _almos.global_position + Vector2.UP * (_spell.fireball_range / 2.0)
	_damage = _spell.damage_for(_almos.tuning.channelling)


# A second training enemy, no target, this far from the first.
func _spawn_second_enemy(offset: Vector2):
	_rig = EnemyRig.new(self)
	return _rig.spawn_enemy(null, _enemy.global_position + offset)


# A wall across the line of fire, this far above Almos (negative is up), wide enough to catch
# the fireball and the things beside it.
func _add_wall(y_from_almos: float) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(400.0, WALL_THICKNESS)
	shape.shape = rectangle
	wall.add_child(shape)
	_room.add_child(wall)
	wall.global_position = _almos.global_position + Vector2(0.0, y_from_almos - WALL_THICKNESS / 2.0)
	# The wall is the fireball's way; the training enemy is out of it.
	_enemy.global_position = Vector2(100.0, 100.0)


# A tall thin wall beside the line of fire, this far to the right of the training enemy, between
# the fireball's impact on it and things further right.
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


# Taps the Spell button to draw the flame, waits for the wind-up, taps again to throw it, and waits for the flight to end.
func _cast() -> void:
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	await wait_physics_frames(_spell.wind_up_frames + MARGIN_FRAMES)
	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"cast_spell")
	var flight := ceili(_spell.fireball_range / _spell.fireball_speed * 60.0)
	await wait_physics_frames(flight + MARGIN_FRAMES)
