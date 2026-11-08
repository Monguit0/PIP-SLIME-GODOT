# Marcos del HUD y de las cartas, dibujados a mano en código a la resolución HD (1 px = medio píxel del
# juego) y con la paleta de 9 bits: barras de energía y experiencia con su medallón, la barra del jefe,
# el marco de las cartas y el brillo de la carta elegida. Los íconos de adentro vienen de PixelLab.
#   python3 tools/ui/hud_parts.py assets/sprites/ui/
import sys, os
import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else 'assets/sprites/ui/'
os.makedirs(OUT, exist_ok=True)


def C(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)] + [255], np.uint8)


K, K2 = C('000024'), C('000000')
IRON = [C('242449'), C('49496d'), C('6d6d92'), C('92b6db'), C('dbdbff')]
GOLD = [C('6d2400'), C('924924'), C('db9224'), C('ffdb6d'), C('ffffb6')]
RED = [C('490024'), C('6d0024'), C('b62449'), C('ff6d6d')]
NAVY = [C('000024'), C('000049'), C('24246d'), C('494992')]


def img(w, h):
    return np.zeros((h, w, 4), np.uint8)


def socket(a, cx, cy, r, ring=GOLD):
    """medallón redondo: contorno, aro de oro con luz arriba a la izquierda y fondo de gema oscura"""
    h, w = a.shape[:2]
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = (dx * dx + dy * dy) ** 0.5
            if d > r:
                continue
            if d > r - 1:
                a[y, x] = K
            elif d > r - 3:
                lit = (-dx - dy) / max(d, 1e-6)  # 1 arriba a la izquierda, -1 abajo a la derecha
                a[y, x] = ring[4] if lit > 0.75 and d > r - 2 else ring[3] if lit > 0.2 else ring[2] if lit > -0.5 else ring[1]
            elif d > r - 4:
                a[y, x] = K
            else:
                lit = (dx + dy) / max(r, 1e-6)  # adentro al revés: hundido
                a[y, x] = NAVY[2] if lit > 0.35 else NAVY[1] if lit > -0.2 else NAVY[0]


def bar_frame(a, x0, y0, bw, bh, tip=GOLD):
    """marco de hierro de la barra (adentro vacío y oscuro) con punta de oro a la derecha"""
    x1, y1 = x0 + bw, y0 + bh
    a[y0 - 2:y1 + 2, x0 - 2:x1 + 2] = K
    a[y0 - 1, x0 - 1:x1 + 1] = IRON[3]
    a[y1, x0 - 1:x1 + 1] = IRON[1]
    a[y0 - 1:y1 + 1, x0 - 1] = IRON[2]
    a[y0 - 1:y1 + 1, x1] = IRON[1]
    a[y0 - 1, x1] = IRON[2]
    a[y0:y1, x0:x1] = C('242449')
    a[y0, x0:x1] = K
    # punta: un rombito de oro
    cy = (y0 + y1) / 2.0
    hh = bh / 2.0 + 2
    for x in range(x1 + 2, x1 + 2 + int(hh) + 2):
        k = x - (x1 + 1)
        half = hh + 1 - k
        if half <= 0:
            break
        for y in range(int(cy - half - 0.5), int(cy + half + 0.5)):
            yy = y + 0.5
            if abs(yy - cy) < half - 1:
                a[y, x] = tip[3] if yy < cy else tip[2]
            elif abs(yy - cy) < half:
                a[y, x] = K
    for y in range(y0 - 2, y1 + 2):
        if a[y, x1 + 1, 3] == 0:
            a[y, x1 + 1] = K
    # remaches de oro sobre el borde de arriba, cada tanto
    for x in range(x0 + 10, x1 - 4, 22):
        a[y0 - 2, x:x + 2] = K
        a[y0 - 1, x:x + 2] = tip[3]


def small_bar(bw, bh):
    """barra chica con medallón a la izquierda: medallón 20x20, adentro desde x=20"""
    H = 20
    a = img(20 + bw + 9, H)
    y0 = (H - bh) // 2
    bar_frame(a, 20, y0, bw, bh)
    socket(a, 10, 10, 9.6)
    return a, y0


def boss_bar(bw, bh):
    H = 24
    a = img(22 + bw + 11, H)
    y0 = (H - bh) // 2
    bar_frame(a, 22, y0, bw, bh, GOLD)
    # filete rojo arriba y abajo: es la barra del jefe
    a[y0 - 2, 22:22 + bw] = RED[1]
    a[y0 + bh + 1, 22:22 + bw] = RED[0]
    a[y0 - 3, 20:22 + bw + 2] = K
    a[y0 + bh + 2, 20:22 + bw + 2] = K
    socket(a, 12, 12, 11.6, GOLD)
    return a, y0


# ---------------------------------------------------------------- carta
CW, CH, M = 160, 196, 4  # cuerpo de la carta y margen para el brillo


def card_mask():
    m = np.zeros((CH, CW), bool)
    m[:] = True
    for y in range(3):
        for x in range(3 - y):
            for yy, xx in [(y, x), (y, CW - 1 - x), (CH - 1 - y, x), (CH - 1 - y, CW - 1 - x)]:
                m[yy, xx] = False
    return m


def dist_in(m):
    """distancia (en píxeles, tablero de ajedrez) de cada píxel al borde de la máscara"""
    d = np.zeros((m.shape[0] + 2, m.shape[1] + 2), int)
    cur = np.pad(m, 1)  # afuera de la imagen también es borde
    k = 0
    while cur.any():
        k += 1
        d[cur] = k
        sh = cur.copy()
        sh[1:] &= cur[:-1]
        sh[:-1] &= cur[1:]
        sh[:, 1:] &= cur[:, :-1]
        sh[:, :-1] &= cur[:, 1:]
        cur = sh
    return d[1:-1, 1:-1]


def bevel(a, x0, y0, x1, y1, ramp, th, inset=False):
    """borde biselado de grosor th: luz arriba-izquierda (o al revés si está hundido)"""
    for y in range(y0, y1):
        for x in range(x0, x1):
            e = min(x - x0, y - y0, x1 - 1 - x, y1 - 1 - y)
            if e >= th:
                continue
            tl = min(x - x0, y - y0) < min(x1 - 1 - x, y1 - 1 - y)
            if inset:
                tl = not tl
            if tl:
                a[y, x] = ramp[3] if e == 0 else ramp[2]
            else:
                a[y, x] = ramp[1] if e == 0 else ramp[2]


def diamond(a, cx, cy, r, ramp):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            d = abs(x - cx) + abs(y - cy)
            if d > r:
                continue
            if d == r:
                a[y, x] = K
            else:
                a[y, x] = ramp[4] if (x - cx) + (y - cy) < -r // 2 else ramp[3] if (x - cx) + (y - cy) < 0 else ramp[2]


WIN = (24, 26, 136, 102)  # ventana del dibujo (transparente: el color lo pone el juego)


def card():
    a = img(CW + 2 * M, CH + 2 * M)
    b = a[M:M + CH, M:M + CW]
    m = card_mask()
    d = dist_in(m)
    lit = np.add.outer(np.arange(CH), np.arange(CW)) < (CH + CW) / 2  # mitad de arriba a la izquierda
    yy, xx = np.mgrid[0:CH, 0:CW]
    tl = np.minimum(xx, yy) < np.minimum(CW - 1 - xx, CH - 1 - yy)
    b[m] = NAVY[0]
    b[d == 1] = K
    b[(d == 2) & tl] = GOLD[4]
    b[(d == 2) & ~tl] = GOLD[2]
    b[(d == 3) & tl] = GOLD[3]
    b[(d == 3) & ~tl] = GOLD[1]
    b[(d == 4)] = GOLD[2]
    b[(d == 5) & tl] = GOLD[1]
    b[(d == 5) & ~tl] = GOLD[3]
    b[d == 6] = K
    b[(d == 7) & tl] = NAVY[2]
    b[(d == 7) & ~tl] = NAVY[1]
    # trama suave en el fondo (como tela oscura)
    inner = d >= 8
    b[inner & ((xx + yy) % 4 == 0) & ((xx // 2 + yy // 2) % 2 == 0)] = NAVY[1]
    # esquineros de oro
    for cx, cy, sx, sy in [(8, 8, 1, 1), (CW - 9, 8, -1, 1), (8, CH - 9, 1, -1), (CW - 9, CH - 9, -1, -1)]:
        for i in range(10):
            b[cy, cx + sx * i] = GOLD[3]
            b[cy + sy * i, cx] = GOLD[3]
            b[cy + sy, cx + sx * i] = GOLD[1] if i > 0 else GOLD[3]
            b[cy + sy * i, cx + sx] = GOLD[1] if i > 0 else GOLD[3]
        diamond(b, cx + sx * 2, cy + sy * 2, 2, GOLD)
    # marco de la ventana del dibujo: contorno, bisel de oro hundido y otro contorno
    x0, y0, x1, y1 = WIN
    b[y0 - 4:y1 + 4, x0 - 4:x1 + 4] = K
    bevel(b, x0 - 3, y0 - 3, x1 + 3, y1 + 3, GOLD, 2, inset=True)
    b[y0:y1, x0:x1] = 0
    for cx, cy in [(x0 - 2, y0 - 2), (x1 + 1, y0 - 2), (x0 - 2, y1 + 1), (x1 + 1, y1 + 1)]:
        diamond(b, cx, cy, 2, GOLD)
    # cinta de arriba (el nombre de la clase): roja con borde de oro y colas en V
    rx0, rx1, ry0, ry1 = 26, 134, 4, 19
    for y in range(ry0, ry1):
        for x in range(rx0 - 6, rx1 + 6):
            cut = abs(y - (ry0 + ry1 - 1) / 2.0)
            if x < rx0 and (rx0 - x) > 6 - cut * 0.0 - (cut < 3) * 3 - (6 - cut) * 0:
                pass
            inside = rx0 <= x < rx1
            tail = (x < rx0 and x >= rx0 - 6 + max(0, 3 - int(cut))) or (x >= rx1 and x < rx1 + 6 - max(0, 3 - int(cut)))
            if not (inside or tail):
                continue
            edge = y in (ry0, ry1 - 1) or x in (rx0 - 6 + max(0, 3 - int(cut)), rx1 + 5 - max(0, 3 - int(cut)))
            if edge:
                b[y, x] = K
            elif tail:
                b[y, x] = RED[1] if y > (ry0 + ry1) / 2 else RED[2]
            elif y == ry0 + 1:
                b[y, x] = GOLD[3]
            elif y == ry1 - 2:
                b[y, x] = GOLD[1]
            elif y == ry0 + 2:
                b[y, x] = RED[3]
            else:
                b[y, x] = RED[2] if y < (ry0 + ry1) / 2 + 2 else RED[1]
    # separador entre el nombre y el efecto: filete de oro con un rombo al medio
    sy = 145
    b[sy - 1, 22:138] = K
    b[sy, 22:138] = GOLD[2]
    b[sy, 22:138:2] = GOLD[3]
    b[sy + 1, 22:138] = K
    diamond(b, 80, sy, 3, GOLD)
    diamond(b, 22, sy, 1, GOLD)
    diamond(b, 137, sy, 1, GOLD)
    a[M:M + CH, M:M + CW] = b
    return a


def glow():
    """brillo de la carta elegida: aro de tres píxeles por fuera del contorno"""
    a = img(CW + 2 * M, CH + 2 * M)
    full = np.zeros((CH + 2 * M, CW + 2 * M), bool)
    full[M:M + CH, M:M + CW] = card_mask()
    cur = full.copy()
    cols = [GOLD[4], GOLD[3], GOLD[2]]
    for k in range(3):
        nxt = cur.copy()
        nxt[1:] |= cur[:-1]
        nxt[:-1] |= cur[1:]
        nxt[:, 1:] |= cur[:, :-1]
        nxt[:, :-1] |= cur[:, 1:]
        a[nxt & ~cur] = cols[k]
        cur = nxt
    a[full] = GOLD[4]
    return a


def save(a, name):
    Image.fromarray(a).save(OUT + name)
    print(name, a.shape[1], a.shape[0])


en, y0 = small_bar(68, 6)
save(en, 'bar_energia.png')
print('  energía: adentro en x=20, y=%d' % y0)
xp, y0 = small_bar(68, 4)
save(xp, 'bar_exp.png')
print('  exp: adentro en x=20, y=%d' % y0)
bb, y0 = boss_bar(240, 8)
save(bb, 'bar_jefe.png')
print('  jefe: adentro en x=22, y=%d' % y0)
save(card(), 'carta.png')
save(glow(), 'carta_brillo.png')
