"""Mock battle frame at 1280x720, composed from the kit at game scale.

Run: python3 art/tools/frame.py [out.png]   (default art/previews/battle_frame.png)

Everything here is the real assets placed by their json data. The scene is built in author
px (5120 x 2880, 4 per game px) and rendered at 1280 x 720. Glow layers are rendered in a
second pass and added to the first the way the engine's additive blend does it. The team
outline uses an SVG dilate filter here; in the game it is a shader on the composed toy.
"""

import json
import math
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose as c  # noqa: E402

KIT = os.path.join(c.ASSETS, "maps", "bedroom")
FX = os.path.join(c.ASSETS, "fx")
W, H = 5120, 2880
FLOOR_Y = 2700
TEAM = {"blue": "#2f7de1", "orange": "#ff8c1a"}


def kit(name):
    return json.loads(c.load(os.path.join(KIT, "kit.json")))["pieces"][name]


def prop(name, x, y, scale=1.0, opacity=None, wall_shadow=True):
    """Place a kit piece with its origin at (x, y), with its shadow cast on the wall behind.

    The shadow is the same file flattened dark and offset: a sprite copy with a black
    modulate in the engine, no blur needed.
    """
    k = kit(name)
    path = os.path.join(KIT, k["file"])
    out = ""
    if wall_shadow and k["kind"] == "prop":
        out = c.place_flat(path, x + 70, y - 10, "#2b3442", 0.16, anchor=k["origin"], topleft=True)
    return out + c.place(path, x, y, scale=scale, anchor=k["origin"], topleft=True, opacity=opacity)


def fxp(name, x, y, scale=1.0, rot=0.0, flip=False, opacity=None):
    return c.place(os.path.join(FX, f"{name}.svg"), x, y, scale=scale, rot=rot, flip=flip, opacity=opacity)


def fxm(name, m, opacity=None):
    return c.place_m(os.path.join(FX, f"{name}.svg"), m, opacity=opacity)


def shadow(x, y, w=150, h=26, op=0.45):
    gid = f"sh{x}{y}"
    return (f'<defs><radialGradient id="{gid}" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#1a1008" '
            f'stop-opacity="{op}"/><stop offset="1" stop-color="#1a1008" stop-opacity="0"/></radialGradient></defs>'
            f'<ellipse cx="{x}" cy="{y}" rx="{w}" ry="{h}" fill="url(#{gid})"/>')


def backdrop():
    out = []
    for tx in range(0, W, 1024):
        for ty in range(-200, FLOOR_Y, 1024):
            out.append(prop("wall_tile", tx, ty))
    out.append(prop("window", 1900, 240))
    # moonlight falling in from the window, added light on the backdrop
    out.append('<defs><linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#eef4ff" '
               'stop-opacity="0.35"/><stop offset="1" stop-color="#eef4ff" stop-opacity="0"/></linearGradient></defs>'
               '<path d="M2000 380L3600 380L4600 2700L2700 2700Z" fill="url(#beam)"/>')
    out.append(prop("poster", 4200, 260))
    for tx in range(0, W, 1024):
        out.append(prop("skirting", tx, FLOOR_Y - 88))
    # a soft wash of lamp light over the wall, part of the backdrop
    out.append('<defs><radialGradient id="wash" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#fff6e0" '
               'stop-opacity="0.45"/><stop offset="1" stop-color="#fff6e0" stop-opacity="0"/></radialGradient></defs>'
               f'<ellipse cx="2600" cy="1200" rx="2600" ry="1500" fill="url(#wash)"/>')
    return "".join(out)


def pop_scene(cx, cy, team, rng):
    """The soldier's pop: parts snapped off at the joints and flying, helmet spinning off,
    a battery flung clear, snap marks, a burst and the POP! word."""
    r = c.rig()
    parts = {p["name"]: p for p in r["parts"]}
    path = lambda f_: os.path.join(c.SOLDIER, f_)  # noqa: E731
    # (part, dx, dy, rot)
    layout = [
        ("far_thigh", 90, 120, 55), ("far_shin", 190, 170, 100), ("far_upper_arm", 150, -100, -60),
        ("far_forearm", 230, -30, -120), ("near_thigh", -110, 130, -35), ("near_shin", -220, 180, -85),
        ("torso", 0, 30, -18), ("near_upper_arm", -170, -50, 80), ("near_forearm", -250, 10, 140),
    ]
    out = []
    for name, dx, dy, rot in layout:
        p = parts[name]
        m = c.mul(c.T(cx + dx, cy + dy), c.R(rot))
        out.append(f'<g transform="{c.svgm(m)}">{c.body(path(p["file"]))}</g>')
        if parts[name].get("modulate"):
            out.append(f'<g transform="{c.svgm(m)}" opacity="0.35">{c._silhouette(path(p["file"]), "#0d1a08")}</g>')
    # head with its hurt face, popped up and back
    hm = c.mul(c.T(cx - 20, cy - 190), c.R(-24))
    out.append(f'<g transform="{c.svgm(hm)}">{c.body(path("head.svg"))}{c.body(path("face_shocked.svg"))}</g>')
    # helmet flying off, spinning
    out.append(f'<g transform="{c.svgm(c.mul(c.T(cx + 120, cy - 380), c.R(38)))}">{c.body(path("helmet.svg"))}</g>')
    # a battery flung clear: the jetpack's three layers
    jm = c.mul(c.T(cx - 260, cy - 220), c.mul(c.R(-58), c.S(0.9)))
    for f_ in ("jetpack_back.svg", r["team"]["baked"][team], "jetpack_front.svg"):
        out.append(f'<g transform="{c.svgm(jm)}">{c.body(path(f_))}</g>')
    snaps = [(cx + 60, cy + 100), (cx - 90, cy + 110), (cx - 20, cy - 110)]
    for x, y in snaps:
        out.append(fxp("pop_snap", x, y, scale=0.9 + rng.random() * 0.4, rot=rng.random() * 90))
    burst = (fxp("pop_burst", cx + 300, cy - 360, scale=1.15, rot=-8)
             + fxp("pop_text", cx + 300, cy - 360, scale=1.15, rot=-8))
    return "".join(out), burst


def scene():
    rng = random.Random(5)
    base, glow, top = [], [], []
    base.append(backdrop())

    # props
    base.append(prop("bookshelf", -1380, FLOOR_Y))
    base.append(prop("wall_shelf", 560, 1060))
    base.append(prop("toy_chest", 3050, FLOOR_Y))
    base.append(prop("bed", 4660, FLOOR_Y))
    base.append(prop("book_stack", 1180, FLOOR_Y))
    base.append(prop("block_star", 560, FLOOR_Y))
    base.append(prop("block_moon", 790, FLOOR_Y))
    base.append(prop("block_heart", 680, FLOOR_Y - 210))
    for tx in range(0, W, 1536):
        base.append(prop("floor", tx, FLOOR_Y))

    # the orange toy on the chest lid, firing up at the flyer
    chest_top = FLOOR_Y - 1200 - 30
    info_o = {}
    o_pose = dict(c.poses()["aim"])
    o_pose.update({"aim": -22, "grip_at": [62, -168], "face": "determined"})
    ox = 3620
    base.append(shadow(ox, chest_top + 6, 160, 24))
    base.append(c.toy(o_pose, root=(ox, chest_top), facing=-1, team="orange", outline=TEAM["orange"], info=info_o))

    # the blue flyer, thrusting, firing down at the chest
    info_b = {}
    b_pose = dict(c.poses()["fly"])
    b_pose.update({"aim": 18, "grip_at": [60, -160], "face": "cocky", "lean": 10})
    bx, by = 2200, 1180
    base.append(c.toy(b_pose, root=(bx, by), facing=1, team="blue", outline=TEAM["blue"], info=info_b))
    for m in info_b["nozzles"]:
        glow.append(fxm("thrust_glow", m))
    base.append(fxp("smoke_ring", bx - 150, by + 600, scale=1.25, opacity=0.8))
    base.append(fxp("smoke_puff", bx - 300, by + 900, scale=0.9, opacity=0.5))

    # muzzle flashes and tracers between them
    for info, flash in ((info_b, "muzzle_flash"), (info_o, "muzzle_flash_b")):
        m = info["muzzle"]
        top.append(fxm(flash, m))
        glow.append(fxm("muzzle_flash_glow", m))

    def tracer_line(info, n, d0, gap):
        m = info["muzzle"]
        for i in range(n):
            mm = c.mul(m, c.T(d0 + i * gap, (i % 2) * 14 - 7))
            glow.append(fxm("tracer", mm))
            glow.append(fxm("tracer", mm))
    tracer_line(info_b, 3, 360, 300)
    tracer_line(info_o, 2, 380, 340)

    # frag blast on the floor, popping a second orange toy
    gx, gy = 2150, FLOOR_Y - 260
    glow.append(fxp("frag_blast_glow", gx, gy, scale=1.5))
    top.append(fxp("blast_smoke", gx - 330, gy - 80, scale=1.2, opacity=0.9))
    top.append(fxp("blast_smoke", gx + 320, gy - 30, scale=1.0, opacity=0.85))
    top.append(fxp("frag_blast", gx, gy, scale=1.4, rot=8))
    pop_parts, pop_burst = pop_scene(gx - 40, gy - 420, "orange", rng)
    top.append(pop_parts)
    top.append(pop_burst)
    return "".join(base) + "".join(top), "".join(glow)


def render(out_png):
    from PIL import Image, ImageChops
    body, glow = scene()
    tmp = out_png[:-4]
    c.render(c.doc(W, H, body, bg="#d9e4ea"), tmp + "_base.png", width=1280, height=720)
    c.render(c.doc(W, H, glow), tmp + "_glow.png", width=1280, height=720)
    base = Image.open(tmp + "_base.png").convert("RGB")
    g = Image.open(tmp + "_glow.png").convert("RGBA")
    # additive blend: dst + src.rgb * src.a, as the engine's BLEND_MODE_ADD
    r, gg, b, a = g.split()
    prem = Image.merge("RGB", [ImageChops.multiply(ch, a) for ch in (r, gg, b)])
    out = ImageChops.add(base, prem)
    out.save(out_png)
    for suffix in ("_base.png", "_glow.png", "_base.svg", "_glow.svg"):
        try:
            os.remove(tmp + suffix)
        except OSError:
            pass
    return out_png


if __name__ == "__main__":
    dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(c.ROOT, "art", "previews", "battle_frame.png")
    print(render(dst))
