"""Draws the Nar knight's frames, assets/characters/nar_knight/*.png, at 32 px.

The knight is a fellow Nar, so like the jailer he is drawn on Almos's own build and side-on poses
(draw_almos.py, facing right), but in armour of his own so he reads as a knight and not a jailer:
a closed helm of grey iron with a visor slit and a crest of dark bark fibre, a broad iron pauldron
over his shoulders where a hood's mantle would be, a cuirass of grown bark plates in bands, mail
sleeves, iron gauntlets and sabatons, dark greaves, and a longsword, longer and broader than the
jailer's, with a wide crossguard. He wears no Seal and carries no Flask. Each frame is a 64x64
canvas, feet on row 55, the body in the middle, as the jailer's are.

Besides what every enemy plays (idle, walk, strike, low, unblockable, break, death) he has `sleep`:
sitting on the stool at the end of his desk (draw_props.py's desk), slumped forward with his arms
folded on the desk top and his helmed head down on them, his sword leaning against the stool behind him.

    python3 scripts/art/draw_nar_knight.py [OUT_DIR] [--sheet SHEET.png]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402
import draw_almos as almos  # noqa: E402
import draw_nar_jailer as jailer  # noqa: E402

M = pk.Material
IRON = M("#646a7a", tones=4, step=0.08, lit_step=0.1, shine=0.1, outline="#20212b")
PAULDRON = M("#545866", tones=4, step=0.075, lit_step=0.09, shine=0.1, outline="#20212b")
KNIGHT = almos.Outfit(
    skin=M("#5c6170", tones=3, step=0.08),  # the visor's face plate and his gauntleted hands
    hood=IRON,  # the helm, and the pauldron where the mantle would be
    hood_in=M("#1d1d26", tones=2, step=0.04),
    robe=M("#54463c", tones=4, step=0.075, lit_step=0.085),  # bark plates
    sleeve=M("#5d606b", tones=3, step=0.08, shine=0.05),  # mail
    sleeve_far=M("#43454f", tones=2, step=0.05),
    trousers=M("#5a5f6e", tones=3, step=0.08, shine=0.1),  # iron greaves and cuisses
    trousers_far=M("#3f424e", tones=2, step=0.05),
    wraps=M("#737888", tones=3, step=0.09, shine=0.1),  # gauntlets and sabatons
    wraps_far=M("#50535f", tones=2, step=0.06),
    strap=M("#2e2420", tones=2, step=0.05),
    rope=M("#3b2e27", tones=2, step=0.05),  # his sword belt
    tail_len=0.0,
    has_seal=False,
    has_flask=False,
)
BARK_LINE = KNIGHT.robe.ramp[0]
KNEE = M("#6b7181", tones=3, step=0.09, shine=0.12, outline="#20212b")
KNEE_FAR = M("#474b57", tones=2, step=0.05)
CREST = M("#4a4a36", tones=3, step=0.07)
VISOR = M("#70768a", tones=3, step=0.09, shine=0.12, outline="#20212b")
SLIT = (22, 22, 30)
RIVET = (196, 200, 214)
BLADE = M("#a9aebe", tones=3, step=0.11, shine=0.15, outline="#363442")
GUARD = M("#504a40", tones=2, step=0.06)
GRIP = M("#3a2c25", tones=2, step=0.05)
GLINT = (228, 230, 240)

SIZE = jailer.SIZE
FOOT_ROW = jailer.FOOT_ROW
OX, OY = jailer.OX, jailer.OY
SWORD = 25  # the longsword's length from the hand, against the jailer's 17 to 21


def longsword(c, hand, angle, z, length=SWORD):
    """The longsword, its grip in the hand and its blade out along the angle (radians, 0 = right,
    y down): a heavy pommel and a long wrapped grip, a wide crossguard, a broad blade to a point."""
    hx, hy = hand
    dx, dy = math.cos(angle), math.sin(angle)
    px, py = -dy, dx
    keep = lambda x, y: y <= FOOT_ROW
    gx, gy = hx + dx * 2.2, hy + dy * 2.2
    tx, ty = hx + dx * length, hy + dy * length
    c.capsule(gx, gy, tx, ty, 2.2, BLADE, z, r2=0.7, clip=keep)
    # The fuller, a dark groove down the middle of the blade's first half.
    for k in range(3, int(length * 0.55)):
        c.dot(int(hx + dx * k), int(hy + dy * k), BLADE.ramp[0])
    c.capsule(gx - px * 4.6, gy - py * 4.6, gx + px * 4.6, gy + py * 4.6, 1.1, GUARD, z + 0.2, clip=keep)
    c.capsule(hx - dx * 5.0, hy - dy * 5.0, gx, gy, 0.9, GRIP, z + 0.1, clip=keep)
    c.ellipse(hx - dx * 5.8, hy - dy * 5.8, 1.6, 1.6, GUARD, z + 0.2, clip=keep)
    k = 0.62
    c.dot(int(hx + dx * length * k + px), int(hy + dy * length * k + py), GLINT)


def helm(c, cx, cy):
    """Over the hooded head drawn by draw_almos: a visor plate over the face with a dark slit, a
    rivet, and a crest of bark fibre along the top."""
    cy = round(cy * 2) / 2
    c.ellipse(cx + 3.1, cy + 2.6, 3.2, 4.1, VISOR, 10.4)
    for x in range(int(cx + 2), int(cx + 7)):
        c.dot(x, int(cy + 1.5), SLIT)
    c.dot(int(cx + 4), int(cy + 4.5), SLIT)
    c.dot(int(cx + 5), int(cy + 5.5), SLIT)
    c.dot(int(cx + 1), int(cy + 3.5), RIVET)
    c.capsule(cx - 4.2, cy - 4.4, cx + 2.2, cy - 7.0, 1.4, CREST, 10.6, r2=1.0)


def cuirass(c, p, top, belt_y, hip_x):
    """The bands of the bark cuirass and its tassets, dark lines across the chest and the skirt,
    and the pauldron, a rounded iron plate over the shoulder, darker than the helm so the two read
    apart, with a rivet."""
    for y in (top + 7, belt_y + 4, belt_y + 7):
        for x in range(int(hip_x - 4 + p.lean * 0.5), int(hip_x + 4 + p.lean * 0.5)):
            c.dot(x, int(y), BARK_LINE)
    # The knee cops: a rounded plate on each knee, with a glint on the near one, and a dark seam
    # where the cuisse meets the greave.
    for i, (mat, z) in enumerate(((KNEE, 3.4), (KNEE_FAR, 1.4))):
        fdx, lift = p.feet[i]
        hip_y = 36 + p.bob + p.crouch + OY
        fx, fy = hip_x + fdx, 45.6 - lift + OY
        kx, ky = (hip_x + fx) / 2 + 1.2 + lift * 0.3, (hip_y + fy) / 2 - 0.5
        c.ellipse(kx + 0.6, ky, 2.0, 1.8, mat, z)
        if i == 0:
            c.dot(int(kx), int(ky - 1), RIVET)
    sx = hip_x + p.lean + 0.5
    c.ellipse(sx - 0.5, top + 2.5, 4.6, 3.6, PAULDRON, 7.3)
    c.capsule(sx - 4.5, top + 5.2, sx + 3.5, top + 5.6, 1.0, PAULDRON, 7.4)
    c.dot(int(sx - 1), int(top + 2), RIVET)


def pose(sword_angle=None, sword_behind=False, sword_length=SWORD, render=True, sword_at=None, **kw):
    """One frame: Almos's side-on pose (draw_almos.Pose keywords) in the knight's armour, with the
    longsword in his near hand (or, with sword_at, lying where it is given)."""
    c = pk.Canvas(SIZE, SIZE)
    # A closed helm shows no eye: the "blink" draws it in the face plate's dark tone, part of the slit.
    p = almos.Pose(outfit=KNIGHT, blink=True, **kw)
    almos.side(p, c, OX, OY)
    b = p.bob + p.crouch
    top = 19 + b + OY
    belt_y = 29 + b + OY
    hip_x = 16 + OX
    cuirass(c, p, top, belt_y, hip_x)
    helm(c, *c.head)
    if sword_at is not None:
        longsword(c, sword_at[0], sword_at[1], sword_at[2], length=sword_length)
    elif sword_angle is not None:
        longsword(c, c.hand, sword_angle, 0.3 if sword_behind else 7.9, length=sword_length)
    return pk.remove_orphans(c.render()) if render else c


def walk():
    frames = []
    for i in range(4):
        ph = i / 4.0 * 2 * math.pi
        co, s = math.cos(ph), math.sin(ph)
        near = (round(5 * co), max(0, round(2.4 * s)))
        far = (round(-5 * co), max(0, round(-2.4 * s)))
        frames.append(pose(feet=(near, far), hands=((2, 0), (round(3 * co), 0)), bob=i % 2, lean=1,
                           sword_angle=1.2 - 0.1 * co, sword_length=22))
    return frames


def death():
    """He buckles, drops to his knees, and falls flat, the longsword fallen from his hand."""
    buckle = pose(crouch=3, lean=-2, hands=((3, 3), (-3, 0)), feet=((3, 0), (-2, 0)), sword_angle=1.6, sword_length=20)
    kneel = pose(crouch=7, lean=3, hands=((6, 6), (3, 5)), feet=((4, 0), (-5, 0)), sword_angle=0.15)
    saved = pk.LIGHT
    pk.LIGHT = (-saved[1], saved[0], saved[2])
    slack = pose(hands=((1, 2), (-1, 2)))
    pk.LIGHT = saved
    lying = jailer.on_the_floor(slack.transpose(pk.Image.Transpose.ROTATE_270), -2)
    cl = pk.Canvas(SIZE, SIZE)
    longsword(cl, (12, 53), -0.05, 1, length=22)
    lying_with_sword = pk.Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    lying_with_sword.alpha_composite(pk.remove_orphans(cl.render()))
    lying_with_sword.alpha_composite(lying)
    return [jailer.on_the_floor(buckle), jailer.on_the_floor(kneel), lying_with_sword]


def frames():
    stride = ((5, 0), (-5, 0))
    out = {}
    # idle: a slow breath, the longsword hanging from his hand, its point low.
    out["idle"] = [pose(hands=((2, 0), (0, 0)), sword_angle=1.2, sword_length=22),
                   pose(bob=1, hands=((2, 0), (0, 0)), sword_angle=1.23, sword_length=22)]
    out["walk"] = walk()
    # strike: the longsword drawn back over his shoulder, swung down in front, and the recovery.
    out["strike"] = [
        pose(lean=-1, hands=((-3, -10), (2, -1)), feet=((2, 0), (-3, 0)), sword_angle=-2.6, sword_behind=True),
        pose(lean=2, crouch=1, hands=((9, -4), (-2, 0)), feet=stride, sword_angle=0.45),
        pose(lean=1, crouch=1, hands=((7, 2), (-2, 0)), feet=stride, sword_angle=1.1, sword_length=22),
    ]
    # low: crouched, then a sweep of the longsword along the floor at the ankles.
    out["low"] = [
        pose(crouch=4, lean=1, hands=((-2, 1), (-2, -1)), feet=((4, 0), (-4, 0)), sword_angle=2.85, sword_behind=True),
        pose(crouch=4, lean=2, hands=((9, 3), (0, 0)), feet=((5, 0), (-5, 0)), sword_angle=0.12),
        pose(crouch=4, lean=2, hands=((8, 4), (0, 0)), feet=((5, 0), (-5, 0)), sword_angle=0.4),
    ]
    # unblockable: the longsword raised high in both hands, held, then slammed down to the floor.
    out["unblockable"] = [
        pose(lean=-1, hands=((-1, -13), (-2, -13)), sword_angle=-2.75, sword_behind=True),
        pose(lean=-2, hands=((-3, -14), (-4, -14)), sword_angle=-2.95, sword_behind=True),
        pose(crouch=2, lean=3, hands=((9, 1), (7, 0)), feet=stride, sword_angle=1.3, sword_length=20),
    ]
    # break: knocked back, slumped, the longsword hanging from a loose hand.
    out["break"] = [
        pose(lean=-2, hands=((2, 3), (-4, 0)), feet=((3, 0), (-1, 0)), sword_angle=1.9, sword_length=20),
        pose(bob=1, crouch=1, lean=-2, hands=((2, 4), (-4, 1)), feet=((3, 0), (-1, 0)), sword_angle=1.75, sword_length=20),
    ]
    out["death"] = death()
    # sleep: seated on the stool at the desk's end, slumped forward over the desk, his arms folded
    # on it and his head down on them, the longsword leaning against the stool behind him; a slow breath.
    # The desk itself is its own picture behind him.
    asleep = dict(crouch=5, lean=3, feet=((6, 0), (5, 0)), hands=((9, -4), (8, -5)),
                  sword_at=((23, 37), 1.95, 0.2), sword_length=17)
    # Asleep he breathes deep and slow: his back and shoulders rise, hold and sink again.
    out["sleep"] = [pose(head=(5, 11), bob=1, **asleep), pose(head=(5, 11), **asleep),
                    pose(head=(5, 10), bob=-1, **asleep), pose(head=(5, 10), bob=-1, **asleep),
                    pose(head=(5, 11), **asleep), pose(head=(5, 11), bob=1, **asleep)]
    hang = dict(sword_angle=1.2, sword_length=22)
    out["hurt"] = [pose(lean=-2, head=(-1, 0), hands=((-1, -3), (-4, -2)), feet=((1, 0), (-4, 1)), crouch=1, sword_angle=1.7, sword_length=20),
                   pose(lean=-1, hands=((1, 0), (-2, 0)), feet=((2, 0), (-3, 0)), crouch=1, **hang)]
    out["look"] = [pose(hands=((2, 0), (0, 0)), **hang), pose(head=(-1, 0), lean=-1, hands=((2, 0), (0, 0)), **hang),
                   pose(head=(-1, 0), lean=-1, bob=1, hands=((2, 0), (0, 0)), **hang), pose(head=(1, 0), hands=((2, 0), (0, 0)), **hang)]
    out["startle"] = [pose(bob=-2, lean=-1, hands=((3, -6), (-2, -4)), feet=((1, 2), (-1, 1)), sword_angle=-0.6, sword_length=20),
                      pose(crouch=2, lean=1, hands=((6, -3), (1, -2)), feet=((4, 0), (-4, 0)), sword_angle=-0.4, sword_length=20)]
    # rise: heavy in his armour, he pushes up off the desk, takes up the longsword and stands.
    out["rise"] = [pose(head=(4, 8), crouch=5, lean=3, feet=((6, 0), (5, 0)), hands=((9, -2), (8, -3)), sword_at=((23, 37), 1.95, 0.2), sword_length=17),
                   pose(head=(2, 3), crouch=4, lean=3, feet=((6, 0), (4, 0)), hands=((8, 1), (7, 0)), sword_at=((23, 37), 1.95, 0.2), sword_length=17),
                   pose(crouch=2, lean=2, hands=((4, 2), (2, 1)), feet=((4, 0), (-1, 0)), sword_angle=1.0, sword_length=20),
                   pose(hands=((2, 0), (0, 0)), **hang)]
    return out


def main():
    args = list(sys.argv[1:])
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    out_dir = args[0] if args else "assets/characters/nar_knight"
    all_frames = frames()
    if out_dir != "-":
        for name, images in all_frames.items():
            for i, image in enumerate(images):
                pk.save(image, os.path.join(out_dir, "%s_%d.png" % (name, i)))
    if sheet:
        ims = [im for ims in all_frames.values() for im in ims]
        ims.append(jailer.frames()["idle"][0])
        pk.sheet(ims, zoom=4, cols=6).save(sheet)


if __name__ == "__main__":
    main()
