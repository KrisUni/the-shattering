class_name WeaponData
extends Resource
## The attacks of one Weapon and the one number they share. The values live in the Weapon's
## data file, such as data/sword.tres, not here.

## How far from Almos's centre, in pixels, the Weapon's strike reaches: the far edge of the box
## his sword Hitbox hurts with, along the direction he swings. The box keeps its width and
## height from the scene and is placed so that its far edge is this far out. Every attack of
## the Weapon reaches this far.
@export var reach: float

## The swings of the Light attack combo, in the order they chain: the first press makes the
## first swing, a press at the end of each swing chains into the next, and after the last
## the combo starts over at the first.
@export var light_attacks: Array[AttackData]

## The Heavy attack.
@export var heavy_attack: HeavyAttackData

## A press of an attack button in the last this many physics frames of an attack's recovery
## is remembered, and the attack it asked for begins the moment the recovery ends.
@export var attack_buffer_frames: int
