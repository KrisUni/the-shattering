extends RefCounted
## Where the box of a strike sits and where its drawing is, for the tests of how far
## a strike reaches. Both are read from a Hitbox as it stands, in its own frame: the frame the
## attacker's centre is the origin of, and the direction of the strike is +x, as long as the
## Hitbox has not been turned. It lives under test/helpers without the test_ prefix, so GUT
## does not collect it as a test.


## The box that hurts: the Hitbox's CollisionShape2D, where it sits.
static func real_box(hitbox: Hitbox) -> Rect2:
	var shape_node := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var box := shape_node.shape.get_rect()
	return Rect2(box.position + shape_node.position, box.size)


## The box that is drawn: the bounds of the Hitbox's Look and its Shape, where they sit. A
## Hitbox that has no Look yet (the enemies', until they are given one) is read from its
## Placeholder.
static func drawn_box(hitbox: Hitbox) -> Rect2:
	var shape := hitbox.get_node_or_null("Look/Shape") as Polygon2D
	var offset := Vector2.ZERO
	if shape != null:
		offset = (shape.get_parent() as Node2D).position + shape.position
	else:
		shape = hitbox.get_node("Placeholder") as Polygon2D
		offset = shape.position
	var box := Rect2(shape.polygon[0] + offset, Vector2.ZERO)
	for point in shape.polygon:
		box = box.expand(point + offset)
	return box


## The width and height of the box that hurts, as the scene gives them, before anything has
## had the chance to change them. The scene is instantiated, read and freed without ever
## entering a tree.
static func box_size_in_scene(scene_path: String, hitbox_path: NodePath) -> Vector2:
	var root := (load(scene_path) as PackedScene).instantiate()
	var size := real_box(root.get_node(hitbox_path) as Hitbox).size
	root.free()
	return size
