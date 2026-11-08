# Plataformas nuevas con los tilesets de PixelLab (de esquinas, 16x16): se arman por cuartos de 8x8
# (tapa izquierda, medio, tapa derecha; arriba el pasto, abajo el borde) y se pegan en level.png
# sobre las viejas, con la parte de arriba justo en la altura de la colisión.
import sys, os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TS = sys.argv[1] if len(sys.argv) > 1 else HERE + '/'
LEVEL = sys.argv[2] if len(sys.argv) > 2 else ""
OUT = sys.argv[3] if len(sys.argv) > 3 else ""
GRID = np.array([0, 36, 73, 109, 146, 182, 219, 255])
PLATS = [
    [40, 96, 64], [136, 72, 48], [216, 96, 64], [300, 64, 48], [376, 88, 56], [448, 60, 40],
    [560, 96, 48], [632, 72, 48], [704, 48, 64], [792, 72, 48], [864, 96, 48], [930, 64, 56],
    [1064, 96, 64], [1150, 64, 48], [1220, 88, 40], [1280, 56, 56], [1360, 96, 48], [1430, 72, 56],
    [1556, 96, 36], [1632, 66, 64], [1736, 96, 36],
]


def q9(a):
    a = a.copy()
    idx = np.abs(a[:, :, :3].astype(int)[:, :, :, None] - GRID[None, None, None, :]).argmin(-1)
    a[:, :, :3] = GRID[idx]
    a[:, :, 3] = np.where(a[:, :, 3] > 127, 255, 0)
    return a


class Tiles:
    def __init__(self, path, gain=1.0):
        a = np.array(Image.open(path).convert('RGBA')).astype(float)
        a[:, :, :3] = np.clip(a[:, :, :3] * gain, 0, 255)  # el ladrillo muy oscuro se perdía en los 9 bits
        self.img = q9(a.astype(np.uint8))
        self.by = {}
        for r in range(4):
            for c in range(4):
                t = self.img[r * 16:r * 16 + 16, c * 16:c * 16 + 16]
                occ = tuple(int((t[qy * 8:qy * 8 + 8, qx * 8:qx * 8 + 8, 3] > 0).mean() > 0.5)
                            for qy in (0, 1) for qx in (0, 1))  # NW, NE, SW, SE
                self.by.setdefault(occ, []).append(t)

    def get(self, occ, k=0):
        lst = self.by.get(occ)
        if not lst:
            raise KeyError(occ)
        return lst[k % len(lst)]


def col(t, qx):
    """columna de 8 px de un tile (los 16 de alto)"""
    return t[:, qx * 8:qx * 8 + 8]


def build(ts, w):
    """plataforma de w px (múltiplo de 8): 8 de pasto arriba + 16 de cuerpo + 8 colgando abajo"""
    n = w // 8
    out = np.zeros((32, w, 4), np.uint8)
    for k in range(n):
        if k == 0:
            top = col(ts.get((0, 0, 0, 1)), 1)      # solo SE: esquina de arriba a la izquierda
            bot = col(ts.get((0, 1, 0, 0)), 1)      # solo NE: esquina de abajo a la izquierda
        elif k == n - 1:
            top = col(ts.get((0, 0, 1, 0)), 0)      # solo SW
            bot = col(ts.get((1, 0, 0, 0)), 0)      # solo NW
        else:
            top = col(ts.get((0, 0, 1, 1), k // 2), k % 2)   # SW+SE: el borde de arriba
            bot = col(ts.get((1, 1, 0, 0), k // 2), k % 2)   # NW+NE: el borde de abajo
        out[0:16, k * 8:k * 8 + 8] = top        # mitad de arriba (vacía: pasto que asoma) + borde de arriba
        sub = bot.copy()
        m = sub[:, :, 3] > 0
        o = out[16:32, k * 8:k * 8 + 8]
        o[m] = sub[m]
    return out


def bricks(p):
    """el ladrillo del tileset es puro ruido rojo: le marca las juntas (hiladas de 4 px, trabadas)"""
    cap = p[4:12]
    white = (cap[:, :, 0] == 255) & (cap[:, :, 1] == 255) & (cap[:, :, 2] == 255)
    cap[white, :3] = (182, 182, 219)  # la tapa de piedra gris, no blanca
    body = p[10:23]
    h, w = body.shape[:2]
    for yy in range(h):
        for xx in range(w):
            px = body[yy, xx]
            if px[3] == 0 or px[0] < 100 or px[1] > px[0] * 0.6:
                continue  # borde, contorno o la tapa gris
            row = (yy + 1) // 4
            joint = (yy + 1) % 4 == 0 or (xx + (4 if row % 2 else 0)) % 10 == 0
            if joint:
                body[yy, xx, :3] = (73, 0, 36)
            elif (yy + 1) % 4 == 1 or (xx + (4 if row % 2 else 0)) % 10 == 1:
                body[yy, xx, :3] = (182, 36, 73)  # canto con luz arriba a la izquierda


def main():
    lv = np.array(Image.open(LEVEL).convert('RGBA'))
    gain = {'murallas': 1.75}
    sets = {z: Tiles(TS + f'ts_{z}.png', gain.get(z, 1.0)) for z in ['pradera', 'ruinas', 'murallas', 'salon']}
    for x, y, w in PLATS:
        z = 'pradera' if x < 512 else 'ruinas' if x < 1024 else 'murallas' if x < 1536 else 'salon'
        X, Y, Wd = x * 2, y * 2, w * 2
        # borra la vieja (cuerpo, borde y pasto) y las enredaderas verdes que colgaban
        poles = [c for c in range(X, X + Wd) if lv[Y + 20, c, 3] > 0 and lv[Y + 26, c, 3] > 0]
        lv[max(0, Y - 10):Y + 18, X - 4:X + Wd + 4] = 0
        below = lv[Y + 18:Y + 32, X - 4:X + Wd + 4]
        rgb = below[:, :, :3].astype(int)
        green = (rgb[:, :, 1] > rgb[:, :, 0] + 30) & (rgb[:, :, 1] > rgb[:, :, 2])
        if z == 'murallas':
            below[green] = 0  # acá abajo están los postes: solo se va lo verde
        else:
            below[:] = 0
        p = build(sets[z], Wd)
        if z == 'murallas':
            bricks(p)
        # la fila 8 de la pieza es el borde de arriba: va en la altura de la colisión
        reg = lv[Y - 8:Y + 24, X:X + Wd]
        m = p[:, :, 3] > 0
        reg[m] = p[m]
        # los postes de las murallas suben hasta tocar la plataforma nueva
        for c in poles:
            yy = Y + 19
            while yy > Y and lv[yy, c, 3] > 0:
                yy -= 1
            while yy > Y and lv[yy, c, 3] == 0:
                lv[yy, c] = lv[Y + 20, c]
                yy -= 1
    Image.fromarray(lv).save(OUT)
    print('listo', OUT)


if __name__ == '__main__':
    main()
