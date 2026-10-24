"""Gera as texturas pixeladas do jogo em assets/textures/.

Todas são procedurais, tileáveis e determinísticas (sementes fixas), no estilo
"realista retrô": pouca resolução, filtro nearest no Godot e paleta dessaturada.

Uso (na raiz do projeto): python tools/generate_textures.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"


def spectral_noise(h, w, beta, seed, stretch_y=1.0):
    """Ruído fractal tileável por síntese espectral (1/f^beta), normalizado em 0..1.

    stretch_y > 1 alonga os detalhes na vertical (veios de casca de árvore).
    """
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(h)[:, None] * stretch_y
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx**2 + fy**2)
    f[0, 0] = 1.0
    spectrum = np.fft.fft2(rng.standard_normal((h, w))) / f**beta
    spectrum[0, 0] = 0.0
    n = np.real(np.fft.ifft2(spectrum))
    return (n - n.min()) / (n.max() - n.min())


def worley(size, cells, seed):
    """Distâncias F1 e F2 (em pixels) de um diagrama de Voronoi tileável."""
    rng = np.random.default_rng(seed)
    gy, gx = np.mgrid[0:cells, 0:cells]
    pts_x = ((gx + rng.random((cells, cells))) * size / cells).ravel()
    pts_y = ((gy + rng.random((cells, cells))) * size / cells).ravel()
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    f1 = np.full((size, size), np.inf)
    f2 = np.full((size, size), np.inf)
    for px, py in zip(pts_x, pts_y):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, size - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        f2 = np.where(d < f1, f1, np.minimum(f2, d))
        f1 = np.minimum(f1, d)
    return f1, f2


def ramp(v, stops):
    """Mapeia v (0..1) numa rampa de cores [(t, (r, g, b)), ...]."""
    ts = [s[0] for s in stops]
    return np.stack([np.interp(v, ts, [s[1][c] for s in stops]) for c in range(3)], axis=-1)


def ramp_color(t, stops):
    return ramp(np.array([t]), stops)[0]


def stroke(img, x0, y0, dx, dy, length, color, alpha=None, wrap=True):
    """Desenha uma linha de 1 px; com wrap=True ela dá a volta nas bordas (textura tileável)."""
    h, w = img.shape[:2]
    for i in range(int(length)):
        x = int(round(x0 + dx * i))
        y = int(round(y0 + dy * i))
        if wrap:
            x %= w
            y %= h
        elif not (0 <= x < w and 0 <= y < h):
            continue
        img[y, x] = color
        if alpha is not None:
            alpha[y, x] = 1.0


def ellipse(img, alpha, cx, cy, a, b, angle, color_fn):
    """Preenche uma elipse rotacionada; color_fn(u, v) recebe coordenadas normalizadas (-1..1)."""
    h, w = img.shape[:2]
    r = int(np.ceil(max(a, b))) + 1
    ca, sa = np.cos(angle), np.sin(angle)
    for y in range(int(cy) - r, int(cy) + r + 1):
        for x in range(int(cx) - r, int(cx) + r + 1):
            if not (0 <= x < w and 0 <= y < h):
                continue
            px, py = x + 0.5 - cx, y + 0.5 - cy
            u = (px * ca + py * sa) / a
            v = (-px * sa + py * ca) / b
            if u * u + v * v <= 1.0:
                img[y, x] = color_fn(u, v)
                alpha[y, x] = 1.0


def fill_transparent(rgb, alpha):
    """Pinta os pixels transparentes com a cor média, para os mipmaps não criarem bordas pretas."""
    mask = alpha > 0
    if mask.any():
        rgb[~mask] = rgb[mask].mean(axis=0)
    return rgb


def save(name, rgb, alpha=None):
    data = np.clip(rgb, 0.0, 1.0)
    if alpha is not None:
        data = np.concatenate([data, np.clip(alpha, 0.0, 1.0)[..., None]], axis=-1)
    Image.fromarray((data * 255 + 0.5).astype(np.uint8)).save(OUT / name)
    print(f"  {name} {data.shape[1]}x{data.shape[0]}")


def save_gray(name, v):
    Image.fromarray((np.clip(v, 0.0, 1.0) * 255 + 0.5).astype(np.uint8), mode="L").save(OUT / name)
    print(f"  {name} {v.shape[1]}x{v.shape[0]}")


GRASS_STOPS = [(0.0, (0.17, 0.19, 0.10)), (0.35, (0.30, 0.31, 0.17)), (0.65, (0.44, 0.41, 0.25)), (1.0, (0.56, 0.52, 0.36))]


def ground_grass(size=128):
    rng = np.random.default_rng(11)
    v = spectral_noise(size, size, 1.7, 1) * 0.65 + spectral_noise(size, size, 0.6, 2) * 0.35
    img = ramp(v, GRASS_STOPS)
    # Folhas de capim vistas de cima: traços curtos, quase verticais.
    for _ in range(1500):
        x, y = rng.uniform(0, size, 2)
        angle = rng.normal(-np.pi / 2, 0.55)
        t = np.clip(v[int(y), int(x)] + rng.normal(0, 0.2), 0, 1)
        color = ramp_color(t, GRASS_STOPS) * rng.uniform(0.85, 1.15)
        stroke(img, x, y, np.cos(angle), np.sin(angle), rng.integers(2, 6), color)
    return img


def ground_dirt(size=128):
    rng = np.random.default_rng(21)
    v = spectral_noise(size, size, 1.5, 3) * 0.7 + spectral_noise(size, size, 0.5, 4) * 0.3
    img = ramp(v, [(0.0, (0.17, 0.13, 0.09)), (0.5, (0.31, 0.24, 0.17)), (1.0, (0.45, 0.37, 0.27))])
    # Pedrinhas: células de Voronoi com raio variável, sombreadas e com contorno escuro.
    f1, _ = worley(size, 12, 5)
    # Raio pequeno e variável: muitas células ficam sem pedra, e as que têm ficam discretas.
    r = 0.3 + spectral_noise(size, size, 1.0, 6) * 1.7
    pebble_color = ramp(spectral_noise(size, size, 0.3, 7), [(0.0, (0.27, 0.24, 0.2)), (1.0, (0.4, 0.36, 0.3))])
    shade = 1.0 - (f1 / r) * 0.3
    pebble = f1 < r
    img = np.where(pebble[..., None], img * 0.4 + pebble_color * shade[..., None] * 0.6, img)
    img[rng.random((size, size)) < 0.04] *= 0.6
    return img


def rock(size=128):
    rng = np.random.default_rng(31)
    v = spectral_noise(size, size, 1.4, 31) * 0.75 + spectral_noise(size, size, 0.4, 32) * 0.25
    img = ramp(v, [(0.0, (0.22, 0.22, 0.22)), (0.5, (0.40, 0.39, 0.37)), (1.0, (0.58, 0.57, 0.54))])
    # Rachaduras só aparecem em parte das bordas das células, senão vira calçamento.
    crack_mask = spectral_noise(size, size, 1.2, 36)
    f1, f2 = worley(size, 4, 33)
    img[((f2 - f1) < 1.2) & (crack_mask > 0.45)] *= 0.5
    f1, f2 = worley(size, 9, 34)
    img[((f2 - f1) < 0.8) & (crack_mask < 0.55)] *= 0.8
    # Estratos horizontais suaves.
    strata = spectral_noise(size, size, 1.6, 37, stretch_y=0.15)
    img *= (0.85 + 0.3 * strata)[..., None]
    lichen = spectral_noise(size, size, 1.3, 35) > 0.7
    img[lichen] = img[lichen] * 0.45 + np.array([0.46, 0.47, 0.30]) * 0.55
    img[rng.random((size, size)) < 0.03] *= 1.25
    return img


def ground_forest(size=128):
    rng = np.random.default_rng(41)
    v = spectral_noise(size, size, 1.5, 42)
    img = ramp(v, [(0.0, (0.10, 0.08, 0.06)), (0.5, (0.21, 0.16, 0.11)), (1.0, (0.32, 0.24, 0.15))])
    needle_colors = np.array([(0.42, 0.28, 0.15), (0.33, 0.23, 0.13), (0.50, 0.36, 0.20), (0.26, 0.20, 0.12)])
    for _ in range(1800):
        x, y = rng.uniform(0, size, 2)
        a = rng.uniform(0, np.pi)
        color = needle_colors[rng.integers(len(needle_colors))] * rng.uniform(0.8, 1.1)
        stroke(img, x, y, np.cos(a), np.sin(a), rng.integers(3, 7), color)
    leaf_colors = np.array([(0.45, 0.30, 0.14), (0.36, 0.25, 0.12), (0.30, 0.28, 0.14)])
    for _ in range(45):
        cx, cy = rng.uniform(0, size, 2)
        color = leaf_colors[rng.integers(len(leaf_colors))]
        for dy in range(-1, 2):
            for dx in range(-2, 3):
                if abs(dx) + abs(dy) <= 2:
                    img[int(cy + dy) % size, int(cx + dx) % size] = color * (0.9 if dy > 0 else 1.0)
    for _ in range(12):
        x, y = rng.uniform(0, size, 2)
        a = rng.uniform(0, np.pi)
        stroke(img, x, y, np.cos(a), np.sin(a), rng.integers(10, 18), np.array([0.17, 0.12, 0.08]))
    return img


def bark(w=64, h=128):
    rng = np.random.default_rng(51)
    val = spectral_noise(h, w, 1.3, 51, stretch_y=6.0) * 0.7 + spectral_noise(h, w, 0.5, 52, stretch_y=3.0) * 0.3
    img = ramp(val, [(0.0, (0.10, 0.08, 0.07)), (0.45, (0.25, 0.21, 0.17)), (1.0, (0.42, 0.38, 0.33))])
    img[val < 0.35] *= 0.6
    for _ in range(14):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        stroke(img, x, y, 1.0, rng.uniform(-0.2, 0.2), rng.integers(3, 8), np.array([0.08, 0.06, 0.05]))
    return img


def fur(size=64):
    rng = np.random.default_rng(91)
    v = spectral_noise(size, size, 1.4, 92)
    stops = [(0.0, (0.16, 0.11, 0.07)), (0.5, (0.32, 0.23, 0.15)), (1.0, (0.48, 0.38, 0.27))]
    img = ramp(v, stops)
    for _ in range(900):
        x, y = rng.uniform(0, size, 2)
        a = rng.normal(np.pi / 2, 0.35)
        t = np.clip(v[int(y), int(x)] + rng.normal(0, 0.25), 0, 1)
        stroke(img, x, y, np.cos(a), np.sin(a), rng.integers(3, 7), ramp_color(t, stops))
    return img


def pelt(size=64):
    """Pelo curto dos bichos, quase neutro (o shader tinge por região): fios curtos caídos
    para baixo, mechas mais escuras e pontas claras. Tileável."""
    rng = np.random.default_rng(141)
    v = spectral_noise(size, size, 1.6, 142) * 0.6 + spectral_noise(size, size, 0.8, 143) * 0.4
    stops = [(0.0, (0.5, 0.47, 0.43)), (0.5, (0.7, 0.67, 0.62)), (1.0, (0.86, 0.83, 0.78))]
    img = ramp(v, stops)
    for _ in range(1400):
        x, y = rng.uniform(0, size, 2)
        a = rng.normal(np.pi / 2, 0.28)
        t = np.clip(v[int(y), int(x)] + rng.normal(0, 0.3), 0, 1)
        stroke(img, x, y, np.cos(a), np.sin(a), rng.integers(2, 5), ramp_color(t, stops))
    # Mechas: faixas mais escuras na direção do pelo.
    clumps = spectral_noise(size, size, 1.2, 144, stretch_y=0.25)
    img *= (0.8 + 0.25 * clumps)[..., None]
    img[rng.random((size, size)) < 0.05] *= 0.75
    return img


def bristle(size=64):
    """Cerdas do javali: fios longos, grossos e duros, escuros com pontas claras."""
    rng = np.random.default_rng(151)
    v = spectral_noise(size, size, 1.4, 152)
    img = ramp(v, [(0.0, (0.28, 0.26, 0.24)), (1.0, (0.5, 0.47, 0.43))])
    for _ in range(700):
        x, y = rng.uniform(0, size, 2)
        a = rng.normal(np.pi / 2, 0.22)
        length = rng.integers(5, 11)
        dark = rng.uniform(0.15, 0.35)
        stroke(img, x, y, np.cos(a), np.sin(a), length, np.array([dark, dark * 0.92, dark * 0.85]))
        if rng.random() < 0.4:
            stroke(img, x + np.cos(a) * length, y + np.sin(a) * length, np.cos(a), np.sin(a), 1, np.array([0.58, 0.54, 0.47]))
    return img


def plumage(size=64):
    """Penas: escamas sobrepostas (cada pena com a raque e a borda mais clara), quase neutras."""
    rng = np.random.default_rng(161)
    img = np.full((size, size, 3), 0.5)
    shade = spectral_noise(size, size, 1.3, 162)
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    rows = 8
    for row in range(rows + 1):
        for col in range(rows):
            cx = (col + 0.5 * (row % 2) + rng.uniform(-0.15, 0.15)) * size / rows
            cy = (row + rng.uniform(-0.1, 0.1)) * size / rows
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    dx = (xx - cx - ox) / (size / rows * 0.62)
                    dy = (yy - cy - oy) / (size / rows * 0.9)
                    inside = (dx * dx + dy * dy < 1.0) & (dy > -0.6)
                    edge = inside & (dx * dx + dy * dy > 0.62)
                    tone = 0.45 + 0.25 * rng.random()
                    img[inside] = tone
                    img[edge] = tone + 0.14
                    img[inside & (np.abs(dx) < 0.09)] = tone - 0.12
    img *= (0.85 + 0.3 * shade)[..., None]
    img *= np.array([1.0, 0.98, 0.95])
    return img


def grass_card(size=64):
    """Tufo de capim seco com fundo transparente (cartão de grama)."""
    rng = np.random.default_rng(61)
    rgb = np.zeros((size, size, 3))
    alpha = np.zeros((size, size))
    blades = sorted(rng.uniform(0, 1, 48))  # tons escuros primeiro (ficam atrás)
    for tone in blades:
        x0 = rng.uniform(3, size - 3)
        height = rng.uniform(0.45, 0.98) * size
        lean = rng.normal(0, 7)
        color = ramp_color(tone, GRASS_STOPS)
        steps = int(height)
        for s in range(steps):
            t = s / steps
            x = x0 + lean * t * t
            y = size - 1 - s
            width = 2 if t < 0.55 else 1
            for wx in range(width):
                xi = int(x) + wx
                if 0 <= xi < size:
                    rgb[y, xi] = color * (0.5 + 0.5 * t)
                    alpha[y, xi] = 1.0
        if rng.random() < 0.2:  # cabeça de semente
            tip_x, tip_y = int(x0 + lean), int(size - steps)
            for dy in range(3):
                if 0 <= tip_x < size and 0 <= tip_y + dy < size:
                    rgb[tip_y + dy, tip_x] = np.array([0.66, 0.6, 0.42])
                    alpha[tip_y + dy, tip_x] = 1.0
    return fill_transparent(rgb, alpha), alpha


def pine_branch(size=64):
    """Galho de pinheiro: o eixo vai da esquerda (tronco) para a direita (ponta)."""
    rng = np.random.default_rng(71)
    rgb = np.zeros((size, size, 3))
    alpha = np.zeros((size, size))
    stops = [(0.0, (0.06, 0.10, 0.07)), (0.6, (0.12, 0.19, 0.12)), (1.0, (0.21, 0.28, 0.17))]
    twig = np.array([0.22, 0.15, 0.10])

    def needles_along(x0, y0, dx, dy, length, needle_len):
        for k in range(int(length)):
            px, py = x0 + dx * k, y0 + dy * k
            for side in (-1, 1):
                ang = np.arctan2(dy, dx) + side * rng.uniform(0.5, 1.1)
                nl = needle_len * rng.uniform(0.6, 1.0)
                color = ramp_color(rng.uniform(0, 1), stops)
                stroke(rgb, px, py, np.cos(ang), np.sin(ang), nl, color, alpha, wrap=False)

    mid = size / 2
    for bx in range(2, size - 6, 4):
        frac = bx / size
        side_len = (1.0 - frac) * 20 + 4
        for side in (-1, 1):
            ang = side * rng.uniform(0.6, 1.0)
            needles_along(bx, mid + np.sin(bx / 18) * 2, np.cos(ang), np.sin(ang), side_len, 5 + 4 * (1 - frac))
    needles_along(0, mid, 1.0, 0.0, size - 3, 5)
    for x in range(0, size - 4):
        y = int(round(mid + np.sin(x / 18) * 2))
        for t in range(2 if x < size * 0.4 else 1):
            rgb[y + t, x] = twig
            alpha[y + t, x] = 1.0
    return fill_transparent(rgb, alpha), alpha


LEAF_COLORS = np.array([
    (0.55, 0.33, 0.12), (0.42, 0.26, 0.12), (0.62, 0.48, 0.20),
    (0.36, 0.38, 0.18), (0.50, 0.40, 0.18), (0.30, 0.20, 0.10),
])


def leaves_card(size=64):
    """Cacho de folhas de outono com fundo transparente (copa da árvore velha)."""
    rng = np.random.default_rng(81)
    rgb = np.zeros((size, size, 3))
    alpha = np.zeros((size, size))
    for _ in range(6):
        a = rng.uniform(0, 2 * np.pi)
        stroke(rgb, size / 2, size / 2, np.cos(a), np.sin(a), rng.uniform(14, 26), np.array([0.2, 0.14, 0.09]), alpha, wrap=False)
    for _ in range(85):
        cx, cy = np.clip(rng.normal(size / 2, 12, 2), 5, size - 5)
        base = LEAF_COLORS[rng.integers(len(LEAF_COLORS))]
        light = 1.1 - 0.35 * ((cx + cy) / (2 * size))
        ellipse(rgb, alpha, cx, cy, rng.uniform(2.5, 4.2), rng.uniform(1.3, 2.1), rng.uniform(0, np.pi),
                lambda u, v, c=base * light: c * (0.85 if v > 0.3 else 1.0))
    return fill_transparent(rgb, alpha), alpha


BUSH_COLORS = np.array([
    (0.19, 0.24, 0.12), (0.25, 0.30, 0.15), (0.32, 0.35, 0.18),
    (0.40, 0.39, 0.21), (0.27, 0.27, 0.14), (0.44, 0.38, 0.19),
])


def bush_card(size=64):
    """Cacho de folhas miúdas e escuras de arbusto (coleta de frutinhas), com galhinhos."""
    rng = np.random.default_rng(91)
    rgb = np.zeros((size, size, 3))
    alpha = np.zeros((size, size))
    for _ in range(7):
        a = rng.uniform(0, 2 * np.pi)
        stroke(rgb, size / 2, size / 2, np.cos(a), np.sin(a), rng.uniform(16, 28), np.array([0.17, 0.12, 0.08]), alpha, wrap=False)
    for _ in range(140):
        cx, cy = np.clip(rng.normal(size / 2, 11, 2), 4, size - 4)
        base = BUSH_COLORS[rng.integers(len(BUSH_COLORS))]
        # Luz de cima: as folhas de baixo ficam mais escuras.
        light = 1.15 - 0.45 * (cy / size)
        ellipse(rgb, alpha, cx, cy, rng.uniform(2.0, 3.4), rng.uniform(1.1, 1.8), rng.uniform(0, np.pi),
                lambda u, v, c=base * light: c * (0.8 if v > 0.35 else 1.0))
    return fill_transparent(rgb, alpha), alpha


def berry_card(size=64):
    """Cachos de frutinhas escuras (vermelho de amora) com fundo transparente: vai por cima do arbusto."""
    rng = np.random.default_rng(92)
    rgb = np.zeros((size, size, 3))
    alpha = np.zeros((size, size))
    dark = np.array([0.17, 0.05, 0.07])
    red = np.array([0.33, 0.09, 0.11])
    for _ in range(7):
        cx, cy = np.clip(rng.normal(size / 2, 13, 2), 6, size - 6)
        stroke(rgb, cx, cy, rng.uniform(-0.4, 0.4), -1.0, rng.uniform(3, 6), np.array([0.2, 0.15, 0.08]), alpha, wrap=False)
        for _ in range(rng.integers(3, 7)):
            bx, by = cx + rng.normal(0, 2.2), cy + rng.normal(0, 2.2)
            r = rng.uniform(1.3, 2.1)
            ellipse(rgb, alpha, bx, by, r, r, 0.0,
                    lambda u, v: (red * 1.3 if u < -0.2 and v < -0.2 else red if u + v < 0.6 else dark))
    return fill_transparent(rgb, alpha), alpha


def tree_blaze(w=24, h=40):
    """Casca raspada no tronco (F10): uma mancha irregular de madeira clara, com a borda da casca
    rasgada mais escura e três riscos fundos de garra. Fundo transparente (vai colado na casca)."""
    rng = np.random.default_rng(141)
    yy, xx = np.mgrid[0:h, 0:w] + 0.5
    # Elipse comprida com a borda roída pelo ruído.
    edge = spectral_noise(h, w, 1.2, 142) - 0.5
    shape = ((xx - w / 2) / (w * 0.42)) ** 2 + ((yy - h / 2) / (h * 0.46)) ** 2 + edge * 0.55
    alpha = (shape < 1.0).astype(float)
    grain = spectral_noise(h, w, 1.4, 143, stretch_y=5.0)
    rgb = ramp(grain, [(0.0, (0.52, 0.42, 0.29)), (0.5, (0.70, 0.60, 0.44)), (1.0, (0.80, 0.71, 0.55))])
    # A casca rasgada em volta: escura, como a madeira que já começou a oxidar.
    rim = (shape > 0.72) & (shape < 1.0)
    rgb[rim] = rgb[rim] * 0.55
    for i in range(3):
        x = w / 2 + (i - 1) * 4.5 + rng.uniform(-0.6, 0.6)
        stroke(rgb, x, h * 0.18 + rng.uniform(0, 2), rng.uniform(-0.12, 0.12), 1.0, h * 0.62, np.array([0.24, 0.17, 0.10]), wrap=False)
    return fill_transparent(rgb, alpha), alpha


def smoke_puff(size=32):
    """Bolo de fumaça (F10, a fumaça da toca vista de longe): redondo, mais denso no meio, com a
    borda comida pelo ruído. O alpha vira dither no jogo (ALPHA_HASH), no estilo pixelado."""
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    r = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2) / (size / 2)
    noise = spectral_noise(size, size, 1.6, 151)
    alpha = np.clip((1.0 - r) * 1.4 + (noise - 0.5) * 0.9, 0.0, 1.0) ** 1.3
    # Zera de vez antes da borda do quad: o ruído deixava os cantos acesos e o bolo virava um quadrado.
    alpha *= np.clip((0.95 - r) / 0.25, 0.0, 1.0)
    shade = 0.75 + 0.25 * (1.0 - yy / size)  # luz de cima
    rgb = np.stack([shade * (0.86 + 0.1 * noise)] * 3, axis=-1) * np.array([1.0, 0.99, 0.97])
    return rgb, alpha


def leaf(size=16):
    """Uma folha solta (partículas de folhas caindo)."""
    rgb = np.zeros((size, size, 3))
    alpha = np.zeros((size, size))
    center = np.array([0.68, 0.45, 0.15])
    edge = np.array([0.46, 0.27, 0.10])
    ellipse(rgb, alpha, 8.5, 7.5, 6.5, 3.4, np.pi / 4,
            lambda u, v: (edge + (center - edge) * (1 - min(1.0, u * u + v * v))) * (0.7 if abs(v) < 0.18 else 1.0))
    stroke(rgb, 3.5, 12.5, 1.0, -1.0, 3, np.array([0.3, 0.2, 0.1]), alpha, wrap=False)
    return fill_transparent(rgb, alpha), alpha


def goblin_skin(size=64):
    """Pele de goblin: verde-oliva acinzentado, manchado, com verrugas e sujeira."""
    rng = np.random.default_rng(111)
    v = spectral_noise(size, size, 1.5, 111) * 0.7 + spectral_noise(size, size, 0.6, 112) * 0.3
    img = ramp(v, [(0.0, (0.2, 0.23, 0.14)), (0.5, (0.31, 0.35, 0.22)), (1.0, (0.42, 0.45, 0.3))])
    dirt = spectral_noise(size, size, 1.8, 113) > 0.66
    img[dirt] = img[dirt] * 0.6 + np.array([0.3, 0.23, 0.15]) * 0.4
    f1, _ = worley(size, 6, 114)
    img[f1 < 1.1] = img[f1 < 1.1] * 0.65 + np.array([0.48, 0.48, 0.33]) * 0.35
    img[(f1 >= 1.1) & (f1 < 1.9)] *= 0.8
    img[rng.random((size, size)) < 0.07] *= 0.82
    return img


def goblin_cloth(size=64):
    """Trapo de estopa: trama, fios irregulares, manchas e furos."""
    rng = np.random.default_rng(121)
    v = spectral_noise(size, size, 1.3, 121)
    img = ramp(v, [(0.0, (0.19, 0.14, 0.09)), (0.5, (0.31, 0.24, 0.16)), (1.0, (0.43, 0.35, 0.24))])
    yy, xx = np.mgrid[0:size, 0:size]
    img[(xx + yy) % 2 == 0] *= 1.1
    threads = spectral_noise(size, size, 1.0, 122, stretch_y=0.1)
    img *= (0.88 + 0.24 * threads)[..., None]
    img[spectral_noise(size, size, 1.6, 123) > 0.7] *= 0.65
    f1, _ = worley(size, 5, 124)
    holes = (f1 < 1.3) & (rng.random((size, size)) < 0.8) & (spectral_noise(size, size, 1.0, 125) > 0.55)
    img[holes] = np.array([0.06, 0.05, 0.04])
    return img


def leather(size=32):
    """Couro gasto: marrom escuro com arranhões claros."""
    rng = np.random.default_rng(131)
    v = spectral_noise(size, size, 1.4, 131)
    img = ramp(v, [(0.0, (0.13, 0.09, 0.06)), (1.0, (0.3, 0.21, 0.13))])
    for _ in range(14):
        x, y = rng.uniform(0, size, 2)
        a = rng.uniform(0, np.pi)
        stroke(img, x, y, np.cos(a), np.sin(a), rng.integers(2, 6), np.array([0.36, 0.27, 0.18]))
    return img


def wood(w=32, h=64):
    """Madeira clara com veios (arco e haste das flechas)."""
    val = spectral_noise(h, w, 1.2, 141, stretch_y=8.0) * 0.8 + spectral_noise(h, w, 0.5, 142) * 0.2
    return ramp(val, [(0.0, (0.3, 0.2, 0.12)), (0.5, (0.47, 0.34, 0.21)), (1.0, (0.6, 0.47, 0.31))])


def concrete(size=128):
    """Parede de concreto do Abrigo: cinza frio, poros, marcas de fôrma e escorridos de umidade."""
    rng = np.random.default_rng(151)
    v = spectral_noise(size, size, 1.3, 151) * 0.6 + spectral_noise(size, size, 0.5, 152) * 0.4
    img = ramp(v, [(0.0, (0.25, 0.26, 0.25)), (0.5, (0.38, 0.39, 0.37)), (1.0, (0.5, 0.5, 0.47))])
    # Junta da fôrma de madeira: uma linha horizontal a cada metade.
    img[[size // 2 - 1, size - 1], :] *= 0.72
    # Escorridos: manchas alongadas na vertical que escurecem para baixo.
    streaks = spectral_noise(size, size, 1.6, 153, stretch_y=0.08)
    img *= (1.0 - 0.3 * np.clip((streaks - 0.55) * 3.0, 0.0, 1.0))[..., None]
    pores = rng.random((size, size)) < 0.012
    img[pores] *= 0.78
    return img


def concrete_floor(size=128):
    """Piso de concreto: mais escuro, gasto no meio, com a junta de dilatação e manchas de óleo."""
    rng = np.random.default_rng(161)
    v = spectral_noise(size, size, 1.5, 161) * 0.7 + spectral_noise(size, size, 0.4, 162) * 0.3
    img = ramp(v, [(0.0, (0.19, 0.2, 0.19)), (0.5, (0.29, 0.3, 0.28)), (1.0, (0.4, 0.4, 0.37))])
    img[size - 1, :] *= 0.55
    img[:, size - 1] *= 0.55
    stains = spectral_noise(size, size, 1.8, 163) > 0.72
    img[stains] *= 0.7
    img[rng.random((size, size)) < 0.03] *= 1.2
    return img


def metal(size=64):
    """Chapa pintada de verde-acinzentado, descascada, com arranhões e ferrugem nas falhas."""
    rng = np.random.default_rng(171)
    v = spectral_noise(size, size, 1.2, 171)
    img = ramp(v, [(0.0, (0.3, 0.34, 0.31)), (1.0, (0.44, 0.48, 0.44))])
    chips = spectral_noise(size, size, 1.6, 172) > 0.82
    img[chips] = ramp(spectral_noise(size, size, 0.6, 173), [(0.0, (0.2, 0.15, 0.11)), (1.0, (0.32, 0.24, 0.17))])[chips]
    for _ in range(10):
        x, y = rng.uniform(0, size, 2)
        a = rng.normal(0.0, 0.3)
        stroke(img, x, y, np.cos(a), np.sin(a), rng.integers(3, 8), np.array([0.49, 0.52, 0.48]))
    return img


def cobblestone(size=128):
    """Calçamento da cidade lá fora (Final 2): pedras gastas de tamanhos parecidos, juntas escuras
    com terra e musgo, e a umidade da neblina."""
    rng = np.random.default_rng(181)
    f1, f2 = worley(size, 10, 181)
    edge = np.clip((f2 - f1) / 3.0, 0.0, 1.0)
    tone = spectral_noise(size, size, 0.9, 182)
    img = ramp(tone, [(0.0, (0.27, 0.27, 0.26)), (0.5, (0.37, 0.36, 0.34)), (1.0, (0.46, 0.45, 0.42))])
    # Cada pedra com o meio mais claro (gasto pelos passos).
    img *= (0.82 + 0.25 * np.sqrt(edge))[..., None]
    joints = edge < 0.32
    img[joints] = ramp(spectral_noise(size, size, 1.4, 183), [(0.0, (0.1, 0.1, 0.08)), (1.0, (0.2, 0.22, 0.15))])[joints]
    img[rng.random((size, size)) < 0.02] *= 0.85
    return img


def plaster(size=128):
    """Reboco das fachadas abandonadas: cal desbotada, manchas de chuva escorrendo e o tijolo
    aparecendo onde o reboco caiu."""
    rng = np.random.default_rng(191)
    v = spectral_noise(size, size, 1.4, 191) * 0.7 + spectral_noise(size, size, 0.5, 192) * 0.3
    img = ramp(v, [(0.0, (0.4, 0.39, 0.36)), (0.6, (0.53, 0.51, 0.47)), (1.0, (0.6, 0.58, 0.54))])
    streaks = spectral_noise(size, size, 1.6, 193, stretch_y=10.0)
    img *= (1.0 - 0.35 * np.clip((streaks - 0.5) * 3.0, 0.0, 1.0))[..., None]
    fallen = spectral_noise(size, size, 1.9, 194) > 0.78
    yy, xx = np.mgrid[0:size, 0:size]
    mortar = ((yy % 8) == 0) | (((xx + (yy // 8) % 2 * 8) % 16) == 0)
    brick = np.where(mortar[..., None], np.array([0.33, 0.31, 0.28]), np.array([0.45, 0.3, 0.24]))
    brick = brick * (0.85 + 0.15 * rng.random((size, size, 1)))
    img[fallen] = brick[fallen]
    return img


def ari_reflection(w=64, h=80):
    """O rosto de Ari no vidro da vitrine (Final 2, a única vez que aparece): 41 anos, magro de
    onze anos deitado, barba por fazer, o cabelo crescido e a coberta da cápsula nos ombros.
    Pintado de frente com luz de cima e da esquerda; o vidro escurece e desbota o resto."""
    rng = np.random.default_rng(2714)
    yy, xx = np.mgrid[0:h, 0:w] + 0.5
    rgb = np.zeros((h, w, 3))
    alpha = np.zeros((h, w))
    grain = spectral_noise(h, w, 0.6, 2715)
    cx, cy, rx, ry = 32.0, 30.0, 14.5, 19.0
    # O queixo afina: a largura da cabeça cai embaixo.
    dy = (yy - cy) / ry
    rx_at = rx * (1.0 - 0.28 * np.clip(dy, 0.0, 1.0) ** 2)
    dx = (xx - cx) / rx_at
    head = dx * dx + dy * dy <= 1.0
    # Pescoço e a coberta caindo dos ombros.
    neck = (np.abs(xx - cx) < 6.5) & (yy > cy + 12) & (yy < 60)
    shoulder_half = np.clip(10.0 + (yy - 54.0) * 1.6, 0.0, 31.0)
    blanket = (yy > 54) & (np.abs(xx - cx + 0.5 * np.sin(yy * 0.3)) < shoulder_half)
    ear_l = ((xx - (cx - rx - 0.5)) / 2.6) ** 2 + ((yy - (cy + 1.0)) / 4.5) ** 2 <= 1.0
    ear_r = ((xx - (cx + rx + 0.5)) / 2.6) ** 2 + ((yy - (cy + 1.0)) / 4.5) ** 2 <= 1.0
    ears = ear_l | ear_r
    # Luz: a cabeça como uma bola, luz de cima e da esquerda.
    nz = np.sqrt(np.clip(1.0 - dx * dx - dy * dy, 0.0, 1.0))
    light = np.clip(-0.45 * dx - 0.5 * dy + 0.75 * nz, 0.0, 1.0)
    skin = np.array([0.72, 0.62, 0.55])
    face = skin * (0.42 + 0.58 * light)[..., None]

    def blob(x, y, ax, ay):
        return np.exp(-(((xx - x) / ax) ** 2 + ((yy - y) / ay) ** 2))

    # Órbitas fundas, maçãs do rosto marcadas e o rosto chupado embaixo delas.
    shade = 1.0 - 0.5 * (blob(cx - 6, cy - 1, 4.0, 2.6) + blob(cx + 6, cy - 1, 4.0, 2.6))
    shade -= 0.28 * (blob(cx - 9, cy + 8, 3.0, 4.0) + blob(cx + 9, cy + 8, 3.0, 4.0))
    shade += 0.12 * (blob(cx - 8, cy + 3, 3.0, 1.8) + blob(cx + 8, cy + 3, 3.0, 1.8))
    # Nariz: o lado direito na sombra, a ponta e as narinas.
    shade -= 0.3 * blob(cx + 1.8, cy + 4, 1.0, 4.5)
    shade += 0.15 * blob(cx - 0.8, cy + 4, 0.9, 4.0)
    shade -= 0.45 * (blob(cx - 1.6, cy + 8.6, 0.9, 0.6) + blob(cx + 1.6, cy + 8.6, 0.9, 0.6))
    face *= np.clip(shade, 0.25, 1.3)[..., None]
    # Barba por fazer: escurece o queixo, o buço e o rosto embaixo das maçãs, com pontinhos.
    beard = np.clip((yy - (cy + 5.5)) / 4.0, 0.0, 1.0) * (np.abs(xx - cx) < rx_at * 0.92)
    beard = np.maximum(beard, 0.8 * blob(cx, cy + 10.2, 4.5, 1.0))
    dots = rng.random((h, w)) < 0.45
    face *= (1.0 - beard * (0.45 + 0.25 * dots))[..., None]
    # Boca: uma linha fina, caída nos cantos.
    mouth = (np.abs(yy - (cy + 12.3 + 0.03 * (xx - cx) ** 2)) < 0.6) & (np.abs(xx - cx) < 4.2)
    face[mouth] *= 0.35
    # Olhos: a íris escura e o brilho úmido; sobrancelhas grossas.
    for side in (-1, 1):
        ex = cx + side * 6.0
        iris = ((xx - ex) / 1.6) ** 2 + ((yy - (cy - 0.8)) / 1.1) ** 2 <= 1.0
        white = ((xx - ex) / 2.8) ** 2 + ((yy - (cy - 0.8)) / 1.1) ** 2 <= 1.0
        face[white & ~iris] = np.array([0.5, 0.47, 0.43])
        face[iris] = np.array([0.1, 0.09, 0.08])
        face[(np.abs(xx - (ex - 0.6)) < 0.5) & (np.abs(yy - (cy - 1.3)) < 0.5)] = np.array([0.8, 0.8, 0.78])
        brow = (np.abs(yy - (cy - 5.0 + 0.02 * (xx - ex) ** 2)) < 0.9) & (np.abs(xx - ex) < 3.6)
        face[brow] *= 0.35
    # Cabelo crescido, despenteado, caindo na testa e sobre as orelhas.
    fringe = cy - ry * 0.42 + (grain - 0.5) * 6.0 + 1.5 * np.sin(xx * 0.9)
    hair_top = head & (yy < fringe)
    hair_sides = (np.abs(xx - cx) > rx_at * 0.86) & (yy < cy + 4) & (head | ears)
    hair_out = (((xx - cx) / (rx + 2.5)) ** 2 + ((yy - (cy - 3)) / (ry + 1.5)) ** 2 <= 1.0) & (yy < cy - 4) & (grain > 0.35)
    hair = hair_top | hair_sides | (hair_out & ~head)
    hair_color = ramp(grain, [(0.0, (0.1, 0.09, 0.08)), (1.0, (0.26, 0.23, 0.2))]) * (0.6 + 0.4 * light)[..., None]
    neck_color = skin * (0.32 + 0.12 * (1.0 - np.abs(xx - cx) / 7.0))[..., None]
    blanket_color = ramp(spectral_noise(h, w, 1.1, 2716), [(0.0, (0.2, 0.23, 0.2)), (1.0, (0.36, 0.4, 0.34))])
    blanket_color *= (0.8 + 0.2 * np.sin(xx * 0.7 + yy * 0.25))[..., None]
    rgb[blanket] = blanket_color[blanket]
    alpha[blanket] = 1.0
    rgb[neck & ~blanket] = neck_color[neck & ~blanket]
    alpha[neck] = 1.0
    rgb[ears] = skin * 0.55
    alpha[ears] = 1.0
    rgb[head] = face[head]
    alpha[head] = 1.0
    rgb[hair] = hair_color[hair]
    alpha[hair] = 1.0
    # Desbotado e granulado, como se visse no vidro sujo; embaixo some no escuro.
    rgb = rgb * 0.85 + rgb.mean(axis=-1, keepdims=True) * 0.15
    rgb *= (0.9 + 0.2 * grain)[..., None]
    alpha *= 1.0 - np.clip((yy - 66.0) / 14.0, 0.0, 1.0)
    return fill_transparent(rgb, alpha), alpha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    print("Gerando texturas em", OUT)
    save("ground_grass.png", ground_grass())
    save("ground_dirt.png", ground_dirt())
    save("ground_forest.png", ground_forest())
    save("rock.png", rock())
    save("bark.png", bark())
    save("fur.png", fur())
    save("pelt.png", pelt())
    save("bristle.png", bristle())
    save("plumage.png", plumage())
    save("grass_card.png", *grass_card())
    save("pine_branch.png", *pine_branch())
    save("leaves_card.png", *leaves_card())
    save("leaf.png", *leaf())
    save("bush_card.png", *bush_card())
    save("berry_card.png", *berry_card())
    save("goblin_skin.png", goblin_skin())
    save("goblin_cloth.png", goblin_cloth())
    save("leather.png", leather())
    save("wood.png", wood())
    save("concrete.png", concrete())
    save("concrete_floor.png", concrete_floor())
    save("metal.png", metal())
    save("cobblestone.png", cobblestone())
    save("plaster.png", plaster())
    save("ari_reflection.png", *ari_reflection())
    save("tree_blaze.png", *tree_blaze())
    save("smoke_puff.png", *smoke_puff())
    save_gray("macro_noise.png", spectral_noise(256, 256, 1.8, 101))
    save_gray("dither_noise.png", spectral_noise(64, 64, 0.2, 102))


if __name__ == "__main__":
    main()
