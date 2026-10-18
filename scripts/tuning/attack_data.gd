class_name AttackData
extends Resource
## The numbers of one attack: how long each part of the swing lasts, what it does and what
## it costs. The values live in the data file of the Weapon the attack belongs to, such as
## data/sword.tres, not here.
##
## An attack runs in three parts, one after the other and counted in whole physics frames
## (60 to the second). Startup is the wind-up before it can hurt anyone. Active is when the
## Hitbox is on. Recovery is the follow-through, after which Almos is free again.
##
## The functions below put a frame into one of the three parts. They are the one timeline
## every attacker follows, Almos and enemies alike. A frame is its number in the attack,
## counted from 0 for the first physics frame the attack is processed in; before that, and
## from the frame after the last one, there is no attack and the frame is in none of the
## parts.

## How many physics frames pass from the attack beginning to its Hitbox switching on.
@export var startup_frames: int

## How many physics frames its Hitbox stays on.
@export var active_frames: int

## How many physics frames pass after the Hitbox switches off before Almos is free again.
@export var recovery_frames: int

## How much Health a hit takes off.
@export var damage: float

## How much Stamina the attack spends when it begins.
@export var stamina_cost: float

## How much Stagger a hit builds on whoever it lands on. Light attacks build none. Only
## Almos's attacks use it: the enemy's attack builds none on Almos.
@export var stagger: float


## How many physics frames the whole attack lasts: its startup, active and recovery frames.
func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


## Whether this frame of the attack is one of its startup frames.
func is_winding_up(frame: int) -> bool:
	return frame >= 0 and frame < startup_frames


## Whether this frame of the attack is one of its active frames, when its Hitbox is on.
func is_active(frame: int) -> bool:
	return frame >= startup_frames and frame < startup_frames + active_frames


## Whether this frame of the attack is one of its recovery frames.
func is_recovering(frame: int) -> bool:
	return frame >= startup_frames + active_frames and frame < total_frames()
