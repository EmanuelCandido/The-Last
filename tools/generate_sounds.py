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


def leaves_loop(seconds=16):
    rng = np.random.default_rng(2)
    n = seconds * SR
    gust = slow_env(n, rng, 1, 5)
    hiss = band(periodic_noise(n, rng), 1800, 8500) * (0.25 + 0.75 * gust)
    times = thinned_times(rng, n, 140, gust**1.5)
    crackle = place_events(n, times, lambda: burst(rng, rng.uniform(0.004, 0.02), rng.uniform(0.002, 0.008)) * rng.uniform(0.2, 1.0))
    crackle = band(crackle, 2000, 9000)
    return 0.5 * rms_norm(hiss) + rms_norm(crackle)


def fire_loop(seconds=12):
    rng = np.random.default_rng(3)
    n = seconds * SR
    flicker = slow_env(n, rng, 20, 80, 0.6, 1.0) * slow_env(n, rng, 2, 6, 0.7, 1.0)
    roar = band(periodic_noise(n, rng, beta=1.0), 40, 400) * flicker
    cracks = place_events(n, rng.uniform(0, n, 7 * seconds),
                          lambda: burst(rng, rng.uniform(0.003, 0.012), rng.uniform(0.0008, 0.004), 0.0002) * rng.lognormal(0, 0.6))
    cracks = band(cracks, 900, 7000)
    pops = place_events(n, rng.uniform(0, n, seconds // 2),
                        lambda: burst(rng, 0.05, rng.uniform(0.008, 0.02), 0.0003) * rng.uniform(1.5, 3.0))
    pops = band(pops, 300, 4000)
    hiss = band(periodic_noise(n, rng), 3000, 9000) * flicker
    return 0.18 * rms_norm(roar) + 0.7 * peak_norm(cracks) + 0.6 * peak_norm(pops) + 0.02 * rms_norm(hiss)


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

def tree_fall():
    """Estalos e rangido enquanto tomba, depois o baque no chão (~3 s)."""
    rng = np.random.default_rng(96)
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    creak = np.zeros(n)
    for fc in (180, 260, 390):
        creak += band_oneshot(rng.standard_normal(n), fc * 0.96, fc * 1.04, edge=0.03)
    creak *= (0.5 + 0.5 * np.sin(TAU * 11 * t) ** 2) * smoothstep(0.0, 0.4, t) * (1 - smoothstep(1.4, 1.75, t))
    cracks = place_events(n, rng.uniform(0, 1.6 * SR, 14), lambda: burst(rng, 0.03, 0.006, 0.0003) * rng.uniform(0.3, 1.0))
    cracks[int(1.8 * SR):] = 0
    cracks = band_oneshot(cracks, 800, 6000)
    impact_t = np.maximum(t - 1.75, 0)
    impact = band_oneshot(rng.standard_normal(n), 40, 700) * np.exp(-impact_t / 0.35) * (t >= 1.75)
    rumble = tone(np.full(n, 55.0)) * np.exp(-impact_t / 0.5) * (t >= 1.75)
    branches = place_events(n, rng.uniform(1.75 * SR, 2.4 * SR, 25), lambda: burst(rng, 0.04, 0.01, 0.0005) * rng.uniform(0.2, 0.8))
    branches = band_oneshot(branches, 1000, 7000)
    return 0.5 * peak_norm(creak) + 0.6 * peak_norm(cracks) + peak_norm(impact) + 0.6 * peak_norm(rumble) + 0.5 * peak_norm(branches)


def deer_snort():
    rng = np.random.default_rng(97)
    t = np.arange(int(0.4 * SR)) / SR
    breath = formants(rng.standard_normal(len(t)), [(600, 200, 1.0), (1400, 300, 0.6)])
    return peak_norm(breath) * np.minimum(t / 0.01, 1.0) * np.exp(-t / 0.12)


def rabbit_squeal():
    t = np.arange(int(0.3 * SR)) / SR
    freq = 2300 - 800 * t / t[-1] + 60 * np.sin(TAU * 30 * t)
    return tone(freq, ((1, 1.0), (2, 0.3))) * np.sin(np.pi * t / t[-1]) ** 0.5


# --- Corpo, fogo e caverna (sobrevivência) ------------------------------------------

def stomach_growl(variant):
    """Ronco da barriga: um tom grave que sobe e desce, borbulhando, com bolhas soltas."""
    rng = np.random.default_rng(140 + variant)
    dur = rng.uniform(1.1, 1.6)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = rng.uniform(70, 105) * (1 + 0.3 * np.sin(TAU * rng.uniform(0.6, 1.2) * t + rng.uniform(0, TAU))
                                + 0.08 * np.sin(TAU * rng.uniform(5, 8) * t))
    voice = tone(f, ((1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2), (5, 0.1)))
    # Borbulha: o tom vem em golfadas irregulares, não contínuo.
    gurgle = (0.55 + 0.45 * np.sin(TAU * rng.uniform(9, 15) * t + 2.0 * np.sin(TAU * 3.1 * t))) ** 2
    bubble = lambda: tone(np.full(int(0.05 * SR), rng.uniform(180, 420))) * np.exp(-np.arange(int(0.05 * SR)) / SR / 0.012)
    bubbles = place_events(n, rng.uniform(0, n, rng.integers(5, 10)), bubble)
    env = np.sin(np.pi * t / dur) ** 0.7 * (1 - 0.4 * smoothstep(0.5, 0.7, t / dur) * smoothstep(0.9, 0.7, t / dur))
    x = formants(voice * gurgle, [(160, 70, 1.0), (380, 110, 0.6), (700, 150, 0.2)]) * env
    return band_oneshot(peak_norm(x) + 0.25 * peak_norm(bubbles) * env, 40, 1200)


def chew(variant):
    """Mastigar carne: mordidas úmidas e abafadas, cada uma com um estalo de fibra."""
    rng = np.random.default_rng(150 + variant)
    n = int(0.9 * SR)
    out = np.zeros(n)
    for k in range(4):
        start = int((0.08 + k * 0.2 + rng.uniform(-0.03, 0.03)) * SR)
        squish = band_oneshot(burst(rng, 0.12, rng.uniform(0.03, 0.05), 0.008), 300, 2500) * rng.uniform(0.6, 1.0)
        fiber = band_oneshot(burst(rng, 0.02, 0.004, 0.0005), 1500, 6000) * rng.uniform(0.2, 0.5)
        thump = tone(np.full(int(0.08 * SR), rng.uniform(90, 130))) * np.exp(-np.arange(int(0.08 * SR)) / SR / 0.02)
        for ev, gain in ((squish, 1.0), (fiber, 0.6), (thump, 0.4)):
            end = min(n, start + len(ev))
            out[start:end] += gain * peak_norm(ev)[: end - start]
    return out


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


def wolf_growl(variant):
    """Rosnado: um ronco grave e áspero que sobe e desce, com a respiração por trás."""
    rng = np.random.default_rng(200 + variant)
    dur = rng.uniform(1.2, 1.8)
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = rng.uniform(85, 110) * (1 + 0.12 * np.sin(TAU * rng.uniform(0.8, 1.5) * t))
    voice = tone(f, ((1, 1.0), (2, 0.8), (3, 0.6), (4, 0.4), (5, 0.3), (6, 0.2)))
    rough = 0.6 + 0.4 * np.sign(np.sin(TAU * rng.uniform(25, 40) * t))
    breath = band_oneshot(rng.standard_normal(n), 300, 2500)
    env = smoothstep(0.0, 0.15, t) * (1 - smoothstep(dur - 0.3, dur, t))
    x = formants(voice * rough, [(400, 150, 1.0), (900, 200, 0.5)]) + 0.25 * peak_norm(breath)
    return band_oneshot(peak_norm(x) * env, 50, 3000)


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


def wolf_yelp():
    """Ganido de lobo ferido: agudo, caindo rápido, duas vezes."""
    out = []
    for dur, f0 in ((0.28, 1300), (0.4, 1150)):
        t = np.arange(int(dur * SR)) / SR
        freq = f0 - 600 * (t / dur) ** 0.7
        out.append(tone(freq, ((1, 1.0), (2, 0.4), (3, 0.15))) * np.sin(np.pi * t / dur) ** 0.5)
        out.append(silence(0.08))
    return concat(*out)


def teeth_chatter():
    """Dentes batendo de frio: estalinhos rápidos e irregulares."""
    rng = np.random.default_rng(220)
    n = int(1.4 * SR)
    times = np.cumsum(rng.uniform(0.045, 0.08, 30)) * SR
    clicks = place_events(n, times[times < n - 400], lambda: burst(rng, 0.008, 0.0015, 0.0002) * rng.uniform(0.4, 1.0))
    t = np.arange(n) / SR
    return band_oneshot(clicks, 1500, 7000) * smoothstep(0.0, 0.1, t) * (1 - smoothstep(1.1, 1.4, t))


# --- Caça completa ------------------------------------------------------------------

def heartbeat():
    """Uma batida do coração ouvida por dentro: dois baques graves e abafados (tum-tum)."""
    rng = np.random.default_rng(230)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for start, gain, f0 in ((0.0, 1.0, 52), (0.17, 0.65, 46)):
        local = np.maximum(t - start, 0)
        thump = tone(f0 * (1 + 0.6 * np.exp(-local / 0.02))) * (t >= start) * np.exp(-local / 0.06) * np.minimum(local / 0.004, 1)
        out += gain * thump
    out += 0.08 * band_oneshot(rng.standard_normal(n), 30, 200) * np.exp(-t / 0.08)
    return band_oneshot(out, 20, 260)


def breath_in():
    """Puxar o ar pelo nariz e prender: um chiado curto que sobe e corta seco."""
    rng = np.random.default_rng(240)
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    air = formants(rng.standard_normal(n), [(900, 300, 1.0), (2400, 500, 0.6), (4200, 700, 0.3)])
    return band_oneshot(air, 300, 6000) * smoothstep(0.0, 0.35, t) * (1 - smoothstep(0.46, 0.5, t))


def gasp():
    """Soltar o ar preso: um bufo forte pela boca e duas puxadas ofegantes."""
    rng = np.random.default_rng(250)
    parts = []
    for dur, lo, hi, gain in ((0.45, 200, 3500, 1.0), (0.3, 400, 5000, 0.55), (0.32, 400, 5000, 0.5)):
        n = int(dur * SR)
        t = np.arange(n) / SR
        air = formants(rng.standard_normal(n), [(700, 250, 1.0), (1500, 400, 0.7), (2800, 600, 0.3)])
        env = smoothstep(0.0, 0.04, t) * np.exp(-t / (dur * 0.45))
        parts.append(gain * peak_norm(band_oneshot(air, lo, hi)) * env)
        parts.append(silence(0.12))
    return concat(*parts)


def sniff():
    """Farejar: três fungadas curtas e úmidas, a última mais longa."""
    rng = np.random.default_rng(260)
    parts = []
    for dur in (0.09, 0.08, 0.16):
        n = int(dur * SR)
        t = np.arange(n) / SR
        air = formants(rng.standard_normal(n), [(1800, 500, 1.0), (3500, 700, 0.6)])
        parts.append(peak_norm(band_oneshot(air, 600, 7000)) * np.sin(np.pi * t / dur) ** 0.6)
        parts.append(silence(0.06))
    return concat(*parts)


def stone_throw():
    """Pedra saindo da mão: um zunido curto de ar."""
    rng = np.random.default_rng(270)
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    whoosh = band_oneshot(rng.standard_normal(n), 250, 1800) * np.sin(np.pi * np.minimum(t / 0.3, 1)) ** 2
    return whoosh


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


def fan_hum():
    """Ventilador vazando: zumbido grave de 110 Hz com o chiado ritmado da hélice, 3 s."""
    rng = np.random.default_rng(310)
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    hum = tone(np.full(n, 110.0), ((1, 1.0), (2, 0.5), (3, 0.25), (4, 0.12)))
    chop = band_oneshot(rng.standard_normal(n), 400, 3000) * (0.5 + 0.5 * np.sin(TAU * 18.0 * t)) ** 3
    env = smoothstep(0.0, 0.6, t) * (1 - smoothstep(2.3, 3.0, t))
    return (peak_norm(hum) + 0.35 * peak_norm(chop)) * env


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


def wing_flap():
    """Corvo levantando voo: três batidas de asa abafadas."""
    rng = np.random.default_rng(340)
    parts = []
    for gap in (0.0, 0.11, 0.13):
        parts.append(silence(gap))
        flap = band_oneshot(burst(rng, 0.09, 0.025, 0.006), 150, 2200)
        parts.append(peak_norm(flap) * rng.uniform(0.7, 1.0))
    return concat(*parts)


# --- O Abrigo -----------------------------------------------------------------------

def shelter_loop(seconds=12):
    """Ar parado de sala fechada: o zumbido de 50 Hz da rede, a ventilação e o concreto."""
    rng = np.random.default_rng(400)
    n = seconds * SR
    t = np.arange(n) / SR
    mains = tone(np.full(n, 50.0), ((1, 1.0), (2, 0.6), (3, 0.35), (4, 0.15), (6, 0.06)))
    vent = band(periodic_noise(n, rng, beta=0.8), 90, 900) * slow_env(n, rng, 1, 3, 0.7, 1.0)
    rattle = band(periodic_noise(n, rng), 1800, 3200, edge=0.06) * (0.5 + 0.5 * np.sin(TAU * 0.25 * t)) ** 6
    return 0.5 * rms_norm(mains) + rms_norm(vent) + 0.08 * rms_norm(rattle)


def light_buzz(seconds=4):
    """Lâmpada fluorescente velha: zumbido áspero de 100 Hz, cheio de harmônicos."""
    rng = np.random.default_rng(410)
    n = seconds * SR
    harmonics = tuple((k, 1.0 / k) for k in range(1, 30))
    buzz = tone(np.full(n, 100.0), harmonics)
    buzz = band(np.sign(buzz) * np.abs(buzz) ** 0.6, 100, 5000)
    hiss = band(periodic_noise(n, rng), 3000, 8000) * slow_env(n, rng, 2, 6, 0.3, 1.0)
    return rms_norm(buzz) + 0.15 * rms_norm(hiss)


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


def blind_rattle():
    """As lâminas da persiana girando: estalinhos de plástico em cascata."""
    rng = np.random.default_rng(450)
    n = int(0.5 * SR)
    times = np.sort(rng.uniform(0, 0.38 * SR, 22))
    clicks = place_events(n, times, lambda: band_oneshot(burst(rng, 0.02, 0.003, 0.0003), 1500, 7000) * rng.uniform(0.3, 1.0))
    return clicks


def main():
    print("Gerando sons em", ROOT)
    write_wav(ROOT / "ambience" / "wind_loop.wav", wind_loop(), loop=True)
    write_wav(ROOT / "ambience" / "leaves_loop.wav", leaves_loop(), loop=True)
    write_wav(ROOT / "ambience" / "fire_loop.wav", fire_loop(), loop=True)
    write_wav(ROOT / "ambience" / "cave_loop.wav", cave_loop(), loop=True)
    write_wav(ROOT / "ambience" / "grasshoppers_loop.wav", grasshoppers_loop(), loop=True)
    for v in range(1, 5):
        write_wav(ROOT / "animals" / f"bird_{v}.wav", bird(v))
    for v in range(1, 3):
        write_wav(ROOT / "animals" / f"crow_{v}.wav", crow(v))
    write_wav(ROOT / "animals" / "woodpecker.wav", woodpecker())
    write_wav(ROOT / "animals" / "wolf_howl.wav", wolf_howl())
    for v in range(1, 4):
        write_wav(ROOT / "sfx" / f"drip_{v}.wav", drip(v))
    write_wav(ROOT / "sfx" / "tree_fall.wav", tree_fall())
    write_wav(ROOT / "animals" / "deer_snort.wav", deer_snort())
    write_wav(ROOT / "animals" / "rabbit_squeal.wav", rabbit_squeal())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"stomach_growl_{v}.wav", stomach_growl(v))
        write_wav(ROOT / "sfx" / f"chew_{v}.wav", chew(v))
    write_wav(ROOT / "ambience" / "sizzle_loop.wav", sizzle_loop(), loop=True)
    write_wav(ROOT / "sfx" / "moss_fall.wav", moss_fall())
    write_wav(ROOT / "ambience" / "crickets_loop.wav", crickets_loop(), loop=True)
    for v in range(1, 3):
        write_wav(ROOT / "animals" / f"owl_{v}.wav", owl(v))
        write_wav(ROOT / "animals" / f"wolf_growl_{v}.wav", wolf_growl(v))
    write_wav(ROOT / "animals" / "wolf_bite.wav", wolf_bite())
    write_wav(ROOT / "animals" / "wolf_yelp.wav", wolf_yelp())
    write_wav(ROOT / "sfx" / "teeth_chatter.wav", teeth_chatter())
    write_wav(ROOT / "sfx" / "heartbeat.wav", heartbeat())
    write_wav(ROOT / "sfx" / "breath_in.wav", breath_in())
    write_wav(ROOT / "sfx" / "gasp.wav", gasp())
    write_wav(ROOT / "sfx" / "sniff.wav", sniff())
    write_wav(ROOT / "sfx" / "stone_throw.wav", stone_throw())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"stone_hit_{v}.wav", stone_hit(v))
    write_wav(ROOT / "sfx" / "mud_rub.wav", mud_rub())
    write_wav(ROOT / "sfx" / "snare_snap.wav", snare_snap())
    write_wav(ROOT / "sfx" / "monitor_beep.wav", monitor_beep())
    write_wav(ROOT / "sfx" / "fan_hum.wav", fan_hum())
    write_wav(ROOT / "sfx" / "stone_door.wav", stone_door())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"stone_click_{v}.wav", stone_click(v))
    write_wav(ROOT / "animals" / "wing_flap.wav", wing_flap())
    write_wav(ROOT / "ambience" / "shelter_loop.wav", shelter_loop(), loop=True)
    write_wav(ROOT / "ambience" / "light_buzz.wav", light_buzz(), loop=True)
    write_wav(ROOT / "sfx" / "servo.wav", servo())
    write_wav(ROOT / "ambience" / "wheel_loop.wav", wheel_loop(), loop=True)
    write_wav(ROOT / "sfx" / "keeper_beep.wav", keeper_beep())
    for v in range(1, 3):
        write_wav(ROOT / "sfx" / f"keeper_voice_{v}.wav", keeper_voice(v))
    write_wav(ROOT / "sfx" / "blind_rattle.wav", blind_rattle())


if __name__ == "__main__":
    main()
