"""A small kit for drawing the game's 32 px art in code.

Run nothing from here; the draw_*.py scripts use it. Every thing is drawn as parts: a part is a
shape (an ellipse, a capsule, a polygon, a box, a mask), a material and a depth. The kit then
renders the parts the way the art bible asks:

- One light, from the top left. Each part has a rounded form (a sphere, a cylinder or flat), and the
  light on it picks one of its material's tones.
- Hue-shifted ramps: a material's shadows are cooler (toward blue violet) and darker, its lights
  warmer (toward sand) and paler. Three or four tones per material.
- Parts in front cast a short shadow onto parts behind and below them.
- Selective outlines: only the silhouette is outlined, near black tinted by the material, and on the
  lit top left edge the outline is the material's own deep tone. Where one part meets another
  inside the silhouette, the line is the deep tone of the part behind, never black.
- Cleanup: a pixel whose four neighbours all share another tone of its material takes that tone,
  so there are no stray single pixels; marked details (eyes, glints, rivets) are kept.

Colours are free (no master palette); Danger red (#d62839) is never produced on purpose, and
`check_no_danger` guards every saved image.
"""

import colorsys
import math
import os

from PIL import Image

LIGHT = (-0.55, -0.7, 0.6)
_l = math.sqrt(sum(c * c for c in LIGHT))
LIGHT = tuple(c / _l for c in LIGHT)

DANGER = (0xD6, 0x28, 0x39)

# Hues the shading leans to, in turns (0..1): shadows to blue violet, lights to warm sand.
COOL_HUE = 0.70
WARM_HUE = 0.11


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _lean(h, target, amount):
    d = ((target - h + 0.5) % 1.0) - 0.5
    return (h + d * amount) % 1.0


def shift(rgb, light=0.0, hue=0.0, sat=0.0):
    """The colour made lighter (light > 0, leaning warm) or darker (light < 0, leaning cool)."""
    r, g, b = (c / 255.0 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if light < 0:
        h = _lean(h, COOL_HUE, min(1.0, -light * 1.4) * (0.35 if hue == 0.0 else hue))
    elif light > 0:
        h = _lean(h, WARM_HUE, min(1.0, light * 1.4) * (0.3 if hue == 0.0 else hue))
    l = max(0.0, min(1.0, l + light))
    s = max(0.0, min(1.0, s + sat))
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return (round(r * 255), round(g * 255), round(b * 255))


class Material:
    """A material's ramp, darkest first: [deep, shade, base, lit] (or three tones), its outline,
    and how shiny it is (how much of the form takes the lit tone)."""

    def __init__(self, base, tones=4, step=0.085, sat=0.02, outline=None, shine=0.0, lit_step=None):
        base = hexrgb(base) if isinstance(base, str) else base
        lit_step = step if lit_step is None else lit_step
        if tones == 4:
            self.ramp = [shift(base, -2 * step, sat=sat), shift(base, -step, sat=sat * 0.5), base,
                         shift(base, lit_step, sat=-sat * 0.5)]
        elif tones == 3:
            self.ramp = [shift(base, -step * 1.3, sat=sat), base, shift(base, lit_step, sat=-sat * 0.5)]
        else:
            self.ramp = [shift(base, -step * 1.3, sat=sat), base]
        if outline is None:
            outline = shift(self.ramp[0], -0.13, hue=0.5, sat=0.05)
        self.outline = hexrgb(outline) if isinstance(outline, str) else outline
        self.shine = shine

    @property
    def deep(self):
        return self.ramp[0]

    def tone(self, value):
        """The tone for a lit value in 0..1 (0 is facing away from the light)."""
        n = len(self.ramp)
        # Thresholds bias toward the middle tones, so the lit tone is a highlight, not half the form.
        if n == 4:
            cuts = (0.2, 0.45, 0.8 - self.shine)
        elif n == 3:
            cuts = (0.3, 0.75 - self.shine)
        else:
            cuts = (0.4,)
        i = 0
        for c in cuts:
            if value > c:
                i += 1
        return i


class Part:
    def __init__(self, mask, material, z, form, centre, radii, tilt=0.0, bias=0.0, line=True,
                 axis=None):
        self.mask = mask  # set of (x, y)
        self.material = material
        self.z = z
        self.form = form  # 'sphere', 'cylinder', 'flat'
        self.centre = centre
        self.radii = radii
        self.bias = bias
        self.line = line
        self.axis = axis  # for a capsule: (ax, ay, bx, by, r)


class Canvas:
    def __init__(self, width, height):
        self.w = width
        self.h = height
        self.parts = []
        self.details = {}  # (x, y) -> rgb, drawn last and kept by cleanup
        self.overlays = []  # (x, y, rgba) drawn after everything, unlit (smears, glows)

    # --- shapes --------------------------------------------------------------------------------

    def _add(self, mask, material, z, form, centre, radii, **kw):
        mask = {(x, y) for (x, y) in mask if 0 <= x < self.w and 0 <= y < self.h}
        p = Part(mask, material, z, form, centre, radii, **kw)
        self.parts.append(p)
        return p

    def ellipse(self, cx, cy, rx, ry, material, z, form="sphere", clip=None, **kw):
        mask = set()
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                u = (x + 0.5 - cx) / rx
                v = (y + 0.5 - cy) / ry
                if u * u + v * v <= 1.0 and (clip is None or clip(x, y)):
                    mask.add((x, y))
        return self._add(mask, material, z, form, (cx, cy), (rx, ry), **kw)

    def capsule(self, ax, ay, bx, by, r, material, z, r2=None, clip=None, **kw):
        """A limb from (ax, ay) to (bx, by), r thick at a and r2 at b."""
        r2 = r if r2 is None else r2
        mask = set()
        lo_x, hi_x = int(min(ax, bx) - max(r, r2) - 1), int(max(ax, bx) + max(r, r2) + 2)
        lo_y, hi_y = int(min(ay, by) - max(r, r2) - 1), int(max(ay, by) + max(r, r2) + 2)
        dx, dy = bx - ax, by - ay
        ll = dx * dx + dy * dy or 1e-6
        for y in range(lo_y, hi_y):
            for x in range(lo_x, hi_x):
                px, py = x + 0.5, y + 0.5
                t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / ll))
                qx, qy = ax + dx * t, ay + dy * t
                rr = r + (r2 - r) * t
                if (px - qx) ** 2 + (py - qy) ** 2 <= rr * rr and (clip is None or clip(x, y)):
                    mask.add((x, y))
        return self._add(mask, material, z, "capsule", ((ax + bx) / 2, (ay + by) / 2), (r, r2),
                         axis=(ax, ay, bx, by, r, r2), **kw)

    def poly(self, points, material, z, form="cylinder", clip=None, **kw):
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        mask = set()
        for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
            for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
                if _inside(points, x + 0.5, y + 0.5) and (clip is None or clip(x, y)):
                    mask.add((x, y))
        cx = (min(xs) + max(xs)) / 2
        cy = (min(ys) + max(ys)) / 2
        return self._add(mask, material, z, form, (cx, cy), ((max(xs) - min(xs)) / 2 + 0.5,
                                                            (max(ys) - min(ys)) / 2 + 0.5), **kw)

    def box(self, x0, y0, x1, y1, material, z, form="flat", **kw):
        """A box from (x0, y0) to (x1, y1), both inclusive."""
        mask = {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}
        return self._add(mask, material, z, form, ((x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2),
                         ((x1 - x0 + 1) / 2, (y1 - y0 + 1) / 2), **kw)

    def mask(self, pixels, material, z, form="flat", centre=None, radii=None, **kw):
        pixels = set(pixels)
        if centre is None and pixels:
            xs = [p[0] for p in pixels]
            ys = [p[1] for p in pixels]
            centre = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2)
            radii = ((max(xs) - min(xs) + 1) / 2, (max(ys) - min(ys) + 1) / 2)
        return self._add(pixels, material, z, form, centre, radii, **kw)

    def dot(self, x, y, rgb):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.details[(x, y)] = hexrgb(rgb) if isinstance(rgb, str) else rgb

    def overlay(self, x, y, rgba):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.overlays.append((x, y, rgba))

    # --- render --------------------------------------------------------------------------------

    def _light(self, part, x, y):
        px, py = x + 0.5, y + 0.5
        if part.form == "flat":
            n = (0.0, 0.0, 1.0)
            v = 0.5
        elif part.form == "capsule":
            ax, ay, bx, by, r, r2 = part.axis
            dx, dy = bx - ax, by - ay
            ll = dx * dx + dy * dy or 1e-6
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / ll))
            rr = r + (r2 - r) * t
            ox, oy = (px - (ax + dx * t)) / rr, (py - (ay + dy * t)) / rr
            d2 = min(1.0, ox * ox + oy * oy)
            n = (ox, oy, math.sqrt(1.0 - d2))
        else:
            cx, cy = part.centre
            rx, ry = part.radii
            u = (px - cx) / rx
            w = (py - cy) / ry
            if part.form == "cylinder":
                # Rounded across x, a little down its length, so a torso is lit on its top left.
                w *= 0.45
            d2 = min(1.0, u * u + w * w)
            n = (u, w, math.sqrt(1.0 - d2))
        v = n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2]
        v = (v + 0.25) / 1.25
        return max(0.0, min(1.0, v + part.bias))

    def render(self, outline=True, cleanup=True, shadow=True):
        owner = {}
        for part in sorted(self.parts, key=lambda p: p.z):
            for px in part.mask:
                owner[px] = part
        tone = {}
        for (x, y), part in owner.items():
            t = part.material.tone(self._light(part, x, y))
            if shadow:
                # A part in front of this one, toward the light (up and left), shades it.
                for ox, oy in ((0, -1), (-1, -1), (0, -2)):
                    o = owner.get((x + ox, y + oy))
                    if o is not None and o is not part and o.z > part.z + 0.5:
                        t = max(0, t - 1)
                        break
            tone[(x, y)] = t
        if cleanup:
            tone = _clean(owner, tone)
        colour = {}
        for (x, y), part in owner.items():
            colour[(x, y)] = part.material.ramp[tone[(x, y)]]
        # Inner lines: where a part meets a part in front of it, below or beside, the part behind
        # takes its deep tone on that edge.
        for (x, y), part in owner.items():
            for ox, oy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                o = owner.get((x + ox, y + oy))
                if o is not None and o is not part and o.line and o.z > part.z + 0.5 \
                        and o.material is not part.material:
                    colour[(x, y)] = part.material.deep
                    break
        if outline:
            for (x, y), part in owner.items():
                edge = [(ox, oy) for ox, oy in ((0, -1), (-1, 0), (1, 0), (0, 1))
                        if (x + ox, y + oy) not in owner]
                if edge:
                    lit_side = all(e in ((0, -1), (-1, 0)) for e in edge)
                    colour[(x, y)] = part.material.deep if lit_side else part.material.outline
        for p, rgb in self.details.items():
            colour[p] = rgb
        image = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), rgb in colour.items():
            image.putpixel((x, y), tuple(rgb) + (255,))
        for x, y, rgba in self.overlays:
            if len(rgba) == 3:
                rgba = tuple(rgba) + (255,)
            under = image.getpixel((x, y))
            a = rgba[3] / 255.0
            if under[3] == 0:
                image.putpixel((x, y), tuple(rgba))
            else:
                image.putpixel((x, y), tuple(round(rgba[i] * a + under[i] * (1 - a)) for i in range(3)) + (255,))
        return image


def _inside(points, x, y):
    inside = False
    n = len(points)
    j = n - 1
    for i in range(n):
        xi, yi = points[i]
        xj, yj = points[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def _clean(owner, tone):
    """Stray single pixels take the tone around them, within one part."""
    out = dict(tone)
    for _ in range(2):
        changed = False
        for (x, y), part in owner.items():
            t = out[(x, y)]
            same = []
            for ox, oy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                q = (x + ox, y + oy)
                if owner.get(q) is part:
                    same.append(out[q])
            if len(same) >= 3 and t not in same:
                best = max(set(same), key=same.count)
                if same.count(best) >= 3:
                    out[(x, y)] = best
                    changed = True
        if not changed:
            break
    return out


def remove_orphans(image):
    """Drops opaque pixels with no opaque neighbour (stray dots outside a silhouette)."""
    w, h = image.size
    px = image.load()
    gone = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if not any(0 <= x + ox < w and 0 <= y + oy < h and px[x + ox, y + oy][3] > 0
                       for ox, oy in ((0, -1), (-1, 0), (1, 0), (0, 1))):
                gone.append((x, y))
    for p in gone:
        px[p] = (0, 0, 0, 0)
    return image


def check_no_danger(image, name=""):
    for p in image.getdata():
        if p[3] > 0 and tuple(p[:3]) == DANGER:
            raise SystemExit("Danger red in %s" % name)


def save(image, path):
    check_no_danger(image, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)


def sheet(images, zoom=4, cols=8, background=(40, 36, 46, 255)):
    """A zoomed contact sheet of images, for looking at a batch."""
    cols = min(cols, len(images))
    rows = (len(images) + cols - 1) // cols
    cw = max(i.width for i in images) * zoom + 8
    ch = max(i.height for i in images) * zoom + 8
    out = Image.new("RGBA", (cols * cw, rows * ch), background)
    for n, im in enumerate(images):
        big = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
        out.alpha_composite(big, ((n % cols) * cw + 4, (n // cols) * ch + 4))
    return out
