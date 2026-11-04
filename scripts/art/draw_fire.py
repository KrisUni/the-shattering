"""Draws the game's flames, original pixel art for this game:

- assets/shared/fire/flame_0-14.png: Fire, the flame that stands on anything burning (20x32,
  15 frames, a seamless loop at 12 a second), tall and restless, tongues breaking off its top and a
  wisp of violet smoke above;
- assets/shared/torch/flame_0-4.png: a torch's small, steadier flame (16x24, 5 frames at 8 a second).

Each flame is a teardrop whose sides sway with slow, looping waves, filled in hard bands from a deep
amber rim to a cream core (no anti-aliasing: every pixel is one of the band colours). The waves turn
a whole number of times over the loop, so the last frame runs into the first.

    python3 -I scripts/art/draw_fire.py [OUT_ROOT]
"""
import math
import os
import sys

from PIL import Image

# Rim to core. Fire amber (#f29a2e) is the body; nothing comes near Danger red (#d62839).
BANDS = [
    (176, 82, 30),
    (226, 128, 40),
    (242, 154, 46),
    (247, 196, 104),
    (252, 238, 204),
]
SMOKE = [(92, 78, 104), (118, 102, 128)]


def flame(width, height, frames, frame, sway, tongues, smoke, base_ratio, seed):
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
        foot = min(1.0, 0.62 + h * 2.2) if up < 4 else 1.0
        profile = math.sin(math.pi * min(1.0, 0.3 + h * 0.7)) ** 0.8 * (1.0 - h) ** 0.45 * foot
        half = base_half * profile * 1.3
        # Its edge is ragged where the tongues lick up.
        if h > 0.3:
            half += 0.8 * math.sin(up * 1.9 + phase * 3.0 + seed) * h
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
        size = 2 if lift < 0.5 else 1
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
            sx = int(round(centre + 2.5 * math.sin(phase + i * 2.4) + lift * 2))
            colour = SMOKE[1] if lift < 0.5 else SMOKE[0]
            for dx in (0, 1):
                if 0 <= sx + dx < width and 0 <= sy < height:
                    image.putpixel((sx + dx, sy), colour + (255 if lift < 0.6 else 160,))
    return image


def doubled(image):
    """The image at the game's 32 px scale: every pixel drawn here as 2x2 (it is drawn at 16 px)."""
    return image.resize((image.width * 2, image.height * 2), Image.NEAREST)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "assets/shared"
    os.makedirs(os.path.join(root, "fire"), exist_ok=True)
    os.makedirs(os.path.join(root, "torch"), exist_ok=True)
    for f in range(15):
        doubled(flame(20, 32, 15, f, sway=2.6, tongues=3, smoke=True, base_ratio=0.8, seed=0.7)).save(
            os.path.join(root, "fire", "flame_%d.png" % f))
    for f in range(5):
        doubled(flame(16, 24, 5, f, sway=1.2, tongues=1, smoke=False, base_ratio=0.55, seed=1.9)).save(
            os.path.join(root, "torch", "flame_%d.png" % f))


if __name__ == "__main__":
    main()


# The torch's bracket: a shaft of grown root with a bowl of woven bark bound in sap-dark cord at its
# head, where the flame sits. 10x37, drawn by hand for this game.
BRACKET = [
    ".oooooooo.",
    "obbBBBBBBo",
    "oBnBnBnBQo",
    "obBBBBBBQo",
    "oQBnBnBQQo",
    "oQQQQQQQQo",
    ".oLLlLLLo.",
    "..oWwWWo..",
    "..oLlLLo..",
    "..oWwWXo..",
    "..oLlLLo..",
    "..owWWXo..",
    "...owXo...",
    "...owWo...",
    "...owXo...",
    "...owWo...",
    "...owWo...",
    "...okXo...",
    "...owWo...",
    "...owWo...",
    "...owXo...",
    "...owWo...",
    "...okWo...",
    "...owWo...",
    "...owXo...",
    "...owWo...",
    "...owWo...",
    "...owXo...",
    "...okWo...",
    "...owWo...",
    "...owWo...",
    "...owXo...",
    "...owWo...",
    "...owWo...",
    "...oXXo...",
    "...oXXo...",
    "....oo....",
]
BRACKET_COLOURS = {
    "o": (26, 21, 30),
    "b": (150, 118, 86), "B": (112, 86, 62), "Q": (74, 56, 42), "n": (186, 154, 110),
    "L": (56, 42, 46), "l": (86, 66, 70),
    "w": (138, 100, 68), "W": (100, 72, 50), "X": (70, 50, 36), "k": (50, 35, 26),
}


def bracket():
    image = Image.new("RGBA", (10, 37), (0, 0, 0, 0))
    for y, row in enumerate(BRACKET):
        for x, key in enumerate(row):
            if key != ".":
                image.putpixel((x, y), BRACKET_COLOURS[key] + (255,))
    return image


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "assets/shared"
    doubled(bracket()).save(os.path.join(root, "torch", "torch.png"))
