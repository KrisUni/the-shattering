class_name AlmosSpell
extends Node
## Almos's Spells, made with the Spell button. He has two, Pull and Shove, and the switch_spell
## button cycles through them in that order; the one selected starts as Pull. A switch tap is read only when he
## is free to act, as a Switch Weapon tap is, and is refused while he winds up or holds a flame.
##
## Pull takes whatever is nearest to him, all round him (an invisible circle, not a cone): a lit
## torch's flame within draw_range, a Fire's flame within flame_range of its edge, or an enemy or prop
## within the Pull's target_range with no wall between. Shove still looks in a cone along his aim.
##
## A tap of the Spell button with Pull selected and a lit torch nearest draws: the press winds up
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
## Pull and Shove also move props: a wardrobe, a barrel, a crate stack (anything with a Liftable). A
## Pull at one nearer than any flame to take, grips it for the wind-up and then lifts it: it is
## held over his head as a flame is held, Shove is selected, and a tap of Shove throws it the way he
## aims, into the first enemy in its path. A Shove at one standing on the floor knocks it away from
## him. A prop heavier than the greatest Weight he can move shudders, the cost spent. Any loss of
## Health, or a reset, puts down a prop he holds, as it puts out a held flame.
##
## A press that cannot cast does nothing and spends nothing: Pull with no lit torch in range,
## Shove with no flame held, Health that would not stay above the Health cost, or Stamina below the
## Stamina cost; with too little to pay for the throw the flame stays held. So does a press made
## when he is not free to act, which Almos decides; it is lost, not kept for after. The wind-up
## commits him: Almos treats him as busy while it lasts.

enum Spell { PULL, SHOVE }

# The collision layer of the walls, the first, which block the line to a target.
const WALL_MASK := 1

const FIREBALL_SCENE := preload("res://scenes/almos/fireball.tscn")
# Props Pull lifts and Shove throws, by their component's script (no class name needed to load).
const LIFTABLE_SCRIPT := preload("res://scenes/world/liftable.gd")
# The wave of energy a Pull or Shove on ordinary things shows (only a look).
const WAVE_SCRIPT := preload("res://scenes/almos/spell_wave.gd")
# In pixels: how far in front of his feet a prop he puts down lands.
const DROP_AHEAD := 40.0

## Emitted when the fireball leaves him, with the fireball and the torch whose flame it is.
signal fireball_thrown(fireball: Fireball, torch: Torch)

## Emitted when a prop leaves him, thrown from his hold or knocked from the floor.
signal object_thrown(liftable: Node)

## Emitted when the selected Spell changes.
signal selection_changed

## Emitted with every press of Pull or Shove that is not for a flame, whether it moves anything or
## not, as its wave of energy goes out: whether it is a Pull, and what it lands on (an enemy or a
## prop), or null.
signal wave_sent(pulling: bool, target: Node2D)

## The fireball's numbers, and those of taking a torch's flame. The data file is given in the Almos scene.
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

## What the costs are spent from: Health before he has his Mana bar, Mana after.
@export var health: Health
@export var mana: Mana
@export var stamina: Stamina

## Whether the wind-up is under way: from the frame of the press to the frame the fireball leaves
## in, the latter excluded.
var winding_up: bool:
	get:
		return _winding_up

## Whether he holds something over his hand: a drawn flame or a lifted prop, from the end of the
## wind-up until it is thrown, put out or put down.
var holding: bool:
	get:
		return _holding or _held_object != null

## Whether what he holds is a drawn flame.
var holding_flame: bool:
	get:
		return _holding

## The prop he holds, its Liftable, or null.
var held_object: Node:
	get:
		return _held_object

## What the wind-up draws a flame from, the torch or the Fire, or null when he is not winding up.
## Only read, by his look.
var drawing_from: Node2D:
	get:
		if not _winding_up:
			return null
		return _torch if _torch != null else _fire

## How far the wind-up has got, from 0 at the press to 1 at the release; 0 when there is none.
## Only read, by his look.
var wind_up_progress: float:
	get:
		if not _winding_up or spell_data.wind_up_frames <= 0:
			return 0.0
		return clampf(float(_frames) / spell_data.wind_up_frames, 0.0, 1.0)

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
# The Fire whose flame the wind-up is for, and for how many more seconds he holds a flame taken from
# a Fire (zero for a torch's, which he holds as long as he likes).
var _fire: Flammable
var _fire_hold_left := 0.0
# The prop the wind-up is lifting, and the prop he holds.
var _lift: Node
var _held_object: Node


func _ready() -> void:
	_health_seen = health.current
	health.changed.connect(_on_health_changed)
	_light_the_way(false)


## Lets one physics frame go by. free says whether he is free to switch Spell, to begin a draw or
## to throw the flame he holds; aim is the unit direction a fireball thrown now flies in. A press
## made when he is not free is lost.
func advance(free: bool, aim: Vector2) -> void:
	if free and not holding and not _winding_up and Input.is_action_just_pressed(&"switch_spell"):
		_select(_next_spell())
	if _held_object != null:
		if not is_instance_valid(_held_object) or not _held_object.held():
			reset()
			return
		if free and Input.is_action_just_pressed(&"cast_spell") and _selected == Spell.SHOVE and _can_pay(shove_cost):
			_throw_object(aim)
		return
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
		if _selected == Spell.PULL:
			_pull(aim)
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
	if holding:
		_select(_selected_before_draw)
	if _lift != null and is_instance_valid(_lift):
		_lift.release_grip()
	_lift = null
	if _held_object != null and is_instance_valid(_held_object):
		_held_object.drop_at(body.global_position + _ahead() * DROP_AHEAD)
	_held_object = null
	_winding_up = false
	_frames = 0
	_torch = null
	_fire = null
	_fire_hold_left = 0.0
	_drawn_from = null
	_holding = false
	_light_the_way(false)


# Pull takes whatever is nearest to him of all it can take, each within its own range around him: a
# lit torch's flame, a Fire's flame (measured to its edge), an enemy or a prop. Nothing in range,
# nothing happens and nothing is spent.
func _pull(aim: Vector2) -> void:
	var torch := _nearest_lit_torch_in_range()
	var fire := _nearest_fire_in_range()
	var torch_distance := _distance_to(torch) if torch != null else INF
	var fire_distance := fire.distance_to_edge(body.global_position) if fire != null else INF
	var other_distance := INF
	var enemy := _nearest_enemy_in_the_cone(pull_cost, aim)
	if enemy != null:
		other_distance = _distance_to(enemy)
	var prop := _nearest_prop_in_the_cone(pull_cost, aim)
	if prop != null:
		other_distance = minf(other_distance, _distance_to(prop.prop()))
	if torch != null and torch_distance <= fire_distance and torch_distance <= other_distance:
		_begin()
	elif fire != null and fire_distance <= other_distance:
		_begin_on_a_fire()
	else:
		_act_on_an_enemy(aim)


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
	var prop := _nearest_prop_in_the_cone(cost, aim)
	if prop != null and (enemy == null or _distance_to(prop.prop()) < _distance_to(enemy)):
		_send_a_wave(pulling, aim, prop.prop())
		_act_on_a_prop(prop, pulling, cost)
		return
	_send_a_wave(pulling, aim, enemy)
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


# Pull grips a prop for the wind-up, to lift it at the end; Shove knocks it away at once. Too heavy,
# it shudders, the cost spent.
func _act_on_a_prop(prop: Node, pulling: bool, cost: SpellCost) -> void:
	if not _can_pay(cost):
		return
	if prop.weight > tuning.greatest_weight():
		_pay(cost)
		var toward: Vector2 = body.global_position - prop.prop().global_position
		prop.shudder(toward if pulling else -toward)
		return
	if pulling:
		_lift = prop
		prop.grip()
		_winding_up = true
		_frames = 0
		return
	_pay(cost)
	prop.throw(prop.prop().global_position - body.global_position, true)
	object_thrown.emit(prop)


# The nearest prop that can be moved within the cost's range and cone around the aim, with no wall
# between, or null.
func _nearest_prop_in_the_cone(cost: SpellCost, aim: Vector2) -> Node:
	var nearest: Node = null
	var nearest_distance := cost.target_range
	for node in get_tree().get_nodes_in_group(&"liftables"):
		if node.get_script() != LIFTABLE_SCRIPT or not node.can_be_moved():
			continue
		var prop: Node2D = node.prop()
		var away := prop.global_position - body.global_position
		var distance := away.length()
		if distance > nearest_distance or distance <= 0.0:
			continue
		if not _in_the_cone(cost, aim, away):
			continue
		var line := PhysicsRayQueryParameters2D.create(body.global_position, prop.global_position, WALL_MASK)
		line.exclude = node.body_rids()
		if not body.get_world_2d().direct_space_state.intersect_ray(line).is_empty():
			continue
		nearest = node
		nearest_distance = distance
	return nearest


# Whether this way from him lies in the cost's cone around the aim. A cone of 180 degrees either side
# is all round him, straight behind included.
func _in_the_cone(cost: SpellCost, aim: Vector2, away: Vector2) -> bool:
	if cost.cone_half_angle_degrees >= 180.0:
		return true
	return rad_to_deg(absf(aim.angle_to(away))) <= cost.cone_half_angle_degrees


func _distance_to(target: Node2D) -> float:
	return body.global_position.distance_to(target.global_position)


# The way he faces, for where he puts a prop down.
func _ahead() -> Vector2:
	var facing: Variant = body.get(&"facing")
	return (facing as Vector2).normalized() if facing is Vector2 and not (facing as Vector2).is_zero_approx() else Vector2.DOWN


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
		if not _in_the_cone(cost, aim, away):
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
	var lift := _lift
	_lift = null
	reset()
	if lift != null:
		_lift_up(lift)
		return
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


# The end of a lift's wind-up: he pays and holds the prop, if it can still be moved and he can still
# pay; otherwise it settles where it stands, nothing spent.
func _lift_up(prop: Node) -> void:
	if not is_instance_valid(prop):
		return
	prop.release_grip()
	if not prop.can_be_moved() or not _can_pay(pull_cost):
		return
	_pay(pull_cost)
	prop.lift(body)
	_held_object = prop
	_selected_before_draw = _selected
	_select(Spell.SHOVE)


# The held prop leaves him, thrown the way he aims.
func _throw_object(aim: Vector2) -> void:
	var prop := _held_object
	_held_object = null
	_select(_selected_before_draw)
	_pay(shove_cost)
	_send_a_wave(false, aim, null)
	prop.throw(aim)
	object_thrown.emit(prop)


# The wave of energy of a Pull or Shove on ordinary things: a look, sent whatever comes of the press.
func _send_a_wave(pulling: bool, aim: Vector2, target: Node2D) -> void:
	if body != null and body.get_parent() != null:
		var cost := pull_cost if pulling else shove_cost
		var wave: Node2D = WAVE_SCRIPT.new()
		body.get_parent().add_child(wave)
		wave.global_position = body.global_position
		wave.call(&"start", pulling, aim, cost.target_range, cost.cone_half_angle_degrees, body, target)
	wave_sent.emit(pulling, target)


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


# Any loss of Health puts the held flame out, and puts down a prop he holds.
func _on_health_changed() -> void:
	if (holding or _lift != null) and health.current < _health_seen:
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


# The Spell the switch button selects after this one: Pull, Shove, and round again.
func _next_spell() -> Spell:
	match _selected:
		Spell.PULL:
			return Spell.SHOVE
	return Spell.PULL


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
