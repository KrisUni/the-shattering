"""Draws the game's flames, original pixel art for this game:

- assets/shared/fire/flame_0-14.png: Fire, the flame that stands on anything burning (40x64,
  15 frames, a seamless loop at 12 a second), tall and restless, tongues breaking off its top and a
  wisp of violet smoke above;
- assets/shared/torch/flame_0-4.png: a torch's small, steadier flame (32x48, 5 frames at 8 a second);
- assets/shared/torch/torch.png: the torch's bracket, a bowl on a wrapped pole (20x74).

Drawn at 32 px: one art pixel is one world unit. The shapes are made at the first drawing's size and
scaled (`scale`), so the flame keeps its rhythm while its bands, tongues and smoke get the detail.

Each flame is a teardrop whose sides sway with slow, looping waves, filled in hard bands from a deep
amber rim to a cream core (no anti-aliasing: every pixel is one of the band colours). The waves turn
a whole number of times over the loop, so the last frame runs into the first.

    python3 scripts/art/draw_fire.py [OUT_ROOT]
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

# Rim to core. Fire amber (#f29a2e) is the body; nothing comes near Danger red (#d62839).
BANDS = [
    (176, 82, 30),
    (226, 128, 40),
    (242, 154, 46),
    (247, 196, 104),
    (252, 238, 204),
]
SMOKE = [(92, 78, 104), (118, 102, 128)]


def flame(width, height, frames, frame, sway, tongues, smoke, base_ratio, seed, scale=1):
    k = scale
    sway *= k
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    phase = 2.0 * math.pi * frame / frames
    centre = (width - 1) / 2.0
    # The flame's own height breathes a little over the loop.
    body = height * (0.78 if smoke else 0.9) * (1.0 + 0.05 * math.sin(phase * 2 + seed))
    base_half = width * base_ratio / 2.0
    for y in range(height):
        up = height - 1 - y  # pixels above the foot
        h = up / body
        if h > 1.0:
            continue
        # A teardrop with a rounded foot: narrow where it eats into what burns, widest a fifth up,
        # coming to a point at the top.
        foot = min(1.0, 0.62 + h * 2.2) if up < 4 * k else 1.0
        profile = math.sin(math.pi * min(1.0, 0.3 + h * 0.7)) ** 0.8 * (1.0 - h) ** 0.45 * foot
        half = base_half * profile * 1.3
        # Its edge is ragged where the tongues lick up.
        if h > 0.3:
            half += 0.8 * k * math.sin(int(up / k) * 1.9 + phase * 3.0 + seed) * h
        # The sides sway: waves that run up the flame, stronger toward its top.
        offset = sway * h * (math.sin(phase + h * 5.0 + seed) + 0.5 * math.sin(2 * phase - h * 7.0 + seed * 2))
        for x in range(width):
            d = abs(x - centre - offset)
            if d > half:
                continue
            # Hottest in a core low in the flame, cooling outward and upward.
            across = d / max(half, 0.5)
            along = (h - 0.22) / (0.95 if h > 0.22 else 0.4)
            heat = 1.0 - math.sqrt(across * across * 0.85 + along * along)
            band = max(0, min(len(BANDS) - 1, int(heat * (len(BANDS) - 0.2) + 0.55)))
            if across > 0.82:
                band = 0
            image.putpixel((x, y), BANDS[band] + (255,))
    # Tongues that break off the top and rise, each on its own track, looping with the frames.
    for i in range(tongues):
        lift = ((frame / frames) * (1 + i % 2) + i / tongues) % 1.0
        ty = height - 1 - int(body * (0.7 + 0.45 * lift))
        tx = int(round(centre + sway * 0.8 * math.sin(phase * (1 + i % 2) + i * 2.1 + seed)))
        size = (2 if lift < 0.5 else 1) * k + (1 if k > 1 and lift < 0.25 else 0)
        colour = BANDS[2] if lift < 0.4 else BANDS[1]
        for dx in range(size):
            for dy in range(size):
                x, y = tx + dx, ty + dy
                if 0 <= x < width and 0 <= y < height:
                    image.putpixel((x, y), colour + (255,))
    # A wisp of smoke above, drifting up and off.
    if smoke:
        for i in range(3):
            lift = ((frame / frames) + i / 3.0) % 1.0
            sy = int(height - 1 - body - 1 - lift * (height - body - 1))
            sx = int(round(centre + 2.5 * k * math.sin(phase + i * 2.4) + lift * 2 * k))
            colour = SMOKE[1] if lift < 0.5 else SMOKE[0]
            for dx in range(2 * k - (1 if lift > 0.6 else 0)):
                for dy in range(k):
                    if 0 <= sx + dx < width and 0 <= sy + dy < height:
                        image.putpixel((sx + dx, sy + dy), colour + (255 if lift < 0.6 else 160,))
    return pk.remove_orphans(_clean(image))


def _clean(image):
    """A flame pixel whose four neighbours mostly share another band takes it: no stray pixels."""
    w, h = image.size
    px = image.load()
    out = image.copy()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            ns = [px[x + ox, y + oy] for ox, oy in ((0, -1), (-1, 0), (1, 0), (0, 1))
                  if 0 <= x + ox < w and 0 <= y + oy < h and px[x + ox, y + oy][3] > 0]
            if len(ns) == 4 and px[x, y] not in ns:
                best = max(set(ns), key=ns.count)
                if ns.count(best) >= 3:
                    po[x, y] = best
    return out


WOOD = pk.Material("#7f5c44", tones=4, step=0.075, lit_step=0.085)
BOWL = pk.Material("#6a5040", tones=3, step=0.07)
CORD = pk.Material("#3e3038", tones=2, step=0.05)
EMBER = (120, 58, 34)


def bracket():
    """The torch's bracket: a shaft of grown root, bound in sap-dark cord, with a bowl of woven bark
    at its head where the flame sits. 20x74."""
    c = pk.Canvas(20, 74)
    c.capsule(10, 14, 10, 72, 2.6, WOOD, 1, r2=2.2)
    for y in range(22, 70, 9):
        c.dot(9, y, WOOD.ramp[0])
        c.dot(10, y + 1, WOOD.ramp[0])
    for y in (14, 17, 20):
        c.capsule(6.5, y, 13.5, y, 1.0, CORD, 2)
    bowl = c.poly([(1, 3), (19, 3), (17, 10), (13, 13), (7, 13), (3, 10)], BOWL, 3, form="sphere")
    bowl.radii = (9.5, 7)
    for x in range(3, 18, 3):
        for y in range(5, 12):
            if (x, y) in bowl.mask and (x + y) % 2 == 0:
                c.dot(x, y, BOWL.ramp[0])
    rim = c.ellipse(10, 3.5, 9.0, 2.6, BOWL, 3.5)
    rim.bias = 0.12
    c.ellipse(10, 3.6, 6.5, 1.4, pk.Material("#2b2228", tones=2), 3.8, form="flat", line=False)
    for x in (7, 10, 13):
        c.dot(x, 3, EMBER)
    return pk.remove_orphans(c.render())


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "assets/shared"
    for f in range(15):
        pk.save(flame(40, 64, 15, f, sway=2.6, tongues=3, smoke=True, base_ratio=0.8, seed=0.7, scale=2),
                os.path.join(root, "fire", "flame_%d.png" % f))
    for f in range(5):
        pk.save(flame(32, 48, 5, f, sway=1.2, tongues=1, smoke=False, base_ratio=0.55, seed=1.9, scale=2),
                os.path.join(root, "torch", "flame_%d.png" % f))
    pk.save(bracket(), os.path.join(root, "torch", "torch.png"))


if __name__ == "__main__":
    main()
