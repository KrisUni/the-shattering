class_name Flammable
extends Area2D
## A flammable thing: it catches Fire when a fireball hits it or a lit torch in Almos's hand is
## swung into it. Once it burns it spreads Fire, after the spread delay, to every flammable thing
## within the spread radius, and burns for the burn time, then it is burnt out: gone, with no look
## and no collision. While it burns it gives light, as a lit torch does (it has light and lights), and
## is in the group "fires" for those that read light. It is never in the group "torches", so Flame
## draw never finds it, and Fire never draws, puts out or relights a torch.
##
## It is on the physics layer flammable, where a fireball and the torch's Hitbox find it. It is in
## the group "flammables", which is where Fire looks for the things to spread to. Coming back after
## it is burnt out is not its business yet.
##
## While it burns it hurts, in ticks, every Hurtbox of Almos or an enemy that overlaps it: the tick
## damage every tick interval, the first one tick interval after it catches, none once it is burnt
## out. The damage is unblockable, builds no Stagger, and misses whoever is untouchable at that
## moment. Each burning thing ticks on its own clock, so overlapping ones each hurt.

## Emitted once, when it catches.
signal caught

## Emitted once, when the burn time is over and it is burnt out. (The property burnt_out says
## whether it is.)
signal burned_out

## Emitted at each tick, after the damage is dealt.
signal ticked

## What the thing is, for what Fire does to it afterwards.
enum Kind { HIDING_SPOT, FUNGUS, PATH_BLOCKER }

## What the thing is.
@export var kind := Kind.HIDING_SPOT

## The numbers of Fire. They live in data/fire.tres.
@export var tuning: FireTuning = preload("res://data/fire.tres")

## What is drawn of the thing itself, hidden once it is burnt out. Optional.
@export var look: CanvasItem

## The gameplay light it gives within its light radius while it burns.
var light: float:
	get:
		return tuning.light

## Whether it burns now.
var burning: bool:
	get:
		return _burning

## Whether it has burnt out: gone for now.
var burnt_out: bool:
	get:
		return _burnt_out

## How many ticks it has made since it caught.
var ticks: int:
	get:
		return _ticks

var _burning := false
var _burnt_out := false
var _burned_for := 0.0
var _spread := false
var _ticks := 0

@onready var _flame: CanvasItem = get_node_or_null("Flame")


func _enter_tree() -> void:
	add_to_group(&"flammables")


func _ready() -> void:
	_show()


func _physics_process(delta: float) -> void:
	if not _burning:
		return
	_burned_for += delta
	_tick()
	if not _spread and _burned_for >= tuning.spread_delay:
		_spread = true
		_spread_fire()
	if _burned_for >= tuning.burn_time:
		_burn_out()


## It is set alight. Says whether it caught: a thing already burning or burnt out is left as it is.
func ignite() -> bool:
	if _burning or _burnt_out:
		return false
	_burning = true
	_burned_for = 0.0
	_spread = false
	_ticks = 0
	add_to_group(&"fires")
	_show()
	caught.emit()
	return true


## Whether it lights this point (global coordinates): it burns and the point is within its light
## radius, the edge included.
func lights(point: Vector2) -> bool:
	return _burning and global_position.distance_to(point) <= tuning.light_radius


# Ticks that are due: each hurts whoever stands in the thing, while it has not burnt out.
func _tick() -> void:
	if tuning.tick_interval <= 0.0:
		return
	while _burned_for < tuning.burn_time and _burned_for >= (_ticks + 1) * tuning.tick_interval:
		_ticks += 1
		for area in get_overlapping_areas():
			var hurtbox := area as Hurtbox
			if hurtbox != null:
				hurtbox.hurt_damage_only(tuning.damage_per_tick, global_position, true)
		ticked.emit()


# Sets alight every other flammable thing within the spread radius.
func _spread_fire() -> void:
	for node in get_tree().get_nodes_in_group(&"flammables"):
		var other := node as Flammable
		if other != null and other != self and global_position.distance_to(other.global_position) <= tuning.spread_radius:
			other.ignite()


# The burn time is over: it is gone, with no look and nothing to touch.
func _burn_out() -> void:
	_burning = false
	_burnt_out = true
	remove_from_group(&"fires")
	collision_layer = 0
	set_deferred(&"monitorable", false)
	_show()
	burned_out.emit()


# The flame shows while it burns; once burnt out nothing of it shows.
func _show() -> void:
	visible = not _burnt_out
	if look != null:
		look.visible = not _burnt_out
	if _flame != null:
		_flame.visible = _burning
