class_name WeaponData
extends Resource
## The attacks of one Weapon and the one number they share. The values live in the Weapon's
## data file, such as data/sword.tres, not here.

## How far from Almos's centre, in pixels, the Weapon's strike reaches: the far edge of the box
## his sword Hitbox hurts with, along the direction he swings. The box keeps its width and
## height from the scene and is placed so that its far edge is this far out. Every attack of
## the Weapon reaches this far.
@export var reach: float

## The swings of the Light attack combo, in the order they chain: the first press makes the
## first swing, a press at the end of each swing chains into the next, and after the last
## the combo starts over at the first.
@export var light_attacks: Array[AttackData]

## The Heavy attack.
@export var heavy_attack: HeavyAttackData

## The Jump attack: the Heavy attack press made in mid-air, which strikes as he lands. Its
## startup is the rest of the Jump, so its startup_frames stays 0: they count from the landing,
## so a number above 0 would delay the strike past the frame he lands in. The active frames
## begin on that frame, then the recovery. It builds more Stagger than any Heavy attack, and is
## paid for with its stamina_cost when it begins.
@export var jump_attack: AttackData

## How close to Almos's centre, in pixels, the centre of a broken enemy must be for a Light
## attack press to make the Critical hit instead of a Light swing.
@export var critical_range: float

## The Critical hit, which Almos makes on a broken enemy. It uses the Weapon's reach. It
## spends no Stamina, so its stamina_cost is not used, and it builds no Stagger.
@export var critical_attack: AttackData

## A press of an attack button in the last this many physics frames of an attack's recovery
## is remembered, and the attack it asked for begins the moment the recovery ends.
@export var attack_buffer_frames: int
