extends GutTest
## Hurtbox, tested through its public interface: hurt() is called here by hand with a Health
## of its own to take the damage, and the two hooks its owner can set are stood in for by
## small functions made here. The last test puts a real Hitbox over a Hurtbox, to see which
## point the Hitbox says its hit comes from. Every expected number comes from the damage a
## test gives the hit and the amount its hook lets through, never from how the code works
## them out.

# In Health points.
const TOLERANCE := 0.0001
# In Health points. More than any hit in these tests takes off.
const HEALTH_MAXIMUM := 100.0
# In Health points.
const HIT_DAMAGE := 30.0
# In pixels. A strike this wide covers a Hurtbox from wherever the Hitbox is placed.
const HITBOX_RADIUS := 200.0
# In pixels.
const HURTBOX_RADIUS := 12.0
# Enough physics frames for a node put in the tree to be known to the physics server, and for
# a Hitbox switched on to have been through a frame.
const SETTLE_FRAMES := 2

var _health: Health
var _hurtbox: Hurtbox


func before_each() -> void:
	# Start between two physics frames, as real input arrives, so what the test spawns is first processed after the first sample
	# and what it presses is seen from the next frame. GUT alone would start it in the physics frame the last test ended in.
	await get_tree().process_frame
	_health = autofree(Health.new())
	_health.maximum = HEALTH_MAXIMUM
	_hurtbox = autofree(Hurtbox.new())
	_hurtbox.health = _health


func test_by_default_a_hit_lands_and_takes_all_its_damage_off_the_health() -> void:
	var landed := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_true(landed, "a hit should land")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - HIT_DAMAGE, TOLERANCE)


func test_the_health_takes_the_damage_the_hook_lets_through_not_the_damage_of_the_hit() -> void:
	var let_through := HIT_DAMAGE / 3.0
	_hurtbox.damage_through = func(_damage: float, _from: Vector2) -> float: return let_through

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_almost_eq(_health.current, HEALTH_MAXIMUM - let_through, TOLERANCE)


func test_the_hook_is_asked_with_the_damage_of_the_hit_and_the_point_it_comes_from() -> void:
	var asked: Array[Dictionary] = []
	_hurtbox.damage_through = func(damage: float, from: Vector2) -> float:
		asked.append({"damage": damage, "from": from})
		return damage
	var from := Vector2(40.0, -25.0)

	_hurtbox.hurt(HIT_DAMAGE, from)

	assert_eq(asked.size(), 1, "the hook should be asked once")
	if asked.size() == 1:
		assert_almost_eq(asked[0].damage, HIT_DAMAGE, TOLERANCE)
		assert_almost_eq(asked[0].from, from, Vector2.ONE * TOLERANCE)


func test_the_hook_is_asked_again_for_every_hit_that_lands() -> void:
	var asked := [0]
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float:
		asked[0] += 1
		return damage

	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)
	_hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_eq(asked[0], 2)
	assert_almost_eq(_health.current, HEALTH_MAXIMUM - 2.0 * HIT_DAMAGE, TOLERANCE)


func test_a_hit_the_hook_lets_none_of_the_damage_through_still_lands() -> void:
	_hurtbox.damage_through = func(_damage: float, _from: Vector2) -> float: return 0.0

	var landed := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_true(landed, "a hit that does no damage has still landed, so that its swing does not hit again")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_hit_on_an_untouchable_owner_does_not_land_and_the_damage_hook_is_not_asked() -> void:
	var asked := [0]
	_hurtbox.is_untouchable = func() -> bool: return true
	_hurtbox.damage_through = func(damage: float, _from: Vector2) -> float:
		asked[0] += 1
		return damage

	var landed := _hurtbox.hurt(HIT_DAMAGE, Vector2.ZERO)

	assert_false(landed, "a hit on someone untouchable should not land")
	assert_eq(asked[0], 0, "the hook is for hits that land")
	assert_almost_eq(_health.current, HEALTH_MAXIMUM, TOLERANCE)


func test_a_hitbox_says_its_hit_comes_from_where_it_sits_in_the_world() -> void:
	var from_hook: Array[Vector2] = []
	_hurtbox.collision_layer = 1
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.damage_through = func(damage: float, from: Vector2) -> float:
		from_hook.append(from)
		return damage
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HURTBOX_RADIUS
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	# Under a parent that is not at the origin, so that where it sits in the world is not
	# where it sits under the parent.
	var holder := Node2D.new()
	holder.position = Vector2(100.0, 0.0)
	var hitbox := Hitbox.new()
	hitbox.damage = HIT_DAMAGE
	hitbox.collision_mask = 1
	hitbox.position = Vector2(30.0, 40.0)
	var strike := CollisionShape2D.new()
	var wide := CircleShape2D.new()
	wide.radius = HITBOX_RADIUS
	strike.shape = wide
	hitbox.add_child(strike)
	holder.add_child(hitbox)
	add_child_autofree(holder)
	await wait_physics_frames(SETTLE_FRAMES)

	hitbox.active = true
	await wait_physics_frames(SETTLE_FRAMES)
	hitbox.active = false

	assert_eq(from_hook.size(), 1, "the hit should have landed once")
	if from_hook.size() == 1:
		assert_almost_eq(from_hook[0], Vector2(130.0, 40.0), Vector2.ONE * TOLERANCE)
