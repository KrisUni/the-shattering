class_name FlaskTuning
extends Resource
## The numbers of Almos's Flasks: how many charges the Health Flask holds and what a Sip of it
## does. The values live in data/flasks.tres, not here.

## How many charges the Health Flask holds to begin with, and is refilled to at a Checkpoint.
@export var health_charges: int

## How long, in seconds, a Sip lasts. Health comes back at its end.
@export var sip_duration: float

## The share of the Health maximum a Sip of the Health Flask restores, from 0 to 1.
@export_range(0.0, 1.0) var health_restore_share: float

## Walking speed during a Sip, in pixels per second.
@export var sip_walk_speed: float
