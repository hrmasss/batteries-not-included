"""Launch weapons as molded toy props, separate from any toy.

Run: python3 art/src/weapons.py  (writes assets/weapons/*.svg and weapons.json)

Each weapon faces right and is drawn in its own frame with the grip near (0, 0).
Colours keep clear of the team hues (blue, orange, pink, yellow) so a gun in a toy's hand
never reads as a team mark. Every gun has the small orange safety tip real toy guns carry.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bni_svg import DETAIL, Doc, Plastic, ellipse_d, molded, rrect_d, smooth  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "weapons")

WINK = "#1b1c22"
SLATE = Plastic(base="#5b6474", light="#8f99ab", shadow="#3d4451", deep="#272c35", rim="#a3acbf", ink=WINK)
RED = Plastic(base="#e5473b", light="#ff8e74", shadow="#a82a22", deep="#741a15", rim="#ffb28d", ink=WINK)
PURPLE = Plastic(base="#8a5ae6", light="#b997ff", shadow="#5d37a6", deep="#40236f", rim="#d6c0ff", ink=WINK)
TEAL = Plastic(base="#1fb5a2", light="#71e8d6", shadow="#127a6c", deep="#0b4f47", rim="#b0f7ec", ink=WINK)
CREAM = Plastic(base="#efe5cc", light="#fffbf0", shadow="#c3b28d", deep="#8c7d5c", rim="#fff7de", ink=WINK)
TIP = Plastic(base="#ff8a1f", light="#ffc27a", shadow="#c45d00", deep="#8a4100", rim="#ffd8a8", ink=WINK)
GLASS = Plastic(base="#5fd3ff", light="#e2f8ff", shadow="#2585b8", deep="#14506f", rim="#bdf0ff", ink=WINK)

REGISTRY = {}


def part(doc, d, m, band=5, rim=3, **kw):
    molded(doc, d, m, band=band, rim=rim, **kw)


def screw(doc, x, y, r=3.2, m=SLATE):
    doc.path(ellipse_d(x, y, r, r), fill=m.light)
    doc.path(ellipse_d(x + 0.6, y + 0.6, r * 0.55, r * 0.55), fill=m.deep, op=0.7)


def slots(doc, x0, y0, n, dx, h, w=5, col=None):
    for i in range(n):
        doc.path(rrect_d(x0 + i * dx, y0, w, h, w / 2), fill=col or "#20242b", op=0.75)


def tip(doc, x, yc, h, w=11):
    part(doc, rrect_d(x, yc - h / 2, w, h, 3), TIP, band=3, rim=2)


def register(name, doc, grip, muzzle, support=None, label=None, hands=2, extra=None):
    doc.save(os.path.join(OUT, f"{name}.svg"))
    x0, y0 = doc.x0, doc.y0
    entry = {"file": f"{name}.svg", "size": [doc.w, doc.h],
             "grip": [grip[0] - x0, grip[1] - y0],
             "muzzle": [muzzle[0] - x0, muzzle[1] - y0],
             "hands": hands, "label": label or name.replace("_", " ")}
    if support:
        entry["support"] = [support[0] - x0, support[1] - y0]
    for k, v in (extra or {}).items():
        entry[k] = [v[0] - x0, v[1] - y0]
    REGISTRY[name] = entry


# ---------------------------------------------------------------- guns

def pistol():
    doc = Doc(-40, -64, 140, 110, prefix="ps")
    grip = smooth([(-24, -16, "c"), (8, -16, "c"), (16, 28), (12, 36, "c"), (-14, 38, "c"), (-20, 30), (-26, -4)])
    part(doc, grip, SLATE, details=[smooth([(-14, 4), (6, 4)], closed=False), smooth([(-12, 14), (8, 14)], closed=False),
                                    smooth([(-10, 24), (10, 24)], closed=False)],
         gloss=[(ellipse_d(-16, 0, 3, 8), 0.4)])
    doc.path(smooth([(4, -16), (6, 4), (22, 6), (30, -16)], closed=False), stroke=WINK, sw=6)
    doc.path(smooth([(14, -16), (16, -4), (20, -6)], closed=False), stroke=SLATE.shadow, sw=4)
    part(doc, rrect_d(-22, -28, 84, 16, 5), SLATE)
    tip(doc, 66, -38, 18)
    part(doc, smooth([(-30, -52, "c"), (60, -52, "c"), (70, -44), (70, -26, "c"), (-30, -26, "c")]), RED, band=6,
         details=[smooth([(-22, -48), (-22, -30)], closed=False), smooth([(-16, -48), (-16, -30)], closed=False),
                  smooth([(-10, -48), (-10, -30)], closed=False)],
         gloss=[(rrect_d(-2, -48, 52, 5, 2.5), 0.55)])
    part(doc, rrect_d(-34, -56, 10, 12, 3), SLATE, band=2, rim=1.5)
    doc.path(rrect_d(56, -58, 6, 8, 2), fill=SLATE.base, stroke=WINK, sw=3)
    screw(doc, -12, 22)
    register("pistol", doc, grip=(-6, 10), muzzle=(78, -38), support=(-2, 16), hands=1, label="pistol")


def uzi():
    doc = Doc(-74, -76, 176, 152, prefix="uz")
    part(doc, rrect_d(-6, 2, 24, 62, 6), SLATE, details=[smooth([(-2, 50), (14, 50)], closed=False)])
    grip = smooth([(-14, -18, "c"), (16, -18, "c"), (20, 30), (16, 36, "c"), (-10, 36, "c"), (-16, 28)])
    part(doc, grip, SLATE, details=[smooth([(-8, 8), (12, 8)], closed=False), smooth([(-8, 18), (14, 18)], closed=False)])
    doc.path(smooth([(16, -16), (18, 4), (36, 6), (44, -16)], closed=False), stroke=WINK, sw=6)
    # folded wire stock
    doc.path(smooth([(-62, -50, "c"), (-30, -50, "c"), (-30, -30), (-62, -30, "c")], closed=False), stroke=WINK, sw=9)
    doc.path(smooth([(-62, -50, "c"), (-30, -50, "c"), (-30, -30), (-62, -30, "c")], closed=False),
             stroke=SLATE.light, sw=3.5)
    body = smooth([(-36, -58, "c"), (60, -58, "c"), (66, -50), (66, -18, "c"), (-36, -18, "c"), (-40, -30), (-40, -50)])
    part(doc, body, PURPLE, band=7,
         shadows=[(rrect_d(-36, -30, 102, 12, 3), PURPLE.shadow, 0.6)],
         details=[smooth([(-26, -48), (30, -48)], closed=False), smooth([(40, -50), (40, -24)], closed=False)],
         gloss=[(rrect_d(-26, -54, 60, 5, 2.5), 0.5)])
    for x in (46, 54):
        doc.path(rrect_d(x, -46, 4, 18, 2), fill=PURPLE.deep, op=0.8)
    part(doc, rrect_d(66, -46, 16, 18, 4), SLATE, band=3, rim=2)
    tip(doc, 80, -37, 16, 9)
    part(doc, ellipse_d(-4, -64, 8, 6), SLATE, band=2, rim=1.5)
    screw(doc, -28, -40)
    screw(doc, 54, -24, 2.6)
    register("uzi", doc, grip=(2, 6), muzzle=(91, -37), hands=1, label="Uzi")


def smg():
    doc = Doc(-124, -78, 262, 150, prefix="sm")
    # skeleton stock
    stock = smooth([(-112, -50, "c"), (-48, -46, "c"), (-48, -30, "c"), (-100, -18), (-112, -6, "c"), (-118, -6, "c"),
                    (-118, -50, "c")])
    part(doc, stock, SLATE, band=4)
    doc.path(smooth([(-104, -38, "c"), (-62, -38, "c"), (-100, -18, "c")]), fill="#2a2f39")
    # curved magazine
    mag = smooth([(32, -20, "c"), (54, -20, "c"), (58, 20), (66, 52, "c"), (44, 58, "c"), (36, 22)])
    part(doc, mag, SLATE, details=[smooth([(40, 0), (56, 0)], closed=False), smooth([(44, 24), (60, 22)], closed=False)])
    grip = smooth([(-14, -20, "c"), (14, -20, "c"), (18, 28), (14, 34, "c"), (-10, 34, "c"), (-16, 26)])
    part(doc, grip, SLATE, details=[smooth([(-8, 6), (12, 6)], closed=False), smooth([(-8, 16), (14, 16)], closed=False)])
    doc.path(smooth([(12, -18), (14, 2), (26, 4), (30, -18)], closed=False), stroke=WINK, sw=6)
    body = smooth([(-52, -60, "c"), (84, -60, "c"), (92, -52), (92, -18, "c"), (-52, -18, "c")])
    part(doc, body, TEAL, band=7,
         shadows=[(rrect_d(-52, -32, 144, 14, 3), TEAL.shadow, 0.6)],
         details=[smooth([(-40, -50), (30, -50)], closed=False)],
         gloss=[(rrect_d(-40, -56, 80, 5, 2.5), 0.55)])
    slots(doc, 48, -52, 4, 10, 18)
    part(doc, rrect_d(92, -46, 26, 16, 5), SLATE, band=3, rim=2)
    tip(doc, 116, -38, 18, 10)
    part(doc, rrect_d(-30, -72, 26, 12, 4), SLATE, band=2, rim=1.5)
    part(doc, rrect_d(70, -70, 8, 10, 2), SLATE, band=2, rim=1.5)
    screw(doc, -40, -40)
    register("smg", doc, grip=(0, 4), muzzle=(127, -38), support=(46, 4), label="SMG")


def assault_rifle():
    doc = Doc(-140, -96, 360, 160, prefix="ar")
    stock = smooth([(-126, -54, "c"), (-40, -48, "c"), (-40, -22, "c"), (-120, -6, "c"), (-128, -6, "c"),
                    (-130, -30), (-128, -54, "c")])
    part(doc, stock, RED, band=6, details=[smooth([(-116, -46), (-116, -12)], closed=False)],
         gloss=[(rrect_d(-110, -50, 50, 5, 2.5), 0.5)])
    part(doc, rrect_d(-132, -56, 12, 50, 4), SLATE, band=3, rim=2)
    mag = smooth([(22, -20, "c"), (48, -20, "c"), (52, 14), (62, 46, "c"), (36, 52, "c"), (28, 18)])
    part(doc, mag, SLATE, details=[smooth([(30, 0), (50, 0)], closed=False), smooth([(34, 24), (56, 22)], closed=False)])
    grip = smooth([(-16, -20, "c"), (12, -20, "c"), (16, 30), (10, 36, "c"), (-12, 36, "c"), (-18, 28)])
    part(doc, grip, RED, details=[smooth([(-10, 8), (12, 8)], closed=False)])
    doc.path(smooth([(10, -18), (12, 2), (22, 4), (26, -18)], closed=False), stroke=WINK, sw=6)
    recv = smooth([(-44, -60, "c"), (72, -60, "c"), (76, -50), (76, -18, "c"), (-44, -18, "c")])
    part(doc, recv, SLATE, band=7,
         details=[smooth([(-30, -40), (40, -40)], closed=False), smooth([(56, -54), (56, -24)], closed=False)],
         gloss=[(rrect_d(-34, -56, 70, 5, 2.5), 0.5)])
    part(doc, rrect_d(-10, -36, 22, 10, 3), SLATE, band=2, rim=1.5)
    # carry handle
    handle = smooth([(-24, -60, "c"), (-20, -82, "c"), (46, -82, "c"), (50, -60, "c"), (40, -60, "c"), (36, -72, "c"),
                     (-10, -72, "c"), (-14, -60, "c")])
    part(doc, handle, SLATE, band=4)
    hg = smooth([(74, -56, "c"), (160, -54, "c"), (160, -22, "c"), (74, -20, "c")])
    part(doc, hg, RED, band=6, gloss=[(rrect_d(84, -52, 60, 5, 2.5), 0.55)])
    slots(doc, 90, -48, 5, 13, 20)
    part(doc, rrect_d(160, -44, 46, 12, 4), SLATE, band=3, rim=2)
    part(doc, smooth([(150, -54, "c"), (156, -84, "c"), (166, -84, "c"), (168, -54, "c")]), SLATE, band=2, rim=1.5)
    tip(doc, 204, -38, 18, 12)
    screw(doc, -30, -30)
    register("assault_rifle", doc, grip=(-2, 6), muzzle=(217, -38), support=(100, -14), label="assault rifle")


def shotgun():
    doc = Doc(-160, -72, 400, 128, prefix="sg")
    stock = smooth([(-150, -40, "c"), (-30, -50, "c"), (-30, -18, "c"), (-4, -12), (-6, 8), (-22, 12, "c"),
                    (-40, -6), (-150, 12, "c"), (-154, -14)])
    part(doc, stock, CREAM, band=7, details=[smooth([(-140, -34), (-140, 6)], closed=False)],
         gloss=[(rrect_d(-130, -40, 70, 5, 2.5), 0.6)])
    part(doc, rrect_d(-158, -42, 12, 56, 4), SLATE, band=3, rim=2)
    doc.path(smooth([(-6, -16), (-2, 4), (18, 6), (22, -16)], closed=False), stroke=WINK, sw=6)
    recv = smooth([(-34, -54, "c"), (40, -54, "c"), (40, -16, "c"), (-34, -16, "c")])
    part(doc, recv, SLATE, band=7, details=[smooth([(-20, -36), (24, -36)], closed=False)],
         gloss=[(rrect_d(-24, -50, 50, 5, 2.5), 0.5)])
    part(doc, rrect_d(38, -32, 156, 12, 5), SLATE, band=3, rim=2)  # tube magazine
    part(doc, rrect_d(38, -52, 182, 16, 6), SLATE, band=4, rim=2, gloss=[(rrect_d(46, -50, 160, 4, 2), 0.5)])
    pump = smooth([(96, -40, "c"), (170, -40, "c"), (174, -26), (170, -10, "c"), (96, -10, "c"), (92, -26)])
    part(doc, pump, CREAM, band=6, gloss=[(rrect_d(104, -37, 56, 4, 2), 0.6)])
    for x in range(108, 168, 10):
        doc.path(f"M{x} -36V-14", stroke=CREAM.deep, sw=3.5)
    part(doc, rrect_d(-6, -64, 10, 12, 3), SLATE, band=2, rim=1.5)
    tip(doc, 216, -44, 20, 12)
    register("shotgun", doc, grip=(-14, -2), muzzle=(229, -44), support=(132, -18), label="pump shotgun")


def sniper():
    doc = Doc(-170, -112, 450, 160, prefix="sn")
    stock = smooth([(-158, -46, "c"), (-60, -44), (-30, -40, "c"), (130, -38, "c"), (130, -14, "c"), (12, -14),
                    (-6, 10), (-24, 14, "c"), (-40, -8), (-90, -4), (-156, 12, "c"), (-162, -20)])
    part(doc, stock, PURPLE, band=7,
         gloss=[(rrect_d(-140, -42, 70, 5, 2.5), 0.5), (rrect_d(30, -36, 80, 4, 2), 0.5)])
    doc.path(smooth([(-96, -30, "c"), (-56, -30, "c"), (-60, -14), (-92, -12, "c")]), fill="#2a2140",
             stroke=WINK, sw=4)  # thumbhole
    part(doc, rrect_d(-166, -48, 12, 62, 4), SLATE, band=3, rim=2)
    doc.path(smooth([(-4, -14), (0, 6), (16, 8), (20, -14)], closed=False), stroke=WINK, sw=6)
    recv = rrect_d(-26, -56, 96, 20, 6)
    part(doc, recv, SLATE, band=5, gloss=[(rrect_d(-16, -54, 60, 4, 2), 0.5)])
    doc.path(smooth([(40, -40), (52, -26)], closed=False), stroke=WINK, sw=10)
    doc.path(ellipse_d(54, -24, 7, 7), fill=SLATE.light, stroke=WINK, sw=4)  # bolt knob
    part(doc, rrect_d(68, -52, 186, 12, 5), SLATE, band=3, rim=2, gloss=[(rrect_d(74, -51, 160, 3, 1.5), 0.5)])
    part(doc, rrect_d(240, -56, 26, 20, 5), SLATE, band=3, rim=2,
         details=[smooth([(248, -54), (248, -38)], closed=False), smooth([(256, -54), (256, -38)], closed=False)])
    tip(doc, 264, -46, 16, 10)
    # scope
    for x in (0, 58):
        part(doc, rrect_d(x, -70, 14, 18, 3), SLATE, band=2, rim=1.5)
    scope = smooth([(-24, -94, "c"), (-4, -94), (10, -86, "c"), (60, -86, "c"), (74, -96), (100, -96, "c"),
                    (100, -66, "c"), (74, -66), (60, -76, "c"), (10, -76, "c"), (-4, -68), (-24, -68, "c")])
    part(doc, scope, SLATE, band=5, gloss=[(rrect_d(10, -85, 46, 4, 2), 0.55)])
    part(doc, rrect_d(28, -98, 14, 12, 3), SLATE, band=2, rim=1.5)
    part(doc, ellipse_d(100, -81, 5, 13), GLASS, band=2, rim=1.5, gloss=[(ellipse_d(99, -86, 1.6, 4), 0.9)])
    register("sniper_rifle", doc, grip=(-14, 0), muzzle=(275, -46), support=(90, -18), label="sniper rifle")


def rocket_launcher():
    doc = Doc(-150, -104, 380, 150, prefix="rl")
    # rocket poking out of the front
    part(doc, rrect_d(126, -56, 50, 30, 6), CREAM, band=4, gloss=[(rrect_d(132, -54, 36, 4, 2), 0.6)])
    nose = smooth([(170, -58, "c"), (196, -52), (214, -41, "c"), (196, -30), (170, -24, "c")])
    part(doc, nose, RED, band=5, gloss=[(ellipse_d(186, -50, 8, 3), 0.6)])
    for y in (-68, -24):
        doc.path(smooth([(150, y + (8 if y < 0 else -8)), (158, y), (168, y + (8 if y < 0 else -8))], closed=True),
                 fill=RED.base, stroke=WINK, sw=4)
    grip = smooth([(-26, -20, "c"), (2, -20, "c"), (6, 30), (0, 36, "c"), (-22, 36, "c"), (-28, 28)])
    part(doc, grip, SLATE, details=[smooth([(-20, 8), (2, 8)], closed=False)])
    doc.path(smooth([(0, -18), (2, 2), (14, 4), (18, -18)], closed=False), stroke=WINK, sw=6)
    fgrip = smooth([(46, -20, "c"), (70, -20, "c"), (72, 24), (66, 30, "c"), (48, 30, "c"), (44, 24)])
    part(doc, fgrip, SLATE, details=[smooth([(50, 4), (66, 4)], closed=False)])
    tube = smooth([(-128, -70, "c"), (-108, -64), (130, -64, "c"), (140, -60), (140, -22), (130, -18, "c"),
                   (-108, -18), (-128, -12, "c")])
    part(doc, tube, TEAL, band=9,
         shadows=[(rrect_d(-128, -32, 268, 20, 4), TEAL.shadow, 0.5)],
         gloss=[(rrect_d(-96, -60, 200, 6, 3), 0.55)])
    for x in (-80, 100):
        part(doc, rrect_d(x, -68, 16, 54, 4), SLATE, band=3, rim=2)
    part(doc, ellipse_d(-128, -41, 9, 29), SLATE, band=3, rim=2)
    doc.path(ellipse_d(-129, -41, 4, 19), fill="#1f232a")
    part(doc, ellipse_d(140, -41, 6, 22), SLATE, band=2, rim=1.5)
    sight = smooth([(-6, -64, "c"), (-2, -90, "c"), (34, -90, "c"), (38, -64, "c")])
    part(doc, sight, SLATE, band=3, details=[smooth([(6, -82), (26, -82)], closed=False)])
    doc.path(ellipse_d(34, -78, 4, 6), fill=GLASS.base, stroke=WINK, sw=3)
    register("rocket_launcher", doc, grip=(-12, 6), muzzle=(214, -41), support=(58, 6), label="rocket launcher",
             extra={"exhaust": (-136, -41)})


def frag():
    doc = Doc(-44, -56, 92, 104, prefix="fg")
    body = smooth([(0, -18), (22, -10), (30, 10), (24, 32), (0, 40), (-24, 32), (-30, 10), (-22, -10)])
    part(doc, body, RED, band=7, rim=4,
         details=[(smooth([(-26, 6), (0, 10), (28, 6)], closed=False), RED.deep, 3.5),
                  (smooth([(-24, 24), (0, 28), (24, 24)], closed=False), RED.deep, 3.5),
                  (smooth([(-10, -14), (-12, 10), (-10, 38)], closed=False), RED.deep, 3.5),
                  (smooth([(12, -14), (14, 10), (12, 38)], closed=False), RED.deep, 3.5)],
         gloss=[(ellipse_d(-12, -2, 6, 8), 0.6)])
    part(doc, rrect_d(-12, -32, 24, 18, 4), SLATE, band=3, rim=2)
    lever = smooth([(4, -34, "c"), (26, -34), (32, -24), (36, 14, "c"), (30, 16, "c"), (24, -18), (4, -24, "c")])
    part(doc, lever, SLATE, band=3, rim=2)
    doc.path(ellipse_d(-22, -32, 12, 12), stroke=WINK, sw=9)
    doc.path(ellipse_d(-22, -32, 12, 12), stroke=CREAM.base, sw=4)
    doc.path("M-10 -30L-4 -26", stroke=WINK, sw=5)
    register("frag_grenade", doc, grip=(0, 10), muzzle=(0, 10), label="frag grenade", hands=1)


def main():
    os.makedirs(OUT, exist_ok=True)
    for fn in (pistol, uzi, smg, assault_rifle, shotgun, sniper, rocket_launcher, frag):
        fn()
    data = {
        "units": "author px, 4 per game px at 720p; points are px from the file's top-left",
        "facing": "right; mirror on y-axis to face left",
        "grip": "where the trigger hand's fist centre sits",
        "support": "where the other hand holds it; absent for one-handed weapons",
        "muzzle": "where bullets and the muzzle flash leave",
        "weapons": REGISTRY,
    }
    with open(os.path.join(OUT, "weapons.json"), "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
