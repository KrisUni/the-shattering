extends GutTest
## Props react, as looks only: a barrel knocked across the floor rocks one way and the other as it
## settles; a clay pot breaks into small shards rather than a barrel's staves; Corridor 2's locked
## door swings its leaf open on its hinge when the Jailer's key opens it; and a pickup rises off the
## floor and fades as it is taken.

const BARREL_SCENE := preload("res://scenes/world/barrel.tscn")
const DOOR_SCENE := preload("res://scenes/world/locked_door.tscn")
const PICKUP_SCENE := preload("res://scenes/world/weapon_pickup.tscn")
const KEY := &"dungeons/jailers_key"

var _holder: Node2D


func before_each() -> void:
	WorldState.reset()
	_holder = Node2D.new()
	add_child_autofree(_holder)


func after_each() -> void:
	WorldState.reset()


func test_a_knocked_barrel_rocks_as_it_settles() -> void:
	var barrel := BARREL_SCENE.instantiate() as Node2D
	_holder.add_child(barrel)
	await wait_physics_frames(2)
	var lift := barrel.get_node("Liftable")
	lift.throw(Vector2.RIGHT, true)
	var rocked := false
	for i in 120:
		await wait_physics_frames(1)
		if lift.state == Liftable.State.RESTING and (barrel.get_node("Look") as Node2D).position.x != 0.0:
			rocked = true
	assert_true(rocked, "it rocks as it comes to rest")
	assert_eq((barrel.get_node("Look") as Node2D).position, Vector2.ZERO, "and settles")


func test_a_clay_pot_breaks_into_shards() -> void:
	assert_eq((load("res://data/clay_pot_lift.tres") as LiftTuning).pieces, &"shards", "a pot breaks into shards")
	assert_eq((load("res://data/barrel_lift.tres") as LiftTuning).pieces, &"staves", "a barrel into staves")
	var pieces := (load("res://scenes/world/prop_break.gd") as GDScript).new() as Node2D
	_holder.add_child(pieces)
	var texture := load("res://assets/dungeons/pots/clay_pot.png") as Texture2D
	pieces.call(&"shatter", texture, Vector2.ZERO, Vector2.ONE, Vector2.RIGHT, &"shards")
	var shards := pieces.get_children().filter(func(node: Node) -> bool: return node is Sprite2D)
	assert_gt(shards.size(), 8, "many small pieces")
	for shard: Sprite2D in shards:
		assert_lte(shard.region_rect.size.x, 5.0, "each small")


func test_the_locked_door_swings_its_leaf_open() -> void:
	var door := DOOR_SCENE.instantiate() as MainEntrance
	_holder.add_child(door)
	var leaf := door.get_node("Look/Leaf") as Node2D
	assert_eq(leaf.rotation, 0.0, "shut, the leaf fills the doorway")
	WorldState.record_taken(KEY)
	assert_true(door.open_with_key(), "control: it opens")
	await wait_seconds(0.8)
	assert_almost_eq(leaf.rotation, PI / 2.0, 0.001, "the leaf has swung a quarter turn into the hall")
	assert_eq((door.get_node("Look") as Node2D).modulate, Color.WHITE, "drawn plain, not dimmed")


func test_a_pickup_rises_off_the_floor_as_it_is_taken() -> void:
	var pickup := PICKUP_SCENE.instantiate() as Node2D
	pickup.set(&"weapon", load("res://data/sword.tres"))
	_holder.add_child(pickup)
	await wait_process_frames(2)
	var copy := PickupLift.lift(pickup)
	pickup.queue_free()
	assert_not_null(copy, "a copy of it is left")
	var start := copy.position.y
	await wait_seconds(0.2)
	assert_lt(copy.position.y, start, "rising")
	await wait_seconds(0.5)
	assert_false(is_instance_valid(copy), "then gone")
