"""Effects: muzzle flash, thrust flame, smoke ring, tracer, frag blast and the soldier's pop.

Run: python3 art/src/fx.py  (writes assets/fx/*.svg and fx.json)

Light effects come in two layers. `<name>.svg` is the hot shape, drawn with normal blending so
it keeps its colour on a pale map. `<name>_glow.svg` is soft light on a transparent ground,
meant for additive blending on top (art ref 03), so it glows on any map.
Origins: a flash starts at the muzzle and points right, a flame starts at the nozzle and
points down, a tracer's origin is its head, everything else is centred.
"""

import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bni_svg import Doc, Plastic, ellipse_d, f, molded, poly, smooth, star_d  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "fx")
INK = "#1d1712"

WHITE_HOT = "#fffbe8"
YELLOW = "#ffd84a"
ORANGE = "#ff8a1c"
RED_ORANGE = "#f0521c"
CYAN = "#7ff3ff"
SMOKE = Plastic(base="#ece4d2", light="#fffaf0", shadow="#b9ad98", deep="#8c8170", rim="#fff3dc", ink="#5a5047")
DARK_SMOKE = Plastic(base="#6c6560", light="#938b84", shadow="#4b4541", deep="#37322f", rim="#a19486", ink="#2a2522")

META = {}


def meta(name, doc, origin=(0, 0), blend="normal", note=""):
    META[name] = {"file": f"{name}.svg", "size": [doc.w, doc.h],
                  "origin": [origin[0] - doc.x0, origin[1] - doc.y0], "blend": blend}
    if note:
        META[name]["note"] = note


def save(doc, name, **kw):
    doc.save(os.path.join(OUT, f"{name}.svg"))
    meta(name, doc, **kw)


def jag(rng, cx, cy, length, width, n, spread=0.35, rot=0.0):
    """A spiky flame burst pointing along +x, as a closed polygon."""
    pts = []
    for i in range(n + 1):
        t = i / n
        a = math.pi * (t - 0.5)  # -90..90 degrees around the front
        reach = length * (0.55 + 0.45 * math.cos(a) ** 2) * (1 if i % 2 == 0 else 0.55 + rng.random() * 0.15)
        reach *= 1 + (rng.random() - 0.5) * spread
        x = math.cos(a) * reach
        y = math.sin(a) * width * (1 if i % 2 == 0 else 0.7)
        pts.append((x, y))
    pts.append((-length * 0.12, width * 0.25))
    pts.append((-length * 0.12, -width * 0.25))
    r = math.radians(rot)
    return poly([(cx + x * math.cos(r) - y * math.sin(r), cy + x * math.sin(r) + y * math.cos(r)) for x, y in pts])


# ---------------------------------------------------------------- muzzle flash

def muzzle_flash(name, seed, length=96, width=34):
    rng = random.Random(seed)
    doc = Doc(-16, -width * 1.6, length * 1.25 + 16, width * 3.2, prefix=f"mf{seed}")
    doc.path(jag(rng, 0, 0, length, width, 14), fill=ORANGE)
    doc.path(jag(rng, 0, 0, length * 0.78, width * 0.72, 12), fill=YELLOW)
    doc.path(jag(rng, 0, 0, length * 0.5, width * 0.42, 10, spread=0.2), fill=WHITE_HOT)
    # side spurts
    for side in (-1, 1):
        doc.path(jag(rng, length * 0.08, side * width * 0.3, length * 0.38, width * 0.3, 6, rot=side * 52), fill=ORANGE)
        doc.path(jag(rng, length * 0.08, side * width * 0.3, length * 0.24, width * 0.18, 6, rot=side * 52),
                 fill=YELLOW)
    save(doc, name, origin=(0, 0), note="starts at the muzzle, points right")


def muzzle_glow():
    doc = Doc(-60, -70, 220, 140, prefix="mg")
    g = doc.rad(40, 0, 100, [(0, ("#fff2c0", 0.95)), (0.25, ("#ffc24a", 0.65)), (0.6, ("#ff7a1a", 0.22)),
                             (1, ("#ff5a00", 0))], transform="translate(40 0) scale(1 0.6) translate(-40 0)")
    doc.path(ellipse_d(40, 0, 100, 60), fill=g)
    save(doc, "muzzle_flash_glow", origin=(0, 0), blend="add")


# ---------------------------------------------------------------- thrust

def thrust_flame(name, seed, length=170, width=38):
    """From a battery nozzle, pushing down. An electric blue core turning to fire."""
    rng = random.Random(seed)
    doc = Doc(-width * 1.4, -10, width * 2.8, length + 30, prefix=f"tf{seed}")

    def lick(w, ln, wob):
        pts = [(-w * 0.55, 0, "c")]
        n = 6
        for i in range(1, n):
            t = i / n
            pts.append((-w * (0.55 + 0.45 * math.sin(t * math.pi * 0.9)) + (rng.random() - 0.5) * wob,
                        ln * t * 0.8))
        pts.append((0, ln, "c"))
        for i in range(n - 1, 0, -1):
            t = i / n
            pts.append((w * (0.55 + 0.45 * math.sin(t * math.pi * 0.9)) + (rng.random() - 0.5) * wob,
                        ln * t * 0.8 + (rng.random() - 0.5) * wob))
        pts.append((w * 0.55, 0, "c"))
        return smooth(pts)

    doc.path(lick(width, length, 10), fill=RED_ORANGE, op=0.95)
    doc.path(lick(width * 0.82, length * 0.86, 8), fill=ORANGE)
    doc.path(lick(width * 0.62, length * 0.66, 6), fill=YELLOW)
    doc.path(lick(width * 0.42, length * 0.44, 3), fill="#cffcff")
    doc.path(lick(width * 0.24, length * 0.3, 1), fill="#ffffff")
    # sparks
    for _ in range(5):
        x = (rng.random() - 0.5) * width * 1.6
        y = length * (0.55 + rng.random() * 0.45)
        doc.path(ellipse_d(x, y, 2.2, 4.5), fill=YELLOW)
    save(doc, name, origin=(0, 0), note="starts at the nozzle exit, points down (+y)")


def thrust_glow():
    doc = Doc(-100, -50, 200, 280, prefix="tg")
    g = doc.rad(0, 70, 120, [(0, ("#e8fdff", 0.55)), (0.2, ("#8cefff", 0.4)), (0.5, ("#ff9a2a", 0.25)),
                            (1, ("#ff6a00", 0))], transform="translate(0 70) scale(0.75 1.1) translate(0 -70)")
    doc.path(ellipse_d(0, 70, 100, 135), fill=g)
    save(doc, "thrust_glow", origin=(0, 0), blend="add")


def smoke_ring():
    """A puffy ring left under a toy as it takes off, seen from a low angle."""
    rng = random.Random(7)
    doc = Doc(-96, -46, 192, 92, prefix="sr")
    puffs = []
    n = 13
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = 66 * math.cos(a), 20 * math.sin(a)
        r = 17 + rng.random() * 6 + (4 if math.sin(a) > 0 else 0)
        puffs.append((y, x, y, r))
    puffs.sort()
    for _, x, y, r in puffs:
        d = ellipse_d(x, y, r, r * 0.86)
        front = y > 0
        molded(doc, d, SMOKE, band=5 if front else 3, rim=2, sw=3.5,
               grad=None if front else SMOKE.shadow,
               gloss=[(ellipse_d(x - r * 0.3, y - r * 0.35, r * 0.3, r * 0.2), 0.6)] if front else None)
    save(doc, "smoke_ring", origin=(0, 0), note="centred; spawn it at the nozzles on take-off")


def smoke_puff(name="smoke_puff", seed=3, r=40, m=SMOKE):
    rng = random.Random(seed)
    doc = Doc(-r * 1.8, -r * 1.6, r * 3.6, r * 3.0, prefix=f"sp{seed}")
    blobs = [(0, 0, r)]
    for i in range(6):
        a = 2 * math.pi * i / 6 + rng.random() * 0.5
        blobs.append((math.cos(a) * r * 0.8, math.sin(a) * r * 0.55, r * (0.5 + rng.random() * 0.25)))
    d = ""
    for x, y, rr in blobs:
        d += ellipse_d(x, y, rr, rr * 0.9)
    molded(doc, d, m, band=8, rim=3, sw=4, union=True,
           gloss=[(ellipse_d(-r * 0.35, -r * 0.4, r * 0.35, r * 0.2), 0.55)])
    save(doc, name, origin=(0, 0))


# ---------------------------------------------------------------- tracer

def tracer():
    doc = Doc(-240, -14, 252, 28, prefix="tr")
    g = doc.lin(-240, 0, 0, 0, [(0, ("#ff8a1c", 0)), (0.55, ("#ffb02e", 0.55)), (0.9, ("#ffe27a", 0.95)),
                                (1, ("#ffffff", 1))])
    doc.path(smooth([(-240, 0, "c"), (-40, -6), (0, -6), (8, 0, "c"), (0, 6), (-40, 6)]), fill=g)
    g2 = doc.lin(-120, 0, 0, 0, [(0, ("#ffffff", 0)), (1, ("#ffffff", 1))])
    doc.path(smooth([(-120, 0, "c"), (-20, -2.5), (4, 0, "c"), (-20, 2.5)]), fill=g2)
    save(doc, "tracer", origin=(0, 0), blend="add", note="origin is the head; stretch along x with speed")


# ---------------------------------------------------------------- frag blast

def blast():
    rng = random.Random(11)
    doc = Doc(-220, -220, 440, 440, prefix="bl")
    # spikes
    doc.path(star_d(0, 0, 190, 90, 14, rot=8, jitter=[1, 0.9, 1.15, 1, 0.85, 1.1, 0.95]), fill=ORANGE)
    doc.path(star_d(0, 0, 150, 80, 11, rot=-4, jitter=[1.05, 1, 0.9, 1.1]), fill=YELLOW)
    # fireball puffs
    puffs = [(0, 0, 92)]
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.random() * 0.4
        puffs.append((math.cos(a) * 86, math.sin(a) * 78, 40 + rng.random() * 18))
    d = "".join(ellipse_d(x, y, r, r) for x, y, r in puffs)
    fire = Plastic(base="#ffb52e", light="#fff2b0", shadow="#f06a12", deep="#c2410c", rim="#ffd27a", ink="#5a2108")
    molded(doc, d, fire, band=14, rim=6, sw=5, union=True,
           grad=doc.rad(-20, -24, 140, [(0, "#fffbe0"), (0.35, "#ffe066"), (0.75, "#ffaa2a"), (1, "#ff7a1a")]))
    # hot core
    doc.path(ellipse_d(-8, -10, 52, 46), fill=WHITE_HOT, op=0.9)
    # debris and sparks
    for i in range(16):
        a = 2 * math.pi * i / 16 + rng.random() * 0.3
        r0 = 170 + rng.random() * 40
        x, y = math.cos(a) * r0, math.sin(a) * r0
        doc.path(ellipse_d(x, y, 5 + rng.random() * 4, 3 + rng.random() * 2), fill=YELLOW,
                 extra=f'transform="rotate({f(math.degrees(a))} {f(x)} {f(y)})"')
    save(doc, "frag_blast", origin=(0, 0), note="centred on the grenade")
    # smoke that lingers after the fire
    smoke_puff("blast_smoke", seed=5, r=70, m=DARK_SMOKE)


def blast_glow():
    doc = Doc(-320, -320, 640, 640, prefix="bg")
    g = doc.rad(0, 0, 320, [(0, ("#fff4c8", 1)), (0.2, ("#ffcf5a", 0.8)), (0.5, ("#ff8a1c", 0.35)),
                            (1, ("#ff5a00", 0))])
    doc.path(ellipse_d(0, 0, 320, 320), fill=g)
    save(doc, "frag_blast_glow", origin=(0, 0), blend="add")


# ---------------------------------------------------------------- the pop

def pop_burst():
    """The comic burst behind the POP! word."""
    doc = Doc(-170, -130, 340, 260, prefix="pb")
    doc.path(star_d(0, 0, 160, 92, 12, rot=-6, jitter=[1, 0.82, 1.12, 0.9, 1.05, 0.86]), fill="#ff5a3a",
             stroke=INK, sw=8)
    doc.path(star_d(0, 0, 120, 78, 12, rot=-6, jitter=[1, 0.85, 1.1, 0.92, 1.05, 0.88]), fill="#fff3a8")
    save(doc, "pop_burst", origin=(0, 0))


def pop_text():
    """POP! drawn as shapes (no font): yellow letters, orange drop, ink outline."""
    doc = Doc(-170, -90, 340, 180, prefix="pt")

    def letter_p(x, y, rot):
        outer = smooth([(-26, -56, "c"), (12, -56), (34, -44), (38, -22), (30, -4), (6, 6), (-4, 6, "c"), (-4, 54, "c"),
                        (-30, 54, "c")])
        hole = smooth([(-4, -34, "c"), (6, -34), (14, -28), (14, -18), (6, -12), (-4, -12, "c")])
        return outer, hole, (x, y, rot)

    def letter_o(x, y, rot):
        return ellipse_d(0, 0, 40, 56), ellipse_d(2, 0, 14, 26), (x, y, rot)

    def bang(x, y, rot):
        bar = smooth([(-14, -56, "c"), (14, -56, "c"), (8, 22, "c"), (-8, 22, "c")])
        dot = ellipse_d(0, 42, 12, 12)
        return bar + dot, "", (x, y, rot)

    letters = [letter_p(-104, 4, -10), letter_o(-26, -4, -3), letter_p(52, 2, 6), bang(118, -6, 12)]
    for layer, (dx, dy, col, stroke) in enumerate([(8, 10, "#e2520f", True), (0, 0, "#ffd52a", True)]):
        for outer, hole, (x, y, rot) in letters:
            tr = f'transform="translate({f(x + dx)} {f(y + dy)}) rotate({f(rot)})"'
            d = outer + hole
            doc.path(d, fill=col, extra=f'fill-rule="evenodd" {tr}')
            doc.path(d, stroke=INK, sw=9, extra=tr)
    for outer, hole, (x, y, rot) in letters:
        tr = f'transform="translate({f(x)} {f(y)}) rotate({f(rot)})"'
        doc.path(smooth([(-18, -46), (-8, -50), (-12, -30), (-20, -26)]), fill="#ffffff", op=0.75, extra=tr)
    save(doc, "pop_text", origin=(0, 0))


def pop_snap():
    """Little snap lines where a plastic joint lets go."""
    doc = Doc(-40, -40, 80, 80, prefix="ps")
    for i in range(7):
        a = 2 * math.pi * i / 7
        x0, y0 = math.cos(a) * 12, math.sin(a) * 12
        x1, y1 = math.cos(a) * (30 + (i % 2) * 6), math.sin(a) * (30 + (i % 2) * 6)
        doc.path(f"M{f(x0)} {f(y0)}L{f(x1)} {f(y1)}", stroke=INK, sw=8)
        doc.path(f"M{f(x0)} {f(y0)}L{f(x1)} {f(y1)}", stroke="#fffbe0", sw=4)
    save(doc, "pop_snap", origin=(0, 0))


def main():
    os.makedirs(OUT, exist_ok=True)
    muzzle_flash("muzzle_flash", 1)
    muzzle_flash("muzzle_flash_b", 2, length=84, width=40)
    muzzle_glow()
    thrust_flame("thrust_flame", 3)
    thrust_flame("thrust_flame_b", 4, length=150, width=34)
    thrust_glow()
    smoke_ring()
    smoke_puff()
    tracer()
    blast()
    blast_glow()
    pop_burst()
    pop_text()
    pop_snap()
    data = {"units": "author px, 4 per game px at 720p; origin is px from the file's top-left",
            "blend": "normal: draw as is; add: additive blending (CanvasItemMaterial BLEND_MODE_ADD)",
            "fx": META}
    with open(os.path.join(OUT, "fx.json"), "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
