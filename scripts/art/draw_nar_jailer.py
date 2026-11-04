"""Draws the Nar jailer's frames, assets/characters/nar_jailer/*.png, at 32 px.

A jailer is a fellow Nar, so he is drawn on Almos's own build and poses (draw_almos.py, side on,
facing right) in a guard's outfit: a moss-grey hood with a short tail and its mantle, a dark
leather jerkin over a grey shirt, a leather belt and baldric, dark trousers and boots, and a
sword of grey iron in his hand. He wears no Seal (only the Marked do) and carries no
Flask. Each frame is a 64x64 canvas, feet on row 55, the body in the middle, as Almos's attack
frames are.

    python3 scripts/art/draw_nar_jailer.py [OUT_DIR] [--sheet SHEET.png]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402
import draw_almos as almos  # noqa: E402

M = pk.Material
JAILER = almos.Outfit(
    hood=M("#4d5a4b", tones=4, step=0.07, lit_step=0.09, shine=0.05),
    hood_in=M("#262b26", tones=2, step=0.05),
    robe=M("#5c483c", tones=4, step=0.07, lit_step=0.08),
    sleeve=M("#5f6262", tones=3, step=0.07),
    sleeve_far=M("#464849", tones=2, step=0.05),
    trousers=M("#3d3a44", tones=3, step=0.06),
    trousers_far=M("#2c2a32", tones=2, step=0.05),
    wraps=M("#4e3c32", tones=3, step=0.07),
    wraps_far=M("#382b25", tones=2, step=0.05),
    strap=M("#2f2420", tones=2, step=0.05),
    rope=M("#3a2c26", tones=2, step=0.05),
    tail_len=0.35,
    has_seal=False,
    has_flask=False,
)
BLADE = M("#a3a8b8", tones=3, step=0.11, shine=0.15, outline="#3a3848")
GUARD = M("#4a4652", tones=2, step=0.06)
GRIP = M("#3f2f28", tones=2, step=0.05)
GLINT = (226, 228, 238)
BUCKLE = (214, 200, 168)

SIZE = 64
FOOT_ROW = 55
OX, OY = 16, 8  # where Almos's 32x48 frame sits on the 64x64 canvas


def sword(c, hand, angle, z, length=19):
    """The sword, its grip in the hand and its blade out along the angle (radians, 0 = right, y down):
    a pommel and a wrapped grip behind the hand, a crossguard at it, a straight blade to a point."""
    hx, hy = hand
    dx, dy = math.cos(angle), math.sin(angle)
    px, py = -dy, dx
    keep = lambda x, y: y <= FOOT_ROW
    gx, gy = hx + dx * 2.0, hy + dy * 2.0
    tx, ty = hx + dx * length, hy + dy * length
    c.capsule(gx, gy, tx, ty, 1.75, BLADE, z, r2=0.7, clip=keep)
    c.capsule(gx - px * 3.6, gy - py * 3.6, gx + px * 3.6, gy + py * 3.6, 1.0, GUARD, z + 0.2, clip=keep)
    c.capsule(hx - dx * 3.5, hy - dy * 3.5, gx, gy, 0.85, GRIP, z + 0.1, clip=keep)
    c.ellipse(hx - dx * 4.2, hy - dy * 4.2, 1.3, 1.3, GUARD, z + 0.2, clip=keep)
    # A glint along the blade's lit flat, a third of the way up.
    k = 0.45
    c.dot(int(hx + dx * length * k), int(hy + dy * length * k), GLINT)


def pose(sword_angle=None, sword_behind=False, sword_length=21, render=True, **kw):
    """One frame: Almos's side-on pose (draw_almos.Pose keywords) in the jailer's outfit, with the
    sword in his near hand."""
    c = pk.Canvas(SIZE, SIZE)
    p = almos.Pose(outfit=JAILER, **kw)
    almos.side(p, c, OX, OY)
    # The belt buckle, bone, at the front.
    belt_y = 29 + p.bob + p.crouch + OY
    c.dot(int(16 + OX + 3 + p.lean * 0.5), int(belt_y + 0.5), BUCKLE)
    if sword_angle is not None:
        sword(c, c.hand, sword_angle, 0.3 if sword_behind else 7.9, length=sword_length)
    return pk.remove_orphans(c.render()) if render else c


def walk():
    frames = []
    for i in range(4):
        ph = i / 4.0 * 2 * math.pi
        co, s = math.cos(ph), math.sin(ph)
        near = (round(5 * co), max(0, round(2.4 * s)))
        far = (round(-5 * co), max(0, round(-2.4 * s)))
        frames.append(pose(feet=(near, far), hands=((2, 0), (round(3 * co), 0)), bob=i % 2, lean=1,
                           tail=round(-co), sword_angle=1.15 - 0.12 * co, sword_length=17))
    return frames


def on_the_floor(image, dx=0):
    box = image.getbbox()
    out = pk.Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(image, (dx, FOOT_ROW + 1 - box[3]))
    return out


def death():
    """He buckles, drops to his knees, and falls flat, the sword fallen from his hand."""
    buckle = pose(crouch=3, lean=-2, hands=((3, 3), (-3, 0)), feet=((3, 0), (-2, 0)), sword_angle=1.6)
    kneel = pose(crouch=7, lean=3, hands=((6, 6), (3, 5)), feet=((4, 0), (-5, 0)), sword_angle=0.2)
    # Lying: a slack pose turned a quarter, lit so the light still falls from the top left.
    saved = pk.LIGHT
    pk.LIGHT = (-saved[1], saved[0], saved[2])
    slack = pose(hands=((1, 2), (-1, 2)))
    pk.LIGHT = saved
    lying = on_the_floor(slack.transpose(pk.Image.Transpose.ROTATE_270), -2)
    cl = pk.Canvas(SIZE, SIZE)
    sword(cl, (14, 53), -0.06, 1, length=17)
    lying_with_sword = pk.Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    lying_with_sword.alpha_composite(pk.remove_orphans(cl.render()))
    lying_with_sword.alpha_composite(lying)
    return [on_the_floor(buckle), on_the_floor(kneel), lying_with_sword]


def frames():
    stride = ((5, 0), (-5, 0))
    out = {}
    # idle: a slow breath, the sword hanging from his hand at his side.
    out["idle"] = [pose(hands=((2, 0), (0, 0)), sword_angle=1.15, sword_length=17),
                   pose(bob=1, tail=1, hands=((2, 0), (0, 0)), sword_angle=1.18, sword_length=17)]
    out["walk"] = walk()
    # strike: the sword drawn back over his shoulder, swung down in front, and the recovery.
    out["strike"] = [
        pose(lean=-1, hands=((-3, -10), (2, -1)), feet=((2, 0), (-3, 0)), sword_angle=-2.6, sword_behind=True),
        pose(lean=2, crouch=1, hands=((9, -4), (-2, 0)), feet=stride, tail=-2, sword_angle=0.5),
        pose(lean=1, crouch=1, hands=((7, 2), (-2, 0)), feet=stride, tail=-1, sword_angle=1.1),
    ]
    # low: crouched, then a sweep of the sword along the floor at the ankles.
    out["low"] = [
        pose(crouch=4, lean=1, hands=((-2, 1), (-2, -1)), feet=((4, 0), (-4, 0)), sword_angle=2.8, sword_behind=True),
        pose(crouch=4, lean=2, hands=((9, 3), (0, 0)), feet=((5, 0), (-5, 0)), tail=-2, sword_angle=0.15),
        pose(crouch=4, lean=2, hands=((8, 4), (0, 0)), feet=((5, 0), (-5, 0)), tail=-1, sword_angle=0.45),
    ]
    # unblockable: the sword raised high in both hands, held, then slammed down to the floor.
    out["unblockable"] = [
        pose(lean=-1, hands=((-1, -13), (-2, -13)), sword_angle=-2.75, sword_behind=True),
        pose(lean=-2, hands=((-3, -14), (-4, -14)), tail=1, sword_angle=-2.95, sword_behind=True),
        pose(crouch=2, lean=3, hands=((9, 1), (7, 0)), feet=stride, tail=-2, sword_angle=1.3),
    ]
    # break: knocked back, slumped, the sword hanging from a loose hand.
    out["break"] = [
        pose(lean=-2, hands=((2, 3), (-4, 0)), feet=((3, 0), (-1, 0)), tail=2, sword_angle=1.9),
        pose(bob=1, crouch=1, lean=-2, hands=((2, 4), (-4, 1)), feet=((3, 0), (-1, 0)), tail=2, sword_angle=1.75),
    ]
    out["death"] = death()
    # sit: seated on the guard post's bench, the sword across his knees, a slow breath.
    sit = dict(crouch=5, feet=((5, 0), (4, 0)), sword_angle=-0.1)
    out["sit"] = [pose(hands=((5, 1), (4, 1)), **sit), pose(bob=1, hands=((5, 1), (4, 1)), **sit)]
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
        ims = [im for ims in all_frames.values() for im in ims]
        ims.append(almos.frames()["idle_side"][0])
        pk.sheet(ims, zoom=4, cols=6).save(sheet)


if __name__ == "__main__":
    main()
