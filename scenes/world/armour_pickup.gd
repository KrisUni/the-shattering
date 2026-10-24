class_name ArmourPickup
extends Node2D
## A piece of Armour lying in a room, drawn as a placeholder plate. It holds the Armour's data
## file in `armour`, which is what Almos wears when he takes it with a tap of Interact; the pickup
## is then gone. The Armour is a placeholder until Armour and Load is done, so wearing it has no
## effect. It is in the group "armour_pickups", which is where Almos looks for one, and has no
## body, so he walks through it, as through a Checkpoint.

## The Armour lying here: its data file, such as data/almos_armour.tres.
@export var armour: ArmourData
