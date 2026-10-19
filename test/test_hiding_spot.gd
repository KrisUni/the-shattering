extends GutTest
## Hiding spots in the test room with the real Almos, the real enemies and the shipped tuning,
## driven by Input actions: a tap of Interact gets him into a spot in reach and a tap leaves it;
## in there he cannot move or act; a pursuer that does not see him get in ends its Pursuit at once;
## one that does drags him out with an Unblockable attack he can still Roll away from. Every
## distance and time is worked from the tuning, and nothing here pins a number in it.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const SPOT_SCENE_PATH := "res://scenes/world/hiding_spot.tscn"
const ENEMY_SCENE_PATH := "res://scenes/enemies/training_enemy.tscn"
const PICKUP_SCENE_PATH := "res://scenes/world/weapon_pickup.tscn"
const SPEAR_PATH := "res://data/spear.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const HUNTER_TUNING_PATH := "res://data/sound_hunter.tres"
const GROUP := &"hiding_spots"
const SPOT_NAMES: Array[String] = ["Barrel", "Bed", "Curtain"]
# In pixels. Where the enemy has its post: in the open, clear of the pickups and the Checkpoint.
const POST := Vector2(700.0, 324.0)
const FAR_AWAY := Vector2(-10000.0, -10000.0)
# A fraction of the Sight length, along the line leftwards from the post: where Almos is seen.
const SEEN_AT := 0.45
# In pixels. How far past Almos, away from the enemy, the spot is put.
const SPOT_BEHIND_ALMOS := 15.0
# In pixels. Clearance around the things a placeholder spot in the test room must stay clear of.
const CLEARANCE := 32.0
# In pixels. How far from the spot the Sound hunter stands: close by, and out of reach of a grab.
const HUNTER_DISTANCE := 120.0
const TAP_FRAMES := 3
const SETTLE_FRAMES := 2
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 600
const WALL_THICKNESS := 8.0
const WALL_WIDTH := 300.0
# In pixels. How far the wall is from Almos, towards the enemy that must not see him.
const WALL_DISTANCE := 75.0
const TOLERANCE := 0.001

var _almos_input: AlmosInput
var _player: PlayerTuning
var _enemy_tuning: EnemyTuning


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_player = load(AlmosInput.TUNING_PATH) as PlayerTuning
	_enemy_tuning = load(ENEMY_TUNING_PATH) as EnemyTuning


func after_each() -> void:
	_almos_input.release_everything()


func test_the_test_room_has_a_barrel_a_bed_and_a_curtain_clear_of_everything_else() -> void:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	add_child_autofree(room)
	var others: Array[Node2D] = []
	for node in room.get_children():
		if node is Node2D and not node.is_in_group(GROUP) and (node.name == &"Checkpoint" or String(node.name).ends_with("Pickup") or node is Almos or node.is_in_group("enemies")):
			others.append(node)
	assert_gt(others.size(), 5, "control: there are things to keep clear of")

	for spot_name in SPOT_NAMES:
		var spot := room.get_node_or_null(spot_name) as HidingSpot
		assert_not_null(spot, "the test room has a %s" % spot_name)
		if spot == null:
			continue
		assert_true(spot.is_in_group(GROUP), "%s is a Hiding spot" % spot_name)
		for other in others:
			assert_gt(spot.global_position.distance_to(other.global_position), CLEARANCE, "%s is clear of %s" % [spot_name, other.name])
		for light in get_tree().get_nodes_in_group("light_zones"):
			assert_false(LightZone.light_at([light], spot.global_position) < 1.0, "%s is in full light" % spot_name)


func test_a_tap_of_interact_in_reach_of_a_spot_gets_him_into_it() -> void:
	var c := _case()
	c.almos.global_position = c.spot.global_position + Vector2.RIGHT * _player.hide_reach * 0.9

	await _tap_interact()

	assert_true(c.almos.hiding)
	assert_eq(c.almos.global_position, c.spot.global_position, "he is in the spot")


func test_a_tap_out_of_reach_of_every_spot_does_nothing() -> void:
	var c := _case()
	c.almos.global_position = c.spot.global_position + Vector2.RIGHT * _player.hide_reach * 1.2

	await _tap_interact()

	assert_false(c.almos.hiding)


func test_a_second_tap_leaves_the_spot_where_he_is_in_it() -> void:
	var c := _case()
	c.almos.global_position = c.spot.global_position + Vector2.RIGHT * _player.hide_reach * 0.5
	await _tap_interact()
	assert_true(c.almos.hiding, "control: he is in")

	await _tap_interact()

	assert_false(c.almos.hiding)
	assert_eq(c.almos.global_position, c.spot.global_position, "at the spot's place")


func test_he_cannot_move_in_a_spot() -> void:
	var c := _case()
	c.almos.global_position = c.spot.global_position
	await _tap_interact()
	_almos_input.press_action(&"move_down")

	await _frames(TAP_FRAMES * 4)

	assert_eq(c.almos.global_position, c.spot.global_position)
	assert_true(c.almos.hiding)


func test_he_cannot_roll_or_attack_in_a_spot_and_makes_no_noise() -> void:
	var c := _case()
	c.almos.global_position = c.spot.global_position
	await _tap_interact()

	_almos_input.press_action(&"move_down")
	_almos_input.press_action(&"roll")
	_almos_input.press_action(&"attack_light")
	await _frames(TAP_FRAMES)

	assert_false(c.almos.rolling, "no Roll")
	assert_false(c.almos.attacking, "no attack")
	assert_eq(c.almos.noise_radius, 0.0, "no Noise")
	assert_eq(c.almos.global_position, c.spot.global_position, "and he has not moved")


func test_holding_interact_in_a_spot_neither_drops_the_weapon_nor_leaves() -> void:
	var c := _case()
	c.almos.global_position = c.spot.global_position
	await _tap_interact()
	var in_hand: WeaponData = c.almos.weapons.in_hand
	assert_not_null(in_hand, "control: he carries a Weapon")

	_almos_input.press_action(&"interact")
	await _frames(ceili(_player.drop_hold_time * 60.0) + TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await _frames(TAP_FRAMES)

	assert_true(c.almos.hiding, "a hold is not a tap")
	assert_same(c.almos.weapons.in_hand, in_hand, "and the Weapon is still in his hand")


func test_a_checkpoint_in_reach_wins_against_a_spot_in_reach() -> void:
	var c := _case()
	var checkpoint := c.room.get_node("Checkpoint") as Node2D
	c.spot.global_position = checkpoint.global_position + Vector2.RIGHT * _player.rest_reach * 0.3
	c.almos.global_position = checkpoint.global_position
	var rests := []
	c.almos.rested.connect(func(_checkpoint: Checkpoint) -> void: rests.append(true))

	await _tap_interact()

	assert_eq(rests.size(), 1, "he rests")
	assert_false(c.almos.hiding, "and does not hide")


func test_a_spot_in_reach_wins_against_a_weapon_in_reach() -> void:
	var c := _case()
	var pickup := (load(PICKUP_SCENE_PATH) as PackedScene).instantiate()
	pickup.weapon = load(SPEAR_PATH)
	pickup.position = c.spot.position + Vector2.UP * _player.pickup_reach * 0.3
	c.room.add_child(pickup)
	c.almos.global_position = c.spot.global_position

	await _tap_interact()

	assert_true(c.almos.hiding, "he hides")
	assert_false(pickup.is_queued_for_deletion(), "and the Weapon is left lying")


func test_a_weapon_in_reach_is_still_picked_up_when_there_is_no_spot() -> void:
	var c := _case()
	var pickup := (load(PICKUP_SCENE_PATH) as PackedScene).instantiate()
	pickup.weapon = load(SPEAR_PATH)
	pickup.position = c.almos.position + Vector2.UP * _player.hide_reach * 4.0 + Vector2.UP * _player.pickup_reach * 0.3
	c.room.add_child(pickup)
	c.almos.global_position = pickup.global_position

	await _tap_interact()

	assert_false(c.almos.hiding)
	assert_true(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "control: it is picked up")


func test_a_pursuer_that_does_not_see_him_get_in_ends_its_pursuit_at_once() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	assert_true(c.enemy.in_pursuit, "control: it sees him and is after him")
	# He steps behind a wall, out of its Sight, and gets into a spot there.
	var behind := _wall_between(c.room, c.almos.global_position, Vector2.LEFT)
	c.almos.global_position = behind
	c.spot.global_position = behind + Vector2.LEFT * SPOT_BEHIND_ALMOS
	await _frames(SETTLE_FRAMES)
	assert_true(c.enemy.in_pursuit, "control: it has not lost him yet, the lose-time is far off")

	await _tap_interact(1)

	assert_false(c.enemy.in_pursuit, "in the frame he gets in")


func test_a_pursuer_that_saw_him_get_in_drags_him_out_with_an_unblockable_attack_that_deals_its_damage() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	assert_true(c.enemy.in_pursuit, "control: it is after him")
	assert_eq(c.enemy.attack_kind, EnemyTuning.AttackKind.STRIKE, "control: the pattern starts with another kind")

	await _tap_interact(1)
	assert_true(c.almos.hiding, "control: he is in")
	assert_true(c.enemy.in_pursuit, "it did not lose him")
	await _until(func() -> bool: return c.enemy.attacking)

	assert_eq(c.enemy.attack_kind, EnemyTuning.AttackKind.UNBLOCKABLE, "out of its pattern, the grab")
	assert_true(c.enemy.winding_up, "with its usual wind-up")
	assert_lt(c.enemy.global_position.distance_to(c.spot.global_position), _enemy_tuning.attack_range + 1.0, "at the spot")
	await _until(func() -> bool: return not c.almos.hiding)

	assert_false(c.almos.hiding, "he is pulled out")
	assert_almost_eq(c.almos.health.current, c.almos.health.maximum - _enemy_tuning.unblockable_attack.damage, TOLERANCE, "and takes the grab's damage")
	assert_eq(c.almos.global_position, c.spot.global_position, "at the spot's place")


func test_leaving_in_the_wind_up_and_rolling_away_avoids_the_grab() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	await _tap_interact(1)
	await _until(func() -> bool: return c.enemy.attacking and c.enemy.attack_kind == EnemyTuning.AttackKind.UNBLOCKABLE)
	assert_true(c.enemy.winding_up, "control: the grab is winding up")

	await _tap_interact(1)
	assert_false(c.almos.hiding, "he left")
	# Away from the enemy, which stands on the other side of the spot.
	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"roll")
	await _frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _frames(SETTLE_FRAMES)
	_almos_input.release_everything()
	assert_true(c.almos.rolling, "control: he is Rolling")
	await _until(func() -> bool: return not c.enemy.attacking)

	assert_eq(c.almos.health.current, c.almos.health.maximum, "the grab found nobody")


func test_a_drag_out_that_a_wall_stops_short_gives_up_after_the_lose_time_and_it_goes_back() -> void:
	var c := _case()
	await _frames(SETTLE_FRAMES)
	_almos_input.press_action(&"interact")
	await _frames(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	# Frame by frame, so that the frame he gets in is the one the count starts from.
	for i in FRAME_LIMIT:
		await get_tree().physics_frame
		if c.almos.hiding:
			break
	assert_true(c.almos.hiding, "control: he is in")
	assert_true(c.enemy.in_pursuit, "control: it saw him get in and is after the spot")
	# A wall midway between the enemy and the spot, put up once it has set off.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_THICKNESS, WALL_WIDTH)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = (c.enemy.global_position + c.spot.global_position) / 2.0
	c.room.add_child(wall)

	await _frames(_enemy_tuning.lose_sight_frames - 1)
	assert_true(c.enemy.in_pursuit, "one frame before the lose-time it is still at the wall")
	assert_false(c.enemy.attacking, "it never got to grab")
	await _frames(1)
	assert_false(c.enemy.in_pursuit, "the lose-time after he got in, it gives up")

	await _until(func() -> bool: return c.enemy.global_position.distance_to(POST) < 1.0)
	assert_lt(c.enemy.global_position.distance_to(POST), 1.0, "it is back at its post")
	assert_false(c.enemy.in_pursuit, "and stays out of Pursuit")
	assert_true(c.almos.hiding, "he is still hidden")
	assert_eq(c.almos.health.current, c.almos.health.maximum, "and unharmed")


func test_two_pursuers_one_that_saw_him_drags_and_one_that_did_not_ends_its_pursuit() -> void:
	var c := _case()
	var second := _second_enemy_behind_a_wall(c)
	await _frames(SETTLE_FRAMES)
	assert_true(second.in_pursuit, "control: the second is after him too, unseen")
	assert_true(c.enemy.in_pursuit, "control: so is the first, which sees him")

	await _tap_interact(1)

	assert_false(second.in_pursuit, "the one that did not see ends it")
	assert_true(c.enemy.in_pursuit, "the one that did goes on")
	await _until(func() -> bool: return c.enemy.attacking)
	assert_eq(c.enemy.attack_kind, EnemyTuning.AttackKind.UNBLOCKABLE)


func test_nothing_notices_him_in_a_spot() -> void:
	var c := _case()
	# The enemy faces away, and does not see him get in.
	c.enemy.post_facing = Vector2.RIGHT
	await _frames(SETTLE_FRAMES)
	assert_false(c.enemy.in_pursuit, "control: it has not noticed him")
	await _tap_interact(1)
	assert_true(c.almos.hiding, "control: he is in")

	# It turns to face him, close by, in full light.
	c.enemy.post_facing = Vector2.LEFT
	await _frames(FRAME_LIMIT / 10)

	assert_false(c.enemy.in_pursuit, "it does not see him")


func test_a_sound_hunter_close_by_does_not_find_him_when_he_hides_after_walking() -> void:
	var c := _case_with_hunter()
	c.almos.global_position = c.spot.global_position + Vector2.RIGHT * 4.0
	await _frames(SETTLE_FRAMES)
	_almos_input.press_action(&"move_left")
	await _frames(TAP_FRAMES)
	_almos_input.release_action(&"move_left")
	assert_false(c.hunter.in_pursuit, "control: walking made no Noise")

	await _tap_interact(1)
	await _frames(FRAME_LIMIT / 10)

	assert_true(c.almos.hiding, "control: he is in")
	assert_false(c.hunter.in_pursuit, "it did not find him")
	assert_false(c.hunter.attacking, "and does not grab")
	assert_eq(c.almos.health.current, c.almos.health.maximum)


func test_a_sound_hunter_close_by_drags_him_out_when_he_hides_right_after_a_roll() -> void:
	var c := _case_with_hunter()
	# He Rolls right and lands on the spot, within earshot of the hunter.
	var start: Vector2 = c.spot.global_position + Vector2.LEFT * _player.roll_distance
	c.almos.global_position = start
	await _frames(SETTLE_FRAMES)
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _frames(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _until(func() -> bool: return c.almos.rolling)
	_almos_input.release_everything()
	# The Roll is under way and ends at the start of the frame after its last one. The tap is made
	# in that frame, pressed and let go of between two physics frames as a quick tap of the key is,
	# so it is the last thing done before the Roll's end.
	var roll_frames := ceili(_player.roll_duration * 60.0 - 0.001)
	await _frames(roll_frames - 2)
	assert_true(c.almos.rolling, "control: in the Roll still")
	assert_true(c.hunter.in_pursuit, "control: the hunter heard it")

	_almos_input.press_key(KEY_R, true)
	_almos_input.release_key(KEY_R, true)
	await _frames(2)

	assert_true(c.almos.hiding, "control: he is in")
	await _until(func() -> bool: return c.hunter.attacking and c.hunter.attack_kind == EnemyTuning.AttackKind.UNBLOCKABLE)
	await _until(func() -> bool: return not c.almos.hiding)
	assert_lt(c.almos.health.current, c.almos.health.maximum, "dragged out and hurt")


# --- Helpers ---

# In pixels. How far from the enemy Almos stands for the swing tests: well inside every reach.
const SWING_DISTANCE := 30.0
# In pixels. How far from the enemy the wall that hides Almos from it stands, between them.
const SWING_WALL_DISTANCE := 12.0
const SWING_WALL_THICKNESS := 2.0


func test_an_unseen_pursuers_strike_under_way_does_not_hit_or_pull_him_out() -> void:
	await _unseen_swing_does_not_hit(EnemyTuning.AttackKind.STRIKE)


func test_an_unseen_pursuers_low_attack_under_way_does_not_hit_or_pull_him_out() -> void:
	await _unseen_swing_does_not_hit(EnemyTuning.AttackKind.LOW)


func test_a_seers_strike_under_way_does_not_pull_him_out_but_its_later_grab_does() -> void:
	await _seers_swing_does_not_pull_out_but_the_grab_does(EnemyTuning.AttackKind.STRIKE)


func test_a_seers_low_attack_under_way_does_not_pull_him_out_but_its_later_grab_does() -> void:
	await _seers_swing_does_not_pull_out_but_the_grab_does(EnemyTuning.AttackKind.LOW)


func test_a_seers_unblockable_pattern_attack_under_way_does_not_pull_him_out_but_its_later_grab_does() -> void:
	await _seers_swing_does_not_pull_out_but_the_grab_does(EnemyTuning.AttackKind.UNBLOCKABLE)


func test_an_enemy_with_no_target_ignores_him_hiding() -> void:
	var c := _case()
	var stray := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	stray.position = FAR_AWAY
	stray.tuning = _enemy_tuning
	stray.target = null
	c.room.add_child(stray)
	await _frames(SETTLE_FRAMES)

	await _tap_interact(1)

	assert_true(c.almos.hiding, "he is in")
	assert_false(stray.in_pursuit, "it is unmoved")


# The test room with Almos where the training enemy sees him, a spot just behind him, and the
# enemy at its post facing left. The Sound hunter is far away. Returns {"room", "almos", "enemy",
# "spot"}. The test frees it.
func _case() -> Dictionary:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	var almos := room.get_node("Almos") as Node2D
	var enemy := room.get_node("TrainingEnemy")
	almos.position = POST + Vector2.LEFT * _enemy_tuning.sight_length_full * SEEN_AT
	enemy.position = POST
	enemy.post_facing = Vector2.LEFT
	room.get_node("SoundHunter").position = FAR_AWAY
	var spot := (load(SPOT_SCENE_PATH) as PackedScene).instantiate() as Node2D
	spot.position = almos.position + Vector2.LEFT * SPOT_BEHIND_ALMOS
	room.add_child(spot)
	add_child_autofree(room)
	return {"room": room, "almos": almos, "enemy": enemy, "spot": spot}


# The test room with the Sound hunter beside the spot, and the training enemy far away.
func _case_with_hunter() -> Dictionary:
	var c := _case()
	c.enemy.position = FAR_AWAY
	c.spot.global_position = Vector2(300.0, 100.0)
	c.almos.global_position = c.spot.global_position
	var hunter: Node2D = c.room.get_node("SoundHunter")
	hunter.global_position = c.spot.global_position + Vector2.RIGHT * HUNTER_DISTANCE
	hunter.post_facing = Vector2.LEFT
	c["hunter"] = hunter
	return c


# A wall across the line from this point towards that direction, WALL_DISTANCE away, and the point
# on the far side of it, where Almos is out of the Sight of an enemy on the near side.
func _wall_between(room: Node, from: Vector2, towards: Vector2) -> Vector2:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(WALL_WIDTH, WALL_THICKNESS) if towards.x == 0.0 else Vector2(WALL_THICKNESS, WALL_WIDTH)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = from + towards * WALL_DISTANCE
	room.add_child(wall)
	return from + towards * (WALL_DISTANCE + WALL_THICKNESS * 3.0)


# A second enemy in Pursuit that cannot see Almos: it stands behind a wall across the way to him.
func _second_enemy_behind_a_wall(c: Dictionary) -> Node:
	var enemy := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	enemy.name = "SecondEnemy"
	enemy.position = c.almos.position + Vector2.UP * WALL_DISTANCE * 2.0
	enemy.tuning = _enemy_tuning
	enemy.target = c.almos
	enemy.post_facing = Vector2.DOWN
	c.room.add_child(enemy)
	_wall_between(c.room, c.almos.position, Vector2.UP)
	# A hit from him notices him, wall or no wall.
	enemy.get_node("Hurtbox").landed.emit(0.0, c.almos.position, false)
	return enemy


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


# Almos gets into the spot while an enemy that cannot see him get in is making this attack: its
# Pursuit ends, and the swing, which reaches the spot, does not hit him or pull him out.
func _unseen_swing_does_not_hit(kind: EnemyTuning.AttackKind) -> void:
	var c := _swing_case()
	await _until(func() -> bool: return c.enemy.attacking and c.enemy.winding_up and c.enemy.attack_kind == kind)
	assert_eq(c.enemy.attack_kind, kind, "control: the swing is under way")
	assert_lt(SWING_DISTANCE, _enemy_tuning.reach_of(kind), "control: Almos is within its reach")
	var health_before: float = c.almos.health.current
	# A wall between them, so that it does not see him get in; the swing goes through it.
	_wall_across(c.room, c.enemy.position + Vector2.LEFT * SWING_WALL_DISTANCE)

	await _tap_interact(1)
	assert_true(c.almos.hiding, "control: he is in")
	assert_false(c.enemy.in_pursuit, "it did not see him get in, so its Pursuit ends")
	await _until(func() -> bool: return c.enemy.striking)
	assert_true(c.enemy.striking, "control: the swing strikes")
	await _until(func() -> bool: return not c.enemy.striking)

	assert_true(c.almos.hiding, "the swing did not pull him out")
	assert_eq(c.almos.health.current, health_before, "and did no damage")


# Almos gets into the spot while an enemy that sees him get in is making this attack of its
# pattern: that swing does not pull him out, the grab it makes after it does.
func _seers_swing_does_not_pull_out_but_the_grab_does(kind: EnemyTuning.AttackKind) -> void:
	var c := _swing_case()
	await _until(func() -> bool: return c.enemy.attacking and c.enemy.winding_up and c.enemy.attack_kind == kind)
	assert_eq(c.enemy.attack_kind, kind, "control: the swing is under way")
	var health_before: float = c.almos.health.current

	await _tap_interact(1)
	assert_true(c.almos.hiding, "control: he is in")
	assert_true(c.enemy.in_pursuit, "control: it saw him get in")
	await _until(func() -> bool: return c.enemy.striking)
	assert_true(c.enemy.striking, "control: the swing strikes")
	await _until(func() -> bool: return not c.enemy.striking)

	assert_true(c.almos.hiding, "its pattern's swing did not pull him out")
	assert_eq(c.almos.health.current, health_before, "and did no damage")

	await _until(func() -> bool: return not c.almos.hiding)
	assert_false(c.almos.hiding, "the grab pulls him out")
	assert_almost_eq(c.almos.health.current, health_before - _enemy_tuning.unblockable_attack.damage, TOLERANCE, "for the grab's damage")


# The room with the enemy in Pursuit and Almos, with Health enough for several swings, close in
# front of it and a spot just behind him.
func _swing_case() -> Dictionary:
	var c := _case()
	c.almos.position = POST + Vector2.LEFT * SWING_DISTANCE
	c.spot.position = c.almos.position + Vector2.LEFT * SPOT_BEHIND_ALMOS
	c.almos.health.maximum = 100000.0
	return c


# A thin wall across the line between the enemy and Almos, at this place.
func _wall_across(room: Node, at: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(SWING_WALL_THICKNESS, WALL_WIDTH)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = at
	room.add_child(wall)
