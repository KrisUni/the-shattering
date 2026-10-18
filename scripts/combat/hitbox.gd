class_name Hitbox
extends Area2D
## The part of an attack that hurts. It is switched on for the attack's active frames and
## off otherwise, and damages the Hurtboxes its mask reaches, each at most once per swing.
## It never hurts the body it is part of.
##
## A Hitbox sits on no layer and looks for Hurtboxes through its mask: an attack on the
## player masks player_hurtbox, an attack on enemies masks enemy_hurtbox.
##
## It tells the Hurtbox where the hit comes from: the Hitbox's own position, so a Hitbox
## belongs at the centre of whoever swings it, turning there to aim.

## Emitted once for each hit that a Hurtbox reports parried, with that Hurtbox. The attacker
## hears of it here.
signal parried(hurtbox: Hurtbox)

## How much Health a hit takes off.
@export var damage: float

## How much Stagger a hit builds on whoever it lands on.
@export var stagger: float

## Whether a hit is a Critical hit, which the Hurtbox tells whoever owns it. Almos's Critical
## swing is the one that sets it.
@export var critical := false

## Whether a hit is low, which travels along the ground: the Hurtbox tells whether its owner is
## in the air, and a hit on someone in the air misses. A Low attack sets it.
@export var low := false

## The box the strike hurts with, a CollisionShape2D under this Hitbox. set_reach moves it.
@export var strike_shape: CollisionShape2D

## What is drawn of the strike while it is on, under this Hitbox. set_reach moves it with the
## box, so that it keeps covering it. Optional.
@export var strike_placeholder: Node2D

## Whether the swing is on. Switching it on starts a new swing, which may hit every
## Hurtbox again; switching it on when it is already on changes nothing.
var active := false:
	set(value):
		if value == active:
			return
		active = value
		_hit.clear()

# The Hurtboxes this swing has hit already, parried hits included. A hit that did not land,
# on someone untouchable, does not count: a swing that is still on when they stop being
# untouchable catches them.
var _hit: Array[Hurtbox] = []


## Puts the strike this far out: the far edge of strike_shape lands reach pixels from this
## Hitbox's origin along its local +x, and strike_placeholder moves the same distance. The box
## keeps its width and height, and the Hitbox itself does not move, so a Hitbox that sits at
## the attacker's centre and is turned to aim still turns about that centre. Done once the
## scene is ready and again whenever the reach changes; doing it again for the same reach
## changes nothing.
func set_reach(reach: float) -> void:
	assert(strike_shape != null and strike_shape.shape != null, "set_reach needs a strike_shape with a shape")
	var far_edge := strike_shape.position.x + strike_shape.shape.get_rect().end.x
	var shift := reach - far_edge
	strike_shape.position.x += shift
	if strike_placeholder != null:
		strike_placeholder.position.x += shift


func _physics_process(_delta: float) -> void:
	if not active:
		return
	# Polled, not listened for, so that a Hurtbox already under the Hitbox when it is
	# switched on is hit as well as one that walks into it.
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null and hurtbox not in _hit and not _is_part_of_same_body(hurtbox):
			var outcome := hurtbox.hurt(damage, global_position, stagger, critical, low)
			if outcome != Hurtbox.Outcome.MISSED:
				_hit.append(hurtbox)
			if outcome == Hurtbox.Outcome.PARRIED:
				parried.emit(hurtbox)


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
