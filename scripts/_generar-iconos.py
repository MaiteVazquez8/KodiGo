# -*- coding: utf-8 -*-
"""Genera los recursos Android de Kodigo desde el fantasma oficial (public/kodigo.png)."""
from PIL import Image, ImageDraw, ImageFilter
import os

SRC = 'public/kodigo.png'
RES = 'android/app/src/main/res'

VIOLETA_OSCURO = (62, 6, 95, 255)     # #3E065F
VIOLETA_MARCA = (112, 11, 151, 255)   # #700B97
VIOLETA_ACENTO = (142, 5, 194, 255)   # #8E05C2
NEGRO = (0, 0, 0, 255)
BLANCO = (255, 255, 255, 255)

ICON = Image.open(SRC).convert('RGBA')
print('fuente', ICON.size)

# Recortar al fantasma (alpha)
alpha = ICON.getchannel('A')
bbox = alpha.getbbox()
ghost = ICON.crop(bbox)
print('bbox fantasma', ghost.size)

def centrar(canvas, elemento, escala):
    objetivo = int(min(canvas.size) * escala)
    r = ghost.copy()
    r.thumbnail((objetivo, objetivo), Image.LANCZOS)
    out = Image.new('RGBA', canvas.size, canvas.getpixel((0, 0)))
    x = (canvas.width - r.width) // 2
    y = (canvas.height - r.height) // 2
    out.paste(r, (x, y), r)
    return out

def fondo(color, size):
    return Image.new('RGBA', (size, size), color)

# Densidades y tamaños estándar
den = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
icon_px = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
fg_px = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
splash = {'mdpi': (480, 800, 800, 480), 'hdpi': (480, 800, 800, 480), 'xhdpi': (720, 1280, 1280, 720),
          'xxhdpi': (1080, 1920, 1920, 1080), 'xxxhdpi': (1440, 2560, 2560, 1440)}

for d, f in den.items():
    os.makedirs(f'{RES}/mipmap-{d}', exist_ok=True)
    # Legacy ic_launcher: fondo oscuro + fantasma
    img = fondo(VIOLETA_OSCURO, icon_px[d])
    img = centrar(img, ghost, 0.72)
    img.save(f'{RES}/mipmap-{d}/ic_launcher.png')
    # Round: mismo contenido, máscara circular
    img = fondo(VIOLETA_OSCURO, icon_px[d])
    img = centrar(img, ghost, 0.72)
    mask = Image.new('L', (icon_px[d], icon_px[d]), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, icon_px[d], icon_px[d]], fill=255)
    round_img = Image.new('RGBA', (icon_px[d], icon_px[d]), (0, 0, 0, 0))
    round_img.paste(img, (0, 0), mask)
    round_img.save(f'{RES}/mipmap-{d}/ic_launcher_round.png')
    # Adaptive foreground: fantasma con margen seguro
    img = Image.new('RGBA', (fg_px[d], fg_px[d]), (0, 0, 0, 0))
    img = centrar(img, ghost, 0.62)
    img.save(f'{RES}/mipmap-{d}/ic_launcher_foreground.png')

# Splash por orientación (fondo #3E065F, fantasma violeta en el centro)
for d, sizes in splash.items():
    for orientation, size in (('port', (sizes[0], sizes[1])), ('land', (sizes[2], sizes[3]))):
        os.makedirs(f'{RES}/drawable-{orientation}-{d}', exist_ok=True)
        img = Image.new('RGBA', size, VIOLETA_OSCURO)
        centrado = centrar(img, ghost, 0.38)
        centrado.save(f'{RES}/drawable-{orientation}-{d}/splash.png')

# Splash legacy raíz
img = Image.new('RGBA', (1080, 1920), VIOLETA_OSCURO)
centrar(img, ghost, 0.38).save(f'{RES}/drawable/splash.png')
print('recursos generados')
