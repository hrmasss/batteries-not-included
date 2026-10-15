"""Check every asset: SVG features Godot's importer supports, json metadata, and a pixel
comparison of Godot's own rasterizer (ThorVG) against librsvg.

Run: python3 art/tools/check.py [--godot PATH] [--out DIR]
Exits non-zero on any failure. Needs rsvg-convert; the Godot comparison is skipped with a
warning when no Godot binary is found.
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ASSETS = os.path.join(ROOT, "assets")
NS = "{http://www.w3.org/2000/svg}"

ALLOWED = {"svg", "defs", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon",
           "linearGradient", "radialGradient", "stop", "clipPath", "use"}
BANNED_ATTRS = {"filter", "mask", "mix-blend-mode", "style", "font-family"}
GODOT_DEFAULT = os.path.expanduser("~/tools/godot/Godot_v4.7.2-stable_linux.x86_64")

failures = []


def fail(msg):
    failures.append(msg)
    print("FAIL", msg)


def svg_files():
    return sorted(glob.glob(os.path.join(ASSETS, "**", "*.svg"), recursive=True))


def check_svg(path):
    rel = os.path.relpath(path, ROOT)
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        fail(f"{rel}: not valid XML ({e})")
        return None
    for el in root.iter():
        tag = el.tag.replace(NS, "")
        if tag not in ALLOWED:
            fail(f"{rel}: <{tag}> is not in the Godot-safe set")
        for a in el.attrib:
            if a in BANNED_ATTRS:
                fail(f"{rel}: attribute {a} is not Godot-safe")
    w, h = float(root.get("width")), float(root.get("height"))
    vb = [float(v) for v in root.get("viewBox").split()]
    if abs(vb[2] - w) > 0.01 or abs(vb[3] - h) > 0.01:
        fail(f"{rel}: size {w}x{h} differs from viewBox {vb[2]}x{vb[3]}")
    return w, h


def inside(pt, size, slack=2.0, name=""):
    x, y = pt
    if not (-slack <= x <= size[0] + slack and -slack <= y <= size[1] + slack):
        fail(f"{name}: point {pt} is outside the file ({size[0]}x{size[1]})")


def check_json():
    sizes = {}
    for p in svg_files():
        root = ET.parse(p).getroot()
        sizes[p] = (float(root.get("width")), float(root.get("height")))
    # rig
    sd = os.path.join(ASSETS, "toys", "soldier")
    rig = json.load(open(os.path.join(sd, "rig.json")))
    names = {p["name"] for p in rig["parts"]} | {"root"}
    zs = [p["z"] for p in rig["parts"]]
    if len(zs) != len(set(zs)):
        fail("rig.json: draw orders repeat")
    for p in rig["parts"]:
        f = os.path.join(sd, p["file"])
        if f not in sizes:
            fail(f"rig.json: {p['name']} file {p['file']} missing")
            continue
        if p["parent"] not in names:
            fail(f"rig.json: {p['name']} parent {p['parent']} unknown")
        inside(p["pivot"], sizes[f], name=f"rig.json {p['name']} pivot")
    for k, f in list(rig["faces"].items()) + list(rig["team"]["baked"].items()) + list(rig["team"].get("pattern_files", {}).items()):
        if os.path.join(sd, f) not in sizes:
            fail(f"rig.json: {k} file {f} missing")
    poses = json.load(open(os.path.join(sd, "poses.json")))
    weapons = json.load(open(os.path.join(ASSETS, "weapons", "weapons.json")))["weapons"]
    for pn, pose in poses.items():
        if pn.startswith("_"):
            continue
        for part in pose.get("rot", {}):
            if part not in names:
                fail(f"poses.json {pn}: unknown part {part}")
        if pose.get("weapon") and pose["weapon"] not in weapons:
            fail(f"poses.json {pn}: unknown weapon {pose['weapon']}")
    # weapons
    for wn, w in weapons.items():
        f = os.path.join(ASSETS, "weapons", w["file"])
        if f not in sizes:
            fail(f"weapons.json: {wn} file missing")
            continue
        for k in ("grip", "muzzle", "support"):
            if k in w:
                inside(w[k], sizes[f], name=f"weapons.json {wn} {k}")
    # fx
    fx = json.load(open(os.path.join(ASSETS, "fx", "fx.json")))["fx"]
    for n, e in fx.items():
        f = os.path.join(ASSETS, "fx", e["file"])
        if f not in sizes:
            fail(f"fx.json: {n} file missing")
            continue
        inside(e["origin"], sizes[f], name=f"fx.json {n} origin")
    # kit
    kit = json.load(open(os.path.join(ASSETS, "maps", "bedroom", "kit.json")))["pieces"]
    for n, e in kit.items():
        f = os.path.join(ASSETS, "maps", "bedroom", e["file"])
        if f not in sizes:
            fail(f"kit.json: {n} file missing")
            continue
        inside(e["origin"], sizes[f], name=f"kit.json {n} origin")
        for i, c in enumerate(e["collision"]):
            if c["type"] not in ("solid", "platform"):
                fail(f"kit.json {n}: shape {i} type {c['type']}")
            if len(c["poly"]) < 3:
                fail(f"kit.json {n}: shape {i} has under 3 points")
            for pt in c["poly"]:
                inside(pt, sizes[f], slack=40, name=f"kit.json {n} shape {i}")
    # pickups
    pk_path = os.path.join(ASSETS, "pickups", "pickups.json")
    pickups = json.load(open(pk_path))["pickups"] if os.path.exists(pk_path) else {}
    for n, e in pickups.items():
        f = os.path.join(ASSETS, "pickups", e["file"])
        if f not in sizes:
            fail(f"pickups.json: {n} file missing")
            continue
        inside(e["origin"], sizes[f], name=f"pickups.json {n} origin")
    # every svg is referenced by some json
    referenced = set()
    for p in rig["parts"]:
        referenced.add(os.path.join(sd, p["file"]))
    for f in list(rig["faces"].values()) + list(rig["team"]["baked"].values()) + list(rig["team"].get("pattern_files", {}).values()):
        referenced.add(os.path.join(sd, f))
    for w in weapons.values():
        referenced.add(os.path.join(ASSETS, "weapons", w["file"]))
    for e in fx.values():
        referenced.add(os.path.join(ASSETS, "fx", e["file"]))
    for e in kit.values():
        referenced.add(os.path.join(ASSETS, "maps", "bedroom", e["file"]))
    for e in pickups.values():
        referenced.add(os.path.join(ASSETS, "pickups", e["file"]))
    for p in sizes:
        if p not in referenced:
            fail(f"{os.path.relpath(p, ROOT)}: not listed in any json")
    return len(sizes)


GD = """extends SceneTree
# Rasterize SVGs with Godot's own importer code (ThorVG). Args: scale out_dir in1 in2 ...
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scale := float(a[0])
	var out := a[1]
	for i in range(2, a.size()):
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(a[i]), scale)
		if err != OK:
			printerr("FAIL ", a[i], " ", err)
			continue
		img.save_png(out.path_join(a[i].get_file().get_basename() + ".png"))
		print("OK ", a[i])
	quit()
"""


def godot_compare(godot, out_dir, scale):
    from PIL import Image, ImageChops
    files = svg_files()
    work = tempfile.mkdtemp(prefix="bni-godot-svg-")
    try:
        with open(os.path.join(work, "project.godot"), "w") as fh:
            fh.write('config_version=5\n[application]\nconfig/name="svgcheck"\n')
        with open(os.path.join(work, "rast.gd"), "w") as fh:
            fh.write(GD)
        gdir = os.path.join(out_dir, f"godot_x{scale}")
        rdir = os.path.join(out_dir, f"rsvg_x{scale}")
        os.makedirs(gdir, exist_ok=True)
        os.makedirs(rdir, exist_ok=True)
        # file names must be unique for the flat output folders
        stems = [os.path.basename(f) for f in files]
        if len(stems) != len(set(stems)):
            fail("svg file names repeat across folders; the comparison needs unique names")
        r = subprocess.run([godot, "--headless", "--path", work, "-s", "rast.gd", "--", str(scale), gdir] + files,
                           capture_output=True, text=True, timeout=600)
        for line in r.stderr.splitlines():
            if line.startswith("FAIL"):
                fail(f"godot: {line}")
        rows = []
        for f in files:
            stem = os.path.splitext(os.path.basename(f))[0]
            g = os.path.join(gdir, stem + ".png")
            rr = os.path.join(rdir, stem + ".png")
            subprocess.run(["rsvg-convert", "-z", str(scale), f, "-o", rr], check=True, timeout=120)
            if not os.path.exists(g):
                fail(f"godot: no raster for {stem}")
                continue
            a = Image.open(g).convert("RGBA")
            b = Image.open(rr).convert("RGBA")
            if a.size != b.size:
                b = b.resize(a.size)
            d = ImageChops.difference(a, b)
            px = a.size[0] * a.size[1]
            hist = d.convert("L").histogram()
            mean = sum(i * n for i, n in enumerate(hist)) / px
            big = sum(hist[48:]) / px * 100
            rows.append((os.path.relpath(f, ASSETS), a.size, mean, big))
            if mean > 4 or big > 3:
                fail(f"godot vs rsvg differ on {stem}: mean {mean:.2f}, {big:.2f}% px off by >48")
        return rows
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", default=os.environ.get("GODOT", GODOT_DEFAULT))
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "bni-art-check"))
    ap.add_argument("--scale", type=float, default=0.5)
    args = ap.parse_args()
    files = svg_files()
    for p in files:
        check_svg(p)
    print(f"svg features: {len(files)} files checked")
    n = check_json()
    print(f"json metadata: {n} files cross-checked")
    if os.path.exists(args.godot):
        rows = godot_compare(args.godot, args.out, args.scale)
        print(f"godot vs librsvg at scale {args.scale} (mean abs diff 0-255, % pixels off by more than 48):")
        for rel, size, mean, big in rows:
            print(f"  {rel:42s} {size[0]:5d}x{size[1]:<5d} mean {mean:5.2f}  off {big:5.2f}%")
    else:
        print(f"WARN no Godot at {args.godot}; skipped the rasterizer comparison")
    if failures:
        print(f"{len(failures)} failures")
        sys.exit(1)
    print("all checks passed")


if __name__ == "__main__":
    main()
