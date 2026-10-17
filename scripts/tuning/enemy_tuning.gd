class_name EnemyTuning
extends Resource
## Tuning numbers for one kind of enemy and its one attack. The values live in the enemy's
## data file, such as data/training_enemy.tres, not here.

## The most Health the enemy can have. A full bar is this much.
@export var health_maximum: float

## How fast it walks towards its target, in pixels per second.
@export var move_speed: float

## How far from its target, in pixels, it still notices it. Beyond this it stays where it is.
@export var notice_range: float

## How close to its target, in pixels, it stops walking and attacks.
@export var attack_range: float

## How far from its centre, in pixels, its strike reaches: the far edge of the box its Hitbox
## hurts with, along the direction it strikes. The box keeps its width and height from the
## scene and is placed so that its far edge is this far out. It hurts what its box overlaps, so
## the nearest edge of whatever it swings at, which is a Hurtbox radius short of attack_range
## from its centre, must not be farther than this, or it swings from where it cannot hit.
@export var attack_reach: float

## Its one attack. The startup frames are its wind-up. Enemies have no Stamina, so the
## attack's stamina_cost is not used.
@export var attack: AttackData
