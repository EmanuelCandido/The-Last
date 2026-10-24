"""Corta e trata as gravações reais (CC0) que substituem sons sintéticos, e grava em assets/audio/real/.

As gravações originais não vão para o repositório: baixe-as (links e autores no assets/CREDITS.md) para
uma pasta e rode

    python tools/process_real_sounds.py --raw=PASTA [nome ...]

Cada som vira mono e, se a gravação tiver mais de 48 kHz, cai para 48 kHz. O trecho escolhido ganha
rampas nas pontas e o mesmo volume do sintético que ele substitui (a medida está em LEVELS), para não
mexer na mixagem do jogo. Os loops viram WAV com o ponto de loop (chunk smpl, que o Godot lê) e uma
emenda cruzada de `xfade` segundos, então o fim encosta no começo sem estalo. Os curtos viram OGG Vorbis.
"""
import struct
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parent.parent / "assets" / "audio"
OUT = ROOT / "real"

# Nível de cada sintético substituído, em dBFS: RMS do loop inteiro (loops) ou da janela de 300 ms
# mais forte (curtos). Medido dos .wav sintéticos antes de saírem do jogo.
LEVELS = {
    "leaves_loop": -25.4, "fire_loop": -14.6, "light_buzz": -10.3, "fan_hum": -7.7, "church_bell": -10.1,
    "wing_flap": -18.2, "crow_1": -14.0, "deer_snort": -15.9, "deer_stomp": -17.5, "boar_squeal": -9.5,
    "wolf_growl_1": -12.6, "wolf_growl_2": -13.1, "breath_in": -11.9, "stomach_growl_1": -11.4,
    "stomach_growl_2": -13.3, "chew_2": -18.0, "tree_fall": -10.8, "stone_throw": -15.7, "blind_rattle": -22.1,
    "glitch": -11.6, "blast_door": -13.4,
    "wolf_yelp": -6.2, "gasp": -15.5, "sniff": -14.3, "chew_1": -18.5, "teeth_chatter": -27.0,
    "wolf_bite": -18.3,
}

# saída: (bruto, sintético substituído, início s, fim s, loop, rampa de entrada s, rampa de saída s)
CUTS = {
    "leaves_wind_loop": ("leaves.ogg", "leaves_loop", 2.0, 34.0, True, 0, 0),
    "campfire_loop": ("fire.ogg", "fire_loop", None, 40.0, True, 0, 0),
    "fluorescent_buzz_loop": ("light_buzz.ogg", "light_buzz", 4.0, 16.0, True, 0, 0),
    "extractor_fan": ("fan.ogg", "fan_hum", 10.0, 18.0, False, 0.8, 1.6),
    "church_bell_toll": ("church_bell.ogg", "church_bell", None, None, False, 0.0, 0.6),
    "wing_flap": ("wing_flap.ogg", "wing_flap", 0.0, 1.36, False, 0.005, 0.15),
    "crow_caw": ("crow.ogg", "crow_1", 0.0, 0.43, False, 0.003, 0.05),
    "deer_snort": ("deer_snort.ogg", "deer_snort", 0.35, 1.05, False, 0.01, 0.12),
    "deer_stomp": ("deer_stomp.ogg", "deer_stomp", 0.45, 1.3, False, 0.003, 0.25),
    "boar_squeal": ("boar_squeal.ogg", "boar_squeal", 0.0, 1.75, False, 0.005, 0.2),
    "wolf_growl_1": ("wolf_growl_1.ogg", "wolf_growl_1", 0.0, 0.95, False, 0.01, 0.12),
    "wolf_growl_2": ("wolf_growl_2.ogg", "wolf_growl_2", 0.0, 2.5, False, 0.01, 0.4),
    "breath_in": ("breath_in.ogg", "breath_in", 0.0, 1.42, False, 0.02, 0.1),
    "stomach_growl_1": ("stomach_growl_1.ogg", "stomach_growl_1", 0.0, 2.83, False, 0.02, 0.2),
    "stomach_growl_2": ("stomach_growl_2.ogg", "stomach_growl_2", 0.0, 2.04, False, 0.02, 0.2),
    "chew_2": ("chew_2.mp3", "chew_2", None, None, False, 0.01, 0.1),
    "tree_fall": ("tree_fall.ogg", "tree_fall", 0.3, 10.7, False, 0.01, 1.2),
    "stone_throw": ("stone_throw.ogg", "stone_throw", 0.0, 0.33, False, 0.003, 0.05),
    "blind_rattle": ("blinds.ogg", "blind_rattle", 2.62, 3.22, False, 0.003, 0.12),
    "glitch": ("glitch.ogg", "glitch", 0.0, 2.9, False, 0.003, 0.05),
    "blast_door": ("blast_door.ogg", "blast_door", 0.0, 6.34, False, 0.01, 0.6),
    "wolf_yelp": ("wolf_yelp.ogg", "wolf_yelp", 0.0, 0.82, False, 0.005, 0.1),
    "gasp": ("gasp.ogg", "gasp", 0.0, 2.38, False, 0.01, 0.3),
    # O farejar toca a cada 1 a 1,5 s: um trecho de 0,9 s com duas fungadas.
    "sniff": ("sniff.ogg", "sniff", 0.35, 1.25, False, 0.01, 0.15),
    "chew_1": ("chew_1.ogg", "chew_1", None, None, False, 0.01, 0.1),
    # Montado: estalos reais de dente (Freesound #691908) repetidos ~11 vezes por segundo.
    "teeth_chatter": ("teeth_chatter.wav", "teeth_chatter", 0.0, 1.35, False, 0.003, 0.1),
    # Montado: o rosnado do wolf_growl_2, a mandíbula fechando (Freesound #27476), a pancada na carne
    # (Kenney, a da flecha) e um esmagar (Freesound #816237), juntos no fim do rosnado.
    "wolf_bite": ("wolf_bite.wav", "wolf_bite", 0.0, 0.85, False, 0.01, 0.08),
}
XFADE = 2.0
PEAK_LIMIT = 0.97


def load(path):
    x, sr = sf.read(str(path), always_2d=True)
    x = x.mean(axis=1)
    if sr > 48000:
        n = int(round(len(x) * 48000 / sr))
        spec = np.fft.rfft(x)
        x = np.fft.irfft(spec[: n // 2 + 1], n) * (n / len(x))
        sr = 48000
    return x - np.mean(x), sr


def window_rms_db(x, sr, seconds=0.3):
    n = max(1, int(seconds * sr))
    if len(x) <= n:
        return 20 * np.log10(np.sqrt(np.mean(x * x)) + 1e-12)
    c = np.cumsum(np.concatenate([[0.0], x * x]))
    return 10 * np.log10(np.max((c[n:] - c[:-n]) / n) + 1e-12)


def quietest_stretch(x, sr, seconds):
    """Início (s) do trecho de `seconds` com menos estalos fortes (pico sobre RMS)."""
    n = int(seconds * sr)
    best, at = 1e9, 0
    for start in range(0, len(x) - n - int(XFADE * sr), sr):
        seg = x[start:start + n]
        crest = np.max(np.abs(seg)) / (np.sqrt(np.mean(seg * seg)) + 1e-12)
        if crest < best:
            best, at = crest, start
    return at / sr


def bell_tolls(x, sr, tolls=3):
    """Do começo de uma badalada até o começo da `tolls`-ésima seguinte: o loop do sino lá fora."""
    hop = int(0.02 * sr)
    env = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
    rise = np.maximum(np.diff(env), 0)
    onsets = [i for i in range(1, len(rise) - 1) if rise[i] > 0.35 * rise.max() and rise[i] >= rise[i - 1] and rise[i] >= rise[i + 1]]
    merged = []
    for i in onsets:
        if not merged or i - merged[-1] > int(0.6 / 0.02):
            merged.append(i)
    start = merged[1]
    return (start * hop - int(0.02 * sr)) / sr, (merged[1 + tolls] * hop - int(0.02 * sr)) / sr


def strongest_chew(x, sr):
    hop = int(0.01 * sr)
    env = np.array([np.max(np.abs(x[i:i + hop])) for i in range(0, len(x) - hop, hop)])
    peak = int(np.argmax(env[int(0.5 / 0.01):-int(1.0 / 0.01)])) + int(0.5 / 0.01)
    return peak * 0.01 - 0.15, peak * 0.01 + 0.6


def ramp(n):
    return 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, max(n, 1)))


def write_loop_wav(path, x, sr):
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, sr, sr * 2, 2, 16)
    smpl = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, len(x) - 1, 0, 0)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"smpl" + struct.pack("<I", len(smpl)) + smpl \
        + b"data" + struct.pack("<I", len(pcm)) + pcm
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def process(name, raw_dir):
    raw, synthetic, start, end, loop, fade_in, fade_out = CUTS[name]
    x, sr = load(raw_dir / raw)
    if name == "church_bell_toll":
        start, end = bell_tolls(x, sr)
    elif name.startswith("chew_"):
        start, end = strongest_chew(x, sr)
    elif start is None:
        start = quietest_stretch(x, sr, end)
        end = start + end
    a, b = int(start * sr), min(int(end * sr), len(x))
    if loop:
        xf = int(XFADE * sr)
        seg = x[a:b + xf] if b + xf <= len(x) else x[a - xf:b]
        body = seg[: len(seg) - xf].copy()
        tail = seg[len(seg) - xf:]
        # Emenda de potência igual: o começo do loop nasce do que vinha depois do fim.
        w = np.linspace(0, 1, xf)
        body[:xf] = body[:xf] * np.sin(w * np.pi / 2) + tail * np.cos(w * np.pi / 2)
        y = body
        level = 20 * np.log10(np.sqrt(np.mean(y * y)) + 1e-12)
    else:
        y = x[a:b].copy()
        y[: int(fade_in * sr)] *= ramp(int(fade_in * sr))[: len(y)]
        nf = int(fade_out * sr)
        if nf:
            y[-nf:] *= ramp(nf)[::-1]
        level = window_rms_db(y, sr)
    y *= 10 ** ((LEVELS[synthetic] - level) / 20)
    peak = np.max(np.abs(y))
    if peak > PEAK_LIMIT:
        # Limitador suave só nos picos: o corpo do som fica no nível do sintético.
        y = np.tanh(y / PEAK_LIMIT) * PEAK_LIMIT
    OUT.mkdir(parents=True, exist_ok=True)
    if loop:
        path = OUT / f"{name}.wav"
        write_loop_wav(path, y, sr)
    else:
        path = OUT / f"{name}.ogg"
        sf.write(str(path), y, sr, format="OGG", subtype="VORBIS")
    print(f"  {path.relative_to(ROOT.parent.parent)}: {start:.2f}-{end:.2f} s de {raw}, {len(y) / sr:.2f} s"
          f"{', loop' if loop else ''}, pico {20 * np.log10(np.max(np.abs(y)) + 1e-12):.1f} dB")


def main():
    raw = next((Path(a.split("=", 1)[1]) for a in sys.argv[1:] if a.startswith("--raw=")), None)
    if raw is None:
        sys.exit("uso: python tools/process_real_sounds.py --raw=PASTA [nome ...]")
    wanted = [a for a in sys.argv[1:] if not a.startswith("--")] or list(CUTS)
    for name in wanted:
        process(name, raw)


if __name__ == "__main__":
    main()
