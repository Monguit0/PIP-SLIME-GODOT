# Los efectos de sonido nuevos, uno por función. Cada uno: golpe inicial + cuerpo + cola.
import numpy as np
from synth import *

B5, E6, G5, D6, G6, B6, E5, C6 = 987.77, 1318.5, 783.99, 1174.66, 1567.98, 1975.53, 659.25, 1046.5


def bell(f, d, tau, ratio=2.0, idx=2.2, idx_tau=0.05, sq=0.12):
    """campanita FM con un poco de cuadrada de las de antes (para que no pierda lo retro)"""
    t = T(d)
    e = exp_env(d, tau, 0.002)
    b = fm(np.full(len(t), f), ratio, idx * np.exp(-t / idx_tau))
    s = svf(osc(np.full(len(t), f), 'square', 0.25), 5000, 0.7) * sq
    rel = np.clip((d - t) / min(0.03, d * 0.4), 0, 1)  # se apaga al final: sin chasquido al cortar
    return (b + s) * e * rel


def salto():
    d = 0.2
    t = T(d)
    air = svf(noise(d), sweep(1400, 5200, 0.12, len(t)), 1.1, 'bp') * exp_env(d, 0.05, 0.004)
    f = glide([(0, 300), (0.07, 760), (0.2, 820)], d)
    body = svf(osc(f, 'tri') * 0.8 + osc(f, 'square', 0.25) * 0.22, 4200, 0.8) * exp_env(d, 0.06, 0.003)
    return air * 0.55 + body * 0.75


def aterrizar():
    d = 0.14
    t = T(d)
    thump = osc(sweep(150, 52, 0.07, len(t)), 'sine') * exp_env(d, 0.045, 0.002)
    dirt = svf(noise(d), 2400, 0.7) * exp_env(d, 0.022, 0.001)
    grav = np.zeros(len(t))
    for k in range(5):
        i = n_(0.004 + k * 0.012 + rng.uniform(0, 0.006))
        g = svf(noise(0.012), rng.uniform(1600, 3200), 2.0, 'bp') * exp_env(0.012, 0.003, 0)
        grav[i:i + len(g)] += g[:len(grav) - i] * (0.6 - k * 0.1)
    return drive(thump * 1.0 + dirt * 0.45 + grav * 0.5, 1.6)


def disparo():
    d = 0.22
    t = T(d)
    twang = karplus(196, d, 0.992, 0.7) * exp_env(d, 0.07, 0.0015)
    twang = svf(twang, 3500, 0.8)
    whoosh = svf(noise(d), sweep(3200, 900, 0.16, len(t)), 1.4, 'bp') * bell_env(d, 0.025, 2.4)
    click = hp1(noise(0.004), 3000) * np.linspace(1, 0, n_(0.004))
    return mix(d, (twang, 0, 0.75), (whoosh, 0.006, 0.6), (click, 0, 0.5))


def tajo():
    d = 0.24
    t = T(d)
    e = bell_env(d, 0.07, 2.2)
    fc = 700 + 2600 * e
    a = svf(noise(d), fc, 2.6, 'bp')
    b = svf(noise(d), fc * 2.1, 3.0, 'bp')
    ring = modal(d, [2240, 3410, 5120], [0.06, 0.04, 0.025], [0.5, 0.35, 0.2], 0.004)
    ring *= np.clip((t - 0.05) / 0.02, 0, 1)
    return (a * 1.0 + b * 0.45) * e + ring * 0.18


def clavar():
    d = 0.3
    t = T(d)
    click = hp1(noise(0.006), 2500) * np.linspace(1, 0, n_(0.006)) ** 2
    knock = modal(d, [190, 430, 760, 1250], [0.05, 0.03, 0.02, 0.012], [1.0, 0.6, 0.4, 0.25])
    # la flecha que queda vibrando: un zumbido de madera que tiembla y se apaga
    wob = 0.5 + 0.5 * np.sin(2 * np.pi * sweep(34, 22, 0.25, len(t)) * t)
    buzz = svf(osc(np.full(len(t), 155.0), 'saw'), 1100, 1.4) * wob * exp_env(d, 0.07, 0.01)
    return drive(mix(d, (click, 0, 0.7), (knock, 0, 0.9), (buzz, 0.012, 0.32)), 1.4)


def acierto():
    d = 0.12
    t = T(d)
    burst = svf(noise(d), 1900, 0.8, 'bp') * exp_env(d, 0.016, 0.001)
    body = osc(sweep(560, 170, 0.05, len(t)), 'sine') * exp_env(d, 0.035, 0.001)
    pop = osc(sweep(1100, 380, 0.03, len(t)), 'tri') * exp_env(d, 0.015, 0.001)
    return drive(burst * 0.8 + body * 0.9 + pop * 0.35, 2.2)


def critico():
    d = 0.5
    t = T(d)
    burst = svf(noise(d), sweep(7000, 900, 0.08, len(t)), 0.7) * exp_env(d, 0.03, 0.001)
    sub = osc(sweep(110, 38, 0.12, len(t)), 'sine') * exp_env(d, 0.09, 0.002)
    body = osc(sweep(700, 200, 0.05, len(t)), 'sine') * exp_env(d, 0.04, 0.001)
    hit = drive(burst * 0.9 + sub * 1.0 + body * 0.6, 2.4)
    shing = modal(d, [1480, 2960 * 1.003, 4450 * 1.01, 5930 * 1.02, 7400],
                  [0.26, 0.18, 0.12, 0.08, 0.05], [0.7, 0.5, 0.4, 0.25, 0.15], 0.0035)
    shing *= np.clip((t - 0.008) / 0.004, 0, 1)
    shing = echo(shing, 0.085, 0.3, 0.3, 5000, 0.0)[:len(t)]
    return hit * 0.9 + shing * 0.32


def moneda():
    d = 0.32
    a = bell(B5, 0.07, 0.05)
    b = bell(E6, 0.26, 0.11)
    spark = svf(noise(0.05), 7500, 1.0, 'hp') * exp_env(0.05, 0.012, 0)
    out = mix(d, (a, 0, 0.6), (b, 0.055, 0.75), (spark, 0.055, 0.12))
    return echo(out, 0.075, 0.22, 0.22, 5000, 0.12)


def pisoton():
    d = 0.16
    t = T(d)
    thump = osc(sweep(190, 58, 0.06, len(t)), 'sine') * exp_env(d, 0.05, 0.001)
    squelch = svf(noise(d), sweep(2800, 380, 0.07, len(t)), 3.0) * exp_env(d, 0.04, 0.002)
    boing = osc(sweep(260, 520, 0.06, len(t)), 'tri') * exp_env(d, 0.04, 0.008)
    return drive(mix(d, (thump, 0, 1.0), (squelch, 0, 0.6), (boing, 0.035, 0.28)), 1.8)


def explotar():
    d = 0.32
    t = T(d)
    bloop = osc(sweep(760, 110, 0.08, len(t)), 'sine') * exp_env(d, 0.06, 0.001)
    splash = svf(noise(d), sweep(6500, 700, 0.12, len(t)), 0.8) * exp_env(d, 0.07, 0.001)
    sizzle = svf(noise(d), 3200, 1.2, 'bp') * exp_env(d, 0.13, 0.01)
    drops = np.zeros(len(t))
    for k in range(6):
        t0 = 0.05 + rng.uniform(0, 0.2)
        f0 = rng.uniform(900, 2400)
        n = n_(0.03)
        g = osc(sweep(f0 * 0.7, f0 * 1.6, 0.02, n), 'sine') * exp_env(0.03, 0.007, 0.001)
        i = n_(t0)
        drops[i:i + n] += g[:max(0, min(n, len(drops) - i))] * rng.uniform(0.2, 0.45)
    return drive(bloop * 0.9 + splash * 0.8 + sizzle * 0.18 + drops * 0.5, 2.0)


def dano():
    d = 0.26
    t = T(d)
    crunch = crush(svf(noise(d), 1300, 0.8, 'bp'), 9000) * exp_env(d, 0.03, 0.001)
    vib = 1 + 0.035 * np.sin(2 * np.pi * 32 * t)
    f = glide([(0, 640), (0.05, 470), (0.26, 250)], d) * vib
    tone = svf(osc(f, 'square', 0.3) * 0.6 + osc(f * 0.84, 'tri') * 0.5, 3000, 0.8) * exp_env(d, 0.09, 0.003)
    thump = osc(sweep(160, 60, 0.05, len(t)), 'sine') * exp_env(d, 0.04, 0.001)
    return drive(crunch * 0.8 + tone * 0.65 + thump * 0.7, 1.8)


def alerta():
    d = 0.16
    d = 0.2
    out = bell(G6, d, 0.075, ratio=3.5, idx=1.6, idx_tau=0.025, sq=0.28)
    hi = bell(G6 * 2, d, 0.03, ratio=1.0, idx=0.5, sq=0.0)
    return out + hi * 0.25


def porton():
    d = 0.55
    t = T(d)
    grind_am = np.clip(svf(noise(d), 18, 0.7) * 30 + 0.6, 0.1, 1.4)
    grind = svf(noise(d), 520, 1.2, 'bp') * grind_am * ad(d, 0.04, 0.26, 0.2)
    chain = np.zeros(len(t))
    tt = 0.01
    while tt < 0.36:
        c = modal(0.03, [rng.uniform(2200, 3400), rng.uniform(4300, 5600)], [0.008, 0.005], [1, 0.5])
        i = n_(tt)
        chain[i:i + len(c)] += c[:max(0, min(len(c), len(chain) - i))] * rng.uniform(0.4, 1.0)
        tt += rng.uniform(0.022, 0.04)
    thud = osc(sweep(95, 42, 0.1, n_(0.2)), 'sine') * exp_env(0.2, 0.07, 0.002)
    dust = svf(noise(0.2), 900, 0.7) * exp_env(0.2, 0.05, 0.002)
    return drive(mix(d, (grind, 0, 0.7), (chain, 0, 0.32), (thud, 0.34, 1.0), (dust, 0.34, 0.4)), 1.6)


def metal():
    d = 0.36
    t = T(d)
    click = hp1(noise(0.004), 4000) * np.linspace(1, 0, n_(0.004))
    ring = modal(d, [640, 1490, 2720, 4240, 6000], [0.17, 0.11, 0.075, 0.05, 0.03],
                 [0.8, 0.7, 0.5, 0.35, 0.2], 0.006)
    knock = osc(sweep(320, 140, 0.03, len(t)), 'sine') * exp_env(d, 0.025, 0.001)
    return drive(mix(d, (click, 0, 0.7), (ring, 0, 0.6), (knock, 0, 0.6)), 1.5)


def rugido():
    d = 1.15
    t = T(d)
    jit = np.exp(svf(noise(d), 9, 0.7) * 1.2)
    f = glide([(0, 78), (0.25, 104), (0.7, 96), (1.15, 66)], d) * jit
    rough = 1 + 0.45 * np.sign(np.sin(2 * np.pi * f * 0.5 * t)) * 0.5  # subarmónico: la voz rasposa
    src = osc(f, 'saw') * rough + osc(f * 1.007, 'saw') * 0.6
    vow = np.clip(t / 1.15, 0, 1)
    f1, f2, f3 = 650 - 220 * vow, 1150 - 350 * vow, 2500 - 300 * vow
    voice = svf(src, f1, 4.0, 'bp') * 1.0 + svf(src, f2, 5.0, 'bp') * 0.7 + svf(src, f3, 6.0, 'bp') * 0.35
    breath = svf(noise(d), 1400 - 500 * vow, 1.5, 'bp') * 0.5
    sub = osc(f * 0.5, 'sine') * 0.5
    env = ad(d, 0.12, 0.6, 0.4, 1.6)
    out = drive((voice * 1.6 + breath + sub) * env, 2.6)
    return echo(out, 0.12, 0.33, 0.3, 2500, 0.35)


def huesos():
    d = 0.2
    out = modal(d, [460, 930], [0.03, 0.018], [0.8, 0.4])
    tt = 0.0
    k = 0
    while tt < 0.16:
        c = modal(0.03, [rng.uniform(1100, 2600), rng.uniform(2800, 4200)], [rng.uniform(0.006, 0.014), 0.005], [1, 0.4])
        c[:n_(0.002)] += hp1(noise(0.002), 3000)
        i = n_(tt)
        out[i:i + len(c)] += c[:max(0, min(len(c), len(out) - i))] * (1.0 - k * 0.09) * rng.uniform(0.6, 1)
        tt += rng.uniform(0.014, 0.03)
        k += 1
    return drive(out, 1.5)


def baba():
    d = 0.16
    a = osc(sweep(190, 620, 0.05, n_(0.07)), 'sine') * exp_env(0.07, 0.025, 0.003)
    b = osc(sweep(280, 860, 0.04, n_(0.06)), 'sine') * exp_env(0.06, 0.02, 0.003)
    sq = svf(noise(d), sweep(1800, 500, 0.08, n_(d)), 2.5) * exp_env(d, 0.03, 0.002)
    return mix(d, (a, 0, 0.9), (b, 0.06, 0.6), (sq, 0, 0.35))


def posesion():
    d = 0.62
    t = T(d)
    rise = svf(noise(d), sweep(500, 6000, 0.35, len(t)), 2.0, 'bp') * ad(d, 0.25, 0.05, 0.25)
    notes = [E5, 830.6, B5, E6]  # mi mayor
    parts = [(rise, 0, 0.35)]
    for i, f in enumerate(notes):
        parts.append((bell(f, 0.45, 0.14 + i * 0.03, ratio=3.0, idx=1.4, sq=0.08), 0.05 + i * 0.06, 0.5))
    out = mix(d, *parts)
    return echo(out, 0.1, 0.35, 0.35, 4500, 0.3)


def dash():
    d = 0.14
    t = T(d)
    e = bell_env(d, 0.02, 2.0)
    air = svf(noise(d), 1200 + 4200 * e, 1.6, 'bp') * e
    zip_ = osc(sweep(900, 2600, 0.04, len(t)), 'sine') * exp_env(d, 0.02, 0.002)
    low = svf(noise(d), 500, 0.8) * e
    return air * 0.9 + zip_ * 0.15 + low * 0.4


def escudo():
    d = 0.26
    t = T(d)
    f = 880 * (1 + 0.02 * np.sin(2 * np.pi * 14 * t))
    out = fm(f, 1.5, 2.5 * np.exp(-t / 0.05)) * exp_env(d, 0.08, 0.002)
    return out * 0.8 + modal(d, [1760, 2640], [0.06, 0.04], [0.3, 0.2])


def cargado():
    d = 0.3
    a = bell(E6, 0.12, 0.05, ratio=2.0, idx=1.8)
    b = bell(B6, 0.22, 0.09, ratio=2.0, idx=1.8)
    spark = svf(noise(0.12), 7000, 1.0, 'hp') * exp_env(0.12, 0.03, 0.005)
    out = mix(d, (a, 0, 0.55), (b, 0.05, 0.7), (spark, 0.04, 0.15))
    return echo(out, 0.06, 0.3, 0.3, 6000, 0.12)


def poder():
    d = 0.38
    t = T(d)
    whoosh = svf(noise(d), sweep(600, 3800, 0.1, len(t)), 1.8, 'bp') * bell_env(d, 0.05, 2.2)
    f = glide([(0, 260), (0.05, 820), (0.38, 300)], d)
    zap = fm(f, 1.5, 3.0 * np.exp(-t / 0.09)) * exp_env(d, 0.11, 0.003)
    twang = svf(karplus(147, d, 0.993, 0.8), 3000, 0.7) * exp_env(d, 0.08, 0.001)
    sub = osc(sweep(120, 45, 0.1, len(t)), 'sine') * exp_env(d, 0.07, 0.002)
    return drive(whoosh * 0.55 + zap * 0.45 + twang * 0.5 + sub * 0.8, 1.8)


def oleada():
    d = 0.55
    parts = []
    for i, f in enumerate([G5, D6, G6]):
        last = i == 2
        parts.append((bell(f, 0.5 if last else 0.12, 0.2 if last else 0.05, ratio=2.0, idx=1.5, sq=0.18), i * 0.055, 0.55 if last else 0.45))
    out = mix(d, *parts)
    return echo(out, 0.09, 0.3, 0.28, 4500, 0.1)


def menu():
    d = 0.07
    t = T(d)
    tone = osc(sweep(C6 * 1.08, C6, 0.01, len(t)), 'tri') * exp_env(d, 0.022, 0.001)
    click = hp1(noise(0.002), 3000) * np.linspace(1, 0, n_(0.002))
    return mix(d, (tone, 0, 0.9), (click, 0, 0.35))


def derrota():
    d = 1.15
    parts = []
    notes = [(587.33, 0.0, 0.16), (493.88, 0.15, 0.16), (392.0, 0.3, 0.16), (369.99, 0.45, 0.65)]
    for f, t0, dur in notes:
        tt = T(dur)
        last = dur > 0.3
        vib = 1 + (0.012 * np.sin(2 * np.pi * 5.5 * tt) * np.clip((tt - 0.1) / 0.2, 0, 1) if last else 0)
        sag = sweep(1.0, 0.94, dur, len(tt)) if last else 1.0
        ff = np.full(len(tt), f) * vib * sag
        v = svf(osc(ff, 'square', 0.35) * 0.4 + osc(ff, 'tri') * 0.7, 2600, 0.7)
        v *= ad(dur, 0.006, dur * 0.4, dur * 0.6, 1.4)
        parts.append((v, t0, 0.6))
    out = mix(d, *parts)
    return echo(out, 0.14, 0.3, 0.3, 3000, 0.2)


def boom():
    d = 0.75
    t = T(d)
    sub = osc(sweep(95, 30, 0.3, len(t)), 'sine') * exp_env(d, 0.22, 0.002)
    thump = osc(sweep(220, 70, 0.06, len(t)), 'sine') * exp_env(d, 0.06, 0.001)
    blast = svf(noise(d), sweep(5500, 280, 0.3, len(t)), 0.8) * exp_env(d, 0.16, 0.001)
    crackle = np.zeros(len(t))
    tt = 0.03
    while tt < 0.6:
        c = svf(noise(0.008), rng.uniform(1500, 4200), 2.5, 'bp') * exp_env(0.008, 0.002, 0)
        i = n_(tt)
        crackle[i:i + len(c)] += c[:max(0, min(len(c), len(crackle) - i))] * rng.uniform(0.3, 1.0) * (1 - tt / 0.6)
        tt += rng.uniform(0.008, 0.03) * (1 + tt * 4)
    out = drive(sub * 1.2 + thump * 0.8 + crush(blast, 14000) * 0.9 + crackle * 0.6, 2.8)
    return echo(out, 0.14, 0.3, 0.22, 2000, 0.25)


def paso():
    """pisada del caballero: golpe sordo de bota pesada y el tintineo de la armadura"""
    d = 0.2
    t = T(d)
    thud = osc(sweep(120, 46, 0.06, len(t)), 'sine') * exp_env(d, 0.055, 0.002)
    grit = svf(noise(d), 1400, 0.7) * exp_env(d, 0.018, 0.001)
    clink = modal(d, [1240, 2310, 3720], [0.03, 0.022, 0.015], [0.6, 0.45, 0.3], 0.005)
    return drive(mix(d, (thud, 0, 1.0), (grit, 0, 0.35), (clink, 0.012, 0.22)), 1.7)


ALL = ["salto", "aterrizar", "disparo", "tajo", "clavar", "acierto", "critico", "moneda", "pisoton",
       "explotar", "dano", "alerta", "porton", "metal", "rugido", "huesos", "baba", "posesion", "dash",
       "escudo", "cargado", "poder", "oleada", "menu", "derrota", "boom", "paso"]
