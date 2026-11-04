"""Draws the Dungeons' tile atlas at 32 px: assets/shared/dungeon_tiles/dungeon_tiles.png.

    python3 scripts/art/draw_tiles.py [OUT.png] [--sheet SHEET.png]

The atlas keeps its layout (TileSet dungeon_tiles.tres, 32x32 tiles):

    row 0: floor 0-3 (packed earth, four variants), 4 the floor's strip at the south wall,
           5 root mass (the solid root round the rooms)
    row 1: 0 north face top (a sand lip), 1 north face base (its foot in shadow), 2 left side,
           3 right side, 4 south wall top (seen from above, darker), 5 south wall strip
    row 2: 0 deep root (near black), 1 the blend from root mass to deep root (a dither)

Each tile keeps the transparency of the one it replaces (the strips are only partly drawn). The
floor variants share their edges, so any variant can lie next to any other without a seam. Light is
from the top left; the shading leans cool in the dark and warm in the light, as in pixelkit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402
from PIL import Image  # noqa: E402

T = 32
ATLAS = "assets/shared/dungeon_tiles/dungeon_tiles.png"

EARTH = pk.Material("#5e5260", tones=4, step=0.045, lit_step=0.05)
PEBBLE = pk.Material("#7a6e76", tones=3, step=0.07)
ROOTLET = pk.hexrgb("#43394a")
BARK = pk.Material("#584c73", tones=4, step=0.06, lit_step=0.07)
BARK_DARK = pk.Material("#3b3858", tones=3, step=0.05)
STAKE = pk.Material("#2f2d4c", tones=2, step=0.04)
LIP = pk.Material("#cdb38e", tones=3, step=0.07)
ROOT = pk.Material("#2c2b4a", tones=3, step=0.035)
DEEP = (16, 14, 24)
GLOW = pk.hexrgb("#c9e06b")


def _hash(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def _noise(x, y, period, cell, seed):
    """Smooth value noise that repeats every `period` pixels."""
    n = period // cell
    gx, gy = x / cell, y / cell
    x0, y0 = int(math.floor(gx)), int(math.floor(gy))
    fx, fy = gx - x0, gy - y0
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

    def v(i, j):
        return _hash(i % n, j % n, seed)

    a = v(x0, y0) + (v(x0 + 1, y0) - v(x0, y0)) * sx
    b = v(x0, y0 + 1) + (v(x0 + 1, y0 + 1) - v(x0, y0 + 1)) * sx
    return a + (b - a) * sy


def _clean(grid, w, h, wrap=True, passes=2):
    """Each pixel whose four neighbours mostly share another value takes it: no stray pixels."""
    for _ in range(passes):
        new = [row[:] for row in grid]
        for y in range(h):
            for x in range(w):
                ns = []
                for ox, oy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    qx, qy = x + ox, y + oy
                    if wrap:
                        qx, qy = qx % w, qy % h
                    elif not (0 <= qx < w and 0 <= qy < h):
                        continue
                    ns.append(grid[qy][qx])
                v = grid[y][x]
                if ns and v not in ns:
                    best = max(set(ns), key=ns.count)
                    if ns.count(best) >= 3:
                        new[y][x] = best
        grid = new
    return grid


# --- floor -----------------------------------------------------------------------------------

def floor(variant):
    # The shared part repeats every tile; the variant's own part fades out toward the edges.
    tone = [[0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            base = 0.6 * _noise(x, y, T, 8, 11) + 0.4 * _noise(x, y, T, 4, 12)
            edge = min(x, y, T - 1 - x, T - 1 - y)
            wv = min(1.0, max(0.0, (edge - 2) / 6.0))
            own = 0.6 * _noise(x, y, T, 8, 20 + variant) + 0.4 * _noise(x, y, T, 4, 30 + variant)
            v = base * (1 - wv * 0.7) + own * wv * 0.7
            # Packed earth: mostly the middle tones, darker hollows, a few worn light patches.
            tone[y][x] = 0 if v < 0.3 else (1 if v < 0.5 else (2 if v < 0.72 else 3))
    tone = _clean(tone, T, T)
    image = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            image.putpixel((x, y), EARTH.ramp[tone[y][x]] + (255,))
    # Pebbles and rootlets inside the tile (never on the shared edges).
    rnd = lambda k: _hash(k, variant, 77)
    for k in range(2 + variant % 2):
        px = 5 + int(rnd(k) * 20)
        py = 5 + int(rnd(k + 10) * 20)
        big = rnd(k + 20) > 0.5
        cells = [(0, 0), (1, 0), (0, 1), (1, 1)] + ([(2, 0), (2, 1), (1, 2)] if big else [])
        for ox, oy in cells:
            image.putpixel((px + ox, py + oy), PEBBLE.ramp[1] + (255,))
        image.putpixel((px, py), PEBBLE.ramp[2] + (255,))
        for ox, oy in cells:
            if (ox + 1, oy) not in cells and (ox, oy + 1) not in cells:
                image.putpixel((px + ox, py + oy), PEBBLE.ramp[0] + (255,))
        # Its shadow on the earth, down and right.
        sx, sy = px + max(o[0] for o in cells) + 1, py + max(o[1] for o in cells)
        image.putpixel((sx, sy), EARTH.ramp[0] + (255,))
    if variant in (1, 3):
        x, y = 6 + variant * 2, 22 - variant
        for i in range(9):
            image.putpixel((x + i, y + int(1.5 * math.sin(i * 0.8))), ROOTLET + (255,))
    return image


# --- walls -----------------------------------------------------------------------------------

def weave(dark=False, glow=False, seed=0):
    """Woven bark: strips of bark woven over and under upright stakes. Each strip waves, rising
    over one stake (lit, nearer) and dipping under the next (in shadow, the stake showing over it),
    the rows in turn, so the weave reads. Lit from the top left; repeats every 32 pixels."""
    mat = BARK_DARK if dark else BARK
    stake = STAKE if dark else BARK_DARK
    image = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            best = None
            for r in range(-1, 5):
                p = math.pi * (x + 0.5) / 16.0 + r * math.pi
                centre = r * 8 + 4 + 1.3 * math.sin(p)
                d = (y + 0.5) - centre
                if best is None or abs(d) < abs(best[0]):
                    best = (d, math.sin(p), r)
            d, over, r = best
            # The stakes stand at x 8 and 24; one shows where the strip passes under it.
            sx = (x - 8) % 16
            on_stake = sx in (15, 0, 1)
            if on_stake and over < -0.6:
                colour = stake.ramp[min(len(stake.ramp) - 1, 2 if sx == 15 else (1 if sx == 0 else 0))]
            elif abs(d) > 3.2:
                colour = STAKE.ramp[0]
            else:
                lit = 0.55 - d * 0.16 + over * 0.28
                tone = 3 if lit > 0.78 else (2 if lit > 0.5 else (1 if lit > 0.22 else 0))
                colour = mat.ramp[min(tone, len(mat.ramp) - 1)]
            image.putpixel((x, y), colour + (255,))
    if glow:
        for i, (gx, gy) in enumerate(((19, 10), (20, 10), (21, 11))):
            image.putpixel((gx + seed, gy), (GLOW if i == 1 else pk.shift(GLOW, -0.25)) + (255,))
    return image


def north_top():
    image = weave(glow=False)
    for y in range(8):
        for x in range(T):
            t = 2 if y < 2 else (1 if y < 6 else 0)
            colour = LIP.ramp[t]
            if y == 0 and x % 11 == 3:
                colour = LIP.ramp[1]
            if y == 7:
                colour = STAKE.ramp[0]
            image.putpixel((x, y), colour + (255,))
    return image


def north_base():
    image = weave()
    for y in range(T - 4, T):
        for x in range(T):
            under = image.getpixel((x, y))[:3]
            k = (y - (T - 4) + 1) / 5.0
            image.putpixel((x, y), tuple(round(a * (1 - k) + b * k) for a, b in zip(under, STAKE.ramp[0])) + (255,))
    return image


def side(edge_right):
    image = weave(dark=False)
    for y in range(T):
        for i in range(4):
            x = T - 1 - i if edge_right else i
            image.putpixel((x, y), (STAKE.ramp[0] if i < 2 else BARK.ramp[0]) + (255,))
        # The lit rim of the wall's top, on the side away from its shadowed edge.
        x = 0 if edge_right else T - 1
        image.putpixel((x, y), BARK.ramp[3] + (255,))
    return image


def south_top():
    return weave(dark=True)


# --- root ------------------------------------------------------------------------------------

def root_mass(seed=0):
    """Solid root: dark fibres running across, veins between them in the deepest tone."""
    tone = [[0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            fibre = _noise(x, y * 3, T, 8, 40 + seed) * 0.6 + _noise(x, y, T, 4, 41 + seed) * 0.4
            tone[y][x] = 0 if fibre < 0.32 else (1 if fibre < 0.62 else 2)
    tone = _clean(tone, T, T)
    image = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            image.putpixel((x, y), ROOT.ramp[tone[y][x]] + (255,))
    for x, y in ((9, 7), (23, 21)):
        image.putpixel((x, y), pk.shift(ROOT.ramp[2], 0.12) + (255,))
    return image


def deep_root():
    image = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            v = _noise(x, y * 2, T, 8, 50)
            image.putpixel((x, y), (DEEP if v < 0.6 else (24, 22, 34)) + (255,))
    return image


def blend():
    mass = root_mass()
    image = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            image.putpixel((x, y), mass.getpixel((x, y)) if (x + y) % 2 == 0 else DEEP + (255,))
    return image


def atlas(old):
    tiles = {
        (0, 0): floor(0), (1, 0): floor(1), (2, 0): floor(2), (3, 0): floor(3), (4, 0): floor(1),
        (5, 0): root_mass(),
        (0, 1): north_top(), (1, 1): north_base(), (2, 1): side(True), (3, 1): side(False),
        (4, 1): south_top(), (5, 1): south_top(),
        (0, 2): deep_root(), (1, 2): blend(),
    }
    image = Image.new("RGBA", old.size, (0, 0, 0, 0))
    for (tx, ty), tile in tiles.items():
        for y in range(T):
            for x in range(T):
                a = old.getpixel((tx * T + x, ty * T + y))[3]
                if a > 0:
                    image.putpixel((tx * T + x, ty * T + y), tile.getpixel((x, y))[:3] + (a,))
    return image


def main():
    args = list(sys.argv[1:])
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    path = args[0] if args else ATLAS
    old = Image.open(ATLAS).convert("RGBA")
    image = atlas(old)
    if path != "-":
        pk.save(image, path)
    if sheet:
        # The atlas, and a patch of floor and wall laid as a Room lays them, to look for seams.
        patch = Image.new("RGBA", (T * 8, T * 6))
        for ty in range(6):
            for tx in range(8):
                if ty == 0:
                    src = (0, 1)
                elif ty == 1:
                    src = (1, 1)
                else:
                    src = ((tx * 3 + ty) % 4, 0)
                patch.paste(image.crop((src[0] * T, src[1] * T, src[0] * T + T, src[1] * T + T)), (tx * T, ty * T))
        pk.sheet([image, patch], zoom=3, cols=2).save(sheet)


if __name__ == "__main__":
    main()
