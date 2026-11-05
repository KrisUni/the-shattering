extends GutTest
## The opening of a played game and the feedback of Almos's Spells:
## - in the played Dungeons he wakes on the bed in Cell 3 and gets up, held still, then a thought
##   shows until a press takes it away, and only then is he free; a press while it is still typing
##   shows it all first. Hosted the way the tests host the Dungeons, he starts free as before;
## - Cell 3's lamp hangs on its north wall, and the cell has a bed;
## - the HUD's Spell icon shows Pull, and Shove once the switch button (V) is tapped;
## - every press of Pull or Shove on ordinary things sends a wave of energy, whether it moves
##   anything or not, and a Pull for a flame does not;
## - a wardrobe too heavy to move visibly shudders at a Pull or a Shove, leaning toward him or away.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const PullReach := preload("res://test/helpers/pull_reach.gd")
const PLAY_PATH := "res://scenes/areas/play_dungeons.tscn"
const WORLD_PATH := "res://scenes/areas/test_world.tscn"
const DUNGEONS_PATH := "res://scenes/areas/dungeons/dungeons.tscn"
const CELL_3_PATH := "res://scenes/areas/dungeons/cell_3.tscn"
const BARREL_SCENE := preload("res://scenes/world/barrel.tscn")
const WARDROBE_SCENE := preload("res://scenes/world/wardrobe.tscn")
const TORCH_SCENE := preload("res://scenes/world/torch.tscn")
const ICON_SCRIPT := preload("res://scenes/hud/spell_icon.gd")
const THOUGHT_SCRIPT := preload("res://scenes/hud/thought_text.gd")
const WAVE_SCRIPT := preload("res://scenes/almos/spell_wave.gd")
const SPELL_PATH := "res://data/fireball.tres"
const TAP_FRAMES := 2
const MARGIN_FRAMES := 6

var _almos_input: AlmosInput
var _waves: Array = []


func before_each() -> void:
	WorldState.reset()
	await get_tree().process_frame
	_almos_input = AlmosInput.new(self)
	_waves = []


func after_each() -> void:
	_almos_input.release_everything()
	WorldState.reset()


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


func _key_press() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event


func _place(scene: PackedScene, almos: Node2D, offset: Vector2) -> Node2D:
	var node := scene.instantiate() as Node2D
	node.position = almos.global_position + offset
	almos.get_parent().add_child(node)
	autofree(node)
	return node


func _watch_waves(almos: Node) -> void:
	(almos.get_node("Spell") as AlmosSpell).wave_sent.connect(func(pulling: bool, target: Node2D) -> void: _waves.append([pulling, target]))


# --- the opening ---

func _played_dungeons() -> AreaHost:
	var host := (load(PLAY_PATH) as PackedScene).instantiate() as AreaHost
	add_child_autofree(host)
	return host


func test_in_the_played_dungeons_he_wakes_on_the_bed_held_still() -> void:
	var host := _played_dungeons()
	await wait_physics_frames(2)
	var opening := host.get_node("Opening")
	var cell := (host.current_space as DungeonsBuilding).room(&"cell_3")
	var bed := cell.get_node("Bed") as Node2D
	assert_eq(opening.stage, opening.Stage.ASLEEP, "he is asleep")
	assert_almost_eq(host.almos.global_position, (bed.get_node("WakeSpot") as Node2D).global_position, Vector2.ONE * 2.0, "on the bed")
	assert_false(host.almos.is_physics_processing(), "held still")
	assert_almost_eq((host.almos.get_node("Look/Art") as Node2D).rotation, -PI / 2.0, 0.2, "lying on his side")


func test_he_gets_up_then_thinks_and_a_press_lets_him_go() -> void:
	var host := _played_dungeons()
	await wait_physics_frames(2)
	var opening := host.get_node("Opening")
	await wait_seconds(opening.sleep_time + opening.stir_time + opening.get_up_time + 0.2)
	assert_eq(opening.stage, opening.Stage.THINKING, "he is up and thinking")
	var cell := (host.current_space as DungeonsBuilding).room(&"cell_3")
	assert_almost_eq(host.almos.global_position, (cell.get_node("Bed/GetUpSpot") as Node2D).global_position, Vector2.ONE * 2.0, "standing in front of the bed")
	assert_almost_eq((host.almos.get_node("Look/Art") as Node2D).rotation, 0.0, 0.001, "upright")
	assert_false(host.almos.is_physics_processing(), "still held while the thought is up")
	var thought := _find_thought(opening)
	assert_not_null(thought, "the thought shows")
	await wait_seconds(2.0)
	assert_true(thought.all_shown(), "typed out in full")
	thought._input(_key_press())
	await wait_physics_frames(4)
	assert_eq(opening.stage, opening.Stage.DONE, "the press took it away")
	assert_true(host.almos.is_physics_processing(), "and he is free to move")


func test_a_press_while_he_wakes_skips_to_the_thought() -> void:
	var host := _played_dungeons()
	await wait_physics_frames(2)
	var opening := host.get_node("Opening")
	opening._input(_key_press())
	await wait_physics_frames(1)
	assert_eq(opening.stage, opening.Stage.THINKING, "skipped to him standing, thinking")


func test_hosted_as_the_tests_host_it_he_starts_free() -> void:
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	add_child_autofree(host)
	await wait_physics_frames(2)
	assert_true(host.almos.is_physics_processing(), "no opening: he is free")


func test_a_press_while_the_thought_types_shows_it_all_first() -> void:
	var text: Control = THOUGHT_SCRIPT.new()
	text.lines = PackedStringArray(["A FAIRLY LONG LINE OF THOUGHT", "AND ANOTHER"])
	add_child_autofree(text)
	watch_signals(text)
	await wait_physics_frames(2)
	assert_false(text.all_shown(), "control: still typing")
	text._input(_key_press())
	assert_true(text.all_shown(), "the press shows it all")
	assert_signal_not_emitted(text, "dismissed", "and does not take it away yet")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	text._input(click)
	assert_signal_emitted(text, "dismissed", "a click takes it away")


# --- Cell 3 ---

func test_cell_3s_lamps_hang_on_its_side_walls_and_it_has_a_bed() -> void:
	var cell := (load(CELL_3_PATH) as PackedScene).instantiate() as Node2D
	add_child_autofree(cell)
	for side in [["LampLeft", "Walls/CellWallLeft", 1.0], ["LampRight", "Walls/CellWallRight", -1.0]]:
		var torch := cell.get_node(side[0]) as Torch
		var wall := cell.get_node(side[1]) as Node2D
		var inner_edge: float = wall.position.x + 16.0 * side[2]
		assert_between((torch.position.x - inner_edge) * side[2], 0.0, 16.0, "%s hangs off its side wall" % side[0])
	assert_true(cell.get_node("Bed") is StaticBody2D, "a bed, solid")
	assert_not_null(cell.get_node_or_null("Bed/WakeSpot"), "where he lies")
	assert_not_null(cell.get_node_or_null("Bed/GetUpSpot"), "where he stands up")


# --- the HUD icon ---

func test_the_spell_icon_shows_pull_and_shove_after_a_switch() -> void:
	var almos = _almos_input.spawn_almos()
	var icon: Control = ICON_SCRIPT.new()
	icon.spell = almos.get_node("Spell")
	add_child_autofree(icon)
	await wait_physics_frames(2)
	assert_true(icon.showing_pull(), "Pull at the start")
	await _tap(&"switch_spell")
	assert_false(icon.showing_pull(), "Shove after V")
	await _tap(&"switch_spell")
	assert_true(icon.showing_pull(), "Pull again")


func test_the_switch_button_is_v() -> void:
	var v := false
	for event in InputMap.action_get_events(&"switch_spell"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_V:
			v = true
	assert_true(v, "V switches the Spell")


func test_the_dungeons_hud_has_the_spell_icon_by_the_health_bar() -> void:
	var host := (load(WORLD_PATH) as PackedScene).instantiate() as AreaHost
	host.start = DUNGEONS_PATH
	add_child_autofree(host)
	await wait_physics_frames(2)
	var icon := host.current_space.get_node_or_null("Hud/SpellIcon") as Control
	assert_not_null(icon, "a Spell icon on the HUD")
	var bar := host.current_space.get_node("Hud/HealthBar") as Control
	assert_lt(absf(icon.position.x - (bar.position.x + bar.size.x)), 12.0, "right by the Health bar")


# --- the waves ---

func test_a_pull_with_nothing_in_reach_sends_a_wave_and_spends_nothing() -> void:
	var almos = _almos_input.spawn_almos()
	_watch_waves(almos)
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(2)
	assert_eq(_waves.size(), 1, "one wave")
	assert_true(_waves[0][0], "a Pull's")
	assert_null(_waves[0][1], "landing on nothing")
	assert_eq(almos.health.current, almos.health.maximum, "nothing spent")
	var drawn := false
	for child in almos.get_parent().get_children():
		drawn = drawn or child.get_script() == WAVE_SCRIPT
	assert_true(drawn, "and it is drawn")


func test_a_shove_with_nothing_in_reach_sends_a_wave_too() -> void:
	var almos = _almos_input.spawn_almos()
	_watch_waves(almos)
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_physics_frames(2)
	assert_eq(_waves.size(), 1, "one wave")
	assert_false(_waves[0][0], "a Shove's")


func test_a_pull_on_a_barrel_sends_a_wave_that_lands_on_it() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(70, 0))
	_watch_waves(almos)
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(2)
	assert_eq(_waves.size(), 1, "one wave")
	assert_eq(_waves[0][1], barrel, "landing on the barrel")


func test_a_pull_for_a_flame_sends_no_wave() -> void:
	var almos = _almos_input.spawn_almos()
	_place(TORCH_SCENE, almos, Vector2(40, 0))
	_watch_waves(almos)
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames((load(SPELL_PATH) as SpellData).wind_up_frames + MARGIN_FRAMES)
	assert_true((almos.get_node("Spell") as AlmosSpell).holding_flame, "control: he took the flame")
	assert_eq(_waves.size(), 0, "the flame has its own look, no wave")


# --- the wardrobe ---

func test_a_wardrobe_visibly_shudders_toward_him_at_a_pull() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var wardrobe := _place(WARDROBE_SCENE, almos, Vector2(80, 0))
	var look := wardrobe.get_node("Look") as Node2D
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	var moved := false
	var leaned_toward := false
	for i in 12:
		await wait_physics_frames(1)
		moved = moved or look.position != Vector2.ZERO
		leaned_toward = leaned_toward or look.position.x < -2.0
	assert_true(moved, "its look shakes")
	assert_true(leaned_toward, "leaning toward him, who is to its left")
	await wait_physics_frames(30)
	assert_eq(look.position, Vector2.ZERO, "and it settles where it stands")


func test_a_wardrobe_leans_away_at_a_shove() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var wardrobe := _place(WARDROBE_SCENE, almos, Vector2(80, 0))
	var look := wardrobe.get_node("Look") as Node2D
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	var leaned_away := false
	for i in 12:
		await wait_physics_frames(1)
		leaned_away = leaned_away or look.position.x > 2.0
	assert_true(leaned_away, "leaning away from him")


func _find_thought(opening: Node) -> Control:
	for node in opening.find_children("*", "Control", true, false):
		if node.get_script() == THOUGHT_SCRIPT:
			return node as Control
	return null
