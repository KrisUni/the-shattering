extends GutTest
## What comes back after Fire, in the test room with the real Almos, the real enemies and the shipped
## numbers, driven through the Interact and move actions: at a rest, a burnt barrel and a burnt
## patch of fungus are whole again and the barrel can be hidden in; a burnt door or burnt roots stay
## open and can be walked through; when the return is a Death, a barrel or fungus is whole again and
## a door or roots burnt since the last rest are closed again, while those burnt before a rest stay
## open; a door or an enemy's curtain still burning at the rest is dealt with at once, the door open,
## the curtain out and whole.
## Distances and waits are worked from the data files, so nothing here pins a number in them. Each
## test resets WorldState first and last.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const FIRE_PATH := "res://data/fire.tres"
const TAP_FRAMES := 3
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 4
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 900
# In pixels. How far from the Checkpoint's centre Almos is put to rest: within reach.
const BESIDE_THE_CHECKPOINT := 10.0
# In pixels. How far left of a path blocker Almos starts a walk through it, and how far past the
# far side his centre must get to have passed: little, for the Gap lies close behind the Roots.
const WALK_START_GAP := 50.0
const PAST_GAP := 4.0
# In pixels. Where Almos is put when he is to be well away from every Fire.
const FAR_CORNER := Vector2(576.0, 474.0)

var _almos_input: AlmosInput
var _fire: FireTuning
var _player: PlayerTuning
var _room: Node
var _almos: Almos

# The path blockers of the room, by name.
var blocker_params := ["Door", "Roots"]


func before_each() -> void:
	await get_tree().process_frame
	WorldState.reset()
	_almos_input = AlmosInput.new(self)
	_fire = load(FIRE_PATH) as FireTuning
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func test_a_burnt_barrel_is_drawn_again_after_a_rest() -> void:
	_set_up_room()
	var barrel := _flammable("Barrel")
	await _burn_out(barrel)
	assert_false((_room.get_node("Barrel/Look") as CanvasItem).visible, "control: gone while burnt")

	await _rest()

	assert_true((_room.get_node("Barrel/Look") as CanvasItem).visible)


func test_a_burnt_barrel_can_be_hidden_in_after_a_rest() -> void:
	_set_up_room()
	await _burn_out(_flammable("Barrel"))
	await _rest()

	_almos.global_position = _room.get_node("Barrel").global_position
	await _tap(&"interact")

	assert_true(_almos.hiding)


func test_a_burnt_barrel_cannot_be_hidden_in_before_a_rest() -> void:
	_set_up_room()
	await _burn_out(_flammable("Barrel"))

	_almos.global_position = _room.get_node("Barrel").global_position
	await _tap(&"interact")

	assert_false(_almos.hiding)


func test_a_barrel_burnt_and_brought_back_burns_again() -> void:
	_set_up_room()
	var barrel := _flammable("Barrel")
	await _burn_out(barrel)
	await _rest()

	assert_true(barrel.ignite())


func test_burnt_fungus_is_whole_after_a_rest() -> void:
	_set_up_room()
	var fungus := _flammable("Fungus")
	await _burn_out(fungus)

	await _rest()

	assert_false(fungus.burnt_out, "not burnt out")
	assert_true((_room.get_node("Fungus/Look") as CanvasItem).visible, "drawn again")


func test_fungus_brought_back_burns_again() -> void:
	_set_up_room()
	var fungus := _flammable("Fungus")
	await _burn_out(fungus)
	await _rest()

	assert_true(fungus.ignite())


func test_fungus_still_burning_at_a_rest_is_out_and_whole() -> void:
	_set_up_room()
	var fungus := _flammable("Fungus")
	fungus.ignite()
	await wait_physics_frames(MARGIN_FRAMES)
	assert_true(fungus.burning, "control: it burns at the rest")

	await _rest()

	assert_false(fungus.burning, "out")
	assert_false(fungus.burnt_out, "and whole")
	assert_false(fungus.is_in_group(&"fires"), "no longer a fire")


func test_an_enemys_curtain_burning_at_a_rest_goes_out_and_is_whole() -> void:
	_set_up_room()
	var curtain := _flammable("EnemyCurtain")
	curtain.ignite()
	await wait_physics_frames(MARGIN_FRAMES)
	assert_true(curtain.burning, "control: it burns at the rest")

	await _rest()

	assert_false(curtain.burning, "out")
	assert_false(curtain.burnt_out, "and whole")
	assert_true((_room.get_node("EnemyCurtain/Look") as CanvasItem).visible, "drawn")
	assert_true(_room.get_node("EnemyCurtain").is_in_group(&"hiding_spots"), "a Hiding spot")


func test_an_enemys_curtain_put_out_by_a_rest_hurts_no_one_afterwards() -> void:
	_set_up_room()
	var curtain := _flammable("EnemyCurtain")
	curtain.ignite()
	await wait_physics_frames(MARGIN_FRAMES)
	await _rest()
	var ticks_at_the_rest := curtain.ticks

	await wait_physics_frames(ceili(3.0 * _fire.tick_interval * 60.0))

	assert_eq(curtain.ticks, ticks_at_the_rest)


func test_a_burnt_barrel_is_whole_after_a_death_and_return() -> void:
	_set_up_room()
	var barrel := _flammable("Barrel")
	await _burn_out(barrel)

	await _die_and_return()

	assert_false(barrel.burnt_out)
	assert_true(_room.get_node("Barrel").is_in_group(&"hiding_spots"), "a Hiding spot again")


func test_burnt_fungus_is_whole_after_a_death_and_return() -> void:
	_set_up_room()
	var fungus := _flammable("Fungus")
	await _burn_out(fungus)

	await _die_and_return()

	assert_false(fungus.burnt_out)


func test_a_whole_path_blocker_blocks_almos(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()

	var passed := await _walk_through(blocker)

	assert_false(passed)


func test_a_burnt_path_blocker_lets_almos_through(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	await _burn_out(_flammable(blocker))

	var passed := await _walk_through(blocker)

	assert_true(passed)


func test_a_burnt_path_blocker_stays_open_after_a_rest(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	await _burn_out(_flammable(blocker))

	await _rest()

	assert_true((_room.get_node(blocker) as PathBlocker).open, "open")
	var passed := await _walk_through(blocker)
	assert_true(passed, "and passable")


func test_a_burnt_path_blocker_is_closed_again_after_a_death_and_return_with_no_rest_between(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	await _burn_out(_flammable(blocker))

	await _die_and_return()

	assert_false((_room.get_node(blocker) as PathBlocker).open, "closed")
	var passed := await _walk_through(blocker)
	assert_false(passed, "and blocks")


func test_a_burnt_path_blocker_closed_again_by_a_death_can_burn_again(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	await _burn_out(_flammable(blocker))
	await _die_and_return()

	await _burn_out(_flammable(blocker))

	assert_true((_room.get_node(blocker) as PathBlocker).open, "open")
	assert_true(WorldState.is_burnt((_room.get_node(blocker) as PathBlocker).id), "and noted")


func test_a_burnt_path_blocker_stays_open_after_a_rest_and_then_a_death(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	await _burn_out(_flammable(blocker))
	await _rest()

	await _die_and_return()

	assert_true((_room.get_node(blocker) as PathBlocker).open, "open")
	var passed := await _walk_through(blocker)
	assert_true(passed, "and passable")


func test_only_the_path_blocker_burnt_since_the_last_rest_is_closed_by_a_death() -> void:
	_set_up_room()
	await _burn_out(_flammable("Door"))
	await _rest()
	await _burn_out(_flammable("Roots"))

	await _die_and_return()

	assert_true((_room.get_node("Door") as PathBlocker).open, "the Door, burnt before the rest, is open")
	assert_false((_room.get_node("Roots") as PathBlocker).open, "the Roots, burnt after it, are closed")


func test_a_path_blocker_still_burning_at_a_death_is_closed_and_whole_after_the_return(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	var flammable := _flammable(blocker)
	flammable.ignite()
	await wait_physics_frames(MARGIN_FRAMES)
	assert_true(flammable.burning, "control: it burns at the Death")

	await _die_and_return()

	assert_false(flammable.burning, "out")
	assert_false((_room.get_node(blocker) as PathBlocker).open, "closed")
	var passed := await _walk_through(blocker)
	assert_false(passed, "and blocks")


func test_a_path_blocker_still_burning_at_a_rest_is_open_after_it(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	var flammable := _flammable(blocker)
	flammable.ignite()
	await wait_physics_frames(MARGIN_FRAMES)
	assert_true(flammable.burning, "control: it burns at the rest")

	await _rest()

	assert_false(flammable.burning, "out")
	assert_true((_room.get_node(blocker) as PathBlocker).open, "open")
	var passed := await _walk_through(blocker)
	assert_true(passed, "and passable")


func test_a_path_blocker_that_never_caught_is_still_closed_after_a_rest(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()

	await _rest()

	var passed := await _walk_through(blocker)
	assert_false(passed)


func test_a_path_blocker_burnt_open_is_open_in_a_room_built_again(blocker = use_parameters(blocker_params)) -> void:
	_set_up_room()
	await _burn_out(_flammable(blocker))
	_room.free()

	_set_up_room()

	assert_true((_room.get_node(blocker) as PathBlocker).open)


# --- set-up ---


# The test room as shipped, with the enemies given no target, so they leave Almos alone. The test
# frees it all.
func _set_up_room() -> void:
	var scene := load(TEST_ROOM_PATH) as PackedScene
	assert_not_null(scene, "the test room scene should load")
	_room = scene.instantiate()
	add_child_autofree(_room)
	_almos = _room.get_node("Almos") as Almos
	_almos.facing = Vector2.RIGHT
	_room.get_node("TrainingEnemy").target = null
	_room.get_node("SoundHunter").target = null


func _flammable(room_node: String) -> Flammable:
	return _room.get_node(room_node + "/Flammable") as Flammable


# Sets it alight and waits until it has burnt out.
func _burn_out(thing: Flammable) -> void:
	thing.ignite()
	for i in ceili(_fire.burn_time * 60.0) + FRAME_LIMIT:
		if thing.burnt_out:
			return
		await wait_physics_frames(1)
	fail_test("it did not burn out")


# Almos rests at the Checkpoint, by a tap of Interact beside it.
func _rest() -> void:
	var checkpoint: Node2D = _room.get_node("Checkpoint")
	_almos.global_position = checkpoint.global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT
	await wait_physics_frames(MARGIN_FRAMES)
	watch_signals(_almos)
	await _tap(&"interact")
	assert_signal_emitted(_almos, "rested", "control: he rested")


# Almos dies away from every Fire and is returned by the room.
func _die_and_return() -> void:
	_almos.global_position = FAR_CORNER
	await wait_physics_frames(MARGIN_FRAMES)
	watch_signals(_almos)
	_almos.health.take_damage(_almos.health.maximum)
	await wait_physics_frames(ceili(_player.death_pause * 60.0) + MARGIN_FRAMES)
	assert_signal_emitted(_almos, "returned", "control: he was returned")


# Almos walks at the path blocker from the left, across it. Says whether he got to its far side.
func _walk_through(room_node: String) -> bool:
	var blocker: PathBlocker = _room.get_node(room_node)
	var start := blocker.global_position + Vector2.LEFT * (blocker.size.x / 2.0 + WALK_START_GAP)
	_almos.global_position = start
	await wait_physics_frames(MARGIN_FRAMES)
	_almos_input.press_action(&"move_right")
	var distance := WALK_START_GAP + blocker.size.x + PAST_GAP
	await wait_physics_frames(ceili(distance / _player.walk_speed * 60.0) + MARGIN_FRAMES)
	_almos_input.release_action(&"move_right")
	return _almos.global_position.x > blocker.global_position.x + blocker.size.x / 2.0 + PAST_GAP


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)
	await wait_physics_frames(TAP_FRAMES)
