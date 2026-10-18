class_name PlayerTuning
extends Resource
## Tuning numbers for Almos. The values live in data/player_tuning.tres, not here.

## Walking speed, in pixels per second.
@export var walk_speed: float

## The most Health Almos can have. A full bar is this much.
@export var health_maximum: float

## The most Stamina Almos can have. A full bar is this much.
@export var stamina_maximum: float

## How much Stamina comes back each second once the pause is over.
@export var stamina_refill_rate: float

## How long, in seconds, after Almos last spends Stamina before it starts to come back.
@export var stamina_refill_pause: float

## Sprinting speed, in pixels per second.
@export var sprint_speed: float

## How much Stamina a Sprint spends each second.
@export var sprint_stamina_per_second: float

## How long, in seconds, the Roll button must be held before it counts as a Sprint
## rather than a tap. A press released sooner is a tap and Rolls.
@export var roll_hold_threshold: float

## How far a Roll carries Almos, in pixels.
@export var roll_distance: float

## How long a Roll lasts, in seconds.
@export var roll_duration: float

## How much Stamina a Roll spends when it starts.
@export var roll_stamina_cost: float

## How many seconds into a Roll Almos becomes untouchable.
@export var roll_untouchable_start: float

## How long, in seconds, Almos stays untouchable once he has become so.
@export var roll_untouchable_duration: float

## A tap in the last this many seconds of a Roll queues another Roll, which starts the
## moment the current one ends.
@export var roll_buffer_window: float

## How far from Almos, in pixels, an enemy can be for Lock-on to pick it.
@export var lock_on_range: float

## How far from Almos, in pixels, the target of a Lock-on can get before the lock breaks.
## At least lock_on_range, so that a target standing at the edge of the range does not
## flicker between locked and not.
@export var lock_on_break_range: float

## How far, in degrees, the direction of the move input must turn from the direction Lock-on
## latched before it latches afresh. Under Lock-on the move input is split against the line to
## the target into a part along it and a part across it, and the split is latched when the input
## starts. While the input stays within this much of the latched direction, Almos keeps the
## same mix of closing in and circling however far round the target he has got. Past it, the
## new direction is split against the line as it stands then. Letting go of the input clears
## the latch too.
@export var lock_on_relatch_degrees: float

## The fraction of a blocked hit's damage that Block takes off: a blocked hit deals the rest.
## 1 would take all of it, and 0 none.
@export var block_damage_reduction: float

## How much Stamina each blocked hit spends, however hard it hits.
@export var block_stamina_cost: float

## How wide, in degrees, the front is that Block covers, centred on the way Almos faces:
## half of it either side. A hit from outside it is not blocked.
@export var block_arc_degrees: float

## Walking speed while blocking, in pixels per second.
@export var block_walk_speed: float

## How much of the usual Stamina refill comes back while blocking: stamina_refill_rate
## times this. Only the refill is slowed; the pause before it starts is the same.
@export var block_stamina_refill_factor: float

## How long, in seconds, a Guard break lasts: the time Almos is left open after a blocked hit
## takes the last of his Stamina, standing still and unable to Roll, attack or block. A time
## that is not a whole number of physics frames lasts until the next whole frame.
@export var guard_break_duration: float

## How many physics frames the window of a Parry lasts. It opens on the frame of the press,
## which counts as the first. A hit in front of Almos in the window is parried.
@export var parry_window_frames: int

## How many physics frames Almos stands open after a window that caught nothing, unable to
## Roll, attack, Block or Parry, with every hit landing in full.
@export var parry_recovery_frames: int

## How much Stagger each Parry builds on the attacker whose hit it parries. It is Almos's
## number, not the Weapon's.
@export var parry_stagger: float

## How wide, in degrees, the front is that a Parry covers, centred on the way Almos faces:
## half of it either side. A hit from outside it is not parried.
@export var parry_arc_degrees: float

## How long, in seconds, a Jump lasts, from leaving the ground to coming down. He carries
## the speed he had on the frame he took off for all of it, so this and that speed are how
## far a Jump reaches.
@export var jump_duration: float

## How high, in pixels, his placeholder rises at the top of a Jump. It is how the Jump looks:
## the height levels do not depend on it.
@export var jump_height: float

## How much Stamina a Jump spends when it starts. It may be zero, and then a Jump needs no
## Stamina at all.
@export var jump_stamina_cost: float

## How close to the centre of a Checkpoint, in pixels, Almos must be to rest at it.
@export var rest_reach: float

## How long, in seconds, a Checkpoint flashes when Almos rests at it.
@export var rest_flash_duration: float
