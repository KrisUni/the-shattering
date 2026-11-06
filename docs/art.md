# Look bible

How the game looks: colour (now free, with what still holds), the references, the mood of each area and a look sheet for every character, creature and gameplay piece. It grows as art is chosen. How to bring art in, and what an art change may touch, is in `assets/AGENTS.md`. What things are and do is in `CONTEXT.md`; this file says only how they look.

## Colour

There is no master palette any more. The owner released the game from it so assets can carry more detail: more shades a material, glow gradients, hue-shifted shading, and packs used as drawn. Choose colours freely.

What still holds:

- **The mood:** muted and dark at heart, with fire warm and bright against it (Hyper Light Drifter's sharp accents on a muted ground; Blasphemous's grim tone). Avoid bright, saturated fantasy colours across the board.
- **Danger red (`#d62839`) is kept for the Unblockable attack's warning**, and an image under `assets/` may not use it (a test checks). It is a combat cue the player must read at a glance, so nothing else may look like it. Keep other strong reds well away from it.
- **Cues** stay a pose plus a flash, never colour alone (below). The wind-up flashes stay cream, then Danger red for an Unblockable (`assets/shared/flash/flash.gdshader`).

What used to be rules is now guidance. Each colour still marks something well, so keep it in mind:

| Colour | Good for | Hex |
|--------|----------|-----|
| Fire amber | Torches, lamps, Fire, the fireball, burning things, the Checkpoint's campfire | `#f29a2e` |
| Arch-tree glow, pale gold-green | Glowing fungus, the tree's light | `#c9e06b` |
| Ilion violet-magenta | Ilion, drained magic, a Seal breaking | `#d23fd0` |

The old base, Lospec's Oil 6 (cream `#fbf5ef`, sand `#f2d3ab`, dusty rose `#c69fa5`, base violet `#8b6d9c`, slate indigo `#494d7e`, navy `#272744`), is what the art so far is drawn in. It stays in `assets/palette/` as a starting point, not a limit, and `scripts/recolour_palette.py` can still map an image onto it (or onto any `.hex` palette given with `--palette`) when that helps an asset sit with the rest.

## Cues

- A cue is a pose plus a brief flash, never colour alone.
- **Normal wind-up:** the pose, with a cream flash at its start.
- **Unblockable wind-up:** the pose, a cream flash, then Danger red held to the end of the wind-up, with its own sound.
- **Hit-stop:** when a blow lands, on Almos or an enemy, blocked or not, the whole game freezes for a moment so it reads as heavy: 0.05 s for a blow, 0.09 s for a Critical hit, 0.08 s for a Parry and 0.11 s for a Break (`scripts/game_feel.gd`). Fire's ticks and fireballs do not freeze it. The freeze is a pause of the game, so no timer or Break runs on through it.
- **Pace:** the whole game runs at 85% of real time, everything alike (`GameFeel.SPEED`).
- **Where blows meet** (`scripts/combat/hurtbox.gd`, looks only, drawn in code on the art pixel grid): a Parry throws ten short iron sparks (`scenes/world/spark_burst.gd`) from where the blow met the guard, cooling from cream through sand to steel; a Block throws a smaller spray of four and a puff of dust from the blocker's feet (`DustPuff`). A blow taken in full throws neither.
- **A jailer's blow** leaves an arc through the air (`scenes/enemies/blade_smear.gd`, on its `Look`), a crescent in cream and sand swept from over the shoulder down across its front while the blow is live, as Almos's swing smear is.
- **Props** (looks only): a barrel or crate knocked or thrown rocks one way and the other, two pixels and then one, as it comes to rest (`scenes/world/liftable.gd`); a clay pot breaks into small uneven shards that scatter and spin (`LiftTuning.pieces = shards`, `scenes/world/prop_break.gd`), where a barrel breaks into staves with hoops rolling off; a pickup taken, a Weapon, Armour or the Flask upgrade, leaves a copy of its look rising 12 art pixels off the floor and fading in 0.45 s (`scenes/world/pickup_lift.gd`). The metal gates already glow and drip as they melt.
- **A guard straining:** once an enemy's Stagger is 70% full, short of a Break, its figure shakes a pixel each way.
- **Spells:** a curl of violet smoke rises from a torch whose flame Pull takes (`scenes/world/smoke_curl.gd`); faint threads of heat rise off a held flame (`scenes/world/heat_shimmer.gd`, `HeldFlame/Flame/Shimmer`); what a Shove sends flying, a prop or an enemy, leaves pale arcs in the air in its wake (`scenes/world/air_ripple.gd`).

### How Looks animate

- An enemy with an AnimatedSprite2D named `Art` in its `Look` is driven by `EnemyLook`: it plays `idle`, `walk`, `strike`, `low`, `unblockable`, `break` or `death` for what the enemy is doing, and skips a name the sprite lacks. `hurt` is not played yet: it needs a hurt signal from the enemy, which is still open. The sprite is flipped left or right with the way the enemy faces, so it is drawn facing right.
- The flash is drawn on the sprite by `assets/shared/flash/flash.gdshader` (cream, then Danger red for an Unblockable), so the enemy itself is never tinted. Without an `Art` sprite the old whole-look tints stay.

## Darkness

- The dark is a dithered overlay drawn from the gameplay light, so it looks as dark as enemies treat it.
- Each dark zone goes two or three steps toward navy.
- Each lit torch or Fire cuts a circle of exactly its light radius, rimmed in Fire amber.
- A wall hides what lies behind it from Almos: the circle is cut short at every wall of the Room (`scenes/world/darkness.gd`, each wall's collision box), though a wall's own face shows. Corridor 2's circle is smaller than the hall's (280 units against 340).

## References

- **Hyper Light Drifter:** the view, a muted palette with sharp accents, readable wind-ups.
- **Blasphemous:** the grim, devotional tone.

Avoid:

- cute or chibi proportions
- bright, saturated fantasy colours
- outlines heavier than one pixel

## The world

What the Nar and the arch tree are is in `CONTEXT.md` (**Nar**, **Arch tree**). Looks only:

- Whether the Nar have pointed ears is not decided yet.
- The Marked look like any other Nar. Only the Seal at the neck tells them apart.

## Area moods

### Dungeons

- **Mood (the owner's polish pass):** a damp, dim root-prison. The floor is packed earth in muted mauve-browns with a few pebbles, roots and one short crack among its four tiles; the woven walls are a shade deeper, with faint veins of the tree's pale gold-green light. A cool grade over the whole Dungeons (a CanvasModulate named `Grade`) lets every flame read warm: each lit torch, lamp and Fire throws a flickering, dithered amber pool, added onto what is under it (`scenes/world/lamp_glow.gd`, under the Flame, so it goes out with it). Furniture and cell props are warm, muted wood. Each Room has a little life (`scenes/world/ambience.gd`): dust drifting in the light and the cells' window shafts, water dripping from the north walls with a splash, and pale motes rising out of the hall's chasm. Moss is kept sparse. The small glowing fungus on the walls and floors (`fungus_0`, `fungus_1`) swells and ebbs in brightness, slowly, each on its own beat (`scenes/world/glow_pulse.gd`).

- Root and packed earth, not stone.
- The wood is veined with the tree's glowing light.
- Where Ilion feed, the wood is grey, cracked and bleeding sap.
- Rooms keep their modern names, but each is served by grown and hand-made means: a speaking-root, a listening slit, a root-fed trough, woven bins.

### Other areas

- **Base of the tree:** mood decided when it is drawn.
- **Upper tree:** mood decided when it is drawn.
- **Catacombs:** mood decided when it is drawn.
- **Lands between:** mood decided when it is drawn.

## HUD

The Health, Stamina and Mana bars share `scenes/hud/hud_bar.gd`, a ProgressBar that draws itself pixel-exact in place of the default look:
- **Frame and fill:** a near-black frame around a recessed background, and the fill with a lit top row and a shaded bottom row.
- **Loss trail:** a pale trail that a loss leaves where the bar was. It holds for a moment, then drains down to the new value, so a hit reads at a glance.
- **Colours:**
  - Health is blood red (`#9b3a46`), kept well apart from Danger red.
  - Stamina is sage green (`#7f9a5a`).
  - Mana is steel blue (`#4a6fb5`).
- **Placement:** top left, in HUD pixels (a HUD pixel is 2 screen pixels: the HUD layer is drawn at scale 2 on the 1152x648 view). Health is on top and longest (84x7), Stamina under it (64x5), and Mana under that (64x5) once Almos has it.

The text labels in the test room are still placeholders.

### Spell icon

A 15x15 box right of the Health bar (`scenes/hud/spell_icon.gd`), framed like the bars, shows the selected Spell: Pull is two sand arrows pointing in at a violet-and-cream mote, Shove the same arrows pointing out from it. A rose `V`, the switch key, sits beside it, and the box's top edge flashes cream for a moment when the Spell switches. The letters are a 5x7 pixel font drawn in code (`scenes/hud/pixel_text.gd`); the project has no font file.

### Thoughts

Almos's thoughts (`scenes/hud/thought_text.gd`) show low on the screen in a dark, slate-edged box, in the pixel font in sand, typed out letter by letter, with three small bubbles rising from its corner and a blinking violet prompt once the lines are out.

### Spell waves

A Pull or Shove on ordinary things (not a flame, which keeps its fire look) shows a wave of energy in the base palette (`scenes/almos/spell_wave.gd`): for Pull, a broken cream ring half as wide as Pull's reach closes in on Almos with a rose ring behind and motes drawn in; for Shove, an arc in cream, rose and slate bands bursts out along his aim to half Shove's reach. What it lands on gets a small cream ripple. It shows on every press, even one that moves nothing.

### Enemy Health bars

Each enemy carries a small Health bar over its head (`scenes/enemies/enemy_health_bar.gd`, node `OverheadHealthBar`). It is 32x6 art px, drawn like the HUD's: a frame, a blood-red fill lit along its top, and a pale trail where a loss took it from. It shows once the enemy is hurt or in Pursuit, and hides while it is whole and at rest, and once it is dead.

## Look sheets

One sheet per thing that is in the game now. Fill a sheet in when its art is chosen. The test room stays placeholder and gets no sheet. The Cave's door to the Catacombs stands in until the Catacombs are drawn (out of scope), so it has no sheet yet.

Each sheet has these fields:

- **Thing:** the `CONTEXT.md` term, or the word `CONTEXT.md` uses for it, with the entry where it appears.
- **Source pack and files:** where the art comes from.
- **Size in art px:** width × height.
- **Palette notes and accents used:** which base colours, and which reserved accents, if any.
- **Animations and poses needed:** every animation or pose the thing needs.
- **Status:** not chosen, chosen, or in the game.

### Characters

#### Almos

- **Thing:** Almos
- **Source pack and files:** Drawn in code for this game (no pack) by `scripts/art/draw_almos.py` at 32 px, on the shared kit `scripts/art/pixelkit.py` (parts lit from the top left, hue-shifted ramps, selective outlines), into `assets/characters/almos/`. Driven by `AlmosLook` (`scenes/almos/almos_look.gd`). An original young wanderer in the spirit the owner asked for (a classic hooded hero with a long cap), not a copy of any existing character: a deep indigo hood with a long tail and a short mantle over the shoulders, so the head and body read as one silhouette.
- **Size in art px:** 32x48 for every frame but the attacks, which are 64x64 with the body in the middle (feet on row 55) so the swing's smear has room; feet always on the body (sprite offset -16 art px).
- **Palette notes and accents used:** Free colour, each material shaded from the top left with a lit and a shaded tone, and selective outlines: the silhouette is outlined in near-black, lines inside it take the deep tone of the material they sit on. Bark-grey skin (`#6c6966`, lit `#8a8682`, shade `#4e4b49`), pale cream eyes and root hair; an indigo hood (`#3e4573` with `#59639c` and `#2c3155`), a violet seam and sand stitches; a warm fibre robe (`#b38c76`, lit `#d4b298`, shade `#86634f`); a dark leather strap, a sand rope belt, a pale glass Flask; sand bandage and foot wraps; indigo trousers, the far leg in shadow so a stride reads. The Seal is near-black with a glint. The swing's smear runs from cream to warm sand. No accent.
- **Animations and poses needed:** Now, each for `down`, `up` and `side`:
  - `idle` (4 frames: breath, hood tail sway, a blink)
  - `walk` (6 frames at 10 a second: contact, down and passing for each leg; the arms swing against the legs, and the hood tail and rope end follow through)
  - `roll` (6 frames at 20 a second): drawn, but no longer played. A Roll is a vanishing dash: he stays upright on `walk` from its first frame, fades out over its first quarter, is gone for its middle and fades back in over its last (Almos's `dash_visibility`), and leaves a trail of shadows, a still copy of his figure every two physics frames tinted a deep violet (`#291a47`, at 70%), each fading over 0.45 s (`AlmosLook`).
  - `attack` (5 frames: wind-up, coil, strike with a smear arc, follow-through, recover). These are not played at a frame rate: `AlmosLook` picks the frame from the swing's own startup, active and recovery frames, so it fits every Weapon and every swing of a combo. A charging Heavy attack holds the coil. The smear is drawn without a weapon, so it stands for any Weapon or for a fist.

  - `attack_sword` (5 frames, 64x64, as `attack`): the same swing with the sword in his hand while he carries one, a short blade of grey iron with a crossguard, a wrapped grip and a pommel (drawn by `scripts/art/draw_almos.py`, like the jailer's). Side: drawn back over his shoulder, swung down in front. Down: raised over his head, swung down toward the viewer. Up: low at his side, swung up away from the viewer. The smear still shows the arc. A Weapon's `look` (`data/sword.tres` has `sword`) names its own swing; one with none, or with no swing drawn, plays the plain `attack`.
  - `pull` and `shove` (3 frames each, 32x48): a small gesture of the hands for a moment after a Pull or Shove is cast on an enemy or a thing (or at nothing), 18 physics frames, its middle frame from the 4th to the 12th. Shove gathers the hands to the chest, pushes the palms out and eases back; Pull reaches out, closes on it and draws the hands in. A Spell's wind-up (drawing a flame, gripping a prop) and a throw show the attack frames instead, as before.

  - `sprint` (6 frames at 14 a second): a run, a longer stride than the walk with the feet lifted higher, the body pitched forward and bobbing, the arms pumping and the hood tail and robe streaming. Played while he Sprints.
  - `jump` (3 frames, picked from how far through the Jump he is, `AlmosJump.progress`): a crouch to spring from (the first 18%), tucked in the air with the feet drawn up and the arms raised for balance, and a crouch to take the landing (from 82%).
  - `hurt` (2 frames, 16 physics frames from any loss of Health, the second from the 7th): a flinch, knocked back with the head snapped back and the arms thrown up, then gathering himself. It shows over a walk or a stand, not over a swing, a cast, a gesture or a dash.
  - `block` (1 frame, held while he Blocks): weight down, both forearms up before him.
  - `fidget` (8 frames at 6 a second, once): after he has stood still for 5 to 8 seconds he glances one way and the other, tugs his hood straight and settles with a blink, then stands idle again and the wait starts over. Not while he is held still (the opening) or dead.

  Dust (`scenes/world/dust_puff.gd`, a `DustPuff` left in his parent, drawn in code on the art pixel grid in the floor's own earth, its motes bursting out, rising a little and fading in 0.4 s) kicks up from his feet: behind him on each foot strike of a Sprint and as he sets off into one, ahead of him as he pulls up from one, a small puff as he springs into a Jump and a ring of it as he lands. Landing also dips his figure (`Art`, not his `Look`) two art pixels down into the crouch, coming back up over 6 physics frames. Walking kicks up none.

  - `parry` (2, held: the forearm swept out across the blow while the Parry window is open, then drawn back).
  - `sip` (3 at 4 a second, once: the Flask raised to his mouth, the head tipped back to drink).
  - `hold` (6 at 10 a second): a flame or a prop held over his head in both hands, walking with it; standing, its first frame.
  - `winded` (4 at 6 a second): out of breath and standing, bent over with his hands on his knees, his back heaving.
  - `death` (3 at 6 a second, once, 64x64 as the attacks): he buckles, drops to his knees and falls on his side, limp; drawn side on and shown for every side. A fall down a Drop shows itself instead.
  - `attack_greatsword` (5, 64x64, as `attack`): the swing with the greatsword in his hand, a longer, broader blade with a fuller, a wide guard and a long grip (`data/greatsword.tres` has `look = greatsword`).

  The side frames face right and are flipped for left; a diagonal shows the side. Still owed: a weapon drawn in hand outside the swings; the Parry shape over his `parry` pose, the Block shape over his `block` pose, and the death tint over his `death` all still show. The sword's strike box (`Sword/Look/Shape`) is transparent now that the smear shows the swing; it stays for the code and tests that measure it. The torches hung on him (`CarriedTorch`, `HeldFlame`) show only their flame. Pointed ears are left off, since whether the Nar have them is not decided.
- **Status:** in the game (fifth draft, the first in free colour; the owner checks the look in the editor)

#### Nar jailer

- **Thing:** Nar jailer
- **Source pack and files:** Drawn for this game (no pack), `assets/characters/nar_jailer/`, by `scripts/art/draw_nar_jailer.py` at 32 px. A jailer is a fellow Nar, so he is a variation of Almos: drawn on Almos's own build and side-on poses (`scripts/art/draw_almos.py`, with its `Outfit`) in a guard's outfit: a moss-grey hood with a short tail and its mantle, a dark leather jerkin over a grey shirt, a dark leather belt with a bone buckle and a baldric, dark trousers and boots, and a sword of grey iron (crossguard, wrapped grip, pommel). He wears no Seal (only the Marked do) and carries no Flask. The same bark-grey Nar skin and pale eye as Almos. `scenes/enemies/nar_jailer.tscn` is the training enemy with the jailer's tuning and this sprite. The test room's jailers stay placeholder.
- **Size in art px:** 64x64 canvas, facing right, feet on row 55 (sprite offset -16 art px), the body in the middle as in Almos's attack frames, so he stands as tall as Almos.
- **Palette notes and accents used:** Free colour, muted: moss-grey hood, dark leather browns, grey cloth, a pale steel blade with a glint. No accent; the flashes come from the shared shader.
- **Animations and poses needed:** `idle` (2, a breath, the sword hanging at his side), `walk` (4, a stride), `strike` (sword drawn back over the shoulder, swung down, recover), `low` (crouched, a sweep along the floor), `unblockable` (sword raised high in both hands, held, slammed down), `break` (knocked back and slumped, the sword hanging), `death` (buckles, drops to his knees, falls flat with the sword fallen from his hand), `sit` (4, on the guard post's bench, the sword across his knees, a slow breath: the chest lifts, the head nods, the hands shift on the blade). For a moment each, over the rest: `hurt` (2, rocked back by a blow that costs Health, head snapped back, then gathering himself), `startle` (2, a jerk up as he notices Almos, then dropping into a guard, the sword up), `rise` (3, getting up from the bench), and `look` (4, a glance back over his shoulder and round again, while a patrol pauses at one of its points). Dying he is gone at once, but `EnemyLook` leaves his body behind as a look: a copy that plays `death`, lies 0.7 s and fades over 0.9 s. Not yet: Block and Parry poses.
- **Burning:** a jailer carries a `Flammable` of the creature kind, as the Root crawler does: a fireball's hit or splash sets it alight, and the shared Fire flame stands on its feet while it burns.
- **Status:** in the game (fourth draft: a variation of Almos with a sword; the owner checks the look in the editor).

#### Nar knight

- **Thing:** Nar knight (in Radio/Officers)
- **Source pack and files:** Drawn for this game (no pack), `assets/characters/nar_knight/`, by `scripts/art/draw_nar_knight.py` at 32 px. Like the jailer he is drawn on Almos's own build and side-on poses (`scripts/art/draw_almos.py`, with its `Outfit`; a `Pose` can now move the head, as when it droops), but in armour of his own so he reads as a knight: a closed helm of grey iron (the hood's shape with no tail) with a face plate, a dark visor slit and a crest of dark bark fibre; a rounded iron pauldron over the shoulders, darker than the helm; a cuirass of grown bark plates with dark bands across the chest and the tassets; mail sleeves; iron gauntlets, cuisses and greaves with knee cops, and sabatons; and a longsword, longer and broader than the jailer's (25 against 17 to 21), with a fuller, a wide crossguard and a heavy pommel. No eye shows through the helm. No Seal, no Flask. `scenes/enemies/nar_knight.tscn` is the training enemy with the knight's tuning (`data/nar_knight.tres`, the old key jailer's) and this sprite, and a `Zzz` node in its Look.
- **Size in art px:** 64x64 canvas, facing right, feet on row 55 (sprite offset -16 art px), the body in the middle, as the jailer's.
- **Palette notes and accents used:** Free colour, muted: grey iron (`#646a7a`, the pauldron `#545866`), dark bark-brown plates (`#54463c`), mail grey, an olive-dark bark crest, a pale steel blade with a glint. No accent; the flashes come from the shared shader.
- **Animations and poses needed:** `idle` (2), `walk` (4), `strike` (3), `low` (3), `unblockable` (3), `break` (2), `death` (3), as the jailer's but with the longsword; and `sleep` (6, a deep, slow breath, his back and shoulders rising, holding and sinking): sitting on the stool at his desk's west end, slumped forward, his head down on his arms on the desk top, the longsword leaning against the stool behind him. `EnemyLook` plays `sleep` while he is seated and asleep at his post (`asleep` on the enemy, with `seated`), and `sit` for a seated enemy that is awake. He has the jailer's `hurt`, `startle` and `look`, his own body left on death, and his own `rise` (4): heavy in his armour, he pushes up off the desk, takes up the longsword and stands, shown as he wakes. Not yet: Block and Parry poses.
- **Zzz:** `scenes/enemies/sleep_zzz.gd`, drawn in code on the art pixel grid: three Z letters in a pale cream (`#e9e2d0`) with a navy shadow a pixel down and right, a 4x4 Z that grows to a 5x5 one, rising 24 px from just over his head and drifting 12 px back over his shoulder (away from the desk) with a slight sway, fading in and out over 2.4 seconds each, looping while he sleeps. It mirrors with the sprite and is gone the moment he wakes.
- **Burning:** a `Flammable` of the creature kind, as the jailer's.
- **Status:** in the game (first draft; the owner checks the look in the editor).

#### Nar guard

- **Thing:** Nar guard
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

### Creatures

Creatures have no shared rule. Each one's look is decided when its assets arrive.

#### Root crawler

- **Thing:** Root crawler
- **Source pack and files:** Tiny RPG Character Asset Pack 02, Blood Monster_A (plain strips). `assets/creatures/root_crawler/`. See `assets/CREDITS.md`.
- **Size in art px:** 64x56 canvas for every frame, body about 40x32, feet on the bottom row of the body (sprite offset puts them on the 12-unit collision body's foot).
- **Palette notes and accents used:** Base only: navy outline, indigo and violet body, sand and cream teeth. The pack's crimson is mapped away from Danger red and Fire amber. While it burns, the shared Fire flame stands on its feet (Fire amber).
- **Animations and poses needed:** `idle`, `walk` (loop); `strike` (arm raised, then swing); `low` (crouched flat, maw open, then a low lunge); `unblockable` (reared tall with the arm overhead, held, then the slam); `break` (leaning back and slumped, held); `death`. The sprite faces right and turns with the crawler by `flip_h` (left or right).
- **Status:** in the game (first draft; the owner checks the look in the editor).

### Gameplay pieces

#### Torch

- **Thing:** Torch (see Pull)
- **Source pack and files:** Drawn for this game (no pack) by `scripts/art/draw_fire.py`: the bracket `assets/shared/torch/torch.png`, a shaft of grown root with a bowl of woven bark bound in dark cord, and the flame `assets/shared/torch/flame_0-4.png`. Drawn natively at 32 px (the flame's shape at its first size, scaled, with a stray-pixel cleanup); the bracket on `scripts/art/pixelkit.py`.
- **Size in art px:** Bracket 20×74; flame 32×48 (5 frames).
- **Palette notes and accents used:** Bracket in warm root browns. Flame in hard bands from a deep amber rim through Fire amber and sand to a cream core, no anti-aliasing. A small, steady flame, so a lit torch stays apart from Fire.
- **Animations and poses needed:** One looping burn (5 frames, 8 per second). Lit shows it; out hides it (the Flame node's visibility). The bracket's polygon is hidden, not deleted. The Dungeons no longer use the torch: their light sources are lamps (below). `torch.tscn` stays for the test room and for the flames Almos carries; his carried torch and held flame hide the bracket.
- **Status:** in the game (third draft, the first at 32 px; the owner checks the look in the editor)

#### Lamp

- **Thing:** Torch (see Pull): the Dungeons' light sources are lamps, which are torches in every way that matters to play (their flame can be Pulled, they light the way, they are in the group "torches"), drawn as lanterns.
- **Source pack and files:** Drawn in code for this game by `scripts/art/draw_world.py` at 32 px (on `scripts/art/pixelkit.py`), in the style of the owner's lantern reference (harusha's Pixel Lanterns on itch.io, which could not be downloaded here; if its files arrive and its licence allows, its lanterns can be swapped in as drawn). `assets/shared/lamp/`:
  - `lamp_wall.png`: a lantern hung on a short chain from a hook, for north walls (`scenes/world/lamp.tscn`)
  - `lamp_standing.png`: the same lantern on an iron stem and foot, for floors (`scenes/world/lamp_standing.tscn`)
  - `lamp_lit_0-3.png`: the glowing glass and flame, drawn over the lantern while it burns
- **Size in art px:** The wall lantern is 24x32 and the standing one 24x56, both with the glass in the same place (x 4-19, y 14-23).
- **Palette notes and accents used:** A slate iron frame, cap, ribs and foot, lit on the top left. Unlit glass is dark indigo with a pale glint. Lit glass glows cream at a heart that drifts with the flicker, through sand and Fire amber to a deep amber rim, the ribs dark over it.
- **Animations and poses needed:** One looping flicker (4 frames, 6 a second) while lit; dark glass when its flame is taken.
- **Placement:** Wall lanterns hang on north wall faces, the node at y 36 so the lantern sits on the face. In Cells 2 and 3 a pair of side lanterns (`lamp_side.png`, `scenes/world/lamp_side.tscn`: the same lantern hung on an iron arm with a strut, out from the wall's edge) hang one on each side wall, halfway down, the right one flipped, each node 12 units in from its wall so the arm meets the wall; their pools of light fall inward on the floor. In Cell 3 Almos Pulls a flame from one of them and carries it to above the Roots to Shove it at them.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Fire

- **Thing:** Fire
- **Source pack and files:** Drawn for this game (no pack) by `scripts/art/draw_fire.py`, `assets/shared/fire/flame_0-14.png`: a teardrop flame with a rounded foot whose sides sway with looping waves, a ragged edge where its tongues lick up, tongues breaking off its top, and a wisp of violet smoke above.
- **Size in art px:** 40×64 (15 frames), drawn over the 32×40 body of a Flammable, its foot on the body's foot.
- **Palette notes and accents used:** Hard bands from a deep amber rim through Fire amber and sand to a cream core low in the flame; the smoke in muted violets. Larger than a torch flame, with smoke, so a burning thing and a lit torch read apart.
- **Animations and poses needed:** One seamless looping burn (15 frames, 12 per second), shown only while the thing burns (the Flame node's visibility).
- **Status:** in the game (third draft, drawn natively at 32 px; the owner checks the look in the editor). Used by every Flammable, the Root crawler's burning look included (root_crawler.tscn places the shared flame at `Flammable/Flame/Art`).
#### Pull and the fireball

- **Thing:** Pull (taking a torch's or a Fire's flame), the held flame, and the Fireball (see Shove)
- **Source pack and files:** Drawn in code on the art pixel grid, no image files:
  - `scenes/almos/spell_look.gd` (`SpellLook` on Almos): the Pull and the flame in his hand
  - `scenes/almos/fireball_trail.gd` (`FireballTrail`): the fireball in flight
  - `scenes/almos/fire_burst.gd` (`FireBurst`, left where a fireball hits): the impact and its scorch
- **Size in art px:** The tongue runs from the flame to Almos's hand, 6 art px thick at the source, thinning to 1 (these effects are drawn in code, still in 2-unit blocks). The flame in his hand is about 10 by 14. The fireball's head is a blob about 18 across, with a 16-step trail. The burst's ring runs out to the fireball's splash radius, so it shows what the splash reaches.
- **Palette notes and accents used:** Fire amber, sand and cream for the fire; dusty rose and slate for smoke; navy and slate for the scorch. No magic glow: the owner wants it to read as fire, not magic, so no magenta.
- **Animations and poses needed:**
  - **Pull:** while Almos winds up, the flame is torn from the torch toward his hand as a wavering tongue of fire that stretches out with the wind-up, shedding embers. It is drawn into his hand for a moment after the release, the torch is left smoking, and the flame lands with a splash of embers.
  - **Held flame:** a small flickering flame in his hand on the side he faces, an ember rising now and then. The torch flame sprite on `HeldFlame` is hidden.
  - **Fireball:** a round head with a cream heart, and a trail that cools from sand and amber to rose and slate smoke, shedding embers that drift and fall. The trail outlives the fireball and fades.
  - **Burst:** where it hits, a white-hot flash, a ring of fire out to the splash radius, sparks and rising smoke. It leaves a scorch on the ground that thins away over 3 seconds. Running out of range in open air leaves no burst. The fireball's old hexagon (`Look/Shape`) is transparent and stays for the code and tests.
- **Status:** in the game (second draft; the owner checks the look in the editor)

#### Checkpoint

- **Thing:** Checkpoint
- **Source pack and files:** Drawn for this game (no pack) by `scripts/art/draw_fire.py` (`campfire`), into `assets/shared/checkpoint/campfire_0-11.png`: a campfire seen from above, a ring of grey stones round a bed of ash, two logs crossed over it and a third across the front, embers glowing and fading among them, and a low flame drawn as the torch and Fire flames are, with a wisp of smoke. The near logs and stones are drawn over the flame's foot. An `AnimatedSprite2D` named `Art` in its `Look` plays it (`burn`), its bed on the Checkpoint's position (offset -18); a lamp glow (`scenes/world/lamp_glow.gd`) hangs under it as an amber pool, only a look. The placeholder sapling's polygons are hidden, not deleted.
- **Size in art px:** 48x56 (12 frames).
- **Palette notes and accents used:** Stones in cool greys, logs in warm root browns, the flame in hard bands from a deep amber rim through Fire amber and sand to a cream core, smoke in muted violets.
- **Animations and poses needed:** One looping burn (12 frames, 10 a second). Embers rise off it (`scenes/world/ember_sparks.gd`, `Sparks` under its `Art`): a few single-pixel sparks at a time lift from the flames, drift up and sideways and cool from cream through sand and Fire amber to a dull brown before they go out. It still flashes white when Almos rests.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Fungus

- **Thing:** Fungus (flammable fungus; see Fire)
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Hiding spot

- **Thing:** Hiding spot
- **Source pack and files:** Drawn for this game, `assets/dungeons/furniture/`. Redrawn at 32 px in code by `scripts/art/draw_props.py` (on `scripts/art/pixelkit.py`), at the same canvas sizes, so every footprint and rim is where it was.
  - `wardrobe.png` (`scenes/world/wardrobe.tscn`): a tall wardrobe of grown wood, two doors with a gap between them, a sand lip on top
  - `barrel.png` (`scenes/world/barrel.tscn`): a barrel with bark hoops

  Both inherit `hiding_spot.tscn`. The placeholder shape is hidden, and the spot is at the foot of the furniture. The test room's spots stay placeholder.
- **Size in art px:** Wardrobe 40x60; barrel 28x36.
- **Palette notes and accents used:** Warm brown grown wood, lit on the top left, its staves and planks in its own deep tone, iron hoops in slate; the barrel's lid is open, a dark rim round a lighter top. No accent; a burning one shows the shared Fire flame.
- **Animations and poses needed:** No frames. Getting in, Almos is seen hopping in (`scenes/world/hide_hop.gd`, only a look: he is in the spot at once): he crouches, springs up in an arc and drops into a barrel feet first, cut away row by row below its rim (`open_top`), or squeezes in between a wardrobe's doors; the spot squashes and wobbles back as he lands. Getting out, he springs out of it from its rim and lands on his feet in front of it, and it squashes again. Almos inside is not drawn at all, and the spot rattles every three seconds or so, each on its own rhythm: its look hops and jolts for a third of a second. Pulled, it shudders through the wind-up and floats up over Almos's head, bobbing while held. Thrown, it falls in an arc with a dust trail (`scenes/world/throw_dust.gd`) and bursts in dust and wood splinters where it lands (`scenes/world/impact_burst.gd`). Too heavy, it jolts harder and stays put. Almos holds his coiled wind-up pose while gripping, and strikes as he throws.
- **Placement:** Corridor 1 has no wardrobes any more: big rocks stand in their place (`assets/dungeons/rocks/rock_big.png`, a grey lumpy boulder with moss on top, `scenes/world/big_rock.tscn`), and barrels to hide in sit between them and the two cell doors, one a few steps from Cell 3's. A rock crushed against the wall bursts in pieces of its own art and leaves small rocks (`rock_small_0-2.png`).
- **Loose things and growth:** The hall is laid out as a place people use, not scattered: a rockfall in the west corner (two big rocks and their rubble of small rocks), the prisoners' water barrel and bucket by Cell 3's door, the stores against the middle wall (barrels in a row, a pot, a crate stack, burlap sacks), and the guard post east of Cell 2's door (a barrel, a bench with a bowl, a bucket and the spear rack) where a second guard sits on the bench (`sit`, two frames of a slow breath, played while he is at rest at his post; he gets up once he is hurt or in Pursuit). Bones and skulls lie along the chasm's lip and on its ledges, and on the stretch of bridge just below the barricade a jailer's remains (`assets/dungeons/bones/fallen_jailer.png`, 48x26, drawn by `scripts/art/draw_props.py`: his bones on their back in his torn moss-grey hood and mantle, a rotten leather jerkin over the ribs, his boots on, one arm flung out; floor dressing at z -1) lie beside his sword (`assets/dungeons/furniture/sword_floor.png`, 32x10: grey iron, a crossguard, a wrapped grip and a pommel, the art of a `WeaponPickup` that Almos takes up). Everything that is not a plant or the remains can be lifted and thrown, up to Almos's limit of 40 (barrels, bone piles, pots and bowls break where a throw ends; the bench and the spear rack, at 30, can be lifted; the crate stacks, at 45, are too heavy yet and shudder). A Shove knocks the lighter ones further. Plants are only a look, kept sparse: floor moss, small glowing fungus and moss hanging from the north wall (`assets/dungeons/growth/`, drawn by `scripts/art/draw_world.py`: moss in low cushions of touching lumps, the fungus caps in the arch-tree glow on pale stems). The cells' lamps hang on their north walls, and a side lantern hangs over Corridor 1's door to Radio/Officers; no lamp stands on a pole in the Dungeons' hall or cells. Cell 3 has a bowl by the bed and a puddle under a drip.
- **Metal gate:** `assets/dungeons/gates/metal_gate.png`, 128x56 art px, drawn by `scripts/art/draw_world.py`: iron bars between a top rail and a cross rail, rivets with a glint and rust flecks on the bars, darker posts at each end. It stands on its doorway's footprint. Melting, it glows from white to a hot orange and melts away from the top down, a molten edge eating down the bars and dripping, their feet last; crashed, it bursts in pieces of its own art.
- **Status:** in the game in Corridor 1 (first draft; the owner checks the look in the editor)

#### Furniture and cover

- **Thing:** The Dungeons' furniture. Crate stacks are cover: solid, on the walls layer, so they block Sight and movement as a wall does.
- **Source pack and files:** Drawn for this game, `assets/dungeons/furniture/`. Redrawn at 32 px in code by `scripts/art/draw_props.py` (on `scripts/art/pixelkit.py`), at the same canvas sizes, so every footprint and rim is where it was.
  - `crate_stack.png` (`scenes/world/crate_stack.tscn`, a StaticBody2D in the group "cover", its box on the lower crate's footprint)
  - `bench.png`, `spear_rack.png`, `sacks.png`: dressing with no collision
  - `desk.png`: the knight's desk in Radio/Officers, standing lengthwise (north to south) against the east wall: a `Desk` StaticBody2D in the Room with a box on its footprint, clear of where the knight sits, so it blocks as a wall does. Its long plank top seen from above, its short south end face on with a drawer, and two legs; on it bark sheets with writing where his head lies, a stack by the wall, an ink pot and a quill, an unlit candle stub in a clay dish, and the speaking-root (CONTEXT.md, Nar): a dark root grown up through the north end that curls over into an open mouth toward the sitter.
  - `stool.png`: the knight's three-legged stool, dressing with no collision.
  - `bookshelf_0.png`, `bookshelf_1.png` (`scenes/world/bookshelf.tscn`, solid on its 56x12 footprint): tall shelves of dark wood against the north wall, three shelves of bark-bound books in muted colours, standing, leaning and lying in piles, rolled scrolls, clay jars and, on one, small skulls. The two are drawn from different seeds.
  - `weapon_rack.png` (`scenes/world/weapon_rack.tscn`, solid on its 56x12 footprint): a small armoury against the north wall, a rack of dark wood with two swords hung point down, a mace, two spears stood upright and a round bark shield with an iron rim and boss leaning against it. Its left sword can be taken (a hidden `WeaponPickup` child of the rack, `WeaponRack`): once it is, the rack shows `weapon_rack_taken.png`, the same rack with that sword gone and its empty peg.
  - `armour_stand.png` (`scenes/world/armour_stand.tscn`, solid on its 16x8 footprint): a spare suit on a stand of root wood, a helm like the knight's, a bark cuirass and two pauldrons.
  - `scrolls.png`: bark scrolls dropped by the shelves; floor dressing with no collision.
  - `key_crate.png` and `key_crate_open.png` (`scenes/world/key_crate.tscn`, `KeyCrate`): the single crate the Jailer's key is kept in, solid on its 28x16 footprint, not liftable. Shut, an iron hasp on its lid; once the key is taken, open and empty, its lid up against its back, the inside dark. The key inside it does not show.
  - `sword_floor.png`: the fallen jailer's sword lying on Corridor 1's bridge below the barricade, the `art` of its `WeaponPickup` (`scenes/world/weapon_pickup.gd` shows a pickup's `art` in place of its placeholder bar where it has one).
  - `greatsword_floor.png`: the greatsword lying in the Store cupboard, the `art` of its `WeaponPickup`: a long, broad blade of grey iron pointing right with a fuller, a wide crossguard, a long leather-bound two-handed grip and a heavy pommel, a glint along its flat.
  - `stair_flight.png` (Sprite2Ds under Corridor 2's `Stairs`, their top left on the grid, z -1): a flight of steps cut into the chasm's root and packed earth, two tiles wide and three long, seen from above, eight treads each lit along its top and dropping to a dark riser, between two low root kerbs. Every flight is drawn the same, so which way it climbs is left to guess. Only a look: the flight's tiles are firm ground, not Drops.
  - `locked_door.png` and `locked_door_leaf.png` (`scenes/world/locked_door.tscn`, `LockedDoor`, the Main entrance's door set in a side wall, its body 32x64 in the doorway): Corridor 2's east door, seen from above, an oak lintel and sill across the east wall's top and the passage running on under it into the dark, and the leaf (`Look/Leaf`, 20x64) shut between them, its planks banded in iron, an iron lock plate on its hall side. Opened by the key, the leaf swings a quarter turn about its hinge at its north end into the hall, a little past and back, over 0.5 s; the Main entrance, which has no leaf yet, is dimmed instead.
  - `door_frame.png` (a Sprite2D, `DoorFrame`, its top left at x 0, y 500): the oak frame of Corridor 1's door to Radio/Officers in its short west wall, seen from above: a lintel beam over the opening's north end and a sill beam at its south end, laid across the wall's top, a squared post at the hall side of each, the passage under the wall dark, and the iron-banded door swung open back along the wall's foot below it. The side lantern above it (`DoorLamp`, `lamp_side.tscn`, 12 units in from the wall) gives it its light.
- **Size in art px:** Crate stack 48x52, bench 60x18, spear rack 36x52, sacks 36x22, desk 40x72, stool 16x14, bookshelf 60x64, weapon rack 60x60 (and its taken picture), armour stand 26x54, scrolls 28x14, key crate 32x34, floor sword 32x10, floor greatsword 48x14, door frame 44x104, stair flight 64x96, locked door 32x96 (its leaf 20x64).
- **Palette notes and accents used:** Warm brown wood (lighter on the tops seen from above), crates with a framed front and a pale brace, burlap sacks tied with rope, iron spear heads with a glint. Radio/Officers's books in muted violet, rust, moss, ochre and slate; sand bark sheets; grey iron. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game in Corridor 1 and Radio/Officers (first draft; the owner checks the look in the editor)

#### Path blocker

- **Thing:** Path blocker (living roots or a door that close a passage; see Fire)
- **Source pack and files:** Cell 3's Roots only: CRAWLING DEPTHS `root_vein_column`, rotated and squeezed by hand into a horizontal root, `assets/shared/dungeon_tiles/roots_blocker.png`. Set in `cell_3.tscn` under `Roots/Look/Art`; the shared `path_blocker.tscn` and the test room stay placeholder. See `assets/CREDITS.md`.
- **Size in art px:** 128x16 (the 128x16 unit footprint of Cell 3's Roots; a Sprite2D at scale 1).
- **Palette notes and accents used:** Navy body, indigo top edge, a few base violet flecks. No accent; the burning shows Fire's own flame.
- **Animations and poses needed:** One still picture. It goes with the path blocker's Look when the roots burn out.
- **Status:** in the game for Cell 3 (first draft; the owner checks the look in the editor)

#### Crate and Boulder

- **Thing:** Crate, Boulder (objects a Shove or a Pull moves; see Shove)
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Remains

- **Thing:** Remains
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Weapon pickup

- **Thing:** Weapon, lying in a Room
- **Source pack and files:** A placeholder bar, or the pickup's own `art` where it has one (`sword_floor.png`, `greatsword_floor.png`).
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:** A glint (`scenes/world/glint.gd`, `Look/Glint`) catches the eye on it: every 2.6 s a small four-pointed sparkle in cream and sand flares at a spot on it and fades in 0.45 s, each pickup on its own beat, so it reads apart from the floor dressing.
- **Status:** not chosen (the glint is in the game)

#### Armour pickup

- **Thing:** Armour, lying in a Room
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Flask upgrade

- **Thing:** Flask upgrade
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:** The same glint as a Weapon pickup (`Look/Glint`).
- **Status:** not chosen (the glint is in the game)

#### Jailer's key

- **Thing:** Jailer's key
- **Source pack and files:** Not drawn: it is kept in the key crate in Radio/Officers (see Furniture and cover), whose open, empty picture shows it gone. Its placeholder bar stays in `jailers_key.tscn`, hidden in the crate.
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Main entrance

- **Thing:** Main entrance
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Gap

- **Thing:** Gap (see Jump)
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Ledge

- **Thing:** Ledge (a low ledge; see Jump)
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

### Rooms

The Dungeons tiles live in one TileSet, `assets/shared/dungeon_tiles/dungeon_tiles.tres`, from one 32x32 art px atlas, `dungeon_tiles.png`. A Room draws its floor and walls with TileMapLayers at scale 1. The floor sits behind Almos, the north and side walls behind him, and the south walls in front of him (by `z_index`).

#### The cells

All three cells (Cells 1, 2 and 3) are closed in and dressed the same way, from the same pictures in `assets/dungeons/cells/`. Each differs:
- **Cell 1:** smaller (13 by 10 tiles), older and overgrown. Roots break through its wall and it has no window. Its lamp hangs on its wall, with bones, shackles, a bucket, and the pallet in the far corner.
- **Cell 2:** wider (14 by 11 tiles) and damp. A window to the left with its shaft of light, a puddle of seep water (`cell_puddle.png`), a cracked bowl (`cell_bowl.png`), three rows of tallies, and a lantern on each side wall. A dead prisoner's remains are its Inspect spots (`scenes/world/inspect_spot.gd`), drawn by `scripts/art/draw_props.py`: his skeleton slumped in the north-west corner with an arm fallen to the floor (`cell_skeleton.png`, 44x34), a black ring by his hand (`cell_ring.png`, 10x8, near black with a glint), and writing cut into the north wall just above him (`cell_carving.png`, 50x15): two lines of made-up letters in a shaky hand, the shape of I SAW THE / SERPENT GOD, so it looks like writing and is read only in the text box.
- **Cell 3:** described below.

The bars are drawn to fit each cell's front: `cell_bars_64.png`, `cell_bars_80.png` and `cell_bars_96.png`.

#### Cell 3, the cell

- **Thing:** Cell 3 (where Almos wakes; see Dungeons)
- **Source pack and files:** Drawn for this game, `assets/dungeons/cells/`. Redrawn at 32 px in code by `scripts/art/draw_props.py` (on `scripts/art/pixelkit.py`), at the same canvas sizes, so every footprint and rim is where it was. The light shaft (`cell_light.png`) is the old dither, doubled.
  - `cell_bars_80.png`: root bars along the front either side of the door, in front of Almos
  - `cell_window.png` and `cell_light.png`: a barred window slit high in the north wall, and the pale shaft of light it throws on the floor
  - `cell_pallet.png`, `cell_bucket.png`, `cell_bones.png`, `cell_straw.png`: a straw pallet, a bucket, old bones and scattered straw
  - `cell_shackles.png`, `cell_tally.png`: root shackles and tally marks on the north wall

  The solid root around the cell is a new tile, atlas (5,0) of `assets/shared/dungeon_tiles/dungeon_tiles.png`.
- **Size in art px:** The cell is 14 by 11 tiles (x 352..800, y 256..608 in units). The owner asked for it to feel like a cell, so walls close it in: `CellWallTop` (a 64-unit north face), `CellWallLeft`, `CellWallRight`, and solid root (`RootMassTop`, `RootMassLeft`, `RootMassRight`) filling the rest of the Room. The door, its Roots, the torch and the spot where he wakes are all inside.
- **Palette notes and accents used:**
  - Bars, shackles and the root mass: navy and indigo with violet glints.
  - Straw and pallet: sand and rose. Bones: cream.
  - Light shaft: dithered sand. The window shows rose twilight.
  - Only the torch uses an accent.
- **Animations and poses needed:** None; all still pictures, decoration with no collision (the walls are their own bodies).
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Radio/Officers

- **Thing:** Radio/Officers (the Room through the door in the short west wall at the foot of Corridor 1's west spur; Almos comes in by its own north door)
- **Source pack and files:** The same tiles (`assets/shared/dungeon_tiles/dungeon_tiles.tres`, no new tiles), closed in to the size of a cell as Cells 2 and 3 are, but with its door in the north wall: the Room's own north face (two tiles, its doorway open at the top middle) and its own walls `CellWallLeft`, `CellWallRight` and `CellWallBottom` (a south wall one tile thick on the wall grid, in front of Almos, its strip drawn over the root below), with solid root (`RootMassLeft`, `RootMassRight`, `RootMassBottom`) filling the rest of the Room, graded root, blend and deep root as in the cells. Its furniture is in Furniture and cover.
- **Size in art px:** The cell is 14 by 11 tiles (x 352..800, y 64..416 in units).
- **Placement:** An officers' room with a guard's corner. On the north wall, west of the doorway, two bookshelves with scrolls dropped before them; east of it the small armoury, the weapon rack and the armour stand. The desk stands lengthwise against the east wall, and the knight sleeps on his stool at it, facing the wall, his back to the room. A side lantern hangs on each side wall (the east one above the desk), a crate stack stands in the south-east corner, and in the south-west corner the key crate with sacks beside it.
- **Palette notes and accents used:** As Cell 3. Only the lanterns use an accent.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Deep root

- **Thing:** The solid root that fills a Room around its walkable space (Corridor 1, the three cells and Radio/Officers), made to read as deliberate darkness so the eye stays on the hall or the cell.
- **Source pack and files:** Drawn by hand, two tiles in `assets/shared/dungeon_tiles/dungeon_tiles.png`: deep root at atlas (0,2), near-black with faint seamless strands; and a blend at (1,2), every other pixel the root tile (5,0) and deep root.
- **Size in art px:** 32x32 per tile.
- **Palette notes and accents used:** Deep root `#0e0d16` with strands `#181726`; the blend dithers it with the root tile's indigo. No accent.
- **Placement:** Graded by distance from walkable floor: the root tile up to two tiles out, the blend at three, deep root beyond. This acts as a vignette. When the darkness overlay (#78) lands, these areas sit in its shadow too.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Cell 3 floor

- **Thing:** Cell 3 (the floor of the Room)
- **Source pack and files:** Packed earth drawn in code by `scripts/art/draw_tiles.py` (no pack): tileable value noise in clustered tones, a few lit pebbles and a rootlet; the four variants share their edges, so any one can lie by any other. `assets/shared/dungeon_tiles/dungeon_tiles.png`, tiles 0-3 of row 0 (four floor variants) and tile 4 (the 8 art px strip at the south wall).
- **Size in art px:** 32x32 per tile; the Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** Dusty rose ground, a few base violet and sand flecks. No accent.
- **Animations and poses needed:** None; four variants laid in a fixed pattern.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Cell 3 walls

- **Thing:** Cell 3 (the walls of the Room)
- **Source pack and files:** Woven bark drawn in code by `scripts/art/draw_tiles.py` (no pack): waving strips that rise over one upright stake and dip under the next, row by row, lit from the top left; `assets/shared/dungeon_tiles/dungeon_tiles.png`, row 1: north face top (sand lip), north face base (navy shadow), left side, right side, south wall top, south wall strip. The tiles follow the wall grid: north face 2 tiles, sides 1, south 1 plus the strip. Row 0's last tile and row 2 are the root mass, deep root and their dithered blend, drawn by the same script.
- **Size in art px:** 32x32 per tile.
- **Palette notes and accents used:** Woven bark in base violet and indigo with navy shadows; the south wall seen from above is darker. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Corridor 1 floor and walls

- **Thing:** Corridor 1 (the floor and walls of the Room)
- **Source pack and files:** The same tiles as Cell 3 (`assets/shared/dungeon_tiles/dungeon_tiles.tres`, no new tiles). Floor under the whole Room; north walls are two tiles of face (sand lip, navy base) in three runs either side of the two cell doorways (Cell 3's open, Cell 2's shut by its metal gate). It has no south wall: below the lane the chasm runs off the west, east and south edges, drawn in the deep root tile (0,2). A short west wall in the west-wall tile (2,1), `WallDoorNorth` (3 tiles) and `WallDoorSouth` (1 tile), stands either side of the two-tile door to Radio/Officers. The lane's east and west edges are exits (the west one sealed by living roots), so they have no wall tiles, and the low way to Corridor 2 runs off the east edge from the platform.
- **Size in art px:** 32x32 per tile; the Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** As Cell 3. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Corridor 2 floor and walls

- **Thing:** Corridor 2 (the floor and walls of the Room)
- **Source pack and files:** The same tiles as Corridor 1. Floor under the whole Room; north walls two tiles of face either side of the Interviews doorway; a whole south wall, one tile plus the strip; an east wall in the east-wall tile (3,1) above and below the locked door. Along the high road's south side the dividing wall, `WallDivide`, two tiles of north face (sand lip, navy base) seen from the low road. The hall's chasm runs on through it in the deep root tile (0,2), edged by the chasm rim (`scenes/world/chasm_edge.gd`), under the dividing wall and round the low road's ledge, stair runs and the landing between flights; three flights of stairs (`stair_flight.png`) lie over the chasm. The store cupboard is a block of wall at the top of the first flight, its top in the south wall top tile (4,1) and its face in the strip tile (5,1), with its door in its east face dressed in Corridor 1's door frame (`door_frame.png`, `CupboardDoorFrame`) and a side lantern above it (`CupboardDoorLamp`).
- **Size in art px:** 32x32 per tile; the Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** As Corridor 1. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Store cupboard

- **Thing:** Store cupboard
- **Source pack and files:** The same tiles as Radio/Officers: a small room, 8 by 6 tiles inside (smaller than a cell), in the middle of a full Room, root masses in the deep root tile (0,2) all round it; a north face of two tiles, side walls in the side tiles, a south wall in the south wall top and strip; its door in the east wall. Dressed with the Dungeons' barrels, sacks, clay pot and bucket, a side lantern (`lamp_side.tscn`) on its west wall, and the greatsword (`greatsword_floor.png`) lying on the floor.
- **Size in art px:** 32x32 per tile.
- **Palette notes and accents used:** As Radio/Officers. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### The other Rooms' floor and walls

- **Thing:** Every other Room of the Dungeons (Cells 1 and 2, Corridors 3 and 4, the Lobby, Reception, the offices, Interviews, the meeting and staff rooms, the Store room, the back corridors and the Cave)
- **Source pack and files:** The same tiles as Cell 3 (`assets/shared/dungeon_tiles/dungeon_tiles.tres`, no new tiles), laid by the same rule from each Room's walls: floor under the whole Room (plus the strip under a south doorway), north walls two tiles of face, side walls one tile, south walls one tile plus the strip, every doorway open. Two root columns (`root_vein_column.png`) on each Room's north wall, clear of the doorways.
- **Size in art px:** 32x32 per tile; each Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** As Cell 3. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor). Not yet: each Room's own props (the speaking-root, listening slit, root-fed trough, woven bins), the Main entrance and Cave door art, and the tree's glow in the veins.

#### Corridor 1 Back entrance seal

- **Thing:** Back entrance seal (a path blocker of living roots across the west end of Corridor 1; see Fire)
- **Source pack and files:** `assets/shared/dungeon_tiles/root_seal.png`, drawn by hand after CRAWLING DEPTHS `root_vein_column`'s silhouette. Set in `corridor_1.tscn` under `BackEntranceSeal/Look/Art`; the shared `path_blocker.tscn` stays placeholder. See `assets/CREDITS.md`.
- **Size in art px:** 16x616 (the 16x616 unit footprint; a Sprite2D at scale 1). One 88 row pattern repeated seven times; the joins fall on a narrow neck of the root.
- **Palette notes and accents used:** Navy body, indigo right edge, a few base violet flecks. No accent; the glowing veins are not drawn.
- **Animations and poses needed:** One still picture.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Root wall

- **Thing:** Root wall (the Dungeons' wall of grown roots, in Cell 3 the Roots over the south doorway)
- **Source pack and files:** CRAWLING DEPTHS `root_vein_column`: Cell 3's Roots (`roots_blocker.png`); Corridor 1's Back entrance seal (`root_seal.png`, drawn by hand from the column's silhouette); and the two root columns on Corridor 1's north wall (`root_vein_column.png`, the column's top bulge cropped and edged by hand). All in `assets/shared/dungeon_tiles/`. See `assets/CREDITS.md`.
- **Size in art px:** 128x16 for the Roots; 16x616 for the seal; 40x60 for a column.
- **Palette notes and accents used:** Navy and indigo with violet flecks. The glowing veins (arch-tree glow) are not drawn yet.
- **Animations and poses needed:** None yet.
- **Status:** in the game for Cell 3's Roots, Corridor 1's seal and columns (first draft; the owner checks the look in the editor)
