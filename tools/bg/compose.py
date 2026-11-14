# Arma las capas del fondo con las piezas de PixelLab: cielo, montañas lejanas con el castillo del rey,
# capa del medio (bosque, ruinas, murallas) y el salón del trono. Saca también vistas de prueba.
import sys
import numpy as np
from PIL import Image

import os
HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, 'piezas') + '/'
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'assets', 'level1') + '/'
os.makedirs(OUT, exist_ok=True)
LV = 9  # niveles por canal del 9 bits
GRID = np.array([0, 36, 73, 109, 146, 182, 219, 255])


def q9(a):
    """al color de 9 bits más cercano (como todo el arte del juego)"""
    a = a.copy()
    rgb = a[:, :, :3].astype(int)
    idx = np.abs(rgb[:, :, :, None] - GRID[None, None, None, :]).argmin(-1)
    a[:, :, :3] = GRID[idx]
    return a


def load(n):
    return np.array(Image.open(D + n + '.png').convert('RGBA'))


def fog(a, k, haze=(36, 36, 109), dark=1.0):
    """lejanía: oscurece y tiñe hacia el azul de la noche, conserva la transparencia"""
    a = a.copy()
    o = a[:, :, :3].astype(int)
    warm = (o[:, :, 0] >= 180) & (o[:, :, 1] >= 100) & (o[:, :, 2] <= 120)  # ventanas encendidas: siguen brillando
    rgb = a[:, :, :3].astype(float) * dark
    rgb = rgb * (1 - k) + np.array(haze, float) * k
    a[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    a[warm, :3] = o[warm]
    return q9(a)


def paste(dst, src, x, y):
    """alpha binario (pixel art): copia donde la pieza tiene pintura"""
    h, w = src.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(dst.shape[1], x + w), min(dst.shape[0], y + h)
    if x1 <= x0 or y1 <= y0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    m = s[:, :, 3] > 127
    d = dst[y0:y1, x0:x1]
    d[m] = s[m]
    d[m, 3] = 255


def bbox(a):
    m = a[:, :, 3] > 0
    ys, xs = np.where(m)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def crop(a, cut_bottom=0):
    x0, y0, x1, y1 = bbox(a)
    return a[y0:y1 - cut_bottom, x0:x1]


# ---------------------------------------------------------------- cielo
sky = load('sky')
sky = q9(sky)

# ---------------------------------------------------------------- montañas lejanas (1280 de ancho)
mt = load('mountains')
H0 = mt.shape[0]
al = mt[:, :, 3] > 0
top = np.array([np.argmax(al[:, x]) if al[:, x].any() else H0 for x in range(mt.shape[1])])
best = None
for x1 in range(0, 300):
    for x2 in range(x1 + 488, mt.shape[1]):
        if abs(top[x1] - top[x2]) > 1:
            continue
        sl = abs((top[x1 + 1] - top[x1]) - (top[x2] - top[x2 - 1]))
        diff = np.abs(mt[:, x1, :3].astype(int) - mt[:, x2, :3].astype(int)).sum()
        c = diff + sl * 400
        if best is None or c < best[0]:
            best = (c, x1, x2)
_, X1, X2 = best
print('costura montañas', best)
wide = np.concatenate([mt[:, :X2], mt[:, X1:]], axis=1)[:, :1280]
SHIFT = 22  # sube las montañas: los picos quedan entre y 100 y 165
far = np.zeros((288, 1280, 4), np.uint8)
far[:288 - 0] = wide[SHIFT:SHIFT + 288] if wide.shape[0] >= SHIFT + 288 else np.pad(wide[SHIFT:], ((0, 288 - (wide.shape[0] - SHIFT)), (0, 0), (0, 0)), mode='edge')
far = fog(far, 0.42, dark=0.72)
castle = crop(load('castle0'))
castle = fog(castle, 0.36, dark=0.8)
cw, ch = castle.shape[1], castle.shape[0]
CX = X2 - cw // 2  # el castillo del rey tapa la costura
paste(far, castle, CX, 236 - ch)
# la base del cerro se funde con el pie de las montañas
far[236:, CX:CX + cw][far[236:, CX:CX + cw, 3] > 0] = far[287, 0]

# ---------------------------------------------------------------- capa del medio (2200 de ancho)
mid = np.zeros((288, 2200, 4), np.uint8)
BASE = 262
TREE_FOG, RUIN_FOG, WALL_FOG = 0.38, 0.36, 0.34


def put(name, x, fogk, cut=0, base=BASE, dark=0.8):
    p = crop(load(name), cut)
    p = fog(p, fogk, dark=dark)
    paste(mid, p, x, base - p.shape[0])
    return p.shape[1]


# bosque (Pradera): de atrás hacia adelante, un poco encimados para que no se vean las uniones
order = [('trees3', -12), ('trees1', 118), ('trees0', 250), ('trees2', 372), ('trees1', 500), ('trees3', 622)]
for n, x in order:
    put(n, x, TREE_FOG, cut=4)
# loma continua adelante que tapa los cortes de las piezas
xs = np.arange(2200)
hill = 238 + 6 * np.sin(xs / 61.0) + 4 * np.sin(xs / 23.0 + 1.3)
tree_end = 800
for x in range(0, tree_end):
    y0 = int(round(hill[x] + max(0, x - 700) ** 2 / 400.0))  # al final baja hasta perderse
    if y0 >= 288:
        continue
    mid[y0:, x] = (0, 36, 36, 255)
    mid[y0, x] = (0, 73, 73, 255)
    if x % 7 < 2:
        mid[y0 - 1, x] = (36, 109, 109, 255)  # pastito con luz de luna
# ruinas (Ruinas)
for n, x in [('ruins1', 730), ('ruins0', 870), ('ruins2', 1010), ('ruins3', 1150)]:
    put(n, x, RUIN_FOG, cut=12)
# murallas (Murallas)
x = 1300
for n in ['walls1', 'walls0', 'walls2', 'walls3', 'walls1', 'walls2', 'walls0']:
    x += put(n, x, WALL_FOG) - 14
mid = q9(mid)

# ---------------------------------------------------------------- salón del trono
th = q9(load('throne'))

Image.fromarray(sky).save(OUT + 'sky.png')
Image.fromarray(far).save(OUT + 'far.png')
Image.fromarray(mid).save(OUT + 'mid.png')
Image.fromarray(th).save(OUT + 'arena.png')
print('listo', OUT)
