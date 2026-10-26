# Art guide

The working rules for anyone, person or agent, who brings art into the game or changes how something looks. The look bible, `docs/art.md`, holds the palette, the meaning of each accent, the mood of each area and a look sheet per character, creature and gameplay piece; read it before choosing or editing art. This guide does not repeat it.

Sound and the HUD's look are out of scope for now.

## Direction in short

- **View:** three-quarter view. Floors are seen from above; wall faces and character fronts are visible. What is lower on screen draws in front (Y-sort).
- **Scale:** pixel art. One art pixel is 2 world units. A tile is 16 art pixels, so 32 units, and a Room of 1152×648 units is 36 by 20 tiles plus a quarter-tile strip for the south wall. Characters are about 16×24 art pixels, with their feet on the collision body (radius 12 units).
- **Pixel-exact:** the game is drawn at 576×324 and scaled up by whole numbers, so everything lands on whole art pixels. Gameplay positions stay exact. Every camera has zoom 0.5, so it shows 1152×648 units through the 576×324 view, and its position is a multiple of 2 units (one art pixel).
- **Palette:** one master palette: a muted base of 6 to 12 colours in the spirit of Lospec's Oil 6, plus four reserved accents used nowhere else: Fire amber, Danger red, the arch tree's glow and Ilion violet-magenta. Every asset is recoloured into it. `docs/art.md` says what each accent may mark.
- **Walls:** walls snap to the 32-unit tile grid (one 16-art-px tile). North-facing walls, seen face-on, get collision as tall as their drawn face, about two tiles (64 units); side and south walls stay thin. So a north wall's drawn face is about two tiles tall and must match its collision. The wall grid is set by #74; changing it needs the owner's say.
- **Combat cues:** a pose plus a short flash in palette colours, never colour alone.
- **References:** Hyper Light Drifter (the view, a muted palette with sharp accents, readable wind-ups) and Blasphemous (grim and devotional).
- **Avoid:** cute or chibi proportions, bright saturated fantasy colours, outlines heavier than one pixel.

## Bringing art in

1. **Intake.** Each candidate pack goes, unpacked, into its own folder `assets/_incoming/<pack>/`. Git ignores this folder and Godot does not import it (it holds a `.gdignore`). Nothing in it is ever committed.
2. **Shortlist.** An agent sorts the packs in `assets/_incoming/SHORTLIST.md`: each pack, or file, is *fits*, *needs edit* or *rejected*, with the reason and its licence. The shortlist is not committed either.
3. **Approve.** The owner approves what is used. A file can be approved only with a confirmed licence that allows using and modifying it in a game. A pack with no licence file, or one that only links to terms nobody has read, is not approved until its source and terms are known. Note any extra terms, such as a ban on AI training, in the shortlist, and in the Licence column of `assets/CREDITS.md` when the file is committed.
4. **Recolour.** Map every pixel to the master palette: first to the nearest palette colour, then fix by hand what that breaks.
   Run `python3 -I scripts/recolour_palette.py IN.png OUT.png` (palette: `assets/palette/master.hex`), then `python3 -I scripts/recolour_palette.py --verify OUT.png`; it fails if any opaque pixel is off the palette.
5. **Place.** Put the file where it belongs (see below) and attach it to the thing's `Look`.
6. **Credit.** Add a row to `assets/CREDITS.md` in the same commit.

## Layout and names

- `assets/<area>/<thing>/` for art that belongs to one area, such as `assets/dungeons/cell_3/`.
- `assets/shared/<thing>/` for art used in more than one area.
- `assets/characters/<name>/` for Almos and the Nar, such as `assets/characters/nar_jailer/`.
- `assets/creatures/<name>/` for creatures, such as `assets/creatures/root_crawler/`.
- `assets/palette/` for the master palette.

File and folder names are snake_case and use the words of `CONTEXT.md` (`checkpoint`, not `bonfire`; `room`, not `chamber`).

## Import settings

Every image shows pixel-exact: Nearest filtering and no mipmaps, so every art pixel stays exactly as drawn. Turn mipmaps off on import. Nearest is the project default (`rendering/textures/canvas_textures/default_texture_filter`), so no per-node filter is needed; leave a node's `texture_filter` on Inherit.

## Attaching art to a Look

Art never changes code or tests. Each thing draws itself inside its `Look` node (every non-wall `Placeholder` is a `Look`):

- Put an AnimatedSprite2D, or a Sprite2D, inside the `Look`. A Room's floor and walls use a TileMapLayer.
- Hide the placeholder polygon; do not delete what the code or tests use.
- Line the art up with the collision body; do not move the body to fit the art.

## What an art change may touch

An art change changes looks only. It may touch:

- files under `assets/`, and `assets/CREDITS.md`
- the contents of `Look` nodes
- tilemaps and decoration that nothing collides with
- the look of the darkness overlay
- import settings

It needs the owner's say before it touches walls, collision, exits, gameplay pieces, data numbers or what a Room contains. If the art seems to need one of these, stop and ask.

The test room stays placeholder.

Never claim a look is right. The owner checks every look in the Godot editor.

## Checks before committing

- Every pixel of every new or changed image is a palette colour.
- `assets/CREDITS.md` has a row for every third-party file committed.
- Nothing from `assets/_incoming/` is committed (`git status` must not list it).
- The full suite is green: `GODOT=<path> scripts/test.sh`.
