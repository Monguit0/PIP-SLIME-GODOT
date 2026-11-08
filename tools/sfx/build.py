# Arma los .wav nuevos con la misma sonoridad que los viejos y un carrete "antes / después".
import sys, os, wave
import numpy as np
import synth
from synth import SR, hp1, fade_tail, trim, pad
import sounds

OLD = sys.argv[1]   # carpeta con los wav originales
OUT = sys.argv[2]   # carpeta de salida
os.makedirs(OUT, exist_ok=True)
only = sys.argv[3:]


def rd(p):
    w = wave.open(p)
    return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768


def wr(p, x):
    x = np.clip(x, -1, 1)
    w = wave.open(p, 'wb')
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes((x * 32767).astype(np.int16).tobytes())
    w.close()


def loud(x):
    k = hp1(x, 90) + 0.6 * hp1(x, 2000)
    win = int(0.05 * SR)
    if len(k) <= win:
        return np.sqrt(np.mean(k ** 2))
    c = np.cumsum(np.concatenate([[0], k ** 2]))
    return np.sqrt((c[win:] - c[:-win]).max() / win)


report = []
for name in (only or sounds.ALL):
    synth.rng = np.random.default_rng(sum(ord(c) * 31 ** i for i, c in enumerate(name)) % (2 ** 32))
    sounds.rng = synth.rng
    x = getattr(sounds, name)()
    x = x - np.mean(x[:64]) * 0  # sin DC: el hp del final lo saca
    x = hp1(x, 25)
    x = trim(x, 2e-4)
    x = fade_tail(x, 10)
    REF = {'paso': ('aterrizar', 0.7)}  # sonidos nuevos: tan fuertes como uno viejo parecido
    ref, k = REF.get(name, (name, 1.0))
    old = rd(os.path.join(OLD, ref + '.wav'))
    g = loud(old) * k / max(loud(x), 1e-9)
    y = x * g
    pk = np.abs(y).max()
    if pk > 0.97:
        y = np.tanh(y / pk * 1.4) / np.tanh(1.4) * 0.97
    wr(os.path.join(OUT, name + '.wav'), y)
    report.append((name, round(len(old) / SR, 2), round(len(y) / SR, 2), round(20 * np.log10(g), 1), round(np.abs(y).max(), 2)))
for r in report:
    print(*r)
