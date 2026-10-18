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

## The most Stagger the enemy can have. A full meter is this much.
@export var stagger_capacity: float

## How much Stagger drains each second once the pause is over.
@export var stagger_drain_rate: float

## How long, in seconds, nothing has to press the enemy before its Stagger starts to drain.
@export var stagger_drain_pause: float

## How wide, in degrees, its front is, centred on the way it faces: half of it either side. A
## hit from outside it is a hit from behind.
@export var front_arc_degrees: float

## How much Stagger a hit from behind builds on top of what the attack builds itself.
@export var behind_stagger: float
