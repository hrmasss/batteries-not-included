"""Pickups that are not weapons: the health pack and the battery pack, as molded toy props.

Run: python3 art/src/pickups.py  (writes assets/pickups/*.svg and pickups.json)

Colours keep clear of the team hues, like the weapons. No red cross: the health pack is a toy
lunch-box case with a heart.
"""

import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
from bni_svg import Doc, Plastic, ellipse_d, molded, rrect_d, smooth  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "pickups")

WINK = "#1b1c22"
CREAM = Plastic(base="#f3ead2", light="#fffbf0", shadow="#c7b690", deep="#8c7d5c", rim="#fff7de", ink=WINK)
RED = Plastic(base="#e5473b", light="#ff8e74", shadow="#a82a22", deep="#741a15", rim="#ffb28d", ink=WINK)
TEAL = Plastic(base="#1fb5a2", light="#71e8d6", shadow="#127a6c", deep="#0b4f47", rim="#b0f7ec", ink=WINK)
SLATE = Plastic(base="#5b6474", light="#8f99ab", shadow="#3d4451", deep="#272c35", rim="#a3acbf", ink=WINK)
METAL = Plastic(base="#c9ccd3", light="#f2f3f6", shadow="#8a8e99", deep="#5d616c", rim="#e9e3cf", ink=WINK)

REGISTRY = {}


def health_pack():
    doc = Doc(-64, -108, 128, 112, prefix="hp")
    # handle
    molded(doc, smooth([(-24, -78, "c"), (24, -78, "c"), (26, -60), (16, -60), (14, -68, "c"), (-14, -68, "c"),
                        (-16, -60), (-26, -60)]), RED, band=3, rim=2)
    # case
    molded(doc, rrect_d(-56, -64, 112, 64, 12), CREAM, band=8, rim=3,
           gloss=[(rrect_d(-44, -58, 60, 6, 3), 0.6)])
    doc.path(rrect_d(-56, -40, 112, 6, 2), fill=CREAM.shadow, op=0.8)
    # latches
    for x in (-40, 34):
        molded(doc, rrect_d(x, -44, 8, 14, 2), METAL, band=2, rim=1.5)
    # heart
    heart = smooth([(0, -12), (-18, -26, "c"), (-20, -42), (-10, -50), (0, -44), (10, -50), (20, -42), (18, -26, "c")])
    molded(doc, heart, RED, band=4, rim=2, gloss=[(ellipse_d(-9, -40, 4, 3), 0.7)])
    register("health_pack", doc, (0, 0))


def battery_pack():
    doc = Doc(-56, -134, 112, 138, prefix="bp")
    # terminals
    for x in (-22, 14):
        molded(doc, rrect_d(x, -128, 14, 16, 3), METAL, band=3, rim=1.5)
    # body: a chunky toy power cell, slate with a teal band
    molded(doc, rrect_d(-48, -116, 96, 116, 14), SLATE, band=9, rim=3,
           gloss=[(rrect_d(-38, -104, 8, 80, 4), 0.45)])
    molded(doc, rrect_d(-48, -84, 96, 50, 4), TEAL, band=6, rim=2, outline=False)
    doc.path(rrect_d(-48, -84, 96, 50, 4), fill="none", stroke=WINK, sw=3)
    # bolt
    bolt = smooth([(6, -80), (-14, -56), (-2, -56), (-8, -38), (14, -62), (2, -62), (8, -80)], tension=0.0)
    molded(doc, bolt, CREAM, band=2, rim=1.5)
    register("battery_pack", doc, (0, 0))


def register(name, doc, origin):
    doc.save(os.path.join(OUT, f"{name}.svg"))
    REGISTRY[name] = {"file": f"{name}.svg", "size": [doc.w, doc.h],
                      "origin": [origin[0] - doc.x0, origin[1] - doc.y0]}


def main():
    os.makedirs(OUT, exist_ok=True)
    health_pack()
    battery_pack()
    data = {
        "units": "author px, 4 per game px at 720p; origin is the floor contact, px from the file's top-left",
        "pickups": REGISTRY,
    }
    with open(os.path.join(OUT, "pickups.json"), "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
