"""Draws Almos at 32 px: every frame of idle, fidget, walk, sprint, jump, hurt, block, roll, attack, pull and shove for down, up and side.

    python3 scripts/art/draw_almos.py [OUT_DIR] [--sheet SHEET.png]

Pull and Shove each have a small gesture of the hands, `pull_<side>` and `shove_<side>` (3 frames).
Writes `<anim>_<side>_<n>.png` (32x48, attacks 64x64 with the body in the middle) into OUT_DIR,
by default `assets/characters/almos/`. The feet are on the bottom row of a 32x48 frame (row 55 of
an attack frame), so with the sprite offset (0, -16) they stand on his 12-unit body. Side frames
face right. OUT_DIR `-` writes nothing (for a sheet only). See pixelkit.py for how the parts are
lit and outlined.

He is a young Nar in a deep indigo hood with a long tail and a short mantle over the shoulders,
a warm fibre robe with a leather strap and a rope belt, the Flask at his hip, wrapped forearms
and feet, and the Seal at his neck. Bark-grey skin, pale eyes.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

M = pk.Material
SKIN = M("#6c6966", tones=3, step=0.09)
HOOD = M("#3e4573", tones=4, step=0.075, lit_step=0.1, shine=0.05)
HOOD_IN = M("#272a48", tones=2, step=0.05)
ROBE = M("#a8826c", tones=4, step=0.08, lit_step=0.09)
SLEEVE = M("#86675a", tones=3, step=0.08)
SLEEVE_FAR = M("#6a5149", tones=2, step=0.06)
TROUSERS = M("#3a3b5e", tones=3, step=0.07)
TROUSERS_FAR = M("#2b2b46", tones=2, step=0.05)
WRAPS = M("#bfa685", tones=3, step=0.09)
WRAPS_FAR = M("#8f7b66", tones=2, step=0.07)
STRAP = M("#4b3934", tones=2, step=0.06)
ROPE = M("#b29467", tones=3, step=0.08)
SEAL = M("#25232e", tones=2, step=0.05, outline="#141219")
HAIR = M("#a39a8c", tones=2, step=0.08)
FLASK = M("#8fa7ad", tones=3, step=0.1, shine=0.1)



class Outfit:
    """What a Nar wears, drawn on Almos's build: the materials of each part, and whether there is a
    hood tail (and how long), a Seal at the neck (only the Marked wear one) and a Flask at the hip."""

    def __init__(self, **kw):
        self.skin, self.hood, self.hood_in, self.robe = SKIN, HOOD, HOOD_IN, ROBE
        self.sleeve, self.sleeve_far = SLEEVE, SLEEVE_FAR
        self.trousers, self.trousers_far = TROUSERS, TROUSERS_FAR
        self.wraps, self.wraps_far = WRAPS, WRAPS_FAR
        self.strap, self.rope, self.seal, self.hair, self.flask = STRAP, ROPE, SEAL, HAIR, FLASK
        self.tail_len = 1.0
        self.has_seal = True
        self.has_flask = True
        self.__dict__.update(kw)


ALMOS = Outfit()

EYE = "#e9e2d0"
GLINT = "#d9d3e6"
# The swing's smear, its leading edge first.
SMEAR = [(251, 245, 239), (240, 224, 196), (219, 190, 152)]

W, H = 32, 48


class Pose:
    def __init__(self, **kw):
        self.bob = 0  # the body down by this (a step down, a breath out)
        self.feet = ((0, 0), (0, 0))  # left/near foot and right/far foot: (dx, lift)
        self.hands = ((0, 0), (0, 0))  # left/near and right/far hand offsets (dx, dy)
        self.tail = 0  # the hood tail sway
        self.blink = False
        self.lean = 0  # the head and chest forward
        self.crouch = 0  # how far the hips sink
        self.robe_flare = 0
        self.head = (0, 0)  # the head moved from its place on the neck (dx, dy), as when it droops
        self.outfit = ALMOS
        self.__dict__.update(kw)


def mantle(c, cx, y, side=False, o=None):
    """The hood's mantle over his shoulders, a short cape the hood grows from."""
    o = o or ALMOS
    if side:
        pts = [(cx - 4.5, y - 3), (cx + 3, y - 3), (cx + 5.2, y + 1.5), (cx + 4.4, y + 4.4),
               (cx + 1.5, y + 5.4), (cx - 1.5, y + 4.6), (cx - 4.5, y + 5.4), (cx - 6.6, y + 3.6),
               (cx - 6.4, y + 1)]
    else:
        pts = [(cx - 5, y - 3), (cx + 5, y - 3), (cx + 7.6, y + 1.5), (cx + 7.4, y + 3.5),
               (cx + 4, y + 5.2), (cx + 1.5, y + 4.4), (cx - 1.5, y + 5.4), (cx - 4.5, y + 4.4),
               (cx - 7.4, y + 3.5), (cx - 7.6, y + 1.5)]
    c.poly(pts, o.hood, 7, form="cylinder")


def head(c, pose, cx, cy, view):
    """The head in its hood, its centre at (cx, cy). The hood's long tail hangs behind."""
    o = pose.outfit
    cy = round(cy * 2) / 2
    tail = pose.tail
    if view == "down":
        if o.tail_len > 0:
            c.capsule(cx + 3.5, cy - 4.5, cx + 3.5 + (4.5 + tail * 0.5) * o.tail_len,
                      cy - 4.5 + (10.5 + abs(tail) * 0.3) * o.tail_len, 2.4, o.hood, 0.5, r2=1.1 + 0.8 * (1 - o.tail_len))
        c.ellipse(cx, cy, 6.6, 7.0, o.hood, 8)
        c.ellipse(cx, cy + 2.0, 3.9, 4.0, o.hood_in, 8.5, form="flat", line=False)
        c.ellipse(cx, cy + 2.8, 3.1, 3.4, o.skin, 9)
        rim = c.ellipse(cx, cy - 3.2, 6.0, 3.6, o.hood, 10, clip=lambda x, y: y < cy + 0.5)
        rim.bias = 0.05
        ey = int(cy + 2.5)
        if pose.blink:
            for ex in (-2, 1):
                c.dot(int(cx + ex), ey, o.skin.ramp[0])
        else:
            c.dot(int(cx - 2), ey, EYE)
            c.dot(int(cx + 1), ey, EYE)
        if o.has_seal:
            c.capsule(cx - 2.2, cy + 7.6, cx + 2.2, cy + 7.6, 1.0, o.seal, 9.5)
            c.dot(int(cx - 1), int(cy + 7.6), GLINT)
    elif view == "up":
        c.ellipse(cx, cy, 6.6, 7.0, o.hood, 8)
        if o.tail_len > 0:
            c.capsule(cx + 0.5, cy + 3, cx + 0.5 + (1 + tail * 0.6) * o.tail_len,
                      cy + 3 + (10.5 + abs(tail) * 0.2) * o.tail_len, 2.5, o.hood, 8.5, r2=1.1 + 0.8 * (1 - o.tail_len))
    else:
        if o.tail_len > 0:
            c.capsule(cx - 3.5, cy - 3, cx - 3.5 - (6 + tail * 0.5) * o.tail_len,
                      cy - 3 + (7 + abs(tail) * 0.3) * o.tail_len, 2.4, o.hood, 0.5, r2=1.0 + 0.9 * (1 - o.tail_len))
        c.ellipse(cx, cy, 6.3, 7.0, o.hood, 8)
        c.ellipse(cx + 3.0, cy + 2.2, 3.0, 4.2, o.hood_in, 8.5, form="flat", line=False)
        c.ellipse(cx + 3.4, cy + 2.9, 2.4, 3.4, o.skin, 9)
        # The hood's front edge comes down past the cheek, so the face sits inside it.
        c.capsule(cx + 0.5, cy - 4.5, cx + 0.8, cy + 5.5, 1.6, o.hood, 10)
        rim = c.ellipse(cx + 1.5, cy - 3.4, 5.4, 3.0, o.hood, 10, clip=lambda x, y: y < cy + 0.5)
        rim.bias = 0.05
        ey = int(cy + 2.5)
        c.dot(int(cx + 4), ey, o.skin.ramp[0] if pose.blink else EYE)
        if o.has_seal:
            c.capsule(cx + 0.5, cy + 7.4, cx + 3.4, cy + 7.4, 1.0, o.seal, 9.5)


# --- down and up ---------------------------------------------------------------------------------

def front(pose, c=None, ox=0, oy=0, back=False):
    """Almos facing the viewer (or, with back, facing away). ox, oy move him on a bigger canvas."""
    c = c or pk.Canvas(W, H)
    o = pose.outfit
    b = pose.bob + pose.crouch
    hip_y = 36 + b + oy
    for i, sx in enumerate((13.4, 18.6)):
        fdx, lift = pose.feet[i]
        foot_y = 45.6 - lift + oy
        x = sx + ox + fdx
        c.capsule(sx + ox, hip_y, x, foot_y - 1.6, 2.2, o.trousers, 2, r2=1.9)
        c.ellipse(x + (-0.4 if i == 0 else 0.4), foot_y + 0.5, 2.5, 1.6, o.wraps, 3)
    top = 19 + b + oy
    hem = 39 + b + oy - min(pose.crouch, 2)
    f = pose.robe_flare
    robe = [(14 + ox, top - 0.5), (18 + ox, top - 0.5), (21.6 + ox, top + 2), (21.4 + ox, top + 10),
            (23.2 + ox + f, hem - 1.5), (23.6 + ox + f, hem), (20.5 + ox, hem + 0.6), (17.5 + ox, hem - 0.5),
            (14.5 + ox, hem + 0.7), (11.5 + ox, hem - 0.3), (8.4 + ox - f, hem), (8.8 + ox - f, hem - 1.5),
            (10.6 + ox, top + 10), (10.4 + ox, top + 2)]
    c.poly(robe, o.robe, 4, form="cylinder")
    belt_y = 29 + b + oy
    strap = set()
    for t in range(0, 13):
        if back:
            x = round(20 + ox - t * 0.75)
            strap.update({(x, round(top + 2 + t * 0.66)), (x - 1, round(top + 2 + t * 0.66))})
        else:
            x = round(12 + ox + t * 0.75)
            strap.update({(x, round(top + 2 + t * 0.66)), (x + 1, round(top + 2 + t * 0.66))})
    c.mask(strap, o.strap, 5, line=False)
    if not back:
        if o.has_flask:
            c.ellipse(20.2 + ox, belt_y + 4, 1.6, 2.1, o.flask, 7)
            c.dot(int(19.7 + ox), int(belt_y + 3), GLINT)
        c.capsule(13 + ox, belt_y + 1.5, 12.6 + ox + pose.tail * 0.3, belt_y + 5, 0.7, o.rope, 6, line=False)
    c.capsule(10.4 + ox, belt_y + 0.5, 21.6 + ox, belt_y + 0.5, 0.9, o.rope, 6)
    for i, (sx, side) in enumerate(((10.0, -1), (22.0, 1))):
        hdx, hdy = pose.hands[i]
        hx = sx + side * 1.2 + ox + hdx
        hy = 31 + b + oy + hdy
        ex, ey = sx + side * 0.8 + ox + hdx * 0.4, top + 6.5 + hdy * 0.4
        z = 5.5 if -6 < hdy < 6 else (7.6 if back else 8.6)
        c.capsule(sx + ox, top + 2.5, ex, ey, 2.2, o.sleeve, z, r2=2.0)
        c.capsule(ex, ey, hx, hy - 1.2, 1.7, o.wraps, z + 0.1, r2=1.5)
        c.ellipse(hx, hy, 1.6, 1.5, o.skin, z + 0.5)
        if not hasattr(c, "hands"):
            c.hands = [None, None]
        c.hands[i] = (hx, hy, z + 0.5)
    mantle(c, 16 + ox, top + 0.5, o=o)
    head(c, pose, 16 + ox + pose.head[0], 11 + b * 0.5 + oy + pose.head[1], view="up" if back else "down")
    return c


# --- side (facing right) -------------------------------------------------------------------------

def side(pose, c=None, ox=0, oy=0):
    c = c or pk.Canvas(W, H)
    o = pose.outfit
    b = pose.bob + pose.crouch
    lean = pose.lean
    hip_x = 16 + ox
    hip_y = 36 + b + oy
    # Far leg first, darker, then the near one.
    for i, (mat, wrap, z) in enumerate(((o.trousers, o.wraps, 3), (o.trousers_far, o.wraps_far, 1))):
        fdx, lift = pose.feet[i]
        fx = hip_x + fdx
        fy = 45.6 - lift + oy
        knee_x = (hip_x + fx) / 2 + 1.2 + lift * 0.3
        knee_y = (hip_y + fy) / 2 - 0.5
        c.capsule(hip_x - 0.5 + (0 if i == 0 else 1), hip_y, knee_x, knee_y, 2.3, mat, z, r2=2.0)
        c.capsule(knee_x, knee_y, fx, fy - 1.5, 2.0, mat, z, r2=1.8)
        c.ellipse(fx + 1.2, fy + 0.5, 2.8, 1.6, wrap, z + 0.5)
    top = 19 + b + oy
    hem = 39 + b + oy - min(pose.crouch, 2)
    f = pose.robe_flare
    robe = [(hip_x - 2.5 + lean, top - 0.5), (hip_x + 2.5 + lean, top - 0.5), (hip_x + 4.6 + lean, top + 3),
            (hip_x + 4.4 + lean * 0.5, top + 11), (hip_x + 5.6 + f * 0.5, hem - 0.5), (hip_x + 3, hem + 0.6),
            (hip_x, hem - 0.4), (hip_x - 3, hem + 0.6), (hip_x - 6.2 - f, hem - 0.2), (hip_x - 5.4 - f, hem - 2),
            (hip_x - 4.6, top + 10), (hip_x - 4.8 + lean, top + 2.5)]
    c.poly(robe, o.robe, 4, form="cylinder")
    belt_y = 29 + b + oy
    c.capsule(hip_x - 4.4, belt_y + 0.5, hip_x + 4.4 + lean * 0.5, belt_y + 0.5, 0.9, o.rope, 6)
    strap = set()
    for t in range(0, 12):
        x = round(hip_x + 2 + lean - t * 0.4)
        strap.update({(x, round(top + 2 + t * 0.7)), (x + 1, round(top + 2 + t * 0.7))})
    c.mask(strap, o.strap, 5, line=False)
    if o.has_flask:
        c.ellipse(hip_x + 3.6, belt_y + 3.8, 1.5, 2.0, o.flask, 6.5)
        c.dot(int(hip_x + 3), int(belt_y + 3), GLINT)
    c.capsule(hip_x - 3.4, belt_y + 1.5, hip_x - 4.4 - pose.tail * 0.3, belt_y + 5, 0.7, o.rope, 6, line=False)
    # Arms: the far one behind the body, the near one in front.
    sh_x, sh_y = hip_x + lean + 0.5, top + 3
    for i, (sleeve, wrap, z) in enumerate(((o.sleeve, o.wraps, 6.8), (o.sleeve_far, o.wraps_far, 0.8))):
        hdx, hdy = pose.hands[i]
        hx, hy = sh_x + hdx + (0 if i == 0 else 1), 31 + b + oy + hdy
        ex = sh_x + hdx * 0.45 + (0 if i == 0 else 1)
        ey = sh_y + 4.5 + hdy * 0.35
        fz = z if i == 1 else 7.6
        c.capsule(sh_x + (0 if i == 0 else 1), sh_y, ex, ey, 2.1, sleeve, z, r2=1.9)
        c.capsule(ex, ey, hx, hy - 1.0, 1.6, wrap, fz + 0.1, r2=1.4)
        c.ellipse(hx + 0.3, hy, 1.6, 1.5, o.skin, fz + 0.5)
        if i == 0:
            c.hand = (hx + 0.3, hy)
    mantle(c, hip_x + lean, top + 0.5, side=True, o=o)
    c.head = (hip_x + lean + 0.5 + pose.head[0], 11 + b * 0.5 + oy + pose.head[1])
    head(c, pose, c.head[0], c.head[1], view="side")
    return c


# --- the roll: tucked into a ball ----------------------------------------------------------------

def ball(angle, view, c=None, ox=0, oy=0, squash=0.0, o=None):
    """Almos tucked, rolling: a ball of hood and robe turned by angle (radians), on the ground."""
    c = c or pk.Canvas(W, H)
    o = o or ALMOS
    cx, cy = 16 + ox, 39.5 + oy
    rx, ry = 7.8 + squash, 7.8 - squash
    cy += squash
    dx, dy = math.cos(angle), math.sin(angle)
    if view == "up":
        dx, dy = -dx, -dy

    def hood_side(x, y):
        return (x + 0.5 - cx) * dx + (y + 0.5 - cy) * dy > -1.0

    c.ellipse(cx, cy, rx, ry, o.robe, 2)
    c.ellipse(cx, cy, rx, ry, o.hood, 3, clip=hood_side)
    # The wrapped feet and the strap show on the robe side, turning with it.
    fx, fy = cx - dx * 5.2 + dy * 2.4, cy - dy * 5.2 - dx * 2.4
    c.ellipse(fx, fy, 2.0, 1.6, o.wraps, 4)
    sx, sy = cx - dx * 2.0, cy - dy * 2.0
    c.capsule(sx - dy * 4, sy + dx * 4, sx + dy * 4, sy - dx * 4, 0.8, o.strap, 3.5, line=False)
    # The tail flicks out behind the turn.
    tx, ty = cx + dx * 6.0 - dy * 3.0, cy + dy * 6.0 + dx * 3.0
    c.capsule(cx + dx * 4.5, cy + dy * 4.5, tx - dy * 2.0, ty + dx * 2.0, 1.6, o.hood, 1, r2=0.9)
    return c


# --- the swing's smear ---------------------------------------------------------------------------

def smear(c, cx, cy, radius, a0, a1, thick, fade=1.0):
    """A crescent from angle a0 to a1 (radians, a1 the leading end) round (cx, cy)."""
    span = a1 - a0
    for y in range(c.h):
        for x in range(c.w):
            px, py = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(px, py)
            a = math.atan2(py, px)
            # The angle along the swing, 0 at its tail and 1 at its leading end.
            t = None
            for k in (-1, 0, 1):
                tt = (a + k * 2 * math.pi - a0) / span
                if 0.0 <= tt <= 1.0:
                    t = tt
                    break
            if t is None:
                continue
            w = thick * (0.25 + 0.75 * math.sin(min(1.0, t * 1.15) * math.pi * 0.5)) * fade
            if t > 0.92:
                w *= (1.0 - t) / 0.08
            if radius - w <= d <= radius:
                edge = (radius - d) / max(w, 0.01)
                tone = 0 if edge < 0.34 else (1 if edge < 0.7 else 2)
                if t < 0.25 * fade + (1 - fade) * 0.6:
                    tone = min(2, tone + 1)
                c.overlay(x, y, SMEAR[tone])


# --- Pull and Shove: a small gesture of the hands ------------------------------------------------

# The hands of each frame of a gesture, (near, far) as Pose.hands, and the lean, for each view.
# Shove: hands drawn in to the chest, palms pushed out, then eased back. Pull: hands reached out,
# closed on it, then drawn in to the chest.
GESTURES = {
    "shove": {
        "side": [(((3, -6), (2, -6)), -1), (((9, -6), (8, -5)), 1), (((6, -3), (5, -3)), 0)],
        "down": [(((3, -4), (-3, -4)), 0), (((5, -7), (-5, -7)), 0), (((3, -3), (-3, -3)), 0)],
        "up": [(((2, -5), (-2, -5)), 0), (((4, -9), (-4, -9)), 0), (((2, -4), (-2, -4)), 0)],
    },
    "pull": {
        "side": [(((9, -6), (8, -5)), 1), (((7, -6), (6, -6)), 0), (((2, -6), (1, -6)), -1)],
        "down": [(((5, -7), (-5, -7)), 0), (((4, -6), (-4, -6)), 0), (((2, -3), (-2, -3)), 0)],
        "up": [(((4, -9), (-4, -9)), 0), (((3, -7), (-3, -7)), 0), (((1, -3), (-1, -3)), 0)],
    },
}


def gesture_frames(kind, view):
    images = []
    for hands, lean in GESTURES[kind][view]:
        if view == "side":
            c = side(Pose(hands=hands, lean=lean, tail=-lean))
        else:
            c = front(Pose(hands=hands), back=(view == "up"))
        images.append(render(c))
    return images


# --- the poses -----------------------------------------------------------------------------------

def idle_poses():
    return [Pose(), Pose(tail=1), Pose(bob=1, tail=1), Pose(bob=1, blink=True)]


def walk_poses(view):
    poses = []
    for i in range(6):
        p = i / 6.0 * 2 * math.pi
        s = math.sin(p)
        co = math.cos(p)
        bob = 1 if i in (1, 4) else 0
        if view == "side":
            near = (round(5.0 * co), max(0, round(2.4 * s)))
            far = (round(-5.0 * co), max(0, round(-2.4 * s)))
            hands = ((round(-3.5 * co), 0), (round(3.5 * co), 0))
            poses.append(Pose(bob=bob, feet=(near, far), hands=hands, tail=round(-co), lean=1,
                              robe_flare=1 if i in (0, 3) else 0))
        else:
            left = (0, max(0, round(2.2 * s)))
            right = (0, max(0, round(-2.2 * s)))
            hands = ((0, round(1.5 * co)), (0, round(-1.5 * co)))
            poses.append(Pose(bob=bob, feet=(left, right), hands=hands, tail=round(s)))
    return poses


def sprint_poses(view):
    """A run: a longer stride than the walk, the body pitched forward, the arms pumping and the hood
    tail and robe streaming."""
    poses = []
    for i in range(6):
        p = i / 6.0 * 2 * math.pi
        s = math.sin(p)
        co = math.cos(p)
        bob = 1 if i in (1, 4) else (-1 if i in (0, 3) else 0)
        if view == "side":
            near = (round(6.5 * co), max(0, round(3.4 * s)))
            far = (round(-6.5 * co), max(0, round(-3.4 * s)))
            hands = ((round(-5.0 * co) + 1, -1 + round(abs(co))), (round(5.0 * co) + 1, -1))
            poses.append(Pose(bob=bob, feet=(near, far), hands=hands, tail=-2 + round(-co * 0.5), lean=2,
                              robe_flare=2 if i in (0, 3) else 1))
        else:
            left = (0, max(0, round(3.2 * s)))
            right = (0, max(0, round(-3.2 * s)))
            hands = ((round(-0.8 * co), round(-2.5 * co) - 1), (round(0.8 * co), round(2.5 * co) - 1))
            poses.append(Pose(bob=bob, feet=(left, right), hands=hands, tail=round(1.6 * s), robe_flare=1))
    return poses


def jump_poses(view):
    """The Jump: a crouch to spring from, tucked in the air with the arms up for balance, and a
    crouch to take the landing."""
    if view == "side":
        return [Pose(crouch=3, lean=2, hands=((-3, 1), (-2, 1)), feet=((2, 0), (-2, 0)), tail=1),
                Pose(feet=((4, 4), (-3, 3)), hands=((3, -6), (-2, -5)), lean=1, tail=-2, robe_flare=2),
                Pose(crouch=2, lean=1, hands=((2, -1), (-1, -1)), feet=((3, 0), (-3, 0)), tail=1)]
    return [Pose(crouch=3, hands=((-1, 2), (1, 2)), tail=1),
            Pose(feet=((0, 4), (0, 3)), hands=((-2, -7), (2, -7)), tail=-1, robe_flare=2),
            Pose(crouch=2, hands=((-2, -1), (2, -1)), tail=1, robe_flare=1)]


def hurt_poses(view):
    """A flinch from a hit: knocked back a step, the head snapped back and the arms thrown up, then
    gathering himself."""
    if view == "side":
        return [Pose(lean=-2, head=(-1, 0), hands=((-1, -7), (-3, -5)), feet=((1, 0), (-4, 1)), crouch=1, tail=2),
                Pose(lean=-1, hands=((0, -3), (-2, -2)), feet=((2, 0), (-3, 0)), crouch=1, tail=1)]
    return [Pose(head=(0, -1), hands=((-3, -8), (3, -8)), crouch=1, tail=2, robe_flare=1),
            Pose(hands=((-2, -3), (2, -3)), crouch=1, tail=1)]


def block_poses(view):
    """Guarding: weight down, both forearms up before him."""
    if view == "side":
        return [Pose(crouch=2, lean=1, hands=((4, -8), (3, -7)), feet=((3, 0), (-3, 0)))]
    return [Pose(crouch=2, hands=((3, -9), (-3, -9)))]


def fidget_poses(view):
    """Now and then as he stands: he glances one way, then the other, tugs his hood straight and
    settles, with a blink at the end."""
    if view == "side":
        return [Pose(), Pose(head=(1, 0)), Pose(head=(1, 0), tail=1), Pose(head=(-1, 0), tail=-1),
                Pose(head=(0, -1), hands=((1, -16), (0, 0)), tail=1), Pose(hands=((1, -16), (0, 0))),
                Pose(bob=1), Pose(bob=1, blink=True)]
    return [Pose(), Pose(head=(-1, 0)), Pose(head=(-1, 0), tail=-1), Pose(head=(1, 0), tail=1),
            Pose(head=(1, 0)), Pose(hands=((0, 0), (-3, -17))), Pose(hands=((0, 0), (-3, -17)), tail=1),
            Pose(bob=1, blink=True)]


def parry_poses(view):
    """A Parry: the forearm swept out across the blow to turn it aside, then drawn back."""
    if view == "side":
        return [Pose(crouch=1, lean=1, hands=((7, -7), (2, -3)), feet=((3, 0), (-3, 0)), tail=-1),
                Pose(crouch=1, hands=((4, -3), (1, -1)), feet=((2, 0), (-2, 0)))]
    return [Pose(crouch=1, hands=((5, -8), (-1, -2)), tail=1), Pose(crouch=1, hands=((3, -4), (0, -1)))]


def sip_poses(view):
    """A Sip: the Flask raised to his mouth, the head tipped back to drink, and drinking still."""
    if view == "side":
        return [Pose(hands=((2, -9), (0, 0))), Pose(head=(-1, -1), lean=-1, hands=((2, -13), (0, 0))),
                Pose(head=(-1, -1), lean=-1, bob=1, hands=((2, -13), (0, 0)))]
    return [Pose(hands=((0, 0), (-3, -10))), Pose(head=(0, -1), hands=((0, 0), (-4, -15))),
            Pose(head=(0, -1), bob=1, hands=((0, 0), (-4, -15)))]


def hold_poses(view):
    """Holding a prop over his head in both hands: standing (the first frame), and walking
    with it held up (all six)."""
    poses = []
    for p in walk_poses(view):
        p.hands = ((1, -18), (0, -18)) if view == "side" else ((-1, -19), (1, -19))
        p.robe_flare = 0
        poses.append(p)
    poses[0].feet = ((0, 0), (0, 0))
    return poses


def winded_poses(view):
    """Out of Stamina: bent over, hands on his knees, his back heaving as he gets his breath."""
    if view == "side":
        base = dict(crouch=2, lean=2, hands=((3, 5), (2, 5)), feet=((2, 0), (-2, 0)))
    else:
        base = dict(crouch=2, hands=((2, 6), (-2, 6)))
    return [Pose(bob=0, **base), Pose(bob=1, **base), Pose(bob=0, tail=1, **base), Pose(bob=1, blink=True, **base)]


def death_frames():
    """His Death: he buckles, drops to his knees and falls on his side, limp. Drawn side on, on the
    64x64 canvas of the attacks (feet on row 55), since lying he is longer than a standing frame is
    wide, and shown for every side."""
    ox, oy = 16, 8
    buckle = pk.Canvas(64, 64)
    side(Pose(crouch=3, lean=-2, hands=((3, 3), (-3, 0)), feet=((3, 0), (-2, 0)), tail=2), buckle, ox, oy)
    kneel = pk.Canvas(64, 64)
    side(Pose(crouch=7, lean=3, hands=((6, 6), (3, 5)), feet=((4, 0), (-5, 0)), tail=1), kneel, ox, oy)
    saved = pk.LIGHT
    pk.LIGHT = (-saved[1], saved[0], saved[2])
    slack = render(side(Pose(hands=((1, 2), (-1, 2)))))
    pk.LIGHT = saved
    lying = slack.transpose(pk.Image.Transpose.ROTATE_270)
    box = lying.getbbox()
    body = lying.crop(box)
    flat = pk.Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    flat.alpha_composite(body, ((64 - body.width) // 2, 56 - body.height))
    return [render(buckle), render(kneel), flat]


def roll_frames(view):
    images = []
    draw = side if view == "side" else (lambda p, **kw: front(p, back=(view == "up"), **kw))
    images.append(draw(Pose(crouch=4, hands=((2, -2), (-2, -2)) if view != "side" else ((3, -3), (2, -3)),
                            lean=2 if view == "side" else 0, tail=1)))
    for k in range(4):
        angle = -math.pi / 2 + k * math.pi / 2 if view == "side" else -math.pi / 2 + k * math.pi / 2
        squash = 0.6 if k in (0, 3) else 0.0
        if view == "side":
            images.append(ball(angle, view, squash=squash))
        else:
            # Toward or away from the viewer the ball turns over its top: the hood comes round.
            images.append(ball(-math.pi / 2 + k * math.pi / 2 + math.pi / 2 * 0.5, view, squash=squash))
    images.append(draw(Pose(crouch=2, tail=-1, lean=1 if view == "side" else 0)))
    return [render(c) for c in images]


ATTACK_PHASES = ["wind", "coil", "strike", "follow", "recover"]

# The sword in his hand when he carries one: a plain short blade of grey iron, a crossguard, a wrapped
# grip and a pommel, drawn like the jailer's.
SWORD_BLADE = M("#a3a8b8", tones=3, step=0.11, shine=0.15, outline="#3a3848")
SWORD_GUARD = M("#4a4652", tones=2, step=0.06)
SWORD_GRIP = M("#4b3934", tones=2, step=0.05)
SWORD_GLINT = (226, 228, 238)
SWORD_LENGTH = 17
# The angle of the blade in each phase of a swing (radians, 0 = right, y down), for each view, and
# whether it is behind him. Side: drawn back over the shoulder, swung down in front. Down: raised
# over his head, swung down toward the viewer. Up: low at his side, swung up away from the viewer.
SWORD_SWING = {
    "side": {"wind": (-2.3, True), "coil": (-2.75, True), "strike": (0.35, False), "follow": (1.0, False), "recover": (1.3, False)},
    "down": {"wind": (-2.2, True), "coil": (-2.0, True), "strike": (1.35, False), "follow": (2.0, False), "recover": (1.75, False)},
    "up": {"wind": (1.2, True), "coil": (0.9, True), "strike": (-1.45, True), "follow": (-2.1, True), "recover": (1.6, True)},
}


def sword(c, hand, angle, z, length=SWORD_LENGTH, great=False):
    """The sword, its grip in the hand and its blade out along the angle; great, the greatsword: a
    longer, broader blade with a fuller, a wider guard and a long two-handed grip."""
    if great:
        return greatsword(c, hand, angle, z)
    hx, hy = hand
    dx, dy = math.cos(angle), math.sin(angle)
    px, py = -dy, dx
    gx, gy = hx + dx * 2.0, hy + dy * 2.0
    c.capsule(gx, gy, hx + dx * length, hy + dy * length, 1.6, SWORD_BLADE, z, r2=0.6)
    c.capsule(gx - px * 3.2, gy - py * 3.2, gx + px * 3.2, gy + py * 3.2, 0.9, SWORD_GUARD, z + 0.2)
    c.capsule(hx - dx * 3.0, hy - dy * 3.0, gx, gy, 0.8, SWORD_GRIP, z + 0.1)
    c.ellipse(hx - dx * 3.7, hy - dy * 3.7, 1.2, 1.2, SWORD_GUARD, z + 0.2)
    c.dot(int(hx + dx * length * 0.5), int(hy + dy * length * 0.5), SWORD_GLINT)


GREATSWORD_LENGTH = 25


def greatsword(c, hand, angle, z):
    hx, hy = hand
    dx, dy = math.cos(angle), math.sin(angle)
    px, py = -dy, dx
    gx, gy = hx + dx * 3.0, hy + dy * 3.0
    c.capsule(gx, gy, hx + dx * GREATSWORD_LENGTH, hy + dy * GREATSWORD_LENGTH, 2.3, SWORD_BLADE, z, r2=0.8)
    for k in range(4, GREATSWORD_LENGTH - 6):
        c.dot(int(hx + dx * k), int(hy + dy * k), SWORD_BLADE.ramp[0])
    c.capsule(gx - px * 4.4, gy - py * 4.4, gx + px * 4.4, gy + py * 4.4, 1.1, SWORD_GUARD, z + 0.2)
    c.capsule(hx - dx * 5.0, hy - dy * 5.0, gx, gy, 0.9, SWORD_GRIP, z + 0.1)
    c.ellipse(hx - dx * 5.8, hy - dy * 5.8, 1.6, 1.6, SWORD_GUARD, z + 0.2)
    c.dot(int(hx + dx * GREATSWORD_LENGTH * 0.45), int(hy + dy * GREATSWORD_LENGTH * 0.45), SWORD_GLINT)


def attack_frames(view, with_sword=False, great=False):
    """The five frames of a swing for the view; with_sword, the sword is in his hand (great, the
    greatsword, swung in both hands)."""
    images = []
    ox, oy = 16, 8
    for phase in ATTACK_PHASES:
        c = pk.Canvas(64, 64)
        if view == "side":
            hands = {"wind": ((-4, -8), (2, -2)), "coil": ((-6, -10), (3, -1)), "strike": ((9, -4), (-2, 0)),
                     "follow": ((7, 2), (-3, 0)), "recover": ((2, 0), (0, 0))}[phase]
            lean = {"wind": -1, "coil": -2, "strike": 2, "follow": 2, "recover": 1}[phase]
            feet = {"wind": ((2, 0), (-3, 0)), "coil": ((3, 0), (-4, 0)), "strike": ((5, 0), (-5, 0)),
                    "follow": ((5, 0), (-5, 0)), "recover": ((3, 0), (-3, 0))}[phase]
            crouch = {"wind": 0, "coil": 1, "strike": 1, "follow": 1, "recover": 0}[phase]
            side(Pose(hands=hands, lean=lean, feet=feet, crouch=crouch, tail=-lean), c, ox, oy)
            if with_sword:
                angle, behind = SWORD_SWING["side"][phase]
                sword(c, c.hand, angle, 0.3 if behind else 7.9, great=great)
            if phase == "strike":
                smear(c, 33, 30, 22, -1.35, 1.05, 6.5)
            elif phase == "follow":
                smear(c, 33, 30, 22, 0.1, 1.25, 4.5, fade=0.6)
        else:
            back = view == "up"
            # Down swings below him, up swings above; the arm leads from his right (the viewer's left
            # when he faces down).
            arm = 0 if not back else 1
            other = 1 - arm
            if not back:
                reach = {"wind": (-2, -9), "coil": (-3, -11), "strike": (5, 7), "follow": (8, 4), "recover": (1, 1)}[phase]
            else:
                reach = {"wind": (2, -2), "coil": (3, 1), "strike": (-3, -13), "follow": (-7, -9), "recover": (-1, 0)}[phase]
            hands = [(0, 0), (0, 0)]
            hands[arm] = reach
            hands[other] = (0, -1)
            crouch = {"wind": 0, "coil": 1, "strike": 1, "follow": 1, "recover": 0}[phase]
            front(Pose(hands=tuple(hands), crouch=crouch, tail=1 if phase in ("strike", "follow") else 0),
                  c, ox, oy, back=back)
            if with_sword:
                angle, behind = SWORD_SWING[view][phase]
                hx, hy, hz = c.hands[arm]
                sword(c, (hx, hy), angle, 0.3 if behind else hz + 0.3, great=great)
            if phase in ("strike", "follow"):
                fade = 1.0 if phase == "strike" else 0.6
                if not back:
                    a0, a1 = (math.pi * 1.05, math.pi * 0.1) if phase == "strike" else (math.pi * 0.6, math.pi * 0.02)
                    smear(c, 32, 38, 20, a0, a1, 6.5 if phase == "strike" else 4.5, fade=fade)
                else:
                    a0, a1 = (-math.pi * 0.05, -math.pi * 1.0) if phase == "strike" else (-math.pi * 0.4, -math.pi * 1.02)
                    smear(c, 32, 30, 22, a0, a1, 6.5 if phase == "strike" else 4.5, fade=fade)
        images.append(render(c))
    return images


def render(c):
    return pk.remove_orphans(c.render())


def frames():
    out = {}
    for view in ("down", "up", "side"):
        if view == "side":
            draw = side
        else:
            draw = (lambda back: (lambda p, **kw: front(p, back=back, **kw)))(view == "up")
        out["idle_" + view] = [render(draw(p)) for p in idle_poses()]
        out["walk_" + view] = [render(draw(p)) for p in walk_poses(view)]
        out["sprint_" + view] = [render(draw(p)) for p in sprint_poses(view)]
        out["jump_" + view] = [render(draw(p)) for p in jump_poses(view)]
        out["hurt_" + view] = [render(draw(p)) for p in hurt_poses(view)]
        out["block_" + view] = [render(draw(p)) for p in block_poses(view)]
        out["fidget_" + view] = [render(draw(p)) for p in fidget_poses(view)]
        out["roll_" + view] = roll_frames(view)
        out["attack_" + view] = attack_frames(view)
        out["attack_sword_" + view] = attack_frames(view, with_sword=True)
        out["attack_greatsword_" + view] = attack_frames(view, with_sword=True, great=True)
        out["parry_" + view] = [render(draw(p)) for p in parry_poses(view)]
        out["sip_" + view] = [render(draw(p)) for p in sip_poses(view)]
        out["hold_" + view] = [render(draw(p)) for p in hold_poses(view)]
        out["winded_" + view] = [render(draw(p)) for p in winded_poses(view)]
        out["death_" + view] = death_frames()
        out["pull_" + view] = gesture_frames("pull", view)
        out["shove_" + view] = gesture_frames("shove", view)
    return out


def main():
    args = list(sys.argv[1:])
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    out_dir = args[0] if args else "assets/characters/almos"
    all_frames = frames()
    if out_dir != "-":
        for name, imgs in all_frames.items():
            for i, im in enumerate(imgs):
                pk.save(im, os.path.join(out_dir, "%s_%d.png" % (name, i)))
    if sheet:
        rows = []
        for name in all_frames:
            rows.append(pk.sheet(all_frames[name], zoom=4, cols=6))
        w = max(r.width for r in rows)
        out = pk.Image.new("RGBA", (w, sum(r.height for r in rows)), (40, 36, 46, 255))
        y = 0
        for r in rows:
            out.alpha_composite(r, (0, y))
            y += r.height
        out.save(sheet)


if __name__ == "__main__":
    main()
