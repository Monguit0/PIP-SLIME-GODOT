# Íconos chicos del HUD (rayo de energía, estrella de experiencia, yelmo del jefe) armados con figuras
# simples a resolución HD, contorno y luz arriba a la izquierda, en la paleta de 9 bits.
# Se usan hasta que estén los de PixelLab (si están, este script no hace falta).
#   python3 tools/ui/icons.py assets/sprites/ui/
import sys, os, math
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else 'assets/sprites/ui/'
os.makedirs(OUT, exist_ok=True)


def C(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)] + [255], np.uint8)


K = C('000024')
CYAN = [C('246db6'), C('49b6db'), C('6dffff'), C('b6ffff'), C('ffffff')]
GOLD = [C('924924'), C('db9224'), C('ffdb6d'), C('ffffb6'), C('ffffff')]
IRON = [C('242449'), C('49496d'), C('6d6d92'), C('92b6db'), C('dbdbff')]
HORN = [C('492424'), C('6d4924'), C('926d49'), C('b6926d'), C('dbb692')]
RED = [C('490024'), C('6d0024'), C('b62449'), C('ff6d6d')]


def inside(poly, x, y):
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def mask_of(w, h, test):
    return np.array([[test(x + 0.5, y + 0.5) for x in range(w)] for y in range(h)])


def outline(m):
    o = np.zeros_like(m)
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o & ~m


def shade(a, m, ramp, cx, cy, spread):
    """luz desde arriba a la izquierda: borde de arriba claro, abajo-derecha oscuro"""
    h, w = m.shape
    up = np.zeros_like(m)
    up[1:] = m[1:] & ~m[:-1]
    up[0] = m[0]
    dn = np.zeros_like(m)
    dn[:-1] = m[:-1] & ~m[1:]
    dn[-1] = m[-1]
    rt = np.zeros_like(m)
    rt[:, :-1] = m[:, :-1] & ~m[:, 1:]
    for y in range(h):
        for x in range(w):
            if not m[y, x]:
                continue
            k = ((x + 0.5 - cx) + (y + 0.5 - cy)) / spread
            i = 3 if k < -0.5 else 2 if k < 0.45 else 1
            if up[y, x]:
                i = min(4, i + 1)
            if dn[y, x] or rt[y, x]:
                i = max(0, i - 1)
            a[y, x] = ramp[i]


def bolt():
    w = h = 12
    P = [(7.0, 1.0), (10.8, 1.0), (7.6, 4.6), (10.6, 4.6), (3.0, 11.2), (5.0, 7.0), (1.8, 7.0)]
    m = mask_of(w, h, lambda x, y: inside(P, x, y))
    a = np.zeros((h, w, 4), np.uint8)
    shade(a, m, CYAN, 6, 6, 6)
    a[outline(m)] = K
    return a


def star():
    w, h = 13, 13
    cx, cy = 6.5, 7.0
    P = []
    for i in range(10):
        r = 6.4 if i % 2 == 0 else 2.7
        ang = -math.pi / 2 + i * math.pi / 5
        P.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    m = mask_of(w, h, lambda x, y: inside(P, x, y))
    a = np.zeros((h, w, 4), np.uint8)
    shade(a, m, GOLD, cx, cy, 5)
    a[outline(m)] = K
    # brillito en el centro
    a[6, 5] = GOLD[4]
    return np.pad(a, ((0, 0), (0, 1), (0, 0)))


def helm():
    w = h = 20
    def dome(x, y):
        if 4 <= x <= 16 and 8 <= y <= 17:
            return True
        return ((x - 10) / 6.2) ** 2 + ((y - 9) / 7.6) ** 2 <= 1
    m = mask_of(w, h, dome)
    hornL = [(5.2, 7.8), (3.6, 5.0), (1.8, 1.4), (1.0, 3.8), (2.0, 7.8), (4.6, 10.4)]
    hornR = [(20 - x, y) for x, y in hornL]
    hl = mask_of(w, h, lambda x, y: inside(hornL, x, y)) & ~m
    hr = mask_of(w, h, lambda x, y: inside(hornR, x, y)) & ~m
    a = np.zeros((h, w, 4), np.uint8)
    shade(a, m, IRON, 9, 8, 7)
    shade(a, hl | hr, HORN, 8, 4, 6)
    allm = m | hl | hr
    a[outline(allm)] = K
    # cresta de oro al medio y el borde de abajo
    for y in range(2, 9):
        if m[y, 9]:
            a[y, 9] = GOLD[3]
            a[y, 10] = GOLD[1]
    for x in range(4, 17):
        a[16, x] = GOLD[2] if x < 11 else GOLD[1]
    # visera: la ranura de los ojos con un brillo rojo y los respiraderos
    for x in range(5, 16):
        a[10, x] = K
    a[10, 7] = RED[3]
    a[10, 12] = RED[2]
    for x in (8, 10, 12):
        for y in (12, 13, 14):
            if x != 10 or y != 13:
                a[y, x] = IRON[0]
    a[11, 5:16] = IRON[1]
    return a


def save(a, name):
    Image.fromarray(a).save(OUT + name)
    print(name, a.shape[1], a.shape[0])


save(bolt(), 'icon_energia.png')
save(star(), 'icon_exp.png')
save(helm(), 'icon_jefe.png')
