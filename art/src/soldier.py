"""The plastic army soldier, drawn as cutout parts.

Run: python3 art/src/soldier.py  (writes assets/toys/soldier/*.svg and rig.json)

Every part is drawn in its own frame with its pivot at (0, 0). The rest pose faces right
in a three-quarter view: the near side (the toy's left) is screen left, the back and the
jetpack are screen left too. Light comes from the upper left.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bni_svg import (DETAIL, OUTLINE, Doc, Plastic, ellipse_d, f, flat, mix, molded,  # noqa: E402
                     rrect_d, shade, smooth)

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "toys", "soldier")

INK = "#172010"
GREEN = Plastic(base="#5ea93b", light="#94d462", shadow="#3c7c28", deep="#2a5a1c",
                rim="#c8db6a", ink=INK, spec="#f6ffe6")
SCLERA = "#f4f6e6"
MOUTH = "#3a1712"
TONGUE = "#c8584c"
TEETH = "#fbfaf0"
METAL = Plastic(base="#c9ccd3", light="#f2f3f6", shadow="#8a8e99", deep="#5d616c",
                rim="#e9e3cf", ink="#1b1c22", spec="#ffffff")
TAPE = Plastic(base="#a7a9a6", light="#cfd1cc", shadow="#7c7f7a", deep="#5c5f5a",
               rim="#c6c7bd", ink="#1b1c22", spec="#ffffff")

# team colours: (main, light, dark). Greyscale is the tint source for any colour at runtime.
TEAMS = {
    "grey": ("#d9d9d9", "#ffffff", "#8c8c8c"),
    "blue": ("#2f7de1", "#7fb6ff", "#174b97"),
    "orange": ("#ff8c1a", "#ffc46e", "#b85300"),
    "pink": ("#e0509e", "#ff9ccf", "#97245f"),
    "yellow": ("#f2d02b", "#fff089", "#a88a00"),
    "neutral": ("#c46a2b", "#f0a35e", "#7a3a10"),  # free-for-all: a copper-top battery
}


def g_body(doc, top, bottom, m=GREEN):
    """Vertical light-to-base gradient for a part spanning top..bottom."""
    return doc.lin(0, top, 0, bottom, [(0, mix(m.base, m.light, 0.35)), (0.55, m.base), (1, m.base)])


# ---------------------------------------------------------------- head

HEAD = smooth([(-36, -16), (-20, -3), (8, 0), (32, -2), (48, -13), (58, -32), (61, -60), (58, -90),
               (44, -110), (16, -122), (-14, -121), (-40, -110), (-54, -88), (-57, -58), (-51, -32)])
EAR_N = ellipse_d(-55, -50, 11, 16)
EAR_F = ellipse_d(61, -50, 7, 14)
NECK = rrect_d(-21, -26, 42, 36, 10)
NOSE = smooth([(9, -48), (15, -51), (22, -44), (24, -34), (18, -29), (9, -29), (5, -35)])


def head():
    doc = Doc(-76, -136, 152, 160, prefix="hd")
    molded(doc, NECK, GREEN, band=6, rim=3, shadows=[(rrect_d(-21, -26, 42, 16, 6), GREEN.deep, 0.5)])
    molded(doc, EAR_F, GREEN, band=4, rim=3)
    molded(doc, EAR_N, GREEN, band=5, rim=3,
           details=[smooth([(-54, -60), (-60, -50), (-54, -40)], closed=False)])
    molded(doc, HEAD, GREEN, band=12, rim=7, grad=g_body(doc, -122, 0),
           shadows=[
               # forehead under the helmet brim, the far cheek plane, under the jaw
               (smooth([(-56, -90), (0, -84), (60, -88), (60, -76), (0, -72), (-56, -78)]), GREEN.deep, 0.45),
               (smooth([(40, -60), (60, -62), (56, -20), (40, -8), (34, -30)]), GREEN.shadow, 0.55),
               (smooth([(-40, -26), (-10, -12), (30, -12), (12, -1), (-24, -6)]), GREEN.deep, 0.3),
           ],
           details=[smooth([(-30, -30), (-24, -20)], closed=False),
                    smooth([(48, -30), (42, -20)], closed=False),
                    smooth([(6, -6), (18, -5)], closed=False)],
           lights=[(smooth([(-46, -66), (-26, -70), (-22, -44), (-34, -30), (-48, -42)]), GREEN.light, 0.5)],
           gloss=[(smooth([(-44, -60), (-34, -63), (-36, -48), (-44, -46)]), 0.5)])
    molded(doc, NOSE, GREEN, band=5, rim=2.5, sw=DETAIL + 0.5,
           shadows=[(smooth([(9, -31), (19, -31), (23, -36), (18, -29), (10, -29)]), GREEN.deep, 0.6)],
           gloss=[(ellipse_d(12, -44, 3, 2.5), 0.7)])
    doc.save(os.path.join(OUT, "head.svg"))


# ---------------------------------------------------------------- faces

EYE_N = (-12, -55)  # near eye centre
EYE_F = (34, -55)   # far eye centre


def brow(doc, pts, w=12):
    doc.path(smooth(pts, closed=False), stroke=INK, sw=w)


def eye(doc, cx, cy, rx, ry, px, py, pr, lid=None):
    """Sclera, pupil with a catch light, and an optional lid cutting it."""
    d = ellipse_d(cx, cy, rx, ry)
    clip = doc.clip(d)
    doc.path(d, fill=SCLERA)
    doc.open_group(f'clip-path="{clip}"')
    doc.path(ellipse_d(px, py, pr, pr * 1.08), fill=INK)
    doc.path(ellipse_d(px - pr * 0.35, py - pr * 0.42, pr * 0.34, pr * 0.34), fill="#ffffff")
    if lid:
        doc.path(lid, fill=GREEN.base)
        doc.path(lid, stroke=INK, sw=5)
    doc.close_group()
    doc.path(d, stroke=INK, sw=4.5)


def face_doc():
    return Doc(-76, -136, 152, 160, prefix="fc")


def face_determined():
    doc = face_doc()
    eye(doc, *EYE_N, 14, 12, -7, -53, 7.5, lid=smooth([(-30, -76), (2, -60), (2, -80), (-30, -80)]))
    eye(doc, *EYE_F, 13, 12, 39, -53, 7.2, lid=smooth([(20, -60), (50, -74), (50, -80), (20, -80)]))
    brow(doc, [(-30, -76), (-12, -72), (4, -62)], 13)
    brow(doc, [(20, -62), (36, -71), (52, -75)], 13)
    doc.path(smooth([(12, -72), (11, -62)], closed=False), stroke=GREEN.deep, sw=DETAIL)
    # set jaw: tight downturned mouth, lower lip shadow
    doc.path(smooth([(-6, -12), (4, -18), (26, -18), (36, -11)], closed=False), stroke=INK, sw=7)
    doc.path(smooth([(4, -8), (14, -6), (24, -8)], closed=False), stroke=GREEN.deep, sw=DETAIL)
    doc.save(os.path.join(OUT, "face_determined.svg"))


def face_cocky():
    doc = face_doc()
    eye(doc, *EYE_N, 14, 12, -6, -54, 7.5, lid=smooth([(-30, -68), (2, -64), (2, -80), (-30, -80)]))
    eye(doc, *EYE_F, 13, 13, 40, -55, 7.2, lid=smooth([(20, -70), (50, -66), (50, -80), (20, -80)]))
    brow(doc, [(-30, -71), (-12, -74), (2, -71)], 12)
    brow(doc, [(20, -78), (36, -88), (52, -82)], 12)
    # lopsided grin, teeth showing, up on the far side
    grin = smooth([(-10, -22), (8, -18), (30, -22), (48, -34, "c"), (46, -18), (32, -5), (10, -5), (-4, -12)])
    doc.path(grin, fill=MOUTH)
    clip = doc.clip(grin)
    doc.open_group(f'clip-path="{clip}"')
    doc.path(smooth([(-12, -28), (50, -42), (50, -20), (-10, -15)]), fill=TEETH)
    for x in (8, 22, 34):
        doc.path(f"M{x} -30V-10", stroke="#c9c7b8", sw=2.5)
    doc.close_group()
    doc.path(grin, stroke=INK, sw=6)
    doc.path(smooth([(49, -38), (53, -28)], closed=False), stroke=GREEN.deep, sw=DETAIL)
    doc.save(os.path.join(OUT, "face_cocky.svg"))


def face_hurt():
    doc = face_doc()
    doc.path(smooth([(-24, -64), (-4, -55), (-22, -46)], closed=False), stroke=INK, sw=8)
    doc.path(smooth([(46, -64), (28, -55), (44, -46)], closed=False), stroke=INK, sw=8)
    brow(doc, [(-30, -64), (-14, -70), (2, -80)], 12)
    brow(doc, [(22, -80), (38, -71), (52, -66)], 12)
    m = smooth([(-10, -26, "c"), (12, -30), (40, -27, "c"), (44, -8, "c"), (16, -4), (-8, -8, "c")])
    doc.path(m, fill=MOUTH)
    clip = doc.clip(m)
    doc.open_group(f'clip-path="{clip}"')
    doc.path(rrect_d(-12, -28, 58, 11, 2), fill=TEETH)
    doc.path(rrect_d(-12, -16, 58, 11, 2), fill=TEETH)
    for x in (2, 14, 26, 36):
        doc.path(f"M{x} -32V-2", stroke="#c9c7b8", sw=2.5)
    doc.close_group()
    doc.path(m, stroke=INK, sw=6)
    # plastic crack on the cheek
    doc.path("M-46 -38L-36 -30L-42 -22L-32 -14", stroke=INK, sw=3.5)
    doc.path("M-36 -30L-28 -33", stroke=INK, sw=2.6)
    drop = smooth([(-44, -108, "c"), (-36, -94), (-39, -86), (-48, -86), (-50, -95)])
    flat(doc, drop, "#bfe9ff", ink=INK, sw=3.5)
    doc.path(ellipse_d(-43, -93, 2, 3), fill="#ffffff")
    doc.save(os.path.join(OUT, "face_hurt.svg"))


def face_shocked():
    doc = face_doc()
    eye(doc, *EYE_N, 15, 16, -11, -55, 5.5)
    eye(doc, *EYE_F, 14, 15, 35, -55, 5.2)
    brow(doc, [(-30, -82), (-14, -88), (0, -82)], 10)
    brow(doc, [(22, -82), (36, -88), (50, -82)], 10)
    o = ellipse_d(14, -16, 11, 13)
    doc.path(o, fill=MOUTH)
    doc.path(ellipse_d(14, -8, 7, 4.5), fill=TONGUE)
    doc.path(o, stroke=INK, sw=6)
    doc.save(os.path.join(OUT, "face_shocked.svg"))


# ---------------------------------------------------------------- helmet

HELMET = smooth([(-66, -66, "c"), (-74, -84), (-70, -106), (-54, -127), (-22, -141), (16, -141),
                 (50, -130), (68, -112), (76, -98), (86, -90, "c"), (82, -81, "c"), (40, -84),
                 (-10, -79), (-48, -72)])
HELMET_PIVOT = (6, -108)  # in head frame: where the helmet spins when it flies off


def helmet():
    px, py = HELMET_PIVOT
    doc = Doc(-84 - px, -150 - py, 178, 94, prefix="hm")
    doc.open_group(f'transform="translate({-px} {-py})"')
    molded(doc, HELMET, GREEN, band=12, rim=7, grad=g_body(doc, -141, -66),
           shadows=[(smooth([(-68, -82), (-10, -90), (80, -94), (84, -85), (40, -84), (-10, -79), (-62, -70)]),
                     GREEN.deep, 0.6)],
           details=[smooth([(-68, -84), (-10, -92), (40, -94), (80, -94)], closed=False)],
           lights=[(smooth([(-54, -106), (-32, -127), (0, -135), (-10, -120), (-38, -104)]), GREEN.light, 0.6)],
           gloss=[(smooth([(-42, -116), (-22, -130), (-4, -133), (-14, -123), (-34, -110)]), 0.7),
                  (ellipse_d(28, -129, 7, 3.5), 0.5)])
    for dy in (0, 10):
        doc.path(smooth([(8, -116 + dy, "c"), (21, -107 + dy, "c"), (34, -116 + dy, "c")], closed=False),
                 stroke=GREEN.deep, sw=5.5)
        doc.path(smooth([(8, -118 + dy, "c"), (21, -109 + dy, "c"), (34, -118 + dy, "c")], closed=False),
                 stroke=GREEN.light, sw=2, extra='opacity="0.8"')
    doc.close_group()
    doc.save(os.path.join(OUT, "helmet.svg"))


# ---------------------------------------------------------------- torso

TORSO = smooth([(-42, -82), (-18, -90), (20, -90), (46, -83), (60, -68), (63, -44), (58, -20),
                (54, -4), (53, 12), (24, 23), (-12, 23), (-44, 14), (-47, -4), (-46, -24),
                (-52, -50), (-56, -72)])
NECK_POS = (6, -84)
NEAR_SHOULDER = (-30, -66)
FAR_SHOULDER = (44, -66)
NEAR_HIP = (-18, 6)
FAR_HIP = (22, 6)
JETPACK_POS = (-50, -34)


def torso():
    doc = Doc(-70, -104, 146, 142, prefix="to")
    belt = smooth([(-47, -14, "c"), (55, -14, "c"), (55, 2, "c"), (-47, 2, "c")])
    grad = doc.lin(-40, -90, 60, 20, [(0, mix(GREEN.base, GREEN.light, 0.45)), (0.45, GREEN.base),
                                      (1, mix(GREEN.base, GREEN.shadow, 0.5))])
    molded(doc, TORSO, GREEN, band=12, rim=7, grad=grad,
           shadows=[
               (smooth([(-46, 2), (54, 2), (53, 12), (22, 22), (-10, 22), (-44, 12)]), GREEN.shadow, 0.6),
               (smooth([(32, -58), (62, -56), (58, -16), (38, -16)]), GREEN.shadow, 0.55),
               (smooth([(-16, -90), (18, -90), (14, -78), (2, -72), (-12, -78)]), GREEN.deep, 0.7),
           ],
           details=[
               smooth([(-20, -88), (-8, -72, "c"), (4, -78), (2, -88)], closed=False),
               smooth([(4, -78), (16, -70, "c"), (24, -86)], closed=False),
               smooth([(14, -70), (16, -40), (18, -16)], closed=False),
               smooth([(-30, -60, "c"), (2, -58, "c"), (2, -34), (-28, -34), (-30, -60, "c")], closed=False),
               smooth([(-31, -60), (-14, -50), (3, -58)], closed=False),
               smooth([(26, -58, "c"), (48, -58, "c"), (48, -38), (28, -38), (26, -58, "c")], closed=False),
               smooth([(-36, -26), (-26, -16)], closed=False),
               smooth([(36, -28), (30, -16)], closed=False),
               smooth([(16, 4), (14, 21)], closed=False),
           ],
           lights=[(smooth([(-38, -78), (-14, -82), (-20, -62), (-40, -46), (-46, -64)]), GREEN.light, 0.4)],
           gloss=[(smooth([(-40, -76), (-28, -80), (-34, -66), (-42, -60)]), 0.45),
                  (ellipse_d(-14, -52, 6, 3), 0.35)])
    molded(doc, belt, GREEN, band=4, rim=2, sw=DETAIL + 1,
           grad=doc.lin(0, -14, 0, 2, [(0, GREEN.base), (1, GREEN.shadow)]))
    molded(doc, rrect_d(8, -17, 20, 22, 4), GREEN, band=3, rim=2, sw=DETAIL + 1,
           gloss=[(ellipse_d(14, -11, 3, 2), 0.7)])
    for x, w in ((-38, 20), (34, 16)):
        molded(doc, rrect_d(x, -10, w, 22, 5), GREEN, band=4, rim=2, sw=DETAIL + 1,
               details=[smooth([(x + 2, -3), (x + w - 2, -3)], closed=False)])
    for pts in ([(-40, -86), (-34, -64), (-30, -36), (-30, -14)], [(30, -90), (36, -68), (40, -36), (42, -14)]):
        doc.path(smooth(pts, closed=False), stroke=INK, sw=15)
        doc.path(smooth(pts, closed=False), stroke=GREEN.shadow, sw=8)
        doc.path(smooth([(p[0] - 2, p[1]) for p in pts], closed=False), stroke=GREEN.base, sw=3)
    doc.save(os.path.join(OUT, "torso.svg"))


# ---------------------------------------------------------------- arms

UPPER_ARM = smooth([(-19, -12), (0, -22), (19, -12), (22, 12), (18, 50), (14, 70), (0, 77), (-14, 70),
                    (-18, 50), (-22, 12)])
ELBOW = (0, 62)
FOREARM = smooth([(-16, -12), (0, -16), (16, -12), (16, 20), (15, 42), (-15, 42), (-16, 20)])
CUFF = smooth([(-18, 30, "c"), (18, 30, "c"), (18, 44, "c"), (-18, 44, "c")])
FIST = smooth([(-14, 42), (6, 40), (18, 46), (21, 62), (16, 76), (2, 82), (-12, 78), (-18, 64)])
THUMB = smooth([(-6, 50), (6, 52), (10, 60), (2, 64), (-6, 60)])
GRIP = (3, 62)  # where a weapon grip sits in the fist


def upper_arm(name="upper_arm"):
    doc = Doc(-34, -34, 68, 122, prefix="ua")
    molded(doc, UPPER_ARM, GREEN, band=9, rim=6, grad=g_body(doc, -22, 77),
           details=[smooth([(-14, 34), (-4, 40)], closed=False), smooth([(6, 52), (14, 46)], closed=False),
                    smooth([(-18, 4), (0, 10), (20, 4)], closed=False)],
           lights=[(smooth([(-16, -8), (-4, -16), (-8, 10), (-16, 30)]), GREEN.light, 0.45)],
           gloss=[(smooth([(-13, -6), (-6, -12), (-8, 2), (-13, 8)]), 0.55)])
    doc.save(os.path.join(OUT, f"{name}.svg"))


def forearm(name="forearm"):
    doc = Doc(-32, -28, 64, 122, prefix="fa")
    molded(doc, FOREARM, GREEN, band=8, rim=3, grad=g_body(doc, -16, 42),
           details=[smooth([(-10, 8), (0, 14)], closed=False)],
           lights=[(smooth([(-13, -8), (-4, -12), (-8, 20), (-13, 26)]), GREEN.light, 0.4)])
    molded(doc, CUFF, GREEN, band=3, rim=2, sw=DETAIL + 1)
    molded(doc, FIST, GREEN, band=7, rim=3,
           details=[smooth([(14, 50), (18, 62), (14, 74)], closed=False),
                    smooth([(6, 58), (16, 58)], closed=False), smooth([(6, 68), (16, 68)], closed=False)],
           gloss=[(ellipse_d(-6, 50, 5, 3), 0.55)])
    molded(doc, THUMB, GREEN, band=3, rim=2, sw=DETAIL + 1)
    doc.save(os.path.join(OUT, f"{name}.svg"))


# ---------------------------------------------------------------- legs

THIGH = smooth([(-22, -12), (0, -17), (22, -12), (23, 22), (20, 58), (15, 75), (0, 80), (-15, 75),
                (-20, 58), (-23, 22)])
KNEE = (0, 67)
SHIN = smooth([(-18, -12), (0, -15), (18, -12), (19, 30), (-19, 30)])
BLOUSE = smooth([(-22, 26), (0, 22), (22, 26), (24, 38), (20, 46), (-20, 46), (-24, 38)])
BOOT = smooth([(-20, 40, "c"), (18, 40, "c"), (21, 54), (38, 60), (48, 68), (47, 78, "c"), (-22, 78, "c"),
               (-24, 66), (-22, 52)])
SOLE = smooth([(-23, 70, "c"), (48, 70, "c"), (47, 79, "c"), (-22, 79, "c")])
FOOT_GROUND = 79  # sole bottom in shin frame


def thigh(name="thigh"):
    doc = Doc(-36, -30, 72, 124, prefix="th")
    molded(doc, THIGH, GREEN, band=10, rim=7, grad=g_body(doc, -17, 75),
           details=[smooth([(-10, 16, "c"), (8, 16, "c"), (8, 40), (-10, 40), (-10, 16, "c")], closed=False),
                    smooth([(-11, 16), (8, 22)], closed=False),
                    smooth([(10, 56), (16, 50)], closed=False)],
           lights=[(smooth([(-18, -6), (-6, -12), (-12, 14), (-19, 30)]), GREEN.light, 0.45)],
           gloss=[(smooth([(-16, -4), (-9, -9), (-12, 4), (-16, 10)]), 0.5)])
    doc.save(os.path.join(OUT, f"{name}.svg"))


def shin(name="shin"):
    doc = Doc(-36, -28, 98, 120, prefix="sh")
    molded(doc, SHIN, GREEN, band=8, rim=3, grad=g_body(doc, -15, 30),
           lights=[(smooth([(-15, -8), (-6, -11), (-10, 12), (-15, 20)]), GREEN.light, 0.4)])
    molded(doc, BOOT, GREEN, band=8, rim=6, grad=g_body(doc, 40, 78),
           details=[smooth([(20, 56), (24, 66)], closed=False), smooth([(28, 60), (32, 68)], closed=False),
                    smooth([(-20, 56), (10, 58)], closed=False)],
           gloss=[(smooth([(30, 62), (40, 64), (42, 68), (32, 67)]), 0.55)])
    molded(doc, SOLE, GREEN, band=2, rim=1.5, sw=DETAIL + 1,
           grad=doc.lin(0, 70, 0, 79, [(0, GREEN.shadow), (1, GREEN.deep)]))
    molded(doc, BLOUSE, GREEN, band=5, rim=3, sw=DETAIL + 2,
           details=[smooth([(-12, 30), (-8, 44)], closed=False), smooth([(4, 28), (6, 44)], closed=False)])
    doc.save(os.path.join(OUT, f"{name}.svg"))


# ---------------------------------------------------------------- jetpack

# two AA batteries side by side on the back; frame origin is the mount on the torso
BATT = [(-26, 2), (8, -8)]  # (centre x, centre y) for near and far battery
BATT_R = 23
BATT_H = 150
NOZZLE_Y = 92  # exit, below each battery centre


def _batt_shapes(cx, cy):
    top, bot = cy - BATT_H / 2, cy + BATT_H / 2
    body = rrect_d(cx - BATT_R, top, BATT_R * 2, BATT_H, 9)
    cap = smooth([(cx - BATT_R + 1, top + 14, "c"), (cx - BATT_R + 1, top + 6), (cx - BATT_R + 8, top),
                  (cx + BATT_R - 8, top), (cx + BATT_R - 1, top + 6), (cx + BATT_R - 1, top + 14, "c")])
    nub = rrect_d(cx - 8, top - 11, 16, 14, 4)
    base = smooth([(cx - BATT_R + 1, bot - 9, "c"), (cx + BATT_R - 1, bot - 9, "c"), (cx + BATT_R - 1, bot - 4),
                   (cx + BATT_R - 7, bot), (cx - BATT_R + 7, bot), (cx - BATT_R + 1, bot - 4)])
    wrap = smooth([(cx - BATT_R, top + 14, "c"), (cx + BATT_R, top + 14, "c"), (cx + BATT_R, bot - 9, "c"),
                   (cx - BATT_R, bot - 9, "c")])
    nozzle = smooth([(cx - 13, bot - 2, "c"), (cx + 13, bot - 2, "c"), (cx + 19, bot + 20, "c"),
                     (cx - 19, bot + 20, "c")])
    nozzle_lip = rrect_d(cx - 21, bot + 15, 42, 9, 4)
    return dict(body=body, cap=cap, nub=nub, base=base, wrap=wrap, nozzle=nozzle, lip=nozzle_lip,
                top=top, bot=bot)


def _wire_paths():
    (nx, ny), (fx, fy) = BATT
    ntop, ftop = ny - BATT_H / 2 - 10, fy - BATT_H / 2 - 10
    near = [(nx, ntop), (nx - 8, ntop - 22), (nx + 14, ntop - 34), (nx + 34, ntop - 18), (nx + 46, ntop - 30),
            (nx + 62, ntop - 14), (nx + 74, ntop + 6)]
    far = [(fx, ftop), (fx + 10, ftop - 24), (fx + 30, ftop - 22), (fx + 36, ftop - 2), (fx + 50, ftop + 8)]
    # a loop hanging down the near battery's side
    side = [(nx - BATT_R + 2, ny - 30), (nx - BATT_R - 16, ny - 14), (nx - BATT_R - 12, ny + 12),
            (nx - BATT_R + 2, ny + 22)]
    return [near, far, side]


def jetpack_layers():
    """Write jetpack_back, jetpack_team (greyscale tint source and baked team colours) and jetpack_front."""
    box = (-80, -112, 160, 220)
    # back: metal ends, nozzles, outlines
    doc = Doc(*box, prefix="jb")
    for i, (cx, cy) in enumerate(reversed(BATT)):
        s = _batt_shapes(cx, cy)
        dim = i == 0
        molded(doc, s["nozzle"], METAL, band=6, rim=3,
               grad=doc.lin(cx - 19, 0, cx + 19, 0, [(0, METAL.light), (0.4, METAL.base), (1, METAL.shadow)]))
        molded(doc, s["lip"], METAL, band=3, rim=2, sw=DETAIL + 1.5)
        doc.path(ellipse_d(cx, s["bot"] + 22, 13, 3.5), fill="#2a2b31")
        molded(doc, s["nub"], METAL, band=3, rim=2, gloss=[(ellipse_d(cx - 3, s["top"] - 6, 2.5, 2), 0.8)])
        doc.path(s["body"], fill="#2b2d33")
        molded(doc, s["cap"], METAL, band=4, rim=2, outline=False,
               grad=doc.lin(cx - BATT_R, 0, cx + BATT_R, 0,
                            [(0, METAL.light), (0.35, METAL.base), (1, METAL.shadow)]))
        molded(doc, s["base"], METAL, band=3, rim=2, outline=False,
               grad=doc.lin(cx - BATT_R, 0, cx + BATT_R, 0,
                            [(0, METAL.light), (0.35, METAL.base), (1, METAL.shadow)]))
        doc.path(s["body"], stroke=METAL.ink, sw=OUTLINE)
        if dim:  # far battery sits in the near one's shadow
            doc.path(s["body"], fill="#000000", op=0.18)
    doc.save(os.path.join(OUT, "jetpack_back.svg"))

    # team layer: wraps and wires; one file per palette
    for team, (main, light, dark) in TEAMS.items():
        doc = Doc(*box, prefix="jt")
        for i, (cx, cy) in enumerate(reversed(BATT)):
            s = _batt_shapes(cx, cy)
            g = doc.lin(cx - BATT_R, 0, cx + BATT_R, 0,
                        [(0, mix(main, light, 0.5)), (0.3, main), (0.75, main), (1, dark)])
            doc.path(s["wrap"], fill=g)
            band_top = s["top"] + 14
            stripe = rrect_d(cx - BATT_R, band_top + 8, BATT_R * 2, 12, 1)
            doc.path(stripe, fill=mix(main, light, 0.7) if team != "neutral" else "#2b2d33")
            # plus sign
            px, py = cx - 2, cy + 6
            doc.path(f"M{f(px - 8)} {f(py)}H{f(px + 8)}M{f(px)} {f(py - 8)}V{f(py + 8)}",
                     stroke=mix(main, light, 0.75) if team != "neutral" else "#f0d7b8", sw=5)
            doc.path(s["wrap"], fill="none", stroke=dark, sw=2)
            if i == 0:
                doc.path(s["wrap"], fill="#000000", op=0.18)
        for k, w in enumerate(_wire_paths()):
            d = smooth(w, closed=False)
            doc.path(d, stroke="#14161b", sw=12)
            doc.path(d, stroke=main if team != "neutral" else "#d23a2a", sw=6)
            doc.path(d, stroke=light if team != "neutral" else "#ff8d7a", sw=2, op=0.8,
                     extra='transform="translate(-1 -1.5)"')
        name = "jetpack_team" if team == "grey" else f"jetpack_team_{team}"
        doc.save(os.path.join(OUT, f"{name}.svg"))

    # front: duct tape bands, gloss on the batteries
    doc = Doc(*box, prefix="jf")
    (nx, ny), (fx, fy) = BATT
    for y0 in (-34, 30):
        tape = smooth([(nx - BATT_R - 4, y0, "c"), (fx - 6, y0 - 6), (fx + BATT_R + 4, y0 - 10, "c"),
                       (fx + BATT_R + 4, y0 + 8, "c"), (fx - 6, y0 + 12), (nx - BATT_R - 4, y0 + 18, "c")])
        molded(doc, tape, TAPE, band=4, rim=2, sw=DETAIL + 2,
               details=[(smooth([(nx - 8, y0 + 2), (nx + 2, y0 + 10)], closed=False), TAPE.deep, 2),
                        (smooth([(fx + 4, y0 - 4), (fx + 10, y0 + 4)], closed=False), TAPE.deep, 2)])
        # torn end
        doc.path(f"M{f(nx - BATT_R - 4)} {f(y0)}l-6 5l5 4l-5 5l6 4", fill=TAPE.base, stroke=TAPE.ink,
                 sw=DETAIL)
    for cx, cy in BATT:
        doc.path(rrect_d(cx - BATT_R + 6, cy - BATT_H / 2 + 20, 7, BATT_H - 40, 3.5), fill="#ffffff", op=0.38)
        doc.path(ellipse_d(cx - BATT_R + 10, cy - BATT_H / 2 + 34, 3, 9), fill="#ffffff", op=0.7)
    doc.save(os.path.join(OUT, "jetpack_front.svg"))


def nozzles():
    """Nozzle exits in jetpack frame, for thrust effects."""
    return [[cx, cy + BATT_H / 2 + 22] for cx, cy in BATT]


# ---------------------------------------------------------------- rig

def rig():
    shin_len = KNEE[1]
    hip_y = -(shin_len + FOOT_GROUND)  # hip joint height above ground
    waist_y = hip_y - NEAR_HIP[1]
    parts = [
        # name, file, pivot in file px, parent, pos in parent frame, z, side
        ("far_upper_arm", "upper_arm.svg", "torso", FAR_SHOULDER, 1, "far"),
        ("far_forearm", "forearm.svg", "far_upper_arm", ELBOW, 2, "far"),
        ("far_thigh", "thigh.svg", "torso", FAR_HIP, 3, "far"),
        ("far_shin", "shin.svg", "far_thigh", KNEE, 4, "far"),
        ("jetpack_back", "jetpack_back.svg", "torso", JETPACK_POS, 5, None),
        ("jetpack_team", "jetpack_team.svg", "jetpack_back", (0, 0), 6, None),
        ("jetpack_front", "jetpack_front.svg", "jetpack_back", (0, 0), 7, None),
        ("near_thigh", "thigh.svg", "torso", NEAR_HIP, 8, "near"),
        ("near_shin", "shin.svg", "near_thigh", KNEE, 9, "near"),
        ("torso", "torso.svg", "root", (0, waist_y), 10, None),
        ("head", "head.svg", "torso", NECK_POS, 11, None),
        ("face", "face_determined.svg", "head", (0, 0), 12, None),
        ("helmet", "helmet.svg", "head", HELMET_PIVOT, 13, None),
        ("near_upper_arm", "upper_arm.svg", "torso", NEAR_SHOULDER, 15, "near"),
        ("near_forearm", "forearm.svg", "near_upper_arm", ELBOW, 16, "near"),
    ]
    out = []
    for name, file, parent, pos, z, side in parts:
        with open(os.path.join(OUT, file)) as fh:
            txt = fh.read()
        import re
        vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', txt).group(1).split()]
        entry = {"name": name, "file": file, "pivot": [-vb[0], -vb[1]], "size": [vb[2], vb[3]],
                 "parent": parent, "pos": list(pos), "rot": 0, "z": z}
        if side == "far":
            entry["modulate"] = [0.78, 0.82, 0.78, 1.0]
        out.append(entry)
    data = {
        "toy": "soldier",
        "units": "author px, 4 per game px at 720p; 8 per world unit u; the toy stands about 360 tall",
        "facing": "right; mirror the root on x to face left",
        "root": "ground contact point, between the feet",
        "rot": "degrees, clockwise, applied about the pivot",
        "pivot": "the joint, in px from the file's top-left",
        "pos": "where the pivot sits in the parent's frame (parent pivot at 0,0)",
        "z": "draw order, low first; the weapon goes in at 14",
        "parts": out,
        "faces": {k: f"face_{k}.svg" for k in ("determined", "cocky", "hurt", "shocked")},
        "team": {
            "layer": "jetpack_team",
            "tint_source": "jetpack_team.svg is greyscale; modulate it with the team colour",
            "baked": {t: f"jetpack_team_{t}.svg" for t in TEAMS if t != "grey"},
            "outline": "a thin team-colour outline around the whole toy is a shader on the composed toy",
        },
        "sockets": {
            "weapon_grip": {"parent": "near_forearm", "pos": list(GRIP),
                            "note": "trigger hand: the near arm, drawn over the weapon"},
            "weapon_support": {"parent": "far_forearm", "pos": list(GRIP),
                               "note": "support hand: the far arm, reaching from the front shoulder"},
            "thrust": [{"parent": "jetpack_back", "pos": p, "dir": [0, 1]} for p in nozzles()],
            "head_centre": {"parent": "head", "pos": [2, -60]},
            "name_tag": {"parent": "root", "pos": [0, -400]},
        },
        "hitbox_u": {"body": [24, 20], "head_radius": 10.5, "head_above_body_origin": 14,
                     "note": "T-18. Looks never change it; 8 author px per u"},
    }
    with open(os.path.join(OUT, "rig.json"), "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    head()
    face_determined()
    face_cocky()
    face_hurt()
    face_shocked()
    helmet()
    torso()
    upper_arm()
    forearm()
    thigh()
    shin()
    jetpack_layers()
    rig()


if __name__ == "__main__":
    main()
