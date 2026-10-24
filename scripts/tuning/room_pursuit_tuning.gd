class_name RoomPursuitTuning
extends Resource
## The numbers of an enemy in Pursuit following Almos through a Room's exit. The values live in
## its data file, data/room_pursuit.tres, not here.

## How long, in seconds, a pursuing enemy waits at the exit it follows Almos through before it
## comes out of the paired exit in the next Room.
@export var follow_delay_seconds: float

## How long, in seconds, a pursuing enemy on its way to the exit may go without coming any closer
## to it before it gives up the walk, such as when something is in its way, and goes on as an
## enemy in Pursuit does.
@export var follow_give_up_seconds: float
