# Música del Bosque Oscuro: variaciones "místicas" del tema principal del juego (el loop de 8 compases
# Am-F-C-G del original). Mismo motivo, otra armonía, otros instrumentos (campanas FM, flauta, arpa,
# colchón) y eco + reverb en vez del grano de la Mega Drive.
# Uso: python3 bosque.py <carpeta de salida> [a b c | b0 b1 b2]   (escribe .wav; pasarlos a OGG con ffmpeg)
# a, b y c son las tres propuestas; se eligió la c ("Hongos que brillan"), que el juego usa como b0, b1 y b2
# (assets/audio/music), una por zona y cada una un poco más rápida.
import sys, os, wave
import numpy as np
from scipy.signal import fftconvolve, lfilter, butter

SR = 44100
TAU = 2 * np.pi
NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
rng = np.random.default_rng(7)


def midi(n):
    acc = 1 if '#' in n else 0
    return 12 * (int(n[-1]) + 1) + NOTE[n[0]] + acc


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, a, dec, sus, hold, rel):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), sus + (1 - sus) * np.exp(-(t - a) / dec))
    r = np.exp(-np.maximum(0.0, t - hold) / rel)
    return e * r


def fm(f, dur, r=1.0, i0=2.0, i1=0.5, idec=0.1, a=0.005, dec=0.2, sus=0.6, rel=0.08, vib=0.0, det=0.0, tail=0.5):
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    idx = i1 + (i0 - i1) * np.exp(-t / idec)
    ph = TAU * f * t
    if vib:
        ph = ph + vib * np.sin(TAU * 5.4 * t) * np.clip((t - 0.15) / 0.3, 0, 1)
    mod = idx * np.sin(TAU * f * r * t)
    y = np.sin(ph + mod)
    if det:
        y = 0.5 * (y + np.sin(ph * 2 ** (det / 1200) + mod))
    return y * env_adsr(n, a, dec, sus, dur, rel)


def bell(f, dur=0.3, bright=1.0):
    # campanita/celesta: modulador inarmónico que se apaga rápido, cola larga
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    y = np.sin(TAU * f * t + 2.2 * bright * np.exp(-t / 0.12) * np.sin(TAU * f * 3.5 * t))
    y += 0.35 * np.sin(TAU * f * 2.0 * t + 0.8 * np.exp(-t / 0.05) * np.sin(TAU * f * 7.0 * t)) * np.exp(-t / 0.25)
    return y * np.exp(-t / 0.55) * np.minimum(1, t / 0.002)


def harp(f, dur=0.3):
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    y = np.sin(TAU * f * t + 3.0 * np.exp(-t / 0.035) * np.sin(TAU * f * t))
    y += 0.3 * np.sin(TAU * 2 * f * t) * np.exp(-t / 0.2)
    return y * np.exp(-t / (0.45 if f < 300 else 0.32)) * np.minimum(1, t / 0.003)


def flute(f, dur):
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    vib = 0.006 * np.sin(TAU * 5.2 * t) * np.clip((t - 0.2) / 0.35, 0, 1)
    ph = TAU * f * np.cumsum(1 + vib) / SR
    y = np.sin(ph) + 0.28 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
    b, a = butter(2, [min(0.9, f * 1.5 / (SR / 2)), min(0.95, f * 4 / (SR / 2))], 'band')
    breath = lfilter(b, a, rng.standard_normal(n)) * 0.5
    e = env_adsr(n, 0.05, 0.3, 0.8, dur, 0.09)
    return (y + breath * (0.5 + 0.5 * np.exp(-t / 0.08))) * e


def pad(notes, dur):
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for m in notes:
        f = hz(m)
        for d in (-7, 0, 8):
            ff = f * 2 ** (d / 1200)
            y += np.sin(TAU * ff * t + 0.6 * np.sin(TAU * ff * t)) + 0.3 * np.sin(TAU * 2 * ff * t + rng.random() * TAU)
    e = np.minimum(1, t / 0.9) * np.exp(-np.maximum(0, t - dur) / 0.6)
    return y / (3 * len(notes)) * e * (1 + 0.12 * np.sin(TAU * 0.3 * t))


def softbass(f, dur):
    return fm(f, dur, r=1, i0=2.2, i1=0.5, idec=0.08, a=0.008, dec=0.25, sus=0.6, rel=0.08, tail=0.4) + 0.4 * fm(f * 2, dur, r=1, i0=0.8, i1=0.1, idec=0.05, a=0.01, dec=0.15, sus=0.3, rel=0.05, tail=0.4)


def kick(soft=True):
    t = np.arange(int(0.35 * SR)) / SR
    return np.sin(TAU * (48 * t + 60 * (1 - np.exp(-t * 28)) / 28)) * np.exp(-t * (9 if soft else 7))


def tom(f):
    t = np.arange(int(0.4 * SR)) / SR
    return np.sin(TAU * (f * t + f * 0.6 * (1 - np.exp(-t * 20)) / 20)) * np.exp(-t * 9)


def shaker(length=0.06):
    n = int(length * SR)
    t = np.arange(n) / SR
    b, a = butter(2, 0.35, 'high')
    return lfilter(b, a, rng.standard_normal(n)) * np.exp(-t / (length * 0.35))


def rim():
    t = np.arange(int(0.12 * SR)) / SR
    return (np.sin(TAU * 820 * t) * np.exp(-t * 45) + 0.4 * rng.standard_normal(len(t)) * np.exp(-t * 80))


class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.dry = np.zeros((self.n + SR * 6, 2))
        self.wet = np.zeros((self.n + SR * 6, 2))
        self.ech = np.zeros((self.n + SR * 6, 2))

    def add(self, t, sig, gain=1.0, pan=0.0, rev=0.2, echo=0.0):
        i = int(t * SR)
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        st = np.stack([sig * l, sig * r], 1) * gain
        self.dry[i:i + len(sig)] += st
        if rev:
            self.wet[i:i + len(sig)] += st * rev
        if echo:
            self.ech[i:i + len(sig)] += st * echo

    def render(self, echo_t, rev_t=2.6, rev_gain=1.0):
        out = self.dry.copy()
        # eco con rebote de un lado al otro
        d = int(echo_t * SR)
        e = self.ech.copy()
        for k in range(1, 5):
            g = 0.5 ** k
            sh = np.zeros_like(e)
            sh[d * k:] = e[:-d * k] if d * k < len(e) else 0
            if k % 2 == 1:
                sh = sh[:, ::-1]
            out += sh * g
            self.wet += sh * g * 0.5
        # reverb: ruido que se apaga, distinto en cada oído
        m = int(rev_t * SR)
        t = np.arange(m) / SR
        b, a = butter(2, 0.3, 'low')
        for c in range(2):
            ir = lfilter(b, a, rng.standard_normal(m)) * np.exp(-t / (rev_t / 5.5)) * np.minimum(1, t / 0.012)
            ir /= np.sqrt(np.sum(ir ** 2))
            out[:, c] += fftconvolve(self.wet[:, c], ir)[:len(out)] * 0.55 * rev_gain
        # la cola da la vuelta: así el loop empalma
        loop = out[:self.n].copy()
        tail = out[self.n:]
        k = min(len(tail), self.n)
        loop[:k] += tail[:k]
        b, a = butter(1, 30 / (SR / 2), 'high')
        loop = lfilter(b, a, loop, axis=0)
        loop = np.tanh(loop / np.max(np.abs(loop)) * 1.25) * 0.89
        return loop


def parse(bars, per_bar):
    """'E5 - - C5 .' por compás -> [(paso, midi, largo en pasos)]"""
    out = []
    for bi, bar in enumerate(bars):
        last = None
        for i, tk in enumerate(bar.split()):
            if tk == '-':
                if last:
                    last[2] += 1
            elif tk == '.':
                last = None
            else:
                last = [bi * per_bar + i, midi(tk), 1]
                out.append(last)
    return out


# ---------------------------------------------------------------------------------------------
# A · "Claro del bosque": lenta y dórica (Am - D - C - G): campanas, arpa y colchón, casi sin batería
def version_a():
    bpm, per = 92, 8                      # 8 corcheas por compás
    step = 60 / bpm / 2
    lead = parse(['E5 - - C5 A4 - C5 E5', 'F#5 - E5 - D5 - A4 -', 'G4 - C5 - E5 - G5 -', 'F#5 E5 D5 - B4 - G4 -',
                  'E5 - - C5 A4 - C5 E5', 'A5 - G5 - F#5 - E5 D5', 'E5 - D5 C5 G4 - C5 -', 'D5 - B4 G4 B4 - D5 -'], per)
    chords = [('A2', ['A3', 'E4', 'A4', 'C5', 'E5']), ('D3', ['D4', 'A4', 'D5', 'F#5', 'A5']),
              ('C3', ['C4', 'G4', 'C5', 'E5', 'G5']), ('G2', ['G3', 'D4', 'G4', 'B4', 'D5'])]
    bars = 16
    mx = Mix(bars * per * step)
    for rep in range(2):
        t0 = rep * 8 * per * step
        for s, m, ln in lead:
            t = t0 + s * step
            mx.add(t, bell(hz(m)), 0.30, 0.1, rev=0.45, echo=0.35)
            if rep == 1:   # segunda vuelta: la flauta dobla la melodía una octava abajo
                mx.add(t, flute(hz(m - 12), ln * step * 0.95), 0.16, -0.3, rev=0.5)
    for b in range(bars):
        t0 = b * per * step
        bass, arp = chords[b % 4]
        mx.add(t0, pad([midi(n) for n in arp[:4]], per * step), 0.5, 0.0, rev=0.6)
        mx.add(t0, softbass(hz(midi(bass)), per * step * 0.9), 0.34, 0.0, rev=0.1)
        # el arpa sube y baja en semicorcheas
        seq = [0, 1, 2, 3, 4, 3, 2, 1] * 2
        for i, k in enumerate(seq):
            mx.add(t0 + i * step / 2, harp(hz(midi(arp[k]))), 0.10 + 0.03 * (i % 4 == 0), 0.5 - 0.1 * k, rev=0.4, echo=0.15)
        # un tambor grave y lejano, y una semillita
        mx.add(t0, kick(), 0.32, 0, rev=0.3)
        if b % 2 == 1:
            mx.add(t0 + 5 * step, tom(90), 0.2, -0.2, rev=0.4)
        for i in (2, 6):
            mx.add(t0 + i * step, shaker(0.09), 0.035, 0.4, rev=0.3)
        # brillitos: campanitas agudas sueltas
        if b % 4 == 3:
            for i, n in enumerate(['E6', 'A6', 'B6', 'E7']):
                mx.add(t0 + (4 + i) * step, bell(hz(midi(n)), bright=0.6), 0.07, -0.5 + 0.3 * i, rev=0.7, echo=0.4)
    return mx.render(step * 3)


# B · "Vals de las luciérnagas": el motivo en 3/4, menor armónica (Am - F - C - E): flauta y pizzicato
def version_b():
    bpm, per = 152, 6                     # negras a 152; 6 corcheas por compás
    step = 60 / bpm / 2
    lead = parse(['E5 - C5 A4 C5 E5', 'F5 - E5 C5 A4 -', 'G4 C5 E5 - G5 -', 'E5 D5 B4 - G#4 -',
                  'E5 - C5 A4 C5 E5', 'A5 - G5 F5 E5 C5', 'D5 - F5 E5 D5 A4', 'B4 - G#4 B4 E5 -'], per)
    chords = [('A2', ['A3', 'C4', 'E4']), ('F2', ['A3', 'C4', 'F4']), ('C3', ['G3', 'C4', 'E4']), ('E2', ['G#3', 'B3', 'E4']),
              ('A2', ['A3', 'C4', 'E4']), ('F2', ['A3', 'C4', 'F4']), ('D3', ['A3', 'D4', 'F4']), ('E2', ['G#3', 'B3', 'E4'])]
    bars = 16
    mx = Mix(bars * per * step)
    for rep in range(2):
        t0 = rep * 8 * per * step
        for s, m, ln in lead:
            t = t0 + s * step
            mx.add(t, flute(hz(m), ln * step * 0.92), 0.30, 0.15, rev=0.45, echo=0.2)
            if rep == 1:   # segunda vuelta: las campanas contestan arriba
                mx.add(t, bell(hz(m + 12), bright=0.7), 0.10, -0.4, rev=0.6, echo=0.3)
    for b in range(bars):
        t0 = b * per * step
        bass, tri = chords[b % 8]
        mx.add(t0, pad([midi(n) for n in tri], per * step), 0.42, 0.0, rev=0.6)
        # un-pa-pa: bajo pulsado en el uno, acorde de arpa en el dos y el tres
        mx.add(t0, harp(hz(midi(bass))), 0.42, 0.0, rev=0.2)
        mx.add(t0, softbass(hz(midi(bass)), step * 1.6), 0.2, 0.0, rev=0.1)
        for beat in (2, 4):
            for j, n in enumerate(tri):
                mx.add(t0 + beat * step + j * 0.012, harp(hz(midi(n) + 12)), 0.085, -0.35 + 0.35 * j, rev=0.4)
        mx.add(t0, kick(), 0.22, 0, rev=0.3)
        for beat in (2, 4):
            mx.add(t0 + beat * step, shaker(0.05), 0.04, 0.45, rev=0.3)
        if b % 4 == 3:    # una escalera de campanas para dar la vuelta
            for i, n in enumerate(['E5', 'G#5', 'B5', 'E6', 'G#6', 'B6']):
                mx.add(t0 + i * step, bell(hz(midi(n)), bright=0.6), 0.07, -0.6 + 0.24 * i, rev=0.7, echo=0.3)
    return mx.render(step * 2)


# C · "Hongos que brillan": conserva el pulso del juego (para pelear), pero misteriosa: Am - F - Dm - E
def version_c(bpm=124):
    per = 8
    step = 60 / bpm / 2
    lead = parse(['E5 - - C5 A4 - C5 E5', 'F5 - E5 - C5 - A4 -', 'A4 - D5 - F5 - A5 -', 'G#5 F5 E5 - B4 - G#4 -',
                  'E5 - - C5 A4 - C5 E5', 'A5 - G5 - F5 - E5 C5', 'F5 - E5 D5 A4 - D5 -', 'E5 - B4 G#4 B4 - E5 -'], per)
    chords = [('A2', ['A3', 'C4', 'E4', 'A4']), ('F2', ['F3', 'A3', 'C4', 'F4']), ('D3', ['F3', 'A3', 'D4', 'F4']), ('E2', ['E3', 'G#3', 'B3', 'E4'])]
    bass_pat = [(0, 0, 1.7, 1), (3, 0, 0.7, 0.6), (4, 12, 0.8, 0.8), (6, 0, 1.4, 0.85), (8, 0, 1.7, 1), (10, 12, 0.7, 0.75), (11, 7, 0.7, 0.65), (14, 12, 1.4, 0.8)]
    bars = 16
    s16 = step / 2
    mx = Mix(bars * per * step)
    for rep in range(2):
        t0 = rep * 8 * per * step
        for s, m, ln in lead:
            t = t0 + s * step
            d = ln * step * 0.92
            # la voz FM del original, más redonda, con una campana encima
            mx.add(t, fm(hz(m), d, r=1, i0=2.4, i1=1.0, idec=0.09, a=0.006, dec=0.22, sus=0.7, rel=0.06, vib=0.05, det=8), 0.20, 0.1, rev=0.3, echo=0.3)
            mx.add(t, bell(hz(m + 12), bright=0.8), 0.08, -0.2, rev=0.5, echo=0.25)
            if rep == 1 and ln >= 2:  # segunda vuelta: una tercera/cuarta abajo en flauta
                mx.add(t, flute(hz(m - 5 if (m - 5) % 12 in (0, 2, 4, 5, 8, 9, 11) else m - 4), d), 0.11, -0.45, rev=0.5)
    for b in range(bars):
        t0 = b * per * step
        bass, arp = chords[b % 4]
        mx.add(t0, pad([midi(n) for n in arp[:3]], per * step), 0.36, 0.0, rev=0.6)
        for ps, semi, ln, v in bass_pat:
            mx.add(t0 + ps * s16, softbass(hz(midi(bass) + semi), ln * s16), 0.30 * v, 0.0, rev=0.08)
        for i in range(16):   # arpegio de arpa en semicorcheas, con eco
            mx.add(t0 + i * s16, harp(hz(midi(arp[i % 4]) + 12)), 0.065, 0.5, rev=0.3, echo=0.25)
        for i in range(16):
            if i in (0, 8) or (i == 10 and b % 2 == 1):
                mx.add(t0 + i * s16, kick(False), 0.42, 0, rev=0.1)
            if i in (4, 12):
                mx.add(t0 + i * s16, rim(), 0.16, -0.1, rev=0.4)
            if i % 2 == 0:
                mx.add(t0 + i * s16, shaker(0.05 if i % 4 else 0.035), 0.05, 0.35, rev=0.2)
        if b % 4 == 3:
            for i, f in enumerate((150, 120, 95)):
                mx.add(t0 + (13 + i) * s16, tom(f), 0.26, -0.4 + 0.4 * i, rev=0.35)
        if b % 8 == 0:
            for i, n in enumerate(['A6', 'E6', 'C6', 'A5']):
                mx.add(t0 + i * s16 * 3, bell(hz(midi(n)), bright=0.6), 0.06, 0.6 - 0.4 * i, rev=0.7, echo=0.4)
    return mx.render(step * 1.5, rev_gain=0.8)


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    which = sys.argv[2:] or ['a', 'b', 'c']
    # la del juego: "c" a tres tempos, una por zona (b0, b1, b2)
    table = {'a': version_a, 'b': version_b, 'c': version_c,
             'b0': lambda: version_c(124), 'b1': lambda: version_c(128), 'b2': lambda: version_c(132)}
    for v in which:
        y = table[v]()
        w = wave.open(os.path.join(out, ('bosque_%s.wav' if len(v) == 1 else '%s.wav') % v), 'wb')
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(y, -1, 1) * 32767).astype('<i2').tobytes())
        w.close()
        print(v, round(len(y) / SR, 1), 's')
