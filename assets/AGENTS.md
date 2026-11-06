# Art guide

The working rules for anyone, person or agent, who brings art into the game or changes how something looks. The look bible, `docs/art.md`, holds what still holds about colour, the mood of each area and a look sheet per character, creature and gameplay piece; read it before choosing or editing art. This guide does not repeat it.

Sound is out of scope for now. The HUD's bars are drawn in code (`scenes/hud/hud_bar.gd`); `docs/art.md` has their look.

## Direction in short

- **View:** three-quarter view. Floors are seen from above; wall faces and character fronts are visible. What is lower on screen draws in front (Y-sort).
- **Scale:** pixel art at 32 px. One art pixel is 1 world unit. A tile is 32 art pixels, so 32 units, and a Room of 1152×648 units is 36 by 20 tiles plus a quarter-tile strip for the south wall. Characters are about 32×48 art pixels, with their feet on the collision body (radius 12 units).
- **Pixel-exact:** the game is drawn at 1152×648 and scaled up by whole numbers, so everything lands on whole art pixels. Gameplay positions stay exact. Every camera has zoom 1, so it shows 1152×648 units through the 1152×648 view, and its position is a whole unit (one art pixel). A Room that follows Almos zooms to 2 (`Room.follow_zoom`). The HUD and the thoughts are drawn on CanvasLayers at scale 2 (`PixelText.UI_SCALE`), so a HUD pixel is 2 screen pixels.
- **Code-drawn looks:** effects drawn in code (dust, debris, sparks, the chasm rim, the lamp glow, the darkness dither, the spell effects) draw on the art grid too. Those not yet redrawn at 32 px still draw in 2-unit blocks (their `PIXEL` constant), as they did at 16 px.
- **Colour:** free. There is no master palette: use as many colours as an asset needs. Keep the mood (muted and dark, fire warm against it), and never use Danger red (`#d62839`) outside the Unblockable warning. `docs/art.md` has the details.
- **Walls:** walls snap to the 32-unit tile grid (one 32-art-px tile). North-facing walls, seen face-on, get collision as tall as their drawn face, about two tiles (64 units); side and south walls stay thin. So a north wall's drawn face is about two tiles tall and must match its collision. The wall grid is set by #74; changing it needs the owner's say.
- **Combat cues:** a pose plus a short flash, never colour alone.
- **References:** Hyper Light Drifter (the view, a muted palette with sharp accents, readable wind-ups) and Blasphemous (grim and devotional).
- **Avoid:** cute or chibi proportions, bright saturated fantasy colours, outlines heavier than one pixel.

## Bringing art in

1. **Intake.** Each candidate pack goes, unpacked, into its own folder `assets/_incoming/<pack>/`. Git ignores this folder and Godot does not import it (it holds a `.gdignore`). Nothing in it is ever committed.
2. **Shortlist.** An agent sorts the packs in `assets/_incoming/SHORTLIST.md`: each pack, or file, is *fits*, *needs edit* or *rejected*, with the reason and its licence. The shortlist is not committed either.
3. **Approve.** The owner approves what is used. A file can be approved only with a confirmed licence that allows using and modifying it in a game. A pack with no licence file, or one that only links to terms nobody has read, is not approved until its source and terms are known. Note any extra terms, such as a ban on AI training, in the shortlist, and in the Licence column of `assets/CREDITS.md` when the file is committed.
4. **Adjust (optional).** A pack can be used as drawn. If its colours fight the rest of the game, adjust it by hand, or map it onto a palette with `python3 -I scripts/recolour_palette.py IN.png OUT.png` (`--palette` picks any `.hex` file; the old base is `assets/palette/master.hex`). Remove any Danger red.
5. **Place.** Put the file where it belongs (see below) and attach it to the thing's `Look`.
6. **Credit.** Add a row to `assets/CREDITS.md` in the same commit.

## Layout and names

- `assets/<area>/<thing>/` for art that belongs to one area, such as `assets/dungeons/cell_3/`.
- `assets/shared/<thing>/` for art used in more than one area.
- `assets/characters/<name>/` for Almos and the Nar, such as `assets/characters/nar_jailer/`.
- `assets/creatures/<name>/` for creatures, such as `assets/creatures/root_crawler/`.
- `assets/palette/` for the old base palette, kept as a starting point.

File and folder names are snake_case and use the words of `CONTEXT.md` (`checkpoint`, not `bonfire`; `room`, not `chamber`).

## Import settings

Every image shows pixel-exact: Nearest filtering and no mipmaps, so every art pixel stays exactly as drawn. Turn mipmaps off on import. Nearest is the project default (`rendering/textures/canvas_textures/default_texture_filter`), so no per-node filter is needed; leave a node's `texture_filter` on Inherit.

## Attaching art to a Look

Art never changes code or tests. Each thing draws itself inside its `Look` node (every non-wall `Placeholder` is a `Look`):

- Put an AnimatedSprite2D, or a Sprite2D, inside the `Look`. A Room's floor and walls use a TileMapLayer.
- Hide the placeholder polygon; do not delete what the code or tests use.
- Line the art up with the collision body; do not move the body to fit the art.
- Draw sprites at scale 1 (one art pixel is 1 world unit).
- Code shows and hides a `Flame` by its visibility, so the `Flame` stays a polygon child of the thing: give the polygon a colour alpha of 0 and put the AnimatedSprite2D under it as a child. (Setting the polygon's `visible` off would hide the sprite too.)

### Almos's sprite

Almos's sprite is an AnimatedSprite2D named `Art` inside his `Look`. The `AlmosLook` node under `Look` plays `walk_<side>` while he walks, `sprint_<side>` while he Sprints and `idle_<side>` while he stands (with a `fidget_<side>` now and then), where the side is `down`, `up` or `side` from his facing (a diagonal shows the side). A Jump shows `jump_<side>`, a loss of Health `hurt_<side>` and a Block `block_<side>`. A Roll, a vanishing dash, plays `walk_<side>` from its first frame and leaves shadows; `roll_<side>` is drawn but not played. `AlmosLook` may move `Art` a pixel or two (the landing's dip), never his `Look`, which the Jump, the falls and the Hiding spots move. A swing shows `attack_<side>` (5 frames: wind-up, coil, strike, follow-through, recover), with the frame picked from the swing's startup, active and recovery frames rather than a frame rate; attack frames are 64x64 with the body centred and the feet on row 55. Draw the side frames facing right; `Art` is flipped for left. His facing arrow (`Look/Facing/Shape`) is hidden, not deleted; the Block and Parry shapes still show over the sprite.

### Enemy sprites

An enemy's sprite is an AnimatedSprite2D named `Art` inside its `Look`. The `EnemyLook` node under `Look` plays the animation named for the enemy's state: `idle`, `walk`, `strike`, `low`, `unblockable`, `break`, `death` (a missing name is skipped; `hurt` is not played yet, it needs a hurt signal from the enemy, which is still open). It puts `assets/shared/flash/flash.gdshader` on `Art` for the cream and Danger red wind-up flashes; do not give `Art` another material. `Art` turns with the enemy by `flip_h` (left or right only; up and down keep the last side), so draw it facing right. With an `Art`, the enemy is not tinted; without one, it keeps its old tints.

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

- No image uses Danger red (`#d62839`); a test checks.
- `assets/CREDITS.md` has a row for every third-party file committed.
- Nothing from `assets/_incoming/` is committed (`git status` must not list it).
- The full suite is green: `GODOT=<path> scripts/test.sh`.
