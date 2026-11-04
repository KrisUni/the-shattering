class_name WeaponRack
extends StaticBody2D
## A weapon rack, solid on its footprint. It may hold a Weapon that can be taken: a WeaponPickup
## child (hidden, since the rack draws it), which Almos takes up with a tap of Interact in front of
## the rack, as any pickup. Once it is gone, now or in an earlier visit, the rack is drawn with its
## peg empty. Taking it rouses the enemy set in `rouses`, such as the knight asleep in Radio/Officers:
## he wakes and is after Almos at once, wherever he looks. A pickup that frees itself because it was
## taken before rouses nobody.

const FULL := preload("res://assets/dungeons/furniture/weapon_rack.png")
const TAKEN := preload("res://assets/dungeons/furniture/weapon_rack_taken.png")

## The enemy that taking the rack's Weapon rouses, or empty for none.
@export var rouses: NodePath

@onready var _art: Sprite2D = $Look/Art


func _ready() -> void:
	var pickup := _pickup()
	if pickup == null or pickup.is_queued_for_deletion():
		_art.texture = TAKEN
		return
	_art.texture = FULL
	pickup.tree_exiting.connect(_on_pickup_gone.bind(pickup.id))


## Whether its Weapon is gone from it.
func is_empty() -> bool:
	return _art.texture == TAKEN


func _pickup() -> WeaponPickup:
	for child in get_children():
		if child is WeaponPickup:
			return child
	return null


# The pickup leaves the tree when it is taken, and when the Room is freed: only a taking, which
# WorldState has noted by then, empties the rack and rouses anyone.
func _on_pickup_gone(id: StringName) -> void:
	if id != &"" and not WorldState.is_taken(id):
		return
	_art.texture = TAKEN
	var sleeper := get_node_or_null(rouses)
	if sleeper != null and sleeper.has_method(&"rouse"):
		sleeper.rouse()
