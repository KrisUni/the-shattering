class_name HeavyAttackData
extends AttackData
## The numbers of a Heavy attack. Besides what every attack has, it can be charged by
## holding the button: the damage and the Stamina cost it inherits are those of an attack
## that was not charged at all, and the ones below are those of a fully charged attack. In
## between, both grow in a straight line with the number of physics frames the button was
## held, counted from the charge start.

## How many physics frames the button must be held before the charge starts building. A
## button let go by then gives the plain Heavy attack, with the damage and Stamina cost it
## inherits, so a quick tap is never a charged one. It must be less than charge_frames_max.
@export var charge_start_frames: int

## How many physics frames of holding the button make a full charge, counted from the
## press, so the charge builds over the frames from charge_start_frames to this one. The
## attack comes out by itself once the button has been held this long.
@export var charge_frames_max: int

## How much Health a hit takes off when the attack is fully charged.
@export var charged_damage: float

## How much Stagger a hit builds when the attack is fully charged. The Stagger it inherits is
## that of a plain Heavy attack, and in between it grows in a straight line with the charge.
@export var charged_stagger: float

## How much Stamina the attack spends when it is fully charged.
@export var charged_stamina_cost: float
