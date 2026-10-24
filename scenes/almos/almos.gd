class_name Almos
extends CharacterBody2D

# Almos's sprites show eight facings, so his facing is always one of eight directions.
const FACING_STEP := TAU / 8.0

# Frame lengths added up one by one can land a hair short of a whole number of seconds
# (twelve of them at 60 frames a second add up to 0.19999999999999998). A summed time is
# compared with a tuned time through this slack, so that a tuned time which is a whole
# number of frames counts as reached on that frame, not the next. Without it a Roll would
# run one more frame with nothing left to move, the untouchable window would be a frame
# too long and the hold threshold a frame too late. The buffer window of the Roll, the Guard
# break in AlmosBlock and the pause of a Death are timed with it as well.
const TIME_SLACK := 0.000001

# What his placeholder is tinted while he lies limp after a Death. It is a look, not a tuning
# number.
const DEATH_TINT := Color(0.35, 0.35, 0.4)

# What his placeholder is tinted while he hides, so that the player can see he is out of sight. A
# look, not a tuning number.
const HIDDEN_TINT := Color(1.0, 1.0, 1.0, 0.35)

# What he leaves on the ground when he drops the Weapon in hand.
const WEAPON_PICKUP_SCENE := preload("res://scenes/world/weapon_pickup.tscn")

enum State { WALKING, SPRINTING, ROLLING }

## Emitted when he rests at a Checkpoint, after his Health, Stamina, Mana and Flasks are refilled.
signal rested(checkpoint: Checkpoint)

## Emitted once, in the frame his Health reaches zero, with the place he fell. He is limp from
## then, every action he was in is over, and the pause begins.
signal died(place: Vector2)

## Emitted once, in the frame the pause of his Death runs out. He is still limp: whoever handles
## the Death, such as the room, sends him back with return_to.
signal death_pause_over

## Emitted when he is returned, after return_to has put him back on his feet.
signal returned

## Where Almos last moved, snapped to the nearest of eight directions, as a unit
## vector. A Roll with no input goes this way, and so does an attack. Under Lock-on it is
## the direction to the target instead (snapped the same way), and it stays as it was when
## the lock lets go.
var facing := Vector2.DOWN

## Whether a Roll is under way.
var rolling: bool:
	get:
		return _state == State.ROLLING

## How far from him, in pixels, a Sound hunter hears him in this physics frame: the largest of the
## radii of what he is doing, 0 when he walks, stands, Blocks or Jumps with no attack. Sprinting,
## a Roll and any attack under way (a swing, a Heavy attack charge, a Jump attack, a Critical hit)
## each make Noise.
var noise_radius: float:
	get:
		if _dead or _hiding:
			return 0.0
		var radius := 0.0
		if sprinting:
			radius = maxf(radius, tuning.noise_sprint_radius)
		if rolling:
			radius = maxf(radius, tuning.noise_roll_radius)
		if _attacks.committed:
			radius = maxf(radius, tuning.noise_attack_radius)
		return radius

## Whether he is in a Hiding spot: he got in with a tap of Interact and has not left. He cannot
## move or act, makes no Noise, and no enemy can notice him. A tap of Interact leaves, and so does
## being pulled out by a hit.
var hiding: bool:
	get:
		return _hiding

## Whether a Sip is under way: from the frame of the press to the frame Health comes back in, the
## latter included. He can only walk, slowly, and cannot attack, Roll, Sprint, Jump, Block, Parry,
## cast, interact or switch. A hit wastes the Sip: it ends at once with nothing restored.
var sipping: bool:
	get:
		return flasks.sipping

## Whether Almos is sprinting.
var sprinting: bool:
	get:
		return _state == State.SPRINTING

## Whether a Light or Heavy attack, the Critical hit or the strike of a Jump attack is under way:
## its startup, active and recovery frames. A Jump attack is under way from the frame he lands.
var attacking: bool:
	get:
		return _attacks.attacking

## Whether the Critical hit is under way: his swing at a broken enemy, made by a Light attack
## press in its range in place of a Light swing. Alongside attacking, the Light swing is 0.
var critical: bool:
	get:
		return _attacks.critical

## Whether a Jump attack is under way: from the Heavy attack press in the air, through the rest
## of the Jump, to the end of its recovery. He is committed all that time: he stands still once
## down, and can neither Roll, Jump, Block nor Parry.
var jump_attacking: bool:
	get:
		return _attacks.jump_attacking

## Whether a Heavy attack is being charged: he holds the button and has not swung yet.
var charging: bool:
	get:
		return _attacks.charging

## Which swing of the Light attack combo is under way, from 1, or 0 when none is. A Heavy
## attack, or none at all, is 0.
var light_swing: int:
	get:
		return _attacks.light_swing

## Whether Lock-on holds: he has locked on to an enemy and not let go of it yet.
var locked_on: bool:
	get:
		return _lock_on.locked

## The enemy he has locked on to, or null when he has not.
var lock_on_target: Node2D:
	get:
		return _lock_on.target

## Whether he is blocking: the Block button is held and he is free, which he is not in a
## Roll, in an attack, charging a Heavy attack, sprinting, in the air or in a Guard break.
## Holding the Roll button while blocking does not start a Sprint.
var blocking: bool:
	get:
		return _block.blocking

## Whether a Guard break is on him: a blocked hit took the last of his Stamina, and for
## guard_break_duration he is left open. He stands still, and can neither Sprint, Roll, attack
## nor block; his Lock-on works as usual. He is free again from the frame after the last of it.
var guard_broken: bool:
	get:
		return _block.guard_broken

## Whether he recoils: a Nar jailer Parried his attack, and for parried_recoil_frames he is left
## open. He stands still, and can neither attack, Roll, Block, Parry, Jump, cast a Spell nor
## Interact, and a press of any of those buttons is lost; his Lock-on works as usual. Hits on him
## land in full. He is free again from the frame after the last of it.
var recoiling: bool:
	get:
		return _recoil_left > 0

## Whether a Parry is under way: its window or its recovery. He stands still, and can neither
## Roll, attack, Block nor Parry again; his Lock-on works as usual. He is free again from the
## frame after the last recovery frame, or after a hit was parried.
var parrying: bool:
	get:
		return _parry.parrying

## Whether the window of a Parry is open: a hit from the front is parried.
var parry_window_open: bool:
	get:
		return _parry.window_open

## Whether he is in the air, in a Jump: from the frame of the press to the frame he comes
## down in. He can neither Roll, Block nor Parry in it, and a press of any of those buttons is
## lost, as is a Light attack press. A Heavy attack press makes a Jump attack. He can be hurt in
## it as usual, except by a Low attack, which passes under him.
var airborne: bool:
	get:
		return _jump.airborne

## Which height level he is on: 0 for the ground, 1 for a low ledge. In the air it is the
## level he took off from, until he comes down.
var height_level: int:
	get:
		return _jump.height_level

## Whether his Health has reached zero and he has not been returned: he lies limp. He takes no
## input, cannot be hit, and every action he was in has ended. After death_pause he is waiting
## to be sent back with return_to.
var dead: bool:
	get:
		return _dead

## Whether Almos cannot be hurt at this moment: while he is limp, and during part of a Roll.
var untouchable: bool:
	get:
		if _dead:
			return true
		var window_start := tuning.roll_untouchable_start - TIME_SLACK
		var window_end := tuning.roll_untouchable_start + tuning.roll_untouchable_duration - TIME_SLACK
		return rolling and _roll_time >= window_start and _roll_time < window_end

@export var tuning: PlayerTuning

## The Weapon he starts out carrying, in hand: the first of those he carries. What he carries
## after that is up to his Weapons, so this is the only one to set.
@export var weapon: WeaponData

## The Armour he wears, or null for none: a placeholder until Armour and Load is done, so nothing
## reads it and it has no effect. He wears an Armour at once when he takes it with a tap of
## Interact.
@export var armour: ArmourData

## What he fights with when his hands are empty: Unarmed. It is given to his attacks whenever no
## Weapon is in hand, and it is not carried, so it is never in his Weapons.
@export var unarmed: WeaponData

## The torch Weapon (data/torch.tres). While it is the one in hand it burns and lights the way,
## and Pull can take its flame; once taken it is replaced where it is by unlit_torch.
@export var torch_weapon: WeaponData

## What a drawn torch becomes in his hand: the unlit club, with its own attacks. It never burns
## again, and is not relit when enemies return.
@export var unlit_torch: WeaponData

## What Roll and Sprint spend, and what the Stamina bar shows. It is given Almos's tuning,
## so his tuning is the only one to set.
@onready var stamina: Stamina = $Stamina

## What hits take off, and what the Health bar shows. It is given its maximum from Almos's
## tuning, so his tuning is the only one to set.
@onready var health: Health = $Health

## What Spells and the Mana Flask's Sip draw on once he has his Mana bar. It is empty and has no bar
## until grant_mana_bar() gives it, once.
@onready var mana: Mana = $Mana

## What killing enemies has given him and he has not yet cashed in, and what the Experience count
## shows.
@onready var experience: Experience = $Experience

## His Spells, Pull and Shove: made with their own button, and a draw commits him while it winds up.
@onready var spell: AlmosSpell = $Spell

## His Flasks: a press of the Sip button drinks from the Health Flask (the Mana Flask is empty until
## he has a Mana bar), which keeps him slow and
## otherwise busy until it ends.
@onready var flasks: AlmosFlasks = $Flasks

## The Weapons he carries and the one in hand. The one in hand is given to his attacks, and
## what he carries survives a Death.
@onready var weapons: AlmosWeapons = $Weapons

## The flame of the torch in his hand, at his own position. It is in the group "torches", and so
## gives light and can be drawn, only while the torch Weapon is in hand and burning.
@onready var carried_torch: Torch = $CarriedTorch
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _attacks: AlmosAttacks = $Attacks
@onready var _lock_on: AlmosLockOn = $LockOn
@onready var _block: AlmosBlock = $Block
@onready var _parry: AlmosParry = $Parry
@onready var _jump: AlmosJump = $Jump
@onready var _placeholder: Polygon2D = $Placeholder

var _state := State.WALKING
# For how many more physics frames he recoils from a Parried attack.
var _recoil_left := 0
var _dead := false
var _dead_for := 0.0
var _pause_announced := false
var _roll_direction := Vector2.ZERO
var _roll_time := 0.0
var _roll_queued := false
var _roll_button_held_for := 0.0
# Set when he is returned with the Roll button down: a press made before or during his Death. It
# counts for nothing, neither as a tap nor toward a Sprint, until the button is let go.
var _roll_press_lost := false
# Set once the Weapon he starts with has been put in his hands, so that going into the tree again
# does not put it in his hands again.
var _weapons_started := false
# The gear he is given back by a Death: what he carried, which of it was in hand and what he wore at
# his last rest, or at the start until he first rests.
var _saved_weapons: Array[WeaponData] = []
var _saved_in_hand_index := -1
var _saved_armour: ArmourData
# Whether an Interact press that began while he was free is being timed. It ends in a tap or a
# drop, or is lost if he stops being free.
var _interact_counted := false
var _interact_held_for := 0.0
# Set once the press has been held to drop_hold_time: it is a hold now, and letting go of it is not
# a tap.
var _interact_hold_spent := false
# Set when a press of the Switch button was made in an attack, until the attack is over and the
# switch is made. There is room for one.
var _switch_waiting := false
# Set when a Sprint was tried and there was no Stamina to pay for it, until the Roll
# button is let go. Without it, the sliver of Stamina that comes back when the refill
# pause ends would pay for one frame of Sprint, which would start the pause again.
var _out_of_breath := false
# Whether he is in the wind-up of his Spell in this frame: set at the start of the frame from the wind-up
# as the last frame left it, so that the frame the fireball leaves in is spent committed too, and set
# again once the Spell has been advanced, so that the frame of a press is.
var _casting := false
# Whether he is in a Sip in this frame: set at the start of the frame from the Sip as the last frame
# left it, so that the frame Health comes back in is spent sipping too, and set again once the Sip
# has been advanced, so that the frame of a press is.
var _sipping := false
# Whether he is in a Hiding spot.
var _hiding := false

# The Hiding spot he is in, while he is in one.
var _hiding_spot: HidingSpot
# The Noise radius he made in the physics frame before this one, read at the start of this frame: it
# is what an enemy that sees him get into a Hiding spot in this frame heard of him.
var _noise_before := 0.0


func _enter_tree() -> void:
	# Done here, not in _ready, so that every node's _ready finds Stamina and Health already
	# filled in whatever order the nodes are in: the bars read them in their _ready. Giving
	# either its numbers refills it, so each is only given a different one.
	var own_stamina := $Stamina as Stamina
	if own_stamina.tuning != tuning:
		own_stamina.tuning = tuning
	var own_health := $Health as Health
	if own_health.maximum != tuning.health_maximum:
		own_health.maximum = tuning.health_maximum
	# He starts with his exported Weapon in hand, once.
	var own_weapons := $Weapons as AlmosWeapons
	if not _weapons_started:
		_weapons_started = true
		own_weapons.pick_up(weapon)
		_save_the_gear(own_weapons)
	# Handing over the weapon in hand or the tuning changes nothing else, so they need no check
	# first.
	($Attacks as AlmosAttacks).weapon = own_weapons.in_hand if own_weapons.in_hand != null else unarmed
	($LockOn as AlmosLockOn).tuning = tuning
	($Block as AlmosBlock).tuning = tuning
	($Parry as AlmosParry).tuning = tuning
	($Jump as AlmosJump).tuning = tuning
	($Spell as AlmosSpell).tuning = tuning


func _ready() -> void:
	health.depleted.connect(_fall)
	# Whichever Weapon is in hand is the one his attacks make. A switch is only made when he is not
	# in an attack, and a drop only when he is free, so nothing is handed over in the middle of one.
	weapons.changed.connect(_hand_over_the_weapon_in_hand)
	# The torch in hand burns; a torch drawn becomes the unlit club.
	weapons.changed.connect(_tend_the_carried_torch)
	carried_torch.put_out.connect(_leave_an_unlit_club)
	_tend_the_carried_torch()
	# The Critical hit turns him to the enemy it is made at.
	_attacks.critical_began.connect(_face)
	# An attack a Nar jailer Parries is over at once, and leaves him recoiling.
	_attacks.hitbox.parried.connect(_on_attack_parried)
	# A switch pressed in a swing, or in the frame its recovery ends, is made in that frame, before
	# the attack kept for it begins, which is then made with the new Weapon.
	_attacks.kept_press_beginning.connect(_make_the_waiting_switch)
	# A Jump attack pressed in the air strikes as he comes down, or is cancelled by a gap.
	_jump.landed.connect(_on_landed)
	# A hit that lands on him in a Hiding spot pulls him out of it.
	_hurtbox.landed.connect(_on_hurt_landed)
	_hurtbox.is_untouchable = func() -> bool: return untouchable
	# In a Hiding spot only a grab hurts him.
	_hurtbox.is_hidden = func() -> bool: return _hiding
	# A Low attack passes under him while he is in the air.
	_hurtbox.is_airborne = func() -> bool: return airborne
	_hurtbox.is_parried = func(from: Vector2) -> bool:
		return _parry.catches(from, global_position, facing)
	_hurtbox.parry_stagger = tuning.parry_stagger
	_hurtbox.damage_through = func(damage: float, from: Vector2) -> float:
		return _block.receive_hit(damage, from, global_position, facing)


func _physics_process(delta: float) -> void:
	if _dead:
		_lie_limp(delta)
		return
	_noise_before = noise_radius
	if _hiding:
		_stay_hidden(delta)
		return
	# A Guard break that runs out in this frame is still spent open, though the block clears it
	# before the frame is over. So it is read once, here, for everything below.
	var left_recoiling := _recoil_left > 0
	if left_recoiling:
		_recoil_left -= 1
	# A recoil is spent open in just the same way, and is counted from the frame after the Parry.
	var left_open := _block.guard_broken or left_recoiling
	# Likewise a Parry whose last recovery frame this is is still spent standing open.
	var left_parrying := _parry.parrying
	_casting = spell.winding_up
	_sipping = flasks.sipping
	# get_vector applies the deadzone to the stick as a whole, not axis by axis, and
	# never returns more than length 1, so diagonals are no faster.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Lock-on goes first, because everything below aims or moves by it: a target that died or
	# got away since the last frame is let go of here, and a press of its button is read. It is
	# told the direction every frame, even one spent in a Roll or a swing, so that it can tell
	# a direction held from one let go of.
	_lock_on.advance(direction)
	# The order matters: a tap has to be read before the timer is reset by the end of the
	# press, and the timer has to be advanced before _move_freely reads it.
	var tapped := _roll_button_was_tapped()
	_advance_roll_button_timer(delta)
	# A finished Roll is ended at the start of the next frame, so that a queued Roll can
	# start in that same frame and follow it without a gap.
	if rolling and _roll_time >= tuning.roll_duration - TIME_SLACK:
		_end_roll(direction)
	# In the air he can do none of these, and a press of their buttons is lost, as it is in a
	# Guard break; only a Heavy attack press is read, as a Jump attack. A Jump that comes down in
	# this frame is still spent in the air.
	var in_the_air := airborne
	# A press of the Switch button is read ahead of the attacks, so that one made in the frame a
	# swing's recovery ends counts as waiting for it, as an attack press made in that frame counts as
	# kept for it. It is lost in a Guard break or a Parry; a Parry begun in this frame wins against it
	# (see below).
	var switch_was_waiting := _switch_waiting
	var switch_pressed := Input.is_action_just_pressed(&"switch_weapon") and not left_open and not left_parrying and not _sipping and not spell.holding
	if switch_pressed:
		_switch_waiting = true
	_attacks.advance(_aim(), not rolling and not left_open and not left_parrying and not in_the_air and not _casting and not _sipping and not spell.holding, in_the_air and not spell.holding)
	# An attack commits him and a Guard break or a Parry leaves him open, so a tap in any of
	# them is lost, not kept for after it.
	if tapped and not _attacks.committed and not left_open and not left_parrying and not in_the_air and not _casting and not _sipping:
		_on_roll_tapped(direction)
	# A Parry can be begun from a Sprint or while blocking, but not in a Roll, an attack or a
	# Guard break, nor in a Parry. The attack and the Roll have begun by now if they were going
	# to this frame, and so win against a Parry press made in the same frame.
	_parry.advance(_free_to_act(left_open, left_parrying, in_the_air) and not spell.holding)
	var parry_on := left_parrying or parrying
	# The Spell is made from the same places as resting is, and its wind-up commits him: it begins
	# only if he is free and not blocking, and an attack, a Roll or a Parry begun in this frame wins
	# against a press made in the same frame.
	spell.advance(_free_to_act(left_open, parry_on, in_the_air) and not blocking, _aim())
	_casting = _casting or spell.winding_up
	# A Sip is made from the same places, and an attack, a Roll, a Parry or a Spell begun in this frame
	# wins against a press made in the same frame. A press he cannot Sip on is lost, as is one with no
	# charge left.
	# Like the Spell, it is not made while blocking.
	if _free_to_act(left_open, parry_on, in_the_air) and not blocking and not spell.holding:
		if Input.is_action_just_pressed(&"sip_health"):
			flasks.sip()
		elif Input.is_action_just_pressed(&"sip_mana"):
			flasks.sip_mana()
	flasks.advance(delta)
	_sipping = _sipping or flasks.sipping
	# A Jump can be begun from a walk, a Sprint or while blocking, in the same places: not in a
	# Roll, an attack, a Guard break or a Parry, which have begun by now if they were going to
	# this frame and so win against a Jump press made in the same frame, nor in the air. It is
	# read before Block is, so that blocking ends as he leaves the ground.
	if _jump_pressed_and_free(left_open, parry_on, in_the_air):
		_take_off(direction, delta)
	# A switch is made in a Roll, a Block or a Jump, but not in a Guard break or a Parry, where the
	# press is lost. A press in an attack waits for it to end, which is the frame its recovery ends
	# (a press kept for that frame is made with the new Weapon), or the frame he lands in a gap that
	# cancels a Jump attack. What waits is made here once he is not in an attack, which comes after the
	# attacks have been advanced, so that a Heavy attack charge or a swing that ends in this frame
	# lets it through at once. A Parry begun in this frame wins against a switch press made in the
	# same frame, though not against one that was already waiting.
	if switch_pressed and parry_on and not switch_was_waiting:
		_switch_waiting = false
	_advance_switch()
	# Interact is a tap or a hold, read as he is free and not blocking as the last frame left it,
	# since this comes before Block is advanced. A tap rests at a Checkpoint in reach, or else picks
	# up a Weapon or Armour in reach; a hold drops the Weapon in hand. A Jump taken off in this frame wins
	# against a press made in the same frame, since he is in the air by now.
	_advance_interact(_free_to_act(left_open, parry_on, airborne) and not blocking and not spell.holding, delta)
	# Getting into a Hiding spot in this frame leaves him in it, still, whatever else was pressed.
	if _hiding:
		return
	# He is free to block unless he is in a Roll, an attack or a Parry, which have begun by now
	# if they were going to this frame, or sprinting, which is as the last frame left it, or in
	# the air.
	_block.advance(not left_recoiling and not rolling and not _attacks.committed and not parry_on and not sprinting and not airborne and not _casting and not _sipping and not spell.holding, delta)
	# Set every frame, ahead of Stamina's own processing in this frame, so that it never lags.
	stamina.refill_factor = tuning.block_stamina_refill_factor if blocking else 1.0
	if airborne:
		_jump.advance(delta)
	elif rolling:
		_roll(delta)
	elif _attacks.committed or left_open or parry_on or _casting:
		_stand_still()
	else:
		_move_freely(direction, delta)
	# Under Lock-on he ends every frame facing the target, whatever he did in it. This comes
	# after the move, so that it is where he has got to that he faces, and not where he was.
	_face_the_target()
	# Turning the placeholder shape stands in for the eight facing sprites.
	_placeholder.rotation = facing.angle()


# His Health has reached zero: he goes limp where he is. Every action he was in ends at once, and
# whatever he had locked on to is let go of. A press of any button made from here is lost.
func _fall() -> void:
	if _dead:
		return
	_dead = true
	_dead_for = 0.0
	_pause_announced = false
	_end_every_action()
	_placeholder.modulate = DEATH_TINT
	died.emit(global_position)


# One frame of lying limp: the pause is counted in summed frame lengths compared with death_pause
# through TIME_SLACK, as the Roll is, and its end is announced once. He neither reads input nor
# moves.
func _lie_limp(delta: float) -> void:
	_dead_for += delta
	if not _pause_announced and _dead_for >= tuning.death_pause - TIME_SLACK:
		_pause_announced = true
		death_pause_over.emit()


## Gives him his Mana bar, once and for good: it starts full, sized by the Mana stat as it stands now,
## so the points bought before he had the bar are in it. A bar he already has is left as it is. The
## Mana Flask holds its charges from the next Checkpoint refill on. The Time Keeper's mark calls this.
func grant_mana_bar() -> void:
	mana.grant(tuning.mana_maximum())


## He is back on his feet at this point, in global coordinates: on the ground level, with full
## Health, Stamina, Mana and Flask charges, still, and in none of the actions. He carries the Weapons
## he carried at his last rest, with the same one in hand, and wears the Armour he wore then (what
## he started with, if he has not rested): what he took since is not his any more. His Experience,
## his facing and everything outside him are left as they are; whoever sends him back sees to those.
func return_to(point: Vector2) -> void:
	_end_every_action()
	_dead = false
	_dead_for = 0.0
	_roll_press_lost = Input.is_action_pressed(&"roll")
	_placeholder.modulate = Color.WHITE
	global_position = point
	health.refill()
	stamina.refill()
	mana.refill()
	flasks.refill()
	weapons.restore(_saved_weapons, _saved_in_hand_index)
	armour = _saved_armour
	returned.emit()


# The attack he made was Parried: it is over at once, with the sword off, and he recoils.
func _on_attack_parried(_hurtbox: Hurtbox) -> void:
	_attacks.reset()
	_recoil_left = tuning.parried_recoil_frames


# Ends whatever he is in, at once, and leaves him still: a Hiding spot, a Roll and the Roll kept for its end,
# a Sprint, a swing, a charge, a Jump, a Block, a Guard break, a recoil, a Parry and the Lock-on, along with
# what each of them showed. The Roll button is forgotten, so that a hold begun before does not
# count after, and so are an Interact press being timed and a switch kept for the end of a swing.
# What he carries is left as it is.
func _end_every_action() -> void:
	_state = State.WALKING
	_roll_time = 0.0
	_roll_queued = false
	_roll_button_held_for = 0.0
	_out_of_breath = false
	_interact_counted = false
	_switch_waiting = false
	velocity = Vector2.ZERO
	if _hiding:
		_hiding = false
		_placeholder.modulate = Color.WHITE
	_recoil_left = 0
	_attacks.reset()
	_block.reset()
	_parry.reset()
	_jump.reset()
	spell.reset()
	_casting = false
	flasks.reset()
	_sipping = false
	_lock_on.release()


func _move_freely(direction: Vector2, delta: float) -> void:
	var sprint := false
	if _wants_to_sprint(direction):
		# The only place a Sprint is paid for. When spend() fails Stamina is gone, which
		# drops him back to walking until the button is let go and held again.
		sprint = stamina.spend(tuning.sprint_stamina_per_second * delta)
		_out_of_breath = not sprint
	_state = State.SPRINTING if sprint else State.WALKING
	velocity = _walking_velocity(direction, delta, sprint)
	move_and_slide()


# The velocity he walks, sprints or, blocking, walks slowly at this frame, turning him to the
# way he goes. Under Lock-on he circles the target instead of walking where the stick points.
func _walking_velocity(direction: Vector2, delta: float, sprint: bool) -> Vector2:
	var speed := tuning.walk_speed
	if sprint:
		speed = tuning.sprint_speed
	elif _sipping:
		speed = flasks.tuning.sip_walk_speed
	elif blocking:
		speed = tuning.block_walk_speed
	if _lock_on.locked:
		# He circles the target instead of walking where the stick points, and faces it
		# whichever way he goes (see _face_the_target).
		return _lock_on.circling_velocity(direction, speed, delta)
	if direction != Vector2.ZERO:
		_face(direction)
	return direction * speed


# Whether the Jump button was pressed this frame by someone free to Jump. The press is read
# only then, so that one made when he is not free is lost, not kept for after.
func _jump_pressed_and_free(left_open: bool, parry_on: bool, in_the_air: bool) -> bool:
	return _free_to_act(left_open, parry_on, in_the_air) and Input.is_action_just_pressed(&"jump")


# Whether he is free to begin something new: not in a Roll, an attack (charging a Heavy attack
# and a Jump attack included), a Guard break, a Parry, the air, the wind-up of a Spell or a Sip. A Guard break or a Parry whose
# last frame this is is still spent open, so the caller says whether one is on him.
func _free_to_act(left_open: bool, parry_on: bool, in_the_air: bool) -> bool:
	return not rolling and not _attacks.committed and not left_open and not parry_on and not in_the_air and not _casting and not _sipping


# Times a press of the Interact button and acts on it. A press counts only if it begins while he
# is free, which is the same as for resting: not in a Roll, an attack, a Guard break, a Parry or
# the air, and not blocking. One made when he is not free is lost, not kept for after, and so is
# one he stops being free in the middle of. Let go of before drop_hold_time it is a tap, which
# rests at a Checkpoint in reach, or picks up a Weapon or Armour in reach if there is no Checkpoint.
# Held to drop_hold_time it drops the Weapon in hand, once, on the frame it gets there, and neither
# picks up nor rests when it is let go of. The time is counted in summed frame lengths compared
# through TIME_SLACK, as the Roll's hold is. The button is polled, as the Roll button is: a press
# and release that both land before the same frame never show it down, so the just-pressed check
# catches them.
func _advance_interact(free: bool, delta: float) -> void:
	var down := Input.is_action_pressed(&"interact")
	if _interact_counted and not free:
		_interact_counted = false
		return
	if _interact_counted and (not down or Input.is_action_just_released(&"interact")):
		_interact_counted = false
		if not _interact_hold_spent:
			_on_interact_tapped()
	if not _interact_counted:
		if not free or not Input.is_action_just_pressed(&"interact"):
			return
		_interact_counted = true
		_interact_held_for = 0.0
		_interact_hold_spent = false
		if not down:
			_interact_counted = false
			_on_interact_tapped()
			return
	_interact_held_for += delta
	if not _interact_hold_spent and _interact_held_for >= tuning.drop_hold_time - TIME_SLACK:
		_interact_hold_spent = true
		if not _hiding:
			_drop_the_weapon_in_hand()


# A tap of Interact: in a Hiding spot he leaves it. Otherwise he rests if a Checkpoint is in reach,
# or else hides if a Hiding spot is, or else picks up a Weapon or Armour, and takes the Jailer's
# key only if there is none of those, so a pickup lying beside a Checkpoint or a Hiding spot stays
# where it is.
func _on_interact_tapped() -> void:
	if _hiding:
		_leave_hiding()
	elif not _rest_at_a_checkpoint_in_reach() and not _hide_in_a_spot_in_reach() and not _pick_up_a_pickup_in_reach():
		_take_a_key_in_reach()


# One frame in a Hiding spot: he neither moves nor acts, and a tap of Interact leaves. A Roll button
# press made in there is lost, so that holding it on the way out does not Roll or Sprint.
func _stay_hidden(delta: float) -> void:
	_roll_press_lost = Input.is_action_pressed(&"roll")
	velocity = Vector2.ZERO
	_advance_interact(true, delta)


# Gets into the nearest Hiding spot within hide_reach of him, if there is one, and says whether he
# did. Every enemy is told first, from where he stands: those that saw him get in go to the spot
# to drag him out, and every other pursuer ends its Pursuit at once. Then he is in the spot, still,
# and in none of the actions.
func _hide_in_a_spot_in_reach() -> bool:
	var nearest: HidingSpot = null
	var nearest_distance := tuning.hide_reach
	for node in get_tree().get_nodes_in_group(&"hiding_spots"):
		var spot := node as HidingSpot
		if spot == null:
			continue
		var distance := global_position.distance_to(spot.global_position)
		if distance <= nearest_distance:
			nearest = spot
			nearest_distance = distance
	if nearest == null:
		return false
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy.has_method(&"react_to_hiding"):
			enemy.react_to_hiding(nearest.global_position, _noise_before)
	_end_every_action()
	global_position = nearest.global_position
	_hiding = true
	_hiding_spot = nearest
	if nearest.flammable != null and not nearest.flammable.caught.is_connected(_on_hiding_spot_caught):
		nearest.flammable.caught.connect(_on_hiding_spot_caught)
	_placeholder.modulate = HIDDEN_TINT
	return true


# He leaves the Hiding spot, standing where it is.
func _leave_hiding() -> void:
	_hiding = false
	_placeholder.modulate = Color.WHITE


# A Hiding spot caught Fire: if it is the one he is in, he is out of it at once, as with a tap, and
# so can be hurt by the Fire.
func _on_hiding_spot_caught() -> void:
	if _hiding and _hiding_spot != null and _hiding_spot.flammable != null and _hiding_spot.flammable.burning:
		_leave_hiding()


# A hit landed on him: in a Hiding spot, that pulls him out of it.
func _on_hurt_landed(_stagger: float, _from: Vector2, _critical: bool) -> void:
	if _hiding:
		_leave_hiding()


# Rests at the nearest Checkpoint within rest_reach of him, if there is one: Health, Stamina, Mana
# (if he has the bar) and the Flasks are refilled, the Checkpoint flashes and the rest is announced. Says whether he rested; a tap
# with none in reach does nothing.
func _rest_at_a_checkpoint_in_reach() -> bool:
	var nearest: Checkpoint = null
	var nearest_distance := tuning.rest_reach
	for node in get_tree().get_nodes_in_group(&"checkpoints"):
		var checkpoint := node as Checkpoint
		if checkpoint == null:
			continue
		var distance := global_position.distance_to(checkpoint.global_position)
		if distance <= nearest_distance:
			nearest = checkpoint
			nearest_distance = distance
	if nearest == null:
		return false
	spell.reset()
	health.refill()
	stamina.refill()
	mana.refill()
	flasks.refill()
	_save_the_gear(weapons)
	nearest.rest(tuning.rest_flash_duration)
	rested.emit(nearest)
	return true


# Keeps the Weapons he carries, the one in hand and the Armour he wears, as what a Death gives back.
func _save_the_gear(own_weapons: AlmosWeapons) -> void:
	_saved_weapons = own_weapons.carried
	_saved_in_hand_index = own_weapons.in_hand_index
	_saved_armour = armour


# Takes up the nearest Weapon or Armour lying within pickup_reach of him, if there is one, and
# only that one, and says whether he did. A Weapon is carried from then on, after the others;
# Armour is worn at once. The pickup is gone from the ground.
func _pick_up_a_pickup_in_reach() -> bool:
	var nearest: Node2D = null
	var nearest_distance := tuning.pickup_reach
	for node in get_tree().get_nodes_in_group(&"weapon_pickups") + get_tree().get_nodes_in_group(&"armour_pickups"):
		var pickup := node as Node2D
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		if not (pickup is WeaponPickup and pickup.weapon != null) and not (pickup is ArmourPickup and pickup.armour != null):
			continue
		var distance := global_position.distance_to(pickup.global_position)
		if distance <= nearest_distance:
			nearest = pickup
			nearest_distance = distance
	if nearest == null:
		return false
	if nearest is WeaponPickup:
		weapons.pick_up(nearest.weapon)
	else:
		armour = nearest.armour
	# One with an id is noted taken until the next rest, so that a Death puts it back.
	if nearest.id != &"":
		WorldState.record_taken(nearest.id)
	nearest.queue_free()
	return true


# Takes the nearest Jailer's key lying within pickup_reach of him that can be taken, if there is
# one. He has it for good: it is kept through a Death, and the key is gone from the ground.
func _take_a_key_in_reach() -> void:
	var nearest: JailersKey = null
	var nearest_distance := tuning.pickup_reach
	for node in get_tree().get_nodes_in_group(&"key_pickups"):
		var key := node as JailersKey
		if key == null or key.is_queued_for_deletion() or not key.takeable:
			continue
		var distance := global_position.distance_to(key.global_position)
		if distance <= nearest_distance:
			nearest = key
			nearest_distance = distance
	if nearest == null:
		return
	WorldState.record_kept(nearest.id)
	nearest.queue_free()


# Leaves the Weapon in hand on the ground where he stands, as a pickup in his own parent, and the
# next one he carries comes to hand. With empty hands there is nothing to drop.
func _drop_the_weapon_in_hand() -> void:
	var dropped := weapons.drop()
	if dropped == null:
		return
	var pickup := WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
	pickup.weapon = dropped
	pickup.position = position
	get_parent().add_child(pickup)


# Hands his attacks the Weapon in hand, or Unarmed when his hands are empty.
func _hand_over_the_weapon_in_hand() -> void:
	_attacks.weapon = weapons.in_hand if weapons.in_hand != null else unarmed


# The torch in hand burns, lights the way, sets things alight with his swings, and can be drawn; with anything else in hand, or
# nothing, the carried torch is out and out of the group of torches. Putting it out here is not a
# draw, so it leaves no unlit club behind.
func _tend_the_carried_torch() -> void:
	var burning := torch_weapon != null and weapons.in_hand == torch_weapon
	# A lit torch in hand sets alight what his swings reach; it is not drawn by doing so.
	_attacks.hitbox.ignites = burning
	if burning:
		carried_torch.relight()
		carried_torch.add_to_group(&"torches")
	else:
		carried_torch.remove_from_group(&"torches")
		carried_torch.extinguish()


# The torch in hand has been drawn: it is an unlit club from now on, in the same place in the list
# and still in hand.
func _leave_an_unlit_club() -> void:
	if torch_weapon != null and weapons.in_hand == torch_weapon:
		weapons.replace_in_hand(unlit_torch)


# A press of the Switch button puts the next carried Weapon in hand, at once, unless he is in an
# attack (a swing, a Heavy attack charge or a Jump attack) or in the wind-up of his Spell, which
# a switch would spoil by putting out the torch in hand: then it waits, and is made in the frame
# the attack is over. For a swing that is the frame its recovery ends, ahead of the attack kept for
# that frame (see _make_the_waiting_switch), and for a Jump attack that a gap cancels, the frame he
# lands in (see _on_landed). Only one press waits, and a press made while one is waiting does not
# add another. This makes the waiting switch in any other frame he is not in an attack.
func _advance_switch() -> void:
	if _switch_waiting and spell.holding:
		# A Switch is not made while he holds a flame; the one that waited for the wind-up is lost.
		_switch_waiting = false
	elif _switch_waiting and not _attacks.committed and not _casting:
		_make_the_waiting_switch()


# He has come down from a Jump. A Jump attack pressed in it strikes now, or is cancelled by a gap,
# and a switch that waited for it is then made in this very frame if he is not in an attack, so that
# a press made in the next frame is made with the new Weapon.
func _on_landed(in_a_gap: bool) -> void:
	_attacks.jump_ended(in_a_gap)
	if not _attacks.committed:
		_make_the_waiting_switch()


# Puts the next carried Weapon in hand, if a switch is waiting.
func _make_the_waiting_switch() -> void:
	if not _switch_waiting:
		return
	_switch_waiting = false
	weapons.switch_to_next()


# He takes off with the velocity he has this frame: walking, sprinting (which the Jump ends, so
# the frame is not paid for) or blocking, or none standing still. Block is read as the last
# frame left it, since this comes before Block is advanced. A press he cannot pay for is no
# Jump, and he carries on as usual; a Jump that costs nothing needs no Stamina.
func _take_off(direction: Vector2, delta: float) -> void:
	if tuning.jump_stamina_cost > 0.0 and not stamina.spend(tuning.jump_stamina_cost):
		return
	var sprint := _state == State.SPRINTING and _wants_to_sprint(direction)
	_state = State.WALKING
	_jump.begin(_walking_velocity(direction, delta, sprint))


# An attack commits him: he neither walks nor sprints from the moment he begins charging a
# Heavy attack or swinging until the recovery is over. A Guard break leaves him standing
# the same way, and so does a Parry. He still takes the step that moves nothing, as a free
# frame without a push of the stick does, because that is what pushes him out of a body he has
# landed on: only a step separates him from one, and a Jump attack or a Parry begun on landing
# would otherwise have him stand inside an enemy to the end.
func _stand_still() -> void:
	_state = State.WALKING
	velocity = Vector2.ZERO
	move_and_slide()


# Whether he is trying to Sprint: pushing a direction with the Roll button held to the
# threshold, and not already out of breath. While blocking he cannot Sprint, so the hold is
# passed over. A Sprint he was in when he pressed Block is not ended by it: he does not block
# while he sprints. It only asks; paying for the Sprint is up to the caller.
func _wants_to_sprint(direction: Vector2) -> bool:
	return direction != Vector2.ZERO and _held_to_the_threshold() and not _out_of_breath and not blocking and not _sipping


func _face(direction: Vector2) -> void:
	facing = Vector2.from_angle(snappedf(direction.angle(), FACING_STEP))


# Under Lock-on, turns him to the target, whichever way he is going and whatever he is doing.
# Without Lock-on, or standing on the target, there is nothing to turn to and he keeps his
# facing.
func _face_the_target() -> void:
	# The Critical hit keeps him facing the broken enemy it was made at, to the end of its
	# swing; the lock itself holds, and turns him back to its target after.
	if _attacks.critical:
		return
	var to_target := _lock_on.direction_to_target()
	if to_target != Vector2.ZERO:
		_face(to_target)


# Which way an attack that begins now is aimed: exactly at the target under Lock-on, not at
# the nearest of the eight facings, and along his facing otherwise.
func _aim() -> Vector2:
	var to_target := _lock_on.direction_to_target()
	return to_target if to_target != Vector2.ZERO else facing


# The button is polled every frame, rather than listening for its events, so that it
# reads the same whether it was pressed by a key, a pad or an action press. A press let
# go before the hold threshold is a tap. A longer one was a hold (a Sprint, if he was
# moving), so letting go of it does not Roll. A press and release that both land before
# the same frame never show the button down, so the just-pressed and just-released
# checks catch them.
#
# Whether the press ended this frame as a tap. It only asks, and must be called before
# _advance_roll_button_timer, which forgets the press once it has ended.
func _roll_button_was_tapped() -> bool:
	if _roll_press_ended():
		return not _held_to_the_threshold()
	# Pressed and let go again before this frame, so it was never seen down.
	return Input.is_action_just_pressed(&"roll") and not Input.is_action_pressed(&"roll")


# Times how long the button has been held, and forgets the press once it has ended.
func _advance_roll_button_timer(delta: float) -> void:
	if _roll_press_lost:
		_roll_press_lost = Input.is_action_pressed(&"roll")
		return
	if _roll_press_ended():
		_roll_button_held_for = 0.0
		_out_of_breath = false
	if Input.is_action_pressed(&"roll"):
		_roll_button_held_for += delta


# Whether the press being timed is over: the button was let go, even if it went down
# again in the same frame.
func _roll_press_ended() -> bool:
	return _roll_button_held_for > 0.0 \
			and (not Input.is_action_pressed(&"roll") or Input.is_action_just_released(&"roll"))


# Whether the press being timed has lasted as long as the hold threshold: from then on it
# is a hold, and letting go of it is not a tap.
func _held_to_the_threshold() -> bool:
	return _roll_button_held_for >= tuning.roll_hold_threshold - TIME_SLACK


func _start_roll(direction: Vector2) -> void:
	if not stamina.spend(tuning.roll_stamina_cost):
		return
	_roll_direction = direction.normalized() if direction != Vector2.ZERO else _neutral_roll_direction()
	# Under Lock-on he keeps facing the target through the Roll, wherever it takes him.
	if not _lock_on.locked:
		_face(_roll_direction)
	_roll_time = 0.0
	_state = State.ROLLING


# Where a Roll with no direction pushed goes: the way he faces, or under Lock-on directly
# away from the target, since facing it he would otherwise Roll into it.
func _neutral_roll_direction() -> Vector2:
	var to_target := _lock_on.direction_to_target()
	return -to_target if to_target != Vector2.ZERO else facing


func _on_roll_tapped(direction: Vector2) -> void:
	if not rolling:
		_start_roll(direction)
	elif tuning.roll_duration - _roll_time <= tuning.roll_buffer_window + TIME_SLACK:
		_roll_queued = true


func _end_roll(direction: Vector2) -> void:
	_state = State.WALKING
	if _roll_queued:
		_roll_queued = false
		_start_roll(direction)


func _roll(delta: float) -> void:
	# The last frame is cut short if the Roll does not end on a frame boundary, so the
	# Roll always covers exactly roll_distance.
	var step := minf(delta, tuning.roll_duration - _roll_time)
	_roll_time += step
	velocity = _roll_direction * tuning.roll_distance / tuning.roll_duration * step / delta
	move_and_slide()
