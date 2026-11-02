extends RefCounted
## Pull takes the nearest thing all round Almos, so a test of one target clears the room of every
## other enemy, movable object and liftable prop first, keeping only those given. It lives under
## test/helpers without the test_ prefix, so GUT does not collect it as a test.


## Takes out of this room every enemy, movable object and liftable prop but those in keep.
static func clear(room: Node, keep: Array = []) -> void:
	var tree := room.get_tree()
	var doomed: Array[Node] = []
	for group in [&"enemies", &"movables"]:
		for node in tree.get_nodes_in_group(group):
			if not keep.has(node) and room.is_ancestor_of(node):
				doomed.append(node)
	for lift in tree.get_nodes_in_group(&"liftables"):
		var prop: Node = lift.get_parent()
		if prop != null and not keep.has(prop) and room.is_ancestor_of(prop):
			doomed.append(prop)
	for node in doomed:
		if is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.free()
