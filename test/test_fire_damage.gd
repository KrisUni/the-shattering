extends GutTest
## Fire hurting, in the test room with the real Almos, the real enemies and the shipped numbers,
## driven through the Interact, Block and Roll actions: Almos standing in a burning curtain loses
## the tick damage each tick, and Block takes none of it off; a Roll through a fire line is
## untouchable for part of it and the ticks that land then do nothing; hidden in the barrel when it
## catches he is put out of it and hurt; and an enemy beside its own curtain takes the same damage
## as Almos and no Stagger. Distances and waits are worked from the data files, so nothing here
## pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FIRE_PATH := "res://data/fire.tres"
const TAP_FRAMES := 3
# In physics frames. Slack added to a computed wait; shorter than the shipped tick interval.
const MARGIN_FRAMES := 4
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 600
# In pixels. How wide the fire line of the Roll is, and how far left of its middle Almos starts.
const LINE_WIDTH := 600.0
const START_LEFT_OF_MIDDLE := 200.0
# In pixels. Where Almos stands when he is to be far from every fire and enemy.
const FAR_CORNER := Vector2(100.0, 100.0)

var _almos_input: AlmosInput
var _fire: FireTuning
var _player: PlayerTuning
var _room: Node
var _almos: Almos
var _ticks_while_untouchable := 0
var _health_when_last_untouchable_tick := -1.0


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_fire = load(FIRE_PATH) as FireTuning
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning
	_ticks_while_untouchable = 0
	_health_when_last_untouchable_tick = -1.0


func after_each() -> void:
	_almos_input.release_everything()


func test_almos_standing_in_a_burning_curtain_loses_the_tick_damage_each_tick() -> void:
	_set_up_room()
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	_almos.global_position = _room.get_node("Curtain").global_position
	await wait_physics_frames(MARGIN_FRAMES)

	curtain.ignite()
	await _wait_for_ticks(curtain, 1)
	assert_eq(_lost(), _fire.damage_per_tick, "one tick")
	await _wait_for_ticks(curtain, 2)

	assert_eq(_lost(), 2.0 * _fire.damage_per_tick, "two")


func test_almos_beside_a_burning_curtain_but_not_in_it_is_not_hurt() -> void:
	_set_up_room()
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	_almos.global_position = _room.get_node("Curtain").global_position + Vector2(0.0, 100.0)
	await wait_physics_frames(MARGIN_FRAMES)

	curtain.ignite()
	await _wait_for_ticks(curtain, 2)

	assert_eq(_lost(), 0.0)


func test_holding_block_takes_nothing_off_the_fire_damage() -> void:
	_set_up_room()
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	_almos.global_position = _room.get_node("Curtain").global_position + Vector2.LEFT * 8.0
	_almos.facing = Vector2.RIGHT
	_almos_input.press_action(&"block")
	await wait_physics_frames(MARGIN_FRAMES)
	assert_true(_almos.blocking, "control: he is blocking")

	curtain.ignite()
	await _wait_for_ticks(curtain, 1)

	assert_eq(_lost(), _fire.damage_per_tick)


func test_a_tick_that_lands_while_he_is_untouchable_in_a_roll_does_nothing() -> void:
	_set_up_room()
	var line := _room.get_node("Curtain/Flammable") as Flammable
	var shape := RectangleShape2D.new()
	shape.size = Vector2(LINE_WIDTH, 40.0)
	(line.get_node("CollisionShape2D") as CollisionShape2D).shape = shape
	var middle: Vector2 = _room.get_node("Curtain").global_position
	_almos.global_position = middle + Vector2.LEFT * START_LEFT_OF_MIDDLE
	_almos.facing = Vector2.RIGHT
	line.ticked.connect(_on_ticked)
	await wait_physics_frames(MARGIN_FRAMES)

	line.ignite()
	await _wait_for_ticks(line, 1)
	# The Roll begins when the tap ends; the tap is begun early enough that the next tick falls in
	# the middle of the untouchable stretch of the Roll.
	var lead := TAP_FRAMES / 60.0 + _player.roll_untouchable_start + _player.roll_untouchable_duration / 2.0
	await wait_physics_frames(ceili((_fire.tick_interval - lead) * 60.0))
	_almos_input.press_action(&"roll")
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _wait_for_ticks(line, 2)

	assert_eq(_ticks_while_untouchable, 1, "control: the second tick fell in the untouchable stretch")
	assert_eq(_health_when_last_untouchable_tick, _almos.health.maximum - _fire.damage_per_tick, "it took nothing")
	assert_eq(_lost(), _fire.damage_per_tick, "only the first tick hurt")


func test_hidden_in_the_barrel_when_it_catches_he_is_put_out_and_hurt() -> void:
	_set_up_room()
	var barrel := _room.get_node("Barrel/Flammable") as Flammable
	_almos.global_position = _room.get_node("Barrel").global_position
	await _tap(&"interact")
	assert_true(_almos.hiding, "control: he is in the barrel")

	barrel.ignite()
	assert_false(_almos.hiding, "he is out at once, as with a tap")
	assert_eq(_lost(), 0.0, "and not hurt before the first tick")
	await _wait_for_ticks(barrel, 1)

	assert_eq(_lost(), _fire.damage_per_tick, "then he takes Fire damage like anyone in it")
	assert_false(_almos.hiding)


func test_hidden_in_a_spot_that_does_not_burn_he_stays_hidden_while_another_burns() -> void:
	_set_up_room()
	var barrel := _room.get_node("Barrel/Flammable") as Flammable
	var bed := _room.get_node("Bed/Flammable") as Flammable
	_almos.global_position = _room.get_node("Barrel").global_position
	await _tap(&"interact")
	assert_true(_almos.hiding, "control: he is in the barrel")

	bed.ignite()
	await _wait_for_ticks(bed, 1)

	assert_true(_almos.hiding)
	assert_eq(_lost(), 0.0)
	assert_false(barrel.burning)


func test_a_burnt_out_spot_hurts_no_one() -> void:
	_set_up_room()
	var curtain := _room.get_node("Curtain/Flammable") as Flammable
	_almos.global_position = _room.get_node("Curtain").global_position
	await wait_physics_frames(MARGIN_FRAMES)
	curtain.ignite()
	await _until(func() -> bool: return curtain.burnt_out)
	var lost := _lost()
	assert_gt(lost, 0.0, "control: it hurt while it burned")

	await wait_physics_frames(ceili(3.0 * _fire.tick_interval * 60.0))

	assert_eq(_lost(), lost)


func test_the_training_enemy_beside_its_curtain_takes_what_almos_does_and_no_stagger() -> void:
	_set_up_room()
	var enemy = _room.get_node("TrainingEnemy")
	var curtain := _room.get_node("EnemyCurtain/Flammable") as Flammable
	_almos.global_position = FAR_CORNER
	await wait_physics_frames(MARGIN_FRAMES)

	curtain.ignite()
	await _wait_for_ticks(curtain, 1)

	assert_eq(enemy.health.maximum - enemy.health.current, _fire.damage_per_tick)
	assert_eq(enemy.stagger.current, 0.0, "Fire builds no Stagger")


func test_the_sound_hunter_beside_its_curtain_is_hurt_the_same() -> void:
	_set_up_room()
	var hunter = _room.get_node("SoundHunter")
	var curtain := _room.get_node("HunterCurtain/Flammable") as Flammable
	_almos.global_position = FAR_CORNER
	await wait_physics_frames(MARGIN_FRAMES)

	curtain.ignite()
	await _wait_for_ticks(curtain, 1)

	assert_eq(hunter.health.maximum - hunter.health.current, _fire.damage_per_tick)
	assert_eq(hunter.stagger.current, 0.0)


# --- set-up ---


# The test room as shipped, with the enemies kept away from Almos by his spot: the test moves him
# to the thing it uses. The test frees it all.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_almos.facing = Vector2.RIGHT
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null


func _lost() -> float:
	return _almos.health.maximum - _almos.health.current


func _on_ticked() -> void:
	if _almos.untouchable:
		_ticks_while_untouchable += 1
		_health_when_last_untouchable_tick = _almos.health.current


# Waits until this burning thing has ticked this many times in all since it caught.
func _wait_for_ticks(thing: Flammable, count: int) -> void:
	for i in FRAME_LIMIT:
		if thing.ticks >= count:
			return
		await get_tree().physics_frame


# Taps an action and lets the tap take effect.
func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)


func _until(condition: Callable) -> void:
	for i in FRAME_LIMIT:
		if condition.call():
			return
		await get_tree().physics_frame
