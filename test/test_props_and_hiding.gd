extends GutTest
## The props Almos can hide in and move, and the enemies' Health bars:
## - a hidden Almos is not drawn at all, and the spot he is in rattles now and then; wardrobes and
##   barrels are solid, and he steps out in front of them;
## - Pull lifts a barrel over his head and Shove throws it into an enemy, hurting it; a Shove knocks
##   a barrel from the floor; a wardrobe is too heavy for him yet and only shudders; a loss of Health
##   puts down what he holds; a thrown barrel breaks apart and is whole again when enemies return;
##   Pull takes the nearest thing all round him;
## - an enemy's Health bar shows once it is hurt or in Pursuit, with a trail where a loss took it.
## Numbers come from the data files.

const AlmosInput := preload("res://test/helpers/almos_input.gd")
const BARREL_SCENE := preload("res://scenes/world/barrel.tscn")
const WARDROBE_SCENE := preload("res://scenes/world/wardrobe.tscn")
const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const SPELL_PATH := "res://data/fireball.tres"
const THROW_PATH := "res://data/throw.tres"
const TAP_FRAMES := 2
const MARGIN_FRAMES := 6
const WALLS_LAYER := 1

var _almos_input: AlmosInput


func before_each() -> void:
	_almos_input = AlmosInput.new(self)


func after_each() -> void:
	_almos_input.release_everything()


func _tap(action: StringName) -> void:
	_almos_input.press_action(action)
	await wait_physics_frames(TAP_FRAMES)
	_almos_input.release_action(action)


# Placed before it is added, so that its body never lands on Almos for a frame and shoves him.
func _place(scene: PackedScene, almos: Node2D, offset: Vector2) -> Node2D:
	var node := scene.instantiate() as Node2D
	node.position = almos.global_position + offset
	almos.get_parent().add_child(node)
	autofree(node)
	return node


func _wind_up_frames() -> int:
	return (load(SPELL_PATH) as SpellData).wind_up_frames + MARGIN_FRAMES


# --- Hiding ---

func test_hidden_almos_is_not_drawn_and_the_wardrobe_rattles_now_and_then() -> void:
	var almos = _almos_input.spawn_almos()
	var wardrobe := _place(WARDROBE_SCENE, almos, Vector2(0, -20)) as HidingSpot
	await wait_physics_frames(2)
	await _tap(&"interact")
	await wait_physics_frames(2)
	assert_true(almos.hiding, "he is in the wardrobe")
	assert_eq((almos.get_node("Look") as CanvasItem).modulate.a, 0.0, "nothing of him is drawn")
	assert_false((almos.get_node("CarriedTorch") as CanvasItem).visible, "nor a torch he carries")
	assert_true(wardrobe.occupied(), "the wardrobe knows it is occupied")
	var rattled := false
	for i in 300:
		await wait_physics_frames(1)
		rattled = rattled or wardrobe.rattling()
	assert_true(rattled, "it rattles within a few seconds")


func test_an_empty_spot_does_not_rattle() -> void:
	var almos = _almos_input.spawn_almos()
	var wardrobe := _place(WARDROBE_SCENE, almos, Vector2(200, 0)) as HidingSpot
	var rattled := false
	for i in 300:
		await wait_physics_frames(1)
		rattled = rattled or wardrobe.rattling()
	assert_false(rattled, "nobody inside, no rattle")


func test_wardrobes_and_barrels_are_solid_and_he_steps_out_in_front() -> void:
	var almos = _almos_input.spawn_almos()
	for scene in [WARDROBE_SCENE, BARREL_SCENE]:
		var spot := scene.instantiate() as HidingSpot
		autofree(spot)
		var body := spot.get_node_or_null("Body") as StaticBody2D
		assert_not_null(body, "%s has a body" % spot.name)
		assert_ne(body.collision_layer & WALLS_LAYER, 0, "%s blocks like a wall" % spot.name)
		assert_gt(spot.exit_offset.y, 0.0, "%s lets him out in front" % spot.name)
	var wardrobe := _place(WARDROBE_SCENE, almos, Vector2(0, -20)) as HidingSpot
	await wait_physics_frames(2)
	await _tap(&"interact")
	await wait_physics_frames(2)
	await _tap(&"interact")
	await wait_physics_frames(2)
	assert_false(almos.hiding, "he is out")
	assert_almost_eq(almos.global_position, wardrobe.global_position + wardrobe.exit_offset, Vector2.ONE * 1.0, "standing in front of it")
	assert_eq((almos.get_node("Look") as CanvasItem).modulate.a, 1.0, "drawn again")


# --- Lifting and throwing ---

func test_pull_lifts_a_barrel_over_his_head() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(70, 0))
	var lift := barrel.get_node("Liftable")
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_true(spell.holding, "he holds it")
	assert_eq(spell.held_object, lift, "the barrel")
	assert_false(spell.holding_flame, "not a flame")
	assert_eq(spell.selected, AlmosSpell.Spell.SHOVE, "Shove is ready to throw it")
	assert_false(barrel.is_in_group(&"hiding_spots"), "held, it is no hiding spot")
	assert_eq((barrel.get_node("Body") as StaticBody2D).collision_layer, 0, "nor does it block")
	await wait_seconds((load(THROW_PATH) as ThrowTuning).lift_time + 0.1)
	assert_lt(barrel.global_position.y, almos.global_position.y - 20.0, "it floats over his head")
	assert_almost_eq(barrel.global_position.x, almos.global_position.x, 1.0, "right over him")


func test_shove_throws_the_held_barrel_into_an_enemy_and_hurts_it() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(70, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	await wait_seconds(0.3)
	var jailer := _place(JAILER_SCENE, almos, Vector2(160, 0))
	jailer.target = almos
	await wait_physics_frames(2)
	var before: float = jailer.get_node("Health").current
	almos.facing = Vector2.RIGHT
	await _tap(&"cast_spell")
	var lift := barrel.get_node("Liftable")
	var flew := false
	for i in 90:
		await wait_physics_frames(1)
		flew = flew or lift.state == Liftable.State.FLYING
		if flew and lift.state != Liftable.State.FLYING:
			break
	assert_true(flew, "the barrel flew")
	assert_eq(lift.state, Liftable.State.BROKEN, "and broke on the jailer")
	assert_almost_eq(jailer.get_node("Health").current, before - lift.tuning.damage, 0.01, "it hurt the jailer for its damage")
	assert_false((almos.get_node("Spell") as AlmosSpell).holding, "he holds nothing")


func test_a_thrown_barrel_breaks_apart_and_is_whole_again_when_enemies_return() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(70, 0)) as HidingSpot
	var home := barrel.global_position
	var lift := barrel.get_node("Liftable")
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	await wait_seconds(0.3)
	watch_signals(lift)
	await _tap(&"cast_spell")
	for i in 120:
		await wait_physics_frames(1)
		if lift.state == Liftable.State.BROKEN:
			break
	assert_signal_emitted(lift, "broke", "it broke where it came down")
	assert_eq(lift.state, Liftable.State.BROKEN, "and stays broken")
	assert_true(barrel.flammable.burnt_out, "gone, as a burnt-out thing is")
	assert_false((barrel.get_node("Look") as CanvasItem).visible, "nothing of it shows")
	assert_false(barrel.is_in_group(&"hiding_spots"), "it cannot be hidden in")
	assert_eq((barrel.get_node("Body") as StaticBody2D).collision_layer, 0, "nor does it block")
	assert_false(lift.can_be_moved(), "nor be lifted")
	var pieces := false
	for child in barrel.get_parent().get_children():
		pieces = pieces or child.get_script() == preload("res://scenes/world/prop_break.gd")
	assert_true(pieces, "its pieces fly apart")
	barrel.flammable.come_back()
	await wait_physics_frames(2)
	assert_eq(lift.state, Liftable.State.RESTING, "enemies return: it is whole")
	assert_eq(barrel.global_position, home, "where it first stood")
	assert_true(barrel.is_in_group(&"hiding_spots"), "a hiding spot again")
	assert_ne((barrel.get_node("Body") as StaticBody2D).collision_layer, 0, "and blocks again")


func test_a_burnt_out_barrel_blocks_nothing() -> void:
	var almos = _almos_input.spawn_almos()
	var barrel := _place(BARREL_SCENE, almos, Vector2(200, 0)) as HidingSpot
	await wait_physics_frames(2)
	barrel.flammable.burn_out_now()
	assert_eq((barrel.get_node("Body") as StaticBody2D).collision_layer, 0, "burnt out, it blocks nothing")
	barrel.flammable.come_back()
	assert_ne((barrel.get_node("Body") as StaticBody2D).collision_layer, 0, "whole again, it blocks")


func test_a_shove_knocks_a_barrel_from_the_floor_into_an_enemy() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(60, 0))
	var jailer := _place(JAILER_SCENE, almos, Vector2(150, 0))
	jailer.target = almos
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	assert_eq((almos.get_node("Spell") as AlmosSpell).selected, AlmosSpell.Spell.SHOVE, "control: Shove selected")
	var before: float = jailer.get_node("Health").current
	await _tap(&"cast_spell")
	await wait_physics_frames(60)
	assert_lt(jailer.get_node("Health").current, before, "the knocked barrel hurt the jailer")


func test_a_knocked_barrel_that_hits_nothing_comes_to_rest_whole() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(60, 0))
	var lift := barrel.get_node("Liftable")
	await wait_physics_frames(2)
	await _tap(&"switch_spell")
	await _tap(&"cast_spell")
	await wait_physics_frames(60)
	assert_eq(lift.state, Liftable.State.RESTING, "it skidded to a stop, whole")
	assert_true(barrel.is_in_group(&"hiding_spots"), "a hiding spot still")


func test_pull_takes_the_nearest_thing_all_round_him_not_only_ahead() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var near := _place(BARREL_SCENE, almos, Vector2(-60, 0))
	var far := _place(BARREL_SCENE, almos, Vector2(120, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_eq(spell.held_object, near.get_node("Liftable"), "the barrel behind him, being nearer")
	assert_eq(far.get_node("Liftable").state, Liftable.State.RESTING, "not the one ahead")


func test_pull_takes_a_nearer_barrel_before_a_torch_further_off() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(0, 40))
	var torch := _place(preload("res://scenes/world/torch.tscn"), almos, Vector2(-100, 0))
	await wait_physics_frames(2)
	assert_true(torch.lit, "control: the torch burns")
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_eq(spell.held_object, barrel.get_node("Liftable"), "he lifted the nearer barrel")
	assert_true(torch.lit, "and left the torch alight")


func test_a_wardrobe_is_too_heavy_for_him_and_only_shudders() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var wardrobe := _place(WARDROBE_SCENE, almos, Vector2(70, 0))
	var lift := wardrobe.get_node("Liftable")
	var tuning := load("res://data/player_tuning.tres") as PlayerTuning
	assert_gt(lift.weight, tuning.greatest_weight(), "a wardrobe weighs more than he can move yet")
	assert_lt((load("res://data/barrel_lift.tres") as LiftTuning).weight, tuning.greatest_weight(), "a barrel he can")
	await wait_physics_frames(2)
	watch_signals(lift)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	assert_signal_emitted(lift, "shuddered", "it shuddered")
	assert_false((almos.get_node("Spell") as AlmosSpell).holding, "he holds nothing")
	assert_true(wardrobe.is_in_group(&"hiding_spots"), "it stays where it is, a hiding spot")


func test_a_loss_of_health_puts_down_what_he_holds() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	var barrel := _place(BARREL_SCENE, almos, Vector2(70, 0))
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(_wind_up_frames())
	var spell := almos.get_node("Spell") as AlmosSpell
	assert_true(spell.holding, "control: he holds it")
	almos.health.take_damage(5.0)
	await wait_physics_frames(2)
	assert_false(spell.holding, "he put it down")
	assert_true(barrel.is_in_group(&"hiding_spots"), "it is a prop on the floor again")


func test_almos_holds_his_wind_up_pose_while_gripping_and_strikes_as_he_throws() -> void:
	var almos = _almos_input.spawn_almos()
	almos.facing = Vector2.RIGHT
	_place(BARREL_SCENE, almos, Vector2(70, 0))
	var art := almos.get_node("Look/Art") as AnimatedSprite2D
	await wait_physics_frames(2)
	await _tap(&"cast_spell")
	await wait_physics_frames(3)
	assert_eq(art.animation, &"attack_side", "gripping, he is in his wind-up pose")
	assert_eq(art.frame, AlmosLook.COIL, "coiled")
	await wait_physics_frames(_wind_up_frames())
	await _tap(&"cast_spell")
	await wait_physics_frames(1)
	assert_eq(art.frame, AlmosLook.STRIKE, "throwing, he strikes")


# --- Enemy Health bars ---

func test_an_enemys_health_bar_shows_once_it_is_hurt_with_a_trail() -> void:
	var almos = _almos_input.spawn_almos()
	var jailer := _place(JAILER_SCENE, almos, Vector2(-3000, 0))
	jailer.target = almos
	var bar := jailer.get_node("OverheadHealthBar") as EnemyHealthBar
	await wait_physics_frames(2)
	assert_false(bar.showing(), "whole and at rest, no bar")
	var health := jailer.get_node("Health") as Health
	health.take_damage(health.maximum * 0.25)
	await wait_physics_frames(2)
	assert_true(bar.showing(), "hurt, the bar shows")
	assert_almost_eq(bar.trail_share(), 1.0, 0.01, "the trail holds where the bar was")
	await wait_seconds(EnemyHealthBar.TRAIL_HOLD + 2.0)
	# It drains down to the bar (which a jailer at rest slowly refills, so not to a fixed share).
	assert_almost_eq(bar.trail_share(), health.current / health.maximum, 0.01, "then drains to the bar")
	assert_lt(bar.trail_share(), 1.0, "having come down from where it was")


func test_a_shove_knocks_a_light_prop_further_than_a_heavy_one() -> void:
	var throw := load("res://data/throw.tres") as ThrowTuning
	var barrel := (load("res://data/barrel_lift.tres") as LiftTuning).weight
	var bowl := (load("res://data/bowl_lift.tres") as LiftTuning).weight
	var bench := (load("res://data/bench_lift.tres") as LiftTuning).weight
	assert_almost_eq(throw.knock_range_for(barrel), throw.knock_range, 0.01, "a barrel goes the knock range")
	assert_gt(throw.knock_range_for(bowl), throw.knock_range_for(barrel), "a bowl further")
	assert_lt(throw.knock_range_for(bench), throw.knock_range_for(barrel), "a bench less far")
	assert_almost_eq(throw.knock_range_for(0.5), throw.knock_range * throw.knock_scale_max, 0.01, "never more than the most")
	assert_almost_eq(throw.knock_range_for(1000.0), throw.knock_range * throw.knock_scale_min, 0.01, "never less than the least")
