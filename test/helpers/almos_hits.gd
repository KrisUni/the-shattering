extends RefCounted
## What the tests that hit Almos share: a Hitbox that stands in for an attacker, placed in
## front of him or behind him, and the swing that switches it on. It lives under test/helpers
## without the test_ prefix, so GUT does not collect it as a test.

# In Health points. A hit small enough that several of them fit in his Health.
const HIT_DAMAGE := 20.0
# In pixels. How far from Almos a hit's origin is placed, in front of him or behind him.
const HIT_DISTANCE := 50.0
# In pixels. A strike this wide covers all of Almos from wherever the origin is placed.
const HITBOX_RADIUS := 200.0

var _test: GutTest


func _init(test: GutTest) -> void:
	_test = test


# A Hitbox, switched off, standing with its origin this far from Almos, which is where its
# hit comes from, and wide enough to cover him from there, aimed at the player's Hurtboxes as
# an enemy's would be. The test frees it.
func hitbox_from(almos: Node2D, offset: Vector2, damage := HIT_DAMAGE) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.damage = damage
	hitbox.collision_mask = _layer_bit("player_hurtbox")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HITBOX_RADIUS
	shape.shape = circle
	hitbox.add_child(shape)
	hitbox.global_position = almos.global_position + offset
	_test.add_child_autofree(hitbox)
	return hitbox


# Switches the hitbox on for this many physics frames, then off again. It waits on the
# physics_frame signal, which comes before the hitbox is processed in a frame, so the
# hitbox is processed on exactly this many frames while it is on. A hit lands while the
# hitbox is processed, which is after Almos is, since the test adds it to the tree later.
func swing(hitbox: Hitbox, frames: int) -> void:
	hitbox.active = true
	for i in frames:
		await _test.get_tree().physics_frame
	hitbox.active = false


# The collision layer the project calls this, as the bit that sets it in a collision mask.
func _layer_bit(layer_name: String) -> int:
	for layer in range(1, 33):
		if ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer, "") == layer_name:
			return 1 << (layer - 1)
	_test.fail_test("the project should name a 2D physics layer %s" % layer_name)
	return 0
