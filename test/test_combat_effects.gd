extends GutTest
## Where blows meet, a look only: iron sparks fly from a Parry, a smaller spray and a puff of dust from
## a Block. A jailer's sword leaves an arc through its blow, and as its Stagger nears a Break its
## figure shakes. Smoke curls from a torch whose flame Pull takes, heat rises off a held flame, and
## what a Shove sends flying leaves the air rippling in its wake.

const JAILER_SCENE := preload("res://scenes/enemies/nar_jailer.tscn")
const TORCH_SCENE := preload("res://scenes/world/torch.tscn")
const AlmosInput := preload("res://test/helpers/almos_input.gd")

var _holder: Node2D


func before_each() -> void:
	_holder = Node2D.new()
	add_child_autofree(_holder)


func _of(kind: Variant) -> Array:
	return _holder.get_children().filter(func(node: Node) -> bool: return is_instance_of(node, kind))


func _jailer() -> Node2D:
	var jailer := JAILER_SCENE.instantiate() as Node2D
	_holder.add_child(jailer)
	return jailer


func test_a_parry_throws_iron_sparks() -> void:
	var jailer := _jailer()
	await wait_physics_frames(2)
	var hurtbox := jailer.get_node("Hurtbox") as Hurtbox
	hurtbox.is_parried = func(_from: Vector2) -> bool: return true
	hurtbox.hurt(5.0, jailer.global_position + Vector2(30, 0), 1.0)
	assert_eq(_of(SparkBurst).size(), 1, "sparks fly")


func test_a_block_throws_a_spray_of_sparks_and_dust() -> void:
	var jailer := _jailer()
	await wait_physics_frames(2)
	var hurtbox := jailer.get_node("Hurtbox") as Hurtbox
	hurtbox.is_parried = func(_from: Vector2) -> bool: return false
	hurtbox.damage_through = func(damage: float, _from: Vector2) -> float: return damage * 0.2
	hurtbox.hurt(5.0, jailer.global_position + Vector2(30, 0), 1.0)
	assert_eq(_of(SparkBurst).size(), 1, "a spray of sparks")
	assert_eq(_of(DustPuff).size(), 1, "and dust from the feet")


func test_a_blow_in_full_throws_neither() -> void:
	var jailer := _jailer()
	await wait_physics_frames(2)
	var hurtbox := jailer.get_node("Hurtbox") as Hurtbox
	hurtbox.is_parried = func(_from: Vector2) -> bool: return false
	hurtbox.damage_through = func(damage: float, _from: Vector2) -> float: return damage
	hurtbox.hurt(5.0, jailer.global_position + Vector2(30, 0), 1.0)
	assert_eq(_of(SparkBurst).size(), 0, "no sparks")


func test_a_jailer_carries_an_arc_for_its_blows() -> void:
	var jailer := _jailer()
	await wait_physics_frames(2)
	assert_eq(jailer.get_node("Look").get_children().filter(func(node: Node) -> bool: return node is BladeSmear).size(), 1, "its look holds the arc")


func test_a_guard_near_breaking_shakes() -> void:
	var jailer := _jailer()
	await wait_physics_frames(2)
	var stagger := jailer.get_node("Stagger") as Stagger
	stagger.add(stagger.capacity * 0.85)
	var shook := false
	for i in 12:
		await wait_physics_frames(1)
		if (jailer.get_node("Look/Art") as Node2D).position.x != 0.0:
			shook = true
	assert_true(shook, "its figure shakes")


func test_smoke_curls_from_a_torch_whose_flame_is_taken() -> void:
	var torch := TORCH_SCENE.instantiate()
	_holder.add_child(torch)
	assert_true(torch.draw(), "control: the flame is taken")
	assert_eq(_of(SmokeCurl).size(), 1, "smoke curls up")


func test_heat_rises_off_a_held_flame() -> void:
	var input := AlmosInput.new(self)
	var almos = input.spawn_almos()
	assert_true(almos.get_node_or_null("HeldFlame/Flame/Shimmer") is HeatShimmer, "the held flame has its shimmer")


func test_a_shoved_thing_leaves_a_wake() -> void:
	var thing := Node2D.new()
	_holder.add_child(thing)
	var ripple := AirRipple.trail(_holder, thing)
	for i in 6:
		thing.position.x += 10.0
		await wait_process_frames(2)
	assert_true(is_instance_valid(ripple), "the wake follows it")
	await wait_seconds(1.0)
	assert_false(is_instance_valid(ripple), "then fades away")
