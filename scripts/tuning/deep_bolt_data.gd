class_name DeepBoltData
extends SpellCost
## What Deep bolt costs and how its bolt flies and hits: the costs of SpellCost, and the rest here.
## The values live in data/deep_bolt.tres, not here.

## How many physics frames he is committed for between the press and the bolt leaving. The frame
## of the press is the first. The costs are paid, and the bolt leaves, at the end of the last.
@export var wind_up_frames: int

## How fast the bolt flies, in pixels per second.
@export var bolt_speed: float

## How far the bolt flies, in pixels, before it dies out.
@export var bolt_range: float

## How much Health the bolt takes off an enemy, before Channelling adds to it.
@export var base_damage: float

## How much Health more the bolt takes off for each point of Channelling.
@export var damage_per_channelling: float


## How much Health a bolt takes off when the caster has this much Channelling.
func damage_for(channelling: int) -> float:
	return base_damage + damage_per_channelling * channelling
