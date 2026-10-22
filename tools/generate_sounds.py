"""Gera os sons sintéticos do jogo em assets/audio/ por síntese procedural.

Passos em grama, pedra e tronco, arco, impactos de flecha, golpe na madeira, coleta e faca
são gravações reais (CC0) em assets/audio/real/ — ver assets/CREDITS.md; este script não
mexe nelas. Os passos em terra e no chão da caverna são sintéticos (pé descalço; as gravações
que havia eram de sapato, com o "toc-toc" de salto e ponta).

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


# --- Passos descalços ---------------------------------------------------------------

def barefoot_step(variant, gravel):
    """Pé descalço de goblin (leve) em terra batida. gravel (0..1) = quanto cascalho tem.

    Calcanhar: baque surdo e o tapa da pele. O peso rola para a frente e a terra cede,
    estalando grãos soltos. Os dedos empurram e arrastam um pouco de terra ao sair.
    """
    rng = np.random.default_rng(400 + variant + int(gravel * 100))
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    # Baque: o chão macio abafa tudo acima de ~300 Hz; o corpo pequeno dá um grave curto.
    thump = band_oneshot(rng.standard_normal(n), 35, rng.uniform(260, 340)) * np.minimum(t / 0.003, 1.0) * np.exp(-t / rng.uniform(0.016, 0.024))
    thump = peak_norm(thump) + 0.35 * tone(np.full(n, rng.uniform(70, 95))) * np.minimum(t / 0.004, 1.0) * np.exp(-t / 0.03)
    # Tapa da pele na terra: médio, curtíssimo e sem estalo.
    pat = band_oneshot(rng.standard_normal(n), 350, 1700) * np.minimum(t / 0.0015, 1.0) * np.exp(-t / 0.007)
    # Rolagem do peso: a terra assenta (grave longo) e grãos estalam soltos, mais no meio.
    settle = band_oneshot(rng.standard_normal(n), 120, 900) * smoothstep(0.005, 0.03, t) * np.exp(-t / 0.06)
    grain_env = np.exp(-0.5 * ((t - rng.uniform(0.05, 0.08)) / 0.035) ** 2)
    grain_env += 0.6 * np.exp(-0.5 * ((t - rng.uniform(0.15, 0.2)) / 0.025) ** 2)
    count = int(rng.uniform(12, 20) * (1.0 + 2.5 * gravel))
    times = thinned_times(rng, n, count / (n / SR) * 2.5, grain_env / grain_env.max())

    def grain():
        g = burst(rng, 0.004, rng.uniform(0.0002, 0.0007 + 0.0008 * gravel), 0.00005)
        return g * np.exp(rng.uniform(np.log(0.15), 0.0))

    grains = band_oneshot(place_events(n, times, grain), 1400 - 500 * gravel, 6500)
    # Saída dos dedos: um arrasto curto de terra.
    toe_at = rng.uniform(0.15, 0.2)
    toe_t = np.maximum(t - toe_at, 0.0)
    scuff = band_oneshot(rng.standard_normal(n), 700, 4500) * (t >= toe_at) * smoothstep(0.0, 0.012, toe_t) * np.exp(-toe_t / 0.03)
    x = (1.0 * peak_norm(thump) + 0.35 * peak_norm(pat) + 0.3 * peak_norm(settle)
         + (0.16 + 0.3 * gravel) * peak_norm(grains) + rng.uniform(0.1, 0.18) * peak_norm(scuff))
    # Sem clique no fim do arquivo.
    return x * (1.0 - smoothstep(0.34, 0.42, t))


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
    for v in range(1, 7):
        write_wav(ROOT / "steps" / f"barefoot_dirt_{v}.wav", barefoot_step(v, 0.15))
        write_wav(ROOT / "steps" / f"barefoot_cave_{v}.wav", barefoot_step(v, 0.7))


if __name__ == "__main__":
    main()
