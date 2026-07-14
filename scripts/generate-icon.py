#!/usr/bin/env python3
"""Generate the Agent Dock macOS application icon.

The script creates a 1024x1024 source PNG using only the Python standard
library, then builds a complete .iconset with sips. It packages the iconset
with iconutil when available, with a direct ICNS writer as a fallback.
"""

from __future__ import annotations

import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path


SIZE = 1024


def clamp(value: float, low: int = 0, high: int = 255) -> int:
    return max(low, min(high, int(round(value))))


def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(clamp(a[i] + (b[i] - a[i]) * t) for i in range(4))


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.pixels = bytearray(width * height * 4)

    def blend_pixel(self, x: int, y: int, color: tuple[int, int, int, int]) -> None:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        r, g, b, a = color
        if a <= 0:
            return
        offset = (y * self.width + x) * 4
        if a >= 255:
            self.pixels[offset : offset + 4] = bytes((r, g, b, 255))
            return

        dst_r, dst_g, dst_b, dst_a = self.pixels[offset : offset + 4]
        src_a = a / 255.0
        dst_af = dst_a / 255.0
        out_a = src_a + dst_af * (1.0 - src_a)
        if out_a <= 0:
            return
        out_r = (r * src_a + dst_r * dst_af * (1.0 - src_a)) / out_a
        out_g = (g * src_a + dst_g * dst_af * (1.0 - src_a)) / out_a
        out_b = (b * src_a + dst_b * dst_af * (1.0 - src_a)) / out_a
        self.pixels[offset : offset + 4] = bytes((clamp(out_r), clamp(out_g), clamp(out_b), clamp(out_a * 255)))

    def draw_rounded_rect(
        self,
        x0: int,
        y0: int,
        x1: int,
        y1: int,
        radius: int,
        color_at: callable,
        feather: int = 3,
    ) -> None:
        for y in range(y0 - feather, y1 + feather):
            for x in range(x0 - feather, x1 + feather):
                cx = min(max(x, x0 + radius), x1 - radius)
                cy = min(max(y, y0 + radius), y1 - radius)
                outside = math.hypot(x - cx, y - cy) - radius
                if outside > feather:
                    continue
                coverage = 1.0 if outside <= 0 else 1.0 - outside / feather
                r, g, b, a = color_at(x, y)
                self.blend_pixel(x, y, (r, g, b, clamp(a * coverage)))

    def draw_rect(self, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int, int]) -> None:
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.blend_pixel(x, y, color)

    def draw_circle(self, cx: int, cy: int, radius: int, color: tuple[int, int, int, int], feather: int = 3) -> None:
        for y in range(cy - radius - feather, cy + radius + feather + 1):
            for x in range(cx - radius - feather, cx + radius + feather + 1):
                outside = math.hypot(x - cx, y - cy) - radius
                if outside > feather:
                    continue
                coverage = 1.0 if outside <= 0 else 1.0 - outside / feather
                r, g, b, a = color
                self.blend_pixel(x, y, (r, g, b, clamp(a * coverage)))

    def draw_line(self, x0: int, y0: int, x1: int, y1: int, width: int, color: tuple[int, int, int, int]) -> None:
        dx = x1 - x0
        dy = y1 - y0
        length_sq = dx * dx + dy * dy
        radius = width / 2.0
        xmin = min(x0, x1) - width
        xmax = max(x0, x1) + width
        ymin = min(y0, y1) - width
        ymax = max(y0, y1) + width
        for y in range(ymin, ymax + 1):
            for x in range(xmin, xmax + 1):
                if length_sq == 0:
                    distance = math.hypot(x - x0, y - y0)
                else:
                    t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / length_sq))
                    px = x0 + t * dx
                    py = y0 + t * dy
                    distance = math.hypot(x - px, y - py)
                if distance <= radius:
                    self.blend_pixel(x, y, color)

    def write_png(self, path: Path) -> None:
        rows = bytearray()
        stride = self.width * 4
        for y in range(self.height):
            rows.append(0)
            start = y * stride
            rows.extend(self.pixels[start : start + stride])

        def chunk(kind: bytes, data: bytes) -> bytes:
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

        png = bytearray(b"\x89PNG\r\n\x1a\n")
        png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)))
        png.extend(chunk(b"IDAT", zlib.compress(bytes(rows), 9)))
        png.extend(chunk(b"IEND", b""))
        path.write_bytes(png)


def draw_icon(path: Path) -> None:
    canvas = Canvas(SIZE, SIZE)

    def background_color(x: int, y: int) -> tuple[int, int, int, int]:
        diagonal = (x + y) / (SIZE * 2)
        radial = math.hypot(x - 760, y - 250) / 920
        base = mix((18, 35, 59, 255), (22, 114, 140, 255), diagonal)
        glow = mix(base, (80, 207, 176, 255), max(0.0, 1.0 - radial) * 0.35)
        return glow

    canvas.draw_rounded_rect(42, 42, 982, 982, 214, background_color, 5)

    for y in range(112, 920, 82):
        canvas.draw_line(154, y, 870, y, 2, (127, 221, 205, 32))
    for x in range(154, 900, 94):
        canvas.draw_line(x, 130, x, 874, 2, (127, 221, 205, 28))

    nodes = [
        (294, 292, 46, (86, 213, 187, 255)),
        (512, 230, 36, (255, 205, 91, 255)),
        (722, 314, 42, (122, 162, 255, 255)),
        (362, 552, 38, (255, 128, 119, 255)),
        (612, 560, 50, (88, 225, 154, 255)),
        (760, 716, 34, (237, 245, 255, 255)),
    ]
    links = [(294, 292, 512, 230), (512, 230, 722, 314), (294, 292, 362, 552), (362, 552, 612, 560), (612, 560, 760, 716), (722, 314, 612, 560)]
    for x0, y0, x1, y1 in links:
        canvas.draw_line(x0, y0, x1, y1, 18, (122, 230, 213, 70))
        canvas.draw_line(x0, y0, x1, y1, 7, (235, 253, 255, 98))

    panels = [(190, 168, 406, 380), (428, 142, 636, 354), (642, 216, 846, 428), (244, 444, 456, 658), (500, 432, 724, 670), (626, 642, 826, 824)]
    for x0, y0, x1, y1 in panels:
        canvas.draw_rounded_rect(x0, y0, x1, y1, 34, lambda _x, _y: (241, 250, 255, 26), 3)
        canvas.draw_rounded_rect(x0 + 8, y0 + 8, x1 - 8, y1 - 8, 26, lambda _x, _y: (3, 18, 30, 38), 2)
        canvas.draw_rect(x0 + 34, y0 + 42, x1 - 34, y0 + 54, (223, 250, 255, 92))
        canvas.draw_rect(x0 + 34, y0 + 78, x1 - 62, y0 + 88, (223, 250, 255, 48))

    for cx, cy, radius, color in nodes:
        canvas.draw_circle(cx, cy, radius + 20, (color[0], color[1], color[2], 42), 5)
        canvas.draw_circle(cx, cy, radius, color, 4)
        canvas.draw_circle(cx - radius // 4, cy - radius // 4, max(8, radius // 4), (255, 255, 255, 145), 3)

    dock_y = 842
    canvas.draw_rounded_rect(202, 790, 822, 910, 54, lambda _x, _y: (239, 251, 255, 42), 3)
    for i, color in enumerate([(86, 213, 187, 255), (255, 205, 91, 255), (122, 162, 255, 255), (255, 128, 119, 255), (88, 225, 154, 255)]):
        x = 318 + i * 98
        canvas.draw_circle(x, dock_y, 28, color, 3)
        canvas.draw_circle(x, dock_y + 45, 8, (226, 255, 244, 210), 2)

    canvas.draw_rounded_rect(42, 42, 982, 982, 214, lambda _x, _y: (255, 255, 255, 28), 5)
    canvas.write_png(path)


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def write_icns(iconset: Path, output: Path) -> None:
    entries = [
        ("icp4", "icon_16x16.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("icp5", "icon_32x32.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
    ]
    chunks = []
    for icon_type, filename in entries:
        data = (iconset / filename).read_bytes()
        chunks.append(icon_type.encode("ascii") + struct.pack(">I", len(data) + 8) + data)
    output.write_bytes(b"icns" + struct.pack(">I", sum(len(chunk) for chunk in chunks) + 8) + b"".join(chunks))


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    resources = repo_root / "Resources"
    resources.mkdir(exist_ok=True)

    source_png = resources / "AppIcon-1024.png"
    output_icns = resources / "AppIcon.icns"
    draw_icon(source_png)

    iconset = Path(tempfile.mkdtemp(prefix="AgentDock.", suffix=".iconset"))
    try:
        sizes = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        for name, size in sizes:
            run(["sips", "-z", str(size), str(size), str(source_png), "--out", str(iconset / name)])
        try:
            run(["iconutil", "-c", "icns", str(iconset), "-o", str(output_icns)])
        except subprocess.CalledProcessError:
            write_icns(iconset, output_icns)
    finally:
        shutil.rmtree(iconset, ignore_errors=True)

    print(f"generated: {source_png.relative_to(repo_root)}")
    print(f"generated: {output_icns.relative_to(repo_root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
