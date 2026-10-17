# The Broken World

A top-down 2D action RPG with souls-lite combat, set on a world that stopped spinning: one half in permanent night, one in permanent day, the Tempest between them.

## Language

### World

**Marked**:
A Nar born to the Path of the Deep, required to wear a Seal. Almos is Marked.
_Avoid_: Marked one, Deep mage

**Seal**:
The ring the Marked wear around the neck, which stops them channelling. Almos's Seal breaks at the end of the Base of the tree.
_Avoid_: Ring, neck ring, collar

### Areas

In play order: Base of the tree → Dungeons → Upper tree → Lands between → Tempest. The areas are fully connected: the player can return to any area, including the arch tree, at any time.

**Base of the tree**:
The first area, at the foot of the arch tree, where the game begins. Its enemies are creatures that have crept in from the dark, until its last stretch, when Almos is caught and the Nar guards turn on him. It ends when his Seal breaks and he is thrown into the Dungeons.
_Avoid_: Tree base, roots

**Dungeons**:
The prison in the roots beneath the arch tree, where Almos is held after his Seal breaks. He enters stripped of his Weapon and Armour, keeping only his Flasks, and fights Unarmed, with improvised Weapons and with Flame draw. Its enemies are Nar jailers, who Block and Parry, and creatures living in the roots. He meets no NPCs here.
_Avoid_: Prison, cells, roots

**Upper tree**:
The trunk and canopy of the arch tree, which Almos climbs to escape from the Dungeons and from which he leaves the tree. The area of Jumps and Deadly falls. Its enemies are Nar guards hunting the fugitive, some attacking from higher branches, and creatures of the canopy. He meets no NPCs here.
_Avoid_: Canopy, treetop, branches

**Lands between**:
The ground beyond the arch tree that Almos reaches after his escape, where he meets the Mage teacher and fights the Lesser god. Its enemies are wild creatures of the dark and the Undead.
_Avoid_: Wilds, outlands, midlands

**Tempest**:
The storm-wracked band between the dayside and the Shadowlands; the last of the first areas. Its enemies are storm-hardened creatures and hostile mages, Necro mages among them. Its Wind pushes the player, and Lightning strikes the ground.
_Avoid_: Twilight zone, storm belt

**Vision**:
The dreamlike place in the Lands between that Almos enters by touching something toxic, where he fights the Lesser god. Dying there leaves his Remains at the entrance in the real world.
_Avoid_: Dream, trip, hallucination

**Fugitive**:
Almos's standing in the arch tree after his escape. From then on, Nar guards patrol the Base of the tree, the Dungeons and the Upper tree alongside the creatures, and treat him as an enemy on sight.
_Avoid_: Wanted, outlaw, exile

**Wind**:
The Tempest's gusts, which push the player in a visible direction. Rolls, Jumps and Sprints carry further with the Wind and fall short against it.
_Avoid_: Gust, storm push

**Lightning**:
A Tempest strike marked on the ground a moment before it lands. Parrying it lets the player catch it as a Storm draw.
_Avoid_: Bolt, thunder strike

### Player state

**Health**, **Stamina**, **Mana**:
The player's three bars. Only Stamina refills by itself; Health and Mana come back only at Checkpoints and from Flasks. Almos has no Mana bar at first: he gains it from the Mage teacher early in the Lands between.
_Avoid_: HP, energy, FP, mana points

**Health Flask**, **Mana Flask**:
The two refillable vessels the player carries, each holding its own fixed number of charges that restore its bar. Every Checkpoint refills both, and upgrades found while exploring add charges. Almos carries the Mana Flask from the start, but it stays empty and useless until he gains his Mana bar.
_Avoid_: Estus, potion bottle, potions (as separate items)

**Sip**:
Drinking one Flask charge: a short animation that cannot be cancelled, during which the player can only walk slowly. The bar refills at the end; a hit before then wastes the charge.
_Avoid_: Drink, heal, quaff

**Flask upgrade**:
A collectible found while exploring that adds one charge to both the Health Flask and the Mana Flask.
_Avoid_: Estus shard, flask shard, charge upgrade

**Experience**:
What the player gains by killing enemies. It only turns into Levels when cashed in at a Checkpoint; Experience not yet cashed in is at risk when the player dies. It is not a currency and cannot be spent anywhere else.
_Avoid_: Souls, XP, currency, runes

**Level**:
One step of the player's growth, bought with Experience at a Checkpoint. Each Level adds one point to a stat of the player's choice: Health, Stamina, Mana, Strength or Channelling. Mana can be levelled before Almos has a Mana bar; the points are waiting in it when he gains it.
_Avoid_: Level-up point, rank

**Strength**:
The stat that raises Weapon damage and sets the greatest Weight a Spell can move.
_Avoid_: Might, power, attack

**Weight**:
How heavy an enemy or object is. A Spell that pushes or lifts can only move things whose Weight is within what the player's Strength allows.
_Avoid_: Mass, size class, poise

**Channelling**:
The stat that raises Spell damage.
_Avoid_: Intelligence, magic, arcane, faith

**Remains**:
The marker left where the player died, holding all the Experience not yet cashed in; after a Deadly fall it is left on the last solid ground the player stood on, and after a death in the Vision it is left at the Vision's entrance. Reaching it recovers that Experience; dying again before reaching it destroys it.
_Avoid_: Bloodstain, corpse, grave, souls

**Checkpoint**:
A resting place that refills all three bars and both Flasks and becomes the player's return point. It is also where Experience is cashed in for Levels and where Armour is changed. Resting at one brings back every ordinary enemy; Bosses and named enemies stay dead. Resting is not sleep: it works the same after the Lesser god takes Almos's ability to sleep.
_Avoid_: Bonfire, save point, shrine (until a lore name is chosen)

### Movement and combat

**Lock-on**:
The state in which the player targets a single enemy; while it holds, movement circles that enemy and every attack and roll is aimed relative to it.
_Avoid_: Target lock, Z-targeting, focus

**Weapon**:
Anything the player can sensibly fight with, each with its own Light attack and Heavy attack: a sword, spear or greatsword, but also an improvised object such as a torch or a metal bar. Weapons can be picked up and swapped anywhere, and every carried Weapon counts toward the player's Load. They never break and are never upgraded; those found deeper in the world are stronger.
_Avoid_: Blade, arm, gear

**Armour**:
A single piece of protective gear found in the world that reduces damage taken, at the cost of a slower, shorter Roll as it gets heavier. The player wears one piece at a time and changes it only at a Checkpoint.
_Avoid_: Gear, outfit, equipment (for armour alone)

**Load**:
The total Weight of everything the player wears and carries: Armour and every Weapon. While it stays within the limit set by the Stamina stat, the Roll is normal; past it, the Roll becomes slower and shorter; past a hard ceiling above that, the player can pick up nothing more.
_Avoid_: Equip load, burden, encumbrance

**Unarmed**:
Fighting with fists when no Weapon is held: weak Light and Heavy attacks, with Stagger and Parry still working.
_Avoid_: Fists, bare hands, brawling

**Light attack**:
A quick swing that chains into a short combo; costs stamina and commits the player to its animation.
_Avoid_: Attack, slash, quick attack

**Heavy attack**:
A slower, harder swing that can be charged by holding and builds more Stagger than a Light attack.
_Avoid_: Strong attack, power attack, charge attack

**Spell**:
A channelled ability with its own button. Spells normally cost Mana and Stamina, since channelling is physical work. Almos's first Spell is Flame draw; the Mage teacher teaches him Shove, Pull and Deep bolt.
_Avoid_: Magic, ability, skill, cast

**Flame draw**:
Almos's first Spell, discovered in the Dungeons: he channels the fire out of a magical torch and throws it as a single fireball. It costs Health and Stamina instead of Mana and Stamina, and each torch's flame can be drawn only once. That includes a torch carried as a Weapon, which is left as an unlit club. Torches on walls and stands relight whenever enemies return.
_Avoid_: Torch spell, fire grab, flame weapon

**Shove**:
A Spell that pushes an enemy or object away from the player. It can only move things whose Weight is within what Strength allows.
_Avoid_: Push, force push, telekinesis

**Pull**:
A Spell that drags an enemy or object toward the player, including items across gaps the player cannot Jump. Limited by Weight, like Shove.
_Avoid_: Grab, yank, telekinesis

**Deep bolt**:
A ranged Spell of the Path of the Deep, paid for with Mana and Stamina; the player's everyday ranged attack, needing no torch or storm.
_Avoid_: Magic missile, mana bolt, blast

**Storm draw**:
Catching a Parried Lightning strike and throwing it as a single bolt, in the manner of Flame draw. It costs Stamina only, since the storm supplies the power. A caught bolt lasts only a few seconds before it fades.
_Avoid_: Lightning catch, bolt throw, thunder parry

**Roll**:
The player's preferred defence: a quick evasive move in any direction that costs stamina and briefly makes the player untouchable.
_Avoid_: Dodge, dash, evade

**Sprint**:
Fast running, done by holding the Roll button; drains Stamina continuously and stops it refilling while it lasts.
_Avoid_: Run, dash

**Jump**:
A hop with its own button that carries the player across gaps, up onto low ledges, and over Low attacks. It gives no invulnerability: anything else still hits.
_Avoid_: Leap, hop, vault

**Jump attack**:
A Heavy attack started in mid-air that comes down hard and builds extra Stagger.
_Avoid_: Plunge, aerial, dive attack

**Drop**:
Stepping or jumping off an edge onto ground below. A Drop shorter than the safe height is harmless; one past it, or into empty space, is a Deadly fall.
_Avoid_: Fall (for a safe drop), ledge hop

**Deadly fall**:
A Drop past the safe height or into empty space, which kills the player. Nothing warns of it in advance; players learn which edges are deadly by dying.
_Avoid_: Pit, fall damage, void-out

**Block**:
A held guard that reduces incoming damage without negating it; each blocked hit also costs stamina. The fallback when a roll isn't possible.
_Avoid_: Guard, shield

**Guard break**:
The stagger that follows when a blocked hit takes the player's last stamina, leaving them open to a follow-up.
_Avoid_: Shield break, block break

**Parry**:
A deflect with a tight timing window that negates an incoming attack and adds to the attacker's Stagger; the hardest and most precise defence.
_Avoid_: Deflect, counter

**Stagger**:
An enemy's accumulated loss of balance, shown as a meter that fills toward a Break. Parries build it fastest; Jump attacks, Heavy attacks and hits from behind more slowly; and it drains when the player stops pressing the enemy.
_Avoid_: Poise, posture, balance

**Break**:
The moment an enemy's Stagger fills, leaving it helpless and open to a Critical hit.
_Avoid_: Stun, posture break

**Critical hit**:
The heavy follow-up the player can land on a broken enemy.
_Avoid_: Riposte, deathblow, visceral

### People

**NPC**:
A character the player can talk to, placed as an anchor for the story; some hand Almos an item at a story moment. NPCs give no quests and do not trade.
_Avoid_: Villager, quest giver, merchant

**Emrys**:
Almos's Guardian, dying, met in the Base of the tree. He escapes the arch tree separately and does not appear in the Dungeons or the Upper tree.
_Avoid_: The Guardian, mentor

**Massel**:
A young Marked child in the Base of the tree, on whom Emrys draws to stay alive.
_Avoid_: The child, the Marked child

**Time Keeper**:
A dying Time Keeper met in the Lands between, who tells Almos of the lost city and its memory tree.
_Avoid_: The old one, the keeper

**Mani**:
A wind-casting mage met in the Tempest.
_Avoid_: The storm mage

**Cersei**:
Mani's ally, a healer, met in the Tempest.
_Avoid_: The healer

**Mage teacher**:
The mage Almos meets early in the Lands between, who gives him his Mana bar and teaches him Shove, Pull and Deep bolt before he faces the Lesser god.
_Avoid_: Mentor, master, trainer

### Enemies

**Boss**:
A unique enemy fought only at a story turning point. Once killed it stays dead. The only Boss in the first areas is the Lesser god, in the Lands between.
_Avoid_: Miniboss, elite, guardian

**Lesser god**:
The minor deity Almos meets in the Vision in the Lands between, who takes his ability to sleep in a trade; the first Boss.
_Avoid_: Dream god, the god

**Undead**:
A mage who channelled beyond their physical capacity until no humanity was left. Most stand motionless; some wake and fight.
_Avoid_: Zombie, hollow, revenant

**Necro mage**:
A hostile mage met in the Tempest who channels against the player.
_Avoid_: Necromancer, dark mage

**Unblockable attack**:
An enemy attack, such as a grab or the heaviest slam, that can be neither Blocked nor Parried; only a Roll or a Jump avoids it. It always has a distinct wind-up that warns the player.
_Avoid_: Perilous attack, guard breaker

**Low attack**:
An enemy attack that travels along the ground, such as a tail swipe or a shockwave, and can be cleared with a Jump.
_Avoid_: Sweep, ground attack
