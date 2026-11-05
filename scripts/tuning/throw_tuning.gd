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

## How far, in pixels, a prop of knock_weight that a Shove knocks from where it stands flies. A
## lighter prop flies further and a heavier one less, as the square root of knock_weight over its
## own weight, kept within knock_scale_min and knock_scale_max of it.
@export var knock_range: float

## The weight a Shove knocks exactly knock_range (a barrel's).
@export var knock_weight: float = 10.0

## The least and the most of knock_range a Shove knocks any prop, however heavy or light.
@export var knock_scale_min: float = 0.5
@export var knock_scale_max: float = 1.5


## How far, in pixels, a Shove knocks a prop of this weight.
func knock_range_for(weight: float) -> float:
	if weight <= 0.0:
		return knock_range * knock_scale_max
	return knock_range * clampf(sqrt(knock_weight / weight), knock_scale_min, knock_scale_max)
