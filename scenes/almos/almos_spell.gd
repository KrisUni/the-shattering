class_name AlmosSpell
extends Node
## Almos's Spell, made with its own button. He has one, Flame draw, until the Mana Task adds
## switching. A tap with a lit torch in range draws: the press winds up for wind_up_frames, and at
## the end of the wind-up the Health and Stamina it costs are spent, the nearest lit torch in range
## goes out and he HOLDS its flame. Nothing is thrown until a second tap, however long he waits:
## that tap throws a fireball at once, for free. It flies the way he aims, which is at the Lock-on
## target under Lock-on and along his facing otherwise.
##
## While he holds the flame it lights the way as a lit torch in his hand does. Any loss of Health,
## a Fire tick included, puts it out, and the cost stays spent; so does reset (a Death, a rest, a
## fall, a Hiding spot, a return).
##
## A press that cannot draw does nothing and spends nothing: no lit torch in range, Health that
## would not stay above the Health cost, or Stamina below the Stamina cost. So does a press made
## when he is not free to act, which Almos decides; it is lost, not kept for after. The wind-up
## commits him: Almos treats him as busy while it lasts.

const FIREBALL_SCENE := preload("res://scenes/almos/fireball.tscn")

## Emitted when the fireball leaves him, with the fireball and the torch whose flame it is.
signal fireball_thrown(fireball: Fireball, torch: Torch)

## The Spell's numbers. Flame draw's data file is given in the Almos scene.
@export var spell_data: SpellData

## What the numbers of Channelling come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## Almos himself, from whom the fireball leaves.
@export var body: Node2D

## The flame he holds, at his own position. It is in the group "torches", and so lights the way,
## only while he holds a flame.
@export var held_flame: Torch

## What the costs are spent from.
@export var health: Health
@export var stamina: Stamina

## Whether the wind-up is under way: from the frame of the press to the frame the fireball leaves
## in, the latter excluded.
var winding_up: bool:
	get:
		return _winding_up

## Whether he holds a drawn flame, from the end of the wind-up until it is thrown or put out.
var holding: bool:
	get:
		return _holding

var _holding := false
var _drawn_from: Torch
var _health_seen := 0.0
var _winding_up := false
var _frames := 0
var _torch: Torch


func _ready() -> void:
	_health_seen = health.current
	health.changed.connect(_on_health_changed)
	_light_the_way(false)


## Lets one physics frame go by. free says whether he is free to begin Flame draw or to throw the
## flame he holds; aim is the unit direction a fireball thrown now flies in. A press made when he
## is not free is lost.
func advance(free: bool, aim: Vector2) -> void:
	if _holding:
		if free and Input.is_action_just_pressed(&"cast_spell"):
			_throw(aim)
		return
	if not _winding_up and free and Input.is_action_just_pressed(&"cast_spell"):
		_begin()
	if not _winding_up:
		return
	_frames += 1
	if _frames >= spell_data.wind_up_frames:
		_release()


## The wind-up is over and any flame he holds is out at once, with nothing spent and nothing
## thrown. Called when Almos falls, rests, hides or is returned.
func reset() -> void:
	_winding_up = false
	_frames = 0
	_torch = null
	_drawn_from = null
	_holding = false
	_light_the_way(false)


# Starts the wind-up on the nearest lit torch in range, if he can pay for Flame draw.
func _begin() -> void:
	var torch := _nearest_lit_torch_in_range()
	if torch == null or not _can_pay():
		return
	_torch = torch
	_winding_up = true
	_frames = 0


# The end of the wind-up: he pays and holds the flame, if the torch is still lit and he can still
# pay; otherwise it fizzles with nothing spent.
func _release() -> void:
	var torch := _torch
	reset()
	if not is_instance_valid(torch) or not torch.lit or not _can_pay():
		return
	health.take_damage(spell_data.health_cost)
	stamina.spend(spell_data.stamina_cost)
	torch.draw()
	_drawn_from = torch
	_holding = true
	_light_the_way(true)


# The held flame leaves him as a fireball.
func _throw(aim: Vector2) -> void:
	var torch := _drawn_from if is_instance_valid(_drawn_from) else null
	reset()
	var fireball := FIREBALL_SCENE.instantiate() as Fireball
	body.get_parent().add_child(fireball)
	fireball.launch(body.global_position, aim, spell_data.fireball_speed, spell_data.fireball_range, spell_data.damage_for(tuning.channelling))
	fireball.splash_radius = spell_data.splash_radius
	fireball.splash_fraction = spell_data.splash_fraction
	fireball_thrown.emit(fireball, torch)


# Any loss of Health puts the held flame out.
func _on_health_changed() -> void:
	if _holding and health.current < _health_seen:
		reset()
	_health_seen = health.current


# The held flame burns, and so lights the way as a lit torch in hand does, or is out and out of
# the group of torches, where Flame draw looks for one to draw.
func _light_the_way(on: bool) -> void:
	if held_flame == null:
		return
	if on:
		held_flame.relight()
		held_flame.add_to_group(&"torches")
	else:
		held_flame.remove_from_group(&"torches")
		held_flame.extinguish()


# Whether he could pay for Flame draw now: his Health stays above the Health cost, and his Stamina
# covers the Stamina cost.
func _can_pay() -> bool:
	return health.current > spell_data.health_cost and stamina.current >= spell_data.stamina_cost


# The nearest lit torch within draw_range of him, or null.
func _nearest_lit_torch_in_range() -> Torch:
	var nearest: Torch = null
	var nearest_distance := spell_data.draw_range
	for node in get_tree().get_nodes_in_group(&"torches"):
		var torch := node as Torch
		if torch == null or not torch.lit:
			continue
		var distance := body.global_position.distance_to(torch.global_position)
		if distance <= nearest_distance:
			nearest = torch
			nearest_distance = distance
	return nearest
