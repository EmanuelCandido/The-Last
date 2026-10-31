"""Gera os sons sintéticos da luta (F11, experimental) em assets/audio/sfx/.

Fica fora do generate_sounds.py para não regerar os outros sons junto. Usa os mesmos utilitários.
Os impactos em carne e em madeira são as gravações reais que as flechas e o soco já usam.

Uso (na raiz do projeto): python tools/generate_combat_sounds.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_sounds import ROOT, SR, band_oneshot, burst, formants, tone, write_wav  # noqa: E402


def swing(variant):
    """Vento da arma passando: ruído que sobe e desce de tom com a velocidade da lâmina."""
    rng = np.random.default_rng(900 + variant)
    dur = 0.26 + 0.05 * variant
    n = int(dur * SR)
    t = np.arange(n) / SR
    speed = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    noise = rng.standard_normal(n)
    # Duas faixas que se cruzam: o chiado agudo segue a velocidade, o sopro grave fica embaixo.
    hi = band_oneshot(noise, 900 + 300 * variant, 3200 + 500 * variant, 0.25)
    lo = band_oneshot(noise, 180, 700, 0.3)
    return (hi * speed ** 1.5 + 0.6 * lo * speed) * np.minimum(t / 0.02, 1.0)


def block(variant):
    """A arma ou o braço segurando o golpe: um baque de madeira e couro, curto e surdo."""
    rng = np.random.default_rng(910 + variant)
    knock = band_oneshot(burst(rng, 0.22, 0.03), 140, 900, 0.3)
    t = np.arange(len(knock)) / SR
    body = np.sin(2 * np.pi * (95 + 25 * variant) * t) * np.exp(-t / 0.05)
    rattle = band_oneshot(burst(rng, 0.22, 0.012), 1500, 4000, 0.2) * 0.4
    return knock + body * 0.8 + rattle


def parry():
    """Aparar: um estalo seco de pau contra pau, com um zumbido curto da madeira que vibra."""
    rng = np.random.default_rng(921)
    crack = band_oneshot(burst(rng, 0.3, 0.008), 800, 5000, 0.2)
    t = np.arange(len(crack)) / SR
    ring = (np.sin(2 * np.pi * 410 * t) + 0.5 * np.sin(2 * np.pi * 870 * t)) * np.exp(-t / 0.06)
    return crack + ring * 0.35


def weapon_break():
    """A arma quebrando: três estalos rápidos de fibra rachando e um baque."""
    rng = np.random.default_rng(931)
    n = int(0.45 * SR)
    out = np.zeros(n)
    for at, size in ((0.0, 1.0), (0.05, 0.7), (0.11, 0.9)):
        snap = band_oneshot(burst(rng, 0.12, 0.01), 600, 4500, 0.25) * size
        i = int(at * SR)
        out[i:i + len(snap)] += snap[: n - i]
    thud = band_oneshot(burst(rng, 0.3, 0.06), 80, 400, 0.3)
    i = int(0.16 * SR)
    out[i:i + len(thud)] += thud[: n - i] * 0.8
    return out


def orc_voice(seed, dur, f0, f1, rough, vowel, attack=0.03):
    """Voz grave e rouca do orc: um tom que desliza de f0 a f1 com aspereza (ruído e batimento), pelo
    trato de um peito grande (formantes da vogal). Por trás, o chiado de quem respira por um filtro:
    na segunda leitura, o respirador."""
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    t = np.arange(n) / SR
    glide = f0 + (f1 - f0) * np.clip(t / dur, 0, 1) ** 0.7
    wobble = 1.0 + 0.03 * np.sin(2 * np.pi * 7.0 * t) + 0.02 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    voiced = tone(glide * wobble, ((1, 1.0), (2, 0.7), (3, 0.5), (4, 0.35), (5, 0.25), (7, 0.15)))
    voiced *= 1.0 + rough * band_oneshot(rng.standard_normal(n), 20, 60, 0.4) * 3.0
    breath = band_oneshot(rng.standard_normal(n), 1800, 5000, 0.25) * 0.25
    peaks = {"a": [(650, 120, 1.0), (1100, 150, 0.6), (2500, 300, 0.25)],
             "o": [(420, 100, 1.0), (800, 120, 0.7), (2400, 300, 0.15)],
             "u": [(320, 90, 1.0), (700, 120, 0.4), (2300, 300, 0.1)]}[vowel]
    out = formants(voiced, peaks) + breath
    env = np.minimum(t / attack, 1.0) * np.clip((dur - t) / (dur * 0.35), 0, 1)
    return out * env


def orc_drum(variant):
    """O tambor do acampamento (F14): tronco oco com couro esticado. A pele cai de tom no baque, o tapa
    da mão fica por cima e o oco do tronco ressoa curto. A 2 é o segundo baque do coração, mais leve."""
    rng = np.random.default_rng(980 + variant)
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    f = (62 + 8 * variant) * (1.0 + 0.6 * np.exp(-t / 0.03))
    skin = tone(f, ((1, 1.0), (2, 0.25), (3, 0.1))) * np.exp(-t / (0.32 - 0.06 * variant))
    hollow = np.sin(2 * np.pi * (170 + 20 * variant) * t) * np.exp(-t / 0.07) * 0.35
    slap = band_oneshot(burst(rng, 0.9, 0.018), 250, 1800, 0.3) * 0.5
    return skin + hollow + slap


def orc_talk(variant):
    """A língua dos orcs (F14): uma frase de rádio tocada ao contrário. Sílabas de voz rouca por um
    alto-falante pequeno (só o meio da voz, saturado), o chiado do canal e o estalo de abrir e fechar.
    Na segunda leitura, o rádio da equipe de resgate ("evacuar ala norte")."""
    rng = np.random.default_rng(990 + variant)
    syllables = int(rng.integers(5, 9))
    parts = [np.zeros(int(0.12 * SR))]
    for i in range(syllables):
        dur = rng.uniform(0.12, 0.26)
        # A frase cai de tom até o fim, como quem dá uma ordem.
        f0 = rng.uniform(110, 150) * (1.0 - 0.15 * i / syllables)
        vowel = str(rng.choice(["a", "o", "u"]))
        parts.append(orc_voice(int(rng.integers(1_000_000)), dur, f0, f0 * rng.uniform(0.85, 1.1), 0.3, vowel, 0.015))
        parts.append(np.zeros(int(rng.uniform(0.02, 0.09) * SR)))
    parts.append(np.zeros(int(0.12 * SR)))
    speech = np.concatenate(parts)
    n = len(speech)
    radio = band_oneshot(speech, 350, 2800, 0.2)
    radio = np.tanh(radio / (np.max(np.abs(radio)) + 1e-9) * 2.5)
    hiss = band_oneshot(rng.standard_normal(n), 800, 5000, 0.2) * 0.08
    out = radio + hiss
    for at in (0, n - int(0.05 * SR)):
        click = band_oneshot(burst(rng, 0.05, 0.006), 1200, 6000, 0.2) * 0.8
        out[at:at + len(click)] += click
    return out[::-1].copy()


def main():
    out = ROOT / "sfx"
    for v in (1, 2, 3):
        write_wav(out / f"swing_{v}.wav", swing(v), peak=0.6)
    for v in (1, 2):
        write_wav(out / f"block_{v}.wav", block(v))
    write_wav(out / "parry.wav", parry())
    write_wav(out / "weapon_break.wav", weapon_break())
    # F12: as vozes do orc.
    for v in (1, 2, 3):
        write_wav(out / f"orc_grunt_{v}.wav", orc_voice(940 + v, 0.45 + 0.08 * v, 105 + 10 * v, 80, 0.6, "u", 0.05))
    write_wav(out / "orc_shout.wav", orc_voice(950, 1.1, 120, 165, 0.9, "a", 0.08))
    for v in (1, 2):
        write_wav(out / f"orc_hurt_{v}.wav", orc_voice(960 + v, 0.5, 150 + 15 * v, 95, 1.0, "o", 0.01))
    write_wav(out / "orc_death.wav", orc_voice(970, 1.6, 120, 55, 0.8, "o", 0.02))
    # F14: o tambor (os dois baques do coração) e a língua dos orcs.
    for v in (1, 2):
        write_wav(out / f"orc_drum_{v}.wav", orc_drum(v))
    for v in (1, 2, 3, 4):
        write_wav(out / f"orc_talk_{v}.wav", orc_talk(v), peak=0.7)


if __name__ == "__main__":
    main()
