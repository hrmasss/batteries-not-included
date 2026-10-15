"""Contact sheets for the art lab: cast, weapons, map kit, effects.

Run: python3 art/tools/sheets.py [out_dir]   (default art/previews)
Each sheet is built from the assets and their json, the way the game will read them.
"""

import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose as c  # noqa: E402
import frame  # noqa: E402

BG = "#2b2d31"
PANEL = "#34373d"
TEXT = "#ece8dc"
DIM = "#9a9da5"
TEAM = {"blue": "#1f63d6", "orange": "#ff8c1a", "pink": "#ff8fcb", "yellow": "#f2d02b"}


def title(x, y, text, sub=None, size=44):
    out = [c.label(x, y, text, size, TEXT, "start", 800)]
    if sub:
        out.append(c.label(x, y + size * 0.9, sub, size * 0.5, DIM, "start", 500))
    return c.raw("".join(out))


def panel(x, y, w, h, colour=PANEL):
    return c.raw(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="18" fill="{colour}"/>')


def tag(x, y, text, size=22, colour=TEXT, anchor="middle"):
    return c.raw(c.label(x, y, text, size, colour, anchor, 600))


def dot(x, y, colour="#ff2d55", r=5):
    return c.raw(f'<circle cx="{c.f(x)}" cy="{c.f(y)}" r="{r}" fill="{colour}" stroke="#000" stroke-width="1.5"/>')


# ---------------------------------------------------------------- cast

def cast_sheet(out):
    W, H = 2400, 2050
    parts, glow = [], []
    parts.append(title(60, 90, "Toy 01: the plastic army soldier",
                       "Cutout parts in SVG, assembled by rig.json and poses.json. Light from the upper left."))
    # 1. exploded parts with pivots
    parts.append(panel(40, 160, 1100, 820))
    parts.append(tag(70, 205, "Parts and pivots (red), author scale x0.9", 24, TEXT, "start"))
    r = c.rig()
    seen = set()
    layout = {"head.svg": (190, 480), "helmet.svg": (190, 270), "face_determined.svg": None,
              "torso.svg": (420, 430), "upper_arm.svg": (610, 380), "forearm.svg": (720, 380),
              "thigh.svg": (840, 380), "shin.svg": (960, 380),
              "jetpack_back.svg": (300, 760), "jetpack_team_blue.svg": (520, 760), "jetpack_front.svg": (740, 760)}
    for f_, pos in layout.items():
        if pos is None or f_ in seen:
            continue
        seen.add(f_)
        x, y = pos
        path = os.path.join(c.SOLDIER, f_)
        parts.append(c.place(path, x, y, scale=0.9))
        parts.append(dot(x, y))
        dy = 150 if "jetpack" in f_ else (70 if f_ == "helmet.svg" else 120)
        parts.append(tag(x, y + dy, f_.replace(".svg", "").replace("_", " "), 18, DIM))
    # jetpack assembled
    jx, jy = 960, 760
    for f_ in ("jetpack_back.svg", "jetpack_team_blue.svg", "jetpack_front.svg"):
        parts.append(c.place(os.path.join(c.SOLDIER, f_), jx, jy, scale=0.9))
    for s in r["sockets"]["thrust"]:
        parts.append(dot(jx + s["pos"][0] * 0.9, jy + s["pos"][1] * 0.9, "#ffd23a"))
    parts.append(tag(jx, jy + 150, "jetpack: 3 layers, nozzles (yellow)", 18, DIM))

    # 2. faces
    parts.append(panel(1180, 160, 1180, 820))
    parts.append(tag(1210, 205, "Faces: swap one sprite. Big, and at game size below", 24, TEXT, "start"))
    hp = [p for p in r["parts"] if p["name"] == "helmet"][0]["pos"]
    for i, face in enumerate(("determined", "cocky", "hurt", "shocked")):
        x = 1330 + i * 280
        for f_ in ("head.svg", f"face_{face}.svg"):
            parts.append(c.place(os.path.join(c.SOLDIER, f_), x, 560, scale=1.7))
        parts.append(c.place(os.path.join(c.SOLDIER, "helmet.svg"), x + hp[0] * 1.7, 560 + hp[1] * 1.7, scale=1.7))
        for f_ in ("head.svg", f"face_{face}.svg"):
            parts.append(c.place(os.path.join(c.SOLDIER, f_), x, 830, scale=0.25))
        parts.append(c.place(os.path.join(c.SOLDIER, "helmet.svg"), x + hp[0] * 0.25, 830 + hp[1] * 0.25, scale=0.25))
        for f_ in ("head.svg", f"face_{face}.svg"):
            parts.append(c.place(os.path.join(c.SOLDIER, f_), x, 940, scale=0.5))
        parts.append(c.place(os.path.join(c.SOLDIER, "helmet.svg"), x + hp[0] * 0.5, 940 + hp[1] * 0.5, scale=0.5))
        parts.append(tag(x, 690, face, 26))
    parts.append(tag(1210, 845, "1x", 18, DIM, "start"))
    parts.append(tag(1210, 945, "2x", 18, DIM, "start"))

    # 3. poses
    parts.append(panel(40, 1020, 2320, 990))
    parts.append(tag(70, 1065, "Four poses, author scale x1.1, then at game scale (1x) and 2x with the team outline",
                     24, TEXT, "start"))
    poses = [("stand", None), ("run", None), ("fly", "fly with thrust"), ("aim", None)]
    for i, (pn, lab) in enumerate(poses):
        x = 300 + i * 560
        info = {}
        g = c.toy(pn, root=(x, 1560), team="blue", scale=1.1, info=info)
        parts.append(g)
        if c.poses()[pn].get("thrust"):
            for m in info["nozzles"]:
                glow.append(c.place_m(os.path.join(c.ASSETS, "fx", "thrust_glow.svg"), m))
        if "muzzle" in info and pn == "aim":
            parts.append(c.place_m(os.path.join(c.ASSETS, "fx", "muzzle_flash.svg"), info["muzzle"]))
            glow.append(c.place_m(os.path.join(c.ASSETS, "fx", "muzzle_flash_glow.svg"), info["muzzle"]))
        parts.append(tag(x, 1630, lab or pn, 28))
        # game scale and 2x, two teams
        parts.append(c.toy(pn, root=(x - 140, 1900), team="orange", scale=0.25, outline=TEAM["orange"],
                           facing=-1))
        parts.append(c.toy(pn, root=(x - 60, 1900), team="blue", scale=0.25, outline=TEAM["blue"]))
        parts.append(c.toy(pn, root=(x + 110, 1960), team="pink", scale=0.5, outline=TEAM["pink"]))
    parts.append(tag(70, 1990, "1x = 90 px tall on a 720 px screen", 18, DIM, "start"))
    c.render_add(parts, glow, W, H, out, bg=BG)


def team_sheet(out):
    W, H = 2400, 760
    parts = [title(60, 90, "Team marks: battery wraps and wires, plus a thin outline",
                   "Same toy, every team. Greyscale layer for a runtime tint; baked colours ship too. "
                   "Colour-blind check by lightness: see the grey row.")]
    teams = [("grey", "tint source", None), ("blue", "blue", "blue"), ("orange", "orange", "orange"),
             ("pink", "pink", "pink"), ("yellow", "yellow", "yellow"), ("neutral", "free-for-all", None)]
    for i, (t, lab, oc) in enumerate(teams):
        x = 230 + i * 370
        parts.append(c.toy("stand", root=(x, 560), team=t, scale=0.9, outline=TEAM.get(oc)))
        parts.append(c.toy("stand", root=(x + 120, 690), team=t, scale=0.25, outline=TEAM.get(oc)))
        parts.append(tag(x, 620, lab, 26))
    tmp = out[:-4] + "_rgb.png"
    c.render_add(parts, [], W, H, tmp, bg=BG)
    # add a greyscale strip of the same image to show lightness separation
    from PIL import Image, ImageOps
    im = Image.open(tmp).convert("RGB")
    grey = ImageOps.grayscale(im.crop((0, 160, W, 720))).convert("RGB")
    sheet = Image.new("RGB", (W, H + 560), BG)
    sheet.paste(im, (0, 0))
    sheet.paste(grey, (0, H))
    sheet.save(out)
    os.remove(tmp)


# ---------------------------------------------------------------- weapons

def weapons_sheet(out):
    W, H = 2400, 1500
    parts = [title(60, 90, "Launch weapons as toy props",
                   "Separate from the toy. Red: grip (trigger hand). Green: support hand. Yellow: muzzle.")]
    wd = c.weapons()["weapons"]
    parts.append(panel(40, 160, 2320, 760))
    x, y, rowh = 100, 230, 0
    for name, w in wd.items():
        sw, sh = w["size"]
        sc = 1.6
        if x + sw * sc > 2320:
            x, y, rowh = 100, y + rowh + 70, 0
        path = os.path.join(c.WEAPONS, w["file"])
        parts.append(c.place(path, x, y, scale=sc, topleft=True))
        for k, col in (("grip", "#ff2d55"), ("support", "#2dff6a"), ("muzzle", "#ffe12d")):
            if k in w:
                parts.append(dot(x + w[k][0] * sc, y + w[k][1] * sc, col))
        parts.append(tag(x + sw * sc / 2, y + sh * sc + 32, w["label"], 24))
        x += sw * sc + 70
        rowh = max(rowh, sh * sc + 40)
    # every weapon in the soldier's hands at game scale and 2x
    parts.append(panel(40, 960, 2320, 500))
    parts.append(tag(70, 1005, "In hand: same aim pose, every weapon, at 2x and at game scale", 24, TEXT, "start"))
    for i, name in enumerate(wd):
        if name in ("frag_grenade", "rocket"):
            continue
        x = 190 + i * 300
        pose = dict(c.poses()["aim"])
        pose["weapon"] = name
        if wd[name]["hands"] == 1:
            pose["grip_at"] = [80, -190]
        parts.append(c.toy(pose, root=(x, 1340), team="blue", scale=0.5, outline=TEAM["blue"]))
        parts.append(c.toy(pose, root=(x + 30, 1430), team="orange", scale=0.25, outline=TEAM["orange"]))
        parts.append(tag(x + 20, 1100, wd[name]["label"], 20, DIM))
    c.render_add(parts, [], W, H, out, bg=BG)


# ---------------------------------------------------------------- kit

def kit_sheet(out, collision=False):
    W, H = 2400, 1500
    k = frame.kit
    sub = ("Solid shapes red, platforms cyan. Polygons in kit.json." if collision else
           "Playable props: saturated, shaded, inked like the toys. Backdrop: pale, soft, no ink. Scale x0.18.")
    parts = [title(60, 90, "Bedroom kit" + (": collision" if collision else ""), sub)]
    parts.append(c.raw(f'<rect x="40" y="160" width="{W - 80}" height="{H - 200}" rx="18" fill="#d9e4ea"/>'))
    s = 0.18
    layout = [("bed", 80, 260), ("bookshelf", 900, 200), ("desk", 1260, 330), ("toy_chest", 80, 760),
              ("wall_shelf", 460, 760), ("ceiling_fan", 830, 820), ("book_stack", 520, 1130),
              ("block_star", 700, 1150), ("block_moon", 750, 1150), ("block_heart", 725, 1112),
              ("floor", 80, 1340), ("skirting", 400, 1350), ("window", 1600, 800), ("poster", 2050, 840),
              ("wall_tile", 2050, 260)]
    labels = {"block_star": None, "block_moon": None, "block_heart": "blocks"}
    for name, x, y in layout:
        e = k(name)
        path = os.path.join(frame.KIT, e["file"])
        parts.append(c.place(path, x, y, scale=s, topleft=True))
        if collision:
            for sh in e["collision"]:
                pts = " ".join(f"{x + px * s:.1f},{y + py * s:.1f}" for px, py in sh["poly"])
                col = "#ff2d55" if sh["type"] == "solid" else "#00b8ff"
                parts.append(c.raw(f'<polygon points="{pts}" fill="{col}" fill-opacity="0.22" stroke="{col}" '
                                   f'stroke-width="2"/>'))
        lab = labels.get(name, name.replace("_", " "))
        if lab:
            parts.append(tag(x + e["size"][0] * s / 2, y + e["size"][1] * s + 30, lab, 22, "#3a4652"))
    # a toy for scale
    parts.append(c.toy("stand", root=(1020, 1420), team="blue", scale=s, outline=TEAM["blue"]))
    parts.append(tag(1020, 1460, "toy, same scale", 20, "#3a4652"))
    c.render_add(parts, [], W, H, out, bg=BG)


# ---------------------------------------------------------------- effects

def fx_sheet(out):
    W, H = 2400, 1820
    F = os.path.join(c.ASSETS, "fx")
    fx = lambda n: os.path.join(F, f"{n}.svg")  # noqa: E731
    parts = [title(60, 90, "Effects",
                   "Hot shapes drawn normally, glow layers added on top (additive), so they keep colour on a "
                   "pale map and glow on a dark one.")]
    glow = []
    for row, (bg, lab) in enumerate((("#0b0b0e", "on black"), ("#d9e4ea", "on the bedroom wall"))):
        y0 = 170 + row * 520
        parts.append(c.raw(f'<rect x="40" y="{y0}" width="{W - 80}" height="480" rx="18" fill="{bg}"/>'))
        tc = TEXT if row == 0 else "#3a4652"
        parts.append(tag(70, y0 + 44, lab, 24, tc, "start"))
        cy = y0 + 250
        items = [("muzzle_flash", 150, cy, 2.0, 0), ("muzzle_flash_b", 430, cy, 2.0, 0)]
        for n, x, y, sc, rot in items:
            parts.append(c.place(fx(n), x, y, scale=sc, rot=rot))
            glow.append(c.place(fx("muzzle_flash_glow"), x, y, scale=sc, rot=rot))
        for i, n in enumerate(("thrust_flame", "thrust_flame_b")):
            x = 760 + i * 150
            parts.append(c.place(fx(n), x, y0 + 80, scale=1.5))
            glow.append(c.place(fx("thrust_glow"), x, y0 + 80, scale=1.5))
        parts.append(c.place(fx("smoke_ring"), 1150, cy + 120, scale=1.4))
        glow.append(c.place(fx("tracer"), 1500, cy - 60, scale=1.6))
        glow.append(c.place(fx("tracer"), 1500, cy - 60, scale=1.6))
        glow.append(c.place(fx("tracer"), 1440, cy + 10, scale=1.6))
        glow.append(c.place(fx("tracer"), 1440, cy + 10, scale=1.6))
        glow.append(c.place(fx("frag_blast_glow"), 1900, cy, scale=0.9))
        parts.append(c.place(fx("blast_smoke"), 1760, cy - 40, scale=1.1))
        parts.append(c.place(fx("frag_blast"), 1900, cy, scale=0.9))
        parts.append(c.place(fx("smoke_puff"), 2200, cy - 100, scale=1.2))
        if row == 0:
            for x, n in ((150, "muzzle flash a"), (430, "muzzle flash b"), (835, "thrust, 2 frames"),
                         (1150, "smoke ring"), (1470, "tracers"), (1900, "frag blast"), (2200, "smoke")):
                parts.append(tag(x, y0 + 460, n, 22, DIM))
    # the pop, three steps
    y0 = 1210
    parts.append(panel(40, y0, W - 80, 570))
    parts.append(tag(70, y0 + 44, "The soldier's pop: hit, snap at the joints, POP! (parts are the rig's own)",
                     24, TEXT, "start"))
    rng = random.Random(3)
    for i, (spread, word, face) in enumerate(((0.0, False, "face_hurt.svg"), (0.35, False, "face_shocked.svg"),
                                              (1.0, True, "face_shocked.svg"))):
        cx = 420 + i * 760
        p, burst = frame.pop_scene(cx, y0 + 300, "orange", rng, spread=spread, word=word, face=face)
        k, py = 0.62, y0 + 330
        parts.append(c.raw(f'<g transform="translate({cx} {py}) scale({k}) translate({-cx} {-py})">'))
        parts.append(c.join([p, burst]))
        parts.append(c.raw("</g>"))
        parts.append(tag(cx, y0 + 545, ("hit", "snap", "POP!")[i], 24, DIM))
    c.render_add(parts, glow, W, H, out, bg=BG)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(c.ROOT, "art", "previews")
    os.makedirs(out, exist_ok=True)
    for fn, name in ((cast_sheet, "cast_sheet.png"), (team_sheet, "team_sheet.png"),
                     (weapons_sheet, "weapons_sheet.png"), (kit_sheet, "kit_sheet.png"),
                     (lambda p: kit_sheet(p, collision=True), "kit_collision.png"), (fx_sheet, "fx_sheet.png")):
        print(fn(os.path.join(out, name)) or os.path.join(out, name))


if __name__ == "__main__":
    main()
