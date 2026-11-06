extends Node
## How the game feels to play, apart from its rules: the pace it runs at, and the hit-stop, the
## moment the game freezes when a blow lands so that it reads as heavy. Neither changes what happens
## on any physics frame, only how long frames take in real time.
##
## The pace: the whole game runs at SPEED of real time, every movement, swing, animation and timer
## alike. It slows the tick rate and the clock together, so each physics frame is the same 1/60 of
## a second of game time it always was and every number in the tuning keeps its meaning.
##
## Both are off under the test runner (GUT), which steps the game a frame at a time at its own fixed
## rate; a test can switch the hit-stop on to watch it.

## The pace of the game, as a share of real time.
const SPEED := 0.85
## The tick rate the game's numbers are counted in: one physics frame is 1/BASE_TICKS of a second.
const BASE_TICKS := 60

## How long the game freezes, in real seconds: when a blow lands, when it is a Critical hit, when
## a guard is broken (a Break), and when a Parry turns a blow aside.
const STOP_HIT := 0.05
const STOP_CRITICAL := 0.09
const STOP_BREAK := 0.11
const STOP_PARRY := 0.08

## Whether the hit-stop freezes the game when a blow lands.
var hit_stop := true

var _stopping := false
var _stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _under_the_test_runner():
		hit_stop = false
		return
	Engine.time_scale = SPEED
	Engine.physics_ticks_per_second = roundi(BASE_TICKS * SPEED)


## Whether the game is frozen in a hit-stop now.
func stopped() -> bool:
	return _stopping


## A blow landed: on Almos or an enemy, blocked or not.
func blow_landed(critical: bool) -> void:
	freeze(STOP_CRITICAL if critical else STOP_HIT)


## A guard was broken through: a Break.
func guard_broken() -> void:
	freeze(STOP_BREAK)


## A Parry turned a blow aside.
func parried() -> void:
	freeze(STOP_PARRY)


## Freezes the game for this long, in real seconds, or until a longer freeze already under way ends.
func freeze(seconds: float) -> void:
	if not hit_stop or not is_inside_tree():
		return
	var until := Time.get_ticks_msec() + roundi(seconds * 1000.0)
	if _stopping and until <= _stop_until:
		return
	_stop_until = until
	if not _stopping:
		_stopping = true
		get_tree().paused = true


func _process(_delta: float) -> void:
	if _stopping and Time.get_ticks_msec() >= _stop_until:
		_stopping = false
		get_tree().paused = false


static func _under_the_test_runner() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.ends_with("gut_cmdln.gd"):
			return true
	return false
