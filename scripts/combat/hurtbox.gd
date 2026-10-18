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

## How much Stagger a hit this Hurtbox parries builds on whoever struck it. Its owner sets it,
## such as Almos from his tuning; the attacker reads it off the Hurtbox its Hitbox hands it
## when it hears of the Parry. Left as it is, a Parry builds none.
var parry_stagger := 0.0

## Emitted once for each hit that lands, with how much Stagger it builds and the point in the
## world it comes from. Not for a hit that misses or is parried. The owner hears of a landed
## hit here, such as an enemy building its Stagger.
signal landed(stagger: float, from: Vector2)

## Asked on every hit on someone who is not untouchable, given the point in the world the hit
## comes from: whether the owner parries it, which negates it. Almos in the window of his
## Parry, with the hit in front of him, is the case. A parried hit never reaches
## damage_through. It is asked once for each hit, so it may do more than answer, such as end
## the Parry. Left as it is, nothing is parried.
var is_parried: Callable = func(_from: Vector2) -> bool: return false

## What became of a hit that reached a Hurtbox.
enum Outcome {
	## The owner was untouchable, so the hit did not land and may land later.
	MISSED,
	## The hit landed, and whatever damage got through was taken off the Health.
	LANDED,
	## The owner parried the hit: it did no damage, and it has been dealt with.
	PARRIED,
}

## Asked on every hit that does not miss, after is_parried has let it by: how much of
## the hit's damage gets through, given the damage and the point in the world the hit comes
## from. Almos blocking is the case: a hit from the front deals less. The Health takes what it
## returns. It is asked once for each hit, so it may do more than answer, such as spend
## something on the hit. Left as it is, all of the damage gets through.
var damage_through: Callable = func(damage: float, _from: Vector2) -> float: return damage


## A hit reaches this Hurtbox, for this much damage, building this much Stagger, coming from
## this point in the world. Returns what became of it: it misses while the owner is untouchable and is parried when
## the owner's Parry catches it. A hit that landed or was parried has been dealt with, even
## if none of its damage got through.
func hurt(damage: float, from: Vector2, stagger := 0.0) -> Outcome:
	if is_untouchable.call():
		return Outcome.MISSED
	if is_parried.call(from):
		return Outcome.PARRIED
	health.take_damage(damage_through.call(damage, from))
	landed.emit(stagger, from)
	return Outcome.LANDED
