class_name AlmosSpell
extends Node
## Almos's Spells, made with the Spell button. He has two, Pull and Shove, and the switch_spell
## button cycles between them; the one selected starts as Pull. A switch tap is read only when he
## is free to act, as a Switch Weapon tap is, and is refused while he winds up or holds a flame.
##
## A tap of the Spell button with Pull selected and a lit torch in range draws: the press winds up
## for wind_up_frames, and at the end of the wind-up the Pull cost is spent, the nearest lit torch
## in range goes out and he HOLDS its flame. Holding selects Shove and locks the selection. Nothing
## is thrown until a tap with Shove: that tap throws a fireball at once, paying the Shove cost, and
## it flies the way he aims, which is at the Lock-on target under Lock-on and along his facing
## otherwise. After the throw, or when the flame goes out, the selection returns to what it was
## before the draw.
##
## While he holds the flame it lights the way as a lit torch in his hand does. Any loss of Health,
## a Fire tick included, puts it out, and the cost stays spent; so does reset (a Death, a rest, a
## fall, a Hiding spot, a return). The Health a Spell spends itself is not such a loss.
##
## A press that cannot cast does nothing and spends nothing: Pull with no lit torch in range,
## Shove with no flame held, Health that would not stay above the Health cost, or Stamina below the
## Stamina cost; with too little to pay for the throw the flame stays held. So does a press made
## when he is not free to act, which Almos decides; it is lost, not kept for after. The wind-up
## commits him: Almos treats him as busy while it lasts.

enum Spell { PULL, SHOVE }

const FIREBALL_SCENE := preload("res://scenes/almos/fireball.tscn")

## Emitted when the fireball leaves him, with the fireball and the torch whose flame it is.
signal fireball_thrown(fireball: Fireball, torch: Torch)

## Emitted when the selected Spell changes.
signal selection_changed

## The fireball's and the draw's numbers. Flame draw's data file is given in the Almos scene.
@export var spell_data: SpellData

## What each Spell costs.
@export var pull_cost: SpellCost
@export var shove_cost: SpellCost

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

## The Spell the Spell button makes now.
var selected: Spell:
	get:
		return _selected

var _selected := Spell.PULL
var _selected_before_draw := Spell.PULL
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


## Lets one physics frame go by. free says whether he is free to switch Spell, to begin a draw or
## to throw the flame he holds; aim is the unit direction a fireball thrown now flies in. A press
## made when he is not free is lost.
func advance(free: bool, aim: Vector2) -> void:
	if free and not _holding and not _winding_up and Input.is_action_just_pressed(&"switch_spell"):
		_select(Spell.SHOVE if _selected == Spell.PULL else Spell.PULL)
	if _holding:
		if free and Input.is_action_just_pressed(&"cast_spell") and _selected == Spell.SHOVE and _can_pay(shove_cost):
			_throw(aim)
		return
	if not _winding_up and free and Input.is_action_just_pressed(&"cast_spell"):
		if _selected == Spell.PULL and _nearest_lit_torch_in_range() != null:
			_begin()
		else:
			_act_on_an_enemy(aim)
	if not _winding_up:
		return
	_frames += 1
	if _frames >= spell_data.wind_up_frames:
		_release()


## The wind-up is over and any flame he holds is out at once, with nothing spent and nothing
## thrown, and the selection is what it was before the draw. Called when Almos falls, rests, hides
## or is returned.
func reset() -> void:
	if _holding:
		_select(_selected_before_draw)
	_winding_up = false
	_frames = 0
	_torch = null
	_drawn_from = null
	_holding = false
	_light_the_way(false)


# Starts the wind-up on the nearest lit torch in range, if he can pay for Flame draw.
func _begin() -> void:
	var torch := _nearest_lit_torch_in_range()
	if torch == null or not _can_pay(pull_cost):
		return
	_torch = torch
	_winding_up = true
	_frames = 0


# Shove or Pull on the nearest enemy in the cone around the aim, if he can pay: the cost is spent
# whatever comes of it. An enemy within the greatest Weight he can move slides, one beyond it
# shudders. With no enemy in the cone nothing happens and nothing is spent.
func _act_on_an_enemy(aim: Vector2) -> void:
	var pulling := _selected == Spell.PULL
	var cost := pull_cost if pulling else shove_cost
	var enemy = _nearest_enemy_in_the_cone(cost, aim)
	if enemy == null or not _can_pay(cost):
		return
	_pay(cost)
	if enemy.tuning.weight > tuning.greatest_weight():
		enemy.shudder()
		return
	var away: Vector2 = enemy.global_position - body.global_position
	if pulling:
		enemy.slide(-away, maxf(away.length() - cost.distance, 0.0), cost.move_speed)
	else:
		enemy.slide(away, cost.distance, cost.move_speed)


# The nearest living enemy within the cost's range and cone around the aim, or null.
func _nearest_enemy_in_the_cone(cost: SpellCost, aim: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := cost.target_range
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method(&"slide") or enemy.dead:
			continue
		var away := enemy.global_position - body.global_position
		var distance := away.length()
		if distance > nearest_distance or distance <= 0.0:
			continue
		if rad_to_deg(absf(aim.angle_to(away))) > cost.cone_half_angle_degrees:
			continue
		nearest = enemy
		nearest_distance = distance
	return nearest


# The end of the wind-up: he pays and holds the flame, if the torch is still lit and he can still
# pay; otherwise it fizzles with nothing spent.
func _release() -> void:
	var torch := _torch
	reset()
	if not is_instance_valid(torch) or not torch.lit or not _can_pay(pull_cost):
		return
	_pay(pull_cost)
	torch.draw()
	_drawn_from = torch
	_holding = true
	_selected_before_draw = _selected
	_select(Spell.SHOVE)
	_light_the_way(true)


# The held flame leaves him as a fireball.
func _throw(aim: Vector2) -> void:
	var torch := _drawn_from if is_instance_valid(_drawn_from) else null
	reset()
	_pay(shove_cost)
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


# Whether he could pay this Spell's cost now: his Health stays above the Health cost, and his
# Stamina covers the Stamina cost. Mana arrives with #19: when AlmosFlasks.has_mana_bar is true
# this and _pay are the one place that picks Mana for the Health cost.
func _can_pay(cost: SpellCost) -> bool:
	return health.current > cost.health_cost and stamina.current >= cost.stamina_cost


# Spends the cost. The Health a Spell spends itself is not a loss that puts the held flame out:
# Pull pays before he holds, and Shove after the flame has left him.
func _pay(cost: SpellCost) -> void:
	health.take_damage(cost.health_cost)
	stamina.spend(cost.stamina_cost)


# Selects a Spell, and says so if it is another.
func _select(spell: Spell) -> void:
	if spell == _selected:
		return
	_selected = spell
	selection_changed.emit()


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
