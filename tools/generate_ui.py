"""Gera a fonte pixelada e as texturas da interface em assets/ui/.

Tudo procedural e determinístico (sementes fixas), no estilo "realista retrô" do jogo:
pedra escura, linhas gastas, pontilhado (dither) no lugar de degradê e filtro nearest.

- A fonte "Toca" é desenhada aqui à mão, pixel a pixel: maiúsculas de 9 px, minúsculas de 6 px,
  descendentes de 3 px. Os acentos são compostos sobre a letra. Sai em BMFont (texto) em três
  pesos: normal, negrito (a letra engrossada 1 px) e itálico (as linhas de cima puxadas 1 px).
- As texturas são 9-patch para o Theme (assets/ui/ui_theme.tres): painel, botões, faixa de
  seleção, mancha de fundo do HUD, tecla, slider, caixa de marcar e barra de rolagem.
- Peças dos menus (UiStyle): os painéis de rocha (rock_*.png, a 3x), o logo "A TOCA", os riscos, a
  boca da caverna, a tecla-lápide do rodapé, o marcador laranja de foco, as setas da lista de
  fabricar e o atlas de ícones dos itens do HUD (item_icons.png, na ordem de ICONS).

Uso (na raiz do projeto): python tools/generate_ui.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"

# --- Fonte ----------------------------------------------------------------------------------------

# Linhas da fonte: 0-2 acentos das maiúsculas, 3-11 corpo (maiúscula de 9), linha de base depois
# da 11, 12-14 descendentes. O desenho de cada letra começa na linha 3.
TOP = 3
CELL_H = 15
LINE_H = 16
BASE = 12

# Cada letra: "@<letra>" (ou "@U+XXXX") e, opcional, "+N" linhas vazias em cima; depois as linhas,
# "#" = tinta. Letras sem descendente podem parar na linha de base.
GLYPHS = r"""
@A
..##..
.#..#.
#....#
#....#
#....#
######
#....#
#....#
#....#
@B
#####.
#....#
#....#
#....#
#####.
#....#
#....#
#....#
#####.
@C
.####.
#....#
#.....
#.....
#.....
#.....
#.....
#....#
.####.
@D
####..
#...#.
#....#
#....#
#....#
#....#
#....#
#...#.
####..
@E
######
#.....
#.....
#.....
####..
#.....
#.....
#.....
######
@F
######
#.....
#.....
#.....
####..
#.....
#.....
#.....
#.....
@G
.####.
#....#
#.....
#.....
#..###
#....#
#....#
#....#
.####.
@H
#....#
#....#
#....#
#....#
######
#....#
#....#
#....#
#....#
@I
###
.#.
.#.
.#.
.#.
.#.
.#.
.#.
###
@J
..####
....#.
....#.
....#.
....#.
....#.
#...#.
#...#.
.###..
@K
#....#
#...#.
#..#..
#.#...
##....
#.#...
#..#..
#...#.
#....#
@L
#.....
#.....
#.....
#.....
#.....
#.....
#.....
#.....
######
@M
#.....#
##...##
#.#.#.#
#..#..#
#.....#
#.....#
#.....#
#.....#
#.....#
@N
#....#
##...#
##...#
#.#..#
#.#..#
#..#.#
#...##
#...##
#....#
@O
.####.
#....#
#....#
#....#
#....#
#....#
#....#
#....#
.####.
@P
#####.
#....#
#....#
#....#
#####.
#.....
#.....
#.....
#.....
@Q
.####.
#....#
#....#
#....#
#....#
#....#
#..#.#
#...#.
.###.#
@R
#####.
#....#
#....#
#....#
#####.
#..#..
#...#.
#....#
#....#
@S
.####.
#....#
#.....
#.....
.####.
.....#
.....#
#....#
.####.
@T
#######
...#...
...#...
...#...
...#...
...#...
...#...
...#...
...#...
@U
#....#
#....#
#....#
#....#
#....#
#....#
#....#
#....#
.####.
@V
#.....#
#.....#
#.....#
.#...#.
.#...#.
.#...#.
..#.#..
..#.#..
...#...
@W
#.....#
#.....#
#.....#
#.....#
#..#..#
#..#..#
#.#.#.#
##...##
#.....#
@X
#....#
#....#
.#..#.
.#..#.
..##..
.#..#.
.#..#.
#....#
#....#
@Y
#.....#
#.....#
.#...#.
..#.#..
...#...
...#...
...#...
...#...
...#...
@Z
######
.....#
....#.
....#.
...#..
..#...
.#....
#.....
######
@a +3
.###.
....#
.####
#...#
#...#
.####
@b
#....
#....
#....
####.
#...#
#...#
#...#
#...#
####.
@c +3
.###.
#...#
#....
#....
#...#
.###.
@d
....#
....#
....#
.####
#...#
#...#
#...#
#...#
.####
@e +3
.###.
#...#
#####
#....
#...#
.###.
@f
..##
.#..
.#..
####
.#..
.#..
.#..
.#..
.#..
@g +3
.####
#...#
#...#
#...#
#...#
.####
....#
#...#
.###.
@h
#....
#....
#....
####.
#...#
#...#
#...#
#...#
#...#
@i
...
.#.
...
##.
.#.
.#.
.#.
.#.
###
@U+0131 +3
##.
.#.
.#.
.#.
.#.
###
@j
...
..#
...
.##
..#
..#
..#
..#
..#
..#
#.#
.#.
@k
#...
#...
#...
#..#
#.#.
##..
#.#.
#..#
#..#
@l
##.
.#.
.#.
.#.
.#.
.#.
.#.
.#.
###
@m +3
###.##.
#..#..#
#..#..#
#..#..#
#..#..#
#..#..#
@n +3
####.
#...#
#...#
#...#
#...#
#...#
@o +3
.###.
#...#
#...#
#...#
#...#
.###.
@p +3
####.
#...#
#...#
#...#
#...#
####.
#....
#....
#....
@q +3
.####
#...#
#...#
#...#
#...#
.####
....#
....#
....#
@r +3
#.##
##..
#...
#...
#...
#...
@s +3
.####
#....
.###.
....#
....#
####.
@t
....
.#..
.#..
####
.#..
.#..
.#..
.#..
..##
@u +3
#...#
#...#
#...#
#...#
#...#
.####
@v +3
#...#
#...#
#...#
.#.#.
.#.#.
..#..
@w +3
#.....#
#.....#
#..#..#
#..#..#
#.#.#.#
.#...#.
@x +3
#...#
.#.#.
..#..
..#..
.#.#.
#...#
@y +3
#...#
#...#
#...#
#...#
#...#
.####
....#
#...#
.###.
@z +3
#####
...#.
..#..
.#...
#....
#####
@0
.###.
#...#
#..##
#.#.#
#.#.#
#.#.#
##..#
#...#
.###.
@1
..#..
.##..
#.#..
..#..
..#..
..#..
..#..
..#..
#####
@2
.###.
#...#
....#
....#
...#.
..#..
.#...
#....
#####
@3
.###.
#...#
....#
....#
..##.
....#
....#
#...#
.###.
@4
...#.
..##.
.#.#.
#..#.
#..#.
#####
...#.
...#.
...#.
@5
#####
#....
#....
####.
....#
....#
....#
#...#
.###.
@6
.###.
#...#
#....
#....
####.
#...#
#...#
#...#
.###.
@7
#####
....#
....#
...#.
...#.
..#..
..#..
..#..
..#..
@8
.###.
#...#
#...#
#...#
.###.
#...#
#...#
#...#
.###.
@9
.###.
#...#
#...#
#...#
.####
....#
....#
#...#
.###.
@!
#
#
#
#
#
#
.
.
#
@"
#.#
#.#
@#
.....
.#.#.
.#.#.
#####
.#.#.
#####
.#.#.
.#.#.
@$
..#..
.####
#.#..
#.#..
.###.
..#.#
..#.#
####.
..#..
@%
##..#
##..#
...#.
...#.
..#..
.#...
.#...
#..##
#..##
@&
.##...
#..#..
#..#..
.##...
.#..#.
#.#.#.
#..#..
#..##.
.##..#
@'
#
#
@(
..#
.#.
.#.
#..
#..
#..
#..
#..
.#.
.#.
..#
@)
#..
.#.
.#.
..#
..#
..#
..#
..#
.#.
.#.
#..
@*
.....
..#..
#.#.#
.###.
#.#.#
..#..
@+ +3
..#..
..#..
#####
..#..
..#..
@, +7
.#
.#
#.
@- +5
####
@. +7
##
##
@/
....#
....#
...#.
...#.
..#..
.#...
.#...
#....
#....
@: +3
##
##
..
..
##
##
@; +3
##
##
..
..
##
##
.#
#.
@< +3
...#
..#.
.#..
#...
.#..
..#.
...#
@= +4
#####
.....
#####
@> +3
#...
.#..
..#.
...#
..#.
.#..
#...
@?
.###.
#...#
....#
...#.
..#..
..#..
.....
.....
..#..
@@
.#####.
#.....#
#..##.#
#.#.#.#
#.#.#.#
#..##.#
#......
#.....#
.#####.
@[
###
#..
#..
#..
#..
#..
#..
#..
#..
#..
###
@\
#....
#....
.#...
.#...
..#..
...#.
...#.
....#
....#
@]
###
..#
..#
..#
..#
..#
..#
..#
..#
..#
###
@^
..#..
.#.#.
#...#
@_ +9
######
@`
#.
.#
@{
..##
.#..
.#..
.#..
#...
.#..
.#..
.#..
.#..
.#..
..##
@|
#
#
#
#
#
#
#
#
#
#
#
@}
##..
..#.
..#.
..#.
...#
..#.
..#.
..#.
..#.
..#.
##..
@~ +4
.##..#
#..##.
@U+00B7 +4
##
##
@U+2022 +3
.##.
####
####
.##.
@U+2014 +5
#########
@U+2013 +5
######
@U+2026 +7
#.#.#
#.#.#
@U+203A +3
#..
.#.
..#
.#.
#..
@U+2039 +3
..#
.#.
#..
.#.
..#
@U+00BB +3
#..#..
.#..#.
..#..#
.#..#.
#..#..
@U+00AB +3
..#..#
.#..#.
#..#..
.#..#.
..#..#
@U+2192 +3
....#..
.....#.
#######
.....#.
....#..
@U+2190 +3
..#....
.#.....
#######
.#.....
..#....
@U+2191
..#..
.###.
#.#.#
..#..
..#..
..#..
..#..
..#..
..#..
@U+2193
..#..
..#..
..#..
..#..
..#..
..#..
#.#.#
.###.
..#..
@U+2665 +2
.##.##.
#######
#######
.#####.
..###..
...#...
@U+2082 +6
##.
..#
.#.
#..
###
@U+00B0
.#.
#.#
.#.
@U+00AA
.##.
...#
.###
#..#
.###
....
####
@U+00BA
.##.
#..#
#..#
.##.
....
####
@U+00D7 +3
#...#
.#.#.
..#..
.#.#.
#...#
@U+2265 +1
#....
.##..
...##
.##..
#....
.....
#####
@U+201C
.#.#
#.#.
@U+201D
.#.#
#.#.
@U+2018
.#
#.
@U+2019
.#
#.
@U+00A1 +2
#
.
.
#
#
#
#
#
#
@U+00BF +2
..#..
.....
.....
..#..
..#..
.#...
#....
#...#
.###.
"""

# Acentos: duas linhas, sobre a letra (com uma linha de folga).
ACCENTS = {
    "acute": [".#", "#."],
    "grave": ["#.", ".#"],
    "circ": [".#.", "#.#"],
    "tilde": [".#.#", "#.#."],
    "diaer": ["...", "#.#"],
}

COMPOSED = {
    "Á": ("A", "acute"), "À": ("A", "grave"), "Â": ("A", "circ"), "Ã": ("A", "tilde"), "Ä": ("A", "diaer"),
    "É": ("E", "acute"), "È": ("E", "grave"), "Ê": ("E", "circ"), "Ë": ("E", "diaer"),
    "Í": ("I", "acute"), "Ì": ("I", "grave"), "Î": ("I", "circ"), "Ï": ("I", "diaer"),
    "Ó": ("O", "acute"), "Ò": ("O", "grave"), "Ô": ("O", "circ"), "Õ": ("O", "tilde"), "Ö": ("O", "diaer"),
    "Ú": ("U", "acute"), "Ù": ("U", "grave"), "Û": ("U", "circ"), "Ü": ("U", "diaer"),
    "Ñ": ("N", "tilde"),
    "á": ("a", "acute"), "à": ("a", "grave"), "â": ("a", "circ"), "ã": ("a", "tilde"), "ä": ("a", "diaer"),
    "é": ("e", "acute"), "è": ("e", "grave"), "ê": ("e", "circ"), "ë": ("e", "diaer"),
    "í": ("ı", "acute"), "ì": ("ı", "grave"), "î": ("ı", "circ"), "ï": ("ı", "diaer"),
    "ó": ("o", "acute"), "ò": ("o", "grave"), "ô": ("o", "circ"), "õ": ("o", "tilde"), "ö": ("o", "diaer"),
    "ú": ("u", "acute"), "ù": ("u", "grave"), "û": ("u", "circ"), "ü": ("u", "diaer"),
    "ñ": ("n", "tilde"),
}


def parse_glyphs():
    glyphs = {}
    char = None
    rows = []

    def close():
        if char is None:
            return
        width = len(rows[0])
        assert all(len(r) == width for r in rows), f"linhas de larguras diferentes em {char!r}"
        cell = np.zeros((CELL_H, width), dtype=bool)
        for y, row in enumerate(rows):
            cell[TOP + pad + y] = [c == "#" for c in row]
        glyphs[char] = cell

    pad = 0
    for line in GLYPHS.strip("\n").split("\n"):
        if line.startswith("@") and (char is None or rows):
            close()
            head = line[1:]
            pad = 0
            if " +" in head:
                head, n = head.rsplit(" +", 1)
                pad = int(n)
            char = chr(int(head[2:], 16)) if head.startswith("U+") and len(head) > 2 else head
            rows = []
        else:
            rows.append(line)
    close()
    for char, (base, accent) in COMPOSED.items():
        cell = glyphs[base].copy()
        mark = ACCENTS[accent]
        top = int(np.argmax(cell.any(axis=1)))
        aw = len(mark[0])
        width = max(cell.shape[1], aw)
        if width > cell.shape[1]:
            cell = np.pad(cell, ((0, 0), (0, width - cell.shape[1])))
        x0 = (width - aw + 1) // 2
        for i, row in enumerate(mark):
            y = top - 3 + i
            for j, c in enumerate(row):
                if c == "#":
                    cell[y, x0 + j] = True
        glyphs[char] = cell
    # Ç e ç: a cedilha embaixo da letra.
    for char, base in (("Ç", "C"), ("ç", "c")):
        cell = glyphs[base].copy()
        x = cell.shape[1] // 2
        cell[BASE, x] = True
        cell[BASE + 1, x - 1] = True
        glyphs[char] = cell
    return glyphs


def bold(cell):
    out = np.pad(cell, ((0, 0), (0, 1)))
    out[:, 1:] |= cell
    return out


def italic(cell):
    # As linhas de cima da metade do corpo vão 1 px para a direita.
    out = np.pad(cell, ((0, 0), (0, 1)))
    for y in range(CELL_H):
        if y < 7:
            out[y] = np.roll(out[y], 1)
    return out


def write_font(glyphs, name, face):
    cols = 16
    cell_w = 12
    rows = (len(glyphs) + cols - 1) // cols
    sheet_w = 256
    sheet_h = 1
    while sheet_h < rows * (CELL_H + 1):
        sheet_h *= 2
    sheet = np.zeros((sheet_h, sheet_w, 4), dtype=np.uint8)
    lines = []
    chars = []
    for i, (char, cell) in enumerate(sorted(glyphs.items(), key=lambda kv: ord(kv[0]))):
        x = (i % cols) * (cell_w + 4)
        y = (i // cols) * (CELL_H + 1)
        h, w = cell.shape
        sheet[y:y + h, x:x + w, :3] = 255
        sheet[y:y + h, x:x + w, 3] = np.where(cell, 255, 0)
        chars.append(f"char id={ord(char)} x={x} y={y} width={w} height={h} xoffset=0 yoffset=0 "
                     f"xadvance={w + 1} page=0 chnl=15")
    space_w = 4
    chars.insert(0, f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={space_w} page=0 chnl=15")
    chars.insert(1, f"char id=160 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={space_w} page=0 chnl=15")
    lines.append(f'info face="{face}" size={LINE_H} bold=0 italic=0 charset="" unicode=1 stretchH=100 '
                 'smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0')
    lines.append(f"common lineHeight={LINE_H} base={BASE} scaleW={sheet_w} scaleH={sheet_h} pages=1 packed=0")
    lines.append(f'page id=0 file="{name}.png"')
    lines.append(f"chars count={len(chars)}")
    lines += chars
    Image.fromarray(sheet, "RGBA").save(OUT / "font" / f"{name}.png")
    (OUT / "font" / f"{name}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")


# --- Texturas -------------------------------------------------------------------------------------

# Paleta: pedra escura, linha de ferro gasto, osso e ocre de vela (a mesma de UiStyle).
STONE = np.array([17, 18, 18])
EDGE = np.array([6, 7, 7])
LINE = np.array([86, 86, 78])
ACCENT = np.array([196, 172, 118])
BONE = np.array([214, 209, 194])
# Laranja do marcador de foco (o único ponto quente da interface).
MARK = np.array([224, 148, 64])

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1.0 / 32.0


def dither(alpha):
    """Alpha contínuo (0..1) vira pontilhado de 0/1 pela matriz de Bayer."""
    h, w = alpha.shape
    tile = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    return (alpha > tile).astype(float)


def rgba(rgb, alpha):
    h, w = alpha.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    return out


def save(name, pixels):
    Image.fromarray(pixels, "RGBA").save(OUT / f"{name}.png")


def stone_fill(h, w, seed, base=STONE, spread=7.0):
    rng = np.random.default_rng(seed)
    grain = rng.normal(0.0, 1.0, (h, w))
    return base[None, None, :] + grain[..., None] * spread


def framed(size, margin, seed, fill_alpha, line, base=STONE, rivets=True, worn=0.12):
    """Painel 9-patch: borda escura, linha gasta por dentro, cantos cortados e cravos."""
    rng = np.random.default_rng(seed)
    rgb = stone_fill(size, size, seed, base)
    alpha = np.full((size, size), fill_alpha)
    yy, xx = np.mgrid[0:size, 0:size]
    edge = (xx == 0) | (yy == 0) | (xx == size - 1) | (yy == size - 1)
    rgb[edge] = EDGE
    alpha[edge] = 1.0
    inner = ((xx == 2) | (yy == 2) | (xx == size - 3) | (yy == size - 3)) & (xx >= 2) & (yy >= 2) \
        & (xx <= size - 3) & (yy <= size - 3)
    keep = rng.random((size, size)) > worn
    rgb[inner & keep] = line
    rgb[inner & ~keep] = line * 0.6
    alpha[inner] = 1.0
    # Cantos cortados (um pixel fora) e o vão escuro entre a borda e a linha.
    for cy in (0, size - 1):
        for cx in (0, size - 1):
            alpha[cy, cx] = 0.0
    if rivets:
        for cy in (4, size - 5):
            for cx in (4, size - 5):
                rgb[cy, cx] = line * 1.35
                alpha[cy, cx] = 1.0
    return rgba(rgb, alpha)


def plate(width, height, fade, seed):
    """Faixa de seleção: um brilho quente e baixo atrás do item em foco, que some em pontilhado
    para a direita (e um pouco nas pontas de cima e de baixo). O marcador ocre fica fora dela."""
    x = np.arange(width)
    ramp_x = np.clip((width - x) / fade, 0.0, 1.0) * np.clip((x + 1) / 6.0, 0.0, 1.0)
    y = np.arange(height)
    ramp_y = np.clip(np.minimum(y + 1, height - y) / 3.0, 0.0, 1.0)
    alpha = dither(np.outer(ramp_y, ramp_x) * 0.85)
    rgb = stone_fill(height, width, seed, np.array([44, 39, 32]), 3.0)
    return rgba(rgb, alpha)


def smudge(width, height, edge_x, edge_y, strength):
    """Mancha escura de bordas pontilhadas, atrás dos textos do HUD (lê sobre a neblina clara)."""
    x = np.minimum(np.arange(width), width - 1 - np.arange(width)) / edge_x
    y = np.minimum(np.arange(height), height - 1 - np.arange(height)) / edge_y
    a = np.clip(np.minimum.outer(np.clip(y, 0, 1), np.clip(x, 0, 1)), 0, 1)
    a = a * a * (3 - 2 * a) * strength
    alpha = dither(a) * strength
    rgb = np.zeros((height, width, 3)) + np.array([8, 9, 9])
    return rgba(rgb, alpha)


def sprite(art, palette):
    rows = art.strip().split()
    h, w = len(rows), len(rows[0])
    out = np.zeros((h, w, 4), dtype=np.uint8)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in palette:
                out[y, x, :3] = palette[c]
                out[y, x, 3] = 255
    return out


def with_shadow(pixels, strength=0.65):
    """Sombra de 1 texel para baixo e para a direita: o desenho lê sobre a neblina clara."""
    h, w = pixels.shape[:2]
    out = np.zeros((h + 1, w + 1, 4), dtype=np.uint8)
    solid = pixels[..., 3] > 0
    out[1:, 1:, :3] = EDGE
    out[1:, 1:, 3] = np.where(solid, int(255 * strength), 0)
    top = out[:h, :w]
    top[solid] = pixels[solid]
    return out


def mask_sprite(mask, color, seed, grain=7.0):
    """Máscara (bool) pintada numa cor com grão, sem antialias."""
    rgb = stone_fill(*mask.shape, seed, color, grain)
    return rgba(rgb, mask.astype(float))


def draw_mask(width, height, draw):
    """Máscara desenhada com o ImageDraw do Pillow (sem antialias) na resolução do texel."""
    img = Image.new("L", (width, height), 0)
    draw(ImageDraw.Draw(img))
    return np.array(img) > 127


def neighbors(mask):
    """Quantos dos 4 vizinhos de cada texel estão na máscara."""
    pad = np.pad(mask, 1)
    return pad[:-2, 1:-1].astype(int) + pad[2:, 1:-1] + pad[1:-1, :-2] + pad[1:-1, 2:]


def rock_panel(width, height, profile, seed):
    """Painel de rocha dos menus (desenhado a 3x): pedra quase preta, colada à esquerda da tela,
    cuja borda direita é uma silhueta irregular em degraus que se desfaz em pontilhado.
    `profile` = [(altura 0..1, x da borda em texels)], com relevo por cima."""
    rng = np.random.default_rng(seed)
    rows = np.arange(height)
    ys, xs = zip(*profile)
    edge = np.interp(rows / (height - 1), ys, xs)
    for scale, amp in ((34, 8.0), (11, 3.5), (4, 1.5)):
        knots = rng.normal(0.0, 1.0, height // scale + 2)
        edge = edge + np.interp(rows / scale, np.arange(knots.size), knots) * amp
    # A borda anda em blocos de 3 linhas (degraus de rocha pixelada), não em rampa, e às vezes
    # um bloco salta para fora ou para dentro (lascas e saliências).
    jumps = rng.normal(0.0, 1.0, height // 6 + 1) * (rng.random(height // 6 + 1) < 0.35) * 4.0
    edge = np.repeat(edge[::3], 3)[:height] + np.repeat(jumps, 6)[:height]
    dist = edge[:, None] - np.arange(width)[None, :]
    grain = rng.random((height, width))
    # Fora da borda, pontos escuros que rareiam por ~7 texels; dentro, perto dela, uns furos.
    fringe = dither(np.clip(1.0 + dist / 7.0, 0.0, 1.0) ** 1.7 * 0.8) * (grain > 0.3)
    alpha = np.where(dist > 0, 1.0, fringe)
    holes = (dist > 0) & (dist < 5) & (grain < 0.045 * (5 - dist))
    alpha = np.where(holes, 0.0, alpha)
    rgb = stone_fill(height, width, seed, np.array([11, 11, 11]), 1.6)
    rgb += ((grain > 0.985) * 8.0)[..., None]
    # Um fio de rocha mais clara rente à borda (a pedra pega a luz da neblina).
    rim = (dist > 0) & (dist < 2.5)
    rgb[rim] += 7.0
    return rgba(rgb, alpha)


def roughen(mask, seed, chips=0.14, bumps=0.035):
    """Lascas e calombos na borda de uma máscara: letras entalhadas, não fundidas."""
    rng = np.random.default_rng(seed)
    near = neighbors(mask)
    border = mask & (near < 4)
    mask = mask & ~(border & (rng.random(mask.shape) < chips))
    outside = ~mask & (neighbors(mask) > 0)
    return mask | (outside & (rng.random(mask.shape) < bumps))


def logo():
    """O logo "A TOCA" (desenhado a 3x): letras grossas cor de osso, como entalhadas, o T mais alto
    e o O trocado por um arco de caverna."""
    base, top = 37, 16

    def letters(d):
        for x0 in (1, 111):  # os dois "A"
            d.polygon([(x0, base), (x0 + 7, top), (x0 + 15, top), (x0 + 22, base)], fill=255)
            d.polygon([(x0 + 7, base + 1), (x0 + 11, 32), (x0 + 15, base + 1)], fill=0)
            d.polygon([(x0 + 8, 28), (x0 + 11, 20), (x0 + 14, 28)], fill=0)
        d.polygon([(28, 5), (59, 2), (60, 10), (28, 11)], fill=255)  # T, a barra torta
        d.rectangle([40, 3, 47, 39], fill=255)
        d.pieslice([57, 13, 89, 61], 180, 360, fill=255)  # a boca da caverna
        d.ellipse([65, 22, 81, 40], fill=0)
        d.rectangle([65, 31, 81, base + 1], fill=0)
        d.rectangle([93, top, 107, base], fill=255)  # C
        d.rectangle([99, 22, 108, 31], fill=0)

    mask = roughen(draw_mask(136, 42, letters), 346)
    rng = np.random.default_rng(347)
    # Escorridos de tinta embaixo de algumas letras.
    for x in rng.choice(np.flatnonzero(mask[base]), 5, replace=False):
        mask[base + 1:base + 1 + rng.integers(1, 3), x] = True
    pixels = mask_sprite(mask, BONE, 348, 6.0)
    # Mais escuro embaixo e uns pontos fundos (o entalhe).
    shade = np.clip((np.arange(42) - top) / (base - top), 0, 1)[:, None] * 0.12
    dark = mask & (rng.random(mask.shape) < 0.05)
    rgb = pixels[..., :3].astype(float) * (1.0 - shade[..., None])
    rgb[dark] *= 0.78
    pixels[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return with_shadow(pixels, 0.7)


def cave_icon():
    """A boca da caverna: um morro cor de osso com o arco escuro embaixo (desenhado a 3x)."""
    def shape(d):
        d.pieslice([0, 0, 23, 38], 180, 360, fill=255)
        d.pieslice([7, 8, 16, 30], 180, 360, fill=0)

    mask = roughen(draw_mask(24, 20, shape), 52, 0.1, 0.0)
    return with_shadow(mask_sprite(mask, BONE, 53, 5.0))


def key_icon():
    """A tecla do rodapé dos menus: uma lápide em arco, só o contorno, com um "I" (desenhada a 2x)."""
    def shape(d):
        d.arc([3, 0, 19, 14], 180, 360, fill=255)
        d.line([(3, 7), (0, 19)], fill=255)
        d.line([(19, 7), (22, 19)], fill=255)
        d.line([(0, 19), (22, 19)], fill=255)
        d.line([(11, 7), (11, 14)], fill=255)
        d.line([(9, 7), (13, 7)], fill=255)
        d.line([(9, 14), (13, 14)], fill=255)

    return with_shadow(mask_sprite(draw_mask(23, 20, shape), BONE, 54, 4.0))


# Ícones do HUD (12×12, desenhados a 2x), na ordem do atlas item_icons.png. UiStyle.ICONS
# precisa ter a mesma ordem. "a" = osso, "b" = osso apagado.
ICONS = {
    "arrow": """
        ........aaaa
        .........aaa
        ........a.aa
        .......a...a
        ......a.....
        .....a......
        ....a.......
        .b.a........
        .ba.........
        .aab........
        a..b........
        ............
    """,
    "feathered_arrow": """
        .........aaa
        ..........aa
        .........a.a
        ........a...
        .......a....
        ......a.....
        .a...a......
        .aa.a.......
        ..aa........
        .aaaa.......
        a..aa.......
        ...a........
    """,
    "bone_arrow": """
        ........aaaa
        .......aaaaa
        ........aaaa
        .......a.aaa
        ......a...a.
        .....a......
        ....a.......
        ...a........
        .ba.........
        .aab........
        a..b........
        ............
    """,
    "stone": """
        ............
        ............
        ....aaaa....
        ..aabbbbaa..
        .abbbbbbbba.
        .abbbbbbbbba
        abbbbbbbbbba
        abbbbbbbbbba
        .aaaaaaaaaa.
        ............
        ............
        ............
    """,
    "wood": """
        .........aa.
        ........a..a
        .......a..a.
        ......a..a..
        ..b..a..a...
        ...ba..a....
        ...a..a.....
        ..a..a......
        .a..a.......
        a..a........
        .aa.........
        ............
    """,
    "meat": """
        ............
        ....aaaa....
        ..aa....aa..
        .a..aa....a.
        a..a..a....a
        a..a..a....a
        a...aa....a.
        .a.......a..
        ..aaaaaaa...
        ............
        ............
        ............
    """,
    "cooked_meat": """
        ............
        ....aaaa....
        ..aabbbbaa..
        .abbaabbbba.
        abba..abbbba
        abba..abbbba
        abbbaabbbba.
        .abbbbbbba..
        ..aaaaaaa...
        ............
        ............
        ............
    """,
    "smoked_meat": """
        .....a......
        .....a......
        ....aaa.....
        ...ab.ba....
        ..a.b..ba...
        ..ab..b.a...
        ..a..b..a...
        ..ab...ba...
        ...a.b.a....
        ....aaa.....
        ............
        ............
    """,
    "rotten_meat": """
        ..b....b....
        ....b.....b.
        ....aa.a....
        ..aa....aa..
        .a..aa....a.
        a..a..a.....
        a..a..a....a
        ....aa....a.
        .a.......a..
        ..aa.aaaa...
        ............
        ............
    """,
    "berries": """
        ......b.....
        .....b......
        ...aaa.aaa..
        ..a...a...a.
        ..a...a...a.
        ...aaaaaaa..
        .....a...a..
        ....a.....a.
        ....a.....a.
        .....aaaaa..
        ............
        ............
    """,
    "mushroom": """
        ............
        ...aaaaaa...
        .aa.b..b.aa.
        a..........a
        aaaaaaaaaaaa
        ....a..a....
        ....a..a....
        ....a..a....
        ...aaaaaa...
        ............
        ............
        ............
    """,
    "white_meat": """
        ............
        ....aaaa....
        ..aaaaaaaa..
        .aaabbaaaaa.
        aaab..baaaaa
        aaab..baaaaa
        aaaabbaaaaa.
        .aaaaaaaaa..
        ..aaaaaaa...
        ............
        ............
        ............
    """,
    "hide": """
        ............
        .aa......aa.
        ..aaaaaaaa..
        ..a......a..
        ..a.b..b.a..
        ..a......a..
        ..a..bb..a..
        ..a......a..
        .aa......aa.
        ..aaaaaaaa..
        ............
        ............
    """,
    "bone": """
        ............
        ............
        .aa......aa.
        a..a....a..a
        a...aaaa...a
        .a........a.
        a...aaaa...a
        a..a....a..a
        .aa......aa.
        ............
        ............
        ............
    """,
    "feather": """
        ...........a
        .........aaa
        .......aa.ba
        ......a..ba.
        ....aa..ba..
        ...a...ba...
        ..a...ba....
        ..a..ba.....
        .a.aba......
        .aaa........
        .b..........
        b...........
    """,
    "snare": """
        ............
        ...aaaa.....
        ..a....a....
        .a......a...
        .a......a...
        .a......a...
        ..a....a....
        ...aa.a.....
        .....a......
        .....a......
        .....aaaaaa.
        ............
    """,
}


def item_icons():
    palette = {"a": BONE, "b": BONE * 0.62}
    return np.concatenate([with_shadow(sprite(art, palette)) for art in ICONS.values()], axis=1)


def textures():
    save("panel", framed(48, 8, 11, 0.9, LINE))
    save("panel_dark", framed(48, 8, 12, 0.96, LINE * 0.8, base=np.array([10, 11, 11]), rivets=False))
    save("button", framed(16, 4, 21, 0.82, LINE * 0.85, base=np.array([26, 27, 26]), rivets=False, worn=0.0))
    save("button_hover", framed(16, 4, 22, 0.9, ACCENT * 0.85, base=np.array([38, 36, 31]), rivets=False, worn=0.0))
    save("button_pressed", framed(16, 4, 23, 0.95, ACCENT, base=np.array([14, 14, 13]), rivets=False, worn=0.0))
    save("button_disabled", framed(16, 4, 24, 0.45, LINE * 0.45, base=np.array([20, 20, 20]), rivets=False, worn=0.3))
    # Foco: só um contorno ocre pontilhado (desenhado por cima do botão).
    focus = np.zeros((16, 16, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:16, 0:16]
    ring = ((xx == 1) | (yy == 1) | (xx == 14) | (yy == 14)) & (xx >= 1) & (yy >= 1) & (xx <= 14) & (yy <= 14)
    focus[ring & ((xx + yy) % 2 == 0)] = [*ACCENT, 255]
    save("focus", focus)
    save("plate", plate(256, 16, 200, 31))
    save("smudge", smudge(112, 24, 40.0, 8.0, 0.75))
    save("keycap", sprite("""
        .aaaaaaaaaa.
        abbbbbbbbbba
        abccccccccba
        abccccccccba
        abccccccccba
        abccccccccba
        abccccccccba
        abccccccccba
        abccccccccba
        abbbbbbbbbba
        adddddddddda
        .aaaaaaaaaa.
    """, {"a": EDGE, "b": LINE * 1.2, "c": np.array([34, 34, 31]), "d": LINE * 0.6}))
    save("slider", sprite("""
        aaaaaaaa
        bbbbbbbb
        cccccccc
        aaaaaaaa
    """, {"a": EDGE, "b": LINE * 0.7, "c": LINE * 0.4}))
    save("slider_fill", sprite("""
        aaaaaaaa
        bbbbbbbb
        cccccccc
        aaaaaaaa
    """, {"a": EDGE, "b": ACCENT, "c": ACCENT * 0.6}))
    grabber = """
        .aaaaa.
        abbbbba
        abcccba
        abcccba
        abcccba
        abcccba
        .abcba.
        ..aba..
        ...a...
    """
    save("grabber", sprite(grabber, {"a": EDGE, "b": LINE * 1.4, "c": np.array([40, 40, 36])}))
    save("grabber_hover", sprite(grabber, {"a": EDGE, "b": ACCENT, "c": ACCENT * 0.45}))
    box = """
        aaaaaaaaaaaa
        abbbbbbbbbba
        ab........ba
        ab........ba
        ab........ba
        ab........ba
        ab........ba
        ab........ba
        ab........ba
        ab........ba
        abbbbbbbbbba
        aaaaaaaaaaaa
    """
    save("check_off", sprite(box, {"a": EDGE, "b": LINE}))
    save("check_on", sprite("""
        aaaaaaaaaaaa
        abbbbbbbbbba
        ab........ba
        ab.cc..cc.ba
        ab..cccc..ba
        ab...cc...ba
        ab...cc...ba
        ab..cccc..ba
        ab.cc..cc.ba
        ab........ba
        abbbbbbbbbba
        aaaaaaaaaaaa
    """, {"a": EDGE, "b": ACCENT * 0.9, "c": ACCENT}))
    save("arrow_down", sprite("""
        a.....a
        aa...aa
        .aa.aa.
        ..aaa..
        ...a...
    """, {"a": LINE * 1.6}))
    save("scroll", sprite("""
        a..
        ...
        .a.
        ...
    """, {"a": LINE * 0.8}))
    save("scroll_grabber", sprite("""
        .aaa.
        abbba
        abbba
        abbba
        abbba
        .aaa.
    """, {"a": EDGE, "b": LINE * 1.3}))
    save("scroll_grabber_hover", sprite("""
        .aaa.
        abbba
        abbba
        abbba
        abbba
        .aaa.
    """, {"a": EDGE, "b": ACCENT}))
    # Linha de separação: some nas pontas em pontilhado.
    x = np.arange(96)
    a = np.clip(np.minimum(x, 95 - x) / 30.0, 0, 1)
    sep = np.zeros((3, 96, 4), dtype=np.uint8)
    sep[1, :, :3] = LINE
    sep[1, :, 3] = (dither(a[None, :])[0] * 255).astype(np.uint8)
    save("separator", sep)
    # Aba escolhida: um traço ocre embaixo.
    tab = np.zeros((8, 8, 4), dtype=np.uint8)
    tab[6:8, :, :3] = ACCENT
    tab[6:8, :, 3] = 255
    save("tab_on", tab)
    # Marcador do item em foco: um colchete partido e uma meia-lua, em laranja.
    save("marker", with_shadow(sprite("""
        .aa.......
        aab.......
        aa....ab..
        aa....aaa.
        aa....aaab
        aa....aaaa
        a.....aaaa
        ......aaaa
        ......aaaa
        a.....aaaa
        aa....aaaa
        aa....aaab
        aa....aaa.
        aa....ab..
        aab.......
        .aa.......
    """, {"a": MARK, "b": MARK * 0.62})))
    # Setas de escolher da lista de fabricar.
    save("up_down", with_shadow(sprite("""
        ..a..
        .aaa.
        aaaaa
        .....
        .....
        .....
        .....
        .....
        aaaaa
        .aaa.
        ..a..
    """, {"a": LINE * 1.75})))
    # Painéis de rocha (a 3x, 240 linhas = 720 px): menu principal, pausa e o largo das
    # Configurações e das Dicas. A borda em texels, de cima para baixo.
    save("rock_menu", rock_panel(190, 240, [(0.0, 158), (0.3, 163), (0.45, 153), (0.55, 139),
                                            (0.68, 128), (0.78, 126), (0.88, 134), (1.0, 143)], 61))
    save("rock_pause", rock_panel(200, 240, [(0.0, 84), (0.1, 87), (0.22, 120), (0.33, 135),
                                             (0.45, 139), (0.55, 132), (0.66, 139), (0.76, 143),
                                             (0.87, 158), (1.0, 176)], 62))
    save("rock_wide", rock_panel(340, 240, [(0.0, 308), (0.25, 318), (0.5, 304), (0.75, 312),
                                            (1.0, 322)], 63))
    save("logo", logo())
    save("cave_icon", cave_icon())
    save("key_icon", key_icon())
    save("item_icons", item_icons())


def main():
    (OUT / "font").mkdir(parents=True, exist_ok=True)
    glyphs = parse_glyphs()
    write_font(glyphs, "toca", "Toca")
    write_font({c: bold(g) for c, g in glyphs.items()}, "toca_bold", "Toca Bold")
    write_font({c: italic(g) for c, g in glyphs.items()}, "toca_italic", "Toca Italic")
    textures()
    print(f"{len(glyphs)} letras; texturas em {OUT}")


if __name__ == "__main__":
    main()
