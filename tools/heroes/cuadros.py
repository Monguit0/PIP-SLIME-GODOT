# Pasa los cuadros de PixelLab de un héroe a assets/sprites/<héroe>/<animación>/frame_NNN.png:
# lienzo de 68x68 con los pies en la fila 56, paleta de 9 bits y fondo transparente.
# La entrada son hojas "una animación por fila" del pixelart_workbench de PixelLab
# (join character:<id>:east:<anim> ... --as rows): 18 px de rótulo arriba y celdas de 68x68.
#   python3 tools/heroes/cuadros.py receta.json
# receta: {"out": "assets/sprites/caballero", "hojas": {"a": "hoja1.png", ...},
#          "anims": {"idle": ["a", fila, [cuadros]], ...}, "verde_a_fuego": ["spin"]}
import sys, os, json
import numpy as np
from PIL import Image

LV = np.array([0, 36, 73, 109, 146, 182, 219, 255])
CELL, LAB, FEET = 68, 18, 56


def q9(a):
    return LV[np.abs(a[..., None].astype(int) - LV).argmin(-1)].astype(np.uint8)


def cell(sheet, row, i):
    f = sheet[LAB + row * CELL:LAB + row * CELL + CELL, i * CELL:i * CELL + CELL].copy()
    bg = sheet[LAB + 12, 2, :3]
    on = np.abs(f[..., :3].astype(int) - bg.astype(int)).sum(-1) > 0
    out = np.zeros((CELL, CELL, 4), np.uint8)
    out[..., :3] = q9(f[..., :3])
    out[..., 3] = np.where(on, 255, 0)
    out[~on, :3] = 0
    return out


# el resplandor verde o celeste que PixelLab le puso al giro pasa a viento de fuego (naranja y amarillo)
FIRE = [(109, 36, 0), (182, 73, 36), (255, 109, 73), (255, 182, 109), (255, 219, 182), (255, 255, 255)]


def green_to_fire(f):
    r, g, b = [f[..., k].astype(int) for k in range(3)]
    m = (f[..., 3] > 0) & (g > r + 40) & ((g > b + 20) | (b > r + 40))
    lum = (r + g + b) / 3.0
    idx = np.clip((lum / 255.0 * len(FIRE)).astype(int), 0, len(FIRE) - 1)
    for k, c in enumerate(FIRE):
        sel = m & (idx == k)
        f[sel, 0], f[sel, 1], f[sel, 2] = c
    return f


def main():
    rec = json.load(open(sys.argv[1]))
    base = os.path.dirname(os.path.abspath(sys.argv[1]))
    sheets = {k: np.array(Image.open(os.path.join(base, v)).convert('RGBA')) for k, v in rec["hojas"].items()}
    fire = set(rec.get("verde_a_fuego", []))
    for anim, (sh, row, idx) in rec["anims"].items():
        frames = [cell(sheets[sh], row, i) for i in idx]
        # los que vienen más chicos (plantillas de 48) quedan más abajo: se suben hasta la fila de los pies
        ys = np.where(frames[0][..., 3].any(1))[0]
        dy = FEET - ys.max() if anim != "jump" and anim != "fall" else 0
        d = os.path.join(rec["out"], anim)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            os.remove(os.path.join(d, f))
        for j, f in enumerate(frames):
            if dy:
                f = np.roll(f, dy, axis=0)
            if anim in fire:
                f = green_to_fire(f)
            Image.fromarray(f).save(os.path.join(d, "frame_%03d.png" % j))
        print(anim, len(frames), "dy", dy)
    # el cuadro quieto
    Image.open(os.path.join(rec["out"], "idle", "frame_000.png")).save(os.path.join(rec["out"], "east.png"))


main()
