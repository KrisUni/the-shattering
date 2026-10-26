class_name MovableTuning
extends Resource
## The numbers of one kind of movable object, such as a Crate. The values live in its data file,
## such as data/crate.tres, not here.

## How heavy it is. Shove and Pull move it only if this is no more than the greatest Weight he can
## move (see PlayerTuning.greatest_weight); a heavier one shudders and stays where it is.
@export var weight: float

## The width and height of its square body, in pixels.
@export var size: float

## The colour of its shape.
@export var color: Color
