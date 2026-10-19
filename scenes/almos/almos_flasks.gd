class_name AlmosFlasks
extends Node
## Almos's Flasks, so far the Health Flask. A Sip spends one charge at once and restores the share
## of the Health maximum the tuning gives at the end of sip_duration. It cannot be cancelled, but a
## hit before the end wastes the charge: any loss of Health while it lasts, damage-only Fire ticks
## included, ends the Sip with nothing restored. The Sip that falls out of a Death or a Hiding spot
## is wasted the same way.
##
## Almos decides when he is free to Sip and calls sip(); he advances the Sip every physics frame.

## Emitted whenever the charges change.
signal changed

## The numbers of the Flasks. Almos's scene gives the shipped ones.
@export var tuning: FlaskTuning

## What a Sip restores, and whose loss of Health wastes a Sip.
@export var health: Health

## How many charges the Health Flask holds now.
var health_charges: int:
	get:
		return _health_charges

## How many charges the Health Flask holds when full. Checkpoints refill it to this.
var health_charges_maximum: int:
	get:
		return _health_charges_maximum

## Whether a Sip is under way: from the frame it begins in to the frame it ends in, the latter
## excluded.
var sipping: bool:
	get:
		return _sipping

var _health_charges := 0
var _health_charges_maximum := 0
var _sipping := false
var _sipped_for := 0.0
var _health_seen := 0.0


func _ready() -> void:
	_health_charges_maximum = tuning.health_charges
	_health_charges = _health_charges_maximum
	_health_seen = health.current
	health.changed.connect(_on_health_changed)


## Begins a Sip, spending one charge, and says whether it did. With no charge left, or a Sip
## already under way, it does nothing and spends nothing.
func sip() -> bool:
	if _sipping or _health_charges <= 0:
		return false
	_health_charges -= 1
	_sipping = true
	_sipped_for = 0.0
	changed.emit()
	return true


## Lets this many seconds of a Sip go by. At its end the Health comes back. The time is counted in
## summed frame lengths compared through Almos.TIME_SLACK, as his other durations are.
func advance(delta: float) -> void:
	if not _sipping:
		return
	_sipped_for += delta
	if _sipped_for >= tuning.sip_duration - Almos.TIME_SLACK:
		_sipping = false
		health.heal(health.maximum * tuning.health_restore_share)


## Every charge is back. Resting at a Checkpoint and being returned after a Death do this.
func refill() -> void:
	_health_charges = _health_charges_maximum
	changed.emit()


## Any Sip is over at once, its charge spent and nothing restored. Called when Almos falls or is
## returned, or gets into a Hiding spot.
func reset() -> void:
	_sipping = false
	_sipped_for = 0.0


# Health went down while a Sip was under way: the charge is wasted. The level it is seen at is
# followed through every change, so that only a loss counts, not a refill or a heal.
func _on_health_changed() -> void:
	if health.current < _health_seen:
		reset()
	_health_seen = health.current
