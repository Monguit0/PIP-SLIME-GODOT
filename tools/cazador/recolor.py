# Pip Cazador: la capa y la capucha pasan de carmesí a verde de bosque y la armadura gana bordes dorados.
import sys, os, glob
import numpy as np
from PIL import Image

MAP = {
    # capa y capucha
    '#240000': '#002400', '#490000': '#002424', '#490024': '#002424', '#6d0024': '#004924',
    '#6d2424': '#244924', '#920024': '#006d24', '#922424': '#246d49', '#922449': '#246d49',
    '#924949': '#49926d', '#b60024': '#249249', '#b62449': '#249249', '#b64949': '#49b66d',
    '#db4949': '#6db66d', '#b66d6d': '#6db66d', '#db6d6d': '#92db6d',
    '#240024': '#002424', '#b60049': '#249249',
    # armadura de cuero de cazador: los bordes azulados pasan a oliva y los brillos a dorado viejo
    '#496d6d': '#6d6d49', '#6d9292': '#929249', '#244949': '#244924',
}


def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def recolor(a):
    o = a.copy()
    for src, dst in MAP.items():
        s = hx(src)
        m = (a[:, :, 0] == s[0]) & (a[:, :, 1] == s[1]) & (a[:, :, 2] == s[2]) & (a[:, :, 3] > 0)
        o[m, :3] = hx(dst)
    return o


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    n = 0
    for f in glob.glob(os.path.join(src, '**', '*.png'), recursive=True):
        rel = os.path.relpath(f, src)
        out = os.path.join(dst, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        Image.fromarray(recolor(np.array(Image.open(f).convert('RGBA')))).save(out)
        n += 1
    print(n, 'cuadros')
