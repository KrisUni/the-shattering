extends RefCounted
## Where the box of a strike sits and where its placeholder is drawn, for the tests of how far
## a strike reaches. Both are read from a Hitbox as it stands, in its own frame: the frame the
## attacker's centre is the origin of, and the direction of the strike is +x, as long as the
## Hitbox has not been turned. It lives under test/helpers without the test_ prefix, so GUT
## does not collect it as a test.


## The box that hurts: the Hitbox's CollisionShape2D, where it sits.
static func real_box(hitbox: Hitbox) -> Rect2:
	var shape_node := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var box := shape_node.shape.get_rect()
	return Rect2(box.position + shape_node.position, box.size)


## The box that is drawn: the bounds of the Hitbox's Placeholder, where it sits.
static func drawn_box(hitbox: Hitbox) -> Rect2:
	var placeholder := hitbox.get_node("Placeholder") as Polygon2D
	var box := Rect2(placeholder.polygon[0] + placeholder.position, Vector2.ZERO)
	for point in placeholder.polygon:
		box = box.expand(point + placeholder.position)
	return box


## The width and height of the box that hurts, as the scene gives them, before anything has
## had the chance to change them. The scene is instantiated, read and freed without ever
## entering a tree.
static func box_size_in_scene(scene_path: String, hitbox_path: NodePath) -> Vector2:
	var root := (load(scene_path) as PackedScene).instantiate()
	var size := real_box(root.get_node(hitbox_path) as Hitbox).size
	root.free()
	return size
