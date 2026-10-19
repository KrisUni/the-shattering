class_name SpellData
extends Resource
## The numbers of one Spell: what it costs, how far it reaches and how hard it hits. The values
## live in the Spell's data file, such as data/flame_draw.tres, not here.

## How much Health casting it spends. He cannot cast unless his Health stays above this much.
@export var health_cost: float

## How much Stamina casting it spends. He cannot cast with less than this much.
@export var stamina_cost: float

## How close to him, in pixels, a lit torch must be for Flame draw to take its flame.
@export var draw_range: float

## How many physics frames he is committed for between the press and the fireball leaving. The
## frame of the press is the first. The costs are paid, and the fireball leaves, at the end of the
## last.
@export var wind_up_frames: int

## How fast the fireball flies, in pixels per second.
@export var fireball_speed: float

## How far the fireball flies, in pixels, before it dies out.
@export var fireball_range: float

## How much Health the fireball takes off an enemy, before Channelling adds to it.
@export var base_damage: float

## How much Health more the fireball takes off for each point of Channelling.
@export var damage_per_channelling: float


## How much Health a fireball takes off when the caster has this much Channelling.
func damage_for(channelling: int) -> float:
	return base_damage + damage_per_channelling * channelling
