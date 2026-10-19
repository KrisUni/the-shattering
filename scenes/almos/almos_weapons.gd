class_name AlmosWeapons
extends Node
## The Weapons Almos carries, and the one in hand. A Weapon picked up goes to the end of the
## list, and comes to hand only if his hands were empty. Switching cycles through the list in
## the order the Weapons were picked up, and wraps. Dropping takes the Weapon in hand out of the
## list, and the next one after it comes to hand; with none left his hands are empty. There is
## no limit to how many he carries. Unarmed is not a stop in the cycle: it is only what empty
## hands are.
##
## This only keeps the list. Almos reads the buttons, hands the Weapon in hand to his attacks
## and leaves a dropped Weapon on the ground.

## Emitted when what he carries or what is in hand changes: after a pick-up, a switch to
## another Weapon, a replacement and a drop.
signal changed

## The Weapons he carries, in the order they were picked up. A copy: changing it changes
## nothing.
var carried: Array[WeaponData]:
	get:
		return _carried.duplicate()

## The Weapon in hand, or null when his hands are empty.
var in_hand: WeaponData:
	get:
		return _carried[_in_hand_index] if _in_hand_index >= 0 else null

var _carried: Array[WeaponData] = []
# Where the Weapon in hand is in the list, or -1 when none is. The same data file can be
# carried twice, so the Weapon is not found by what it is.
var _in_hand_index := -1


## Adds the Weapon to those carried, after the others. It comes to hand if his hands are empty.
## Nothing is picked up when there is no Weapon.
func pick_up(weapon: WeaponData) -> void:
	if weapon == null:
		return
	_carried.append(weapon)
	if _in_hand_index < 0:
		_in_hand_index = _carried.size() - 1
	changed.emit()


## Puts the next carried Weapon in hand, after the one in hand, and the first after the last.
## With one Weapon or none there is nothing to switch to, and nothing changes.
func switch_to_next() -> void:
	if _carried.size() < 2:
		return
	_in_hand_index = (_in_hand_index + 1) % _carried.size()
	changed.emit()


## Takes the Weapon in hand out of those carried and returns it, or null if his hands are empty.
## The next Weapon in the list after it comes to hand, the first if it was the last; with none
## left his hands are empty.
func drop() -> WeaponData:
	if _in_hand_index < 0:
		return null
	var dropped := _carried[_in_hand_index]
	_carried.remove_at(_in_hand_index)
	if _carried.is_empty():
		_in_hand_index = -1
	else:
		_in_hand_index = _in_hand_index % _carried.size()
	changed.emit()
	return dropped


## Swaps the Weapon in hand for another, in the same place in the list and still in hand, such as
## a torch that has been drawn for the unlit club it becomes. Nothing changes when his hands are
## empty or there is no Weapon to swap in.
func replace_in_hand(weapon: WeaponData) -> void:
	if weapon == null or _in_hand_index < 0:
		return
	_carried[_in_hand_index] = weapon
	changed.emit()
