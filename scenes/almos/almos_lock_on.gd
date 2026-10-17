class_name AlmosLockOn
extends Node
## Almos's Lock-on: the button that toggles it, who it holds on to, when it lets go, and the
## geometry that goes with it. While it holds, Almos circles the target and aims at it; this
## node only says where the target is and how to move round it, and Almos does the rest.
##
## One press of the Lock-on button picks the nearest enemy within lock_on_range, if there is
## one; another press lets go. It lets go on its own when the target announces its death,
## when it is no longer there, and when it gets farther than lock_on_break_range. Letting
## go changes nothing else: Almos keeps the facing he had.

## Closer than this, in pixels, Almos is taken to stand on the target: there is no line to it
## to circle or to aim along.
const COINCIDENT := 0.001

## What the ranges come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## Almos, whose position everything here is measured from.
@export var almos: Node2D

## The placeholder that sits on the target while the lock holds.
@export var marker: Node2D

## The enemy he has locked on to, or null when he has not.
var target: Node2D:
	get:
		return _target if _usable() else null

## Whether the lock holds.
var locked: bool:
	get:
		return _usable()

var _target: Node2D


func _process(_delta: float) -> void:
	# Almos is processed before the enemy in a physics frame, so the marker is placed again
	# once everything has moved, or it would trail a moving enemy by a frame.
	_place_marker()


## Lets one physics frame go by. Called once per frame by Almos, before anything else in the
## frame uses the lock. It reads the Lock-on button itself.
func advance() -> void:
	# Whatever was lost since last frame is let go of before the press is read, so a press
	# made as the target got away picks a target afresh.
	if not locked or almos.global_position.distance_to(_target.global_position) > tuning.lock_on_break_range:
		release()
	if Input.is_action_just_pressed(&"lock_on"):
		if locked:
			release()
		else:
			_lock_on_to_the_nearest()
	_place_marker()


## Lets go of the target, if there is one.
func release() -> void:
	if is_instance_valid(_target) and _target.is_connected(&"died", release):
		_target.disconnect(&"died", release)
	_target = null
	_place_marker()


## The unit vector from Almos to the target, or Vector2.ZERO when he has not locked on or
## stands on it.
func direction_to_target() -> Vector2:
	if not locked:
		return Vector2.ZERO
	var offset := _target.global_position - almos.global_position
	return offset.normalized() if offset.length() > COINCIDENT else Vector2.ZERO


## The velocity that takes Almos where a push of the stick takes him under Lock-on. The push is
## a screen-relative direction no longer than 1, and speed is how fast it moves him in pixels
## per second, as it would without Lock-on.
##
## The push is split into a part along the line to the target and a part across it. The part
## along moves him closer or farther. The part across moves him round a circle about the
## target through his position, so the distance stays what it was: the position he reaches is
## the one he stands at turned about the target, not a step along the tangent, which would
## drift outward. The velocity is the one that covers that in this frame's delta. When he
## stands on the target there is no line, and it is the plain push.
func circling_velocity(push: Vector2, speed: float, delta: float) -> Vector2:
	if not locked:
		return push * speed
	var offset := almos.global_position - _target.global_position
	var radius := offset.length()
	if radius <= COINCIDENT:
		return push * speed
	var outward := offset / radius
	var around := outward.rotated(PI / 2.0)
	var away_by := push.dot(outward) * speed * delta
	var round_by := push.dot(around) * speed * delta
	# Never negative: past the target he would be on its far side, going the wrong way round.
	var new_radius := maxf(radius + away_by, 0.0)
	var turned := offset.rotated(round_by / radius) * (new_radius / radius)
	return (turned - offset) / delta


# Whether there is a target to hold on to: still there, and still in the scene.
func _usable() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree()


func _lock_on_to_the_nearest() -> void:
	var nearest: Node2D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var distance := almos.global_position.distance_to(enemy.global_position)
		if distance <= tuning.lock_on_range and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest == null:
		return
	_target = nearest
	# Enemies announce their death. Ones that do not are let go of when they are gone.
	if _target.has_signal(&"died"):
		_target.connect(&"died", release)


func _place_marker() -> void:
	if marker == null:
		return
	marker.visible = locked
	if locked:
		marker.global_position = _target.global_position
