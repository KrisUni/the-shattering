class_name FireTuning
extends Resource
## The numbers of Fire: when it passes on by contact, how long a thing burns, and the light a burning thing gives.
## The values live in data/fire.tres, not here.

## How long, in seconds, after a thing catches before it sets alight the flammable things it touches.
## Fire passes only by contact: there is no spread radius.
@export var spread_delay: float

## How long, in seconds, a thing burns before it is burnt out.
@export var burn_time: float

## The gameplay light, from 0 (dark) to 1 (full light), within the light radius of a burning thing.
@export_range(0.0, 1.0) var light: float

## How far from a burning thing, in pixels, its light reaches.
@export var light_radius: float

## How much damage, a tick, Fire does to each body standing in a burning thing.
@export var damage_per_tick: float

## How long, in seconds, between one tick and the next while a thing burns. The first tick comes
## this long after it catches.
@export var tick_interval: float
