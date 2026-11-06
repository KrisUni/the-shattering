"""Draws the Dungeons' props at 32 px: the hall's furniture, pots, bones and rocks, and the cells'.

    python3 scripts/art/draw_props.py [ASSETS_DIR] [--sheet SHEET.png]

Each picture keeps the canvas size of the one it replaces (the scenes, hiding spots and footprints
are lined up with those sizes), and is drawn with pixelkit.py: one light from the top left,
hue-shifted ramps, selective outlines. Seen in three-quarter view: tops from above, fronts face on.
ASSETS_DIR is `assets` by default; `-` writes nothing (for a sheet only).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

M = pk.Material
WOOD = M("#7f5c44", tones=4, step=0.075, lit_step=0.085)
WOOD_TOP = M("#94704f", tones=3, step=0.08)
WOOD_OLD = M("#6b5446", tones=3, step=0.07)
IRON = M("#4c5066", tones=3, step=0.08, shine=0.1)
IRON_DARK = M("#33354a", tones=2, step=0.05)
RUST = M("#7a5440", tones=2, step=0.06)
BURLAP = M("#94805f", tones=3, step=0.08)
ROPE = M("#b29467", tones=2, step=0.08)
CLAY = M("#8e5a45", tones=4, step=0.075, lit_step=0.09)
BONE = M("#c9bea3", tones=3, step=0.09, outline="#3a3340")
STONE = M("#62667c", tones=4, step=0.075, lit_step=0.09)
STONE_DARK = M("#4c4f63", tones=3, step=0.07)
MOSS = M("#5f6e4a", tones=2, step=0.07)
STRAW = M("#b39a63", tones=3, step=0.08)
CLOTH = M("#6e6170", tones=3, step=0.07)
WATER = M("#3d4766", tones=3, step=0.07, shine=0.1, outline="#262a40")
SKY = M("#5d6a8c", tones=2, step=0.08)

GLINT = (214, 212, 230)


def canvas(w, h):
    return pk.Canvas(w, h)


def out(c):
    return pk.remove_orphans(c.render())


def band(c, x0, x1, y, sag, thick, mat, z, line=True):
    """A band across a round thing, curving down by sag at the middle (seen from above)."""
    pixels = set()
    mid = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0 or 1
    for x in range(x0, x1 + 1):
        u = (x + 0.5 - mid) / half
        dy = round(sag * (1 - u * u))
        for t in range(thick):
            pixels.add((x, y + dy + t))
    return c.mask(pixels, mat, z, form="cylinder", centre=(mid + 0.5, y + thick / 2.0),
                  radii=(half + 0.5, thick / 2.0 + 1), line=line)


def grain(c, part, mat, xs, y0, y1, gap=None):
    """Lines in the material's deep tone down a part, at these columns (staves, planks), where no
    part in front of it covers it. Call it once the parts in front are drawn."""
    covered = set()
    for other in c.parts:
        if other.z > part.z:
            covered |= other.mask
    for x in xs:
        for y in range(y0, y1 + 1):
            if (x, y) in part.mask and (x, y) not in covered and (gap is None or not gap(x, y)):
                c.dot(x, y, mat.ramp[0])


# --- the hall --------------------------------------------------------------------------------

def barrel(w=28, h=36):
    c = canvas(w, h)
    cx = w / 2.0
    body = []
    for i in range(0, 13):
        y = 5 + i * (h - 6) / 12.0
        bulge = math.sin(i / 12.0 * math.pi) * 1.6
        body.append((cx - 12.2 - bulge, y))
    for i in range(12, -1, -1):
        y = 5 + i * (h - 6) / 12.0
        bulge = math.sin(i / 12.0 * math.pi) * 1.6
        body.append((cx + 12.2 + bulge, y))
    bottom = lambda x, y: ((x + 0.5 - cx) / 13.5) ** 2 + ((y + 0.5 - (h - 4.5)) / 4.0) ** 2 <= 1.0 or y < h - 4.5
    b = c.poly(body, WOOD, 1, form="cylinder", clip=bottom)
    for y, sag in ((12, 2.5), (h - 11, 3.0)):
        band(c, 1, w - 2, y, sag, 3, IRON, 2)
    lid = c.ellipse(cx, 6.0, 12.0, 5.0, WOOD_TOP, 3, form="flat")
    lid.bias = 0.2
    grain(c, b, WOOD, [int(cx - 8), int(cx - 3), int(cx + 2), int(cx + 7)], 10, h - 2)
    inside = lambda x, y: ((x + 0.5 - cx) / 10.2) ** 2 + ((y + 0.5 - 5.8) / 3.5) ** 2 <= 1.0
    for (x, y) in lid.mask:
        if not inside(x, y) and y >= 3:
            c.dot(x, y, WOOD.ramp[1] if y < 6 else WOOD.ramp[0])
    for x in (int(cx - 4), int(cx + 3)):
        for y in range(3, 10):
            if inside(x, y):
                c.dot(x, y, WOOD_TOP.ramp[0])
    return out(c)


def bench(w=60, h=18):
    c = canvas(w, h)
    for x in (5, w - 9):
        c.box(x, 6, x + 3, h - 1, WOOD_OLD, 1, form="cylinder")
    top = c.box(1, 1, w - 2, 5, WOOD_TOP, 3, form="flat")
    top.bias = 0.1
    c.box(1, 6, w - 2, 8, WOOD, 3.2, form="cylinder")
    for y in (3,):
        for x in range(2, w - 2):
            if (x * 7) % 23 != 0:
                c.dot(x, y, WOOD_TOP.ramp[0] if x % 19 > 2 else WOOD_TOP.ramp[1])
    for x in (14, 31, 45):
        c.dot(x, 2, WOOD_TOP.ramp[0])
    return out(c)


def crate(c, x0, y0, w, h, top_h, z):
    top = c.box(x0, y0, x0 + w - 1, y0 + top_h - 1, WOOD_TOP, z + 0.2)
    top.bias = 0.1
    for x in range(x0 + 4, x0 + w - 2, 6):
        for y in range(y0 + 1, y0 + top_h - 1):
            c.dot(x, y, WOOD_TOP.ramp[0])
    front = c.box(x0, y0 + top_h, x0 + w - 1, y0 + h - 1, WOOD, z, form="cylinder")
    # The frame round the front and its brace, in the wood's deep tone and a lighter edge.
    fy0, fy1 = y0 + top_h, y0 + h - 1
    inner = set()
    for y in range(fy0 + 3, fy1 - 2):
        for x in range(x0 + 3, x0 + w - 3):
            inner.add((x, y))
    panel = c.mask(inner, WOOD_OLD, z + 0.1, form="flat")
    panel.bias = -0.15
    iw = w - 6
    ih = fy1 - 2 - (fy0 + 3)
    for i in range(iw):
        y_a = fy0 + 3 + round(i * (ih - 1) / max(1, iw - 1))
        y_b = fy1 - 3 - round(i * (ih - 1) / max(1, iw - 1))
        c.dot(x0 + 3 + i, y_a, WOOD.ramp[3])
        c.dot(x0 + 3 + i, y_a + 1, WOOD.ramp[1])
        c.dot(x0 + 3 + i, y_b, WOOD.ramp[2])
        c.dot(x0 + 3 + i, y_b + 1, WOOD.ramp[1])
    for x, y in ((x0 + 1, fy0 + 1), (x0 + w - 2, fy0 + 1), (x0 + 1, fy1 - 1), (x0 + w - 2, fy1 - 1)):
        c.dot(x, y, IRON.ramp[1])
    return front


def crate_stack(w=48, h=52):
    c = canvas(w, h)
    crate(c, 1, 24, w - 2, h - 24, 7, 1)
    crate(c, 6, 0, w - 13, 26, 7, 3)
    return out(c)


def sack(c, cx, bottom, rx, ry, z):
    body = c.ellipse(cx, bottom - ry, rx, ry, BURLAP, z,
                     clip=lambda x, y: y >= bottom - ry * 1.6)
    c.poly([(cx - rx * 0.55, bottom - ry * 1.55), (cx + rx * 0.55, bottom - ry * 1.55),
            (cx + 1.5, bottom - ry * 2.0), (cx - 1.5, bottom - ry * 2.0)], BURLAP, z + 0.1)
    c.capsule(cx - 2.5, bottom - ry * 1.95, cx + 2.5, bottom - ry * 1.95, 1.0, ROPE, z + 0.2)
    c.ellipse(cx, bottom - ry * 2.0 - 2.0, 2.0, 1.8, BURLAP, z + 0.15)
    for x in range(int(cx - rx + 3), int(cx + rx - 2), 4):
        c.dot(x, int(bottom - ry + 2), BURLAP.ramp[0])
    return body


def sacks(w=36, h=22):
    c = canvas(w, h)
    sack(c, 10, h - 1, 9.0, 6.5, 1)
    sack(c, 25, h - 1, 9.5, 6.8, 2)
    return out(c)


def spear_rack(w=36, h=52):
    c = canvas(w, h)
    for x in (3, w - 6):
        c.box(x, 8, x + 2, h - 1, WOOD_OLD, 1, form="cylinder")
    for x in (9, 18, 27):
        c.box(x, 6, x + 1, h - 3, WOOD, 2, form="cylinder")
        c.poly([(x - 1.5, 7), (x + 3.5, 7), (x + 1, 0)], IRON, 2.5, form="sphere")
        c.dot(x, 3, GLINT)
        c.box(x - 1, 7, x + 2, 8, ROPE, 2.6)
    c.box(1, 10, w - 2, 12, WOOD_TOP, 3, form="cylinder")
    c.box(1, h - 14, w - 2, h - 12, WOOD_TOP, 3, form="cylinder")
    return out(c)


def wardrobe(w=40, h=60):
    c = canvas(w, h)
    for x in (3, w - 7):
        c.box(x, h - 5, x + 3, h - 1, WOOD_OLD, 1)
    body = c.box(1, 5, w - 2, h - 5, WOOD, 2, form="cylinder")
    top = c.box(0, 0, w - 1, 5, WOOD_TOP, 3, form="cylinder")
    top.bias = 0.1
    for i, (x0, x1) in enumerate(((4, w // 2 - 2), (w // 2 + 1, w - 5))):
        d = c.box(x0, 8, x1, h - 8, WOOD_OLD, 2.5, form="cylinder")
        grain(c, d, WOOD_OLD, [x0 + (x1 - x0) // 2], 10, h - 10)
        hx = x1 - 1 if i == 0 else x0 + 1
        c.box(hx, h // 2 - 2, hx, h // 2 + 1, IRON, 3)
        c.dot(hx, h // 2 - 2, GLINT)
    return out(c)


def clay_pot(w=20, h=22):
    c = canvas(w, h)
    c.ellipse(w / 2, h - 8.5, 9.0, 8.0, CLAY, 1)
    c.box(6, 2, w - 7, 6, CLAY, 2, form="cylinder")
    lip = c.ellipse(w / 2, 2.8, 5.5, 2.4, CLAY, 3)
    lip.bias = 0.1
    c.ellipse(w / 2, 2.8, 3.4, 1.2, M("#3a2a2c", tones=2), 3.5, form="flat", line=False)
    band(c, 3, w - 4, 10, 1.5, 1, CLAY, 2.5, line=False)
    for (x, y) in list(c.parts[-1].mask):
        c.dot(x, y, CLAY.ramp[0])
    return out(c)


def bone_shape(c, ax, ay, bx, by, z, r=1.2):
    c.capsule(ax, ay, bx, by, r, BONE, z)
    dx, dy = bx - ax, by - ay
    n = math.hypot(dx, dy) or 1
    px, py = -dy / n, dx / n
    for (x, y) in ((ax, ay), (bx, by)):
        c.ellipse(x + px * 1.3, y + py * 1.3, 1.7, 1.7, BONE, z + 0.1)
        c.ellipse(x - px * 1.3, y - py * 1.3, 1.7, 1.7, BONE, z + 0.1)


def bone(w=20, h=10):
    c = canvas(w, h)
    bone_shape(c, 3.5, 6.5, 16.5, 3.5, 1)
    return out(c)


def skull_shape(c, cx, cy, z, scale=1.0):
    s = scale
    c.ellipse(cx, cy, 6.2 * s, 5.6 * s, BONE, z)
    c.box(int(cx - 3.5 * s), int(cy + 3.5 * s), int(cx + 3 * s), int(cy + 6.2 * s), BONE, z + 0.1, form="cylinder")
    hole = (42, 36, 48)
    n = 2 if s >= 1 else 1
    for ex in (-3, 1) if n == 2 else (-2, 1):
        for dx in range(n):
            for dy in range(n):
                c.dot(int(cx + ex) + dx, int(cy + 1) + dy, hole)
    c.dot(int(cx) - (1 if n == 2 else 0), int(cy + 3.5 * s), (70, 60, 72))
    for tx in range(int(cx - 2.5 * s), int(cx + 3 * s), 2):
        c.dot(tx, int(cy + 5.5 * s), BONE.ramp[0])


def skull(w=16, h=16):
    c = canvas(w, h)
    skull_shape(c, 8.0, 7.5, 1)
    return out(c)


def bone_pile(w=28, h=14):
    c = canvas(w, h)
    bone_shape(c, 3.5, 11, 15, 7.5, 1)
    bone_shape(c, 5, 6.5, 16, 11.5, 1.5)
    skull_shape(c, 20.5, 7.0, 3, scale=0.75)
    return out(c)


def rock(w, h, seed, mat=STONE, moss=False):
    c = canvas(w, h)
    pts = []
    n = 11
    cx, cy = w / 2.0, h / 2.0 + 1
    for i in range(n):
        a = i / n * 2 * math.pi
        r = 1.0 - 0.13 * (0.5 + 0.5 * math.sin(a * 3 + seed * 1.7)) - 0.06 * math.sin(a * 5 + seed)
        x = cx + math.cos(a) * (w / 2.0 - 0.6) * r
        y = cy + math.sin(a) * (h / 2.0 - 1.2) * r
        y = min(y, h - 0.6)
        pts.append((x, y))
    body = c.poly(pts, mat, 1, form="sphere")
    body.radii = (w / 2.0, h / 2.0)
    # Facets: a crack or two in the stone's deep tone, a lit chip on the top left.
    if w > 30:
        # One crack running down from the top, branching once.
        crack = [(cx + 2, cy - 9), (cx + 3, cy - 8), (cx + 3, cy - 7), (cx + 4, cy - 6), (cx + 4, cy - 5),
                 (cx + 5, cy - 4), (cx + 6, cy - 4), (cx + 7, cy - 3), (cx + 3, cy - 4), (cx + 2, cy - 3)]
        for x, y in crack:
            c.dot(int(x), int(y), mat.ramp[0])
        c.dot(int(cx + 2), int(cy - 10), mat.ramp[3])
    if moss:
        for x in range(int(cx - w * 0.3), int(cx + w * 0.2)):
            for y in range(1, int(h * 0.35)):
                if (x, y) in body.mask and (x * 13 + y * 7 + seed) % 5 < 2 and y < 4 + (x % 3):
                    c.dot(x, y, MOSS.ramp[(x + y) % 2])
    return out(c)


# --- the cells -------------------------------------------------------------------------------

def cell_bars(w, h=48):
    c = canvas(w, h)
    rail = c.box(0, 0, w - 1, 3, IRON, 3, form="cylinder")
    for x in range(4, w - 2, 12):
        c.box(x, 4, x + 3, h - 1, IRON, 2, form="cylinder")
        c.box(x - 1, h // 2 - 1, x + 4, h // 2 + 1, IRON_DARK, 2.5, form="cylinder")
    for x in range(2, w - 2, 12):
        c.dot(x, 1, GLINT)
    return out(c)


def cell_bed(w=68, h=38):
    c = canvas(w, h)
    for x in (2, w - 6):
        c.box(x, h - 8, x + 3, h - 1, WOOD_OLD, 1, form="cylinder")
    frame = c.box(0, 0, w - 1, h - 8, WOOD, 2, form="cylinder")
    c.box(0, h - 10, w - 1, h - 7, WOOD_OLD, 2.2, form="cylinder")
    mat = c.box(3, 3, w - 4, h - 13, STRAW, 3, form="flat")
    mat.bias = 0.05
    for i in range(40):
        x = 4 + (i * 17) % (w - 9)
        y = 4 + (i * 7) % (h - 18)
        c.dot(x, y, STRAW.ramp[0] if i % 3 else STRAW.ramp[2])
    blanket = c.box(w // 2 - 4, 3, w - 4, h - 13, CLOTH, 3.5, form="cylinder")
    for y in range(4, h - 13, 4):
        c.dot(w // 2 - 3, y, CLOTH.ramp[0])
    return out(c)


def cell_bones(w=24, h=14):
    c = canvas(w, h)
    bone_shape(c, 3, 10.5, 13, 9, 1)
    skull_shape(c, 16.5, 7.0, 2, scale=0.7)
    return out(c)


def cell_bowl(w=16, h=10):
    c = canvas(w, h)
    c.ellipse(8, 5.5, 7.4, 4.2, WOOD, 1)
    c.ellipse(8, 4.4, 5.2, 2.4, M("#4a3a33", tones=2), 2, form="flat", line=False)
    c.ellipse(8, 4.8, 3.8, 1.5, M("#7d7560", tones=2), 2.5, form="flat", line=False)
    return out(c)


def cell_bucket(w=20, h=22):
    c = canvas(w, h)
    body = c.poly([(2, 5), (w - 2, 5), (w - 3.5, h - 0.5), (3.5, h - 0.5)], WOOD, 1, form="cylinder")
    grain(c, body, WOOD, [6, 10, 14], 7, h - 2)
    for y in (8, h - 5):
        band(c, 2, w - 3, y, 1.5, 1, IRON, 2)
    lip = c.ellipse(w / 2, 5.0, 8.4, 3.4, WOOD_TOP, 3)
    lip.bias = 0.1
    c.ellipse(w / 2, 5.3, 6.2, 2.0, WATER, 3.5, form="flat", line=False)
    c.dot(int(w / 2) - 2, 4, GLINT)
    # The handle, a rope loop over the top.
    for i in range(13):
        a = math.pi * (1 + i / 12.0)
        c.dot(int(w / 2 + math.cos(a) * 8.5), int(4.5 + math.sin(a) * 4.5), ROPE.ramp[1])
    return out(c)


def cell_pallet(w=52, h=24):
    c = canvas(w, h)
    m = c.poly([(1, 3), (w - 3, 1), (w - 1, h - 4), (3, h - 1)], STRAW, 1, form="sphere")
    for i in range(46):
        x = 3 + (i * 19) % (w - 6)
        y = 3 + (i * 11) % (h - 6)
        if (x, y) in m.mask:
            c.dot(x, y, STRAW.ramp[0] if i % 2 else STRAW.ramp[2])
            if (x + 1, y) in m.mask and i % 3 == 0:
                c.dot(x + 1, y, STRAW.ramp[0])
    return out(c)


def cell_puddle(w=40, h=16):
    c = canvas(w, h)
    p = c.ellipse(w / 2, h / 2, w / 2 - 0.5, h / 2 - 1, WATER, 1, form="flat")
    c.ellipse(w / 2 + 6, h / 2 + 1, 7, 3, WATER, 1.2, form="flat", line=False).bias = -0.3
    for x in (12, 13, 14, 24, 25):
        c.dot(x, 5, (120, 132, 162))
    return out(c)


def cell_shackles(w=32, h=32):
    c = canvas(w, h)
    for x in (9, 22):
        c.ellipse(x, 2.5, 2.4, 2.4, IRON_DARK, 1)
        for y in range(5, 22, 3):
            c.ellipse(x + (0.5 if (y // 3) % 2 else -0.5), y + 1, 1.2, 1.8, IRON, 2)
        ring = c.ellipse(x, 26, 4.6, 4.4, IRON, 3)
        inner = {(px, py) for (px, py) in ring.mask if ((px + 0.5 - x) / 2.6) ** 2 + ((py + 0.5 - 26) / 2.4) ** 2 < 1}
        ring.mask -= inner
        c.dot(x - 2, 23, GLINT)
    return out(c)


def cell_straw(w=12, h=6):
    c = canvas(w, h)
    for (ax, ay, bx, by) in ((0.5, 4.5, 8, 2), (3, 5, 11.5, 4), (2, 2, 9, 4.5)):
        c.capsule(ax, ay, bx, by, 0.7, STRAW, 1, line=False)
    return out(c)


def cell_tally(w=36, h=14):
    """Days scratched into the wall: pale cuts, each with its shadow on its right."""
    c = canvas(w, h)
    cut, shade = (201, 188, 160), (92, 84, 102)
    def mark(x, y0, y1):
        for y in range(y0, y1 + 1):
            c.dot(x, y, cut)
            c.dot(x + 1, y, shade)
    for g in range(2):
        x0 = 1 + g * 15
        for i in range(4):
            mark(x0 + i * 3, 2 + (i % 2), 12 - (i % 2))
        for i in range(12):
            c.dot(x0 - 1 + i, 10 - (i * 7) // 12, cut)
            c.dot(x0 - 1 + i, 11 - (i * 7) // 12, shade)
    for i in range(2):
        mark(30 + i * 3, 3, 11)
    image = c.render()
    return image


def cell_window(w=16, h=24):
    c = canvas(w, h)
    c.box(0, 0, w - 1, h - 1, STONE_DARK, 1, form="cylinder")
    sky = c.box(3, 3, w - 4, h - 4, SKY, 2, form="flat")
    sky.bias = 0.2
    for x in (6, 9):
        c.box(x, 2, x, h - 3, IRON, 3)
    c.box(2, h // 2, w - 3, h // 2, IRON, 3)
    return out(c)


def cell_skeleton(w=44, h=34):
    """A prisoner's remains, slumped against the cell's wall where he sat: skull fallen to one
    shoulder, ribs, pelvis on the floor, legs out in front, one arm fallen to his side."""
    c = canvas(w, h)
    hole = (42, 36, 48)
    # Legs out to the right, the far one a little higher.
    bone_shape(c, 15, 23.5, 27, 21.5, 1, r=1.1)
    bone_shape(c, 27, 21.5, 38.5, 23, 1, r=1.0)
    bone_shape(c, 15, 27, 28, 27.5, 2, r=1.1)
    bone_shape(c, 28, 27.5, 40, 29.5, 2, r=1.0)
    # Pelvis and spine.
    c.ellipse(12.5, 25, 4.6, 3.4, BONE, 2.5)
    c.dot(12, 25, hole)
    c.dot(13, 25, hole)
    c.capsule(10.5, 12, 12, 23, 1.0, BONE, 2.2, line=False)
    # Ribs: a cage with dark gaps between the bones.
    cage = c.ellipse(11, 16.5, 5.6, 5.2, BONE, 3)
    for row in (13, 16, 19):
        for x in range(6, 17):
            if (x, row) in cage.mask and abs(x - 11) > 0:
                c.dot(x, row, hole if abs(x - 11) > 1 else BONE.ramp[0])
    # The near arm fallen to the floor at his side, its hand open.
    bone_shape(c, 15.5, 13, 18.5, 20, 3.5, r=0.9)
    bone_shape(c, 18.5, 20, 22.5, 25.5, 3.5, r=0.9)
    for fx in (23.5, 25, 26.5):
        c.capsule(22.5, 25.5, fx + 0.5, 27.5, 0.6, BONE, 3.6, line=False)
    # The skull, fallen onto his shoulder.
    skull_shape(c, 9.5, 7.5, 4, scale=0.85)
    return out(c)


def cell_ring(w=10, h=8):
    """A black ring lying on the floor: a near-black band seen from above, a glint on its top."""
    c = canvas(w, h)
    ring = c.ellipse(5, 4, 4.4, 3.2, M("#2a2731", tones=3, step=0.05, outline="#141219"), 1)
    inner = {(x, y) for (x, y) in ring.mask if ((x + 0.5 - 5) / 2.2) ** 2 + ((y + 0.5 - 4) / 1.3) ** 2 < 1}
    ring.mask -= inner
    c.dot(3, 1, GLINT)
    c.dot(4, 1, (150, 146, 168))
    return out(c)


# The strokes a scratched glyph is made of, on a 3x5 cell: uprights, bars, slants and hooks.
STROKES = [
    [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4)],
    [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4)], [(0, 0), (1, 0), (2, 0)], [(0, 2), (1, 2), (2, 2)],
    [(0, 4), (1, 4), (2, 4)], [(0, 0), (1, 1), (1, 2), (2, 3), (2, 4)], [(2, 0), (1, 1), (1, 2), (0, 3), (0, 4)],
    [(0, 1), (1, 0), (2, 1)], [(0, 3), (1, 4), (2, 3)], [(2, 2), (2, 3), (1, 4)],
]


def _glyph(seed):
    """A made-up letter: two or three strokes, picked by the seed, so it looks like writing that
    Almos cannot read at a glance."""
    n = 2 + seed % 2
    cells = set()
    k = seed * 7 + 3
    for s in range(n):
        k = (k * 1103515245 + 12345) & 0x7FFFFFFF
        # The first stroke spans the glyph's height (an upright or a slant), so every letter
        # stands as tall as the others.
        cells.update(STROKES[(0, 1, 2, 6, 7)[k % 5]] if s == 0 else STROKES[k % len(STROKES)])
    return cells


def cell_carving(w=50, h=15):
    """Writing cut into the wall in a shaky hand, letters of a script Almos does not read at a
    glance (what it says shows when he looks at it: the Carving's Inspect spot). Two lines with the
    shape of I SAW THE / SERPENT GOD. Pale cuts with their shadow on
    the right, as the tally marks are. It is on the wall above the skeleton in Cell 2."""
    from PIL import Image
    image = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cut, shade = (201, 188, 160, 255), (92, 84, 102, 255)
    marks = set()
    seed = 5
    for row, (words, x0, y0) in enumerate((((1, 3, 3), 2, 1), ((7, 3), 1, 8))):
        x = x0
        for word in words:
            for i in range(word):
                seed += 1
                low = (i * 5 + row + seed) % 3 == 0  # a shaky hand: some letters a pixel low
                for gx, gy in _glyph(seed):
                    marks.add((x + gx, y0 + gy + (1 if low else 0)))
                x += 4
            x += 3
    for (x, y) in marks:
        if 0 <= x + 1 < w and 0 <= y + 1 < h and (x + 1, y) not in marks:
            image.putpixel((x + 1, y), shade)
    for (x, y) in marks:
        if 0 <= x < w and 0 <= y < h:
            image.putpixel((x, y), cut)
    return image


PAPER = M("#c2b28f", tones=3, step=0.08)
INK = (40, 34, 44)
ROOT = M("#4a3f52", tones=4, step=0.08, lit_step=0.09)
DARK = M("#1c1820", tones=2, step=0.04)
CANDLE = M("#cdbf9c", tones=3, step=0.08)
PAPER_END = M("#8a7a5e", tones=2, step=0.05)


def desk(w=40, h=72):
    """Radio/Officers's desk, standing lengthwise against the east wall: seen in three-quarter view,
    its long plank top from above (north to south), its short south end face on, and its two front
    legs; the back legs are hidden under the top. On it, bark sheets with lines of writing, an ink
    pot, a stub of candle and the speaking-root, a dark root grown up through the north end that
    curls over into an open mouth toward the sitter. The node stands at the front legs' feet."""
    c = canvas(w, h)
    x0, x1 = 3, w - 6
    top_y, front_y = 14, h - 16
    for x in (x0 + 1, x1 - 2):
        c.box(x, front_y + 4, x + 2, h - 1, WOOD_OLD, 1, form="cylinder")
    top = c.box(x0, top_y, x1, front_y - 1, WOOD_TOP, 3, form="flat")
    top.bias = 0.1
    for x in range(x0 + 4, x1 - 1, 7):
        for y in range(top_y + 1, front_y - 1):
            if (y * 5 + x) % 11:
                c.dot(x, y, WOOD_TOP.ramp[0])
    c.box(x0, front_y, x1, front_y + 4, WOOD, 3.2, form="cylinder")
    # A drawer in the south end, with a pull.
    c.box(x0 + 8, front_y + 1, x1 - 8, front_y + 3, WOOD_OLD, 3.3, form="flat", line=False)
    c.dot((x0 + x1) // 2, front_y + 2, IRON.ramp[2])
    # Bark sheets, a little askew, where his head lies, and more stacked by the wall.
    c.box(x0 + 3, top_y + 24, x0 + 13, top_y + 33, PAPER, 4)
    c.box(x0 + 6, top_y + 27, x0 + 16, top_y + 37, PAPER, 4.2)
    for y in range(top_y + 29, top_y + 36, 2):
        for x in range(x0 + 8, x0 + 15):
            if (x + y) % 3:
                c.dot(x, y, PAPER.ramp[0])
    c.box(x1 - 9, top_y + 12, x1 - 2, top_y + 19, PAPER, 4)
    c.box(x1 - 9, top_y + 10, x1 - 2, top_y + 13, PAPER, 4.1)
    # The ink pot and a quill of root fibre.
    c.ellipse(x1 - 6, top_y + 26, 2.0, 1.8, DARK, 4)
    c.dot(x1 - 7, top_y + 25, GLINT)
    c.capsule(x1 - 6, top_y + 25, x1 - 2, top_y + 19, 0.5, CANDLE, 4.3, line=False)
    # A candle stub, unlit, in a clay dish.
    c.ellipse(x0 + 6, top_y + 44, 3.0, 1.6, CLAY, 4)
    c.box(x0 + 5, top_y + 39, x0 + 7, top_y + 43, CANDLE, 4.2, form="cylinder")
    c.dot(x0 + 6, top_y + 38, INK)
    # The speaking-root, rising from the north end and curling over toward the sitter.
    rx = x0 + 20
    c.capsule(rx, top_y + 6, rx + 1, top_y - 4, 2.4, ROOT, 4, r2=2.0)
    c.capsule(rx + 1, top_y - 4, rx - 2, top_y - 10, 2.0, ROOT, 4.2, r2=1.7)
    c.ellipse(rx - 6, top_y - 9, 3.6, 3.2, ROOT, 4.4)
    c.ellipse(rx - 6.8, top_y - 8.6, 2.0, 1.8, DARK, 4.6, form="flat", line=False)
    c.capsule(rx + 3, top_y + 7, rx + 7, top_y + 9, 0.9, ROOT, 3.5, line=False)
    c.capsule(rx - 3, top_y + 7, rx - 6, top_y + 10, 0.8, ROOT, 3.5, line=False)
    return out(c)


def stool(w=16, h=14):
    """A plain three-legged stool, the knight's, its round seat seen from above."""
    c = canvas(w, h)
    for x in (3, 7, 11):
        c.box(x, 5, x + 1, h - 1 - (1 if x == 7 else 0), WOOD_OLD, 1 if x != 7 else 0.5, form="cylinder")
    seat = c.ellipse(w / 2, 4, 6.6, 3.2, WOOD_TOP, 2, form="flat")
    seat.bias = 0.1
    c.box(2, 4, w - 3, 6, WOOD, 1.8, form="cylinder")
    return out(c)


BOOKS = [M(h, tones=3, step=0.07) for h in ("#5b4a6e", "#6e4a42", "#4a5a4c", "#7a6648", "#45506a", "#6b5a5f")]


def bookshelf(w=60, h=64, seed=0):
    """A tall bookshelf of dark wood stood against the north wall: its top from above, its open front
    with three shelves of bark-bound books in muted colours, leaning and lying, rolled scrolls, a
    jar and, on one, a small skull. The node stands at its feet."""
    import random
    rnd = random.Random(seed)
    c = canvas(w, h)
    frame = M("#5a4234", tones=4, step=0.07, lit_step=0.08)
    back = M("#2e2329", tones=2, step=0.04)
    c.box(2, 4, w - 3, h - 2, back, 0.5, form="flat", line=False)
    top = c.box(1, 0, w - 2, 4, WOOD_TOP, 3)
    top.bias = 0.1
    c.box(1, 5, 4, h - 1, frame, 3, form="cylinder")
    c.box(w - 5, 5, w - 2, h - 1, frame, 3, form="cylinder")
    shelves = [5 + i * 19 for i in range(4)]
    for y in shelves[1:]:
        c.box(4, y - 2, w - 6, y, frame, 2.9, form="cylinder")
    c.box(4, h - 3, w - 6, h - 1, frame, 2.9, form="cylinder")
    for k in range(3):
        floor = shelves[k + 1] - 3 if k < 2 else h - 4
        x = 6
        while x < w - 9:
            kind = rnd.random()
            if kind < 0.68:
                bw = rnd.choice((2, 3, 3, 4))
                bh = rnd.randint(10, 15)
                mat = rnd.choice(BOOKS)
                lean = rnd.random() < 0.12
                if lean:
                    c.capsule(x + 1, floor, x + 4, floor - bh + 1, bw / 2.0, mat, 2, line=True)
                    x += bw + 4
                else:
                    c.box(x, floor - bh + 1, x + bw - 1, floor, mat, 2, form="cylinder")
                    if bh > 11:
                        c.dot(x + bw // 2, floor - bh + 4, mat.ramp[2] if bw < 3 else PAPER.ramp[1])
                    x += bw
            elif kind < 0.8:
                # A pile of books lying flat.
                for j in range(rnd.randint(2, 3)):
                    c.box(x, floor - 2 * j - 1, x + 8, floor - 2 * j, rnd.choice(BOOKS), 2.2 + j * 0.1, form="flat")
                x += 10
            elif kind < 0.9:
                c.ellipse(x + 3, floor - 2, 2.6, 2.4, PAPER, 2)
                c.ellipse(x + 3, floor - 2, 1.0, 1.0, PAPER_END, 2.1, form="flat", line=False)
                x += 7
            elif seed % 2 == 0 and k == 0:
                skull_shape(c, x + 4, floor - 3, 2.4, scale=0.55)
                x += 9
            else:
                c.ellipse(x + 3, floor - 3, 2.6, 3.4, CLAY, 2)
                c.box(x + 2, floor - 7, x + 4, floor - 6, CLAY, 2.1)
                x += 8
            x += rnd.choice((0, 0, 1))
    return out(c)


def weapon_rack(w=60, h=60, taken=False):
    """A small armoury against the north wall: a rack of dark wood with two swords and a mace hung
    point down from its upper rail, two spears stood in its foot, and a round shield of bark and
    iron leaning against its front. Taken, the left sword is gone from its peg (Almos has it)."""
    c = canvas(w, h)
    blade = M("#9aa0b0", tones=3, step=0.11, shine=0.15, outline="#363442")
    grip = M("#3a2c25", tones=2, step=0.05)
    guard = M("#504a40", tones=2, step=0.06)
    for x in (4, w - 8):
        c.box(x, 6, x + 3, h - 1, WOOD_OLD, 1, form="cylinder")
    c.box(2, 6, w - 3, 9, WOOD, 3, form="cylinder")
    c.box(2, h - 12, w - 3, h - 9, WOOD, 3, form="cylinder")
    # Spears, stood upright behind the rails.
    for x in (12, 46):
        c.capsule(x, h - 2, x, 4, 0.9, WOOD_OLD, 1.5, line=True)
        c.poly([(x - 2, 6), (x, -0.5), (x + 2, 6), (x, 8)], IRON, 1.6)
    # Two swords hung by their crossguards from the upper rail, points down.
    for x in ((38,) if taken else (20, 38)):
        c.capsule(x, 12, x, h - 14, 1.6, blade, 2, r2=0.6)
        c.capsule(x - 3.5, 11, x + 3.5, 11, 1.0, guard, 3.4)
        c.capsule(x, 5, x, 10, 0.8, grip, 3.3)
        c.ellipse(x, 4, 1.3, 1.3, guard, 3.4)
        c.dot(x, 24, GLINT)
    if taken:
        # The empty peg it hung from.
        c.capsule(20, 9, 20, 12, 0.8, WOOD_OLD, 3.2)
    # A mace of root wood with an iron head.
    c.capsule(29, 8, 29, 32, 1.0, WOOD_OLD, 2.4)
    c.ellipse(29, 34, 3.4, 3.4, IRON, 2.5)
    for dx, dy in ((-3, 34), (3, 34), (0, 31), (0, 37)):
        c.dot(29 + dx, dy, IRON.ramp[0])
    # The shield, leaning against the rack's front at the right.
    shield = M("#5c4a3c", tones=4, step=0.075, lit_step=0.085)
    c.ellipse(w - 15, h - 13, 10, 11, shield, 5)
    c.ellipse(w - 15, h - 13, 10, 11, IRON, 4.9, clip=lambda x, y: (x + 0.5 - (w - 15)) ** 2 / 100 + (y + 0.5 - (h - 13)) ** 2 / 121 > 0.72)
    c.ellipse(w - 15.5, h - 13.5, 3.0, 3.0, IRON, 5.2)
    c.dot(w - 17, h - 15, GLINT)
    return out(c)


def armour_stand(w=26, h=54):
    """A spare suit on a stand of root wood: a helm like the knight's on top, a bark cuirass on its
    crosspiece, and an iron pauldron."""
    c = canvas(w, h)
    iron = M("#646a7a", tones=4, step=0.08, lit_step=0.1, shine=0.1, outline="#20212b")
    bark = M("#54463c", tones=4, step=0.075, lit_step=0.085)
    c.capsule(13, h - 3, 13, 10, 1.3, WOOD_OLD, 1)
    c.capsule(7, h - 2, 19, h - 2, 1.2, WOOD_OLD, 1.2)
    c.capsule(5, 19, 21, 19, 1.0, WOOD_OLD, 1.5)
    c.poly([(6, 18), (20, 18), (19, 30), (17, 38), (9, 38), (7, 30)], bark, 3, form="cylinder")
    for y in (24, 29, 34):
        for x in range(8, 19):
            c.dot(x, y, bark.ramp[0])
    c.ellipse(6.5, 19, 3.4, 3.0, iron, 3.5)
    c.ellipse(19.5, 19, 3.4, 3.0, iron, 3.5)
    c.ellipse(13, 9, 5.6, 6.2, iron, 4)
    for x in range(10, 17):
        c.dot(x, 9, (22, 22, 30))
    c.capsule(10, 3, 16, 3, 1.2, M("#4a4a36", tones=3, step=0.07), 4.2)
    c.dot(11, 6, GLINT)
    return out(c)


def scrolls(w=28, h=14):
    """Bark scrolls and a sheet dropped on the floor by the shelves."""
    c = canvas(w, h)
    c.capsule(3, 9, 16, 6, 2.2, PAPER, 2)
    c.ellipse(16, 6, 2.2, 2.2, PAPER, 2.2)
    c.ellipse(16, 6, 0.9, 0.9, PAPER_END, 2.3, form="flat", line=False)
    c.capsule(10, 11, 24, 11, 1.8, PAPER, 1.5)
    c.box(17, 2, 25, 7, PAPER, 1, form="flat")
    for x in range(19, 24):
        if x % 2:
            c.dot(x, 4, PAPER.ramp[0])
    return out(c)


def key_crate(w=32, h=34, open_=False):
    """The crate the Jailer's key is kept in, a single crate with an iron hasp on its front. Open,
    its lid stands against the back and its inside is dark and empty. Its foot is the bottom row."""
    c = canvas(w, h)
    x0, y0, cw, ch, top_h = 2, 8, w - 4, h - 8, 8
    if open_:
        lid = c.box(x0 + 1, 0, x0 + cw - 2, 9, WOOD_TOP, 0.5, form="flat")
        lid.bias = -0.05
        for x in range(x0 + 5, x0 + cw - 3, 6):
            for y in range(1, 9):
                c.dot(x, y, WOOD_TOP.ramp[0])
    front = crate(c, x0, y0, cw, ch, top_h, 1)
    if open_:
        c.box(x0 + 2, y0 + 1, x0 + cw - 3, y0 + top_h - 2, DARK, 1.5, form="flat", line=False)
        # The lid's grain is gone with the lid: nothing marks the dark inside.
        for x in range(x0 + 2, x0 + cw - 2):
            for y in range(y0 + 1, y0 + top_h - 1):
                c.details.pop((x, y), None)
    else:
        # The hasp: an iron plate on the lid's edge with a ring.
        c.box(x0 + cw // 2 - 2, y0 + top_h - 1, x0 + cw // 2 + 1, y0 + top_h + 3, IRON, 1.6)
        c.dot(x0 + cw // 2 - 1, y0 + top_h + 4, IRON.ramp[0])
        c.dot(x0 + cw // 2, y0 + top_h + 4, IRON.ramp[0])
    return out(c)


# A jailer's colours (scripts/art/draw_nar_jailer.py), for the one who fell on the bridge.
JAILER_HOOD = M("#4d5a4b", tones=4, step=0.07, lit_step=0.09, shine=0.05)
JAILER_JERKIN = M("#5c483c", tones=3, step=0.07)
JAILER_BOOT = M("#2f2420", tones=2, step=0.05)
SWORD_BLADE = M("#a3a8b8", tones=3, step=0.11, shine=0.15, outline="#3a3848")
SWORD_GUARD = M("#4a4652", tones=2, step=0.06)
SWORD_GRIP = M("#3f2f28", tones=2, step=0.05)


def fallen_jailer(w=48, h=26):
    """A jailer who fell where the bridge narrows below the barrels and was left there: his bones
    lying on their back along the floor in his torn moss-grey hood and mantle, a rotten leather
    jerkin over the ribs, his boots still on, one arm flung out to where his sword fell."""
    c = canvas(w, h)
    hole = (42, 36, 48)
    # The mantle spread under him, torn at its hem.
    c.poly([(5, 8), (21, 5), (30, 9), (31, 19), (20, 22), (7, 20), (3, 14)], JAILER_HOOD, 0.5)
    for x in (8, 12, 17, 24):
        c.dot(x, 21 if x % 2 else 20, hole)
    # Legs out to the right, boots on.
    bone_shape(c, 27, 12, 37, 10.5, 1, r=1.1)
    bone_shape(c, 27, 16, 37, 17.5, 1.2, r=1.1)
    c.box(37, 8, 42, 12, JAILER_BOOT, 1.5, form="cylinder")
    c.box(37, 15, 42, 19, JAILER_BOOT, 1.6, form="cylinder")
    # Pelvis, and the rotten jerkin over the ribs.
    c.ellipse(26, 14, 2.6, 2.4, BONE, 2)
    c.dot(26, 14, hole)
    c.ellipse(17, 13.5, 6.4, 5.4, JAILER_JERKIN, 2.5)
    for row in (11, 14, 17):
        for x in range(13, 22, 2):
            c.dot(x, row, BONE.ramp[1] if x % 4 == 1 else hole)
    # The near arm flung up and out, its hand open, toward the sword (which lies on its own).
    bone_shape(c, 14, 8, 12, 2.5, 3, r=0.9)
    for fx in (9.5, 11.5, 13.5):
        c.capsule(12, 2.5, fx, 0.8, 0.5, BONE, 3.1, line=False)
    # The far arm along his side.
    bone_shape(c, 15, 18.5, 23, 20.5, 3, r=0.9)
    # The skull in the hood, tipped back, the hood's dark inside around it.
    c.ellipse(7, 13.5, 5.0, 5.6, JAILER_HOOD, 3)
    c.ellipse(7.5, 13.0, 3.6, 4.0, M("#262b26", tones=2, step=0.05), 3.2, line=False)
    skull_shape(c, 7.5, 11.5, 3.5, scale=0.55)
    return out(c)


def sword_floor(w=32, h=10):
    """The fallen jailer's sword lying on the floor: a straight blade of grey iron pointing right,
    a crossguard, a wrapped grip and a pommel, a glint along its lit flat."""
    c = canvas(w, h)
    c.capsule(9, 5, 29, 4.5, 1.8, SWORD_BLADE, 1, r2=0.7)
    c.capsule(8, 0.8, 8, 9.2, 1.2, SWORD_GUARD, 2)
    c.capsule(3, 5, 7, 5, 0.9, SWORD_GRIP, 1.5)
    c.ellipse(2, 5, 1.4, 1.4, SWORD_GUARD, 2)
    c.dot(16, 4, GLINT)
    c.dot(17, 4, GLINT)
    return out(c)


def greatsword_floor(w=48, h=14):
    """A greatsword left lying among the stores: a long, broad blade of grey iron pointing right
    with a fuller down its middle, a wide crossguard, a long two-handed grip bound in leather and a
    heavy pommel, a glint along its lit flat."""
    c = canvas(w, h)
    c.capsule(14, 7, 45, 6.5, 2.6, SWORD_BLADE, 1, r2=0.9)
    for x in range(16, 38):
        c.dot(x, 7, SWORD_BLADE.ramp[0])
    c.capsule(13, 1, 13, 13, 1.4, SWORD_GUARD, 2)
    c.capsule(4, 7, 12, 7, 1.1, SWORD_GRIP, 1.5)
    for x in (6, 9):
        c.dot(x, 7, SWORD_GRIP.ramp[0])
    c.ellipse(2.5, 7, 2.0, 2.0, SWORD_GUARD, 2)
    for x in (22, 23, 24):
        c.dot(x, 5, GLINT)
    return out(c)


def door_frame(w=44, h=104):
    """The doorway to Radio/Officers in the hall's short west wall, seen from above. Its opening is
    two tiles (64 px) from row 12 of the picture to row 76: under the wall the passage runs on into
    the dark, its floor sunk in shadow; an oak frame stands round it, a heavy lintel beam laid across
    the wall's top over its north end and a sill beam at its south end, each capped by a squared post
    at the hall side; the door itself, iron-banded, stands swung open back against the wall's foot
    below it. The lantern hung beside it (scenes/world/lamp_side.tscn) gives it its light."""
    c = canvas(w, h)
    shadow = M("#1f1b26", tones=2, step=0.04, outline="#141019")
    # The passage under the wall, running on into the dark.
    c.box(0, 12, 24, 76, shadow, 0.5)
    # The lintel and the sill: beams across the wall's top, their ends set in the wall.
    c.box(0, 2, 26, 12, WOOD, 4, form="cylinder")
    c.box(0, 76, 26, 85, WOOD, 4, form="cylinder")
    for y in (6, 80):
        for x in range(3, 24, 6):
            c.dot(x, y, WOOD.ramp[0])
    # The jambs, squared posts at the hall side of each beam, their tops seen from above.
    c.box(22, 0, 32, 14, WOOD_OLD, 4.5, form="cylinder")
    c.box(22, 74, 32, 88, WOOD_OLD, 4.5, form="cylinder")
    # The door leaf, swung open and lying back along the wall's foot below the doorway, banded in iron.
    c.box(33, 86, 41, 103, WOOD_OLD, 3, form="cylinder")
    for y in (89, 99):
        c.box(33, y, 41, y + 1, IRON_DARK, 3.2)
    c.dot(39, 94, GLINT)
    return out(c)


def stair_flight(w=64, h=96):
    """A flight of steps cut into the chasm's root and packed earth, seen from above, two tiles wide
    and three long: eight treads, each lit along its top edge from the top left and dropping to a dark
    riser below it, between two low kerbs of root. Which way it climbs is left for the eye to guess."""
    c = canvas(w, h)
    earth = M("#6a5a62", tones=4, step=0.07, lit_step=0.08)
    riser = M("#3a3140", tones=2, step=0.04, outline="#241f2c")
    root = M("#4d3f48", tones=3, step=0.06)
    step = h // 8
    for i in range(8):
        y = i * step
        c.box(4, y, w - 5, y + step - 4, earth, 2, form="cylinder")
        c.box(4, y + step - 4, w - 5, y + step - 1, riser, 1.5)
        for x in range(9 + (i * 7) % 11, w - 8, 17):
            c.dot(x, y + 3, earth.ramp[0])
    c.box(0, 0, 4, h - 1, root, 3, form="cylinder")
    c.box(w - 5, 0, w - 1, h - 1, root, 3, form="cylinder")
    return out(c)


def locked_door(w=32, h=96):
    """The doorway of Corridor 2's locked east door, seen from above, without its leaf: its opening is
    two tiles (64 px), from row 16 of the picture to row 80. An oak lintel and sill lie across the wall's
    top at its ends, and between them the passage runs on under the wall into the dark. The leaf is
    its own picture (locked_door_leaf), so it can swing open."""
    c = canvas(w, h)
    shadow = M("#1f1b26", tones=2, step=0.04, outline="#141019")
    c.box(0, 16, w - 1, 80, shadow, 0.5)
    c.box(0, 4, w - 1, 16, WOOD, 4, form="cylinder")
    c.box(0, 80, w - 1, 92, WOOD, 4, form="cylinder")
    return out(c)


def locked_door_leaf(w=20, h=64):
    """The locked door's leaf, seen from above as it stands shut in the doorway: its planks banded in
    iron, an iron lock plate on its hall side (the west), where the Jailer's key goes. Its hinge is at
    its top left corner, so it swings open into the hall about it."""
    c = canvas(w, h)
    c.box(0, 0, w - 1, h - 1, WOOD_OLD, 3, form="cylinder")
    for y in range(6, h - 2, 8):
        c.dot(2, y, WOOD_OLD.ramp[0])
        c.dot(16, y + 3, WOOD_OLD.ramp[0])
    for y in (10, 54):
        c.box(0, y, w - 1, y + 2, IRON_DARK, 3.2)
    c.box(0, 26, 5, 38, IRON, 3.5)
    c.dot(2, 32, IRON_DARK.ramp[0])
    c.dot(1, 28, GLINT)
    return out(c)


PICTURES = {
    "dungeons/furniture/barrel.png": barrel,
    "dungeons/furniture/stair_flight.png": stair_flight,
    "dungeons/furniture/locked_door.png": locked_door,
    "dungeons/furniture/locked_door_leaf.png": locked_door_leaf,
    "dungeons/furniture/bench.png": bench,
    "dungeons/furniture/crate_stack.png": crate_stack,
    "dungeons/furniture/sacks.png": sacks,
    "dungeons/furniture/spear_rack.png": spear_rack,
    "dungeons/furniture/wardrobe.png": wardrobe,
    "dungeons/furniture/desk.png": desk,
    "dungeons/furniture/stool.png": stool,
    "dungeons/furniture/bookshelf_0.png": lambda: bookshelf(seed=2),
    "dungeons/furniture/bookshelf_1.png": lambda: bookshelf(seed=7),
    "dungeons/furniture/weapon_rack.png": weapon_rack,
    "dungeons/furniture/weapon_rack_taken.png": lambda: weapon_rack(taken=True),
    "dungeons/furniture/armour_stand.png": armour_stand,
    "dungeons/furniture/scrolls.png": scrolls,
    "dungeons/furniture/key_crate.png": key_crate,
    "dungeons/furniture/key_crate_open.png": lambda: key_crate(open_=True),
    "dungeons/pots/clay_pot.png": clay_pot,
    "dungeons/bones/bone.png": bone,
    "dungeons/bones/bone_pile.png": bone_pile,
    "dungeons/bones/skull.png": skull,
    "dungeons/rocks/rock_big.png": lambda: rock(52, 40, 2, moss=True),
    "dungeons/rocks/rock_small_0.png": lambda: rock(16, 14, 0),
    "dungeons/rocks/rock_small_1.png": lambda: rock(16, 14, 3, mat=STONE_DARK),
    "dungeons/rocks/rock_small_2.png": lambda: rock(16, 14, 5),
    "dungeons/cells/cell_bars_64.png": lambda: cell_bars(128),
    "dungeons/cells/cell_bars_80.png": lambda: cell_bars(160),
    "dungeons/cells/cell_bars_96.png": lambda: cell_bars(192),
    "dungeons/cells/cell_bed.png": cell_bed,
    "dungeons/cells/cell_bones.png": cell_bones,
    "dungeons/cells/cell_bowl.png": cell_bowl,
    "dungeons/cells/cell_bucket.png": cell_bucket,
    "dungeons/cells/cell_pallet.png": cell_pallet,
    "dungeons/cells/cell_puddle.png": cell_puddle,
    "dungeons/cells/cell_shackles.png": cell_shackles,
    "dungeons/cells/cell_straw.png": cell_straw,
    "dungeons/cells/cell_tally.png": cell_tally,
    "dungeons/cells/cell_window.png": cell_window,
    "dungeons/cells/cell_skeleton.png": cell_skeleton,
    "dungeons/cells/cell_ring.png": cell_ring,
    "dungeons/cells/cell_carving.png": cell_carving,
    "dungeons/bones/fallen_jailer.png": fallen_jailer,
    "dungeons/furniture/sword_floor.png": sword_floor,
    "dungeons/furniture/greatsword_floor.png": greatsword_floor,
    "dungeons/furniture/door_frame.png": door_frame,
}


def main():
    args = list(sys.argv[1:])
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    root = args[0] if args else "assets"
    images = []
    for path, draw in PICTURES.items():
        image = draw()
        images.append(image)
        if root != "-":
            pk.save(image, os.path.join(root, path))
    if sheet:
        pk.sheet(images, zoom=4, cols=7).save(sheet)


if __name__ == "__main__":
    main()
