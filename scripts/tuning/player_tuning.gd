class_name PlayerTuning
extends Resource
## Tuning numbers for Almos. The values live in data/player_tuning.tres, not here.

## Walking speed, in pixels per second.
@export var walk_speed: float

## The most Stamina Almos can have. A full bar is this much.
@export var stamina_maximum: float

## How much Stamina comes back each second once the pause is over.
@export var stamina_refill_rate: float

## How long, in seconds, after Almos last spends Stamina before it starts to come back.
@export var stamina_refill_pause: float
