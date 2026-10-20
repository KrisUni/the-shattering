class_name AlmosFlasks
extends Node
## Almos's Flasks, so far the Health Flask. A Sip spends one charge at once and restores the share
## of the Health maximum the tuning gives at the end of sip_duration. It cannot be cancelled, but a
## hit before the end wastes the charge: any loss of Health while it lasts, damage-only Fire ticks
## included, ends the Sip with nothing restored. The Sip that falls out of a Death or a Hiding spot
## is wasted the same way.
##
## Almos decides when he is free to Sip and calls sip(); he advances the Sip every physics frame.

## The Mana Flask is carried from the start, but it stays empty and unusable until Almos has a Mana
## bar: has_mana_bar is the one place that says so. Gaining the bar does not fill the Flask: it holds
## its charges from the next Checkpoint refill on.

## Emitted whenever the charges change.
signal changed

## The numbers of the Flasks. Almos's scene gives the shipped ones.
@export var tuning: FlaskTuning

## What a Sip restores, and whose loss of Health wastes a Sip.
@export var health: Health

## What a Mana Sip restores. Without it, or until it is granted, there is no Mana bar.
@export var mana: Mana

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

## How many charges the Mana Flask holds now: none while Almos has no Mana bar.
var mana_charges: int:
	get:
		return _mana_charges

## How many charges the Mana Flask holds when full, which it is not while he has no Mana bar.
var mana_charges_maximum: int:
	get:
		return _mana_charges_maximum

## Whether Almos has his Mana bar, which is Mana's to say. Once he has it the Mana Flask fills at a
## Checkpoint and can be sipped.
var has_mana_bar: bool:
	get:
		return mana != null and mana.granted

var _health_charges := 0
var _health_charges_maximum := 0
var _mana_charges := 0
var _mana_charges_maximum := 0
var _sipping := false
# Whether the Sip under way is from the Mana Flask.
var _sipping_mana := false
var _sipped_for := 0.0
var _health_seen := 0.0


func _ready() -> void:
	_health_charges_maximum = tuning.health_charges
	_health_charges = _health_charges_maximum
	_mana_charges_maximum = tuning.mana_charges
	_health_seen = health.current
	health.changed.connect(_on_health_changed)


## Begins a Sip, spending one charge, and says whether it did. With no charge left, or a Sip
## already under way, it does nothing and spends nothing.
func sip() -> bool:
	if _sipping or _health_charges <= 0:
		return false
	_health_charges -= 1
	_sipping = true
	_sipping_mana = false
	_sipped_for = 0.0
	changed.emit()
	return true


## A Sip of the Mana Flask, as a Sip of the Health Flask but for the Mana bar: does nothing and
## costs nothing while he has no Mana bar, with no charge left or with a Sip under way. Says whether
## a Sip began.
func sip_mana() -> bool:
	if not has_mana_bar or _sipping or _mana_charges <= 0:
		return false
	_mana_charges -= 1
	_sipping = true
	_sipping_mana = true
	_sipped_for = 0.0
	changed.emit()
	return true


## Raises how many charges both Flasks hold by this many, a Flask upgrade's worth. The Health Flask
## gets the new charges at once; the Mana Flask holds its own only once he has a Mana bar.
func add_charges(count: int = 1) -> void:
	_health_charges_maximum += count
	_health_charges += count
	_mana_charges_maximum += count
	if has_mana_bar:
		_mana_charges += count
	changed.emit()


## Lets this many seconds of a Sip go by. At its end the Health comes back, or the Mana of a Mana Sip. The time is counted in
## summed frame lengths compared through Almos.TIME_SLACK, as his other durations are.
func advance(delta: float) -> void:
	if not _sipping:
		return
	_sipped_for += delta
	if _sipped_for >= tuning.sip_duration - Almos.TIME_SLACK:
		_sipping = false
		if _sipping_mana:
			mana.restore(mana.maximum * tuning.mana_restore_share)
		else:
			health.heal(health.maximum * tuning.health_restore_share)


## Every charge is back, the Mana Flask's only if he has a Mana bar. Resting at a Checkpoint and
## being returned after a Death do this.
func refill() -> void:
	_health_charges = _health_charges_maximum
	_mana_charges = _mana_charges_maximum if has_mana_bar else 0
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
