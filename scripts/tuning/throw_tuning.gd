class_name ThrowTuning
extends Resource
## How lifting and throwing a prop goes, the same for every prop. The values live in
## data/throw.tres, not here.

## How far above his feet, in pixels, the foot of a prop he holds floats.
@export var hold_height: float

## How long, in seconds, a lifted prop takes to float up to where he holds it.
@export var lift_time: float

## How fast, in pixels per second, a thrown or knocked prop flies.
@export var throw_speed: float

## How far, in pixels, a prop he throws from his hold flies before it comes down.
@export var throw_range: float

## How far, in pixels, a prop a Shove knocks from where it stands flies.
@export var knock_range: float
