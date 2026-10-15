"""Bedroom map kit: playable props and a muted backdrop.

Run: python3 art/src/bedroom.py  (writes assets/maps/bedroom/*.svg and kit.json)

Scale: 30 author px per cm, so the 360 px soldier is a 12 cm toy and the room is 240 cm
tall (7200 px, 1800 game px). Playable props are saturated, shaded and inked at the toys'
line weight. The backdrop is pale, low-contrast and inked softly, so a player always knows
what they can stand on (US-38.4, art ref 16).

Props stand on the floor with their origin at the bottom-left corner (x right, y up is
negative). The fan hangs from its origin at the ceiling. Collision shapes are polygons in px
from the file's top-left: "solid" blocks everything, "platform" is stood on from above.
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bni_svg import (DETAIL, OUTLINE, Doc, Plastic, ellipse_d, f, mix, molded, poly,  # noqa: E402
                     rrect_d, shade, smooth)

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "maps", "bedroom")
CM = 30

INK = "#22170f"
OAK = Plastic(base="#cf8f52", light="#f0bd80", shadow="#9c5f30", deep="#6e3f1e", rim="#ffd9a3", ink=INK)
WALNUT = Plastic(base="#b0643a", light="#dc8f5c", shadow="#7c3f1f", deep="#552812", rim="#f2b07c", ink=INK)
PINE = Plastic(base="#e0ad6c", light="#f8d39c", shadow="#b17a40", deep="#7f5425", rim="#ffe7bf", ink=INK)
RED_PAINT = Plastic(base="#d9443a", light="#ff806b", shadow="#9c2820", deep="#6b1813", rim="#ffb08c", ink=INK)
YELLOW_PAINT = Plastic(base="#f4c53a", light="#ffe48a", shadow="#c2901a", deep="#8a6410", rim="#fff1b8", ink=INK)
MINT = Plastic(base="#58b99a", light="#93e3c6", shadow="#2f8569", deep="#1c5c47", rim="#c2f5e2", ink=INK)
CREAM = Plastic(base="#f0e7d4", light="#fffaf0", shadow="#cbbd9f", deep="#9a8c70", rim="#fff7e4", ink=INK)
WHITE = Plastic(base="#f3f0ea", light="#ffffff", shadow="#cfc9be", deep="#a29b8f", rim="#ffffff", ink=INK)
BRASS = Plastic(base="#d6a23e", light="#ffe08a", shadow="#9a6c1c", deep="#6a4610", rim="#fff0c0", ink=INK)
STEEL = Plastic(base="#9aa2ad", light="#d7dde4", shadow="#68707b", deep="#474e57", rim="#e8edf2", ink=INK)
GLASS = Plastic(base="#bfe6f0", light="#ffffff", shadow="#86bccb", deep="#5a8f9e", rim="#e8fbff", ink=INK)
TEAL = Plastic(base="#2fa3a0", light="#6fd8d2", shadow="#1d6e6c", deep="#124b49", rim="#b4f2ee", ink=INK)
NAVY = Plastic(base="#34508f", light="#6b8bd0", shadow="#22366a", deep="#152246", rim="#b2c6f2", ink=INK)
MUSTARD = Plastic(base="#e0a52c", light="#ffd06e", shadow="#a8741a", deep="#73500f", rim="#ffe6a6", ink=INK)
PLUM = Plastic(base="#8e4f8f", light="#c385c4", shadow="#5f3061", deep="#3f1e40", rim="#e6c2e7", ink=INK)
LEAF = Plastic(base="#5f9e3a", light="#94cf66", shadow="#3e6e24", deep="#284a17", rim="#c8ec9e", ink=INK)
BOOKS = [RED_PAINT, NAVY, MUSTARD, TEAL, PLUM, LEAF, CREAM, WALNUT]

KIT = {}


def save(doc, name, origin, collision=(), kind="prop", note=""):
    doc.save(os.path.join(OUT, f"{name}.svg"))
    shapes = []
    for c in collision:
        pts = [[round(x - doc.x0, 1), round(y - doc.y0, 1)] for x, y in c["poly"]]
        shapes.append({"type": c["type"], "poly": pts})
    KIT[name] = {"file": f"{name}.svg", "kind": kind, "size": [doc.w, doc.h],
                 "origin": [origin[0] - doc.x0, origin[1] - doc.y0], "collision": shapes}
    if note:
        KIT[name]["note"] = note


def box(x0, y0, x1, y1, kind="solid"):
    return {"type": kind, "poly": [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]}


def grain(doc, x0, y0, x1, y1, rng, m, n=6, op=0.35, vertical=False):
    """Wavy wood grain lines inside a board."""
    for i in range(n):
        if vertical:
            x = x0 + (x1 - x0) * (i + 0.5) / n + (rng.random() - 0.5) * 8
            pts = [(x + math.sin(t * 2.3 + i) * 6, y0 + (y1 - y0) * t) for t in (0.05, 0.3, 0.55, 0.8, 0.95)]
        else:
            y = y0 + (y1 - y0) * (i + 0.5) / n + (rng.random() - 0.5) * 6
            pts = [(x0 + (x1 - x0) * t, y + math.sin(t * 5 + i * 1.7) * 4) for t in (0.04, 0.3, 0.55, 0.8, 0.96)]
        doc.path(smooth(pts, closed=False), stroke=m.deep, sw=2.5, op=op)
    if (x1 - x0) * (y1 - y0) > 60000 and rng.random() < 0.8:
        cx, cy = x0 + (x1 - x0) * (0.2 + rng.random() * 0.6), y0 + (y1 - y0) * (0.25 + rng.random() * 0.5)
        doc.path(ellipse_d(cx, cy, 16, 7), stroke=m.deep, sw=2.5, op=op)
        doc.path(ellipse_d(cx, cy, 6, 2.5), fill=m.deep, op=op)


def board(doc, x0, y0, x1, y1, m, rng, r=10, band=None, vertical=None, n=None):
    w, h = x1 - x0, y1 - y0
    vertical = h > w if vertical is None else vertical
    band = band or max(8, min(w, h) * 0.18)
    d = rrect_d(x0, y0, w, h, r)
    g = doc.lin(x0, y0, x1 if not vertical else x0, y1 if not vertical else y0,
                [(0, mix(m.base, m.light, 0.35)), (1, m.base)]) if not vertical else \
        doc.lin(x0, y0, x1, y0, [(0, mix(m.base, m.light, 0.35)), (0.6, m.base), (1, mix(m.base, m.shadow, 0.3))])
    molded(doc, d, m, band=band, rim=7, grad=g)
    clip = doc.clip(d)
    doc.open_group(f'clip-path="{clip}"')
    grain(doc, x0, y0, x1, y1, rng, m, n=n or max(2, int((w if vertical else h) / 40)), vertical=vertical)
    doc.close_group()
    doc.path(d, stroke=m.ink, sw=OUTLINE)


def contact_shadow(doc, x0, x1, y, h=40, op=0.35):
    g = doc.rad((x0 + x1) / 2, y, (x1 - x0) / 2, [(0, ("#1a1008", op)), (1, ("#1a1008", 0))],
                transform=f"translate({f((x0 + x1) / 2)} {f(y)}) scale(1 {f(h / ((x1 - x0) / 2))}) "
                          f"translate({f(-(x0 + x1) / 2)} {f(-y)})")
    doc.path(ellipse_d((x0 + x1) / 2, y, (x1 - x0) / 2, h), fill=g)


# ---------------------------------------------------------------- floor

def floor():
    """A seamless strip of floorboards: a receding top band behind the walking line (y=0)
    and the boards' front edge below it."""
    rng = random.Random(1)
    w, back, front = 1536, 90, 180
    doc = Doc(0, -back - 4, w, back + front + 8, prefix="fl")
    # top surface, planks running left-right with staggered butt joints
    rows = 3
    tones = [OAK.base, mix(OAK.base, OAK.light, 0.25), mix(OAK.base, OAK.shadow, 0.2)]
    for r in range(rows):
        y0 = -back + r * back / rows
        y1 = y0 + back / rows
        doc.path(f"M0 {f(y0)}H{w}V{f(y1)}H0Z", fill=tones[r % 3])
        joints = [(w * (0.18 + 0.33 * r) + k * w / 2) % w for k in range(2)]
        for jx in joints:
            doc.path(f"M{f(jx)} {f(y0)}V{f(y1)}", stroke=OAK.deep, sw=3, op=0.6)
        doc.path(f"M0 {f(y1)}H{w}", stroke=OAK.deep, sw=2.5, op=0.5)
        for k in range(3):
            gx = rng.random() * w
            doc.path(f"M{f(gx)} {f(y0 + 8)}h{f(140 + rng.random() * 120)}", stroke=OAK.shadow, sw=2, op=0.5)
    # back edge fades toward the skirting
    doc.path(f"M0 {-back}H{w}V{-back + 26}H0Z", fill=doc.lin(0, -back, 0, -back + 26,
                                                                  [(0, ("#3b2412", 0.45)), (1, ("#3b2412", 0))]))
    # front edge: a thick board face, the solid you stand on
    face = f"M-10 0H{w + 10}V{front}H-10Z"
    g = doc.lin(0, 0, 0, front, [(0, OAK.shadow), (0.15, mix(OAK.shadow, OAK.deep, 0.3)), (1, "#3a2110")])
    doc.path(face, fill=g)
    doc.path(f"M0 6H{w}", stroke=OAK.rim, sw=5, op=0.8)
    for jx in (w * 0.1, w * 0.6):
        doc.path(f"M{f(jx)} 0V{front}", stroke="#2a170a", sw=3, op=0.7)
    doc.path(f"M-10 0H{w + 10}", stroke=INK, sw=OUTLINE)
    save(doc, "floor", origin=(0, 0), kind="tile",
         collision=[box(0, 0, w, front)],
         note="tiles horizontally; y=0 is the walking line")


# ---------------------------------------------------------------- bed

def bed():
    rng = random.Random(2)
    W, top = 140 * CM, -1200
    leg_h, rail_top = 420, -640
    doc = Doc(-30, -2440, W + 60, 2470, prefix="bd")
    contact_shadow(doc, 80, W - 80, 0, 50, 0.45)
    # under-bed shadow (open space toys can walk through)
    doc.path(f"M160 {-leg_h}H{W - 160}V0H160Z",
             fill=doc.lin(0, -leg_h, 0, 0, [(0, ("#20140c", 0.55)), (1, ("#20140c", 0.15))]))
    # posts and boards
    board(doc, 0, -2400, 200, 0, WALNUT, rng, r=24)
    board(doc, W - 200, -1700, W, 0, WALNUT, rng, r=24)
    # headboard and footboard caps
    for x0, x1, y in ((-20, 220, -2400), (W - 220, W + 20, -1700)):
        molded(doc, rrect_d(x0, y - 50, x1 - x0, 80, 30), WALNUT, band=12, rim=7,
               gloss=[(rrect_d(x0 + 30, y - 40, x1 - x0 - 100, 12, 6), 0.45)])
    # headboard panel with a moon cut-out
    molded(doc, rrect_d(200, -2200, 140, 1000, 20), WALNUT, band=16, rim=7)
    # side rail
    board(doc, 160, rail_top, W - 160, -leg_h, WALNUT, rng, r=14, vertical=False, n=4)
    # mattress
    mat = rrect_d(200, top, W - 400, rail_top - top + 8, 40)
    molded(doc, mat, CREAM, band=24, rim=8,
           details=[(f"M240 {top + 90}H{W - 240}", CREAM.shadow, 5)])
    # quilt over the top, draping down the front
    quilt = smooth([(190, top - 30, "c"), (W - 190, top - 30, "c"), (W - 186, top + 160), (W - 240, top + 330),
                    (W - 600, top + 300), (W - 1100, top + 360), (W - 1700, top + 300), (W - 2300, top + 360),
                    (W - 2900, top + 300), (900, top + 350), (420, top + 300), (200, top + 180, "c")])
    clip = doc.clip(quilt)
    molded(doc, quilt, TEAL, band=26, rim=8, grad=doc.lin(0, top - 30, 0, top + 360,
                                                          [(0, mix(TEAL.base, TEAL.light, 0.3)), (1, TEAL.base)]))
    doc.open_group(f'clip-path="{clip}"')
    # patchwork squares
    pal = [MUSTARD, TEAL, CREAM, RED_PAINT, TEAL, MUSTARD, NAVY]
    sq = 300
    for i, x in enumerate(range(200, W - 200, sq)):
        for j, y in enumerate((top - 40, top + 160)):
            m = pal[(i * 3 + j * 2) % len(pal)]
            if (i + j) % 2 == 0:
                doc.path(rrect_d(x + 10, y + 10, sq - 20, 190, 10), fill=m.base, op=0.85)
                doc.path(rrect_d(x + 10, y + 10, sq - 20, 190, 10), stroke=m.deep, sw=4, op=0.5,
                         extra='stroke-dasharray="14 10"')
    doc.path(f"M190 {top + 150}H{W - 190}", stroke=TEAL.deep, sw=5, op=0.5)
    doc.path(f"M190 {top - 30}H{W - 190}V{top + 10}H190Z", fill=TEAL.light, op=0.35)
    doc.close_group()
    doc.path(quilt, stroke=INK, sw=OUTLINE)
    # pillow
    pillow = smooth([(260, top - 40), (300, top - 250), (700, top - 300), (1080, top - 260), (1120, top - 40)])
    molded(doc, pillow, WHITE, band=22, rim=8,
           details=[(smooth([(420, top - 240), (560, top - 160), (520, top - 60)], closed=False), WHITE.shadow, 5)],
           gloss=[(smooth([(380, top - 240), (600, top - 278), (520, top - 220), (380, top - 200)]), 0.6)])
    for x in (500, 700, 900):
        doc.path(smooth([(x, top - 290 + abs(x - 690) * 0.08), (x + 30, top - 40)], closed=False),
                 stroke=NAVY.base, sw=14, op=0.8)
    collision = [
        box(0, -2400, 200, 0), box(W - 200, -1700, W, 0),
        box(200, top - 30, W - 200, rail_top),        # mattress and quilt: stand on top
        box(160, rail_top, W - 160, -leg_h),          # side rail; open below for walking under
        {"type": "platform", "poly": [(300, top - 250), (700, top - 300), (1080, top - 260), (1100, top - 40),
                                      (280, top - 40)]},
    ]
    save(doc, "bed", origin=(0, 0), collision=collision, note="open under the rail: a toy fits underneath")


# ---------------------------------------------------------------- bookshelf

def bookshelf():
    rng = random.Random(3)
    W, H, side, shelf = 60 * CM, 100 * CM, 90, 80
    doc = Doc(-30, -H - 40, W + 60, H + 70, prefix="bs")
    contact_shadow(doc, 40, W - 40, 0, 40, 0.45)
    # back panel: inside the shelf, darker and calmer (not solid)
    back = f"M{side} {-H + 100}H{W - side}V-140H{side}Z"
    doc.path(back, fill=doc.lin(0, -H, 0, 0, [(0, mix(WALNUT.shadow, "#3d2a20", 0.4)),
                                                (1, mix(WALNUT.shadow, "#2a1a10", 0.5))]))
    for x in range(side + 150, W - side, 300):
        doc.path(f"M{x} {-H + 100}V-140", stroke="#2a1a10", sw=4, op=0.5)
    levels = [-140, -1000, -1860]  # shelf tops, floor to top
    collision = []
    # books on each level
    for li, ytop in enumerate(levels):
        x = side + 20
        limit = W - side - 20
        k = 0
        while x < limit - 60:
            style = rng.random()
            m = BOOKS[(k * 3 + li * 2) % len(BOOKS)]
            k += 1
            if style < 0.12 and x < limit - 400:  # a lying stack
                sx = x
                y = ytop
                for s in range(3):
                    bw = 340 - s * 30
                    bh = 70 + rng.random() * 20
                    mm = BOOKS[(k + s) % len(BOOKS)]
                    molded(doc, rrect_d(sx + s * 10, y - bh, bw, bh, 8), mm, band=10, rim=6,
                           details=[(f"M{f(sx + s * 10 + 30)} {f(y - bh + 14)}V{f(y - 14)}", mm.deep, 4)])
                    y -= bh
                collision.append(box(sx, y, sx + 340, ytop, "solid"))
                x += 360
                continue
            bw = 70 + rng.random() * 60
            bh = 520 + rng.random() * 220
            if style > 0.9 and x < limit - 200:  # a leaning book
                lean = 14
                d = rrect_d(x, ytop - bh, bw, bh, 10)
                doc.open_group(f'transform="rotate({lean} {f(x + bw)} {f(ytop)})"')
                molded(doc, d, m, band=10, rim=6)
                doc.close_group()
                x += bw + 140
                continue
            d = rrect_d(x, ytop - bh, bw, bh, 10)
            molded(doc, d, m, band=10, rim=6,
                   details=[(f"M{f(x + 10)} {f(ytop - bh + 60)}H{f(x + bw - 10)}", m.light, 6),
                            (f"M{f(x + 10)} {f(ytop - 60)}H{f(x + bw - 10)}", m.light, 6)],
                   lights=[(rrect_d(x + bw * 0.3, ytop - bh * 0.62, bw * 0.4, bh * 0.22, 6), m.light, 0.55)])
            collision.append(box(x, ytop - bh, x + bw, ytop, "platform"))
            x += bw + 6
    # top: a plant pot and a little globe-free clutter
    pot_x = W * 0.62
    molded(doc, smooth([(pot_x - 120, -H - 2, "c"), (pot_x + 120, -H - 2, "c"), (pot_x + 90, -H + 200, "c"),
                        (pot_x - 90, -H + 200, "c")]), RED_PAINT, band=16, rim=7)
    # structure: sides, shelves, top, plinth
    board(doc, 0, -H, side, 0, WALNUT, rng, r=16)
    board(doc, W - side, -H, W, 0, WALNUT, rng, r=16)
    for ytop in levels[1:]:
        board(doc, side - 10, ytop, W - side + 10, ytop + shelf, WALNUT, rng, r=10, n=2)
        collision.append(box(side, ytop, W - side, ytop + shelf, "platform"))
    board(doc, -24, -H - 20, W + 24, -H + 90, WALNUT, rng, r=14, n=2)
    board(doc, side - 10, -140, W - side + 10, 0, WALNUT, rng, r=10, n=3)
    collision += [box(0, -H, side, 0), box(W - side, -H, W, 0), box(-24, -H - 20, W + 24, -H + 90),
                  box(side, -140, W - side, 0)]
    # leaves over the top edge
    pot_top = -H - 2
    for ang, ln in ((-60, 260), (-100, 300), (-135, 240), (-20, 200), (-160, 180)):
        a = math.radians(ang)
        tipx, tipy = pot_x + math.cos(a) * ln, pot_top - 20 + math.sin(a) * ln
        mx, my = pot_x + math.cos(a) * ln * 0.5, pot_top - 20 + math.sin(a) * ln * 0.5
        nx, ny = -math.sin(a) * 50, math.cos(a) * 50
        leaf = smooth([(pot_x, pot_top - 10, "c"), (mx + nx, my + ny), (tipx, tipy, "c"), (mx - nx, my - ny)])
        molded(doc, leaf, LEAF, band=10, rim=6,
               details=[(smooth([(pot_x, pot_top - 10), (mx, my), (tipx, tipy)], closed=False), LEAF.deep, 3)])
    collision.append(box(pot_x - 120, -H - 2, pot_x + 120, -H + 200))
    save(doc, "bookshelf", origin=(0, 0), collision=collision,
         note="shelves are platforms; the dark back panel is not solid")


# ---------------------------------------------------------------- desk

def desk():
    rng = random.Random(4)
    W, H, th = 100 * CM, 70 * CM, 100
    doc = Doc(-60, -H - 1060, W + 120, H + 1090, prefix="dk")
    contact_shadow(doc, 0, 900, 0, 40, 0.45)
    contact_shadow(doc, W - 200, W, 0, 30, 0.4)
    # under-desk shadow
    doc.path(f"M900 {-H + th}H{W - 150}V{-H + th + 420}H900Z",
             fill=doc.lin(0, -H + th, 0, -H + th + 420, [(0, ("#20140c", 0.35)), (1, ("#20140c", 0))]))
    # drawer unit
    molded(doc, rrect_d(0, -H + th - 10, 900, H - th + 10, 16), MINT, band=20, rim=8,
           grad=doc.lin(0, 0, 900, 0, [(0, mix(MINT.base, MINT.light, 0.3)), (1, MINT.base)]))
    for i in range(3):
        y0 = -H + th + 40 + i * 640
        molded(doc, rrect_d(50, y0, 800, 590, 20), MINT, band=14, rim=7,
               gloss=[(rrect_d(80, y0 + 20, 500, 14, 7), 0.4)])
        molded(doc, ellipse_d(450, y0 + 160, 50, 50), BRASS, band=8, rim=5,
               gloss=[(ellipse_d(436, y0 + 146, 14, 10), 0.8)])
    # right leg
    board(doc, W - 150, -H + th - 10, W - 50, 0, PINE, rng, r=12)
    molded(doc, rrect_d(W - 170, -40, 140, 40, 10), PINE, band=8, rim=5)
    # top
    board(doc, -40, -H, W + 40, -H + th, PINE, rng, r=18, n=3)
    collision = [box(-40, -H, W + 40, -H + th), box(0, -H + th, 900, 0), box(W - 150, -H + th, W - 50, 0)]
    # on the desk: lamp, pencil cup, notebooks
    ytop = -H
    # notebooks
    for s, (m, bw, bh) in enumerate(((NAVY, 760, 70), (MUSTARD, 700, 60), (RED_PAINT, 620, 80))):
        x0 = 1900 + s * 30
        molded(doc, rrect_d(x0, ytop - bh, bw, bh, 8), m, band=10, rim=6,
               details=[(f"M{f(x0 + 40)} {f(ytop - bh + 12)}V{f(ytop - 12)}", m.deep, 4)])
        ytop -= bh
    collision.append(box(1900, ytop, 2660, -H))
    # pencil cup
    cup = smooth([(1500, -H - 420, "c"), (1760, -H - 420, "c"), (1740, -H, "c"), (1520, -H, "c")])
    for i, (m, dx, h) in enumerate(((RED_PAINT, 0, 280), (TEAL, 60, 340), (MUSTARD, 120, 250), (NAVY, 180, 310))):
        x = 1540 + dx
        molded(doc, rrect_d(x, -H - 420 - h, 44, h + 60, 8), m, band=6, rim=4)
        doc.path(poly([(x, -H - 420 - h), (x + 22, -H - 470 - h), (x + 44, -H - 420 - h)]), fill=CREAM.base,
                 stroke=INK, sw=OUTLINE)
    molded(doc, cup, PLUM, band=18, rim=7, gloss=[(rrect_d(1530, -H - 390, 40, 300, 20), 0.4)])
    collision.append(box(1500, -H - 420, 1760, -H))
    # lamp: base, arm, shade
    lx = 400
    molded(doc, ellipse_d(lx, -H - 30, 220, 50), NAVY, band=12, rim=6)
    for a, b in (((lx, -H - 60), (lx + 140, -H - 600)), ((lx + 140, -H - 600), (lx + 520, -H - 820))):
        doc.path(f"M{f(a[0])} {f(a[1])}L{f(b[0])} {f(b[1])}", stroke=INK, sw=46)
        doc.path(f"M{f(a[0])} {f(a[1])}L{f(b[0])} {f(b[1])}", stroke=STEEL.base, sw=30)
        doc.path(f"M{f(a[0] - 6)} {f(a[1])}L{f(b[0] - 6)} {f(b[1])}", stroke=STEEL.light, sw=8)
    molded(doc, ellipse_d(lx + 140, -H - 600, 34, 34), STEEL, band=6, rim=4)
    shade_d = smooth([(lx + 420, -H - 900, "c"), (lx + 600, -H - 900, "c"), (lx + 720, -H - 640, "c"),
                      (lx + 300, -H - 640, "c")])
    molded(doc, shade_d, NAVY, band=18, rim=7, gloss=[(rrect_d(lx + 440, -H - 880, 30, 180, 15), 0.45)])
    doc.path(ellipse_d(lx + 510, -H - 640, 210, 30), fill="#fff3c4")
    collision += [box(lx - 220, -H - 80, lx + 220, -H),
                  {"type": "platform", "poly": [(lx + 420, -H - 900), (lx + 600, -H - 900), (lx + 600, -H - 870),
                                                (lx + 420, -H - 870)]}]
    save(doc, "desk", origin=(0, 0), collision=collision, note="the lamp's light is in desk_lamp_glow (add)")
    # lamp glow for additive blending
    g = Doc(-700, -700, 1400, 1400, prefix="lg")
    gr = g.rad(0, 0, 700, [(0, ("#fff2c2", 0.75)), (0.3, ("#ffd27a", 0.35)), (1, ("#ffb040", 0))])
    g.path(ellipse_d(0, 0, 700, 700), fill=gr)
    g.save(os.path.join(OUT, "desk_lamp_glow.svg"))
    KIT["desk_lamp_glow"] = {"file": "desk_lamp_glow.svg", "kind": "light", "size": [1400, 1400],
                             "origin": [700, 700], "blend": "add", "collision": [],
                             "note": f"centre it on the lamp mouth: desk px {lx + 510 - doc.x0}, {-H - 640 - doc.y0}"}


# ---------------------------------------------------------------- wall shelf

def wall_shelf():
    rng = random.Random(5)
    W, th = 50 * CM, 90
    doc = Doc(-40, -700, W + 80, 1100, prefix="ws")
    # brackets
    for x in (220, W - 220):
        br = smooth([(x - 26, 0, "c"), (x + 26, 0, "c"), (x + 26, 40, "c"), (x - 120, 300, "c"), (x - 150, 290, "c"),
                     (x - 26, 60, "c")])
        molded(doc, smooth([(x - 26, th, "c"), (x + 26, th, "c"), (x + 26, th + 300, "c"), (x - 26, th + 300, "c")]),
               STEEL, band=8, rim=5)
        molded(doc, smooth([(x + 20, th, "c"), (x + 24, th + 40, "c"), (x - 180, th + 40, "c"), (x - 184, th, "c")]),
               STEEL, band=6, rim=4)
        doc.path(f"M{x - 160} {th + 30}L{x + 10} {th + 280}", stroke=INK, sw=26)
        doc.path(f"M{x - 160} {th + 30}L{x + 10} {th + 280}", stroke=STEEL.base, sw=12)
        _ = br
    board(doc, -20, 0, W + 20, th, OAK, rng, r=14, n=2)
    collision = [box(-20, 0, W + 20, th, "platform")]
    # marble jar
    jx = 260
    jar = smooth([(jx - 130, -380, "c"), (jx + 130, -380, "c"), (jx + 150, -300), (jx + 150, -20), (jx + 120, 0, "c"),
                  (jx - 120, 0, "c"), (jx - 150, -20), (jx - 150, -300)])
    for i in range(14):
        mx = jx - 110 + (i % 5) * 55 + (i // 5 % 2) * 25
        my = -50 - (i // 5) * 60
        mm = [TEAL, RED_PAINT, MUSTARD, NAVY, PLUM][i % 5]
        molded(doc, ellipse_d(mx, my, 30, 30), mm, band=7, rim=5, sw=4,
               gloss=[(ellipse_d(mx - 9, my - 10, 8, 6), 0.9)])
    doc.path(jar, fill=GLASS.base, op=0.35)
    doc.path(jar, stroke=INK, sw=OUTLINE)
    doc.path(smooth([(jx - 120, -300), (jx - 110, -40)], closed=False), stroke="#ffffff", sw=14, op=0.6)
    molded(doc, rrect_d(jx - 140, -440, 280, 70, 14), RED_PAINT, band=10, rim=6)
    collision.append(box(jx - 150, -440, jx + 150, 0))
    # trophy
    tx = 760
    molded(doc, rrect_d(tx - 110, -80, 220, 80, 10), WALNUT, band=10, rim=6)
    molded(doc, rrect_d(tx - 30, -200, 60, 120, 10), BRASS, band=8, rim=5)
    cup = smooth([(tx - 120, -440, "c"), (tx + 120, -440, "c"), (tx + 100, -280), (tx, -200), (tx - 100, -280)])
    for s in (-1, 1):
        doc.path(smooth([(tx + s * 110, -420), (tx + s * 170, -380), (tx + s * 150, -300), (tx + s * 80, -280)],
                        closed=False), stroke=INK, sw=30)
        doc.path(smooth([(tx + s * 110, -420), (tx + s * 170, -380), (tx + s * 150, -300), (tx + s * 80, -280)],
                        closed=False), stroke=BRASS.base, sw=16)
    molded(doc, cup, BRASS, band=16, rim=7, gloss=[(smooth([(tx - 80, -420), (tx - 40, -420), (tx - 60, -310)]), 0.8)])
    doc.path(smooth([(tx - 30, -380, "c"), (tx, -410, "c"), (tx + 30, -380, "c"), (tx, -340, "c")]),
             fill=BRASS.light, stroke=BRASS.deep, sw=4)
    collision.append(box(tx - 120, -440, tx + 120, 0))
    # two books leaning on the right
    for i, (m, bw, bh, rot) in enumerate(((NAVY, 70, 420, 0), (MUSTARD, 64, 380, 18))):
        x = 1180 + i * 74
        doc.open_group(f'transform="rotate({rot} {f(x + bw)} 0)"')
        molded(doc, rrect_d(x, -bh, bw, bh, 8), m, band=8, rim=5,
               details=[(f"M{f(x + 8)} {f(-bh + 50)}H{f(x + bw - 8)}", m.light, 5)])
        doc.close_group()
    collision.append(box(1180, -420, 1250, 0))
    save(doc, "wall_shelf", origin=(0, 0), collision=collision, note="origin is the plank's top-left; hang on the wall")


# ---------------------------------------------------------------- toy chest

def toy_chest():
    rng = random.Random(6)
    W, H = 60 * CM, 40 * CM
    doc = Doc(-80, -H - 140, W + 160, H + 170, prefix="tc")
    contact_shadow(doc, 30, W - 30, 0, 45, 0.5)
    body = rrect_d(0, -H + 120, W, H - 120, 20)
    molded(doc, body, RED_PAINT, band=26, rim=8,
           grad=doc.lin(0, -H, W, 0, [(0, mix(RED_PAINT.base, RED_PAINT.light, 0.25)), (0.7, RED_PAINT.base),
                                       (1, mix(RED_PAINT.base, RED_PAINT.shadow, 0.3))]))
    clip = doc.clip(body)
    doc.open_group(f'clip-path="{clip}"')
    for x in range(120, W, 360):
        doc.path(f"M{x} {-H + 140}V0", stroke=RED_PAINT.deep, sw=5, op=0.45)
    doc.close_group()
    # yellow trim bands and corner guards
    for y0 in (-H + 120, -110):
        molded(doc, rrect_d(-10, y0, W + 20, 90, 14), YELLOW_PAINT, band=12, rim=6,
               gloss=[(rrect_d(30, y0 + 12, W - 300, 12, 6), 0.5)])
    for x0 in (-24, W - 96):
        molded(doc, rrect_d(x0, -H + 100, 120, H - 90, 20), YELLOW_PAINT, band=14, rim=6)
        for y in range(-H + 200, -60, 220):
            molded(doc, ellipse_d(x0 + 60, y, 16, 16), STEEL, band=4, rim=3, sw=4,
                   gloss=[(ellipse_d(x0 + 55, y - 5, 5, 4), 0.9)])
    # star decals
    from bni_svg import star_d
    for i, (sx, sy, r) in enumerate(((560, -560, 150), (980, -480, 110), (1330, -600, 140))):
        m = [YELLOW_PAINT, CREAM, YELLOW_PAINT][i]
        molded(doc, star_d(sx, sy, r, r * 0.45, 5, rot=-90 + i * 8), m, band=10, rim=6)
    # handles
    for x in (240, W - 240):
        doc.path(smooth([(x - 90, -H + 300), (x - 70, -H + 380), (x + 70, -H + 380), (x + 90, -H + 300)], closed=False),
                 stroke=INK, sw=40)
        doc.path(smooth([(x - 90, -H + 300), (x - 70, -H + 380), (x + 70, -H + 380), (x + 90, -H + 300)], closed=False),
                 stroke=STEEL.base, sw=24)
    # lid
    lid = rrect_d(-50, -H - 30, W + 100, 170, 30)
    molded(doc, lid, RED_PAINT, band=16, rim=8,
           grad=doc.lin(0, -H - 30, 0, -H + 140, [(0, mix(RED_PAINT.base, RED_PAINT.light, 0.4)), (1, RED_PAINT.base)]),
           gloss=[(rrect_d(0, -H - 14, W - 400, 16, 8), 0.5)])
    molded(doc, rrect_d(-60, -H + 90, W + 120, 60, 20), YELLOW_PAINT, band=10, rim=6)
    molded(doc, rrect_d(W / 2 - 80, -H + 120, 160, 120, 16), BRASS, band=10, rim=6,
           gloss=[(rrect_d(W / 2 - 60, -H + 132, 60, 10, 5), 0.8)])
    doc.path(ellipse_d(W / 2, -H + 190, 14, 22), fill=BRASS.deep)
    _ = rng
    save(doc, "toy_chest", origin=(0, 0), collision=[box(-50, -H - 30, W + 50, -H + 150), box(0, -H + 150, W, 0)])


# ---------------------------------------------------------------- floor clutter

def blocks():
    """Wooden toy blocks, 7 cm, each with a raised shape. They stack as cover."""
    from bni_svg import star_d
    S = 7 * CM
    shapes = {"block_star": (YELLOW_PAINT, RED_PAINT, "star"), "block_moon": (TEAL, MUSTARD, "moon"),
              "block_heart": (PINE, PLUM, "heart")}
    for name, (m, deco, kind) in shapes.items():
        doc = Doc(-20, -S - 20, S + 40, S + 40, prefix=name[-4:])
        d = rrect_d(0, -S, S, S, 22)
        molded(doc, d, m, band=18, rim=8,
               grad=doc.lin(0, -S, S, 0, [(0, mix(m.base, m.light, 0.35)), (1, m.base)]),
               details=[(rrect_d(22, -S + 22, S - 44, S - 44, 14), m.shadow, 5)],
               gloss=[(rrect_d(26, -S + 26, S * 0.5, 12, 6), 0.55)])
        cx, cy = S / 2, -S / 2
        if kind == "star":
            sd = star_d(cx, cy, 62, 28, 5, rot=-90)
        elif kind == "moon":
            sd = smooth([(cx - 10, cy - 64), (cx + 44, cy - 30), (cx + 50, cy + 20), (cx + 10, cy + 60),
                         (cx - 40, cy + 54), (cx - 6, cy + 30), (cx + 10, cy - 4), (cx - 4, cy - 40)])
        else:
            sd = smooth([(cx, cy - 30, "c"), (cx + 30, cy - 62), (cx + 62, cy - 34), (cx + 46, cy + 10),
                         (cx, cy + 56, "c"), (cx - 46, cy + 10), (cx - 62, cy - 34), (cx - 30, cy - 62)])
        molded(doc, sd, deco, band=8, rim=5)
        save(doc, name, origin=(0, 0), collision=[box(0, -S, S, 0)], note="stack them; 210 px cube")


def book_stack():
    rng = random.Random(8)
    doc = Doc(-40, -330, 820, 360, prefix="bk")
    contact_shadow(doc, 0, 760, 0, 26, 0.4)
    y = 0
    for i, (m, w, h, dx) in enumerate(((NAVY, 760, 110, 0), (RED_PAINT, 700, 90, 30), (MUSTARD, 640, 100, 10))):
        molded(doc, rrect_d(dx, y - h, w, h, 12), m, band=12, rim=7,
               details=[(f"M{f(dx + 50)} {f(y - h + 16)}V{f(y - 16)}", m.deep, 5),
                        (f"M{f(dx + w - 10)} {f(y - h + 18)}H{f(dx + w - 4)}V{f(y - 18)}", CREAM.base, 10)],
               gloss=[(rrect_d(dx + 80, y - h + 14, w * 0.5, 10, 5), 0.5)])
        y -= h
    _ = rng
    save(doc, "book_stack", origin=(0, 0), collision=[box(0, y, 760, 0)])


# ---------------------------------------------------------------- ceiling fan

def ceiling_fan():
    doc = Doc(-1640, -40, 3280, 1000, prefix="cf")
    molded(doc, smooth([(-160, 0, "c"), (160, 0, "c"), (120, 70, "c"), (-120, 70, "c")]), WHITE, band=12, rim=6)
    molded(doc, rrect_d(-26, 60, 52, 340, 12), BRASS, band=8, rim=5)
    # far blade (foreshortened, behind)
    far = smooth([(-180, 470, "c"), (180, 470, "c"), (240, 430, "c"), (-240, 430, "c")])
    molded(doc, far, mix_mat(WALNUT, 0.25), band=10, rim=5)
    # long blades left and right
    for s in (-1, 1):
        x0 = s * 160
        x1 = s * 1600
        blade = smooth([(x0, 480, "c"), (x1 * 0.98, 470), (x1, 500, "c"), (x1 * 0.99, 545), (x0, 560, "c")])
        g = doc.lin(0, 470, 0, 560, [(0, mix(WALNUT.base, WALNUT.light, 0.4)), (1, WALNUT.base)])
        molded(doc, blade, WALNUT, band=12, rim=6, grad=g,
               details=[(smooth([(x0 + s * 100, 500), (x1 * 0.9, 496)], closed=False), WALNUT.deep, 3)])
        molded(doc, smooth([(s * 150, 470, "c"), (s * 420, 480, "c"), (s * 420, 560, "c"), (s * 150, 580, "c")]),
               BRASS, band=8, rim=5)
    # motor housing
    motor = smooth([(-220, 400, "c"), (220, 400, "c"), (250, 520), (210, 610, "c"), (-210, 610, "c"), (-250, 520)])
    molded(doc, motor, WHITE, band=20, rim=8,
           details=[(f"M-240 500H240", WHITE.shadow, 5)],
           gloss=[(rrect_d(-170, 420, 140, 16, 8), 0.7)])
    molded(doc, rrect_d(-230, 470, 460, 50, 16), BRASS, band=8, rim=5, gloss=[(rrect_d(-200, 478, 200, 8, 4), 0.7)])
    # light bowl and pull chain
    bowl = smooth([(-170, 600, "c"), (170, 600, "c"), (120, 720), (0, 760), (-120, 720)])
    molded(doc, bowl, CREAM, band=14, rim=6)
    doc.path("M90 640V880", stroke=BRASS.deep, sw=6, extra='stroke-dasharray="4 8"')
    molded(doc, ellipse_d(90, 900, 16, 22), BRASS, band=4, rim=3, sw=4)
    collision = [box(-250, 400, 250, 610),
                 {"type": "platform", "poly": [(-1600, 470), (-160, 480), (-160, 500), (-1600, 500)]},
                 {"type": "platform", "poly": [(160, 480), (1600, 470), (1600, 500), (160, 500)]}]
    save(doc, "ceiling_fan", origin=(0, 0), collision=collision,
         note="hangs from its origin at the ceiling; the long blades are platforms")


def mix_mat(m, k):
    """A material pushed toward its shadow, for parts further back."""
    return Plastic(base=mix(m.base, m.shadow, k), light=mix(m.light, m.base, k), shadow=mix(m.shadow, m.deep, k),
                   deep=m.deep, rim=mix(m.rim, m.base, k), ink=m.ink)


# ---------------------------------------------------------------- backdrop

WALL = "#d9e4ea"
WALL_LIGHT = "#e8eff2"
WALL_SHADE = "#c3d1da"
SOFT_INK = "#9fb1be"


def wall_tile():
    """Seamless pale wallpaper: soft stars and clouds, no hard edges."""
    rng = random.Random(9)
    S = 1024
    doc = Doc(0, 0, S, S, prefix="wt")
    doc.path(f"M0 0H{S}V{S}H0Z", fill=WALL)
    # vertical soft stripes
    for x in range(0, S, 256):
        doc.path(f"M{x + 128} 0h64V{S}h-64Z", fill=WALL_LIGHT, op=0.55)
    # stars on a grid that wraps
    from bni_svg import star_d
    for gx in range(4):
        for gy in range(4):
            x = gx * 256 + 64 + (gy % 2) * 128
            y = gy * 256 + 96
            r = 22 + rng.random() * 8
            for dx in (-S, 0, S):
                for dy in (-S, 0, S):
                    if -60 < x + dx < S + 60 and -60 < y + dy < S + 60:
                        doc.path(star_d(x + dx, y + dy, r, r * 0.48, 5, rot=-90 + rng.random() * 20),
                                 fill="#f4f1e2", op=0.85)
                        doc.path(ellipse_d(x + dx + 110, y + dy + 120, 6, 6), fill="#f4f1e2", op=0.7)
    save(doc, "wall_tile", origin=(0, 0), kind="backdrop", note="tiles both ways")


def skirting():
    S, H = 1024, 220
    doc = Doc(0, -H, S, H, prefix="sk")
    doc.path(f"M0 {-H}H{S}V0H0Z", fill="#ece7dc")
    doc.path(f"M0 {-H}H{S}V{-H + 40}H0Z", fill="#f6f2ea")
    doc.path(f"M0 {-H + 40}H{S}", stroke="#c9c2b4", sw=5)
    doc.path(f"M0 {-H}H{S}", stroke=SOFT_INK, sw=4)
    doc.path(f"M0 -30H{S}V0H0Z", fill="#d8d1c2", op=0.8)
    save(doc, "skirting", origin=(0, 0), kind="backdrop", note="tiles horizontally; sits on the floor's back edge")


def window():
    W, H = 1800, 2200
    doc = Doc(-260, -60, W + 520, H + 200, prefix="wn")
    # night sky in the panes, muted
    sky = doc.lin(0, 0, 0, H, [(0, "#7486aa"), (1, "#a9b9d0")])
    doc.path(rrect_d(60, 60, W - 120, H - 120, 20), fill=sky)
    doc.path(ellipse_d(1240, 520, 170, 170), fill="#f6edc8")
    doc.path(ellipse_d(1310, 470, 150, 150), fill="#8fa1c0")
    rng = random.Random(4)
    for _ in range(26):
        x, y = 120 + rng.random() * (W - 240), 120 + rng.random() * (H * 0.6)
        doc.path(ellipse_d(x, y, 5, 5), fill="#f3f0dc", op=0.8)
    # rooftops far away
    roofs = [(60, H - 400), (300, H - 560), (520, H - 470), (800, H - 650), (1050, H - 500), (1300, H - 600),
             (1550, H - 450), (W - 60, H - 520)]
    pts = [(60, H - 60)] + roofs + [(W - 60, H - 60)]
    doc.path(poly(pts), fill="#8394b4", op=0.9)
    for x, y in ((420, H - 360), (900, H - 480), (1400, H - 400)):
        doc.path(rrect_d(x, y, 40, 50, 4), fill="#f2d68a", op=0.8)
    # frame
    fr = "#eef0ee"
    doc.path(rrect_d(0, 0, W, H, 30), fill="none", stroke=fr, sw=120)
    doc.path(f"M{W / 2} 0V{H}M0 {H * 0.45}H{W}", stroke=fr, sw=60)
    doc.path(rrect_d(-60, -60, W + 120, H + 120, 40), fill="none", stroke=SOFT_INK, sw=4)
    doc.path(rrect_d(-70, H + 40, W + 140, 90, 20), fill="#f2f1ed", stroke=SOFT_INK, sw=4)
    # curtains, pale mustard
    for s in (0, 1):
        x0 = -240 if s == 0 else W - 140
        cur = smooth([(x0, -40, "c"), (x0 + 380, -40, "c"), (x0 + 330 - s * 0, H * 0.5), (x0 + 400, H + 60, "c"),
                      (x0 - 20, H + 60, "c"), (x0 + 30, H * 0.5)])
        doc.path(cur, fill="#ecdcae")
        for k in range(3):
            xx = x0 + 80 + k * 100
            doc.path(smooth([(xx, -20), (xx - 20, H * 0.5), (xx + 20, H + 40)], closed=False), stroke="#d6c28c",
                     sw=14, op=0.8)
        doc.path(cur, stroke="#c8b582", sw=4)
    doc.path(f"M-260 -30H{W + 260}", stroke="#c8b582", sw=24)
    save(doc, "window", origin=(0, 0), kind="backdrop", note="origin is the frame's top-left")


def poster():
    """A kid's rocket drawing pinned to the wall."""
    W, H = 900, 1200
    doc = Doc(-20, -40, W + 40, H + 70, prefix="po")
    doc.path(rrect_d(10, 10, W, H, 12), fill="#b8c6cf", op=0.6)
    doc.path(rrect_d(0, 0, W, H, 12), fill="#f6f2e6", stroke=SOFT_INK, sw=4)
    doc.path(smooth([(450, 220, "c"), (560, 420), (580, 760, "c"), (320, 760, "c"), (340, 420)]), fill="#e9a99a",
             stroke="#b88a80", sw=8)
    doc.path(ellipse_d(450, 470, 60, 60), fill="#b5d3e6", stroke="#b88a80", sw=8)
    for s in (-1, 1):
        doc.path(poly([(450 + s * 120, 640), (450 + s * 230, 860), (450 + s * 130, 760)]), fill="#9fc4b8",
                 stroke="#8aa89e", sw=8)
    doc.path(smooth([(390, 770), (450, 980, "c"), (510, 770)], closed=False), fill="#f3d48a", stroke="#d8b46e", sw=8)
    from bni_svg import star_d
    for x, y in ((180, 220), (720, 300), (220, 900), (700, 960)):
        doc.path(star_d(x, y, 50, 22, 5, rot=-90), fill="#f3d48a")
    doc.path(ellipse_d(450, 20, 22, 22), fill="#d88d80")
    save(doc, "poster", origin=(0, 0), kind="backdrop")


def main():
    os.makedirs(OUT, exist_ok=True)
    floor()
    bed()
    bookshelf()
    desk()
    wall_shelf()
    toy_chest()
    ceiling_fan()
    blocks()
    book_stack()
    wall_tile()
    skirting()
    window()
    poster()
    data = {"units": "author px, 4 per game px at 720p; 30 px per cm, room 240 cm tall",
            "origin": "px from the file's top-left: a prop's floor contact (bottom-left), the fan's ceiling mount",
            "collision": "polygons in px from the file's top-left; solid blocks, platform is stood on from above",
            "kinds": "prop and tile are playable and inked; backdrop is muted and never collides; light is added",
            "pieces": KIT}
    with open(os.path.join(OUT, "kit.json"), "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
