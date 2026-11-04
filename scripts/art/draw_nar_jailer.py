"""Draws the Nar jailer's frames, assets/characters/nar_jailer/*.png, at 32 px, from parts.

An original design for the game: a heavy-set Nar warder in a carved bark helm with a ridged crest
and a forward brim, a cuirass of overlapping bark plates and a bark pauldron over a moss-grey fibre
tunic, a leather belt with a bone buckle, dark trousers and boots, root-like hair spilling from
under the helm, and a knotted club of grown root. Each frame is a 64x64 canvas, facing right, feet
on row 55, built from the same parts set in a pose and lit by pixelkit.py (top-left light,
hue-shifted ramps, selective outlines). The poses are given on a 32 grid (as the first, 16 px
drawing had them) and drawn at twice that.

    python3 -I scripts/art/draw_nar_jailer.py [OUT_DIR] [--sheet SHEET.png]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

M = pk.Material
HELM = M("#7e5f48", tones=4, step=0.075, lit_step=0.09)
HELM_DARK = M("#3a2b25", tones=2, step=0.05)
SKIN = M("#77736f", tones=3, step=0.09)
SKIN_FAR = M("#5a5754", tones=2, step=0.06)
HAIR = M("#6e5d4a", tones=2, step=0.07)
PLATE = M("#8f8169", tones=4, step=0.075, lit_step=0.09)
CLOTH = M("#62786d", tones=3, step=0.07)
CLOTH_FAR = M("#46564f", tones=2, step=0.06)
BELT = M("#4a3a30", tones=2, step=0.06)
TROUSERS = M("#545060", tones=3, step=0.07)
TROUSERS_FAR = M("#3b3844", tones=2, step=0.05)
BOOT = M("#4e3c32", tones=3, step=0.07)
BOOT_FAR = M("#382b25", tones=2, step=0.05)
WOOD = M("#93694a", tones=4, step=0.08, lit_step=0.09)

EYE = "#ddd3b4"
BONE = "#d6c8a8"

SIZE = 64
FOOT = 27  # the foot row on the 32 grid; 55 at 64


def _p(x, y):
    """A point on the 32 grid, drawn at 64."""
    return (x * 2 + 1.0, y * 2 + 1.0)


def leg(c, hip, knee, foot, near):
    mat, boot, z = (TROUSERS, BOOT, 3) if near else (TROUSERS_FAR, BOOT_FAR, 1)
    h, k, f = _p(*hip), _p(*knee), _p(*foot)
    c.capsule(h[0], h[1], k[0], k[1], 3.3, mat, z, r2=3.0)
    c.capsule(k[0], k[1], f[0], f[1] - 0.5, 3.0, mat, z, r2=2.7)
    c.ellipse(f[0] + 1.8, f[1] + 1.4, 4.0, 2.4, boot, z + 0.2, clip=lambda x, y: y <= min(f[1] + 3, FOOT * 2 + 1))


def arm(c, shoulder, elbow, hand, near):
    cloth, skin, z = (CLOTH, SKIN, 7) if near else (CLOTH_FAR, SKIN_FAR, 0.5)
    s, e, h = _p(*shoulder), _p(*elbow), _p(*hand)
    c.capsule(s[0], s[1], e[0], e[1], 3.0, cloth, z, r2=2.7)
    c.capsule(e[0], e[1], h[0], h[1], 2.4, skin, z + 0.1, r2=2.2)
    c.ellipse(h[0], h[1] + 0.5, 2.5, 2.4, skin, z + 0.2)


def club(c, hand, angle, length=11, z=8):
    """The knotted club, from the grip in the hand out along the angle (radians, 0 = right, y down)."""
    hx, hy = _p(*hand)
    dx, dy = math.cos(angle), math.sin(angle)
    length *= 2
    sx, sy = hx - dx * 2.5, hy - dy * 2.5
    tx, ty = hx + dx * length, hy + dy * length
    c.capsule(sx, sy, tx, ty, 1.5, WOOD, z, r2=2.8)
    # Knots along it, and the knob at its head.
    for t, r in ((0.45, 2.1), (0.72, 2.6)):
        kx, ky = hx + dx * length * t - dy * 1.2, hy + dy * length * t + dx * 1.2
        c.ellipse(kx, ky, r, r, WOOD, z + 0.1)
    c.ellipse(tx, ty, 3.6, 3.6, WOOD, z + 0.2)


def torso(c, hx, hy, lean):
    """The cuirass of bark plates over the tunic, the belt, from the hip (on the 32 grid)."""
    x, y = _p(hx + lean / 2.0, hy)
    top = y - 20
    sk = lean * 1.0
    # Tunic skirt, below the belt.
    c.poly([(x - 7, y - 3), (x + 7, y - 3), (x + 8.5, y + 6), (x + 3, y + 7.5), (x - 3, y + 6.5),
            (x - 8.5, y + 7)], CLOTH, 2.5, form="cylinder")
    body = c.poly([(x - 5 + sk, top), (x + 5 + sk, top), (x + 9 + sk, top + 4), (x + 9.5 + sk * 0.5, top + 12),
                   (x + 8, y - 1), (x - 8, y - 1), (x - 8.5, top + 11), (x - 7.5 + sk, top + 3)],
                  PLATE, 4, form="cylinder")
    # The plates overlap: a line in the plate's own deep tone every few rows, offset like shingles.
    for i, row in enumerate(range(int(top) + 6, int(y) - 2, 5)):
        for px in range(int(x - 9 + sk), int(x + 10 + sk)):
            if (px, row) in body.mask and ((px + i * 3) % 7) != 0:
                c.dot(px, row, PLATE.ramp[0])
    c.capsule(x - 8.4, y - 1.5, x + 8.4, y - 1.5, 1.4, BELT, 5)
    c.ellipse(x + 4.5 + lean * 0.3, y - 1.5, 1.6, 1.4, BELT, 5.5)
    c.dot(int(x + 4.5 + lean * 0.3), int(y - 2), BONE)
    c.dot(int(x + 4.5 + lean * 0.3) - 1, int(y - 2), BONE)


def head(c, hx, hy):
    """The head under its helm, from the neck point (on the 32 grid)."""
    x, y = _p(hx, hy)
    cy = y - 7
    # Root hair spilling from under the helm, at the back.
    c.capsule(x - 5, cy - 1, x - 7, cy + 4, 2.2, HAIR, 5.2, r2=1.2)
    c.capsule(x - 3, cy, x - 4.2, cy + 5, 1.6, HAIR, 5.3, r2=1.0)
    # The face, in profile: a heavy jaw, the brow under the brim.
    c.poly([(x - 4, cy - 3), (x + 4.5, cy - 3), (x + 6.6, cy + 1), (x + 6, cy + 3), (x + 6.4, cy + 4.2),
            (x + 4.5, cy + 7.2), (x - 1, cy + 7.6), (x - 4.5, cy + 4)], SKIN, 6, form="sphere")
    c.dot(int(x + 4), int(cy + 1), EYE)
    c.dot(int(x + 3), int(cy + 1), SKIN.ramp[0])
    c.dot(int(x + 5), int(cy + 5), SKIN.ramp[0])
    # The helm: a dome with a ridged crest and a brim jutting forward.
    c.ellipse(x - 0.5, cy - 4, 7.4, 6.0, HELM, 7, clip=lambda px, py: py < cy - 1)
    c.poly([(x - 8, cy - 2.5), (x + 9.5, cy - 3), (x + 8.5, cy - 0.5), (x - 7.5, cy - 0.5)], HELM, 7.5,
           form="cylinder")
    c.capsule(x - 6, cy - 7, x + 3, cy - 10, 1.2, HELM, 7.6)
    for px in range(int(x - 5), int(x + 3), 3):
        c.dot(px, int(cy - 9 + (px - x) * 0.33), HELM.ramp[0])
    c.mask({(px, int(cy - 0.5)) for px in range(int(x - 6), int(x + 9))}, HELM_DARK, 7.4, line=False)


def pauldron(c, shoulder):
    s = _p(*shoulder)
    c.ellipse(s[0] + 0.5, s[1] + 0.5, 5.0, 4.0, PLATE, 7.8, clip=lambda x, y: y < s[1] + 3.5)
    c.dot(int(s[0]), int(s[1] + 3), PLATE.ramp[0])


def pose(hip=(15, 18), lean=0, head=(0, 0), back_leg=None, front_leg=None, back_arm=None, front_arm=None,
         club_angle=None, club_in_front=True, render=True):
    """One frame. Points are on the 32 grid, relative to the hip; legs are (knee, foot), arms
    (elbow, hand)."""
    c = pk.Canvas(SIZE, SIZE)
    hx, hy = hip
    shoulder = (hx + lean + 2, hy - 9)
    back_leg = back_leg or ((-1, 4), (-1, FOOT - 1 - hy))
    front_leg = front_leg or ((1, 4), (1, FOOT - 1 - hy))
    rel = lambda p: (hx + p[0], hy + p[1])
    hand = rel(front_arm[1]) if front_arm else None
    if back_arm:
        arm(c, (shoulder[0] - 3, shoulder[1] + 1), rel(back_arm[0]), rel(back_arm[1]), near=False)
    if club_angle is not None and hand:
        club(c, hand, club_angle, z=8.5 if club_in_front else 0.3)
    leg(c, (hx - 1, hy), rel(back_leg[0]), rel(back_leg[1]), near=False)
    leg(c, (hx + 1, hy), rel(front_leg[0]), rel(front_leg[1]), near=True)
    torso(c, hx, hy, lean)
    globals()["head"](c, hx + lean + head[0], hy - 11 + head[1])
    if front_arm:
        arm(c, shoulder, rel(front_arm[0]), hand, near=True)
        pauldron(c, shoulder)
    return pk.remove_orphans(c.render()) if render else c


def on_the_floor(image, dx=0):
    """The image moved so that its lowest pixel is on the foot row."""
    box = image.getbbox()
    out = pk.Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(image, (dx, FOOT * 2 + 2 - box[3]))
    return out


def death():
    """He buckles, drops to his knees, and falls flat, the club rolled from his hand."""
    buckle = pose(hip=(14, 20), lean=-2, head=(-1, 2), front_arm=((2, -3), (3, 2)), back_arm=((-4, -4), (-5, -1)),
                  club_angle=1.6, front_leg=((3, 3), (3, 6)), back_leg=((-1, 3), (-2, 6)))
    kneel = pose(hip=(14, 23), lean=3, head=(2, 3), front_arm=((4, -2), (6, 3)), back_arm=((1, -3), (3, 2)),
                 club_angle=0.2, front_leg=((4, 0), (4, 3)), back_leg=((0, 3), (-3, 3)))
    # Lying: a straight, slack pose turned a quarter, lit so the light still comes from the top left.
    saved = pk.LIGHT
    pk.LIGHT = (-saved[1], saved[0], saved[2])
    slack = pose(hip=(16, 18), head=(1, 0), front_arm=((1, 4), (1, 7)), back_arm=((-2, 4), (-2, 7)),
                 front_leg=((1, 4), (1, 8)), back_leg=((-1, 4), (-1, 8)))
    pk.LIGHT = saved
    lying = on_the_floor(slack.transpose(pk.Image.Transpose.ROTATE_270), -4)
    cl = pk.Canvas(SIZE, SIZE)
    club(cl, (6, 26), -0.08, 9)
    lying_with_club = pk.Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    lying_with_club.alpha_composite(pk.remove_orphans(cl.render()))
    lying_with_club.alpha_composite(lying)
    return [on_the_floor(buckle), on_the_floor(kneel), lying_with_club]


def frames():
    down = math.pi / 2
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
    args = list(sys.argv[1:])
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    out_dir = args[0] if args else "assets/characters/nar_jailer"
    all_frames = frames()
    if out_dir != "-":
        for name, images in all_frames.items():
            for i, image in enumerate(images):
                pk.save(image, os.path.join(out_dir, "%s_%d.png" % (name, i)))
    if sheet:
        pk.sheet([im for ims in all_frames.values() for im in ims], zoom=4, cols=6).save(sheet)


if __name__ == "__main__":
    main()
