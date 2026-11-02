#!/usr/bin/env python3
# tools/draw_items.py
# Purpose: Draws the pearl icon, the rug, and the soil squares as small original pixel pictures.
# Run from the project root: python3 tools/draw_items.py

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLEAR = (0, 0, 0, 0)
INK = (63, 45, 39, 255)
STONE = (168, 150, 128, 255)
STONE_DARK = (122, 104, 90, 255)
STONE_LIGHT = (198, 182, 160, 255)
WATER = (79, 159, 154, 255)
WOOD = (122, 79, 50, 255)
WOOD_LIGHT = (160, 110, 70, 255)
ROOF = (201, 111, 74, 255)
ROOF_DARK = (160, 84, 58, 255)


def write_png(path, width, height, pixels):
    rows = b"".join(b"\x00" + bytes(c for px in pixels[y * width:(y + 1) * width] for c in px) for y in range(height))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    with open(path, "wb") as out:
        out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def draw_pearl():
    size = 16
    pixels = [CLEAR] * (size * size)
    for y in range(size):
        for x in range(size):
            dx = x - 7.5
            dy = y - 7.5
            dist = (dx * dx + dy * dy) ** 0.5
            if dist > 6.2:
                continue
            if dist > 5.3:
                pixels[y * size + x] = (120, 110, 130, 255)
                continue
            shine = max(0.0, 1.0 - ((x - 5.5) ** 2 + (y - 5.0) ** 2) ** 0.5 / 8.0)
            value = int(205 + 50 * shine)
            pixels[y * size + x] = (value, value, min(255, value + 6), 255)
    pixels[4 * size + 5] = (255, 255, 255, 255)
    pixels[4 * size + 6] = (255, 255, 255, 255)
    pixels[5 * size + 5] = (255, 255, 255, 255)
    write_png(os.path.join(ROOT, "assets/items/Pearl.png"), size, size, pixels)


def draw_well():
    width = 36
    height = 44
    pixels = [CLEAR] * (width * height)

    def put(x, y, color):
        if 0 <= x < width and 0 <= y < height:
            pixels[y * width + x] = color

    def box(x, y, w, h, color):
        for row in range(y, y + h):
            for col in range(x, x + w):
                put(col, row, color)

    # Stone ring.
    box(4, 26, 28, 16, STONE)
    box(4, 26, 28, 1, INK)
    box(4, 41, 28, 2, INK)
    box(3, 27, 1, 15, INK)
    box(32, 27, 1, 15, INK)
    box(7, 27, 22, 5, INK)
    box(8, 28, 20, 3, WATER)
    for row, start in [(34, 4), (38, 8)]:
        for col in range(start, 32, 7):
            box(col, row, 6, 3, STONE_LIGHT)
            box(col, row + 3, 6, 1, STONE_DARK)
    # Posts and bar.
    box(6, 10, 3, 18, WOOD)
    box(27, 10, 3, 18, WOOD)
    box(6, 10, 1, 18, WOOD_LIGHT)
    box(27, 10, 1, 18, WOOD_LIGHT)
    box(6, 14, 24, 2, WOOD)
    box(17, 16, 1, 9, INK)
    box(15, 24, 5, 4, WOOD_LIGHT)
    # Roof.
    for i in range(9):
        box(9 - i, 10 - i, 18 + i * 2, 1, ROOF if i % 2 == 0 else ROOF_DARK)
    box(0, 10, 36, 1, INK)
    write_png(os.path.join(ROOT, "assets/props/well.png"), width, height, pixels)


def draw_soil(name, base, furrow, speck):
    size = 16
    pixels = [base] * (size * size)
    for y in range(size):
        for x in range(size):
            mix = (x * 31 + y * 57 + x * y * 3) % 17
            if mix < 3:
                pixels[y * size + x] = furrow
            elif mix == 16:
                pixels[y * size + x] = speck
    write_png(os.path.join(ROOT, "assets/farming/%s.png" % name), size, size, pixels)


def draw_rug():
    width = 48
    height = 32
    red = (150, 52, 44, 255)
    black = (50, 34, 30, 255)
    cream = (240, 226, 196, 255)
    pixels = [red] * (width * height)
    for y in range(height):
        for x in range(width):
            edge = min(x, y, width - 1 - x, height - 1 - y)
            if edge < 2:
                pixels[y * width + x] = black
            elif edge < 3:
                pixels[y * width + x] = cream
            elif abs((x - 24) % 12 - 6) + abs(y - 16) < 6:
                pixels[y * width + x] = cream if abs((x - 24) % 12 - 6) + abs(y - 16) < 3 else black
    write_png(os.path.join(ROOT, "assets/props/rug_sadu.png"), width, height, pixels)


if __name__ == "__main__":
    draw_pearl()
    draw_rug()
    draw_soil("soil_bed", (150, 112, 74, 255), (132, 96, 62, 255), (168, 130, 88, 255))
    draw_soil("soil_tilled", (120, 84, 56, 255), (94, 64, 42, 255), (136, 98, 66, 255))
    draw_soil("soil_wet", (78, 54, 40, 255), (58, 40, 30, 255), (92, 66, 50, 255))
