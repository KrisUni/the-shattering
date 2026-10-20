class_name SpellCost
extends Resource
## What casting one Spell costs. The values live in the Spell's cost file, such as
## data/pull.tres, not here.

## How much Health casting it spends. He cannot cast unless his Health stays above this much.
@export var health_cost: float

## How much Mana casting it spends once he has a Mana bar, instead of Health. He cannot cast with
## less Mana than this.
@export var mana_cost: float

## How much Stamina casting it spends. He cannot cast with less than this much.
@export var stamina_cost: float

## How far from him, in pixels, the nearest enemy can be for the Spell to act on it with no flame
## in play. Only Shove and Pull act on enemies, so only their files set it.
@export var target_range: float

## How wide, in degrees, the cone is that the Spell looks for an enemy in, centred on the way he
## aims: half of it either side.
@export var cone_half_angle_degrees: float

## Shove: how far, in pixels, the enemy is slid away from him. Pull: how far from his centre, in
## pixels, the enemy's centre stops when it is slid towards him.
@export var distance: float

## Pull only: how close to him, in pixels, a Fire's nearest edge must be for Pull to take its flame.
@export var flame_range: float

## Pull only: for how many seconds he holds a flame taken from a Fire before it goes out unthrown.
@export var fire_flame_hold_time: float

## How fast the enemy slides, in pixels per second.
@export var move_speed: float
