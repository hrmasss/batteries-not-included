"""Put the Godot render of the mock frame beside a reference image.

Run: python3 art/tools/side_by_side.py <reference.jpg> <ours.png> <out.png>
The reference stays outside this repo (it lives in the private workspace).
"""

import glob
import sys

from PIL import Image, ImageDraw, ImageFont


def font(size):
    for pat in ("~/.local/share/fonts/**/Bricolage*.ttf", "/usr/share/fonts/**/DejaVuSans-Bold.ttf"):
        import os
        hits = glob.glob(os.path.expanduser(pat), recursive=True)
        if hits:
            return ImageFont.truetype(hits[0], size)
    return ImageFont.load_default()


def main(ref_path, ours_path, out_path):
    ref = Image.open(ref_path).convert("RGB").resize((1280, 714))
    ours = Image.open(ours_path).convert("RGB")
    out = Image.new("RGB", (1280 * 2 + 60, 820), "#2b2d31")
    out.paste(ref, (20, 80))
    out.paste(ours, (1320, 80))
    d = ImageDraw.Draw(out)
    f = font(34)
    d.text((20, 22), "Reference 05: raster AI frame (the target feel)", fill="#ece8dc", font=f)
    d.text((1320, 22), "Ours: code-drawn SVG, rendered inside Godot 4.7", fill="#ece8dc", font=f)
    out.save(out_path)


if __name__ == "__main__":
    main(*sys.argv[1:4])
