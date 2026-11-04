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
| Fire amber | Torches, lamps, Fire, the fireball, burning things | `#f29a2e` |
| Arch-tree glow, pale gold-green | Checkpoint shoots, glowing fungus, the tree's light | `#c9e06b` |
| Ilion violet-magenta | Ilion, drained magic, a Seal breaking | `#d23fd0` |

The old base, Lospec's Oil 6 (cream `#fbf5ef`, sand `#f2d3ab`, dusty rose `#c69fa5`, base violet `#8b6d9c`, slate indigo `#494d7e`, navy `#272744`), is what the art so far is drawn in. It stays in `assets/palette/` as a starting point, not a limit, and `scripts/recolour_palette.py` can still map an image onto it (or onto any `.hex` palette given with `--palette`) when that helps an asset sit with the rest.

## Cues

- A cue is a pose plus a brief flash, never colour alone.
- **Normal wind-up:** the pose, with a cream flash at its start.
- **Unblockable wind-up:** the pose, a cream flash, then Danger red held to the end of the wind-up, with its own sound.

### How Looks animate

- An enemy with an AnimatedSprite2D named `Art` in its `Look` is driven by `EnemyLook`: it plays `idle`, `walk`, `strike`, `low`, `unblockable`, `break` or `death` for what the enemy is doing, and skips a name the sprite lacks. `hurt` is not played yet: it needs a hurt signal from the enemy, which is still open. The sprite is flipped left or right with the way the enemy faces, so it is drawn facing right.
- The flash is drawn on the sprite by `assets/shared/flash/flash.gdshader` (cream, then Danger red for an Unblockable), so the enemy itself is never tinted. Without an `Art` sprite the old whole-look tints stay.

## Darkness

- The dark is a dithered overlay drawn from the gameplay light, so it looks as dark as enemies treat it.
- Each dark zone goes two or three steps toward navy.
- Each lit torch or Fire cuts a circle of exactly its light radius, rimmed in Fire amber.

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

- **Mood (the owner's polish pass):** a damp, dim root-prison. The floor is packed earth in muted mauve-browns with a few pebbles, roots and one short crack among its four tiles; the woven walls are a shade deeper, with faint veins of the tree's pale gold-green light. A cool grade over the whole Dungeons (a CanvasModulate named `Grade`) lets every flame read warm: each lit torch, lamp and Fire throws a flickering, dithered amber pool, added onto what is under it (`scenes/world/lamp_glow.gd`, under the Flame, so it goes out with it). Furniture and cell props are warm, muted wood. Each Room has a little life (`scenes/world/ambience.gd`): dust drifting in the light and the cells' window shafts, water dripping from the north walls with a splash, and pale motes rising out of the hall's chasm. Moss is kept sparse.

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
  - `roll` (6 frames at 20 a second, played once from the start of each roll)
  - `attack` (5 frames: wind-up, coil, strike with a smear arc, follow-through, recover). These are not played at a frame rate: `AlmosLook` picks the frame from the swing's own startup, active and recovery frames, so it fits every Weapon and every swing of a combo. A charging Heavy attack holds the coil. The smear is drawn without a weapon, so it stands for any Weapon or for a fist.

  The side frames face right and are flipped for left; a diagonal shows the side. Still owed: Block, Parry, Sip, Jump, the limp Death pose, and a weapon drawn in hand; until then the Block and Parry shapes and the death tint show over the sprite. The sword's strike box (`Sword/Look/Shape`) is transparent now that the smear shows the swing; it stays for the code and tests that measure it. The torches hung on him (`CarriedTorch`, `HeldFlame`) show only their flame. Pointed ears are left off, since whether the Nar have them is not decided.
- **Status:** in the game (fifth draft, the first in free colour; the owner checks the look in the editor)

#### Nar jailer

- **Thing:** Nar jailer (the key jailer included)
- **Source pack and files:** Drawn for this game (no pack), `assets/characters/nar_jailer/`, by `scripts/art/draw_nar_jailer.py` at 32 px. A jailer is a fellow Nar, so he is a variation of Almos: drawn on Almos's own build and side-on poses (`scripts/art/draw_almos.py`, with its `Outfit`) in a guard's outfit: a moss-grey hood with a short tail and its mantle, a dark leather jerkin over a grey shirt, a dark leather belt with a bone buckle and a baldric, dark trousers and boots, and a sword of grey iron (crossguard, wrapped grip, pommel). He wears no Seal (only the Marked do) and carries no Flask. The same bark-grey Nar skin and pale eye as Almos. `scenes/enemies/nar_jailer.tscn` is the training enemy with the jailer's tuning and this sprite; the key jailer in Radio/Officers is one with its own tuning. The test room's jailers stay placeholder.
- **Size in art px:** 64x64 canvas, facing right, feet on row 55 (sprite offset -16 art px), the body in the middle as in Almos's attack frames, so he stands as tall as Almos.
- **Palette notes and accents used:** Free colour, muted: moss-grey hood, dark leather browns, grey cloth, a pale steel blade with a glint. No accent; the flashes come from the shared shader.
- **Animations and poses needed:** `idle` (2, a breath, the sword hanging at his side), `walk` (4, a stride), `strike` (sword drawn back over the shoulder, swung down, recover), `low` (crouched, a sweep along the floor), `unblockable` (sword raised high in both hands, held, slammed down), `break` (knocked back and slumped, the sword hanging), `death` (buckles, drops to his knees, falls flat with the sword fallen from his hand), `sit` (2, on the guard post's bench, the sword across his knees). Not yet: a key at the key jailer's belt, and Block and Parry poses.
- **Burning:** a jailer carries a `Flammable` of the creature kind, as the Root crawler does: a fireball's hit or splash sets it alight, and the shared Fire flame stands on its feet while it burns.
- **Status:** in the game (fourth draft: a variation of Almos with a sword; the owner checks the look in the editor).

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
- **Placement:** Wall lanterns hang on north wall faces, the node at y 36 so the lantern sits on the face. In a cell the lamp hangs on the cell's own north face, or stands on its floor. Cell 3's standing lamp keeps the old torch's spot, within Pull's reach of the roots.
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
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

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
- **Loose things and growth:** The hall is laid out as a place people use, not scattered: a rockfall in the west corner (two big rocks and their rubble of small rocks), the prisoners' water barrel and bucket by Cell 3's door, the stores against the middle wall (barrels in a row, a pot, a crate stack, burlap sacks), and the guard post east of Cell 2's door (a barrel, a bench with a bowl, a bucket and the spear rack) where a second guard sits on the bench (`sit`, two frames of a slow breath, played while he is at rest at his post; he gets up once he is hurt or in Pursuit). Bones and skulls lie only along the chasm's lip and on its ledges. Everything that is not a plant can be lifted and thrown (barrels, bone piles, pots and bowls break where a throw ends; the bench, rack and crates are too heavy yet and shudder). Plants are only a look, kept sparse: floor moss, small glowing fungus and moss hanging from the north wall (`assets/dungeons/growth/`, drawn by `scripts/art/draw_world.py`: moss in low cushions of touching lumps, the fungus caps in the arch-tree glow on pale stems). The cells' lamps hang on their north walls; no lamp stands on a pole in the Dungeons' hall or cells. Cell 3 has a bowl by the bed and a puddle under a drip.
- **Metal gate:** `assets/dungeons/gates/metal_gate.png`, 128x56 art px, drawn by `scripts/art/draw_world.py`: iron bars between a top rail and a cross rail, rivets with a glint and rust flecks on the bars, darker posts at each end. It stands on its doorway's footprint. Melting, it glows from white to a hot orange and melts away from the top down, a molten edge eating down the bars and dripping, their feet last; crashed, it bursts in pieces of its own art.
- **Status:** in the game in Corridor 1 (first draft; the owner checks the look in the editor)

#### Furniture and cover

- **Thing:** The Dungeons' furniture. Crate stacks are cover: solid, on the walls layer, so they block Sight and movement as a wall does.
- **Source pack and files:** Drawn for this game, `assets/dungeons/furniture/`. Redrawn at 32 px in code by `scripts/art/draw_props.py` (on `scripts/art/pixelkit.py`), at the same canvas sizes, so every footprint and rim is where it was.
  - `crate_stack.png` (`scenes/world/crate_stack.tscn`, a StaticBody2D in the group "cover", its box on the lower crate's footprint)
  - `bench.png`, `spear_rack.png`, `sacks.png`: dressing with no collision
- **Size in art px:** Crate stack 48x52, bench 60x18, spear rack 36x52, sacks 36x22.
- **Palette notes and accents used:** Warm brown wood (lighter on the tops seen from above), crates with a framed front and a pale brace, burlap sacks tied with rope, iron spear heads with a glint. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game in Corridor 1 (first draft; the owner checks the look in the editor)

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
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

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
- **Animations and poses needed:**
- **Status:** not chosen

#### Jailer's key

- **Thing:** Jailer's key
- **Source pack and files:**
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
- **Cell 2:** wider (14 by 11 tiles) and damp. A window to the left with its shaft of light, a puddle of seep water (`cell_puddle.png`), a cracked bowl (`cell_bowl.png`), three rows of tallies, and a standing lamp in the corner.
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

#### Deep root

- **Thing:** The solid root that fills a Room around its walkable space (Corridor 1 and the three cells), made to read as deliberate darkness so the eye stays on the hall or the cell.
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
- **Source pack and files:** The same tiles as Cell 3 (`assets/shared/dungeon_tiles/dungeon_tiles.tres`, no new tiles). Floor under the whole Room; north walls are two tiles of face (sand lip, navy base) in four runs between the three north doorways; south walls are one tile plus the strip in two runs either side of the south doorway. The east and west edges are exits, so they have no wall tiles.
- **Size in art px:** 32x32 per tile; the Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** As Cell 3. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### The other Rooms' floor and walls

- **Thing:** Every other Room of the Dungeons (Cells 1 and 2, Corridors 2 to 4, the Lobby, Reception, the offices, Interviews, the meeting and staff rooms, the Store room, the back corridors and the Cave)
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
