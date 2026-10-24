class_name RoomPursuitTuning
extends Resource
## The numbers of an enemy in Pursuit following Almos through a Room's exit. The values live in
## its data file, data/room_pursuit.tres, not here.

## How long, in seconds, a pursuing enemy waits at the exit it follows Almos through before it
## comes out of the paired exit in the next Room.
@export var follow_delay_seconds: float
