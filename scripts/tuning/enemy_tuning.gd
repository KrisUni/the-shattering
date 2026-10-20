class_name EnemyTuning
extends Resource
## Tuning numbers for one kind of enemy and its attacks. The values live in the enemy's data
## file, such as data/training_enemy.tres, not here.

## The kinds of attack an enemy can make. Each has its own AttackData and reach in the tuning,
## which attack_of and reach_of give.
enum AttackKind {
	## Its plain attack: attack and attack_reach.
	STRIKE,
	## A Low attack, which travels along the ground: low_attack and low_attack_reach.
	LOW,
	## An Unblockable attack, which neither Block nor Parry deals with: unblockable_attack and
	## unblockable_attack_reach.
	UNBLOCKABLE,
}

## The order it makes its attacks in, over and over. Each time it starts an attack it makes the
## next kind in the list and moves on; a Break neither resets the order nor skips a place in it.
## Must not be empty.
@export var attack_pattern: Array[AttackKind]

## How much Experience killing the enemy gives.
@export var experience: int

## The most Health the enemy can have. A full bar is this much.
@export var health_maximum: float

## How fast it walks towards its target, in pixels per second.
@export var move_speed: float

## How wide, in degrees, its Sight is, centred on the way it faces: half of it either side.
@export var sight_arc_degrees: float

## How far, in pixels, its Sight reaches when Almos stands in full light (a light value of 1).
@export var sight_length_full: float

## How far, in pixels, its Sight reaches when Almos stands in the dark (a light value of 0). It
## is no longer than sight_length_full; in between, the length follows the light value.
@export var sight_length_dark: float

## For how many physics frames in a row Almos has to stay out of its Sight (a Sound hunter: out
## of earshot) for its Pursuit to end. Seeing him again starts the count over.
@export var lose_sight_frames: int

## How much Health it recovers each second while it walks back to its post and stands at it. It
## recovers none in Pursuit.
@export var health_recovery_rate: float

## Whether it is a Sound hunter: it notices Almos by the Noise he makes, and never by Sight.
## Any other enemy ignores Noise.
@export var sound_hunter := false

## How close to its target, in pixels, it stops walking and attacks.
@export var attack_range: float

## How far from its centre, in pixels, its Strike reaches: the far edge of the box its Hitbox
## hurts with, along the direction it strikes. The box keeps its width and height from the
## scene and is placed so that its far edge is this far out. It hurts what its box overlaps, so
## the nearest edge of whatever it swings at, which is a Hurtbox radius short of attack_range
## from its centre, must not be farther than this, or it swings from where it cannot hit.
@export var attack_reach: float

## Its Strike, the attack it makes first. The startup frames are its wind-up. Enemies have no
## Stamina, so the attack's stamina_cost is not used, and nor is its stagger: Almos has no Stagger
## to build. The same goes for every attack below.
@export var attack: AttackData

## How far from its centre, in pixels, its Low attack reaches: the far edge of the box its Low
## Hitbox hurts with, as attack_reach is for the Strike. The box keeps its width and height from
## the scene.
@export var low_attack_reach: float

## Its Low attack, which travels along the ground and misses a target that is in the air.
@export var low_attack: AttackData

## How far from its centre, in pixels, its Unblockable attack reaches: the far edge of the box its
## Unblockable Hitbox hurts with, as attack_reach is for the Strike. The box keeps its width and
## height from the scene.
@export var unblockable_attack_reach: float

## Its Unblockable attack, which goes through Block and Parry in full. Only a Roll, or a Jump
## that carries the target out of its reach, avoids it. Its startup frames are a long, warned
## wind-up.
@export var unblockable_attack: AttackData

## How many physics frames the white flash at the start of its Unblockable attack's wind-up
## lasts. It must be shorter than the wind-up, whose rest keeps the tint of its own.
@export var unblockable_flash_frames: int

## The most Stagger the enemy can have. A full meter is this much.
@export var stagger_capacity: float

## How much Stagger drains each second once the pause is over.
@export var stagger_drain_rate: float

## How long, in seconds, nothing has to press the enemy before its Stagger starts to drain.
@export var stagger_drain_pause: float

## How long, in physics frames, a Break lasts, counting the frame its Stagger fills in. It is free
## again on the frame after the last.
@export var break_frames: int

## How wide, in degrees, its front is, centred on the way it faces: half of it either side. A
## hit from outside it is a hit from behind.
@export var front_arc_degrees: float

## How much Stagger a hit from behind builds on top of what the attack builds itself.
@export var behind_stagger: float


## How far its Sight reaches when Almos stands in this much light (0 to 1).
func sight_length_at(light: float) -> float:
	return lerpf(sight_length_dark, sight_length_full, clampf(light, 0.0, 1.0))


## The attack of this kind.
func attack_of(kind: AttackKind) -> AttackData:
	match kind:
		AttackKind.LOW:
			return low_attack
		AttackKind.UNBLOCKABLE:
			return unblockable_attack
	return attack


## How far from its centre the attack of this kind reaches.
func reach_of(kind: AttackKind) -> float:
	match kind:
		AttackKind.LOW:
			return low_attack_reach
		AttackKind.UNBLOCKABLE:
			return unblockable_attack_reach
	return attack_reach

## How heavy it is. Shove and Pull move it only if this is no more than the greatest Weight he can
## move (see PlayerTuning.greatest_weight); a heavier one shudders and stays where it is.
@export var weight: float

## How much Stagger it builds when a Shove or a Pull slides it into a wall. A slam takes no Health.
@export var wall_stagger: float
