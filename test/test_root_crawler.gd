extends GutTest
## The Root crawlers in the test room with the real Almos and the shipped tuning, driven by Input
## actions: they are Sound hunters, so a crawler goes after the Noise Almos makes within its reach and
## ignores him while he is silent; hiding right after a Roll is heard, hiding after walking is not.
## They are flammable too: a fireball or a lit torch sets one alight, Fire spreads to the ones near it,
## it goes on hunting by Noise while it burns, its Fire hurts it in ticks without alerting it (a tick of
## some other Fire does), and when the burn time is over it is alive, no longer burning, and can catch
## again; a rest puts out every crawler's Fire. Every distance and time is worked from the tuning.

const AlmosInput := preload("res://test/helpers/almos_input.gd")

const TEST_ROOM_PATH := "res://scenes/test_room.tscn"
const SPOT_SCENE_PATH := "res://scenes/world/hiding_spot.tscn"
const FUNGUS_SCENE_PATH := "res://scenes/world/fungus.tscn"
const PLAYER_TUNING_PATH := AlmosInput.TUNING_PATH
const FIRE_PATH := "res://data/fire.tres"
const FIREBALL_PATH := "res://data/fireball.tres"
const TORCH_PATH := "res://data/torch.tres"
const CRAWLER_TUNING_PATH := "res://data/root_crawler.tres"
const ENEMY_TUNING_PATH := "res://data/training_enemy.tres"
const CRAWLER_NAMES: Array[String] = ["RootCrawler1", "RootCrawler2", "RootCrawler3"]
# In physics frames. How long a case that should stay unnoticed is watched for.
const WATCH_FRAMES := 30
const TAP_FRAMES := 3
const SETTLE_FRAMES := 2
# In physics frames. The most a wait for something to happen may take.
const FRAME_LIMIT := 600
# In pixels. How far past the edge of a radius Almos stands, to be clearly out of it.
const BEYOND_MARGIN := 40.0
# In pixels. How close to a crawler Almos stands when he is to be right behind it, or in its face.
const CLOSE_BY := 30.0
# In pixels. How much closer to Almos a crawler must have come to count as moving towards him.
const CLOSER_BY := 10.0
# In pixels. Clearance around the things a crawler must stay clear of in the test room.
const CLEARANCE := 8.0
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 6
# In pixels. Half the width of a crawler's flammable box.
const HALF_WIDTH := 8.0
# In pixels. How far from the stand torch Almos stands to cast, within the Pull's draw range.
const BESIDE_THE_STAND_TORCH := 20.0
# In pixels. How far from the Checkpoint's centre Almos is put to rest: within reach.
const BESIDE_THE_CHECKPOINT := 10.0
const TOLERANCE := 0.001
const FAR_AWAY := Vector2(-10000.0, -10000.0)
# In pixels. Where the Hiding spot is made and how far from it the crawler stands: close by, and
# out of reach of a grab.
const SPOT_AT := Vector2(300.0, 100.0)
const CRAWLER_FROM_SPOT := 120.0

var _almos_input: AlmosInput
var _player: PlayerTuning
var _crawler_tuning: EnemyTuning
var _fire: FireTuning
var _spell: SpellData


func before_each() -> void:
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_player = load(PLAYER_TUNING_PATH) as PlayerTuning
	_crawler_tuning = load(CRAWLER_TUNING_PATH) as EnemyTuning
	_fire = load(FIRE_PATH) as FireTuning
	_spell = load(FIREBALL_PATH) as SpellData


func after_each() -> void:
	_almos_input.release_everything()


func test_the_root_crawler_data_is_a_sound_hunter() -> void:
	assert_true(_crawler_tuning.sound_hunter)


func test_the_test_room_has_three_crawlers_in_the_dark_zone_apart_and_clear_of_everything_else() -> void:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	add_child_autofree(room)
	var zone := room.get_node("DarkZone") as Node2D
	var half: Vector2 = zone.size / 2.0
	var sight := (load(ENEMY_TUNING_PATH) as EnemyTuning).sight_length_dark
	var crawlers: Array[Node2D] = []
	for crawler_name in CRAWLER_NAMES:
		crawlers.append(room.get_node(crawler_name) as Node2D)
	for crawler in crawlers:
		assert_eq(crawler.tuning, _crawler_tuning, "%s uses the Root crawler data" % crawler.name)
		assert_eq(crawler.target, room.get_node("Almos"), "%s goes after Almos" % crawler.name)
		var offset := crawler.global_position - zone.global_position
		assert_true(absf(offset.x) <= half.x and absf(offset.y) <= half.y, "%s is in the dark zone" % crawler.name)
		assert_gt(crawler.global_position.distance_to(room.get_node("TrainingEnemy").global_position), sight + CLEARANCE, "%s is out of the other enemy's Sight" % crawler.name)
		assert_gt(crawler.global_position.distance_to(room.get_node("Checkpoint").global_position), CLEARANCE * 4.0, "%s is clear of the Checkpoint" % crawler.name)
		for node in room.get_children():
			if node is Node2D and (String(node.name).ends_with("Pickup") or String(node.name).ends_with("Torch")):
				assert_gt(crawler.global_position.distance_to(node.global_position), CLEARANCE * 4.0, "%s is clear of %s" % [crawler.name, node.name])
	for i in crawlers.size():
		for j in range(i + 1, crawlers.size()):
			assert_gt(crawlers[i].global_position.distance_to(crawlers[j].global_position), CLEARANCE * 4.0, "%s and %s are apart" % [crawlers[i].name, crawlers[j].name])


func test_almos_standing_or_walking_right_behind_a_crawler_is_not_noticed() -> void:
	var c := _case(Vector2.RIGHT * CLOSE_BY)
	await _watch(WATCH_FRAMES)
	assert_false(c.crawler.in_pursuit, "standing")

	_almos_input.press_action(&"move_right")
	await _watch(WATCH_FRAMES)
	assert_false(c.crawler.in_pursuit, "walking")


func test_almos_standing_or_walking_in_front_of_a_crawler_in_the_dark_is_not_noticed() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY)
	await _watch(WATCH_FRAMES)
	assert_false(c.crawler.in_pursuit, "standing")

	_almos_input.press_action(&"move_left")
	await _watch(WATCH_FRAMES)
	assert_false(c.crawler.in_pursuit, "walking")


func test_sprinting_within_the_radius_draws_a_crawler_into_pursuit_but_beyond_it_does_not() -> void:
	var radius := _player.noise_sprint_radius
	var near := _case(Vector2.LEFT * radius * 0.5)
	# Towards the crawler, so that it is still inside the radius when the Sprint begins, however
	# far Almos walks while the button is held to the threshold.
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _watch(WATCH_FRAMES)
	assert_true(near.crawler.in_pursuit, "within the radius it hears the Sprint")
	await _retire(near)

	var far := _case(Vector2.LEFT * (radius + BEYOND_MARGIN))
	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"roll")
	await _watch(WATCH_FRAMES)
	assert_false(far.crawler.in_pursuit, "beyond the radius it does not")


func test_rolling_within_the_radius_draws_a_crawler_into_pursuit_but_beyond_it_does_not() -> void:
	var radius := _player.noise_roll_radius
	var near := _case(Vector2.LEFT * radius * 0.5)
	await _tap_roll_away()
	assert_true(near.crawler.in_pursuit, "within the radius it hears the Roll")
	await _retire(near)

	var far := _case(Vector2.LEFT * (radius + BEYOND_MARGIN))
	await _tap_roll_away()
	assert_false(far.crawler.in_pursuit, "beyond the radius it does not")


func test_fighting_within_the_radius_draws_a_crawler_into_pursuit_but_beyond_it_does_not() -> void:
	var radius := _player.noise_attack_radius
	var near := _case(Vector2.LEFT * radius * 0.5)
	await _swing()
	assert_true(near.crawler.in_pursuit, "within the radius it hears the fight")
	await _retire(near)

	var far := _case(Vector2.LEFT * (radius + BEYOND_MARGIN))
	await _swing()
	assert_false(far.crawler.in_pursuit, "beyond the radius it does not")


func test_a_crawler_that_hears_the_fight_moves_towards_him() -> void:
	var c := _case(Vector2.LEFT * _player.noise_attack_radius * 0.5)
	var before: float = c.crawler.global_position.distance_to(c.almos.global_position)

	await _swing()

	var after: float = c.crawler.global_position.distance_to(c.almos.global_position)
	assert_lt(after, before - CLOSER_BY, "it came closer")


func test_a_crawler_close_by_does_not_find_him_when_he_hides_after_walking() -> void:
	var c := _hiding_case()
	_almos_input.press_action(&"move_left")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"move_left")
	assert_false(c.crawler.in_pursuit, "control: walking made no Noise")

	await _tap_interact()
	await _watch(FRAME_LIMIT / 10)

	assert_true(c.almos.hiding, "control: he is in")
	assert_false(c.crawler.in_pursuit, "it did not find him")
	assert_false(c.crawler.attacking, "and does not grab")
	assert_eq(c.almos.health.current, c.almos.health.maximum)


func test_a_crawler_close_by_drags_him_out_when_he_hides_right_after_a_roll() -> void:
	var c := _hiding_case()
	# He Rolls right and lands on the spot, within earshot of the crawler.
	c.almos.global_position = c.spot.global_position + Vector2.LEFT * _player.roll_distance
	await _watch(SETTLE_FRAMES)
	_almos_input.press_action(&"move_right")
	_almos_input.press_action(&"roll")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _until(func() -> bool: return c.almos.rolling)
	_almos_input.release_everything()
	# The Roll ends at the start of the frame after its last one. The tap is made in that frame,
	# pressed and let go of between two physics frames as a quick tap of the key is, so it is the
	# last thing done before the Roll's end.
	var roll_frames := ceili(_player.roll_duration * 60.0 - 0.001)
	await _watch(roll_frames - 2)
	assert_true(c.almos.rolling, "control: in the Roll still")
	assert_true(c.crawler.in_pursuit, "control: the crawler heard it")

	_almos_input.press_key(KEY_R, true)
	_almos_input.release_key(KEY_R, true)
	await _watch(2)

	assert_true(c.almos.hiding, "control: he is in")
	await _until(func() -> bool: return c.crawler.attacking and c.crawler.attack_kind == EnemyTuning.AttackKind.UNBLOCKABLE)
	await _until(func() -> bool: return not c.almos.hiding)
	assert_lt(c.almos.health.current, c.almos.health.maximum, "dragged out and hurt")


func test_a_fireball_that_hits_a_crawler_hurts_it_and_sets_it_alight() -> void:
	var c := _fireball_case()
	var flame := _flame_of(c.crawler)
	var health_before: float = c.crawler.health.current

	await _cast()

	assert_true(flame.burning, "it catches")
	assert_lt(c.crawler.health.current, health_before, "and the fireball hurts it as usual")


func test_a_fireballs_splash_sets_a_crawler_next_to_the_one_it_hits_alight() -> void:
	var c := _fireball_case(true)
	var beside: Node = c.room.get_node(CRAWLER_NAMES[1])

	await _cast()

	assert_true(_flame_of(c.crawler).burning, "the one it hit")
	assert_true(_flame_of(beside).burning, "the one beside it")


func test_a_lit_torch_swung_at_a_crawler_sets_it_alight() -> void:
	var c := _case(Vector2.ZERO)
	await _carry_the_torch_in_hand(c.almos)
	var reach := (load(TORCH_PATH) as WeaponData).reach
	c.almos.global_position = c.crawler.global_position + Vector2.LEFT * (HALF_WIDTH + reach / 2.0)
	c.almos.facing = Vector2.RIGHT

	await _swing()

	assert_true(_flame_of(c.crawler).burning)


func test_fire_spreads_from_a_burning_crawler_to_the_crawlers_near_it() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0, true)
	var others: Array[Flammable] = [_flame_of(c.room.get_node(CRAWLER_NAMES[1])), _flame_of(c.room.get_node(CRAWLER_NAMES[2]))]
	_flame_of(c.crawler).ignite()
	await _watch(1)
	assert_false(others[0].burning or others[1].burning, "control: not at once")

	await _watch(_frames(_fire.spread_delay) + MARGIN_FRAMES)

	assert_true(others[0].burning, "the second")
	assert_true(others[1].burning, "the third")


func test_a_burning_crawler_goes_on_towards_the_noise_he_makes() -> void:
	var c := _case(Vector2.LEFT * _player.noise_attack_radius * 0.5)
	_flame_of(c.crawler).ignite()
	var before: float = c.crawler.global_position.distance_to(c.almos.global_position)

	await _swing()

	assert_true(c.crawler.in_pursuit, "it is in Pursuit")
	var after: float = c.crawler.global_position.distance_to(c.almos.global_position)
	assert_lt(after, before - CLOSER_BY, "and comes closer")


func test_a_burning_crawler_still_ignores_a_silent_almos_before_its_first_tick() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY)
	_flame_of(c.crawler).ignite()
	await _watch(_frames(_fire.tick_interval) / 2)

	assert_false(c.crawler.in_pursuit, "the light of its Fire gives it no Sight of him")


func test_each_tick_of_its_own_fire_takes_the_tick_damage_off_a_crawler() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0)
	var flame := _flame_of(c.crawler)
	flame.ignite()
	var before: float = c.crawler.health.current

	await _until(func() -> bool: return flame.ticks == 1)

	assert_eq(flame.ticks, 1, "control: one tick")
	# Out of Pursuit it recovers Health, so at most a frame's worth has come back since the tick.
	assert_almost_eq(c.crawler.health.current, before - _fire.damage_per_tick, _crawler_tuning.health_recovery_rate / 60.0 + TOLERANCE)


func test_when_the_burn_time_is_over_a_crawler_is_alive_and_no_longer_burning() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0)
	var flame := _flame_of(c.crawler)
	flame.ignite()
	# The ticks that fall before the burn time is over: one every interval, none at its end.
	var ticks := ceili(_fire.burn_time / _fire.tick_interval - TOLERANCE) - 1
	assert_lt(float(ticks) * _fire.damage_per_tick, _crawler_tuning.health_maximum, "control: the ticks alone do not kill it")
	# It recovers Health between ticks, so what shows is the lowest it gets.
	var lowest: float = c.crawler.health.current
	for i in _frames(_fire.burn_time) + MARGIN_FRAMES:
		await _watch(1)
		lowest = minf(lowest, c.crawler.health.current)

	assert_true(is_instance_valid(c.crawler), "it is not gone")
	assert_eq(flame.ticks, 0, "its Fire is out")
	assert_false(flame.burning, "not burning")
	assert_false(flame.burnt_out, "not burnt out")
	assert_true(flame.visible and c.crawler.get_node("Look").visible, "it is still there to be seen")
	assert_lt(lowest, _crawler_tuning.health_maximum, "the ticks hurt it")
	assert_gte(lowest, _crawler_tuning.health_maximum - float(ticks) * _fire.damage_per_tick - TOLERANCE, "and nothing but the ticks did")


func test_a_crawler_whose_burn_time_is_over_catches_again() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0)
	var flame := _flame_of(c.crawler)
	flame.ignite()
	await _watch(_frames(_fire.burn_time) + MARGIN_FRAMES)
	assert_false(flame.burning, "control: it burnt down")

	assert_true(flame.ignite(), "it catches")
	assert_true(flame.burning)


func test_a_crawler_that_dies_in_its_own_fire_stops_burning() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0)
	var flame := _flame_of(c.crawler)
	# Little enough Health that the ticks kill it, even with what it recovers before the first.
	c.crawler.health.take_damage(_crawler_tuning.health_maximum - 1.0)
	flame.ignite()
	assert_true(flame.is_in_group(&"fires"), "control: it gives light")

	await _until(func() -> bool: return not is_instance_valid(c.crawler))

	assert_false(is_instance_valid(c.crawler), "control: the ticks killed it")
	var burning_creatures := get_tree().get_nodes_in_group(&"fires").filter(func(node: Node) -> bool: return node is Flammable and node.kind == Flammable.Kind.CREATURE)
	assert_eq(burning_creatures.size(), 0, "no creature burns")


func test_a_burning_crawler_hunts_by_noise_only_through_its_whole_burn_time() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0)
	var flame := _flame_of(c.crawler)
	flame.ignite()
	var start: Vector2 = c.crawler.global_position
	var health_before: float = c.crawler.health.current
	var noticed := false

	for i in _frames(_fire.burn_time) - MARGIN_FRAMES:
		await _watch(1)
		noticed = noticed or c.crawler.in_pursuit

	assert_gt(flame.ticks, 1, "control: its Fire ticked through the burn time")
	assert_lt(c.crawler.health.current, health_before, "its ticks still hurt it")
	assert_false(noticed, "its own Fire never puts it in Pursuit")
	assert_almost_eq(c.crawler.global_position, start, Vector2.ONE * TOLERANCE, "and it does not close in on a silent Almos")


func test_a_tick_of_some_other_fire_alerts_a_crawler_like_any_hit() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0)
	var fungus := (load(FUNGUS_SCENE_PATH) as PackedScene).instantiate() as Node2D
	fungus.position = c.crawler.position
	c.room.add_child(fungus)
	var other := fungus.get_node("Flammable") as Flammable
	other.ignite()
	var health_before: float = c.crawler.health.current

	await _watch(_frames(_fire.tick_interval) + MARGIN_FRAMES)

	assert_eq(other.ticks, 1, "control: the fungus ticked once")
	assert_false(_flame_of(c.crawler).burning, "control: the crawler does not burn yet, so it is not its own Fire")
	assert_lt(c.crawler.health.current, health_before, "control: the tick hurt it")
	assert_true(c.crawler.in_pursuit, "it is alerted")


func test_no_crawler_burns_after_a_rest_brings_the_enemies_back() -> void:
	var c := _case(Vector2.LEFT * CLOSE_BY * 8.0, true)
	for crawler_name in CRAWLER_NAMES:
		_flame_of(c.room.get_node(crawler_name)).ignite()
	await _watch(MARGIN_FRAMES)
	assert_eq(_burning_creatures().size(), CRAWLER_NAMES.size(), "control: they all burn")

	await _rest(c.almos, c.room)

	assert_eq(_burning_creatures().size(), 0, "no crawler burns")
	for crawler_name in CRAWLER_NAMES:
		assert_false(_flame_of(c.room.get_node(crawler_name)).burning, crawler_name + " is not burning")


# A test room with the first crawler at its post facing left, in the dark zone, with Almos at this
# offset from it, and the other crawlers and enemies far away. The test frees it.
func _case(almos_offset: Vector2, keep_crawlers := false) -> Dictionary:
	var room := _room_with_one_crawler(keep_crawlers)
	var crawler := room.get_node(CRAWLER_NAMES[0])
	var almos := room.get_node("Almos") as Node2D
	almos.position = crawler.position + almos_offset
	add_child_autofree(room)
	return {"room": room, "almos": almos, "crawler": crawler}


# The test room with a Hiding spot in the open, Almos on it, and the first crawler close by it.
func _hiding_case() -> Dictionary:
	var room := _room_with_one_crawler()
	var crawler := room.get_node(CRAWLER_NAMES[0])
	var almos := room.get_node("Almos") as Node2D
	var spot := (load(SPOT_SCENE_PATH) as PackedScene).instantiate() as Node2D
	spot.position = SPOT_AT
	room.add_child(spot)
	almos.position = SPOT_AT
	crawler.position = SPOT_AT + Vector2.RIGHT * CRAWLER_FROM_SPOT
	add_child_autofree(room)
	return {"room": room, "almos": almos, "crawler": crawler, "spot": spot}


# The test room with Almos beside the stand torch, facing up, and the first crawler where a
# fireball thrown that way meets it half way along its flight. With a neighbour, the second crawler
# stands next to it, well within the splash.
func _fireball_case(with_neighbour := false) -> Dictionary:
	var room := _room_with_one_crawler()
	var almos := room.get_node("Almos") as Almos
	var crawler := room.get_node(CRAWLER_NAMES[0])
	almos.position = room.get_node("StandTorch").position + Vector2.LEFT * BESIDE_THE_STAND_TORCH
	crawler.position = almos.position + Vector2.UP * _spell.fireball_range / 2.0
	if with_neighbour:
		room.get_node(CRAWLER_NAMES[1]).position = crawler.position + Vector2.RIGHT * _spell.splash_radius / 2.0
	add_child_autofree(room)
	almos.facing = Vector2.UP
	return {"room": room, "almos": almos, "crawler": crawler}


# The test room, not yet in the tree, with the first crawler facing left and the rest of the
# enemies out of the way, the other crawlers too unless they are to be kept.
func _room_with_one_crawler(keep_crawlers := false) -> Node:
	var room := (load(TEST_ROOM_PATH) as PackedScene).instantiate()
	room.get_node(CRAWLER_NAMES[0]).post_facing = Vector2.LEFT
	for crawler_name in CRAWLER_NAMES.slice(1):
		if not keep_crawlers:
			room.get_node(crawler_name).position = FAR_AWAY
	for enemy_name in ["TrainingEnemy", "SoundHunter", "NarJailer"]:
		room.get_node(enemy_name).position = FAR_AWAY
	return room


func _flame_of(crawler: Node) -> Flammable:
	return crawler.get_node("Flammable") as Flammable


# The creatures that burn now, wherever they are.
func _burning_creatures() -> Array:
	return get_tree().get_nodes_in_group(&"fires").filter(func(node: Node) -> bool: return node is Flammable and node.kind == Flammable.Kind.CREATURE)


# Almos rests at the room's Checkpoint, by a tap of Interact beside it, which brings the ordinary
# enemies back.
func _rest(almos: Almos, room: Node) -> void:
	almos.global_position = room.get_node("Checkpoint").global_position + Vector2.RIGHT * BESIDE_THE_CHECKPOINT
	await _watch(MARGIN_FRAMES)
	watch_signals(almos)
	await _tap(&"interact")
	assert_signal_emitted(almos, "rested", "control: he rested")


# Almos picks the torch up from the floor of the room and puts it in hand.
func _carry_the_torch_in_hand(almos: Almos) -> void:
	almos.global_position = almos.get_parent().get_node("TorchPickup").global_position
	await _tap(&"interact")
	await _tap(&"switch_weapon")
	assert_same(almos.weapons.in_hand, load(TORCH_PATH), "control: the torch is in hand")


# Taps the Spell button to draw the flame, waits for the wind-up, taps again to throw it, and waits
# for the flight to end.
func _cast() -> void:
	await _tap(&"cast_spell", TAP_FRAMES)
	await _watch(_spell.wind_up_frames + MARGIN_FRAMES)
	await _tap(&"cast_spell", TAP_FRAMES)
	await _watch(_frames(_spell.fireball_range / _spell.fireball_speed) + MARGIN_FRAMES)


func _tap(action: StringName, after := TAP_FRAMES) -> void:
	_almos_input.press_action(action)
	await _watch(TAP_FRAMES)
	_almos_input.release_action(action)
	await _watch(after)


# How many physics frames last this long, at the 60 a second the suite runs at.
func _frames(seconds: float) -> int:
	return ceili(seconds * 60.0)


func _tap_roll_away() -> void:
	_almos_input.press_action(&"move_left")
	_almos_input.press_action(&"roll")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"roll")
	await _watch(WATCH_FRAMES)
	_almos_input.release_action(&"move_left")


func _swing() -> void:
	_almos_input.press_action(&"attack_light")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"attack_light")
	await _watch(WATCH_FRAMES)


func _tap_interact() -> void:
	_almos_input.press_action(&"interact")
	await _watch(TAP_FRAMES)
	_almos_input.release_action(&"interact")
	await _watch(TAP_FRAMES)


func _retire(room_case: Dictionary) -> void:
	# Let go of every button and let a frame pass, so that the next case starts with none held.
	_almos_input.release_everything()
	room_case.room.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _watch(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _until(condition: Callable) -> void:
	for i in FRAME_LIMIT:
		if condition.call():
			return
		await get_tree().physics_frame
