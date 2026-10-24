"""Gera os sons sintéticos do jogo em assets/audio/ por síntese procedural.

Passos, arco, impactos de flecha, golpe na madeira, coleta e faca são gravações reais (CC0)
em assets/audio/real/ — ver assets/CREDITS.md; este script não mexe nelas.

Loops (vento, folhas, fogo, caverna, insetos) são feitos no domínio da frequência,
então o fim emenda perfeitamente no começo; o arquivo WAV leva um chunk "smpl"
com os pontos de loop, que o Godot detecta na importação.

Uso (na raiz do projeto): python tools/generate_sounds.py
"""
import struct
from pathlib import Path

import numpy as np

SR = 22050
ROOT = Path(__file__).resolve().parent.parent / "assets" / "audio"
TAU = 2.0 * np.pi


# --- Utilitários ---------------------------------------------------------------

def write_wav(path, x, loop=False, peak=0.89):
    """WAV mono 16 bits; com loop=True grava os pontos de loop (chunk smpl)."""
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-12) * peak
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = [b"fmt " + struct.pack("<I", len(fmt)) + fmt]
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    chunks.append(b"data" + struct.pack("<I", len(pcm)) + pcm)
    body = b"WAVE" + b"".join(chunks)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)
    print(f"  {path.relative_to(ROOT)} ({len(x) / SR:.1f} s{', loop' if loop else ''})")


def rms_norm(x):
    return x / (np.sqrt(np.mean(x * x)) + 1e-12)


def peak_norm(x):
    return x / (np.max(np.abs(x)) + 1e-12)


def periodic_noise(n, rng, beta=0.0):
    """Ruído periódico (emenda no fim) com espectro de potência 1/f^beta."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1.0
    spec = spec / f ** (beta / 2.0)
    spec[0] = 0.0
    return np.fft.irfft(spec, n)


def band(x, lo, hi, edge=0.15):
    """Passa-faixa circular no domínio da frequência (lo=0 vira passa-baixa). Preserva loops."""
    n = len(x)
    spec = np.fft.rfft(x)
    logf = np.log(np.fft.rfftfreq(n, 1.0 / SR) + 1e-9)
    with np.errstate(over="ignore"):  # bordas muito estreitas estouram exp(); o ganho vira 0, como deve
        gain = 1.0 / (1.0 + np.exp((logf - np.log(hi)) / edge))
        if lo > 0:
            gain *= 1.0 / (1.0 + np.exp(-(logf - np.log(lo)) / edge))
    return np.fft.irfft(spec * gain, n)


def band_oneshot(x, lo, hi, edge=0.15):
    """Mesmo filtro, com folga de silêncio para o rabo não dar a volta no começo."""
    pad = int(0.15 * SR)
    return band(np.concatenate([x, np.zeros(pad)]), lo, hi, edge)[: len(x)]


def formants(x, peaks):
    """Realça faixas de frequência (fc, largura, ganho), como o trato vocal de um bicho."""
    pad = int(0.15 * SR)
    y = np.concatenate([x, np.zeros(pad)])
    spec = np.fft.rfft(y)
    f = np.fft.rfftfreq(len(y), 1.0 / SR)
    gain = np.full_like(f, 0.05)
    for fc, bw, g in peaks:
        gain += g * np.exp(-0.5 * ((f - fc) / bw) ** 2)
    return np.fft.irfft(spec * gain, len(y))[: len(x)]


def slow_env(n, rng, cycles_min, cycles_max, lo=0.0, hi=1.0):
    """Envelope suave e periódico entre lo e hi (cycles_* = ciclos por loop)."""
    spec = np.zeros(n // 2 + 1, dtype=complex)
    for k in range(cycles_min, cycles_max + 1):
        spec[k] = (rng.normal() + 1j * rng.normal()) / np.sqrt(k)
    e = np.fft.irfft(spec, n)
    e = (e - e.min()) / (e.max() - e.min() + 1e-12)
    return lo + (hi - lo) * e


def burst(rng, dur, decay, attack=0.001):
    """Rajada de ruído com ataque e decaimento exponencial."""
    t = np.arange(int(dur * SR)) / SR
    return rng.standard_normal(len(t)) * np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def place_events(n, times, make_event):
    """Soma eventos curtos nas posições dadas (em amostras), dando a volta no fim do loop."""
    out = np.zeros(n)
    for start in times:
        ev = make_event()
        np.add.at(out, (int(start) + np.arange(len(ev))) % n, ev)
    return out


def thinned_times(rng, n, rate_max, density):
    """Instantes aleatórios com taxa variável (processo de Poisson por rejeição)."""
    seconds = n / SR
    cand = rng.uniform(0, n, int(rate_max * seconds))
    return cand[rng.random(len(cand)) < density[cand.astype(int)]]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def tone(freq, harmonics=((1, 1.0),)):
    """Soma de harmônicos com fase contínua; freq é um array por amostra."""
    phase = TAU * np.cumsum(freq) / SR
    out = np.zeros(len(freq))
    for k, amp in harmonics:
        out += amp * np.sin(k * phase) * (k * freq < SR * 0.47)
    return out


def concat(*parts):
    return np.concatenate([np.atleast_1d(p) for p in parts])


def silence(seconds):
    return np.zeros(int(seconds * SR))


# --- Ambiente (loops) ------------------------------------------------------------

def wind_loop(seconds=24):
    rng = np.random.default_rng(1)
    n = seconds * SR
    gust = slow_env(n, rng, 1, 6)
    body = band(periodic_noise(n, rng, beta=1.0), 70, 650) * (0.35 + 0.65 * gust)
    howl = np.zeros(n)
    for f0 in (330, 480, 690):
        howl += band(periodic_noise(n, rng), f0 * 0.9, f0 * 1.1, edge=0.05) * slow_env(n, rng, 2, 7) ** 2
    hiss = band(periodic_noise(n, rng), 1500, 5000) * gust**2
    return rms_norm(body) + 0.35 * rms_norm(howl) * (0.3 + 0.7 * gust) + 0.12 * rms_norm(hiss)






def cave_loop(seconds=12):
    rng = np.random.default_rng(4)
    n = seconds * SR
    rumble = band(periodic_noise(n, rng, beta=1.5), 25, 180) * slow_env(n, rng, 1, 4, 0.6, 1.0)
    air = band(periodic_noise(n, rng), 250, 600, edge=0.08) * slow_env(n, rng, 2, 6, 0.2, 1.0)
    return rms_norm(rumble) + 0.25 * rms_norm(air)


def grasshoppers_loop(seconds=10):
    rng = np.random.default_rng(5)
    n = seconds * SR
    out = np.zeros(n)
    for _ in range(4):
        freq = rng.uniform(4500, 7500)
        pulse_rate = rng.uniform(18, 35)
        t0 = rng.uniform(0, 2)
        while t0 < seconds:
            dur = rng.uniform(0.4, 1.8)
            t = np.arange(int(dur * SR)) / SR
            pulses = (0.5 + 0.5 * np.sin(TAU * pulse_rate * t)) ** 6
            env = np.minimum(t / 0.05, 1.0) * np.minimum((dur - t) / 0.1, 1.0)
            chirp = np.sin(TAU * freq * t + 0.3 * np.sin(TAU * 90 * t)) * pulses * env * rng.uniform(0.3, 1.0)
            np.add.at(out, (int(t0 * SR) + np.arange(len(chirp))) % n, chirp)
            t0 += dur + rng.uniform(0.6, 3.0)
    return out + 0.05 * peak_norm(band(periodic_noise(n, rng), 4000, 8000))


# --- Bichos ----------------------------------------------------------------------

def note(f_start, f_end, dur, vib_rate=0.0, vib_depth=0.0, harm=0.15):
    t = np.arange(int(dur * SR)) / SR
    freq = f_start + (f_end - f_start) * (t / dur) + vib_depth * np.sin(TAU * vib_rate * t)
    return tone(freq, ((1, 1.0), (2, harm))) * np.sin(np.pi * t / dur) ** 2


def bird(variant):
    rng = np.random.default_rng(10 + variant)
    if variant == 1:  # "tsii-tsii-tsii" descendente
        parts = []
        for _ in range(rng.integers(4, 7)):
            parts += [note(rng.uniform(5800, 6400), rng.uniform(4400, 4800), 0.07), silence(rng.uniform(0.07, 0.1))]
        return concat(*parts)
    if variant == 2:  # trinado e dois piados
        return concat(note(3600, 3400, 0.7, 28, 700), silence(0.1), note(4200, 5200, 0.06), silence(0.05), note(4300, 5300, 0.06))
    if variant == 3:  # gorjeio sobe e desce
        parts = []
        for _ in range(10):
            f1, f2 = rng.uniform(2500, 4500, 2)
            parts += [note(f1, f2, rng.uniform(0.05, 0.1)), silence(0.02)]
        return concat(*parts)
    return concat(note(4100, 4000, 0.25, 6, 40), silence(0.08), note(3300, 3200, 0.3, 6, 40))  # assobio de duas notas


def crow(variant):
    rng = np.random.default_rng(20 + variant)
    parts = []
    for _ in range(rng.integers(2, 4)):
        dur = rng.uniform(0.3, 0.42)
        m = int(dur * SR)
        t = np.arange(m) / SR
        jitter = band_oneshot(rng.standard_normal(m), 20, 80)
        f0 = rng.uniform(380, 450) * (1 - 0.18 * t / dur) * (1 + 0.03 * jitter / (np.std(jitter) + 1e-9))
        x = tone(f0, [(k, 1.0 / k) for k in range(1, 26)])
        rough = band_oneshot(rng.standard_normal(m), 30, 150)
        x *= 1 + 0.35 * rough / (np.std(rough) + 1e-9)
        x = formants(x, [(1150, 300, 1.0), (1850, 350, 0.8), (2900, 500, 0.4)])
        x = peak_norm(x) + 0.12 * peak_norm(band_oneshot(rng.standard_normal(m), 800, 3500))
        env = np.minimum(t / 0.015, 1.0) * np.minimum((dur - t) / 0.08, 1.0)
        parts += [x * env, silence(rng.uniform(0.18, 0.3))]
    return concat(*parts)


def woodpecker():
    rng = np.random.default_rng(30)
    out = np.zeros(int(1.8 * SR))
    t_hit = 0.0
    hits = 18
    for i in range(hits):
        t = np.arange(int(0.05 * SR)) / SR
        knock = np.zeros(len(t))
        for f, decay, amp in ((rng.uniform(850, 1000), 0.012, 1.0), (rng.uniform(1550, 1750), 0.008, 0.6), (rng.uniform(2600, 2900), 0.005, 0.3)):
            knock += amp * np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / decay)
        start = int(t_hit * SR)
        out[start:start + len(knock)] += knock * (1 - 0.35 * i / hits)
        t_hit += 0.055 + 0.015 * i / hits
    return out


def wolf_howl():
    rng = np.random.default_rng(40)
    dur = 5.0
    t = np.arange(int(dur * SR)) / SR
    rise = smoothstep(0.0, 0.9, t)
    fall = smoothstep(3.6, 5.0, t)
    freq = 300 + 260 * rise - 40 * smoothstep(0.9, 3.6, t) - 140 * fall
    freq += 7 * np.sin(TAU * 5.2 * t) * smoothstep(1.0, 1.6, t)
    x = tone(freq, ((1, 1.0), (2, 0.35), (3, 0.12), (4, 0.05)))
    x += 0.06 * peak_norm(band_oneshot(rng.standard_normal(len(t)), 500, 1800))
    env = np.sin(0.5 * np.pi * np.minimum(t / 0.5, 1.0)) * np.minimum((dur - t) / 1.2, 1.0)
    return x * env


def drip(variant):
    rng = np.random.default_rng(50 + variant)
    t = np.arange(int(0.6 * SR)) / SR
    f0 = rng.uniform(800, 1300)
    f1 = f0 * rng.uniform(1.6, 2.3)
    freq = f0 + (f1 - f0) * np.minimum(t / rng.uniform(0.015, 0.03), 1.0) ** 0.7
    x = tone(freq) * np.exp(-t / rng.uniform(0.03, 0.06)) * np.minimum(t / 0.001, 1.0)
    click = burst(rng, 0.004, 0.0008, 0.0001)
    x[: len(click)] += 0.3 * click
    return x


# --- Árvore caindo e vozes de bichos (caça) -----------------------------------------





def rabbit_squeal():
    t = np.arange(int(0.3 * SR)) / SR
    freq = 2300 - 800 * t / t[-1] + 60 * np.sin(TAU * 30 * t)
    return tone(freq, ((1, 1.0), (2, 0.3))) * np.sin(np.pi * t / t[-1]) ** 0.5


# --- Corpo, fogo e caverna (sobrevivência) ------------------------------------------





def sizzle_loop(seconds=6):
    """Carne chiando no fogo: chiado agudo que oscila e estalinhos de gordura."""
    rng = np.random.default_rng(160)
    n = seconds * SR
    hiss = band(periodic_noise(n, rng), 2500, 9500) * slow_env(n, rng, 6, 30, 0.45, 1.0)
    pops = place_events(n, rng.uniform(0, n, 22 * seconds),
                        lambda: burst(rng, rng.uniform(0.002, 0.008), rng.uniform(0.0005, 0.002), 0.0001) * rng.lognormal(0, 0.7))
    pops = band(pops, 1500, 8000)
    return rms_norm(hiss) * 0.6 + 0.5 * peak_norm(pops)


def moss_fall():
    """Musgo descolando da rocha: um rasgo úmido, terra esfarelando e o baque mole no chão."""
    rng = np.random.default_rng(170)
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    tear = band_oneshot(rng.standard_normal(n), 400, 3000) * smoothstep(0.0, 0.08, t) * (1 - smoothstep(0.25, 0.45, t))
    crumbs = place_events(n, rng.uniform(0.05 * SR, 1.1 * SR, 60), lambda: burst(rng, 0.015, 0.003, 0.0003) * rng.uniform(0.1, 0.6))
    crumbs = band_oneshot(crumbs, 1200, 7000)
    hit_t = np.maximum(t - 0.8, 0)
    thud = band_oneshot(rng.standard_normal(n), 50, 500) * np.exp(-hit_t / 0.12) * (t >= 0.8)
    patter = place_events(n, rng.uniform(0.85 * SR, 1.6 * SR, 25), lambda: burst(rng, 0.02, 0.005, 0.0005) * rng.uniform(0.1, 0.4))
    patter = band_oneshot(patter, 600, 4000)
    return 0.5 * peak_norm(tear) + 0.45 * peak_norm(crumbs) + peak_norm(thud) + 0.35 * peak_norm(patter)


# --- Noite e perigo -----------------------------------------------------------------

def crickets_loop(seconds=12):
    """Grilos: trinados curtos e regulares em poucas notas, uns longe, outros perto."""
    rng = np.random.default_rng(180)
    n = seconds * SR
    out = np.zeros(n)
    for k in range(6):
        freq = rng.uniform(3800, 5200)
        chirp_rate = rng.uniform(1.6, 3.2)
        pulses = int(rng.integers(3, 5))
        gain = rng.uniform(0.25, 1.0) / (1 + k * 0.3)
        period = 1.0 / chirp_rate
        t0 = rng.uniform(0, period)
        while t0 < seconds:
            for p in range(pulses):
                dur = 0.018
                t = np.arange(int(dur * SR)) / SR
                env = np.sin(np.pi * t / dur) ** 2
                pulse = np.sin(TAU * freq * t) * env * gain
                start = int((t0 + p * 0.03) * SR)
                np.add.at(out, (start + np.arange(len(pulse))) % n, pulse)
            t0 += period * rng.uniform(0.92, 1.08)
    return out + 0.02 * peak_norm(band(periodic_noise(n, rng), 3500, 6000))


def owl(variant):
    """Coruja: dois ou três pios graves e redondos ("hu... hu-huuu")."""
    rng = np.random.default_rng(190 + variant)
    pattern = [(0.0, 0.35), (0.75, 0.18), (1.0, 0.6)] if variant == 1 else [(0.0, 0.5), (0.9, 0.7)]
    n = int(2.0 * SR)
    out = np.zeros(n)
    base = rng.uniform(330, 400)
    for start, dur in pattern:
        t = np.arange(int(dur * SR)) / SR
        freq = base * (1.0 + 0.05 * np.sin(np.pi * t / dur)) - 15 * t / dur
        env = np.sin(np.pi * np.minimum(t / dur, 1.0)) ** 0.6
        hoot = tone(freq, ((1, 1.0), (2, 0.12))) * env
        hoot += 0.08 * band_oneshot(rng.standard_normal(len(t)), 300, 900) * env
        s = int(start * SR)
        out[s:s + len(hoot)] += hoot[: n - s]
    return out




def wolf_bite():
    """Mordida: o estalo dos dentes fechando e um rosnado curto."""
    rng = np.random.default_rng(210)
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    snap = band_oneshot(burst(rng, 0.03, 0.004, 0.0003), 1200, 7000)
    snarl_f = 160 * (1 + 0.3 * np.sin(TAU * 7 * t))
    snarl = formants(tone(snarl_f, ((1, 1.0), (2, 0.7), (3, 0.5), (4, 0.3))), [(600, 200, 1.0)])
    snarl *= smoothstep(0.0, 0.03, t) * np.exp(-t / 0.18)
    out = 0.6 * peak_norm(snarl)
    out[: len(snap)] += peak_norm(snap)
    return out










def stone_hit(variant):
    """Pedra caindo: o estalo seco no chão e um rolar curto de cascalho."""
    rng = np.random.default_rng(280 + variant)
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    clack = band_oneshot(burst(rng, 0.05, 0.008, 0.0003), 900, 6000)
    thud = band_oneshot(burst(rng, 0.12, 0.03, 0.001), 60, 600)
    rolls = place_events(n, rng.uniform(0.06 * SR, 0.45 * SR, 14), lambda: burst(rng, 0.012, 0.003, 0.0003) * rng.uniform(0.1, 0.5))
    rolls = band_oneshot(rolls, 1200, 6000) * (1 - smoothstep(0.3, 0.6, t))
    out = 0.5 * peak_norm(rolls)
    out[: len(clack)] += peak_norm(clack)
    out[: len(thud)] += 0.7 * peak_norm(thud)
    return out


def mud_rub():
    """Esfregar lama na pele: chapinhadas moles e o deslizar úmido das mãos."""
    rng = np.random.default_rng(290)
    n = int(2.6 * SR)
    t = np.arange(n) / SR
    slide = band_oneshot(rng.standard_normal(n), 150, 1500) * (0.4 + 0.6 * np.abs(np.sin(TAU * 1.6 * t))) ** 2
    squelch = lambda: band_oneshot(burst(rng, 0.1, 0.03, 0.005), 200, 1800) * (1 + 0.5 * np.sin(TAU * rng.uniform(30, 60) * np.arange(int(0.1 * SR)) / SR))
    squelches = place_events(n, rng.uniform(0, n - 0.12 * SR, 9), squelch)
    env = smoothstep(0.0, 0.2, t) * (1 - smoothstep(2.3, 2.6, t))
    return (0.4 * peak_norm(slide) + peak_norm(squelches)) * env


def snare_snap():
    """Laço fechando: o galho que segura solta com um estalo e a corda chicoteia."""
    rng = np.random.default_rng(300)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    snap = band_oneshot(burst(rng, 0.03, 0.005, 0.0002), 1500, 8000)
    whip = band_oneshot(rng.standard_normal(n), 800, 4000) * smoothstep(0.02, 0.05, t) * np.exp(-np.maximum(t - 0.05, 0) / 0.05)
    out = 0.5 * peak_norm(whip)
    out[: len(snap)] += peak_norm(snap)
    return out


# --- Rachaduras ---------------------------------------------------------------------

def monitor_beep():
    """Um bipe de monitor cardíaco: tom puro de 960 Hz, curto, com ataque e queda limpos."""
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    env = smoothstep(0.0, 0.006, t) * (1 - smoothstep(0.1, 0.16, t))
    return tone(np.full(n, 960.0), ((1, 1.0), (3, 0.05))) * env




def stone_door():
    """Laje de pedra descendo no chão: um ronco de atrito com estalos de cascalho, 3 s."""
    rng = np.random.default_rng(320)
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    grind = band_oneshot(rng.standard_normal(n), 40, 700) * (0.7 + 0.3 * np.sin(TAU * 7.0 * t + np.sin(TAU * 1.3 * t)))
    grit = place_events(n, rng.uniform(0, n - 0.03 * SR, 90), lambda: burst(rng, 0.012, 0.003, 0.0003) * rng.uniform(0.1, 0.7))
    grit = band_oneshot(grit, 1200, 6000)
    end = np.maximum(t - 2.9, 0)
    thud = band_oneshot(rng.standard_normal(n), 40, 400) * np.exp(-end / 0.1) * (t >= 2.9)
    env = smoothstep(0.0, 0.3, t) * (1 - smoothstep(2.8, 2.95, t))
    return peak_norm(grind) * env + 0.4 * peak_norm(grit) * env + 0.9 * peak_norm(thud)


def stone_click(variant):
    """Disco de pedra girando um dente: raspão curto e o clique da trava."""
    rng = np.random.default_rng(330 + variant)
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    scrape = band_oneshot(rng.standard_normal(n), 500, 4000) * smoothstep(0.0, 0.02, t) * (1 - smoothstep(0.08, 0.12, t))
    click = band_oneshot(burst(rng, 0.03, 0.004, 0.0002), 1500, 7000)
    out = 0.5 * peak_norm(scrape)
    start = int(0.1 * SR)
    out[start:start + len(click)] += peak_norm(click)[: n - start]
    return out






def servo():
    """Servo do braço do Zelador: um gemido que sobe e desce, com dente de engrenagem."""
    rng = np.random.default_rng(420)
    n = int(0.7 * SR)
    t = np.arange(n) / SR
    pitch = 620 + 260 * np.sin(np.pi * t / 0.7) ** 2
    whine = tone(pitch, ((1, 1.0), (2, 0.4), (3, 0.3), (5, 0.1)))
    gears = band_oneshot(rng.standard_normal(n), 2000, 6000) * (0.5 + 0.5 * np.sin(TAU * 140 * t)) ** 4
    env = smoothstep(0.0, 0.05, t) * (1 - smoothstep(0.6, 0.7, t))
    return (peak_norm(whine) + 0.3 * peak_norm(gears)) * env


def wheel_loop(seconds=4):
    """A roda do Zelador no concreto: ronco grave com o tique da emenda do piso."""
    rng = np.random.default_rng(430)
    n = seconds * SR
    rumble = band(periodic_noise(n, rng, beta=1.2), 30, 260)
    motor = tone(np.full(n, 180.0), ((1, 1.0), (2, 0.5), (3, 0.2)))
    ticks = place_events(n, np.arange(0, n, int(0.5 * SR)), lambda: band_oneshot(burst(rng, 0.03, 0.006, 0.0005), 600, 3000))
    return rms_norm(rumble) + 0.3 * rms_norm(motor) + 0.35 * peak_norm(ticks)


def keeper_beep():
    """O bipe de passo do Zelador: dois tons curtos e limpos, um acima do outro."""
    parts = []
    for f in (1400.0, 1850.0):
        n = int(0.06 * SR)
        t = np.arange(n) / SR
        parts.append(tone(np.full(n, f), ((1, 1.0), (2, 0.08))) * smoothstep(0.0, 0.004, t) * (1 - smoothstep(0.045, 0.06, t)))
        parts.append(silence(0.025))
    return concat(*parts)


def keeper_voice(variant):
    """A voz do Zelador sem dublagem: sílabas de vogais sintéticas num zumbido de alto-falante
    pequeno, com um bipe no fim de cada frase."""
    rng = np.random.default_rng(440 + variant)
    vowels = [(730, 1090, 2440), (270, 2290, 3010), (300, 870, 2240), (530, 1840, 2480), (570, 840, 2410)]
    parts = []
    syllables = (6, 9)[variant - 1]
    for i in range(syllables):
        dur = rng.uniform(0.12, 0.2)
        n = int(dur * SR)
        t = np.arange(n) / SR
        f0 = 118 * (1.0 - 0.12 * i / syllables) * (1 + 0.04 * np.sin(TAU * 5 * t))
        carrier = tone(f0, tuple((k, 1.0 / k) for k in range(1, 40)))
        f1, f2, f3 = vowels[rng.integers(len(vowels))]
        voiced = formants(carrier, [(f1, 90, 1.0), (f2, 120, 0.6), (f3, 160, 0.3)])
        env = smoothstep(0.0, 0.02, t) * (1 - smoothstep(dur - 0.04, dur, t))
        parts.append(peak_norm(voiced) * env)
        parts.append(silence(rng.uniform(0.02, 0.06)))
    voice = concat(*parts)
    # Alto-falante pequeno: sem graves, sem brilho, um pouco quantizado.
    voice = band_oneshot(voice, 350, 3200)
    voice = np.round(peak_norm(voice) * 24) / 24
    return concat(voice, silence(0.08), 0.4 * keeper_beep())




def stuck_buzz():
    """O áudio de um programa travado: um pedacinho de 46 ms do som do jogo (vento, fogo, o
    zumbido do mundo) repetindo sem parar, o que soa como um zumbido áspero de 22 Hz. Loop."""
    rng = np.random.default_rng(510)
    grain_n = int(0.046 * SR)
    t = np.arange(grain_n) / SR
    wind = band_oneshot(rng.standard_normal(grain_n), 150, 2500)
    hum = tone(np.full(grain_n, 130.0), ((1, 1.0), (2, 0.6), (3, 0.4), (5, 0.2)))
    crack = place_events(grain_n, [int(0.012 * SR), int(0.031 * SR)], lambda: band_oneshot(burst(rng, 0.004, 0.001, 0.0002), 800, 6000))
    grain = 0.6 * peak_norm(wind) + 0.5 * peak_norm(hum) + 0.7 * peak_norm(crack)
    # A emenda do buffer estala um pouco, como de verdade: sem suavizar a borda.
    grain *= 0.85 + 0.15 * np.sin(np.pi * t / t[-1])
    return np.tile(grain, 44)


def wall_scratch(variant):
    """Uma pedra arrastada na rocha: um raspado áspero e granulado, de 0,3 s."""
    rng = np.random.default_rng(520 + variant)
    dur = (0.32, 0.26)[variant - 1]
    n = int(dur * SR)
    t = np.arange(n) / SR
    grit = band_oneshot(rng.standard_normal(n), 1400, 6500)
    # A pedra pula e agarra: o volume treme rápido, em grãos.
    judder = np.abs(np.sin(TAU * rng.uniform(38, 55) * t + 2.0 * np.sin(TAU * 7.0 * t))) ** 1.5
    body = band_oneshot(rng.standard_normal(n), 250, 1200) * 0.35
    env = smoothstep(0.0, 0.03, t) * (1 - smoothstep(dur - 0.12, dur, t))
    return (peak_norm(grit) * (0.4 + 0.6 * judder) + body) * env








def crowd_loop(seconds=10):
    """Vozes ao longe (Final 2): gente conversando numa praça, sílabas de vogais de muitas pessoas
    misturadas, sem palavra nenhuma, abafadas pela neblina e pela distância. Loop."""
    rng = np.random.default_rng(560)
    n = int(seconds * SR)
    vowels = [(730, 1090, 2440), (270, 2290, 3010), (300, 870, 2240), (530, 1840, 2480), (570, 840, 2410), (440, 1020, 2240)]
    out = np.zeros(n)
    for voice in range(10):
        pitch = rng.uniform(95, 240)
        level = rng.uniform(0.3, 1.0)
        cursor = rng.uniform(0, n)
        talked = 0
        while talked < n * 0.55:
            words = rng.integers(3, 9)
            for _ in range(words):
                dur = rng.uniform(0.09, 0.22)
                m = int(dur * SR)
                tt = np.arange(m) / SR
                f0 = pitch * (1 + 0.08 * np.sin(TAU * rng.uniform(2, 5) * tt) + rng.uniform(-0.06, 0.06))
                carrier = tone(f0, tuple((k, 1.0 / k) for k in range(1, 24)))
                f1, f2, f3 = vowels[rng.integers(len(vowels))]
                syllable = formants(carrier, [(f1, 90, 1.0), (f2, 130, 0.5), (f3, 170, 0.2)])
                syllable = peak_norm(syllable) * smoothstep(0.0, 0.025, tt) * (1 - smoothstep(dur - 0.05, dur, tt)) * level
                np.add.at(out, (int(cursor) + np.arange(m)) % n, syllable)
                cursor += m + rng.uniform(0.01, 0.05) * SR
                talked += m
            cursor += rng.uniform(0.3, 1.6) * SR
    # Uma risada de criança de vez em quando, aguda e curta.
    for at in rng.uniform(0, n, 2):
        for k in range(5):
            m = int(0.09 * SR)
            tt = np.arange(m) / SR
            laugh = formants(tone(np.full(m, 330.0 - 12 * k), tuple((j, 1.0 / j) for j in range(1, 14))), [(800, 100, 1.0), (1500, 150, 0.5)])
            laugh = peak_norm(laugh) * np.sin(np.pi * tt / (m / SR)) * 0.6
            np.add.at(out, (int(at + k * 0.14 * SR) + np.arange(m)) % n, laugh)
    out = band(out, 150, 1600)
    return out + 0.08 * peak_norm(band(periodic_noise(n, rng, 1.0), 80, 600))


# --- Caça e vida na toca (F9) ------------------------------------------------------

def rain_loop(seconds=16):
    """Chuva: um chiado largo (a chuva longe, nas folhas) com gotas batendo perto, umas mais
    graves (no chão) e outras agudas (nas folhas). Loop."""
    rng = np.random.default_rng(900)
    n = seconds * SR
    swell = slow_env(n, rng, 1, 4, 0.7, 1.0)
    hiss = band(periodic_noise(n, rng, beta=0.4), 400, 7000) * swell
    patter = band(periodic_noise(n, rng), 2500, 9000) * swell
    times = thinned_times(rng, n, 220, swell)
    drops = place_events(n, times, lambda: burst(rng, rng.uniform(0.003, 0.012), rng.uniform(0.002, 0.01)) * rng.uniform(0.1, 1.0))
    drops = band(drops, 900, 8000)
    thuds = place_events(n, thinned_times(rng, n, 25, swell), lambda: burst(rng, 0.03, 0.015) * rng.uniform(0.2, 0.7))
    thuds = band(thuds, 120, 900)
    return rms_norm(hiss) + 0.35 * rms_norm(patter) + 0.6 * rms_norm(drops) + 0.3 * rms_norm(thuds)




def boar_grunt(variant):
    """Grunhido do javali: roncos curtos e graves pelo nariz, em série."""
    rng = np.random.default_rng(910 + variant)
    out = []
    for _ in range(rng.integers(2, 5)):
        dur = rng.uniform(0.12, 0.25)
        m = int(dur * SR)
        t = np.arange(m) / SR
        f = rng.uniform(70, 95) * (1 - 0.15 * t / dur)
        voice = tone(f, tuple((k, 1.0 / k ** 0.7) for k in range(1, 14)))
        rough = 0.5 + 0.5 * np.sign(np.sin(TAU * rng.uniform(18, 30) * t))
        nose = band_oneshot(rng.standard_normal(m), 200, 1800)
        x = formants(voice * rough, [(300, 120, 1.0), (750, 180, 0.4)]) + 0.3 * peak_norm(nose)
        out.append(peak_norm(x) * np.sin(np.pi * t / dur) ** 0.6)
        out.append(silence(rng.uniform(0.05, 0.16)))
    return band_oneshot(np.concatenate(out), 50, 3000)




def cricket_song(seconds=4):
    """Um grilo só: trinados de 3 a 4 pulsos num ritmo firme (o InsectField varia o tom por grilo)."""
    rng = np.random.default_rng(200)
    n = seconds * SR
    out = np.zeros(n)
    freq = 4600.0
    period = seconds / 10.0
    for c in range(10):
        t0 = c * period
        for p in range(4 if c % 3 else 3):
            dur = 0.017
            t = np.arange(int(dur * SR)) / SR
            env = np.sin(np.pi * t / dur) ** 2
            pulse = (np.sin(TAU * freq * t) + 0.12 * np.sin(TAU * 2 * freq * t)) * env * rng.uniform(0.85, 1.0)
            start = int((t0 + p * 0.028) * SR)
            np.add.at(out, (start + np.arange(len(pulse))) % n, pulse)
    return out


def grasshopper_song(seconds=8):
    """Um gafanhoto só: rajadas de raspado (perna na asa) com pausas, no capim de dia."""
    rng = np.random.default_rng(201)
    n = seconds * SR
    out = np.zeros(n)
    t0 = 0.2
    while t0 < seconds - 0.3:
        dur = rng.uniform(0.5, 1.5)
        rate = rng.uniform(22, 30)
        t = np.arange(int(dur * SR)) / SR
        pulses = (0.5 + 0.5 * np.sin(TAU * rate * t)) ** 5
        env = np.minimum(t / 0.06, 1.0) * np.minimum((dur - t) / 0.12, 1.0)
        rasp = band_oneshot(rng.standard_normal(len(t)), 5000, 9000)
        rasp = rasp / (np.std(rasp) + 1e-9)
        chirp = (0.6 * rasp + np.sin(TAU * 6200 * t + 0.4 * np.sin(TAU * 110 * t))) * pulses * env
        np.add.at(out, (int(t0 * SR) + np.arange(len(chirp))) % n, chirp)
        t0 += dur + rng.uniform(0.8, 2.6)
    return out


def bird_alarm():
    """O pio de alarme do passarinho espantado: dois ou três "tchik" secos."""
    rng = np.random.default_rng(202)
    parts = []
    for _ in range(3):
        parts += [note(rng.uniform(6200, 6800), rng.uniform(3800, 4200), 0.035, harm=0.3), silence(rng.uniform(0.08, 0.12))]
    return concat(*parts)


def write_ambient_life():
    """Os sons dos bichos do ambiente (dá para gerar só eles: python -c "import generate_sounds as g; g.write_ambient_life()")."""
    write_wav(ROOT / "animals" / "cricket_song.wav", cricket_song(), loop=True)
    write_wav(ROOT / "animals" / "grasshopper_song.wav", grasshopper_song(), loop=True)
    write_wav(ROOT / "animals" / "bird_alarm.wav", bird_alarm())


def main():
    print("Gerando sons em", ROOT)
    write_wav(ROOT / "ambience" / "wind_loop.wav", wind_loop(), loop=True)
    write_wav(ROOT / "ambience" / "cave_loop.wav", cave_loop(), loop=True)
    write_wav(ROOT / "ambience" / "grasshoppers_loop.wav", grasshoppers_loop(), loop=True)
    for v in range(1, 5):
        write_wav(ROOT / "animals" / f"bird_{v}.wav", bird(v))
    # crow_1 é gravação real (assets/audio/real/crow_caw.ogg).
    write_wav(ROOT / "animals" / "crow_2.wav", crow(2))
    write_wav(ROOT / "animals" / "woodpecker.wav", woodpecker())
    write_wav(ROOT / "animals" / "wolf_howl.wav", wolf_howl())
    for v in range(1, 4):
        write_wav(ROOT / "sfx" / f"drip_{v}.wav", drip(v))
    write_wav(ROOT / "animals" / "rabbit_squeal.wav", rabbit_squeal())
    write_wav(ROOT / "ambience" / "sizzle_loop.wav", sizzle_loop(), loop=True)
    write_wav(ROOT / "sfx" / "moss_fall.wav", moss_fall())
    write_wav(ROOT / "ambience" / "crickets_loop.wav", crickets_loop(), loop=True)
    for v in range(1, 3):
        write_wav(ROOT / "animals" / f"owl_{v}.wav", owl(v))
    write_wav(ROOT / "animals" / "wolf_bite.wav", wolf_bite())
    write_wav(ROOT / "sfx" / "heartbeat.wav", heartbeat())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"stone_hit_{v}.wav", stone_hit(v))
    write_wav(ROOT / "sfx" / "mud_rub.wav", mud_rub())
    write_wav(ROOT / "sfx" / "snare_snap.wav", snare_snap())
    write_wav(ROOT / "sfx" / "monitor_beep.wav", monitor_beep())
    write_wav(ROOT / "sfx" / "stone_door.wav", stone_door())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"stone_click_{v}.wav", stone_click(v))
    write_wav(ROOT / "ambience" / "shelter_loop.wav", shelter_loop(), loop=True)
    write_wav(ROOT / "sfx" / "servo.wav", servo())
    write_wav(ROOT / "ambience" / "wheel_loop.wav", wheel_loop(), loop=True)
    write_wav(ROOT / "sfx" / "keeper_beep.wav", keeper_beep())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"keeper_voice_{v}.wav", keeper_voice(v))
    write_wav(ROOT / "sfx" / "stuck_buzz.wav", stuck_buzz(), loop=True)
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"wall_scratch_{v}.wav", wall_scratch(v))
    write_wav(ROOT / "ambience" / "crowd_loop.wav", crowd_loop(), loop=True)
    write_f9()
    write_ambient_life()


def write_f9():
    """Os sons da F9 (dá para gerar só eles: python -c "import generate_sounds as g; g.write_f9()")."""
    write_wav(ROOT / "ambience" / "rain_loop.wav", rain_loop(), loop=True)
    for v in range(1, 3):
        write_wav(ROOT / "animals" / f"boar_grunt_{v}.wav", boar_grunt(v))


if __name__ == "__main__":
    main()
