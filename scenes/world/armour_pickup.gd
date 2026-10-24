class_name ArmourPickup
extends Node2D
## A piece of Armour lying in a room, drawn as a placeholder plate. It holds the Armour's data
## file in `armour`. It is a placeholder until Armour and Load is done: Almos cannot take it up
## yet. It is in the group "armour_pickups" and has no body, so he walks through it, as through
## a Checkpoint.

## The Armour lying here: its data file, such as data/almos_armour.tres.
@export var armour: ArmourData
