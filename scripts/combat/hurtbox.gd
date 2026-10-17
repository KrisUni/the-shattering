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


## A hit reaches this Hurtbox, for this much damage. Returns whether it landed: it does
## not while the owner is untouchable.
func hurt(damage: float) -> bool:
	if is_untouchable.call():
		return false
	health.take_damage(damage)
	return true
