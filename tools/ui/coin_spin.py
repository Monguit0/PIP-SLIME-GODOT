# Hoja de la moneda girando (8 cuadros de media vuelta) a partir de la cara de frente: la cara se angosta
# y aparece el canto dorado del costado, como una moneda de verdad. Todo en HD y en la paleta de 9 bits.
#   python3 tools/ui/coin_spin.py assets/sprites/items/coin.png assets/sprites/items/coin_spin.png
import sys, math
import numpy as np
from PIL import Image

src = np.array(Image.open(sys.argv[1]).convert('RGBA'))
H, W = src.shape[:2]
N = 8
FW = W + 2  # cada cuadro: la cara más lugar para el canto
K = np.array([0, 0, 36, 255], np.uint8)
EDGE = [np.array(c, np.uint8) for c in ([146, 73, 36, 255], [219, 146, 36, 255], [255, 219, 109, 255])]

# filas que ocupa la moneda en cada columna (para dibujar el canto con la misma silueta)
rows = src[:, :, 3] > 0
ys = np.where(rows.any(1))[0]
top, bot = ys.min(), ys.max()
mid_c = W // 2
col_top = np.argmax(rows[:, mid_c])
col_bot = H - 1 - np.argmax(rows[::-1, mid_c])

out = np.zeros((H, FW * N, 4), np.uint8)
for k in range(N):
    th = k * math.pi / N
    c, s = math.cos(th), math.sin(th)
    fw = max(1, int(round(W * abs(c))))
    rim = int(round(3 * s)) if k else 0
    tot = fw + rim
    x0 = k * FW + (FW - tot) // 2
    f = out[:, x0:x0 + tot]
    right = c >= 0  # de qué lado se ve el canto
    # cara angostada (muestras de columnas, sin suavizado); el lado sin canto lleva contorno
    face = np.zeros((H, fw, 4), np.uint8)
    for x in range(fw):
        sx = min(W - 1, int((x + 0.5) * W / fw))
        face[:, x] = src[:, sx]
    if fw < W:
        far = 0 if right else -1
        face[:, far][face[:, far, 3] > 0] = K
    off = 0 if right else rim
    m = face[:, :, 3] > 0
    f[:, off:off + fw][m] = face[m]
    # canto: en cada fila sale del borde de la cara (la moneda es redonda), dorado con luz arriba
    rows_on = [y for y in range(H) if m[y].any()]
    if rim and rows_on:
        y0, y1 = rows_on[0], rows_on[-1]
        for y in rows_on:
            xs = np.where(m[y])[0]
            edge = off + (xs.max() if right else xs.min())
            step = 1 if right else -1
            f[y, edge] = EDGE[2] if y0 < y < y1 else K  # el contorno de ese lado pasa a ser el filo
            e = 2 if y < y0 + 3 else 0 if y > y1 - 3 else 1
            for i in range(1, rim + 1):
                x = edge + step * i
                if 0 <= x < tot:
                    f[y, x] = K if (i == rim or y in (y0, y1)) else EDGE[e]
Image.fromarray(out).save(sys.argv[2])
print(sys.argv[2], FW, H, N)
