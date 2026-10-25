class_name Flammable
extends Area2D
## A flammable thing: it catches Fire when a fireball hits it or a lit torch in Almos's hand is
## swung into it. Once it burns it spreads Fire, after the spread delay, to every flammable thing
## within the spread radius, and burns for the burn time, then it is burnt out: gone, with no look
## and no collision. (A creature, such as a Root crawler, is the exception: when its burn time is
## over it stops burning, as extinguish leaves a thing, and is never burnt out.) While it burns it gives light, as a lit torch does (it has light and lights), and
## is in the group "fires" for those that read light. It is never in the group "torches", so Flame
## draw never finds it, and Fire never draws, puts out or relights a torch.
##
## It is on the physics layer flammable, where a fireball and the torch's Hitbox find it. It is in
## the group "flammables", which is where Fire looks for the things to spread to. When enemies
## return (a rest, or the return after a Death) the room calls come_back: every Fire goes out, a
## Hiding spot or fungus is whole again, and a path blocker that has caught stays burnt out for good.
##
## While it burns it hurts, in ticks, every Hurtbox of Almos or an enemy that overlaps it: the tick
## damage every tick interval, the first one tick interval after it catches, none once it is burnt
## out. The damage is unblockable, builds no Stagger, and misses whoever is untouchable at that
## moment. Each burning thing ticks on its own clock, so overlapping ones each hurt. A creature's own
## ticks hurt it but do not alert it: its Hurtbox is not told of them, so only a tick of some other
## Fire, a fireball or a torch swing makes it notice.

## Emitted once, when it catches.
signal caught

## Emitted once, when the burn time is over and it is burnt out. (The property burnt_out says
## whether it is.)
signal burned_out

## Emitted at each tick, after the damage is dealt.
signal ticked

## Emitted when it stops burning without burning out: Pull took its flame, or its burn time is over
## and it is a creature. It is as it was, and can catch again.
signal put_out

## Emitted when it is whole again after a return, having caught before.
signal restored

## What the thing is, for what Fire does to it afterwards. A creature is alive: Fire only hurts it,
## in ticks, as it hurts anyone in it, and when the burn time is over it is as it was.
enum Kind { HIDING_SPOT, FUNGUS, PATH_BLOCKER, CREATURE }

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
# The physics layer it was made with, which it has again when it is whole.
var _home_layer := 0

@onready var _flame: CanvasItem = get_node_or_null("Flame")


func _enter_tree() -> void:
	add_to_group(&"flammables")


func _ready() -> void:
	_home_layer = collision_layer
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
		if kind == Kind.CREATURE:
			extinguish()
		else:
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


## Takes its flame off it: it stops burning at once and is left as it was, not burnt out. Its
## burn time, its tick clock and a spread still due are forgotten, it gives no light and hurts no
## one, and it can catch again. Fire that has already spread from it keeps burning. Says whether it
## was burning.
func extinguish() -> bool:
	if not _burning:
		return false
	_burning = false
	_burned_for = 0.0
	_spread = false
	_ticks = 0
	remove_from_group(&"fires")
	_show()
	put_out.emit()
	return true


## How far the point (global coordinates) is from the thing's nearest edge, in pixels: zero inside
## it. The edge is that of its first rectangular collision shape; a thing without one is measured
## from its centre.
func distance_to_edge(point: Vector2) -> float:
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape is RectangleShape2D:
			var half := (shape_node.shape as RectangleShape2D).size / 2.0
			var local := shape_node.global_transform.affine_inverse() * point
			var outside := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0))
			return outside.length()
	return global_position.distance_to(point)


## Burns it out at once, whatever state it is in, without it ever catching: it is gone. Says
## nothing if it was gone already, and does nothing to a creature, which is never burnt out.
func burn_out_now() -> void:
	if _burnt_out or kind == Kind.CREATURE:
		return
	_burn_out()


## Enemies have returned: every Fire goes out. A Hiding spot or fungus, burning or burnt out, is
## whole again, with its look, its collision and its flammability. A path blocker that WorldState has
## recorded as burnt is burnt out, even if it was still burning; one that has not been recorded (it
## burnt since the last rest, and a Death undid that) is whole again like the rest. A path blocker
## outside a PathBlocker is taken as recorded once it has caught.
func come_back() -> void:
	if kind == Kind.PATH_BLOCKER and _stays_burnt():
		if _burning:
			_burn_out()
		return
	if not (_burning or _burnt_out):
		return
	_burning = false
	_burnt_out = false
	_burned_for = 0.0
	_spread = false
	_ticks = 0
	remove_from_group(&"fires")
	collision_layer = _home_layer
	set_deferred(&"monitorable", true)
	_show()
	restored.emit()


## Whether it lights this point (global coordinates): it burns and the point is within its light
## radius, the edge included.
func lights(point: Vector2) -> bool:
	return _burning and global_position.distance_to(point) <= tuning.light_radius


# Whether a path blocker that has caught is to stay burnt out: its id is recorded in WorldState.
func _stays_burnt() -> bool:
	var blocker := get_parent() as PathBlocker
	if blocker == null:
		return _burning or _burnt_out
	return WorldState.is_burnt(blocker.id)


# Ticks that are due: each hurts whoever stands in the thing, while it has not burnt out. A creature's
# tick hurts its own Hurtbox (a sibling of this Flammable, under the same body) without the creature
# being told, so its own Fire never alerts it; every other tick alerts as any hit does.
func _tick() -> void:
	if tuning.tick_interval <= 0.0:
		return
	while _burned_for < tuning.burn_time and _burned_for >= (_ticks + 1) * tuning.tick_interval:
		_ticks += 1
		for area in get_overlapping_areas():
			var hurtbox := area as Hurtbox
			if hurtbox != null:
				var own_body := kind == Kind.CREATURE and hurtbox.get_parent() == get_parent()
				hurtbox.hurt_damage_only(tuning.damage_per_tick, global_position, true, own_body)
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
