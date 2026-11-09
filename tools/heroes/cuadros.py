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
# Con un cuarto dato en la hoja ["hoja.png", ancho, alto, columnas] la hoja es una grilla (join ... --as sheet
# --columns N) y los cuadros se cuentan seguidos. Los golpes (tajo y espadazo) van en un lienzo más grande
# que 68x68, con el mismo centro, y su estela pasa a la rampa del héroe: ver big() más abajo.
#   python3 tools/heroes/cuadros.py receta.json [--hojas carpeta] [animaciones...]
import sys, os, json
import numpy as np
from PIL import Image

LV = np.array([0, 36, 73, 109, 146, 182, 219, 255])
CELL, LAB, FEET = 68, 18, 56


def q9(a):
    return LV[np.abs(a[..., None].astype(int) - LV).argmin(-1)].astype(np.uint8)


def cell(sheet, row, i, cw=CELL, ch=CELL, cols=None):
    if cols:  # hoja en grilla (join ... --as sheet --columns N): i cuenta de izquierda a derecha y de arriba abajo
        row, i = divmod(i, cols)
    f = sheet[LAB + row * ch:LAB + row * ch + ch, i * cw:i * cw + cw].copy()
    bg = sheet[LAB + 12, 2, :3]
    on = np.abs(f[..., :3].astype(int) - bg.astype(int)).sum(-1) > 0
    out = np.zeros((ch, cw, 4), np.uint8)
    out[..., :3] = q9(f[..., :3])
    out[..., 3] = np.where(on, 255, 0)
    out[~on, :3] = 0
    return out


def align(a, ref, rows=(0, CELL)):
    """dónde cae el cuadro quieto (ref, 68x68) dentro del cuadro a: el pixel (x, y) de ref es el (x+dx, y+dy) de a.
    rows: solo se comparan esas filas del quieto (la cabeza y el torso, para las poses en el aire)"""
    ch, cw = a.shape[:2]
    best, bx, by = None, 0, 0
    r0, r1 = rows
    ra = np.zeros((CELL, CELL), bool)
    ra[r0:r1] = ref[r0:r1, :, 3] > 0
    for dy in range(-(ch - CELL) - 10, (ch - CELL) + 11):
        for dx in range(-(cw - CELL) - 10, (cw - CELL) + 11):
            sub = np.zeros((CELL, CELL), bool)
            ys0, xs0 = max(0, -dy), max(0, -dx)
            ys1, xs1 = min(CELL, ch - dy), min(CELL, cw - dx)
            if ys1 <= ys0 or xs1 <= xs0:
                continue
            sub[ys0:ys1, xs0:xs1] = a[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx, 3] > 0
            sub[:r0] = False
            sub[r1:] = False
            score = (sub & ra).sum() * 2 - (sub ^ ra).sum()
            if best is None or score > best:
                best, bx, by = score, dx, dy
    return bx, by


def fit(frames, ref):
    """corre todos los cuadros para que el primero calce con ref (68x68) y los recorta a 68x68"""
    ch, cw = frames[0].shape[:2]
    bx, by = align(frames[0], ref)
    out = []
    for f in frames:
        g = np.zeros((CELL, CELL, 4), np.uint8)
        ys0, xs0 = max(0, -by), max(0, -bx)
        ys1, xs1 = min(CELL, ch - by), min(CELL, cw - bx)
        g[ys0:ys1, xs0:xs1] = f[ys0 + by:ys1 + by, xs0 + bx:xs1 + bx]
        out.append(g)
    return out, (bx, by)


def wide(frames, offs, pad=None):
    """lienzo más grande que 68x68 con el mismo centro (el AnimatedSprite2D está centrado: así no salta).
    Se agranda lo mismo de cada lado hasta que entra todo; los pies siguen 22 px abajo del centro.
    offs: dónde está el quieto en los cuadros, (bx, by) de align(); uno para todos o uno por cuadro."""
    ch, cw = frames[0].shape[:2]
    offs = offs if isinstance(offs, list) else [offs] * len(frames)
    if pad is None:
        x0 = y0 = 10 ** 9
        x1 = y1 = -10 ** 9
        for f, (bx, by) in zip(frames, offs):
            ys, xs = np.nonzero(f[..., 3])
            if len(xs):
                x0, x1 = min(x0, xs.min() - bx), max(x1, xs.max() - bx)
                y0, y1 = min(y0, ys.min() - by), max(y1, ys.max() - by)
        px, py = max(0, -x0, x1 - (CELL - 1)), max(0, -y0, y1 - (CELL - 1))
        pad = (px + px % 2, py + py % 2)
    px, py = pad
    W, H = CELL + 2 * px, CELL + 2 * py
    out = []
    for f, (bx, by) in zip(frames, offs):
        g = np.zeros((H, W, 4), np.uint8)
        ox, oy = px - bx, py - by
        ys0, xs0 = max(0, -oy), max(0, -ox)
        ys1, xs1 = min(ch, H - oy), min(cw, W - ox)
        g[ys0 + oy:ys1 + oy, xs0 + ox:xs1 + ox] = f[ys0:ys1, xs0:xs1]
        out.append(g)
    return out, pad


def grow(m, n=1):
    for _ in range(n):
        g = m.copy()
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        m = g
    return m


# la estela clara que PixelLab dibuja detrás de la hoja pasa a la rampa del héroe (rojo el caballero,
# dorado el Paladín): el filo blanco queda, el resto toma color y lleva dos bordes de la rampa por fuera
RAMPS = {"r": ["#490024", "#6d0024", "#b62449", "#ff6d6d", "#ffb692"],
         "y": ["#924924", "#db9224", "#ffdb6d", "#ffffb6", "#ffffff"]}


def hexa(c):
    return np.array([int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16), 255], np.uint8)


def tint_smear(f, others, ramp, lmin=120):
    """la estela: lo claro y gris que no está donde está el cuerpo en los cuadros vecinos (others)"""
    body = np.zeros(f.shape[:2], bool)
    for o in others:
        body |= o[..., 3] > 0
    body = grow(body, 2)
    rgb = f[..., :3].astype(int)
    al = f[..., 3] > 0
    lum, sat = rgb.mean(-1), rgb.max(-1) - rgb.min(-1)
    core = al & (lum > lmin) & (sat < 90) & ~body
    for lo, hi, c in ((200, 235, ramp[4]), (165, 200, ramp[3]), (0, 165, ramp[2])):
        f[core & (lum >= lo) & (lum < hi)] = hexa(c)
    r1 = ~al & grow(grow(core) & al)
    r2 = ~al & grow(r1) & ~r1
    f[r1], f[r2] = hexa(ramp[3]), hexa(ramp[2])
    return f


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


def big(rec, anim, spec, sheet, sizes):
    """animación en lienzo grande: {"hoja": k, "cuadros": [...], "alinear": n (el cuadro de la hoja que se
    parece al quieto) o "torso" (cada uno por su cuenta), "estelas": [[cuadro, [vecinos], "r" o "y", lmin], ...]}
    (los números son cuadros de la hoja)"""
    sh = spec["hoja"]
    sheet(sh)
    get = lambda i: cell(sheet(sh), 0, i, *sizes[sh])
    ref = np.array(Image.open(os.path.join(rec["out"], "idle", "frame_000.png")).convert('RGBA'))
    if spec["alinear"] == "torso":  # en el aire: cada cuadro con la cabeza y el torso donde están en el quieto
        off = [align(get(i), ref, (8, 34)) for i in spec["cuadros"]]
    else:
        off = align(get(spec["alinear"]), ref)
    frames, pad = wide([get(i) for i in spec["cuadros"]], off)
    for i, nb, rp, lmin in spec.get("estelas", []):
        j = spec["cuadros"].index(i)
        others, _ = wide([get(n) for n in nb], off, pad)
        frames[j] = tint_smear(frames[j], others, RAMPS[rp], lmin)
    d = os.path.join(rec["out"], anim)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    for j, f in enumerate(frames):
        Image.fromarray(f).save(os.path.join(d, "frame_%03d.png" % j))
    print(anim, len(frames), "lienzo", frames[0].shape[1], "x", frames[0].shape[0], "quieto en", off)


def main():
    args = sys.argv[1:]
    hdir = None
    if "--hojas" in args:  # las hojas pueden estar en otra carpeta que la receta
        k = args.index("--hojas")
        hdir = args[k + 1]
        del args[k:k + 2]
    rec = json.load(open(args[0]))
    only = set(args[1:])  # se pueden pasar solo algunas animaciones
    base = hdir or os.path.dirname(os.path.abspath(args[0]))
    sheets, sizes = {}, {}

    def sheet(k):
        if k not in sheets:
            v = rec["hojas"][k]
            v = [v, CELL, CELL] if isinstance(v, str) else v
            sheets[k] = np.array(Image.open(os.path.join(base, v[0])).convert('RGBA'))
            sizes[k] = (v[1], v[2], v[3] if len(v) > 3 else None)
        return sheets[k]

    fire = set(rec.get("verde_a_fuego", []))
    for anim, spec in rec["anims"].items():
        if only and anim not in only:
            continue
        if isinstance(spec, dict):
            big(rec, anim, spec, sheet, sizes)
            continue
        sh, row, idx = spec[:3]
        frames = [cell(sheet(sh), row, i, *sizes[sh]) for i in idx]
        dy = 0
        if len(spec) > 3:
            rs, rr, ri = spec[3]
            ref = cell(sheet(rs), rr, ri, *sizes[rs])
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
