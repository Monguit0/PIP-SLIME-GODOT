# Bloques de síntesis para los efectos de sonido (numpy, sin scipy).
import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def T(d):
    return np.arange(int(round(d * SR))) / SR


def n_(d):
    return int(round(d * SR))


def pad(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(total, *parts):
    """parts: (señal, inicio_seg, ganancia)"""
    out = np.zeros(n_(total))
    for x, t0, g in parts:
        i = n_(t0)
        if i >= len(out):
            continue
        m = min(len(x), len(out) - i)
        out[i:i + m] += x[:m] * g
    return out


# ---------------------------------------------------------------- envolventes y curvas
def exp_env(d, tau, attack=0.002):
    t = T(d)
    e = np.exp(-t / tau)
    if attack > 0:
        a = np.clip(t / attack, 0, 1)
        e *= a * a * (3 - 2 * a)
    return e


def ad(d, attack, hold, release, curve=2.0):
    t = T(d)
    e = np.where(t < attack, t / max(attack, 1e-6), 1.0)
    r = np.clip((t - attack - hold) / max(release, 1e-6), 0, 1)
    return e * (1 - r) ** curve


def bell_env(d, peak, curve=2.0):
    """sube hasta peak (seg) y baja hasta el final, como un swoosh"""
    t = T(d)
    up = np.clip(t / peak, 0, 1) ** 1.5
    dn = np.clip(1 - (t - peak) / max(d - peak, 1e-6), 0, 1) ** curve
    return np.where(t < peak, up, dn)


def sweep(f0, f1, d, n=None, kind='exp'):
    t = T(d) if n is None else np.arange(n) / SR
    k = np.clip(t / d, 0, 1)
    if kind == 'exp':
        return f0 * (f1 / f0) ** k
    return f0 + (f1 - f0) * k


def glide(points, d):
    """curva por tramos: [(t, valor), ...] interpolada en log"""
    t = T(d)
    ts = np.array([p[0] for p in points])
    vs = np.log(np.array([p[1] for p in points]))
    return np.exp(np.interp(t, ts, vs))


# ---------------------------------------------------------------- osciladores
def phase(f, ph0=0.0):
    f = np.asarray(f, dtype=float)
    return (ph0 + np.cumsum(f) / SR)


def _blep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = x + x - x * x - 1
    m2 = t > 1 - dt
    x = (t[m2] - 1) / dt[m2]
    y[m2] = x * x + x + x + 1
    return y


def osc(f, kind='sine', duty=0.5, ph0=0.0):
    f = np.asarray(f, dtype=float)
    ph = phase(f, ph0)
    p = ph % 1.0
    dt = np.clip(np.abs(f) / SR, 1e-6, 0.5)
    if kind == 'sine':
        return np.sin(2 * np.pi * ph)
    if kind == 'tri':
        return 2 * np.abs(2 * p - 1) - 1
    if kind == 'saw':
        return (2 * p - 1) - _blep(p, dt)
    if kind == 'square':
        s = np.where(p < duty, 1.0, -1.0)
        s += _blep(p, dt)
        s -= _blep((p - duty) % 1.0, dt)
        return s
    raise ValueError(kind)


def fm(fc, ratio, index, ph0=0.0):
    """FM de dos operadores: index puede ser una envolvente"""
    fc = np.asarray(fc, dtype=float)
    mod = np.sin(2 * np.pi * phase(fc * ratio))
    return np.sin(2 * np.pi * phase(fc, ph0) + np.asarray(index) * mod)


def noise(d):
    return rng.uniform(-1, 1, n_(d))


def modal(d, freqs, taus, amps, detune=0.0):
    """suma de parciales que se apagan (metal, madera, hueso)"""
    t = T(d)
    out = np.zeros_like(t)
    for f, tau, a in zip(freqs, taus, amps):
        ph = rng.uniform(0, 2 * np.pi)
        out += a * np.exp(-t / tau) * np.sin(2 * np.pi * f * t + ph)
        if detune:
            out += a * 0.6 * np.exp(-t / tau) * np.sin(2 * np.pi * f * (1 + detune) * t + ph * 1.3)
    return out


def karplus(f, d, damp=0.996, bright=0.5):
    n = n_(d)
    period = max(2, int(round(SR / f)))
    buf = rng.uniform(-1, 1, period)
    # el pulso inicial más oscuro = cuerda menos chillona
    for _ in range(int((1 - bright) * 4)):
        buf = 0.5 * (buf + np.roll(buf, 1))
    out = np.zeros(n)
    idx = 0
    prev = 0.0
    for i in range(n):
        v = buf[idx]
        out[i] = v
        nv = damp * (0.5 * (v + buf[(idx + 1) % period]))
        buf[idx] = nv
        idx = (idx + 1) % period
    return out


# ---------------------------------------------------------------- filtros
def svf(x, fc, q=0.707, mode='lp'):
    """filtro de estado variable (TPT), fc puede variar en el tiempo"""
    x = np.asarray(x, dtype=float)
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, dtype=float), (n,))
    g = np.tan(np.pi * np.clip(fc, 10, SR * 0.45) / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    ic1 = ic2 = 0.0
    out = np.empty(n)
    lp = mode == 'lp'
    bp = mode == 'bp'
    hp = mode == 'hp'
    for i in range(n):
        v0 = x[i]
        v3 = v0 - ic2
        v1 = a1[i] * ic1 + a2[i] * v3
        v2 = ic2 + a2[i] * ic1 + a3[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        if lp:
            out[i] = v2
        elif bp:
            out[i] = v1
        elif hp:
            out[i] = v0 - k * v1 - v2
        else:  # notch / peak no hacen falta
            out[i] = v1 * k  # bp normalizado
    return out


def lp1(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    out = np.empty(len(x))
    y = 0.0
    for i in range(len(x)):
        y = (1 - a) * x[i] + a * y
        out[i] = y
    return out


def hp1(x, fc):
    return x - lp1(x, fc)


def crush(x, rate=16000, bits=None):
    """baja la frecuencia de muestreo (mantiene muestras): un poco de granito de 16 bits"""
    step = SR / rate
    idx = (np.floor(np.arange(len(x)) / step) * step).astype(int)
    y = x[np.clip(idx, 0, len(x) - 1)]
    if bits:
        q = 2 ** (bits - 1)
        y = np.round(y * q) / q
    return y


def drive(x, k=2.0):
    return np.tanh(k * x) / np.tanh(k)


def echo(x, delay=0.09, fb=0.3, mix_=0.3, tone=3500, tail=None):
    """eco tipo SNES: retardo con realimentación y un pasabajos en el lazo"""
    d = n_(delay)
    n = len(x) + (n_(tail) if tail is not None else d * 4)
    src = pad(x, n)
    out = src.copy()
    wet = np.zeros(n)
    a = np.exp(-2 * np.pi * tone / SR)
    y = 0.0
    for i in range(d, n):
        v = src[i - d] + fb * wet[i - d]
        y = (1 - a) * v + a * y
        wet[i] = y
    return out + wet * mix_


def fade_tail(x, ms=8):
    m = min(len(x), n_(ms / 1000))
    x = x.copy()
    x[-m:] *= np.linspace(1, 0, m) ** 2
    return x


def trim(x, thr=1e-4):
    nz = np.where(np.abs(x) > thr)[0]
    if len(nz) == 0:
        return x
    return x[:nz[-1] + 1]
