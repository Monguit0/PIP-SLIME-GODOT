# Arma el arte del nivel 2 (el Bosque Oscuro) en assets/level2 a partir de las piezas de PixelLab de
# piezas/ (Create Image Pro, 256x144, todas con el estilo de "encantado"):
#   mid.png    el bosque, una pieza por zona (el parallax es 0.5: cada zona recorre justo una pieza)
#   arena.png  la guarida del Campeón (zona del jefe)
#   sky.png    el color de la copa de los árboles (se ve si la cámara se aleja) y far.png, vacío
#   level.png  el piso y las plataformas, dibujados acá: tierra oscura con musgo y hongos que brillan,
#              y troncos con musgo para las plataformas
# Uso: python3 build.py   (escribe en ../../assets/level2)
import os, random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', '..', 'assets', 'level2')
PLATS = [
    [48, 92, 56], [128, 68, 40], [196, 96, 48], [268, 72, 56], [352, 52, 40], [420, 90, 56],
    [548, 84, 48], [620, 60, 40], [684, 92, 56], [760, 66, 48], [836, 44, 40], [904, 80, 56], [968, 56, 32],
    [1056, 90, 48], [1124, 64, 40], [1192, 96, 56], [1268, 70, 48], [1340, 48, 40], [1404, 84, 56], [1468, 62, 36],
    [1556, 92, 32], [1640, 62, 48], [1744, 92, 32],
]
WW, GROUND = 1792, 128
EARTH = [(18, 16, 38), (24, 21, 48), (14, 12, 30)]
MOSS = [(38, 106, 96), (23, 77, 77), (60, 150, 120)]
BARK = [(58, 32, 59), (38, 21, 45), (76, 48, 70)]
GLOW = [(32, 239, 233), (150, 255, 250), (16, 139, 137)]
K = (5, 3, 12)


def piece(n):
    return Image.open(os.path.join(HERE, 'piezas', n + '.png')).convert('RGB').resize((512, 288), Image.NEAREST)


def build_mid():
    a, b, c = piece('encantado'), piece('tronco'), piece('estanque')
    m = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    seq = [a, b, c, m(a), m(b)]
    # las piezas se pisan 48 px y ahí se funden una con otra, para que no se vea el corte
    lap, step = 48, 512 - 48
    out = Image.new('RGB', (step * len(seq) + lap, 288))
    for i, im in enumerate(seq):
        mask = Image.new('L', (512, 288), 255)
        if i > 0:
            for x in range(lap):
                mask.paste(int(255 * (x + 0.5) / lap), (x, 0, x + 1, 288))
        out.paste(im, (i * step, 0), mask)
    out.save(os.path.join(OUT, 'mid.png'))
    top = a.resize((1, 1), Image.BILINEAR, box=(0, 0, 512, 40)).getpixel((0, 0))
    sky = Image.new('RGB', (512, 288), tuple(int(v * 0.7) for v in top))
    sky.save(os.path.join(OUT, 'sky.png'))
    Image.new('RGBA', (1280, 288), (0, 0, 0, 0)).save(os.path.join(OUT, 'far.png'))
    piece('guarida').save(os.path.join(OUT, 'arena.png'))


def mushroom(d, x, y, big, rng):
    """hongo que brilla, con el pie apoyado en (x, y)"""
    h = rng.choice([5, 6, 8]) if big else rng.choice([3, 4])
    w = 7 if big else 5
    d.rectangle((x, y - h, x + 1, y), fill=GLOW[2])
    d.rectangle((x - w // 2, y - h - 2, x + w // 2 + 1, y - h), fill=GLOW[0])
    d.rectangle((x - w // 2 + 1, y - h - 3, x + w // 2, y - h - 2), fill=GLOW[0])
    d.point((x - w // 2 + 1, y - h - 2), fill=GLOW[1])
    d.point((x, y - h - 3), fill=GLOW[1])


def build_level():
    rng = random.Random(7)
    im = Image.new('RGBA', (WW * 2, 288), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    gy = GROUND * 2
    # el piso: tierra oscura con piedritas y raíces, y arriba una alfombra de musgo despareja
    d.rectangle((0, gy, WW * 2, 288), fill=EARTH[0])
    for _ in range(2600):
        x, y = rng.randrange(WW * 2), rng.randrange(gy + 6, 288)
        d.rectangle((x, y, x + rng.choice([1, 1, 2, 3]), y + rng.choice([0, 1])), fill=rng.choice(EARTH[1:]))
    for _ in range(160):  # raíces que asoman
        x, y = rng.randrange(WW * 2), rng.randrange(gy + 8, 284)
        for i in range(rng.randrange(6, 16)):
            d.point((x + i, y + (i // 4) * rng.choice([0, 1])), fill=BARK[0])
    x = 0
    while x < WW * 2:
        w = rng.randrange(4, 12)
        h = rng.choice([3, 4, 4, 5, 6])
        d.rectangle((x, gy, x + w, gy + h), fill=MOSS[1])
        d.rectangle((x, gy, x + w, gy + 1), fill=MOSS[0])
        if rng.random() < 0.35:
            d.point((x + rng.randrange(w), gy), fill=MOSS[2])
        if rng.random() < 0.25:  # pastito
            bx = x + rng.randrange(w)
            d.line((bx, gy - 1, bx, gy - rng.choice([2, 3, 4])), fill=MOSS[0])
        x += w
    d.line((0, gy + 6, WW * 2, gy + 6), fill=K)
    # las plataformas: troncos con musgo arriba, corteza con vetas y lianitas colgando
    for px, py, pw in PLATS:
        x0, y0, x1, y1 = px * 2, py * 2, (px + pw) * 2 - 1, py * 2 + 15
        d.rectangle((x0 + 2, y0, x1 - 2, y1), fill=K)
        d.rectangle((x0, y0 + 2, x1, y1 - 2), fill=K)
        d.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=BARK[0])
        d.rectangle((x0 + 2, y1 - 6, x1 - 2, y1 - 2), fill=BARK[1])
        for _ in range(pw // 3):
            vx = rng.randrange(x0 + 4, x1 - 6)
            d.line((vx, y0 + 7, vx + rng.randrange(3, 8), y0 + 7 + rng.choice([0, 1])), fill=BARK[2])
        # anillos del tronco en las puntas
        for ex in (x0 + 2, x1 - 5):
            d.rectangle((ex, y0 + 5, ex + 3, y1 - 4), fill=BARK[2])
            d.rectangle((ex + 1, y0 + 7, ex + 2, y1 - 6), fill=BARK[1])
        # musgo arriba, chorreando un poco
        xx = x0 + 1
        while xx < x1 - 1:
            w = min(rng.randrange(3, 9), x1 - 1 - xx)
            h = rng.choice([3, 4, 5])
            d.rectangle((xx, y0, xx + w, y0 + h), fill=MOSS[1])
            d.rectangle((xx, y0, xx + w, y0 + 1), fill=MOSS[0])
            if rng.random() < 0.3:
                d.point((xx + rng.randrange(max(1, w)), y0), fill=MOSS[2])
            xx += w + 1
        for _ in range(pw // 12):  # lianas
            vx = rng.randrange(x0 + 6, x1 - 6)
            ln = rng.randrange(5, 14)
            d.line((vx, y1, vx, y1 + ln), fill=MOSS[1])
            d.point((vx, y1 + ln), fill=MOSS[0])
        if rng.random() < 0.6:
            mushroom(d, rng.randrange(x0 + 8, x1 - 8), y0 - 1, False, rng)
    # hongos que brillan a lo largo del piso (no en los portones)
    x = 30
    while x < WW * 2 - 30:
        if all(abs(x - g * 2) > 40 for g in (512, 1024, 1536)):
            mushroom(d, x, gy - 1, rng.random() < 0.3, rng)
            if rng.random() < 0.5:
                mushroom(d, x + rng.choice([-7, 8]), gy - 1, False, rng)
        x += rng.randrange(60, 170)
    im.save(os.path.join(OUT, 'level.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    build_mid()
    build_level()
    print('listo:', os.path.abspath(OUT))
