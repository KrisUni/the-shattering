class_name Hitbox
extends Area2D
## The part of an attack that hurts. It is switched on for the attack's active frames and
## off otherwise, and damages the Hurtboxes its mask reaches, each at most once per swing.
## It never hurts the body it is part of.
##
## A Hitbox sits on no layer and looks for Hurtboxes through its mask: an attack on the
## player masks player_hurtbox, an attack on enemies masks enemy_hurtbox.

## How much Health a hit takes off.
@export var damage: float

## Whether the swing is on. Switching it on starts a new swing, which may hit every
## Hurtbox again; switching it on when it is already on changes nothing.
var active := false:
	set(value):
		if value == active:
			return
		active = value
		_hit.clear()

# The Hurtboxes this swing has hit already. A hit that did not land, on someone untouchable,
# does not count: a swing that is still on when they stop being untouchable catches them.
var _hit: Array[Hurtbox] = []


func _physics_process(_delta: float) -> void:
	if not active:
		return
	# Polled, not listened for, so that a Hurtbox already under the Hitbox when it is
	# switched on is hit as well as one that walks into it.
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null and hurtbox not in _hit and not _is_part_of_same_body(hurtbox):
			if hurtbox.hurt(damage):
				_hit.append(hurtbox)


# Whether the Hurtbox is part of the same body as this Hitbox, such as the body of whoever
# swings it. Whatever sits under no body at all belongs to none.
func _is_part_of_same_body(hurtbox: Hurtbox) -> bool:
	var body := _body_of(self)
	return body != null and body == _body_of(hurtbox)


# The body this part of a scene belongs to: the nearest body above it in the tree.
func _body_of(part: Node) -> PhysicsBody2D:
	var node := part.get_parent()
	while node != null and not node is PhysicsBody2D:
		node = node.get_parent()
	return node as PhysicsBody2D
