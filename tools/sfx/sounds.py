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
    """sin silbido de dibujito: el aire que corta la capa, la tela que flamea y el empuje de la bota"""
    d = 0.2
    t = T(d)
    air = svf(noise(d), sweep(900, 3200, 0.12, len(t)), 1.0, 'bp') * exp_env(d, 0.055, 0.006)
    flap_am = 0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)
    cloth = svf(noise(d), 700, 0.8) * flap_am * exp_env(d, 0.05, 0.004)
    push = osc(sweep(170, 120, 0.05, len(t)), 'sine') * exp_env(d, 0.035, 0.002)
    scuff = svf(noise(d), 2200, 1.5, 'bp') * exp_env(d, 0.012, 0.001)
    return air * 0.7 + cloth * 0.5 + push * 0.5 + scuff * 0.35


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
    d = 0.24
    t = T(d)
    twang = karplus(165, d, 0.992, 0.6) * exp_env(d, 0.08, 0.0015)
    twang = svf(twang, 3000, 0.8)
    whoosh = svf(noise(d), sweep(2800, 700, 0.17, len(t)), 1.3, 'bp') * bell_env(d, 0.025, 2.4)
    click = hp1(noise(0.004), 2500) * np.linspace(1, 0, n_(0.004))
    thump = osc(sweep(120, 70, 0.04, len(t)), 'sine') * exp_env(d, 0.03, 0.002)
    return mix(d, (twang, 0, 0.75), (whoosh, 0.006, 0.6), (click, 0, 0.45), (thump, 0, 0.35))


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
    d = 0.13
    t = T(d)
    burst = svf(noise(d), 1500, 0.8, 'bp') * exp_env(d, 0.018, 0.001)
    body = osc(sweep(380, 120, 0.05, len(t)), 'sine') * exp_env(d, 0.04, 0.001)
    flesh = svf(noise(d), sweep(1800, 500, 0.05, len(t)), 2.0) * exp_env(d, 0.03, 0.002)
    return drive(burst * 0.8 + body * 1.0 + flesh * 0.4, 2.4)


def critico():
    d = 0.55
    t = T(d)
    burst = svf(noise(d), sweep(6000, 700, 0.08, len(t)), 0.7) * exp_env(d, 0.035, 0.001)
    sub = osc(sweep(95, 34, 0.14, len(t)), 'sine') * exp_env(d, 0.11, 0.002)
    body = osc(sweep(520, 150, 0.05, len(t)), 'sine') * exp_env(d, 0.045, 0.001)
    hit = drive(burst * 0.9 + sub * 1.1 + body * 0.6, 2.6)
    shing = modal(d, [1120, 2240 * 1.003, 3370 * 1.01, 4490 * 1.02, 5600],
                  [0.3, 0.2, 0.13, 0.08, 0.05], [0.7, 0.5, 0.4, 0.25, 0.12], 0.0035)
    shing *= np.clip((t - 0.008) / 0.004, 0, 1)
    shing = echo(shing, 0.095, 0.32, 0.3, 4000, 0.0)[:len(t)]
    return hit * 0.95 + shing * 0.28


def moneda():
    """dos golpecitos de oro, más graves y metálicos (sigue teniendo nota para el combo)"""
    d = 0.34
    F1, F2 = 739.99, 987.77  # fa# y si
    a = bell(F1, 0.08, 0.05, ratio=3.5, idx=1.3, idx_tau=0.02, sq=0.04)
    b = bell(F2, 0.28, 0.12, ratio=3.5, idx=1.3, idx_tau=0.03, sq=0.04)
    clink = modal(0.05, [3400, 5150, 7300], [0.012, 0.008, 0.005], [0.6, 0.4, 0.25])
    out = mix(d, (a, 0, 0.6), (clink, 0, 0.25), (b, 0.06, 0.8), (clink, 0.06, 0.3))
    return echo(out, 0.08, 0.2, 0.18, 4000, 0.12)


def pisoton():
    d = 0.17
    t = T(d)
    thump = osc(sweep(160, 50, 0.07, len(t)), 'sine') * exp_env(d, 0.055, 0.001)
    squelch = svf(noise(d), sweep(2000, 300, 0.08, len(t)), 2.6) * exp_env(d, 0.045, 0.002)
    boot = svf(noise(d), 900, 0.8) * exp_env(d, 0.02, 0.001)
    return drive(thump * 1.0 + squelch * 0.6 + boot * 0.4, 2.0)


def explotar():
    d = 0.34
    t = T(d)
    gut = osc(sweep(320, 70, 0.09, len(t)), 'sine') * exp_env(d, 0.07, 0.001)
    splash = svf(noise(d), sweep(5000, 500, 0.14, len(t)), 0.8) * exp_env(d, 0.08, 0.001)
    sizzle = svf(noise(d), 2400, 1.2, 'bp') * exp_env(d, 0.14, 0.01)
    drops = np.zeros(len(t))
    for k in range(5):
        t0 = 0.06 + rng.uniform(0, 0.2)
        f0 = rng.uniform(500, 1300)
        n = n_(0.035)
        g = osc(sweep(f0 * 0.7, f0 * 1.3, 0.025, n), 'sine') * exp_env(0.035, 0.008, 0.001)
        i = n_(t0)
        drops[i:i + n] += g[:max(0, min(n, len(drops) - i))] * rng.uniform(0.15, 0.35)
    return drive(gut * 0.9 + splash * 0.9 + sizzle * 0.16 + drops * 0.45, 2.2)


def dano():
    """golpe seco al cuerpo, sin la sirenita: crujido, golpe grave y un gemido corto de cuerda baja"""
    d = 0.28
    t = T(d)
    crunch = crush(svf(noise(d), 1100, 0.8, 'bp'), 9000) * exp_env(d, 0.035, 0.001)
    thump = osc(sweep(140, 45, 0.07, len(t)), 'sine') * exp_env(d, 0.06, 0.001)
    f = glide([(0, 300), (0.28, 170)], d)
    groan = svf(osc(f, 'saw') * 0.7 + osc(f * 1.5, 'saw') * 0.25, 900, 1.2) * exp_env(d, 0.09, 0.008)
    return drive(crunch * 0.85 + thump * 1.0 + groan * 0.45, 2.0)


def alerta():
    d = 0.22
    out = bell(1174.66, d, 0.085, ratio=3.5, idx=1.5, idx_tau=0.025, sq=0.2)
    low = bell(587.33, d, 0.05, ratio=1.0, idx=0.4, sq=0.0)
    return out + low * 0.3


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
    d = 0.17
    a = osc(sweep(120, 380, 0.05, n_(0.08)), 'sine') * exp_env(0.08, 0.03, 0.003)
    b = osc(sweep(170, 520, 0.04, n_(0.07)), 'sine') * exp_env(0.07, 0.022, 0.003)
    sq = svf(noise(d), sweep(1400, 350, 0.08, n_(d)), 2.5) * exp_env(d, 0.035, 0.002)
    return mix(d, (a, 0, 0.9), (b, 0.06, 0.6), (sq, 0, 0.4))


def posesion():
    """las cartas: un acorde menor que se abre despacio, con eco de salón"""
    d = 0.9
    t = T(d)
    rise = svf(noise(d), sweep(300, 3500, 0.45, len(t)), 2.0, 'bp') * ad(d, 0.35, 0.05, 0.35)
    notes = [329.63, 392.0, 493.88, 659.25]  # mi menor
    parts = [(rise, 0, 0.3)]
    for i, f in enumerate(notes):
        parts.append((bell(f, 0.7, 0.22 + i * 0.04, ratio=2.0, idx=1.0, sq=0.05), 0.06 + i * 0.09, 0.5))
        parts.append((svf(osc(np.full(n_(0.7), f * 0.5), 'saw'), 700, 0.8) * ad(0.7, 0.15, 0.2, 0.35), 0.06 + i * 0.09, 0.12))
    out = mix(d, *parts)
    return echo(out, 0.13, 0.38, 0.38, 3500, 0.35)


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
    """el arco listo: un zumbido que se tensa y un tin grave"""
    d = 0.34
    t = T(d)
    hum = svf(osc(sweep(110, 165, 0.12, len(t)), 'saw'), 600, 1.5) * ad(d, 0.03, 0.05, 0.2)
    a = bell(659.25, 0.12, 0.05, ratio=2.0, idx=1.4)
    b = bell(987.77, 0.26, 0.11, ratio=2.0, idx=1.4)
    out = mix(d, (hum, 0, 0.35), (a, 0.02, 0.5), (b, 0.07, 0.65))
    return echo(out, 0.07, 0.28, 0.25, 4500, 0.12)


def poder():
    d = 0.38
    t = T(d)
    whoosh = svf(noise(d), sweep(600, 3800, 0.1, len(t)), 1.8, 'bp') * bell_env(d, 0.05, 2.2)
    f = glide([(0, 260), (0.05, 820), (0.38, 300)], d)
    zap = fm(f, 1.5, 3.0 * np.exp(-t / 0.09)) * exp_env(d, 0.11, 0.003)
    twang = svf(karplus(147, d, 0.993, 0.8), 3000, 0.7) * exp_env(d, 0.08, 0.001)
    sub = osc(sweep(120, 45, 0.1, len(t)), 'sine') * exp_env(d, 0.07, 0.002)
    return drive(whoosh * 0.55 + zap * 0.45 + twang * 0.5 + sub * 0.8, 1.8)


def horn(f, d, a=0.035):
    """metal tipo corno: sierra con filtro que se abre al atacar"""
    t = T(d)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t)
    x = osc(f * vib, 'saw') + osc(f * 1.003 * vib, 'saw') * 0.7
    cut = 500 + 2300 * np.exp(-t / 0.12) * np.clip(t / a, 0, 1)
    hold = d * 0.35
    return svf(x, cut, 1.1) * ad(d, a, hold, d - a - hold - 0.004, 1.4)  # se apaga antes del final: sin chasquido


def oleada():
    """fanfarria corta y noble (sol, re, sol) en vez de campanitas"""
    d = 0.62
    parts = []
    for i, f in enumerate([392.0, 587.33, 783.99]):
        last = i == 2
        dur = 0.5 if last else 0.13
        parts.append((horn(f, dur), i * 0.065, 0.5 if last else 0.42))
        parts.append((bell(f * 2, dur, 0.06, ratio=2.0, idx=0.8, sq=0.0), i * 0.065, 0.12))
    out = mix(d, *parts)
    return echo(out, 0.11, 0.3, 0.28, 3500, 0.15)


def menu():
    d = 0.07
    t = T(d)
    tone = osc(sweep(560, 523.25, 0.01, len(t)), 'tri') * exp_env(d, 0.02, 0.001)
    tick = modal(d, [1900, 3100], [0.006, 0.004], [1.0, 0.5])
    return mix(d, (tone, 0, 0.7), (tick, 0, 0.4))


def derrota():
    """cuatro notas que bajan, despacio, la última se apaga temblando"""
    d = 1.6
    parts = []
    notes = [(392.0, 0.0, 0.22), (349.23, 0.22, 0.22), (311.13, 0.44, 0.22), (293.66, 0.66, 0.85)]
    for f, t0, dur in notes:
        tt = T(dur)
        last = dur > 0.3
        vib = 1 + (0.01 * np.sin(2 * np.pi * 5.0 * tt) * np.clip((tt - 0.15) / 0.25, 0, 1) if last else 0)
        sag = sweep(1.0, 0.95, dur, len(tt)) if last else 1.0
        ff = np.full(len(tt), f) * vib * sag
        v = svf(osc(ff, 'saw') * 0.5 + osc(ff * 0.5, 'tri') * 0.6, 1400, 0.8)
        v *= ad(dur, 0.02, dur * 0.35, dur * 0.65, 1.3)
        parts.append((v, t0, 0.6))
    out = mix(d, *parts)
    return echo(out, 0.16, 0.32, 0.32, 2500, 0.3)


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
