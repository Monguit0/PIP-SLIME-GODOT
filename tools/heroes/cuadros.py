# Pasa los cuadros de PixelLab de un héroe a assets/sprites/<héroe>/<animación>/frame_NNN.png:
# lienzo de 68x68 con los pies en la fila 56, paleta de 9 bits y fondo transparente.
# La entrada son hojas "una animación por fila" del pixelart_workbench de PixelLab
# (join character:<id>:east:<anim> ... --as rows): 18 px de rótulo arriba y celdas de 68x68.
#   python3 tools/heroes/cuadros.py receta.json
# receta: {"out": "assets/sprites/caballero", "hojas": {"a": "hoja1.png", "b": ["hoja2.png", 68, 76], ...},
#          "anims": {"idle": ["a", fila, [cuadros]], "charge_hold": ["b", 0, [0, 1, 2, 3], ["a", 3, 3]], ...},
#          "verde_a_fuego": ["spin"]}
# Una hoja puede tener celdas más grandes (las animaciones que arrancan de un cuadro propio vienen en otro
# lienzo): se da el ancho y el alto. Con un cuarto dato, la animación se acomoda para que su primer cuadro
# calce con ese cuadro de otra hoja (así sale de la misma pose sin saltar) y se recorta a 68x68.
import sys, os, json
import numpy as np
from PIL import Image

LV = np.array([0, 36, 73, 109, 146, 182, 219, 255])
CELL, LAB, FEET = 68, 18, 56


def q9(a):
    return LV[np.abs(a[..., None].astype(int) - LV).argmin(-1)].astype(np.uint8)


def cell(sheet, row, i, cw=CELL, ch=CELL):
    f = sheet[LAB + row * ch:LAB + row * ch + ch, i * cw:i * cw + cw].copy()
    bg = sheet[LAB + 12, 2, :3]
    on = np.abs(f[..., :3].astype(int) - bg.astype(int)).sum(-1) > 0
    out = np.zeros((ch, cw, 4), np.uint8)
    out[..., :3] = q9(f[..., :3])
    out[..., 3] = np.where(on, 255, 0)
    out[~on, :3] = 0
    return out


def fit(frames, ref):
    """corre todos los cuadros para que el primero calce con ref (68x68) y los recorta a 68x68"""
    a = frames[0]
    ch, cw = a.shape[:2]
    best, bx, by = None, 0, 0
    ra = ref[..., 3] > 0
    for dy in range(-(ch - CELL) - 10, 11):
        for dx in range(-(cw - CELL) - 10, 11):
            sub = np.zeros((CELL, CELL), bool)
            ys0, xs0 = max(0, -dy), max(0, -dx)
            ys1, xs1 = min(CELL, ch - dy), min(CELL, cw - dx)
            if ys1 <= ys0 or xs1 <= xs0:
                continue
            sub[ys0:ys1, xs0:xs1] = a[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx, 3] > 0
            score = (sub & ra).sum() * 2 - (sub ^ ra).sum()
            if best is None or score > best:
                best, bx, by = score, dx, dy
    out = []
    for f in frames:
        g = np.zeros((CELL, CELL, 4), np.uint8)
        ys0, xs0 = max(0, -by), max(0, -bx)
        ys1, xs1 = min(CELL, ch - by), min(CELL, cw - bx)
        g[ys0:ys1, xs0:xs1] = f[ys0 + by:ys1 + by, xs0 + bx:xs1 + bx]
        out.append(g)
    return out, (bx, by)


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
    sheets, sizes = {}, {}
    for k, v in rec["hojas"].items():
        name, cw, ch = (v, CELL, CELL) if isinstance(v, str) else v
        sheets[k] = np.array(Image.open(os.path.join(base, name)).convert('RGBA'))
        sizes[k] = (cw, ch)
    fire = set(rec.get("verde_a_fuego", []))
    for anim, spec in rec["anims"].items():
        sh, row, idx = spec[:3]
        frames = [cell(sheets[sh], row, i, *sizes[sh]) for i in idx]
        dy = 0
        if len(spec) > 3:
            rs, rr, ri = spec[3]
            ref = cell(sheets[rs], rr, ri, *sizes[rs])
            frames, off = fit(frames, ref)
            print(anim, "calza con", spec[3], "corrido", off)
        else:
            # los que vienen más chicos (plantillas de 48) quedan más abajo: se suben hasta la fila de los pies
            # (los de v3 ya vienen con los pies en su fila; la punta de la espada puede bajar un poco más)
            ys = np.where(frames[0][..., 3].any(1))[0]
            dy = FEET - ys.max() if anim != "jump" and anim != "fall" else 0
            if abs(dy) <= 4:
                dy = 0
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
