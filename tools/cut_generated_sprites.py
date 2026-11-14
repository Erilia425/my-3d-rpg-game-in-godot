"""Turn generated magenta-screen character art into transparent pixel sprites.

The image generator renders each character on a flat magenta field. This script
keys that field out, removes the magenta fringe from antialiased edges, crops to
the character, and downsamples to a pixel-art-sized texture for the 3D
billboards. Run with the project's Python (Pillow installed).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

KEY = (250, 3, 250)
# Pixels closer than INNER to the key are fully transparent; between INNER and
# OUTER they fade. This keeps soft antialiased outlines without a pink halo.
INNER = 55.0
OUTER = 120.0


def cut(path: Path, out: Path, target_height: int | None = None,
        target_width: int | None = None) -> None:
    image = Image.open(path).convert("RGB")
    pixels = image.load()
    width, height = image.size

    alpha_image = Image.new("L", (width, height), 0)
    alpha_pixels = alpha_image.load()

    kr, kg, kb = KEY
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            distance = ((r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2) ** 0.5
            if distance <= INNER:
                alpha_pixels[x, y] = 0
            elif distance >= OUTER:
                alpha_pixels[x, y] = 255
            else:
                alpha_pixels[x, y] = int(255 * (distance - INNER) / (OUTER - INNER))

    # Un-premultiply the magenta that antialiasing mixed into the edge pixels.
    rgba = Image.new("RGBA", (width, height))
    out_pixels = rgba.load()
    for y in range(height):
        for x in range(width):
            a = alpha_pixels[x, y]
            if a == 0:
                out_pixels[x, y] = (0, 0, 0, 0)
                continue
            r, g, b = pixels[x, y]
            if a < 255:
                f = a / 255.0
                r = int(max(0, min(255, (r - kr * (1 - f)) / f)))
                g = int(max(0, min(255, (g - kg * (1 - f)) / f)))
                b = int(max(0, min(255, (b - kb * (1 - f)) / f)))
            out_pixels[x, y] = (r, g, b, a)

    # A second, hue-based pass removes the last magenta threads the distance
    # key keeps around soft outlines (magenta is bright red and blue with a
    # near-zero green channel; real pink cloth keeps a high green).
    out_pixels = rgba.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = out_pixels[x, y]
            if a and g < 115 and r > 140 and b > 140 and abs(r - b) < 70:
                out_pixels[x, y] = (r, g, b, 0)

    bbox = rgba.getbbox()
    if bbox is None:
        raise SystemExit(f"nothing left after keying {path}")
    rgba = rgba.crop(bbox)

    if target_height is not None:
        scale = target_height / rgba.height
        size = (max(1, round(rgba.width * scale)), target_height)
    elif target_width is not None:
        scale = target_width / rgba.width
        size = (target_width, max(1, round(rgba.height * scale)))
    else:
        size = rgba.size

    # Resize premultiplied so the transparent edges do not darken.
    premultiplied = rgba.copy()
    pp = premultiplied.load()
    for y in range(premultiplied.height):
        for x in range(premultiplied.width):
            r, g, b, a = pp[x, y]
            pp[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
    premultiplied = premultiplied.resize(size, Image.LANCZOS)
    pp = premultiplied.load()
    for y in range(size[1]):
        for x in range(size[0]):
            r, g, b, a = pp[x, y]
            if a:
                pp[x, y] = (min(255, r * 255 // a), min(255, g * 255 // a),
                            min(255, b * 255 // a), a)

    out.parent.mkdir(parents=True, exist_ok=True)
    premultiplied.save(out)
    print(f"{out.name}: {size[0]}x{size[1]} from {image.size[0]}x{image.size[1]}")


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: cut_generated_sprites.py <in.png> <out.png> "
                         "[--height N | --width N]")
    path_in = Path(sys.argv[1])
    path_out = Path(sys.argv[2])
    target_height = None
    target_width = None
    args = sys.argv[3:]
    if "--height" in args:
        target_height = int(args[args.index("--height") + 1])
    if "--width" in args:
        target_width = int(args[args.index("--width") + 1])
    cut(path_in, path_out, target_height, target_width)


if __name__ == "__main__":
    main()
