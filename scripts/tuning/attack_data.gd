class_name AttackData
extends Resource
## The numbers of one attack: how long each part of the swing lasts, what it does and what
## it costs. The values live in the data file of the Weapon the attack belongs to, such as
## data/sword.tres, not here.
##
## An attack runs in three parts, one after the other and counted in whole physics frames
## (60 to the second). Startup is the wind-up before it can hurt anyone. Active is when the
## Hitbox is on. Recovery is the follow-through, after which Almos is free again.

## How many physics frames pass from the attack beginning to its Hitbox switching on.
@export var startup_frames: int

## How many physics frames its Hitbox stays on.
@export var active_frames: int

## How many physics frames pass after the Hitbox switches off before Almos is free again.
@export var recovery_frames: int

## How much Health a hit takes off.
@export var damage: float

## How much Stamina the attack spends when it begins.
@export var stamina_cost: float
