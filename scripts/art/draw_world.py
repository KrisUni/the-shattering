"""Draws the Dungeons' lamps, the metal gate, and the moss and fungus at 32 px.

    python3 scripts/art/draw_world.py [ASSETS_DIR] [--sheet SHEET.png]

- assets/shared/lamp/lamp_wall.png (24x32): an iron lantern hanging from a short chain
- assets/shared/lamp/lamp_standing.png (24x56): the same lantern on a stem and foot
- assets/shared/lamp/lamp_lit_0-3.png (24x32): the glass lit from within, four flickers; laid over
  either lantern, whose glass is in the same place (x 4-19, y 14-23)
- assets/dungeons/gates/metal_gate.png (128x56): iron bars between a top rail and a cross rail
- assets/dungeons/growth/: floor moss (moss_0-2), moss hanging from a wall (moss_hanging), and
  small glowing fungus (fungus_0-1) in the arch-tree glow

Every picture keeps the canvas of the one it replaces. Drawn with pixelkit.py.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

M = pk.Material
IRON = M("#4c5066", tones=4, step=0.07, lit_step=0.09, shine=0.05)
IRON_DARK = M("#363849", tones=3, step=0.05)
GLASS = M("#2f3450", tones=2, step=0.05)
RUST = (122, 84, 64)
GLINT = (214, 212, 230)
MOSS = M("#56653f", tones=3, step=0.065)
MOSS_DRY = M("#5d5f45", tones=3, step=0.06)
STEM = M("#8c8a6e", tones=2, step=0.08)
GLOW = M("#c9e06b", tones=3, step=0.1, outline="#3b4a2a")

# The lit glass, from its rim to its heart, warm.
LIT = [(176, 92, 40), (236, 150, 60), (248, 196, 112), (252, 236, 200)]


def out(c):
    return pk.remove_orphans(c.render())


def lantern(c, top):
    """The lantern's body: a cap, a glass globe with three iron ribs, a foot. Its glass is at
    x 4-19, y 14-23 when top is 8."""
    oy = top - 8
    c.poly([(9, 8 + oy), (15, 8 + oy), (18, 12 + oy), (6, 12 + oy)], IRON, 3, form="sphere")
    c.ellipse(12, 7.5 + oy, 1.6, 1.4, IRON, 3.2)
    glass = c.ellipse(12, 19 + oy, 8.4, 5.6, GLASS, 2, form="flat")
    glass.bias = 0.1
    for x in (8, 12, 16):
        c.box(x - (1 if x == 12 else 0), 13 + oy, x, 24 + oy, IRON, 3, form="cylinder")
    c.box(5, 13 + oy, 18, 13 + oy, IRON, 3.1, form="cylinder")
    c.poly([(6, 24 + oy), (18, 24 + oy), (15, 28 + oy), (9, 28 + oy)], IRON, 3, form="sphere")
    c.dot(6, 17 + oy, GLINT)
    c.dot(6, 18 + oy, GLINT)


def lamp_wall():
    c = pk.Canvas(24, 32)
    for y in range(0, 8, 2):
        c.ellipse(12 + (0.5 if (y // 2) % 2 else -0.5), y + 1, 1.1, 1.4, IRON_DARK, 1)
    lantern(c, 8)
    c.ellipse(12, 29.8, 1.4, 1.6, IRON, 3.3)
    return out(c)


def lamp_standing():
    c = pk.Canvas(24, 56)
    lantern(c, 8)
    c.capsule(12, 28, 12, 51, 1.4, IRON, 2)
    c.capsule(9.5, 40, 14.5, 40, 1.1, IRON, 2.2)
    c.poly([(4, 55.5), (20, 55.5), (16, 51), (8, 51)], IRON, 2.5, form="sphere")
    return out(c)


def lamp_lit(frame):
    """The glass glowing, its heart drifting a little with the flicker, the ribs dark over it."""
    from PIL import Image
    image = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    hx = 11.5 + (0.0, 0.8, 0.3, -0.6)[frame]
    hy = 19.5 + (0.0, -0.4, 0.6, 0.2)[frame]
    strength = (1.0, 0.92, 1.05, 0.96)[frame]
    for y in range(14, 24):
        for x in range(4, 20):
            u = (x + 0.5 - 12) / 8.4
            v = (y + 0.5 - 19) / 5.6
            if u * u + v * v > 1.0:
                continue
            d = math.hypot((x + 0.5 - hx) / 7.5, (y + 0.5 - hy) / 4.8) / strength
            band = 3 if d < 0.38 else (2 if d < 0.7 else (1 if d < 0.95 else 0))
            colour = LIT[band]
            if x in (8, 11, 12, 16) or y == 13:
                colour = (58, 52, 64) if band < 2 else (96, 72, 62)
            image.putpixel((x, y), colour + (255,))
    return image


def metal_gate(w=128, h=56):
    c = pk.Canvas(w, h)
    for x in range(10, w - 10, 11):
        c.box(x, 5, x + 3, h - 1, IRON, 2, form="cylinder")
        # A point where each bar meets the top rail.
        c.dot(x + 1, 6, IRON.ramp[3])
    for x0 in (0, w - 8):
        c.box(x0, 0, x0 + 7, h - 1, IRON_DARK, 3, form="cylinder")
    c.box(0, 0, w - 1, 5, IRON, 3.5, form="cylinder")
    c.box(4, 28, w - 5, 32, IRON, 3.4, form="cylinder")
    for x in list(range(11, w - 10, 11)):
        for y in (2, 30):
            c.dot(x + 1, y, IRON.ramp[0])
            c.dot(x + 1, y - 1, GLINT)
    bars = list(range(10, w - 10, 11))
    for i, (b, y) in enumerate(((1, 14), (3, 44), (5, 20), (7, 38), (9, 12), (2, 36), (8, 50))):
        x = bars[b] + 2
        c.dot(x, y, RUST)
        if i % 2 == 0:
            c.dot(x, y + 1, RUST)
    return out(c)


def moss(w, h, seed, mat=MOSS):
    """A low cushion of moss: lumps lit on their tops, a few tufts and a dry patch."""
    c = pk.Canvas(w, h)
    n = max(3, w // 5)
    for i in range(n):
        t = (i + 0.5) / n
        x = 1 + t * (w - 2) + math.sin(i * 2.3 + seed) * 1.0
        # Bigger lumps in the middle, low ones at the ends, all touching.
        mid = math.sin(t * math.pi)
        rx = 2.6 + 2.6 * mid + 0.6 * math.sin(i * 1.7 + seed * 3)
        ry = min(rx * 0.62, h / 2.0 - 0.8)
        y = h - 1.0 - ry - abs(math.sin(i * 1.1 + seed)) * 1.2
        c.ellipse(x, y, rx, ry, mat if i % 4 else MOSS_DRY, 1 + (i % 2) * 0.6)
    for i in range(n // 2):
        x = int(4 + (i * 7 + seed * 5) % (w - 8))
        c.dot(x, 1 + (i % 2), MOSS.ramp[2])
    return out(c)


def moss_hanging(w=28, h=28):
    c = pk.Canvas(w, h)
    c.capsule(2, 1.5, w - 3, 1.5, 1.6, MOSS, 2)
    for i, (x, length) in enumerate(((4, 16), (8, 22), (12, 13), (16, 25), (20, 18), (24, 11))):
        sway = math.sin(i * 1.9) * 1.5
        c.capsule(x, 2, x + sway, length, 1.3, MOSS if i % 2 else MOSS_DRY, 1, r2=0.7)
    return out(c)


def fungus(w, h, caps):
    """Small fungus caps in the arch tree's glow, on pale stems."""
    c = pk.Canvas(w, h)
    for (x, y, r) in caps:
        c.capsule(x, y + 0.5, x, h - 1, 0.9, STEM, 1)
        cap = c.ellipse(x, y, r, r * 0.65, GLOW, 2, clip=lambda px, py, yy=y: py <= yy + 0.6)
        cap.bias = 0.05
    return out(c)


PICTURES = {
    "shared/lamp/lamp_wall.png": lamp_wall,
    "shared/lamp/lamp_standing.png": lamp_standing,
    "shared/lamp/lamp_lit_0.png": lambda: lamp_lit(0),
    "shared/lamp/lamp_lit_1.png": lambda: lamp_lit(1),
    "shared/lamp/lamp_lit_2.png": lambda: lamp_lit(2),
    "shared/lamp/lamp_lit_3.png": lambda: lamp_lit(3),
    "dungeons/gates/metal_gate.png": metal_gate,
    "dungeons/growth/moss_0.png": lambda: moss(32, 14, 1),
    "dungeons/growth/moss_1.png": lambda: moss(48, 18, 2),
    "dungeons/growth/moss_2.png": lambda: moss(22, 10, 3, mat=MOSS_DRY),
    "dungeons/growth/moss_hanging.png": moss_hanging,
    "dungeons/growth/fungus_0.png": lambda: fungus(24, 12, [(6, 5, 3.6), (13, 3.5, 4.4), (19.5, 6.5, 2.8)]),
    "dungeons/growth/fungus_1.png": lambda: fungus(16, 10, [(5.5, 4, 3.6), (11.5, 5.5, 2.8)]),
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
        lit = images[0].copy()
        lit.alpha_composite(images[2])
        pk.sheet(images[:2] + [lit] + images[7:], zoom=5, cols=6).save(sheet)
        pk.sheet([images[6]], zoom=4).save(sheet.replace(".png", "_gate.png"))


if __name__ == "__main__":
    main()
