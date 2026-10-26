#!/usr/bin/env python3
"""Recolour PNGs into the master palette (#76).

  python3 -I scripts/recolour_palette.py IN.png OUT.png [--palette assets/palette/master.hex]
  python3 -I scripts/recolour_palette.py --verify FILE... [--palette ...]

Nearest palette colour by squared RGB distance (ties to the first listed), no
dither. Alpha is copied byte for byte; transparent pixels also take a palette
colour. --verify exits non-zero if any opaque pixel is not a palette colour.
Only stdlib plus `magick` (paths are passed as arguments, no shell).
"""
import argparse
import os
import subprocess
import sys

DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "palette", "master.hex")


def load_palette(path):
    out = []
    with open(path) as f:
        for line in f:
            s = line.strip().lstrip("#")
            if s:
                out.append(tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)))
    return out


def read_rgba(path):
    w, h = (int(v) for v in subprocess.run(
        ["magick", path, "-format", "%w %h", "info:"], check=True, capture_output=True, text=True).stdout.split())
    rgb = subprocess.run(["magick", path, "-alpha", "off", "-depth", "8", "rgb:-"],
                         check=True, capture_output=True).stdout
    al = subprocess.run(["magick", path, "-alpha", "extract", "-depth", "8", "gray:-"],
                        check=True, capture_output=True).stdout
    return w, h, rgb, al


def nearest(c, pal):
    return min(pal, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def recolour(src, dst, pal):
    w, h, rgb, al = read_rgba(src)
    cache, out = {}, bytearray()
    for i in range(w * h):
        k = rgb[3 * i:3 * i + 3]
        if k not in cache:
            cache[k] = bytes(nearest(tuple(k), pal))
        out += cache[k]
        out.append(al[i])
    subprocess.run(["magick", "-size", f"{w}x{h}", "-depth", "8", "rgba:-", "PNG32:" + dst],
                   check=True, input=bytes(out), capture_output=True)


def verify(files, pal):
    ok = True
    pset = set(pal)
    for f in files:
        w, h, rgb, al = read_rgba(f)
        bad = sum(1 for i in range(w * h)
                  if al[i] and tuple(rgb[3 * i:3 * i + 3]) not in pset)
        print(f"{'OK  ' if not bad else 'FAIL'} {f}" + (f" ({bad} pixels off palette)" if bad else ""))
        ok = ok and not bad
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--palette", default=DEFAULT)
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    pal = load_palette(a.palette)
    if a.verify:
        sys.exit(0 if verify(a.files, pal) else 1)
    if len(a.files) != 2:
        ap.error("need IN.png OUT.png")
    recolour(a.files[0], a.files[1], pal)


if __name__ == "__main__":
    main()
