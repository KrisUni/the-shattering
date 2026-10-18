class_name Hurtbox
extends Area2D
## Where something can be hurt. A Hitbox that reaches it takes its damage off the Health
## this Hurtbox belongs to.
##
## A Hurtbox sits on the layer of its side (player_hurtbox or enemy_hurtbox) and looks for
## nothing itself; Hitboxes look for it through their masks.

## The Health that hits on this Hurtbox take damage from.
@export var health: Health

## Asked on every hit: whether the owner cannot be hurt at this moment, such as Almos in
## part of a Roll. It is asked, not told, so that the answer is never a frame old. Left as
## it is, the owner can always be hurt.
var is_untouchable: Callable = func() -> bool: return false

## Asked on every hit that lands, which a hit on someone untouchable does not: how much of
## the hit's damage gets through, given the damage and the point in the world the hit comes
## from. Almos blocking is the case: a hit from the front deals less. The Health takes what it
## returns. It is asked once for each hit, so it may do more than answer, such as spend
## something on the hit. Left as it is, all of the damage gets through.
var damage_through: Callable = func(damage: float, _from: Vector2) -> float: return damage


## A hit reaches this Hurtbox, for this much damage, coming from this point in the world.
## Returns whether it landed: it does not while the owner is untouchable. A hit that landed
## has been dealt with even if none of its damage got through.
func hurt(damage: float, from: Vector2) -> bool:
	if is_untouchable.call():
		return false
	health.take_damage(damage_through.call(damage, from))
	return true
