extends GutTest
## A jailer shows what happens to it, for a moment each, on its sprite: it flinches when a blow costs
## it Health, jerks into guard as it notices Almos, gets up from its seat, and glances round while a
## patrol pauses. When it dies it is gone at once, but its body is left as a look: it falls, lies a
## moment and fades away. The knight breathes slow and deep in his sleep and gets up heavily.

const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const KNIGHT_SCENE := preload("res://scenes/enemies/nar_knight.tscn")


func _art(enemy: Node) -> AnimatedSprite2D:
	return enemy.get_node("Look/Art") as AnimatedSprite2D


func test_they_have_every_new_moment() -> void:
	for scene in [JAILER_SCENE, KNIGHT_SCENE]:
		var enemy: Node = (scene as PackedScene).instantiate()
		add_child_autofree(enemy)
		var frames := _art(enemy).sprite_frames
		for name in [&"hurt", &"look", &"startle", &"rise"]:
			assert_true(frames.has_animation(name), "%s has %s" % [enemy.name, name])
	var jailer := JAILER_SCENE.instantiate()
	add_child_autofree(jailer)
	assert_eq(_art(jailer).sprite_frames.get_frame_count(&"sit"), 4, "the jailer breathes as he sits")
	var knight := KNIGHT_SCENE.instantiate()
	add_child_autofree(knight)
	assert_eq(_art(knight).sprite_frames.get_frame_count(&"sleep"), 6, "the knight breathes slow and deep asleep")


func test_a_blow_that_costs_health_makes_it_flinch() -> void:
	var jailer := JAILER_SCENE.instantiate()
	add_child_autofree(jailer)
	await wait_physics_frames(2)
	(jailer.get_node("Health") as Health).take_damage(1.0)
	await wait_physics_frames(2)
	assert_eq(_art(jailer).animation, &"hurt", "it flinches")
	await wait_physics_frames(20)
	assert_ne(_art(jailer).animation, &"hurt", "and gathers itself")


func test_a_patrol_pausing_at_a_point_glances_round() -> void:
	var jailer := JAILER_SCENE.instantiate()
	jailer.patrol = PackedVector2Array([Vector2(0, 0), Vector2(40, 0)])
	add_child_autofree(jailer)
	var looked := false
	for i in 240:
		await wait_physics_frames(1)
		if _art(jailer).animation == &"look":
			looked = true
			break
	assert_true(looked, "it glances round as it pauses")


func test_dying_it_leaves_its_body_falling_and_fading() -> void:
	var holder := Node2D.new()
	add_child_autofree(holder)
	var jailer := JAILER_SCENE.instantiate()
	holder.add_child(jailer)
	await wait_physics_frames(2)
	(jailer.get_node("Health") as Health).take_damage(10000.0)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(jailer) and jailer.is_inside_tree(), "the jailer itself is gone at once")
	var bodies := holder.get_children().filter(func(node: Node) -> bool: return node is AnimatedSprite2D)
	assert_eq(bodies.size(), 1, "its body is left behind")
	if bodies.is_empty():
		return
	var body := bodies[0] as AnimatedSprite2D
	assert_eq(body.animation, &"death", "falling as it dies")
	await wait_seconds(3.0)
	assert_false(is_instance_valid(body), "then it fades away")
