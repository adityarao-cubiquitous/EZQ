#!/usr/bin/env python3
"""Generate lightweight wait-screen spot-the-difference puzzle images."""

from __future__ import annotations

import json
import random
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "web" / "wait-puzzles"
CANVAS_SIZE = (1200, 900)
PANEL_SIZE = (535, 735)
PANEL_Y = 116
LEFT_X = 48
RIGHT_X = 617
SOURCE_SIZE = (1400, 950)

PICSUM_IDS = [
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
]


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


TITLE_FONT = _font(36, bold=True)
LABEL_FONT = _font(22, bold=True)
SMALL_FONT = _font(18)


def download_source(picsum_id: int) -> Image.Image:
    url = f"https://picsum.photos/id/{picsum_id}/{SOURCE_SIZE[0]}/{SOURCE_SIZE[1]}.jpg"
    req = urllib.request.Request(url, headers={"User-Agent": "EZQ puzzle generator"})
    with urllib.request.urlopen(req, timeout=30) as response:
        payload = response.read()
    image = Image.open(BytesIO(payload)).convert("RGB")
    return ImageOps.exif_transpose(image)


def crop_to_panel(image: Image.Image) -> Image.Image:
    source_ratio = image.width / image.height
    target_ratio = PANEL_SIZE[0] / PANEL_SIZE[1]
    if source_ratio > target_ratio:
        width = int(image.height * target_ratio)
        left = (image.width - width) // 2
        box = (left, 0, left + width, image.height)
    else:
        height = int(image.width / target_ratio)
        top = (image.height - height) // 2
        box = (0, top, image.width, top + height)
    return image.crop(box).resize(PANEL_SIZE, Image.Resampling.LANCZOS)


def rounded_panel(image: Image.Image) -> Image.Image:
    panel = Image.new("RGBA", PANEL_SIZE, (255, 255, 255, 0))
    mask = Image.new("L", PANEL_SIZE, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, PANEL_SIZE[0], PANEL_SIZE[1]), radius=26, fill=255)
    panel.paste(image.convert("RGBA"), (0, 0), mask)
    return panel


def patch_hide(image: Image.Image, rng: random.Random, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    width = x1 - x0
    height = y1 - y0
    source_x = max(0, min(image.width - width, x0 + rng.choice([-54, 54, 72, -72])))
    source_y = max(0, min(image.height - height, y0 + rng.choice([-42, 42, 64, -64])))
    patch = image.crop((source_x, source_y, source_x + width, source_y + height))
    patch = patch.filter(ImageFilter.GaussianBlur(radius=1.1))
    image.paste(patch, (x0, y0))


def alter_region(image: Image.Image, box: tuple[int, int, int, int], factor: float) -> None:
    region = image.crop(box)
    region = ImageEnhance.Color(region).enhance(factor)
    region = ImageEnhance.Brightness(region).enhance(1.04 if factor < 1 else 0.96)
    image.paste(region, box)


def add_shape(draw: ImageDraw.ImageDraw, rng: random.Random, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    color = rng.choice(
        [
            (15, 118, 110, 210),
            (37, 99, 235, 205),
            (234, 88, 12, 205),
            (126, 34, 206, 205),
            (220, 38, 38, 205),
        ]
    )
    if rng.random() < 0.5:
        draw.ellipse(box, fill=color, outline=(255, 255, 255, 220), width=3)
    else:
        draw.rounded_rectangle(box, radius=8, fill=color, outline=(255, 255, 255, 220), width=3)


def difference_boxes(rng: random.Random) -> list[tuple[int, int, int, int]]:
    boxes: list[tuple[int, int, int, int]] = []
    attempts = 0
    while len(boxes) < 5 and attempts < 200:
        attempts += 1
        width = rng.randint(34, 58)
        height = rng.randint(30, 54)
        x0 = rng.randint(42, PANEL_SIZE[0] - width - 42)
        y0 = rng.randint(72, PANEL_SIZE[1] - height - 48)
        candidate = (x0, y0, x0 + width, y0 + height)
        if all(abs(x0 - b[0]) > 86 or abs(y0 - b[1]) > 86 for b in boxes):
            boxes.append(candidate)
    return boxes


def make_puzzle(source: Image.Image, index: int, picsum_id: int) -> Image.Image:
    rng = random.Random(20260712 + picsum_id * 101)
    left = crop_to_panel(source)
    right = left.copy()
    boxes = difference_boxes(rng)
    right_rgba = right.convert("RGBA")
    draw = ImageDraw.Draw(right_rgba, "RGBA")

    patch_hide(right_rgba, rng, boxes[0])
    alter_region(right_rgba, boxes[1], 0.35)
    add_shape(draw, rng, boxes[2])

    x0, y0, x1, y1 = boxes[3]
    tile = right_rgba.crop((x0, y0, x1, y1)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    right_rgba.paste(tile, (x0, y0))

    x0, y0, x1, y1 = boxes[4]
    draw.line((x0, y1, x1, y0), fill=(255, 255, 255, 220), width=5)
    draw.line((x0, y1, x1, y0), fill=(0, 104, 135, 220), width=2)

    right = right_rgba.convert("RGB")

    canvas = Image.new("RGB", CANVAS_SIZE, (245, 251, 255))
    canvas_draw = ImageDraw.Draw(canvas)
    canvas_draw.rounded_rectangle(
        (24, 24, CANVAS_SIZE[0] - 24, CANVAS_SIZE[1] - 24),
        radius=34,
        fill=(255, 255, 255),
        outline=(205, 235, 244),
        width=2,
    )
    canvas_draw.text((48, 42), "Find 5 differences", font=TITLE_FONT, fill=(10, 31, 45))
    canvas_draw.text(
        (48, 82),
        "Look closely while your table is getting ready.",
        font=SMALL_FONT,
        fill=(96, 125, 139),
    )
    canvas.paste(rounded_panel(left), (LEFT_X, PANEL_Y), rounded_panel(left))
    canvas.paste(rounded_panel(right), (RIGHT_X, PANEL_Y), rounded_panel(right))
    for label, x in (("A", LEFT_X), ("B", RIGHT_X)):
        pill = (x + 16, PANEL_Y + 16, x + 58, PANEL_Y + 52)
        canvas_draw.rounded_rectangle(
            pill,
            radius=12,
            fill=(255, 255, 255),
            outline=(180, 224, 238),
            width=2,
        )
        canvas_draw.text((x + 30, PANEL_Y + 21), label, font=LABEL_FONT, fill=(0, 104, 135), anchor="ma")
    canvas_draw.rounded_rectangle(
        (LEFT_X, PANEL_Y, LEFT_X + PANEL_SIZE[0], PANEL_Y + PANEL_SIZE[1]),
        radius=26,
        outline=(180, 224, 238),
        width=3,
    )
    canvas_draw.rounded_rectangle(
        (RIGHT_X, PANEL_Y, RIGHT_X + PANEL_SIZE[0], PANEL_Y + PANEL_SIZE[1]),
        radius=26,
        outline=(180, 224, 238),
        width=3,
    )
    return canvas


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in OUTPUT_DIR.glob("puzzle-*.jpg"):
        path.unlink()

    manifest = []
    for index, picsum_id in enumerate(PICSUM_IDS, start=1):
        source = download_source(picsum_id)
        puzzle = make_puzzle(source, index, picsum_id)
        output = OUTPUT_DIR / f"puzzle-{index:02d}.jpg"
        puzzle.save(output, format="JPEG", quality=86, optimize=True, progressive=True)
        manifest.append(
            {
                "id": f"puzzle-{index:02d}",
                "file": f"puzzle-{index:02d}.jpg",
                "source": f"https://picsum.photos/id/{picsum_id}/{SOURCE_SIZE[0]}/{SOURCE_SIZE[1]}.jpg",
                "sourceProvider": "Lorem Picsum",
                "differenceCount": 5,
            }
        )
        print(f"Wrote {output.relative_to(ROOT)}")

    (OUTPUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {len(manifest)} puzzle images to {OUTPUT_DIR.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
