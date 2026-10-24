extends GutTest
## The Nar jailer and Hiding spots, in the test room with the real Almos, the real enemy scene and
## the jailer's own data file, driven by Input actions: a jailer that sees him get in goes to the
## spot and drags him out with its Unblockable grab, though its pattern is a club combo with no
## Unblockable attack in it and it guards; one that does not see him get in ends its Pursuit. Every
## distance and time is worked from the data files, and nothing here pins a number in them.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const SPOT_SCENE_PATH := "res://scenes/world/hiding_spot.tscn"
const JAILER_PATH := "res://data/nar_jailer.tres"

const COMBO := EnemyTuning.AttackKind.COMBO
const UNBLOCKABLE := EnemyTuning.AttackKind.UNBLOCKABLE

# In pixels. Where the jailer has its post: in the open, clear of the pickups and the Checkpoint.
const POST := Vector2(700.0, 324.0)
const FAR_AWAY := Vector2(-10000.0, -10000.0)
# In pixels. How far from the jailer Almos stands: inside its attack range and its reach, and so is the spot behind him.
const ALMOS_DISTANCE := 20.0
# In pixels. How far past Almos, away from the jailer, the spot is put.
const SPOT_BEHIND_ALMOS := 15.0
# In pixels. How far from Almos the wall that hides him from the jailer stands, towards it.
const WALL_DISTANCE := 75.0
const WALL_THICKNESS := 8.0
const WALL_WIDTH := 300.0
const TAP_FRAMES := 3
const SETTLE_FRAMES := 2
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 600
# In Health points.
const TOLERANCE := 0.001

var _almos_input: AlmosInput
var _tuning: EnemyTuning


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_tuning = load(JAILER_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_a_jailer_that_saw_him_get_in_drags_him_out_with_its_unblockable_grab_for_its_damage() -> void:
	var c := _case()
	await _until(func() -> bool: return c.jailer.attacking and c.jailer.winding_up)
	assert_true(c.jailer.in_pursuit, "control: it is after him")
	assert_eq(c.jailer.attack_kind, COMBO, "control: its pattern has only the combo in it")

	await _tap_interact(1)
	assert_true(c.almos.hiding, "control: he is in")
	var health_before: float = c.almos.health.current
	assert_true(c.jailer.in_pursuit, "it did not lose him")
	await _until(func() -> bool: return c.jailer.attacking and c.jailer.attack_kind == UNBLOCKABLE)

	assert_eq(c.jailer.attack_kind, UNBLOCKABLE, "the grab")
	assert_true(c.jailer.winding_up, "with its usual wind-up")
	await _until(func() -> bool: return not c.almos.hiding)

	assert_false(c.almos.hiding, "he is pulled out")
	assert_almost_eq(c.almos.health.current, health_before - _tuning.unblockable_attack.damage, TOLERANCE, "and takes the grab's damage")


func test_the_grab_is_announced_with_its_cue() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	var cues := [0]
	c.jailer.unblockable_cue_played.connect(func() -> void: cues[0] += 1)

	await _tap_interact(1)
	await _until(func() -> bool: return cues[0] > 0)

	assert_eq(cues[0], 1, "the cue plays as the grab begins")


func test_a_combo_under_way_when_he_gets_in_is_finished_without_pulling_him_out_and_the_grab_comes_after() -> void:
	var c := _case()
	await _until(func() -> bool: return c.jailer.attacking and c.jailer.winding_up and c.jailer.current_attack == _tuning.combo[0])
	var health_before: float = c.almos.health.current

	await _tap_interact(1)
	assert_true(c.almos.hiding, "control: he is in")
	assert_true(c.jailer.in_pursuit, "control: it saw him get in")
	var begun := await _attacks_begun_until(func() -> bool: return not c.almos.hiding)

	assert_eq(begun.size(), 1, "after the swing under way, only one attack is begun")
	assert_eq(begun[0], _tuning.unblockable_attack, "and it is the grab, not the combo's next swing")
	assert_almost_eq(c.almos.health.current, health_before - _tuning.unblockable_attack.damage, TOLERANCE, "so the swing under way did no damage to him in there")


func test_a_swing_of_the_combo_under_way_does_not_pull_him_out() -> void:
	var c := _case()
	await _until(func() -> bool: return c.jailer.attacking and c.jailer.winding_up and c.jailer.current_attack == _tuning.combo[0])
	var health_before: float = c.almos.health.current

	await _tap_interact(1)
	await _until(func() -> bool: return c.jailer.striking)
	assert_true(c.jailer.striking, "control: the swing strikes")
	await _until(func() -> bool: return not c.jailer.striking)

	assert_true(c.almos.hiding, "the swing did not pull him out")
	assert_eq(c.almos.health.current, health_before, "and did no damage")


func test_leaving_in_the_wind_up_and_rolling_away_avoids_the_grab() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	await _tap_interact(1)
	await _until(func() -> bool: return c.jailer.attacking and c.jailer.attack_kind == UNBLOCKABLE)
	assert_true(c.jailer.winding_up, "control: the grab is winding up")
	var health_before: float = c.almos.health.current

	await _tap_interact(1)
	assert_false(c.almos.hiding, "he left")
	# Away from the jailer, which stands on the other side of the spot.
	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"roll")
	await _frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _frames(SETTLE_FRAMES)
	_almos_input.release_everything()
	assert_true(c.almos.rolling, "control: he is Rolling")
	await _until(func() -> bool: return not c.jailer.attacking)

	assert_eq(c.almos.health.current, health_before, "the grab found nobody")


func test_a_jailer_that_did_not_see_him_get_in_ends_its_pursuit_at_once() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	assert_true(c.jailer.in_pursuit, "control: it sees him and is after him")
	# He steps behind a wall, out of its Sight, and gets into a spot there.
	var behind := _wall_between(c.room, c.almos.global_position, Vector2.LEFT)
	c.almos.global_position = behind
	c.spot.global_position = behind + Vector2.LEFT * SPOT_BEHIND_ALMOS
	await _frames(SETTLE_FRAMES)
	assert_true(c.jailer.in_pursuit, "control: it has not lost him yet, the lose-time is far off")

	await _tap_interact(1)

	assert_true(c.almos.hiding, "control: he is in")
	assert_false(c.jailer.in_pursuit, "in the frame he gets in")


func test_after_the_drag_it_fights_with_its_combo_and_never_the_grab() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	await _tap_interact(1)
	await _until(func() -> bool: return not c.almos.hiding)
	assert_false(c.almos.hiding, "control: he was dragged out")
	var combo_frames := 0
	for swing in _tuning.combo:
		combo_frames += swing.total_frames()

	var begun := await _attacks_begun_until(func() -> bool: return false, combo_frames * 2)

	assert_gt(begun.size(), 0, "control: it fights him")
	assert_false(begun.has(_tuning.unblockable_attack), "never with the grab")
	for attack in begun:
		assert_true(_tuning.combo.has(attack), "only with the swings of its combo")


# --- Helpers ---

# The test room with the Nar jailer at its post facing left, Almos where it sees him, close in
# front of it, with Health enough for several swings, and a spot just behind him. The Sound hunter
# and the training enemy are far away. Returns {"room", "almos", "jailer", "spot"}. The test frees it.
func _case() -> Dictionary:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var almos := room.get_node("Almos") as Node2D
	var jailer := room.get_node("TrainingEnemy")
	jailer.tuning = _tuning
	jailer.position = POST
	jailer.post_facing = Vector2.LEFT
	room.get_node("SoundHunter").position = FAR_AWAY
	almos.position = POST + Vector2.LEFT * ALMOS_DISTANCE
	var spot := (load(SPOT_SCENE_PATH) as PackedScene).instantiate() as Node2D
	spot.position = almos.position + Vector2.LEFT * SPOT_BEHIND_ALMOS
	room.add_child(spot)
	add_child_autofree(room)
	almos.health.maximum = 100000.0
	return {"room": room, "almos": almos, "jailer": jailer, "spot": spot}


# A wall across the line from this point towards that direction, WALL_DISTANCE away, and the point
# on the far side of it, where Almos is out of the Sight of a jailer on the near side.
func _wall_between(room: Node, from: Vector2, towards: Vector2) -> Vector2:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_THICKNESS, WALL_WIDTH)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = from + towards * WALL_DISTANCE
	room.add_child(wall)
	return from + towards * (WALL_DISTANCE + WALL_THICKNESS * 3.0)


# Taps Interact and waits this many frames after it, one by default.
func _tap_interact(after := TAP_FRAMES) -> void:
	_almos_input.press_action(&"interact")
	await _frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await _frames(after)


# Waits this many physics frames, one signal each: what the test does next is seen by the very
# next frame to be processed.
func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# Waits until this is true, for no more than FRAME_LIMIT frames.
func _until(condition: Callable) -> void:
	for i in FRAME_LIMIT:
		if condition.call():
			return
		await get_tree().physics_frame


# Every attack the jailer begins from now until the condition holds, or for this many frames at
# most, as the AttackData of each, in order. An attack under way now is not one of them; a swing
# that follows another at once is.
func _attacks_begun_until(condition: Callable, limit := FRAME_LIMIT) -> Array[AttackData]:
	var jailer := get_tree().get_first_node_in_group("enemies")
	var begun: Array[AttackData] = []
	var last: AttackData = jailer.current_attack if jailer.attacking else null
	for i in limit:
		if condition.call():
			break
		await get_tree().physics_frame
		var now: AttackData = jailer.current_attack if jailer.attacking else null
		if now != null and now != last:
			begun.append(now)
		last = now
	return begun
