# Look bible

How the game looks: the palette and what each accent means, the references, the mood of each area and a look sheet for every character, creature and gameplay piece. It grows as art is chosen. How to bring art in, and what an art change may touch, is in `assets/AGENTS.md`. What things are and do is in `CONTEXT.md`; this file says only how they look.

## Palette

The master palette is chosen. Its base is Lospec's Oil 6 (https://lospec.com/palette-list/oil-6) plus the four reserved accents below.

| Role | Hex |
|------|-----|
| Cream (the white flash) | `#fbf5ef` |
| Sand | `#f2d3ab` |
| Dusty rose | `#c69fa5` |
| Base violet | `#8b6d9c` |
| Slate indigo | `#494d7e` |
| Navy (the colour darkness steps toward) | `#272744` |

The heaviest darkness steps (66% or more of the way to navy) bring the two darkest base colours below dE 5 apart, so the overlay (#78) should use at most the lighter steps.

Files: `assets/palette/master.png`, `assets/palette/master.gpl`, `assets/palette/master.hex`.

### Rules

- One master palette for the whole game. Every asset is recoloured into it.
- A muted base of 6 to 12 colours, in the spirit of Lospec's Oil 6.
- The lightest colour is the white flash, a cream flash: the start of every wind-up cue.
- The darkest colour is a navy: the colour darkness steps toward.
- Four reserved accents sit on top of the base. Each marks only the things listed for it and appears nowhere else.

### Reserved accents

| Accent | Marks | Hex |
|--------|-------|-----|
| Fire amber | Torches, Fire, the fireball, burning Root crawlers, the rim of every lit circle | `#f29a2e` |
| Danger red | Only the Unblockable attack | `#d62839` |
| Arch-tree glow, pale gold-green | Checkpoint shoots, glowing fungus, the tree's light | `#c9e06b` |
| Ilion violet-magenta | Ilion, drained magic, a Seal breaking, Channelling | `#d23fd0` |

Ilion violet-magenta is clearly more saturated than any violet in the base, so the two are never mistaken for each other.

## Cues

- A cue is a pose plus a brief flash in palette colours, never colour alone.
- **Normal wind-up:** the pose, with a cream flash at its start.
- **Unblockable wind-up:** the pose, a cream flash, then Danger red held to the end of the wind-up, with its own sound.

### How Looks animate

- An enemy with an AnimatedSprite2D named `Art` in its `Look` is driven by `EnemyLook`: it plays `idle`, `walk`, `strike`, `low`, `unblockable`, `break` or `death` for what the enemy is doing, and skips a name the sprite lacks. `hurt` is not played yet: it needs a hurt signal from the enemy, which is still open. The sprite is flipped left or right with the way the enemy faces, so it is drawn facing right.
- The flash is drawn on the sprite by `assets/shared/flash/flash.gdshader` (cream, then Danger red for an Unblockable), so the enemy itself is never tinted. Without an `Art` sprite the old whole-look tints stay.

## Darkness

- The dark is a dithered overlay drawn from the gameplay light, so it looks as dark as enemies treat it.
- Each dark zone goes two or three steps toward the palette's navy.
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

- Root and packed earth, not stone.
- The wood is veined with the tree's glowing light.
- Where Ilion feed, the wood is grey, cracked and bleeding sap.
- Rooms keep their modern names, but each is served by grown and hand-made means: a speaking-root, a listening slit, a root-fed trough, woven bins.

### Other areas

- **Base of the tree:** mood decided when it is drawn.
- **Upper tree:** mood decided when it is drawn.
- **Catacombs:** mood decided when it is drawn.
- **Lands between:** mood decided when it is drawn.

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
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Nar jailer

- **Thing:** Nar jailer
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

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
- **Size in art px:** 32x28 canvas for every frame, body about 20x16, feet on the bottom row of the body (sprite offset puts them on the 12-unit collision body's foot).
- **Palette notes and accents used:** Base only: navy outline, indigo and violet body, sand and cream teeth. The pack's crimson is mapped away from Danger red and Fire amber. While it burns, the shared Fire flame stands on its feet (Fire amber).
- **Animations and poses needed:** `idle`, `walk` (loop); `strike` (arm raised, then swing); `low` (crouched flat, maw open, then a low lunge); `unblockable` (reared tall with the arm overhead, held, then the slam); `break` (leaning back and slumped, held); `death`. The sprite faces right and turns with the crawler by `flip_h` (left or right).
- **Status:** in the game (first draft; the owner checks the look in the editor).

### Gameplay pieces

#### Torch

- **Thing:** Torch (see Pull)
- **Source pack and files:** Bracket: Dead Swamp (Sevarihk / Aurora), `assets/shared/torch/torch.png`. Flame: hand-redrawn after Gigapack `fire_looping_003A`, `assets/shared/torch/flame_0-4.png`. See `assets/CREDITS.md`.
- **Size in art px:** Bracket 10×37; flame 16×24 (5 frames).
- **Palette notes and accents used:** Bracket in the base violets and blues. Flame in Fire amber with sand and cream for the body and the core. A small, steady flame, so a lit torch stays apart from Fire.
- **Animations and poses needed:** One looping burn (5 frames, 8 per second). Lit shows it; out hides it (the Flame node's visibility). The bracket's polygon is hidden, not deleted.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Fire

- **Thing:** Fire
- **Source pack and files:** Gigapack (Will Tice / unTied Games) `fire_looping_004B`, `assets/shared/fire/flame_0-14.png`. See `assets/CREDITS.md`.
- **Size in art px:** 20×32 (15 frames), drawn over the 16×20 body of a Flammable, its foot on the body's foot.
- **Palette notes and accents used:** Fire amber with sand and cream for the core; the smoke above in the base violets. Larger than a torch flame, with smoke, so a burning thing and a lit torch read apart.
- **Animations and poses needed:** One looping burn (15 frames, 12 per second), shown only while the thing burns (the Flame node's visibility).
- **Status:** in the game (first draft; the owner checks the look in the editor). Used by every Flammable, the Root crawler's burning look included (root_crawler.tscn places the shared flame at `Flammable/Flame/Art`).

#### Fireball

- **Thing:** Fireball (see Shove)
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

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
- **Source pack and files:**
- **Size in art px:**
- **Palette notes and accents used:**
- **Animations and poses needed:**
- **Status:** not chosen

#### Path blocker

- **Thing:** Path blocker (living roots or a door that close a passage; see Fire)
- **Source pack and files:** Cell 3's Roots only: CRAWLING DEPTHS `root_vein_column`, rotated and squeezed by hand into a horizontal root, `assets/shared/dungeon_tiles/roots_blocker.png`. Set in `cell_3.tscn` under `Roots/Look/Art`; the shared `path_blocker.tscn` and the test room stay placeholder. See `assets/CREDITS.md`.
- **Size in art px:** 64x8 (the 128x16 unit footprint of Cell 3's Roots; a Sprite2D at scale 2).
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

The Dungeons tiles live in one TileSet, `assets/shared/dungeon_tiles/dungeon_tiles.tres`, from one 16x16 art px atlas, `dungeon_tiles.png`. A Room draws its floor and walls with TileMapLayers at scale 2. The floor sits behind Almos, the north and side walls behind him, and the south walls in front of him (by `z_index`).

#### Cell 3 floor

- **Thing:** Cell 3 (the floor of the Room)
- **Source pack and files:** Hand-drawn packed earth in the palette, guided by CRAWLING DEPTHS `earth_floor` (its violet came out wrong, so the pixels are new). `assets/shared/dungeon_tiles/dungeon_tiles.png`, tiles 0-3 of row 0 (four floor variants) and tile 4 (the 4 art px strip at the south wall). See `assets/CREDITS.md`.
- **Size in art px:** 16x16 per tile; the Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** Dusty rose ground, a few base violet and sand flecks. No accent.
- **Animations and poses needed:** None; four variants laid in a fixed pattern.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Cell 3 walls

- **Thing:** Cell 3 (the walls of the Room)
- **Source pack and files:** Dead Swamp (Sevarihk / Aurora) `woven_wall`, one 16x16 weave cut from it and edged by hand; `assets/shared/dungeon_tiles/dungeon_tiles.png`, row 1: north face top (sand lip), north face base (navy shadow), left side, right side, south wall top, south wall strip. The tiles follow the wall grid: north face 2 tiles, sides 1, south 1 plus the strip. See `assets/CREDITS.md`.
- **Size in art px:** 16x16 per tile.
- **Palette notes and accents used:** Woven bark in base violet and indigo with navy shadows; the south wall seen from above is darker. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Corridor 1 floor and walls

- **Thing:** Corridor 1 (the floor and walls of the Room)
- **Source pack and files:** The same tiles as Cell 3 (`assets/shared/dungeon_tiles/dungeon_tiles.tres`, no new tiles). Floor under the whole Room; north walls are two tiles of face (sand lip, navy base) in four runs between the three north doorways; south walls are one tile plus the strip in two runs either side of the south doorway. The east and west edges are exits, so they have no wall tiles.
- **Size in art px:** 16x16 per tile; the Room is 36x20 tiles plus the strip.
- **Palette notes and accents used:** As Cell 3. No accent.
- **Animations and poses needed:** None.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Corridor 1 Back entrance seal

- **Thing:** Back entrance seal (a path blocker of living roots across the west end of Corridor 1; see Fire)
- **Source pack and files:** `assets/shared/dungeon_tiles/root_seal.png`, drawn by hand after CRAWLING DEPTHS `root_vein_column`'s silhouette. Set in `corridor_1.tscn` under `BackEntranceSeal/Look/Art`; the shared `path_blocker.tscn` stays placeholder. See `assets/CREDITS.md`.
- **Size in art px:** 8x308 (the 16x616 unit footprint; a Sprite2D at scale 2). One 44 row pattern repeated seven times; the joins fall on a narrow neck of the root.
- **Palette notes and accents used:** Navy body, indigo right edge, a few base violet flecks. No accent; the glowing veins are not drawn.
- **Animations and poses needed:** One still picture.
- **Status:** in the game (first draft; the owner checks the look in the editor)

#### Root wall

- **Thing:** Root wall (the Dungeons' wall of grown roots, in Cell 3 the Roots over the south doorway)
- **Source pack and files:** CRAWLING DEPTHS `root_vein_column`: Cell 3's Roots (`roots_blocker.png`); Corridor 1's Back entrance seal (`root_seal.png`, drawn by hand from the column's silhouette); and the two root columns on Corridor 1's north wall (`root_vein_column.png`, the column's top bulge cropped and edged by hand). All in `assets/shared/dungeon_tiles/`. See `assets/CREDITS.md`.
- **Size in art px:** 64x8 for the Roots; 8x308 for the seal; 20x30 for a column.
- **Palette notes and accents used:** Navy and indigo with violet flecks. The glowing veins (arch-tree glow) are not drawn yet.
- **Animations and poses needed:** None yet.
- **Status:** in the game for Cell 3's Roots, Corridor 1's seal and columns (first draft; the owner checks the look in the editor)
