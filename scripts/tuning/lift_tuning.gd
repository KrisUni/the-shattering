class_name LiftTuning
extends Resource
## The numbers of one kind of prop Pull can lift and Shove can throw, such as a barrel. The values
## live in its data file, such as data/barrel_lift.tres, not here.

## How heavy it is. Pull lifts it, and Shove knocks it away, only if this is no more than the
## greatest Weight he can move (see PlayerTuning.greatest_weight); a heavier one shudders.
@export var weight: float

## How much Health it takes off the enemy it is thrown into.
@export var damage: float

## How far, in pixels, it knocks that enemy back along its flight.
@export var knockback: float

## Whether it breaks apart where a throw from his hold ends (or where a knock sends it into a wall or
## an enemy), gone until enemies return, rather than coming to rest. A barrel does.
@export var breaks := false
