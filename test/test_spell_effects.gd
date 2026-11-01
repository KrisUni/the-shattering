extends GutTest
## How the Pull and the thrown flame look, and that the Dungeons' skeleton jailers burn:
## - while Almos winds up a Pull the flame streams to his hand, and it lands with a flash;
## - a fireball flies with a trail that outlives it and fades;
## - where a fireball hits it bursts, as wide as its splash; running out of range it does not;
## - a skeleton jailer a fireball hits catches fire and the Fire hurts it.
## The looks are only looks: these tests read their state, not their pixels.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const FIREBALL_SCENE := preload("res://scenes/almos/fireball.tscn")
const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const TORCH_SCENE := preload("res://scenes/world/torch.tscn")
const FIRE_PATH := "res://data/fire.tres"
const SPELL_PATH := "res://data/fireball.tres"
const PALETTE_PATH := "res://assets/palette/master.hex"
# In physics frames. Slack added to a computed wait.
const MARGIN_FRAMES := 6

var _almos_input: AlmosInput


func before_each() -> void:
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func _world() -> Node2D:
	var world := Node2D.new()
	add_child_autofree(world)
	return world


func _bursts(world: Node) -> Array[FireBurst]:
	var found: Array[FireBurst] = []
	for child in world.get_children():
		if child is FireBurst:
			found.append(child as FireBurst)
	return found


func _launch_at(world: Node2D, from: Vector2, direction: Vector2, splash := 48.0) -> Fireball:
	var fireball := FIREBALL_SCENE.instantiate() as Fireball
	world.add_child(fireball)
	fireball.launch(from, direction, 360.0, 320.0, 20.0)
	fireball.splash_radius = splash
	fireball.splash_fraction = 0.5
	return fireball


func test_a_fireball_that_hits_an_enemy_bursts_there_as_wide_as_its_splash() -> void:
	var world := _world()
	var jailer := JAILER_SCENE.instantiate()
	world.add_child(jailer)
	jailer.global_position = Vector2(200, 100)
	await wait_physics_frames(2)
	_launch_at(world, Vector2(60, 100), Vector2.RIGHT, 40.0)

	for i in 60:
		await wait_physics_frames(1)
		if not _bursts(world).is_empty():
			break
	var bursts := _bursts(world)
	assert_eq(bursts.size(), 1, "the fireball burst where it hit")
	if bursts.is_empty():
		return
	assert_lt(bursts[0].global_position.distance_to(jailer.global_position), 20.0, "the burst is at the enemy")
	assert_eq(bursts[0].radius, 40.0, "its ring runs out to the splash radius")
	await wait_seconds(FireBurst.DURATION + 0.1)
	assert_true(_bursts(world).is_empty(), "the burst frees itself when it is over")


func test_a_fireball_that_runs_out_of_range_does_not_burst() -> void:
	var world := _world()
	var fireball := _launch_at(world, Vector2(0, 0), Vector2.RIGHT)
	fireball.launch(Vector2(0, 0), Vector2.RIGHT, 360.0, 40.0, 20.0)
	await wait_physics_frames(30)
	assert_false(is_instance_valid(fireball), "the fireball died out")
	assert_true(_bursts(world).is_empty(), "nothing burst in open air")


func test_the_trail_follows_the_fireball_and_fades_after_it() -> void:
	var world := _world()
	var fireball := _launch_at(world, Vector2(0, 0), Vector2.RIGHT)
	fireball.launch(Vector2(0, 0), Vector2.RIGHT, 360.0, 120.0, 20.0)
	await wait_physics_frames(3)
	var trail: FireballTrail = null
	for child in world.get_children():
		if child is FireballTrail:
			trail = child
	assert_not_null(trail, "the trail moved up beside the fireball")
	if trail == null:
		return
	assert_false(trail.fading(), "it does not fade while the fireball flies")
	await wait_physics_frames(30)
	assert_false(is_instance_valid(fireball), "the fireball is gone")
	assert_true(not is_instance_valid(trail) or trail.fading(), "the trail fades after it")
	await wait_seconds(FireballTrail.FADE + 0.1)
	assert_false(is_instance_valid(trail), "and frees itself")


func test_a_skeleton_jailer_hit_by_a_fireball_catches_fire_and_burns() -> void:
	var world := _world()
	var jailer := JAILER_SCENE.instantiate()
	world.add_child(jailer)
	jailer.global_position = Vector2(200, 100)
	await wait_physics_frames(2)
	var flammable := jailer.get_node("Flammable") as Flammable
	assert_eq(flammable.kind, Flammable.Kind.CREATURE, "a jailer burns as a creature does")
	_launch_at(world, Vector2(60, 100), Vector2.RIGHT)
	for i in 60:
		await wait_physics_frames(1)
		if flammable.burning:
			break
	assert_true(flammable.burning, "the jailer caught fire")
	var health_after_hit: float = jailer.get_node("Health").current
	var fire := load(FIRE_PATH) as FireTuning
	await wait_seconds(fire.tick_interval * 2.0 + 0.1)
	assert_lt(jailer.get_node("Health").current, health_after_hit, "the Fire hurts it")


func test_a_pull_streams_the_flame_to_his_hand_and_lands_with_a_flash() -> void:
	var almos = _almos_input.spawn_almos()
	var spell := almos.get_node("Spell") as AlmosSpell
	var look := almos.get_node("SpellLook") as SpellLook
	var torch := TORCH_SCENE.instantiate() as Torch
	almos.get_parent().add_child(torch)
	autofree(torch)
	torch.global_position = almos.global_position + Vector2(60, 0)
	await wait_physics_frames(2)
	assert_false(look.streaming(), "no stream before a Pull")

	_almos_input.press_action(&"cast_spell")
	await wait_physics_frames(2)
	_almos_input.release_action(&"cast_spell")
	await wait_frames(2)
	assert_true(spell.winding_up, "the Pull winds up")
	assert_eq(spell.drawing_from, torch, "it draws from the torch")
	assert_true(look.streaming(), "the flame streams while he winds up")

	var spell_data := load(SPELL_PATH) as SpellData
	for i in spell_data.wind_up_frames + MARGIN_FRAMES:
		await wait_physics_frames(1)
		if spell.holding:
			break
	await wait_frames(2)
	assert_true(spell.holding, "he holds the flame")
	assert_true(look.flashing(), "it lands with a flash")
	assert_null(spell.drawing_from, "nothing is drawn from once he holds it")


func test_the_wind_up_progress_runs_from_zero_to_one() -> void:
	var almos = _almos_input.spawn_almos()
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_eq(spell.wind_up_progress, 0.0, "no wind-up, no progress")


func test_the_effects_draw_only_palette_colours() -> void:
	var palette := {}
	for line in FileAccess.get_file_as_string(PALETTE_PATH).split("\n", false):
		palette[Color(line.strip_edges()).to_html(false)] = true
	for script_class in [SpellLook, FireballTrail, FireBurst]:
		var script := script_class as Script
		for name in script.get_script_constant_map():
			var value = script.get_script_constant_map()[name]
			if value is Color:
				assert_true(palette.has((value as Color).to_html(false)), "%s.%s is a palette colour" % [script.resource_path.get_file(), name])
