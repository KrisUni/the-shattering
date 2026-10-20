class_name AlmosSpell
extends Node
## Almos's Spells, made with the Spell button. He has three, Pull, Shove and Deep bolt, and the switch_spell
## button cycles through them in that order; the one selected starts as Pull. A switch tap is read only when he
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

enum Spell { PULL, SHOVE, DEEP_BOLT }

# The collision layer of the walls, the first, which block the line to a target.
const WALL_MASK := 1

const FIREBALL_SCENE := preload("res://scenes/almos/fireball.tscn")
const DEEP_BOLT_SCENE := preload("res://scenes/almos/deep_bolt.tscn")

## Emitted when the fireball leaves him, with the fireball and the torch whose flame it is.
signal fireball_thrown(fireball: Fireball, torch: Torch)

## Emitted when the selected Spell changes.
signal selection_changed

## The fireball's numbers, and those of taking a torch's flame. The data file is given in the Almos scene.
@export var spell_data: SpellData

## What each Spell costs.
@export var pull_cost: SpellCost
@export var shove_cost: SpellCost

## Deep bolt: its costs, and how its bolt flies and hits.
@export var deep_bolt: DeepBoltData

## What the numbers of Channelling come from. Almos gives his own tuning.
@export var tuning: PlayerTuning

## Almos himself, from whom the fireball leaves.
@export var body: Node2D

## The flame he holds, at his own position. It is in the group "torches", and so lights the way,
## only while he holds a flame.
@export var held_flame: Torch

## What the costs are spent from: Health before he has his Mana bar, Mana after.
@export var health: Health
@export var mana: Mana
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
# Whether the wind-up under way is Deep bolt's, and the aim the bolt leaves along at its end.
var _bolt_winding := false
var _bolt_aim := Vector2.RIGHT
var _frames := 0
var _torch: Torch
# The Fire whose flame the wind-up is for, and for how many more seconds he holds a flame taken from
# a Fire (zero for a torch's, which he holds as long as he likes).
var _fire: Flammable
var _fire_hold_left := 0.0


func _ready() -> void:
	_health_seen = health.current
	health.changed.connect(_on_health_changed)
	_light_the_way(false)


## Lets one physics frame go by. free says whether he is free to switch Spell, to begin a draw or
## to throw the flame he holds; aim is the unit direction a fireball thrown now flies in. A press
## made when he is not free is lost.
func advance(free: bool, aim: Vector2) -> void:
	if free and not _holding and not _winding_up and Input.is_action_just_pressed(&"switch_spell"):
		_select(_next_spell())
	if _holding:
		if _fire_hold_left > 0.0:
			_fire_hold_left -= get_physics_process_delta_time()
			if _fire_hold_left <= 0.0:
				# A flame taken from a Fire goes out unthrown: the cost stays spent.
				reset()
				return
		if free and Input.is_action_just_pressed(&"cast_spell") and _selected == Spell.SHOVE and _can_pay(shove_cost):
			_throw(aim)
		return
	if not _winding_up and free and Input.is_action_just_pressed(&"cast_spell"):
		if _selected == Spell.DEEP_BOLT:
			_begin_bolt()
		elif _selected == Spell.PULL and _nearest_lit_torch_in_range() != null:
			_begin()
		elif _selected == Spell.PULL and _nearest_fire_in_range() != null:
			_begin_on_a_fire()
		else:
			_act_on_an_enemy(aim)
	if not _winding_up:
		return
	_frames += 1
	if _bolt_winding:
		_bolt_aim = aim
		if _frames >= deep_bolt.wind_up_frames:
			_release_bolt()
	elif _frames >= spell_data.wind_up_frames:
		_release()


## The wind-up is over and any flame he holds is out at once, with nothing spent and nothing
## thrown, and the selection is what it was before the draw. Called when Almos falls, rests, hides
## or is returned.
func reset() -> void:
	if _holding:
		_select(_selected_before_draw)
	_winding_up = false
	_bolt_winding = false
	_frames = 0
	_torch = null
	_fire = null
	_fire_hold_left = 0.0
	_drawn_from = null
	_holding = false
	_light_the_way(false)


# Starts the wind-up on the nearest lit torch in range, if he can pay for the Pull.
func _begin() -> void:
	var torch := _nearest_lit_torch_in_range()
	if torch == null or not _can_pay(pull_cost):
		return
	_torch = torch
	_winding_up = true
	_frames = 0


# Shove or Pull on the nearest enemy or movable object in the cone around the aim, if he can pay: the cost is spent
# whatever comes of it. An enemy within the greatest Weight he can move slides, one beyond it
# shudders. With no enemy in the cone nothing happens and nothing is spent.
func _act_on_an_enemy(aim: Vector2) -> void:
	var pulling := _selected == Spell.PULL
	var cost := pull_cost if pulling else shove_cost
	var enemy = _nearest_enemy_in_the_cone(cost, aim)
	if enemy == null or not _can_pay(cost):
		return
	_pay(cost)
	if enemy.weight > tuning.greatest_weight():
		enemy.shudder()
		return
	var away: Vector2 = enemy.global_position - body.global_position
	if pulling and enemy.has_method(&"pull_towards"):
		enemy.pull_towards(body.global_position, cost.distance, cost.move_speed)
	elif pulling:
		enemy.slide(-away, maxf(away.length() - cost.distance, 0.0), cost.move_speed)
	else:
		enemy.slide(away, cost.distance, cost.move_speed)


# The nearest living enemy or movable object within the cost's range and cone around the aim, or null.
func _nearest_enemy_in_the_cone(cost: SpellCost, aim: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := cost.target_range
	for node in get_tree().get_nodes_in_group(&"enemies") + get_tree().get_nodes_in_group(&"movables"):
		var enemy := node as Node2D
		if enemy == null or not enemy.has_method(&"slide") or enemy.dead:
			continue
		var away := enemy.global_position - body.global_position
		var distance := away.length()
		if distance > nearest_distance or distance <= 0.0:
			continue
		if rad_to_deg(absf(aim.angle_to(away))) > cost.cone_half_angle_degrees:
			continue
		if _wall_between(enemy):
			continue
		nearest = enemy
		nearest_distance = distance
	return nearest


# Whether a wall (the walls layer) stands between him and this target, which a Shove or a Pull needs a
# straight line to. The target itself is not a wall, though a movable object is on that layer.
func _wall_between(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(body.global_position, target.global_position, WALL_MASK)
	var collider := target as CollisionObject2D
	if collider != null:
		query.exclude = [collider.get_rid()]
	return not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# Starts the wind-up on the nearest Fire in range, if he can pay for the Pull. The Fire is chosen now
# and must still burn at the end of the wind-up.
func _begin_on_a_fire() -> void:
	var fire := _nearest_fire_in_range()
	if fire == null or not _can_pay(pull_cost):
		return
	_fire = fire
	_winding_up = true
	_frames = 0


# The nearest burning flammable thing whose nearest edge is within the Pull's flame_range of him
# (its edge, not its centre: a bed or a curtain is big), or null.
func _nearest_fire_in_range() -> Flammable:
	var nearest: Flammable = null
	var nearest_distance := pull_cost.flame_range
	for node in get_tree().get_nodes_in_group(&"fires"):
		var fire := node as Flammable
		if fire == null or not fire.burning:
			continue
		var distance := fire.distance_to_edge(body.global_position)
		if distance <= nearest_distance:
			nearest = fire
			nearest_distance = distance
	return nearest


# The end of the wind-up: he pays and holds the flame, if the torch is still lit and he can still
# pay; otherwise it fizzles with nothing spent.
func _release() -> void:
	var torch := _torch
	var fire := _fire
	reset()
	if not _can_pay(pull_cost):
		return
	if fire != null:
		if not is_instance_valid(fire) or not fire.burning:
			return
		_pay(pull_cost)
		fire.extinguish()
		_fire_hold_left = pull_cost.fire_flame_hold_time
	else:
		if not is_instance_valid(torch) or not torch.lit:
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
# the group of torches, where Pull looks for one to take.
func _light_the_way(on: bool) -> void:
	if held_flame == null:
		return
	if on:
		held_flame.relight()
		held_flame.add_to_group(&"torches")
	else:
		held_flame.remove_from_group(&"torches")
		held_flame.extinguish()


# The Spell the switch button selects after this one: Pull, Shove, Deep bolt, and round again.
func _next_spell() -> Spell:
	match _selected:
		Spell.PULL:
			return Spell.SHOVE
		Spell.SHOVE:
			return Spell.DEEP_BOLT
	return Spell.PULL


# Deep bolt's wind-up begins, if he can pay for it now; otherwise nothing happens.
func _begin_bolt() -> void:
	if not _can_pay(deep_bolt):
		return
	_winding_up = true
	_bolt_winding = true
	_frames = 0


# The end of Deep bolt's wind-up: he pays and the bolt leaves along the aim, if he can still pay;
# otherwise it fizzles with nothing spent.
func _release_bolt() -> void:
	var aim := _bolt_aim
	reset()
	if not _can_pay(deep_bolt):
		return
	_pay(deep_bolt)
	var bolt := DEEP_BOLT_SCENE.instantiate() as Fireball
	body.get_parent().add_child(bolt)
	bolt.launch(body.global_position, aim, deep_bolt.bolt_speed, deep_bolt.bolt_range, deep_bolt.damage_for(tuning.channelling))


# Whether he could pay this Spell's cost now. Once he has his Mana bar, his Mana covers the Mana
# cost; before, his Health stays above the Health cost. Either way his Stamina covers the Stamina
# cost. This and _pay are the one place that picks Mana or Health.
func _can_pay(cost: SpellCost) -> bool:
	if stamina.current < cost.stamina_cost:
		return false
	if _has_mana_bar():
		return mana.current >= cost.mana_cost
	return health.current > cost.health_cost


# Spends the cost. The Health a Spell spends itself is not a loss that puts the held flame out:
# Pull pays before he holds, and Shove after the flame has left him.
func _pay(cost: SpellCost) -> void:
	if _has_mana_bar():
		mana.spend(cost.mana_cost)
	else:
		health.take_damage(cost.health_cost)
	stamina.spend(cost.stamina_cost)


# Whether he has his Mana bar, and so pays Mana for a Spell.
func _has_mana_bar() -> bool:
	return mana != null and mana.granted


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
