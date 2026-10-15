"""Compose rigged toys, weapons and props into SVG scenes for previews.

This is a preview tool, not game code: it reads the same rig.json, poses.json and
weapons.json the game will read, and places the parts the way a cutout rig would.
"""

from __future__ import annotations

import json
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "art", "lib"))
from bni_svg import f, inner, viewbox  # noqa: E402

ASSETS = os.path.join(ROOT, "assets")
SOLDIER = os.path.join(ASSETS, "toys", "soldier")
WEAPONS = os.path.join(ASSETS, "weapons")

_cache: dict = {}
_count = [0]


def load(path):
    if path not in _cache:
        with open(path) as fh:
            _cache[path] = fh.read()
    return _cache[path]


def body(path):
    """The file's drawing, ids made unique for this instance."""
    _count[0] += 1
    return inner(load(path), f"u{_count[0]}_")


# ---------------------------------------------------------------- 2D affine

def mat(a=1, b=0, c=0, d=1, e=0, f_=0):
    return (a, b, c, d, e, f_)


def mul(m, n):
    a, b, c, d, e, f_ = m
    A, B, C, D, E, F = n
    return (a * A + c * B, b * A + d * B, a * C + c * D, b * C + d * D, a * E + c * F + e, b * E + d * F + f_)


def T(x, y):
    return mat(e=x, f_=y)


def R(deg):
    r = math.radians(deg)
    return mat(math.cos(r), math.sin(r), -math.sin(r), math.cos(r))


def S(sx, sy=None):
    return mat(sx, 0, 0, sy if sy is not None else sx)


def apply(m, p):
    a, b, c, d, e, f_ = m
    return (a * p[0] + c * p[1] + e, b * p[0] + d * p[1] + f_)


def inv(m):
    a, b, c, d, e, f_ = m
    det = a * d - b * c
    ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
    return (ia, ib, ic, id_, -(ia * e + ic * f_), -(ib * e + id_ * f_))


def svgm(m):
    return "matrix(" + " ".join(f(v) for v in m) + ")"


# ---------------------------------------------------------------- scene records
# Every placement returns a Rec: the SVG text, plus records of what was placed where, so the
# same scene can be rebuilt in Godot from the assets (art/tools/godot_frame.gd).

class Rec(str):
    def __new__(cls, s, recs=()):
        o = super().__new__(cls, s)
        o.recs = list(recs)
        return o


def join(parts):
    parts = list(parts)
    return Rec("".join(parts), [r for p in parts for r in getattr(p, "recs", [])])


def raw(svg):
    """Free SVG (shadows, light washes) in scene coordinates."""
    return Rec(svg, [{"kind": "raw", "svg": svg}])


def _rel(path):
    return os.path.relpath(path, ROOT)


def records(parts, blend="normal"):
    out = []
    for p in parts:
        for r in getattr(p, "recs", []):
            r = dict(r)
            r["blend"] = blend
            out.append(r)
    return out


# ---------------------------------------------------------------- rig

def rig():
    return json.loads(load(os.path.join(SOLDIER, "rig.json")))


def poses():
    return json.loads(load(os.path.join(SOLDIER, "poses.json")))


def weapons():
    p = os.path.join(WEAPONS, "weapons.json")
    return json.loads(load(p)) if os.path.exists(p) else {"weapons": {}}


def two_bone(shoulder, target, l1, l2, bend=1):
    """Angles (upper, fore) in degrees for a limb hanging along +y at rest, to reach target.

    Both are rotations about the pivot as the rig applies them: the upper arm's in its parent
    frame, the forearm's relative to the upper arm. bend picks which way the elbow folds.
    """
    dx, dy = target[0] - shoulder[0], target[1] - shoulder[1]
    dist = max(1e-3, min(math.hypot(dx, dy), l1 + l2 - 0.01, ))
    dist = max(dist, abs(l1 - l2) + 0.01)
    a = math.atan2(dy, dx)
    alpha = math.acos(max(-1, min(1, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist))))
    beta = math.acos(max(-1, min(1, (l1 * l1 + l2 * l2 - dist * dist) / (2 * l1 * l2))))
    up = a + bend * alpha
    upper = math.degrees(up) - 90
    fore = -bend * (180 - math.degrees(beta))
    return upper, fore


def pose_mats(r, pose, root=(0, 0), facing=1, scale=1.0):
    """World matrix per part name for a pose."""
    parts = {p["name"]: p for p in r["parts"]}
    rots = dict(pose.get("rot", {}))
    off = pose.get("offset", [0, 0])
    m_base = mul(T(*root), mul(S(scale * facing, scale), T(*off)))
    m_root = mul(m_base, R(pose.get("lean", 0)))
    mats = {"root": m_root}

    def solve(name):
        if name in mats:
            return mats[name]
        p = parts[name]
        m = mul(solve(p["parent"]), mul(T(*p["pos"]), R(rots.get(name, p.get("rot", 0)))))
        mats[name] = m
        return m

    # arm IK toward weapon grip and support points, solved in the torso frame
    wpn = pose.get("weapon")
    wdata = weapons()["weapons"].get(wpn) if wpn else None
    if wdata and "grip_at" in pose:
        m_torso = solve("torso")
        aim = pose.get("aim", 0)
        m_w = mul(m_base, mul(T(*pose["grip_at"]), R(aim)))
        mats["weapon"] = m_w
        gx, gy = wdata["grip"]
        tgt = {"near": apply(m_w, (0, 0))}
        if wdata.get("support"):
            sx, sy = wdata["support"]
            tgt["far"] = apply(m_w, (sx - gx, sy - gy))
        sock = r["sockets"]["weapon_grip"]["pos"]
        l1 = parts["near_forearm"]["pos"][1]
        l2 = math.hypot(*sock)
        corr = math.degrees(math.atan2(sock[0], sock[1]))
        for side, target in tgt.items():
            sh = parts[f"{side}_upper_arm"]["pos"]
            t_local = apply(inv(m_torso), target)
            bend = pose.get(f"{side}_bend", 1)
            u, fo = two_bone(sh, t_local, l1, l2, bend)
            rots[f"{side}_upper_arm"] = u
            rots[f"{side}_forearm"] = fo + corr
    for name in parts:
        solve(name)
    return mats


def toy(pose_name_or_dict, root=(0, 0), facing=1, team="blue", face=None, weapon=True, scale=1.0,
        outline=None, extra_under="", fx=True, info=None):
    """SVG group for a posed soldier. outline: team outline colour or None.

    info, if given, is filled with world matrices for effects: 'muzzle' (points along the
    barrel) and 'nozzles' (point down the thrust).
    """
    r = rig()
    pose = poses()[pose_name_or_dict] if isinstance(pose_name_or_dict, str) else pose_name_or_dict
    mats = pose_mats(r, pose, root, facing, scale)
    if info is not None:
        info["nozzles"] = [mul(mats[s["parent"]], T(*s["pos"])) for s in r["sockets"]["thrust"]]
    face = face or pose.get("face", "determined")
    out = []
    items = []
    for p in r["parts"]:
        file = p["file"]
        if p["name"] == "face":
            file = r["faces"][face]
        if p["name"] == "jetpack_team":
            file = r["team"]["baked"].get(team, "jetpack_team.svg")
        if p["name"] in pose.get("hide", []):
            continue
        items.append((p["z"], p["name"], file, mats[p["name"]], p.get("modulate")))
    wpn = pose.get("weapon") if weapon else None
    wd = weapons()["weapons"].get(wpn) if wpn else None
    if wd and "weapon" in mats:
        wpath = os.path.join(WEAPONS, wd["file"])
        vb = viewbox(load(wpath))
        gx, gy = wd["grip"][0] + vb[0], wd["grip"][1] + vb[1]
        items.append((14, "weapon", wpath, mul(mats["weapon"], T(-gx, -gy)), None))
        if info is not None:
            mx, my = wd["muzzle"][0] + vb[0], wd["muzzle"][1] + vb[1]
            info["muzzle"] = mul(mats["weapon"], T(mx - gx, my - gy))
    items.sort(key=lambda t: t[0])
    if fx and pose.get("thrust"):
        out.append(thrust_fx(mats, r, pose.get("thrust")))
    for z, name, file, m, mod in items:
        path = file if os.path.isabs(file) else os.path.join(SOLDIER, file)
        out.append(place_m(path, m))
        if mod:
            # far-side limbs: a dark veil over the part (a modulate in the engine)
            dim = 1 - (mod[0] + mod[1] + mod[2]) / 3
            out.append(place_flat_m(path, m, "#0d1a08", dim * 1.6))
    grp = join(out)
    if outline:
        fid = f"tout{_count[0]}"
        w = 6 * scale
        filt = (f'<filter id="{fid}" x="-20%" y="-20%" width="140%" height="140%">'
                f'<feMorphology in="SourceAlpha" operator="dilate" radius="{f(w)}" result="d"/>'
                f'<feFlood flood-color="{outline}"/><feComposite in2="d" operator="in" result="o"/>'
                f'<feMerge><feMergeNode in="o"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')
        recs = [{"kind": "group_begin", "outline": outline, "width": w}] + grp.recs + [{"kind": "group_end"}]
        return Rec(f'<defs>{filt}</defs><g filter="url(#{fid})">{extra_under}{grp}</g>', recs)
    return join([raw(extra_under) if extra_under else "", grp])


def _silhouette(path, colour):
    """The part's filled shapes recoloured flat, to darken far-side limbs."""
    import re
    g = body(path)
    g = re.sub(r'(?<![-\w])fill="(?!none)[^"]*"', f'fill="{colour}"', g)
    g = re.sub(r'(?<![-\w])stroke="[^"]*"', 'stroke="none"', g)
    g = re.sub(r'(?<![-\w])opacity="[^"]*"', "", g)
    return g


def thrust_fx(mats, r, kind):
    fxdir = os.path.join(ASSETS, "fx")
    name = "thrust_flame.svg" if kind is True or kind == "flame" else f"{kind}.svg"
    path = os.path.join(fxdir, name)
    if not os.path.exists(path):
        return ""
    out = []
    for s in r["sockets"]["thrust"]:
        out.append(place_m(path, mul(mats[s["parent"]], T(*s["pos"]))))
    return join(out)


def place_m(path, m, opacity=None):
    """Place a whole SVG file under a matrix; the drawing's own origin goes to the matrix origin."""
    op = f' opacity="{f(opacity)}"' if opacity is not None else ""
    return Rec(f'<g transform="{svgm(m)}"{op}>{body(path)}</g>',
               [{"kind": "file", "path": _rel(path), "m": list(m), "opacity": 1 if opacity is None else opacity}])


def place_flat_m(path, m, colour, opacity):
    """The file's silhouette in one flat colour under a matrix (shadows, far-side veils)."""
    return Rec(f'<g transform="{svgm(m)}" opacity="{f(opacity)}">{_silhouette(path, colour)}</g>',
               [{"kind": "flat", "path": _rel(path), "m": list(m), "colour": colour, "opacity": opacity}])


def place_flat(path, x, y, colour, opacity, anchor=(0, 0), topleft=False, scale=1.0):
    """The file's silhouette in one flat colour, for cast shadows."""
    if topleft:
        vb = viewbox(load(path))
        anchor = (anchor[0] + vb[0], anchor[1] + vb[1])
    m = mul(T(x, y), mul(S(scale), T(-anchor[0], -anchor[1])))
    return place_flat_m(path, m, colour, opacity)


def place(path, x, y, scale=1.0, rot=0.0, anchor=(0, 0), flip=False, opacity=None, topleft=False):
    """Place a whole SVG file with its point `anchor` (drawing frame) at (x, y).

    topleft: anchor is in px from the file's top-left instead, as the json files give points.
    """
    if topleft:
        vb = viewbox(load(path))
        anchor = (anchor[0] + vb[0], anchor[1] + vb[1])
    m = mul(T(x, y), mul(R(rot), mul(S(scale * (-1 if flip else 1), scale), T(-anchor[0], -anchor[1]))))
    return place_m(path, m, opacity)


def doc(w, h, content, bg=None, defs=""):
    b = f'<rect width="{f(w)}" height="{f(h)}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{f(w)}" height="{f(h)}" '
            f'viewBox="0 0 {f(w)} {f(h)}"><defs>{defs}</defs>{b}{content}</svg>\n')


def label(x, y, text, size=28, colour="#e8e6dc", anchor="middle", weight=700):
    return (f'<text x="{f(x)}" y="{f(y)}" font-family="Bricolage Grotesque, Inter, sans-serif" '
            f'font-size="{f(size)}" font-weight="{weight}" fill="{colour}" text-anchor="{anchor}">{text}</text>')


def render_add(parts, glow_parts, w, h, png, bg=None, width=None, height=None):
    """Render parts, then add glow parts on top the way the engine's additive blend does."""
    from PIL import Image, ImageChops
    tmp = png[:-4]
    render(doc(w, h, "".join(parts), bg=bg), tmp + "__base.png", width, height)
    render(doc(w, h, "".join(glow_parts)), tmp + "__glow.png", width, height)
    base = Image.open(tmp + "__base.png").convert("RGBA")
    g = Image.open(tmp + "__glow.png").convert("RGBA")
    r, gg, b, a = g.split()
    prem = Image.merge("RGB", [ImageChops.multiply(ch, a) for ch in (r, gg, b)])
    rgb = ImageChops.add(base.convert("RGB"), prem)
    alpha = ImageChops.lighter(base.split()[3], a)
    out = Image.merge("RGBA", (*rgb.split(), alpha))
    out.save(png)
    for sfx in ("__base.png", "__glow.png", "__base.svg", "__glow.svg"):
        try:
            os.remove(tmp + sfx)
        except OSError:
            pass
    return png


def render(svg_text, png, width=None, height=None):
    os.makedirs(os.path.dirname(png), exist_ok=True)
    src = png[:-4] + ".svg"
    with open(src, "w") as fh:
        fh.write(svg_text)
    cmd = ["rsvg-convert", src, "-o", png]
    if width:
        cmd[1:1] = ["-w", str(width)]
    if height:
        cmd[1:1] = ["-h", str(height)]
    subprocess.run(cmd, check=True, timeout=300)
    return png
