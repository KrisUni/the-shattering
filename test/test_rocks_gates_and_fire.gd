extends GutTest
## Big rocks, small rocks, metal gates and Fire by contact:
## - a big rock is solid and too heavy to move: a Pull or a Shove only budges it, and a Shove with a
##   wall right behind it breaks it into four to six small rocks;
## - Pull lifts small rocks two at a time and one Shove throws both; a thrown rock breaks a barrel it
##   hits and crashes a metal gate open;
## - a metal gate budges at a Pull or a Shove and stays shut; a thrown flame melts it open, but
##   touching something burning does not;
## - Fire passes only by contact: a burning guard sets alight a barrel it touches, not one apart from
##   it, and Almos catches from a burning guard he touches, burns and is hurt, and is put out when
##   returned;
## - the guards are drawn as warders of their own, not as Almos.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const BIG_ROCK_SCENE := preload("res://scenes/world/big_rock.tscn")
const SMALL_ROCK_SCENE := preload("res://scenes/world/small_rock.tscn")
const BARREL_SCENE := preload("res://scenes/world/barrel.tscn")
const GATE_SCENE := preload("res://scenes/world/metal_gate.tscn")
const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const SPELL_PATH := "res://data/fireball.tres"
const FIRE_PATH := "res://data/fire.tres"
const TAP_FRAMES := 2
const MARGIN_FRAMES := 8

var _almos_input: AlmosInput


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _place(scene: PackedScene, almos: Node2D, offset: Vector2) -> Node2D:
	var node := scene.instantiate() as Node2D
	node.position = almos.global_position + offset
	almos.get_parent().add_child(node)
	autofree(node)
	return node


func _wall(almos: Node2D, centre: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	wall.position = almos.global_position + centre
	almos.get_parent().add_child(wall)
	autofree(wall)
	return wall


func _wind_up() -> int:
	return (load(SPELL_PATH) as SpellData).wind_up_frames + MARGIN_FRAMES


func _small_rocks(parent: Node) -> Array:
	return parent.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("SmallRock") and is_instance_valid(n))


# --- big rocks ---

func test_a_pull_only_budges_a_big_rock() -> void:
	var almos = _almos_input.spawn_almos()
	var rock := _place(BIG_ROCK_SCENE, almos, Vector2(0, 80)) as BigRock
	var at := rock.global_position
	watch_signals(rock)
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(4)
	assert_signal_emitted(rock, "budged", "it budged")
	assert_true(rock.budging(), "and is rocking")
	await wait_physics_frames(30)
	assert_eq(rock.global_position, at, "it stays where it stands")
	assert_false((almos.get_node("Spell") as AlmosSpell).holding, "he holds nothing")


func test_a_shove_in_the_open_only_budges_a_big_rock() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.DOWN
	var rock := _place(BIG_ROCK_SCENE, almos, Vector2(0, 80)) as BigRock
	watch_signals(rock)
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_physics_frames(4)
	assert_signal_emitted(rock, "budged", "it budged")
	assert_signal_not_emitted(rock, "shattered", "nothing behind it to crush it on")
	assert_true(is_instance_valid(rock), "whole")


func test_a_shove_against_a_wall_breaks_a_big_rock_into_four_to_six_small_rocks() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.UP
	var rock := _place(BIG_ROCK_SCENE, almos, Vector2(0, -80)) as BigRock
	_wall(almos, Vector2(0, -80 - 23 - 16 - 10), Vector2(200, 20))
	var parent := rock.get_parent()
	var pieces: Array = []
	rock.shattered.connect(func(made: Array) -> void: pieces.append_array(made))
	await wait_physics_frames(2)
	assert_true(rock.wall_behind(Vector2.UP), "control: a wall right behind it")
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_physics_frames(4)
	assert_between(pieces.size(), 4, 6, "it broke into four to six small rocks")
	assert_false(is_instance_valid(rock), "the big rock is gone")
	for piece in pieces:
		autofree(piece)
		assert_eq(piece.get_parent(), parent, "scattered where it stood")


# --- small rocks ---

func test_pull_lifts_small_rocks_two_at_a_time_and_a_shove_throws_both() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var first := _place(SMALL_ROCK_SCENE, almos, Vector2(50, 0))
	var second := _place(SMALL_ROCK_SCENE, almos, Vector2(70, 20))
	var third := _place(SMALL_ROCK_SCENE, almos, Vector2(150, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up())
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_eq(spell.held_object, first.get_node("Liftable"), "the nearest")
	assert_eq(spell.held_extra, second.get_node("Liftable"), "and the next nearest with it")
	assert_eq(third.get_node("Liftable").state, Liftable.State.RESTING, "not a third")
	await wait_seconds(0.3)
	await _tap(&"cast_spell")
	await wait_physics_frames(2)
	assert_eq(first.get_node("Liftable").state, Liftable.State.FLYING, "one Shove throws the first")
	assert_eq(second.get_node("Liftable").state, Liftable.State.FLYING, "and the second")
	assert_false(spell.holding, "his hands are empty")


func test_a_thrown_rock_breaks_a_barrel() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	_place(SMALL_ROCK_SCENE, almos, Vector2(50, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up())
	await wait_seconds(0.3)
	var barrel := _place(BARREL_SCENE, almos, Vector2(140, 6))
	await wait_physics_frames(2)
	almos.facing = Vector2.RIGHT
	await _tap(&"cast_spell")
	await wait_seconds(0.6)
	assert_eq(barrel.get_node("Liftable").state, Liftable.State.BROKEN, "the barrel broke")


func test_a_thrown_rock_crashes_a_metal_gate_open() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	_place(SMALL_ROCK_SCENE, almos, Vector2(50, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up())
	await wait_seconds(0.3)
	var gate := GATE_SCENE.instantiate() as MetalGate
	gate.id = &"test/gate_crashed"
	gate.size = Vector2(16, 128)
	gate.position = almos.global_position + Vector2(160, 0)
	almos.get_parent().add_child(gate)
	autofree(gate)
	watch_signals(gate)
	await wait_physics_frames(2)
	almos.facing = Vector2.RIGHT
	await _tap(&"cast_spell")
	await wait_seconds(0.6)
	assert_signal_emitted(gate, "crashed", "the rock crashed it")
	assert_true(gate.open, "it is open")


# --- metal gates ---

func _gate(almos: Node2D, offset: Vector2, id: StringName) -> MetalGate:
	var gate := GATE_SCENE.instantiate() as MetalGate
	gate.id = id
	gate.position = almos.global_position + offset
	almos.get_parent().add_child(gate)
	autofree(gate)
	return gate


func test_a_pull_or_a_shove_only_budges_a_metal_gate() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.DOWN
	var gate := _gate(almos, Vector2(0, 80), &"test/gate_budged")
	watch_signals(gate)
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(4)
	assert_signal_emit_count(gate, "budged", 1, "a Pull budges it")
	await wait_physics_frames(30)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_physics_frames(4)
	assert_signal_emit_count(gate, "budged", 2, "and a Shove")
	assert_false(gate.open, "it stays shut")


func test_a_thrown_flame_melts_a_metal_gate_open() -> void:
	var almos = _almos_input.spawn_almos()
	var gate := _gate(almos, Vector2(400, 0), &"test/gate_melted")
	await wait_physics_frames(2)
	var art := gate.get_node("Look/Art") as Sprite2D
	var foot := art.position.y + art.texture.get_size().y * art.scale.y / 2.0
	gate.flammable.ignite()
	await wait_physics_frames(30)
	assert_ne(art.modulate, Color.WHITE, "it glows as it melts")
	await wait_seconds((load(FIRE_PATH) as FireTuning).burn_time * 0.5)
	assert_gt(gate.melted(), 0, "it melts away from the top")
	assert_true(art.region_enabled, "only what is left of the bars is drawn")
	assert_almost_eq(art.position.y + art.region_rect.size.y * art.scale.y / 2.0, foot, 0.01, "their feet stand where they stood: it melts top to bottom")
	assert_almost_eq(art.scale, Vector2(2.0, 2.0), Vector2(0.01, 0.01), "not squashed from both ends")
	await wait_seconds((load(FIRE_PATH) as FireTuning).burn_time * 0.6)
	assert_true(gate.open, "melted open")


func test_touching_something_burning_does_not_melt_a_metal_gate() -> void:
	var almos = _almos_input.spawn_almos()
	var gate := _gate(almos, Vector2(400, 0), &"test/gate_touched")
	var jailer := _place(JAILER_SCENE, almos, Vector2(400, 20))
	await wait_physics_frames(2)
	(jailer.get_node("Flammable") as Flammable).ignite()
	await wait_seconds((load(FIRE_PATH) as FireTuning).spread_delay + 0.3)
	assert_false(gate.flammable.burning, "the gate does not catch")


# --- Fire by contact ---

func test_a_burning_guard_sets_alight_a_barrel_it_touches_and_not_one_apart() -> void:
	var almos = _almos_input.spawn_almos()
	var touching := _place(BARREL_SCENE, almos, Vector2(400, 0)) as HidingSpot
	var apart := _place(BARREL_SCENE, almos, Vector2(400, 120)) as HidingSpot
	var jailer := _place(JAILER_SCENE, almos, Vector2(400, 22))
	await wait_physics_frames(2)
	(jailer.get_node("Flammable") as Flammable).ignite()
	await wait_physics_frames(4)
	assert_false(touching.flammable.burning, "control: not at once")
	await wait_seconds((load(FIRE_PATH) as FireTuning).spread_delay + 0.2)
	assert_true(touching.flammable.burning, "the barrel it touches caught")
	assert_false(apart.flammable.burning, "the one apart from it did not")


func test_almos_catches_fire_from_a_burning_guard_he_touches_and_burns() -> void:
	var almos = _almos_input.spawn_almos()
	var jailer := _place(JAILER_SCENE, almos, Vector2(22, 0))
	await wait_physics_frames(2)
	(jailer.get_node("Flammable") as Flammable).ignite()
	await wait_seconds((load(FIRE_PATH) as FireTuning).spread_delay + 0.2)
	var on_fire := almos.get_node("Flammable") as Flammable
	assert_true(on_fire.burning, "he caught")
	jailer.global_position += Vector2(400, 0)
	var before: float = almos.health.current
	await wait_seconds((load(FIRE_PATH) as FireTuning).tick_interval * 2.0 + 0.1)
	assert_lt(almos.health.current, before, "his own Fire hurts him, away from the guard")
	almos.return_to(almos.global_position)
	assert_false(on_fire.burning, "returned, he is put out")


func test_almos_is_not_set_alight_by_a_fire_he_does_not_touch() -> void:
	var almos = _almos_input.spawn_almos()
	var barrel := _place(BARREL_SCENE, almos, Vector2(120, 0)) as HidingSpot
	await wait_physics_frames(2)
	barrel.flammable.ignite()
	await wait_seconds((load(FIRE_PATH) as FireTuning).spread_delay + 0.5)
	assert_false((almos.get_node("Flammable") as Flammable).burning, "not touching it, he does not catch")


# --- the guards' look ---

func test_the_guards_are_drawn_as_warders_of_their_own_not_as_almos() -> void:
	var guard := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/nar_jailer/idle_0.png"))
	var almos := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/almos/idle_side_0.png"))
	var same_shape := true
	var dx := (guard.get_width() - almos.get_width()) / 2
	var dy := 28 - almos.get_height()
	for y in almos.get_height():
		for x in almos.get_width():
			same_shape = same_shape and (almos.get_pixel(x, y).a > 0.0) == (guard.get_pixel(x + dx, y + dy).a > 0.0)
	assert_false(same_shape, "the guard has an outline of his own, not Almos's")
	# Standing on the foot row, as every 32x32 enemy frame does.
	var lowest := -1
	for y in guard.get_height():
		for x in guard.get_width():
			if guard.get_pixel(x, y).a > 0.0:
				lowest = y
	assert_eq(lowest, 27, "his feet on row 27")


# --- the hall and its cells ---

func test_the_hall_has_two_centred_cell_doors_big_rocks_and_no_wardrobes() -> void:
	var room := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	var doors: Array[float] = []
	for exit_node in room.get_node("Exits").get_children():
		if String(exit_node.name).begins_with("to_cell_"):
			doors.append((exit_node as Node2D).position.x)
	doors.sort()
	assert_eq(doors.size(), 2, "two cells")
	assert_almost_eq(doors[0] + doors[1], 1152.0, 0.01, "their doors centred about the middle of the hall")
	var rocks := 0
	for node in room.get_node("Furniture").get_children():
		assert_false(String(node.name).begins_with("Wardrobe"), "no wardrobe left")
		if node is BigRock:
			rocks += 1
	assert_gte(rocks, 3, "big rocks in their place")
	var gate := room.get_node("Cell2Gate") as MetalGate
	var door_2 := room.get_node("Exits/to_cell_2") as Node2D
	assert_almost_eq(gate.position.x, door_2.position.x, 0.01, "a metal gate shuts the other cell's doorway")
	assert_false(gate.open, "shut")


func test_both_cells_are_shut_by_metal_gates() -> void:
	var cell := (load("res://scenes/areas/dungeons/cell_3.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(cell)
	assert_true(cell.get_node_or_null("Gate") is MetalGate, "Cell 3, where he wakes, has a metal gate")
	assert_false(ResourceLoader.exists("res://scenes/areas/dungeons/cell_1.tscn"), "Cell 1 is gone")


func test_in_the_hall_everything_but_plants_and_big_rocks_can_be_lifted_and_thrown() -> void:
	var room := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	var kinds := {}
	var clusters := 0
	for node in room.get_node("Furniture").get_children():
		if node is BigRock:
			continue
		var liftable := node.get_node_or_null("Liftable")
		assert_not_null(liftable, "%s can be lifted and thrown" % node.name)
		if liftable != null:
			kinds[liftable.tuning.resource_path] = true
	assert_gte(kinds.size(), 8, "barrels, small rocks, skulls, bones, bone piles, pots, sacks, crates, a bench, a rack, buckets, a bowl")
	for node in room.get_node("Growth").get_children():
		assert_true(node is Sprite2D, "%s is a plant, only a look" % node.name)
		assert_null(node.get_node_or_null("Liftable"), "a plant cannot be lifted")
	# Barrels are kept together, in a row of stores, or stand alone where they are used.
	var barrels: Array[Vector2] = []
	for node in room.get_node("Furniture").get_children():
		if node.scene_file_path == "res://scenes/world/barrel.tscn":
			barrels.append((node as Node2D).position)
	for b in barrels:
		var near := barrels.filter(func(o: Vector2) -> bool: return o != b and o.distance_to(b) < 32.0)
		if near.size() == 2:
			clusters += 1
	assert_gte(clusters, 1, "barrels kept together in a row of stores")


func test_a_skull_is_lifted_and_thrown_and_a_thrown_pot_breaks() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var skull := _place(preload("res://scenes/world/skull.tscn"), almos, Vector2(50, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up())
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_eq(spell.held_object, skull.get_node("Liftable"), "he lifts the skull")
	await wait_seconds(0.3)
	await _tap(&"cast_spell")
	await wait_physics_frames(2)
	assert_eq(skull.get_node("Liftable").state, Liftable.State.FLYING, "and throws it")
	await wait_seconds(1.0)
	var pot := _place(preload("res://scenes/world/clay_pot.tscn"), almos, Vector2(50, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up())
	await wait_seconds(0.3)
	await _tap(&"cast_spell")
	await wait_seconds(1.2)
	assert_eq(pot.get_node("Liftable").state, Liftable.State.BROKEN, "a thrown pot breaks where it lands")


func test_the_guard_at_the_post_sits_until_he_is_in_pursuit() -> void:

	var room := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	var guard = room.get_node("Guards/PostGuard")
	var art := guard.get_node("Look/Art") as AnimatedSprite2D
	await wait_physics_frames(4)
	assert_true(guard.seated, "the guard at the post is seated")
	assert_true(guard.sitting(), "and sits, at rest")
	assert_eq(art.animation, &"sit", "drawn sitting")
	var bench := room.get_node("Furniture/BenchPost") as Node2D
	assert_lt(guard.global_position.distance_to(bench.global_position), 24.0, "on the bench")
	var almos = _almos_input.spawn_almos()
	almos.global_position = guard.global_position + Vector2(-200, 80)
	guard.target = almos
	guard.health.take_damage(1.0)
	await wait_physics_frames(4)
	assert_true(guard.in_pursuit, "control: hurt, he goes after Almos")
	assert_false(guard.sitting(), "on his feet")


# --- the hall teaches Pull and Shove ---

func test_the_hall_teaches_pull_and_shove_without_words() -> void:
	var room := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	assert_null(room.get_node_or_null("Lessons"), "no lessons spelt out: the hall teaches by its layout")
	assert_eq(room.find_children("*", "ThoughtSpot", true, false).size(), 0, "and no thought of his on the way")
	# The bridge down is shut by barrels he has to Pull away or Shove off.
	var barricade := []
	for node in room.get_node("Furniture").get_children():
		if String(node.name).begins_with("BarricadeBarrel"):
			barricade.append(node)
	assert_eq(barricade.size(), 2, "two barrels across the bridge")
	for barrel in barricade:
		assert_lt((barrel.get_node("Liftable").weight as float), (load("res://data/player_tuning.tres") as PlayerTuning).greatest_weight(), "light enough to Pull")
	# The walking guard keeps to the east half: the west is quiet ground to learn in.
	var guard = room.get_node("Guards/Guard")
	for point in guard.patrol:
		assert_gt(point.x, 640.0, "the walking guard stays east of the bridge")


# In tiles of 32 units: whether the tile is firm ground, outside every Drop of the hall.
func _hall_floor(room: Node2D, cell: Vector2i) -> bool:
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * 32.0
	for drop in room.get_node("Drops").get_children():
		var footprint := drop as Footprint
		if Rect2(footprint.position - footprint.size / 2.0, footprint.size).has_point(centre):
			return false
	return true


# Whether firm ground joins the lane (at Cell 3's door) to the hall's south exit, on foot, with the
# barricade standing, and with Jumps over one tile of chasm if `jumps` is set. A Jump cannot go over
# the barricade: barrels are solid in the air too.
func _reaches_the_south_exit(room: Node2D, barred: Array[Vector2i], jumps: bool) -> bool:
	var start := Vector2i(12, 2)
	var goal := Vector2i(18, 19)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			return true
		for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var steps: Array[Vector2i] = [cell + way]
			if jumps and not _hall_floor(room, cell + way) and not barred.has(cell + way):
				steps.append(cell + way * 2)
			for next in steps:
				if next.x < 0 or next.x >= 36 or next.y < 2 or next.y > 19 or seen.has(next):
					continue
				if not _hall_floor(room, next) or barred.has(next):
					continue
				seen[next] = true
				queue.append(next)
	return false


func test_a_second_way_down_loops_behind_the_barricade_over_a_gap_he_must_jump() -> void:
	var room := (load("res://scenes/areas/dungeons/corridor_1.tscn") as PackedScene).instantiate() as Node2D
	add_child_autofree(room)
	var barred: Array[Vector2i] = []
	for node in room.get_node("Furniture").get_children():
		if String(node.name).begins_with("BarricadeBarrel"):
			var cell := Vector2i(((node as Node2D).position / 32.0).floor())
			if not barred.has(cell):
				barred.append(cell)
	assert_eq(barred.size(), 2, "the barricade fills the neck of the bridge, two tiles across")
	assert_true(_reaches_the_south_exit(room, [], false), "control: with the barrels gone he walks down")
	assert_false(_reaches_the_south_exit(room, barred, false), "with them standing, no way down on foot")
	assert_true(_reaches_the_south_exit(room, barred, true), "but a Jump takes him round them")
	# The loop: a spur off the bridge above the barricade, down to a gap one tile across, and firm
	# ground beyond it that joins the bridge below the barricade.
	assert_true(_hall_floor(room, Vector2i(12, 10)), "the spur, west of the barricade")
	assert_false(_hall_floor(room, Vector2i(12, 11)), "the gap he jumps")
	assert_true(_hall_floor(room, Vector2i(12, 12)), "the landing beyond it")
	# A walking Jump clears the gap: one tile of chasm is less than a Jump carries him.
	var tuning := load("res://data/player_tuning.tres") as PlayerTuning
	var body_radius := 12.0
	assert_gt(tuning.walk_speed * tuning.jump_duration - body_radius, 32.0, "a Jump from a walk clears it")


func test_a_lesson_speaks_once_and_fades_by_itself() -> void:
	ThoughtSpot.forget_all()
	var almos = _almos_input.spawn_almos()
	var spot := (load("res://scenes/world/thought_spot.tscn") as PackedScene).instantiate() as ThoughtSpot
	spot.id = &"test_lesson"
	spot.lines = PackedStringArray(["A LESSON."])
	spot.stay = 0.5
	spot.position = almos.global_position + Vector2(200, 0)
	almos.get_parent().add_child(spot)
	autofree(spot)
	await wait_physics_frames(2)
	almos.global_position = spot.global_position
	await wait_physics_frames(4)
	assert_true(spot.spoken(), "walking into it, he thinks it")
	assert_not_null(spot.find_children("*", "Control", true, false).front() if not spot.find_children("*", "Control", true, false).is_empty() else null, "it shows")
	await wait_seconds(2.0)
	assert_true(spot.find_children("*", "Control", true, false).is_empty(), "and fades by itself")
