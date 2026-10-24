extends Node2D
## The test room: a floor, walls, Almos, a Checkpoint and the HUD. Killing an enemy gives Almos
## its Experience. Resting at the Checkpoint makes it his return point and brings back every
## ordinary enemy the room started with as new; a named enemy stays dead.
##
## When Almos's Health reaches zero he lies limp for a while (see Almos), and when that is over
## the room sees to his Death: it takes all his Experience and leaves Remains holding it where he
## fell, in place of any it already had, or none if he had none; it brings back every ordinary
## enemy, as a rest does; it undoes the changes made to the world since the last rest (a path blocker
## that burnt since is closed again); it puts the Weapon and Armour pickups back as they lay at the
## last rest, or at the start until the first (one dropped since is gone, one taken since lies where
## it lay), so that the gear he is given back is not also lying on the floor; and it sends him back
## to the return point. The Remains stay where they are through a rest.

const REMAINS_SCENE := preload("res://scenes/world/remains.tscn")
const WEAPON_PICKUP_SCENE := preload("res://scenes/world/weapon_pickup.tscn")
const ARMOUR_PICKUP_SCENE := preload("res://scenes/world/armour_pickup.tscn")

## Where Almos goes back to, in global coordinates: the Checkpoint he last rested at, or where he
## started in the room until he first rests. Read only.
var return_point: Vector2:
	get:
		return _return_point

@onready var _almos: Almos = $Almos

var _return_point := Vector2.ZERO
# Where Almos's Health last reached zero, which is where the Remains of that Death are left.
var _fall_place := Vector2.ZERO
# The set of Remains in the room, if there is one.
var _remains: Remains
# The ordinary enemies the room started with, each as the place and the numbers it was made
# with, and the enemy that is alive in its place now.
var _ordinary_enemies: Array[OrdinaryEnemy] = []
# The Weapon and Armour pickups lying in the room at the last rest (at the start, until the first),
# each as the place and the data it lies with.
var _pickups_at_the_last_rest: Array[PickupSpot] = []


# An ordinary enemy as the room first had it, to make it again as new.
class OrdinaryEnemy:
	var scene: PackedScene
	var parent: Node
	var node_name: StringName
	var position: Vector2
	var post_facing: Vector2
	var tuning: EnemyTuning
	var target: Node2D
	# The enemy that stands in this place now. It is gone once killed, until a rest brings it back.
	var current: Node


# A Weapon or Armour pickup as it lay, to lay it again.
class PickupSpot:
	var scene: PackedScene
	var parent: Node
	var node_name: StringName
	var position: Vector2
	var weapon: WeaponData
	var armour: ArmourData
	var id: StringName


func _ready() -> void:
	_return_point = _almos.global_position
	_almos.rested.connect(_on_almos_rested)
	_almos.died.connect(_on_almos_fell)
	_almos.death_pause_over.connect(_on_almos_death_pause_over)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		_watch_enemy(enemy)
		if not enemy.named:
			_remember(enemy)
	_remember_the_pickups()


## Has the enemy give Almos its Experience when it dies. Called for each enemy the room starts
## with, and again for any it brings back.
func _watch_enemy(enemy: Node) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))


# Notes where an ordinary enemy starts and what it is made with, so that a rest can make it again.
func _remember(enemy: Node) -> void:
	var start := OrdinaryEnemy.new()
	start.scene = load(enemy.scene_file_path)
	start.parent = enemy.get_parent()
	start.node_name = enemy.name
	start.position = enemy.position
	start.post_facing = enemy.post_facing
	start.tuning = enemy.tuning
	start.target = enemy.target
	start.current = enemy
	_ordinary_enemies.append(start)


# Notes the Weapon and Armour pickups lying in the room now, in place of those noted before, so
# that a Death can lay them again. One taken, and so on its way out, is not noted.
func _remember_the_pickups() -> void:
	_pickups_at_the_last_rest.clear()
	for pickup in _pickups_in_the_room():
		var spot := PickupSpot.new()
		spot.parent = pickup.get_parent()
		spot.node_name = pickup.name
		spot.position = pickup.position
		spot.id = pickup.id
		if pickup is WeaponPickup:
			spot.scene = WEAPON_PICKUP_SCENE
			spot.weapon = pickup.weapon
		else:
			spot.scene = ARMOUR_PICKUP_SCENE
			spot.armour = pickup.armour
		_pickups_at_the_last_rest.append(spot)


# Every Weapon and Armour pickup in the room that is not on its way out.
func _pickups_in_the_room() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("weapon_pickups") + get_tree().get_nodes_in_group("armour_pickups"):
		if is_ancestor_of(node) and not node.is_queued_for_deletion():
			found.append(node)
	return found


# Every pickup lying in the room is taken out of the tree at once, so that Almos cannot take it in
# this frame, and those noted at the last rest are laid again where they lay. A pickup noted
# with an id is not made again if WorldState has it taken, as it frees itself when it is made.
func _put_the_pickups_back() -> void:
	for pickup in _pickups_in_the_room():
		pickup.get_parent().remove_child(pickup)
		pickup.queue_free()
	for spot in _pickups_at_the_last_rest:
		if not is_instance_valid(spot.parent):
			continue
		var pickup = spot.scene.instantiate()
		pickup.name = spot.node_name
		pickup.position = spot.position
		pickup.id = spot.id
		if spot.weapon != null:
			pickup.weapon = spot.weapon
		else:
			pickup.armour = spot.armour
		spot.parent.add_child(pickup)


# Almos rested: the Checkpoint is his return point, what has changed in the world is saved, the
# pickups lying in the room are noted, and every ordinary enemy comes back as new.
func _on_almos_rested(checkpoint: Checkpoint) -> void:
	_return_point = checkpoint.global_position
	WorldState.commit()
	_remember_the_pickups()
	_bring_back_the_ordinary_enemies()


# Every torch drawn burns again and every ordinary enemy comes back as new, whether Almos rested
# or died. Every Fire goes out: a Hiding spot or fungus that burnt is whole again, and a path
# blocker that caught is open if WorldState has saved that. One still alive is taken out
# of the tree at once, so that it leaves the "enemies" group in this frame, and a fresh one is made
# at its starting place. A named enemy is not in the list, so it is left as it is. A fresh enemy is
# added last, so that it comes after Almos in the tree: he is processed before enemies, and the
# frame guarantees of his Parry rely on it.
func _bring_back_the_ordinary_enemies() -> void:
	for torch in get_tree().get_nodes_in_group("torches"):
		torch.relight()
	for flammable in get_tree().get_nodes_in_group("flammables"):
		flammable.come_back()
	for start in _ordinary_enemies:
		if is_instance_valid(start.current):
			start.current.get_parent().remove_child(start.current)
			start.current.queue_free()
		var fresh = start.scene.instantiate()
		fresh.name = start.node_name
		fresh.position = start.position
		fresh.post_facing = start.post_facing
		fresh.tuning = start.tuning
		fresh.target = start.target
		start.parent.add_child(fresh)
		_watch_enemy(fresh)
		start.current = fresh


# Almos fell: the Remains are to be left here, once he is returned.
func _on_almos_fell(place: Vector2) -> void:
	_fall_place = place


# The pause of Almos's Death is over. The Experience he carries is the Remains' now, at the place he
# fell, and he is sent back to the return point with the world as it was at the last rest and the
# ordinary enemies back as new and the pickups as they lay. The Remains are made after he is back,
# and notice him from the next frame, so that a return point close enough to them has him recover
# them at once. The old Remains, if any, are destroyed, whether or not new ones are left.
func _on_almos_death_pause_over() -> void:
	var lost := _almos.experience.take_all()
	WorldState.roll_back()
	_bring_back_the_ordinary_enemies()
	_put_the_pickups_back()
	_almos.return_to(_return_point)
	_leave_remains(lost, _fall_place)


# The room's one set of Remains is now this much Experience at this place: the old set is destroyed
# at once, and none is left when there is no Experience.
func _leave_remains(amount: int, place: Vector2) -> void:
	if is_instance_valid(_remains):
		if _remains.is_inside_tree():
			_remains.get_parent().remove_child(_remains)
		_remains.queue_free()
	_remains = null
	if amount <= 0:
		return
	_remains = REMAINS_SCENE.instantiate()
	_remains.position = place
	_remains.amount = amount
	add_child(_remains)


func _on_enemy_died(enemy: Node) -> void:
	_almos.experience.gain(enemy.tuning.experience)
