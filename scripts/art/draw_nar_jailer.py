"""Draws the Nar jailer's frames, assets/characters/nar_jailer/*.png, from parts.

An original design for the game: a heavy-set Nar warder in a carved bark helm with a forward brim,
a cuirass of overlapping bark plates over a moss-grey fibre tunic, a knotted club of grown root, and
root-like hair spilling from under the helm. Each frame is a 32x32 canvas, facing right, feet on
row 27, built from the same parts set in a pose, then outlined in near-black around the silhouette.

    python3 -I scripts/art/draw_nar_jailer.py [OUT_DIR]
"""
import math
import os
import sys

from PIL import Image

PALETTE = {
    "o": (26, 21, 30),  # outline
    # carved bark helm
    "h": (130, 98, 74), "H": (96, 71, 54), "G": (64, 47, 38), "v": (34, 26, 24),
    # bark-grey skin, pale eye
    "s": (138, 134, 130), "S": (108, 105, 102), "K": (78, 75, 73), "e": (222, 214, 186),
    # dry-root hair
    "r": (138, 118, 92), "R": (100, 84, 66),
    # bark plates
    "p": (150, 136, 112), "P": (112, 101, 85), "Q": (76, 68, 58),
    # moss-grey fibre cloth
    "c": (110, 132, 120), "C": (78, 98, 90), "D": (52, 66, 62),
    # leather belt, a bone buckle
    "L": (58, 44, 36), "l": (92, 70, 54), "n": (214, 200, 168),
    # trousers
    "t": (86, 80, 90), "T": (63, 58, 66), "U": (43, 39, 46),
    # boots
    "b": (78, 60, 50), "B": (46, 36, 31),
    # knotted root club
    "w": (150, 108, 72), "W": (108, 76, 52), "X": (72, 50, 35), "k": (52, 36, 26),
}

SIZE = 32
FOOT = 27

# Parts, as char maps; "." is empty. Each has an anchor: the pixel of the map that is put on the
# point the pose gives.
HEAD = [  # anchor: the neck, bottom middle
    "...oooo....",
    ".oohphhoo..",
    "ohhhhhhHHo.",
    "ohhHHHHHHGo",
    "RhHHHHHHHGGo",
    "RGGGGGGGGGGGo",
    "RRKSSSSSvvSo",
    "RRKSSSSSSeS.",
    "rRKSSSSSSSSs",
    ".RKKSSSSSSK.",
    "..oKKSSSKK..",
]
HEAD_ANCHOR = (5, 10)

# The bark pauldron on his near shoulder. Anchor: the shoulder.
PAULDRON = [
    ".pppo",
    "pPPPPo",
    "QPPPQ",
    ".QQQ.",
]
PAULDRON_ANCHOR = (2, 1)

TORSO = [  # anchor: the hips, bottom middle (col 5, row 11)
    "..oCCCCCo..",
    ".oQPPPPpPo.",
    "oQPPpppppPo",
    "oQPPPPPPpPo",
    "oQQPPpPPPPo",
    "oCQPPPPPPPo",
    "oCQQPPPpPPo",
    "oCCQQPPPPQo",
    "oLLLLlnLLLo",
    ".oCCCCcCCo.",
    ".oCDCCCCDo.",
    "..oDDCDDo..",
]
TORSO_ANCHOR = (5, 11)


def blank():
    return [[None] * SIZE for _ in range(SIZE)]


def put(canvas, x, y, key):
    if 0 <= x < SIZE and 0 <= y < SIZE and key is not None:
        canvas[y][x] = key


def stamp(canvas, part, anchor, at, flip=False):
    ax, ay = anchor
    for row, line in enumerate(part):
        for col, key in enumerate(line):
            if key == ".":
                continue
            dx = col - ax
            if flip:
                dx = -dx
            put(canvas, at[0] + dx, at[1] + row - ay, key)


def line(a, b):
    """The pixels of a line from a to b, end points included."""
    (x0, y0), (x1, y1) = a, b
    points = []
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        points.append((round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)))
    return points


def limb(canvas, joints, width, lit, mid, shade):
    """A limb through the joints, `width` px thick, lit on its top-left edge and shaded on the other."""
    for a, b in zip(joints, joints[1:]):
        for (x, y) in line(a, b):
            for w in range(width):
                key = lit if w == 0 else (shade if w == width - 1 else mid)
                put(canvas, x + w - width // 2, y, key)


def leg(canvas, hip, knee, foot, near):
    t, T, U = ("t", "T", "U") if near else ("T", "U", "U")
    limb(canvas, [hip, knee, foot], 3, t, T, U)
    fx, fy = foot
    # The boot: toe forward (to the right).
    b, B = ("b", "B") if near else ("B", "B")
    for x in range(fx - 1, fx + 3):
        put(canvas, x, fy, B)
        put(canvas, x, fy - 1, b if x < fx + 2 else B)


def arm(canvas, shoulder, elbow, hand, near):
    c, C, D = ("c", "C", "D") if near else ("C", "D", "D")
    limb(canvas, [shoulder, elbow], 3, c, C, D)
    limb(canvas, [elbow, hand], 2, "s" if near else "S", "S" if near else "K", "K")
    hx, hy = hand
    for dx in (0, 1):
        for dy in (0, 1):
            put(canvas, hx + dx - 1, hy + dy, "S" if near else "K")


def club(canvas, hand, angle, length=11):
    """The knotted club, from the grip in the hand out along the angle (radians, 0 = right, y down)."""
    dx, dy = math.cos(angle), math.sin(angle)
    tip = (round(hand[0] + dx * length), round(hand[1] + dy * length))
    shaft = line(hand, tip)
    for i, (x, y) in enumerate(shaft):
        thick = 2 if i > len(shaft) * 0.45 else 1
        for w in range(thick):
            ox = round(-dy * w)
            oy = round(dx * w)
            put(canvas, x + ox, y + oy, "w" if w == 0 else "W")
        if i in (len(shaft) // 2, len(shaft) * 3 // 4):
            put(canvas, x, y, "k")
    # The heavy root knot at its head.
    tx, ty = tip
    for ox in (-1, 0, 1, 2):
        for oy in (-1, 0, 1, 2):
            if abs(ox - 0.5) + abs(oy - 0.5) > 2.2:
                continue
            key = "W" if (ox + oy) > 1 else "w"
            if ox == 2 or oy == 2:
                key = "X"
            put(canvas, tx + ox - 1, ty + oy - 1, key)
    put(canvas, tx, ty, "k")


def outline(canvas):
    out = [row[:] for row in canvas]
    for y in range(SIZE):
        for x in range(SIZE):
            if canvas[y][x] is not None:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < SIZE and 0 <= ny < SIZE and canvas[ny][nx] not in (None, "o"):
                    out[y][x] = "o"
                    break
    return out


def render(canvas):
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            key = canvas[y][x]
            if key is not None:
                image.putpixel((x, y), PALETTE[key] + (255,))
    return image


def layer_image(draw):
    canvas = blank()
    draw(canvas)
    return render(outline(canvas))


def pose(hip=(15, 18), lean=0, head=(0, 0), back_leg=None, front_leg=None, back_arm=None, front_arm=None,
         club_angle=None, club_in_front=True):
    """One frame, built in layers that are each outlined, far side first, so his limbs read against
    his body. Points are relative to the hip; legs are (knee, foot), arms (elbow, hand)."""
    hx, hy = hip
    shoulder = (hx + lean + 2, hy - 9)
    back_leg = back_leg or ((-1, 4), (-1, FOOT - 1 - hy))
    front_leg = front_leg or ((1, 4), (1, FOOT - 1 - hy))
    rel = lambda p: (hx + p[0], hy + p[1])
    hand = rel(front_arm[1]) if front_arm else None
    layers = []
    if back_arm:
        layers.append(lambda c: arm(c, (shoulder[0] - 3, shoulder[1] + 1), rel(back_arm[0]), rel(back_arm[1]), near=False))
    if club_angle is not None and not club_in_front and hand:
        layers.append(lambda c: club(c, hand, club_angle))

    def body(c):
        leg(c, (hx - 1, hy), rel(back_leg[0]), rel(back_leg[1]), near=False)
        leg(c, (hx + 1, hy), rel(front_leg[0]), rel(front_leg[1]), near=True)
        stamp(c, TORSO, TORSO_ANCHOR, (hx + lean // 2, hy))
        stamp(c, HEAD, HEAD_ANCHOR, (hx + lean + head[0], hy - 11 + head[1]))
    layers.append(body)
    if front_arm:
        def near_arm(c):
            arm(c, shoulder, rel(front_arm[0]), hand, near=True)
            stamp(c, PAULDRON, PAULDRON_ANCHOR, shoulder)
        layers.append(near_arm)
    if club_angle is not None and club_in_front and hand:
        layers.append(lambda c: club(c, hand, club_angle))
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for draw in layers:
        image.alpha_composite(layer_image(draw))
    return image


def on_the_floor(image, dx=0):
    """The image moved so that its lowest pixel is on the foot row."""
    box = image.getbbox()
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(image, (dx, FOOT + 1 - box[3]))
    return out


def death():
    """He buckles, drops to his knees, and falls flat on his face, the club rolled from his hand."""
    buckle = pose(hip=(14, 20), lean=-2, head=(-1, 2), front_arm=((2, -3), (3, 2)), back_arm=((-4, -4), (-5, -1)),
                  club_angle=1.6, front_leg=((3, 3), (3, 6)), back_leg=((-1, 3), (-2, 6)))
    kneel = pose(hip=(14, 23), lean=3, head=(2, 3), front_arm=((4, -2), (6, 3)), back_arm=((1, -3), (3, 2)),
                 club_angle=0.2, front_leg=((4, 0), (4, 3)), back_leg=((0, 3), (-3, 3)))
    # Lying: a straight, slack pose turned a quarter onto his front.
    slack = pose(hip=(16, 18), head=(1, 0), front_arm=((1, 4), (1, 7)), back_arm=((-2, 4), (-2, 7)),
                 front_leg=((1, 4), (1, 8)), back_leg=((-1, 4), (-1, 8)))
    lying = on_the_floor(slack.transpose(Image.Transpose.ROTATE_270), -2)
    club_layer = layer_image(lambda c: club(c, (6, 26), -0.08, 9))
    lying_with_club = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    lying_with_club.alpha_composite(club_layer)
    lying_with_club.alpha_composite(lying)
    return [on_the_floor(buckle), on_the_floor(kneel), lying_with_club]


def frames():
    down = math.pi / 2
    stand_front = ((5, -3), (6, 0))
    out = {}
    # idle: a slow breath, the club resting on his shoulder... held low at his side.
    out["idle"] = [
        pose(front_arm=((4, -4), (5, 0)), back_arm=((-2, -5), (-3, -1)), club_angle=-1.2),
        pose(hip=(15, 18), head=(0, 1), front_arm=((4, -3), (5, 1)), back_arm=((-2, -4), (-3, 0)), club_angle=-1.15),
    ]
    # walk: a heavy stride, four frames.
    out["walk"] = [
        pose(front_arm=((3, -4), (4, 0)), back_arm=((-3, -5), (-5, -2)), club_angle=-1.0,
             front_leg=((3, 4), (4, 8)), back_leg=((-2, 4), (-3, 8))),
        pose(hip=(15, 17), front_arm=((4, -4), (5, -1)), back_arm=((-2, -5), (-3, -1)), club_angle=-1.1,
             front_leg=((1, 4), (1, 9)), back_leg=((0, 5), (-1, 8))),
        pose(front_arm=((5, -4), (6, -1)), back_arm=((-1, -5), (0, -1)), club_angle=-1.25,
             front_leg=((-1, 4), (-3, 8)), back_leg=((2, 4), (4, 8))),
        pose(hip=(15, 17), front_arm=((4, -4), (5, -1)), back_arm=((-2, -5), (-3, -1)), club_angle=-1.1,
             front_leg=((0, 5), (-1, 8)), back_leg=((1, 4), (1, 9))),
    ]
    # strike: the club drawn back over his shoulder, swung down in front, and the recovery.
    out["strike"] = [
        pose(lean=-1, front_arm=((1, -8), (-2, -11)), back_arm=((-3, -5), (-4, -2)), club_angle=-2.6,
             club_in_front=False, front_leg=((2, 4), (3, 8)), back_leg=((-2, 4), (-3, 8))),
        pose(lean=2, head=(1, 1), front_arm=((6, -5), (10, -3)), back_arm=((-1, -5), (1, -2)), club_angle=0.5,
             front_leg=((4, 4), (6, 8)), back_leg=((-2, 4), (-4, 8))),
        pose(lean=1, front_arm=((5, -3), (7, 1)), back_arm=((-2, -5), (-2, -1)), club_angle=1.1,
             front_leg=((3, 4), (4, 8)), back_leg=((-2, 4), (-3, 8))),
    ]
    # low: crouched, then a sweep of the club along the floor at the ankles.
    crouch = 3
    out["low"] = [
        pose(hip=(14, 18 + crouch), lean=1, head=(0, 0), front_arm=((3, -3), (0, 1)), back_arm=((-3, -4), (-4, -1)),
             club_angle=2.8, club_in_front=False, front_leg=((4, 1), (4, 5)), back_leg=((-2, 2), (-4, 5))),
        pose(hip=(15, 18 + crouch), lean=2, head=(1, 1), front_arm=((5, -1), (9, 2)), back_arm=((-2, -4), (0, -1)),
             club_angle=0.15, front_leg=((4, 1), (5, 5)), back_leg=((-3, 2), (-5, 5))),
        pose(hip=(15, 18 + crouch), lean=2, head=(1, 1), front_arm=((5, -2), (8, 1)), back_arm=((-2, -4), (0, -1)),
             club_angle=0.45, front_leg=((4, 1), (5, 5)), back_leg=((-3, 2), (-5, 5))),
    ]
    # unblockable: the club raised high in both hands, held, then slammed down to the floor.
    out["unblockable"] = [
        pose(lean=-1, head=(0, -1), front_arm=((1, -10), (-1, -12)), back_arm=((-1, -10), (-2, -12)),
             club_angle=-2.75, club_in_front=False),
        pose(lean=-2, head=(-1, -1), front_arm=((0, -11), (-3, -12)), back_arm=((-2, -11), (-4, -12)),
             club_angle=-2.95, club_in_front=False),
        pose(hip=(15, 20), lean=3, head=(1, 2), front_arm=((6, -4), (9, 1)), back_arm=((3, -4), (7, 0)),
             club_angle=down * 0.85, front_leg=((4, 3), (6, 6)), back_leg=((-3, 3), (-5, 6))),
    ]
    # break: knocked back, slumped, the club hanging from a loose hand.
    out["break"] = [
        pose(lean=-3, head=(-2, 1), front_arm=((2, -3), (2, 2)), back_arm=((-4, -4), (-6, -1)), club_angle=1.9,
             front_leg=((2, 4), (3, 8)), back_leg=((-1, 4), (-2, 8))),
        pose(hip=(15, 19), lean=-2, head=(-1, 2), front_arm=((2, -2), (2, 3)), back_arm=((-4, -3), (-5, 0)),
             club_angle=1.75, front_leg=((2, 4), (3, 7)), back_leg=((-1, 4), (-2, 7))),
    ]
    out["death"] = death()
    # sit: seated on the guard post's bench, the club across his knees, a slow breath.
    sit_legs = dict(front_leg=((4, 0), (5, 5)), back_leg=((3, 1), (3, 5)))
    out["sit"] = [
        pose(hip=(13, 22), front_arm=((3, -4), (6, -1)), back_arm=((-1, -5), (1, -1)), club_angle=-0.1, **sit_legs),
        pose(hip=(13, 22), head=(0, 1), front_arm=((3, -3), (6, 0)), back_arm=((-1, -4), (1, 0)), club_angle=-0.05, **sit_legs),
    ]
    return out


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "assets/characters/nar_jailer"
    os.makedirs(out_dir, exist_ok=True)
    for name, images in frames().items():
        for i, image in enumerate(images):
            image.save(os.path.join(out_dir, "%s_%d.png" % (name, i)))


if __name__ == "__main__":
    main()
