class_name WeaponData
extends Resource
## The attacks of one Weapon and the one number they share. The values live in the Weapon's
## data file, such as data/sword.tres, not here.

## The swings of the Light attack combo, in the order they chain: the first press makes the
## first swing, a press at the end of each swing chains into the next, and after the last
## the combo starts over at the first.
@export var light_attacks: Array[AttackData]

## The Heavy attack.
@export var heavy_attack: HeavyAttackData

## A press of an attack button in the last this many physics frames of an attack's recovery
## is remembered, and the attack it asked for begins the moment the recovery ends.
@export var attack_buffer_frames: int
