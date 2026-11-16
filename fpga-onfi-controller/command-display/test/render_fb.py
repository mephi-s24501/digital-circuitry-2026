#!/usr/bin/env python3
"""Render a hex dump from the testbenches as a JPG.

Two layouts are detected from the line count:

  200 lines  framebuffer glyph dump (fb.hex).  10 pages x 20 glyphs.
             Each line is a 96-bit glyph, one bit per pixel, rows first,
             leftmost pixel in the high bit.

  1024 lines GDDRAM stream sent over I2C (i2c.hex).  Byte i is column
             i % 128 of page i // 128; bit b is the row 8 * page + b.
             A shorter stream is rendered as-is (missing bytes stay blank).

Both are rendered as a contact sheet of pages, or as one 128x64 image for
the GDDRAM stream.
"""

import argparse
import sys
import tempfile
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

GLYPH_W = 8
GLYPH_H = 12
PAGE_COLS = 10
PAGE_ROWS = 2
PAGES = 10
WORDS = PAGES * PAGE_COLS * PAGE_ROWS

GDDRAM_COLS = 128
GDDRAM_PAGES = 8
GDDRAM_BYTES = GDDRAM_COLS * GDDRAM_PAGES


def load_values(path):
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    return [int(line, 16) for line in lines]


def glyph_pixels(word):
    for row in range(GLYPH_H):
        for col in range(GLYPH_W):
            bit = row * GLYPH_W + (GLYPH_W - 1 - col)
            if (word >> bit) & 1:
                yield row, col


def render_glyphs(words, scale):
    page_w = PAGE_COLS * GLYPH_W * scale
    page_h = PAGE_ROWS * GLYPH_H * scale
    label_h = 14
    gap = 10
    margin = 10
    cols = 1
    rows = (PAGES + cols - 1) // cols

    width = margin * 2 + cols * page_w + (cols - 1) * gap
    height = margin * 2 + rows * (label_h + page_h) + (rows - 1) * gap

    image = Image.new("RGB", (width, height), "black")
    draw = ImageDraw.Draw(image)

    for page in range(PAGES):
        x0 = margin + (page % cols) * (page_w + gap)
        y0 = margin + (page // cols) * (label_h + page_h + gap)
        draw.text((x0, y0), f"page {page}", fill="white")

        for index in range(PAGE_COLS * PAGE_ROWS):
            glyph = words[page * PAGE_COLS * PAGE_ROWS + index]
            text_row, text_col = divmod(index, PAGE_COLS)
            base_x = x0 + text_col * GLYPH_W * scale
            base_y = y0 + label_h + text_row * GLYPH_H * scale

            for row, col in glyph_pixels(glyph):
                x = base_x + col * scale
                y = base_y + row * scale
                draw.rectangle([x, y, x + scale - 1, y + scale - 1], fill="white")

    return image


def render_gddram(data, scale):
    width = GDDRAM_COLS * scale
    height = GDDRAM_PAGES * 8 * scale

    image = Image.new("1", (GDDRAM_COLS, GDDRAM_PAGES * 8), 0)
    pixels = image.load()
    assert pixels

    for i, byte in enumerate(data):
        page, col = divmod(i, GDDRAM_COLS)
        for bit in range(8):
            if (byte >> bit) & 1:
                pixels[col, page * 8 + bit] = 1

    return image.convert("L").resize((width, height), Image.Resampling.NEAREST).convert("RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", type=Path)
    parser.add_argument("-o", "--output", type=Path, help="defaults to the input stem + .jpg")
    parser.add_argument("--scale", type=int, default=4)
    parser.add_argument("--open", action="store_true", help="open the result with xdg-open")
    args = parser.parse_args()

    values = load_values(args.input)
    if len(values) == WORDS and max(values) > 0xFF:
        image = render_glyphs(values, args.scale)
    elif len(values) <= GDDRAM_BYTES and max(values) <= 0xFF:
        image = render_gddram(values, args.scale)
    else:
        raise SystemExit(
            f"{args.input}: expected {WORDS} glyph lines or at most "
            f"{GDDRAM_BYTES} GDDRAM bytes, got {len(values)}"
        )

    output = (
        args.output
        or (args.open and tempfile.NamedTemporaryFile(prefix="render_fb.", suffix=".jpg").name)
        or args.input.with_suffix(".jpg")
    )
    image.save(output, quality=95)

    if sys.stdout.isatty():
        output_abs = Path(output).absolute()
        print(f"\033]8;;file://{output_abs}\033\\\033[33;m{output}\033[0;m\033]8;;\033\\")
    else:
        print(output)

    if args.open:
        subprocess.run(["xdg-open", str(output)], check=False)


if __name__ == "__main__":
    main()
