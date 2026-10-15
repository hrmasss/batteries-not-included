"""Small SVG drawing kit for BNI art.

Everything here writes plain SVG 1.1 that Godot's importer (ThorVG) renders the same as
librsvg: paths, basic shapes, linear and radial gradients, clip paths, opacity and transforms.
No filters, no text, no CSS, no patterns, no blend modes. Glow is drawn as light on a
transparent ground and blended additively by the engine.

Coordinates are author units: 4 per game pixel at 720p. A toy is about 360 units tall.
"""

from __future__ import annotations

import math
import os
import re
from dataclasses import dataclass, field

OUTLINE = 7.0  # the one outline weight for every playable thing, author units
DETAIL = 3.5  # inner molded detail lines
INK = "#1b2113"  # outline ink for green plastic; other materials pass their own


def f(v: float) -> str:
    """Compact number formatting."""
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


# ---------------------------------------------------------------- shape helpers

def smooth(points, closed=True, tension=1.0) -> str:
    """Catmull-Rom spline through points, as cubic Beziers.

    A point is (x, y) or (x, y, 'c') for a sharp corner.
    """
    pts = [(p[0], p[1], len(p) > 2 and p[2] == "c") for p in points]
    n = len(pts)
    if n < 2:
        return ""

    def tangent(i):
        x, y, sharp = pts[i]
        if sharp:
            return 0.0, 0.0
        if closed:
            a, b = pts[(i - 1) % n], pts[(i + 1) % n]
        else:
            if i == 0 or i == n - 1:
                return 0.0, 0.0
            a, b = pts[i - 1], pts[i + 1]
        return (b[0] - a[0]) / 6 * tension, (b[1] - a[1]) / 6 * tension

    d = [f"M{f(pts[0][0])} {f(pts[0][1])}"]
    segs = n if closed else n - 1
    for i in range(segs):
        j = (i + 1) % n
        t0, t1 = tangent(i), tangent(j)
        c1 = (pts[i][0] + t0[0], pts[i][1] + t0[1])
        c2 = (pts[j][0] - t1[0], pts[j][1] - t1[1])
        d.append(f"C{f(c1[0])} {f(c1[1])} {f(c2[0])} {f(c2[1])} {f(pts[j][0])} {f(pts[j][1])}")
    if closed:
        d.append("Z")
    return "".join(d)


def poly(points, closed=True) -> str:
    d = "M" + " L".join(f"{f(x)} {f(y)}" for x, y in points)
    return d + ("Z" if closed else "")


def ellipse_d(cx, cy, rx, ry) -> str:
    return (f"M{f(cx - rx)} {f(cy)}A{f(rx)} {f(ry)} 0 1 0 {f(cx + rx)} {f(cy)}"
            f"A{f(rx)} {f(ry)} 0 1 0 {f(cx - rx)} {f(cy)}Z")


def rrect_d(x, y, w, h, r) -> str:
    r = min(r, w / 2, h / 2)
    return (f"M{f(x + r)} {f(y)}H{f(x + w - r)}A{f(r)} {f(r)} 0 0 1 {f(x + w)} {f(y + r)}"
            f"V{f(y + h - r)}A{f(r)} {f(r)} 0 0 1 {f(x + w - r)} {f(y + h)}H{f(x + r)}"
            f"A{f(r)} {f(r)} 0 0 1 {f(x)} {f(y + h - r)}V{f(y + r)}A{f(r)} {f(r)} 0 0 1 {f(x + r)} {f(y)}Z")


def star_d(cx, cy, r_out, r_in, n, rot=0.0, jitter=None) -> str:
    pts = []
    for i in range(n * 2):
        a = math.radians(rot) + math.pi * i / n
        r = r_out if i % 2 == 0 else r_in
        if jitter:
            r *= jitter[i % len(jitter)]
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1: str, c2: str, t: float) -> str:
    """Mix two #rrggbb colours."""
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(lerp(x, y, t)):02x}" for x, y in zip(a, b))


def shade(c: str, k: float) -> str:
    """k < 0 darkens toward black, k > 0 lightens toward white."""
    return mix(c, "#000000", -k) if k < 0 else mix(c, "#ffffff", k)


# ---------------------------------------------------------------- document

@dataclass
class Doc:
    """One SVG file. Bounds are in author units; the file's pixel size equals them."""

    x0: float
    y0: float
    w: float
    h: float
    prefix: str = "a"
    defs: list = field(default_factory=list)
    body: list = field(default_factory=list)
    _n: int = 0

    def uid(self, stem="i") -> str:
        self._n += 1
        return f"{self.prefix}{stem}{self._n}"

    # defs ---------------------------------------------------------------
    def lin(self, x1, y1, x2, y2, stops, units="userSpaceOnUse") -> str:
        i = self.uid("g")
        s = "".join(_stop(o, c) for o, c in stops)
        self.defs.append(f'<linearGradient id="{i}" gradientUnits="{units}" x1="{f(x1)}" y1="{f(y1)}" '
                         f'x2="{f(x2)}" y2="{f(y2)}">{s}</linearGradient>')
        return f"url(#{i})"

    def rad(self, cx, cy, r, stops, fx=None, fy=None, transform=None) -> str:
        i = self.uid("g")
        s = "".join(_stop(o, c) for o, c in stops)
        foc = f' fx="{f(fx)}" fy="{f(fy)}"' if fx is not None else ""
        tr = f' gradientTransform="{transform}"' if transform else ""
        self.defs.append(f'<radialGradient id="{i}" gradientUnits="userSpaceOnUse" cx="{f(cx)}" '
                         f'cy="{f(cy)}" r="{f(r)}"{foc}{tr}>{s}</radialGradient>')
        return f"url(#{i})"

    def clip(self, d: str) -> str:
        i = self.uid("c")
        self.defs.append(f'<clipPath id="{i}"><path d="{d}"/></clipPath>')
        return f"url(#{i})"

    # body ---------------------------------------------------------------
    def add(self, s: str):
        self.body.append(s)

    def path(self, d, fill="none", stroke=None, sw=None, op=None, extra="", into=None):
        a = [f'd="{d}"', f'fill="{fill}"']
        if stroke:
            a += [f'stroke="{stroke}"', f'stroke-width="{f(sw or OUTLINE)}"',
                  'stroke-linejoin="round"', 'stroke-linecap="round"']
        if op is not None and op < 1:
            a.append(f'opacity="{f(op)}"')
        if extra:
            a.append(extra)
        s = f"<path {' '.join(a)}/>"
        (into if into is not None else self.body).append(s)
        return s

    def open_group(self, attrs=""):
        self.body.append(f"<g {attrs}>" if attrs else "<g>")

    def close_group(self):
        self.body.append("</g>")

    def svg(self) -> str:
        defs = f"<defs>{''.join(self.defs)}</defs>" if self.defs else ""
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{f(self.w)}" height="{f(self.h)}" '
                f'viewBox="{f(self.x0)} {f(self.y0)} {f(self.w)} {f(self.h)}">'
                f"{defs}{''.join(self.body)}</svg>\n")

    def save(self, path: str):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write(_header(path) + self.svg())


def _stop(o, c):
    if isinstance(c, tuple):
        c, a = c
        return f'<stop offset="{f(o)}" stop-color="{c}" stop-opacity="{f(a)}"/>'
    return f'<stop offset="{f(o)}" stop-color="{c}"/>'


def _header(path):
    return ("<!-- Batteries Not Included. CC BY-SA 4.0, see assets/LICENSE.md. "
            "Generated by art/src; edit the generator, not this file. -->\n")


# ---------------------------------------------------------------- materials

@dataclass
class Plastic:
    """Molded plastic: base, shadow and light tones, a warm rim light and ink."""

    base: str
    light: str
    shadow: str
    deep: str
    rim: str
    ink: str = INK
    spec: str = "#ffffff"


def molded(doc: Doc, d: str, m: Plastic, light=(-1, -1), band=10.0, rim=4.0,
           gloss=None, shadows=(), details=(), lights=(), outline=True, grad=None, sw=None, union=False):
    """Draw one molded plastic shape.

    Layers, inside the shape's clip: rim light, shadow band and a lit body made from
    offset copies of the shape (light from `light` direction), then extra shadow shapes,
    detail lines, light shapes and gloss. The outline goes last, or first and doubled when
    `union` is set, so a shape made of overlapping blobs only shows its outer edge.
    gloss: list of (d, opacity). shadows: list of (d, colour or None, opacity).
    """
    if union and outline:
        doc.path(d, stroke=m.ink, sw=(sw or OUTLINE) * 2)
    lx, ly = light
    n = math.hypot(lx, ly) or 1
    ux, uy = lx / n, ly / n
    clip = doc.clip(d)
    doc.open_group(f'clip-path="{clip}"')
    doc.path(d, fill=m.rim)
    doc.path(d, fill=m.shadow, extra=f'transform="translate({f(ux * rim)} {f(uy * rim)})"')
    body = grad or m.base
    doc.path(d, fill=body, extra=f'transform="translate({f(ux * (rim + band))} {f(uy * (rim + band))})"')
    for item in shadows:
        sd, col, op = (item + (None, None))[:3] if isinstance(item, tuple) else (item, None, None)
        doc.path(sd, fill=col or m.shadow, op=op if op is not None else 1)
    for dd in details:
        if isinstance(dd, tuple):
            dd, col, w = (dd + (None, None))[:3]
        else:
            col, w = None, None
        doc.path(dd, stroke=col or m.deep, sw=w or DETAIL)
    for item in lights:
        ld, col, op = (item + (None, None))[:3] if isinstance(item, tuple) else (item, None, None)
        doc.path(ld, fill=col or m.light, op=op if op is not None else 1)
    for gd, op in (gloss or ()):
        doc.path(gd, fill=m.spec, op=op)
    doc.close_group()
    if outline and not union:
        doc.path(d, stroke=m.ink, sw=sw or OUTLINE)


def flat(doc: Doc, d: str, fill: str, ink=INK, sw=None, op=None):
    doc.path(d, fill=fill, op=op)
    if ink:
        doc.path(d, stroke=ink, sw=sw or OUTLINE)


# ---------------------------------------------------------------- svg merging

_ID = re.compile(r'id="([^"]+)"')


def inner(svg_text: str, prefix: str) -> str:
    """Strip the outer <svg>, prefix every id so files can be merged into one document."""
    body = re.sub(r"<!--.*?-->", "", svg_text, flags=re.S)
    body = re.sub(r"^\s*<svg[^>]*>", "", body.strip())
    body = re.sub(r"</svg>\s*$", "", body)
    ids = set(_ID.findall(body))
    for i in sorted(ids, key=len, reverse=True):
        body = body.replace(f'id="{i}"', f'id="{prefix}{i}"').replace(f"url(#{i})", f"url(#{prefix}{i})")
        body = body.replace(f'href="#{i}"', f'href="#{prefix}{i}"')
    return body


def viewbox(svg_text: str):
    m = re.search(r'viewBox="([^"]+)"', svg_text)
    return [float(v) for v in m.group(1).split()]
