class_name HeavyAttackData
extends AttackData
## The numbers of a Heavy attack. Besides what every attack has, it can be charged by
## holding the button: the damage and the Stamina cost it inherits are those of an attack
## that was not charged at all, and the ones below are those of a fully charged attack. In
## between, both grow in a straight line with the number of physics frames the button was
## held.

## How many physics frames of holding the button make a full charge. The attack comes out
## by itself once the button has been held this long.
@export var charge_frames_max: int

## How much Health a hit takes off when the attack is fully charged.
@export var charged_damage: float

## How much Stamina the attack spends when it is fully charged.
@export var charged_stamina_cost: float
