#!/usr/bin/env python3
"""Compõe os ícones da app a partir do primeiro plano renderizado por tools/render_icon.gd.
Uso: python3 tools/compose_icon.py <primeiro_plano.png> <pasta_saida>"""
import random, sys
from PIL import Image, ImageDraw

fg = Image.open(sys.argv[1]).convert('RGBA')
fg = fg.crop(fg.getbbox())
OUT = sys.argv[2]

def background(S):
    bg = Image.new('RGB', (S, S)); px = bg.load()
    top, bot = (54, 36, 92), (255, 150, 120)
    for y in range(S):
        t = (y / S) ** 1.3
        c = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
        for x in range(S): px[x, y] = c
    d = ImageDraw.Draw(bg); rnd = random.Random(7)
    for _ in range(int(S * 0.06)):
        x, y = rnd.random() * S, rnd.random() * S * 0.55
        r = max(1, S * rnd.choice([0.004, 0.006, 0.009]))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 240, 214))
    R, cx, cy, o = S * 0.62, S * 0.5, S * 1.30, S * 0.012
    d.ellipse([cx - R - o, cy - R - o, cx + R + o, cy + R + o], fill=(40, 28, 60))
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(143, 211, 160))
    pr, px_, py, o = S * 0.07, S * 0.80, S * 0.20, S * 0.008
    d.ellipse([px_ - pr - o, py - pr - o, px_ + pr + o, py + pr + o], fill=(40, 28, 60))
    d.ellipse([px_ - pr, py - pr, px_ + pr, py + pr], fill=(255, 200, 87))
    return bg

def place(canvas, frac, yfrac):
    S = canvas.size[0]; h = int(S * frac); w = int(fg.size[0] * h / fg.size[1])
    canvas.alpha_composite(fg.resize((w, h), Image.LANCZOS), ((S - w) // 2, int(S * yfrac - h / 2)))
    return canvas

for S in (512, 192):
    place(background(S).convert('RGBA'), 0.80, 0.54).save(f'{OUT}/icon_{S}.png')
background(432).save(f'{OUT}/adaptive_background_432.png')
fgc = place(Image.new('RGBA', (432, 432), (0, 0, 0, 0)), 0.56, 0.52)
fgc.save(f'{OUT}/adaptive_foreground_432.png')
mono = Image.new('RGBA', (432, 432), (0, 0, 0, 0)); mono.paste((255, 255, 255, 255), mask=fgc.split()[3])
mono.save(f'{OUT}/adaptive_monochrome_432.png')
print('ok')
