"""Bichos do vale no acabamento do goblin: corpo contínuo, detalhes e esqueleto com joelhos.

Executar no Blender, da raiz do projeto:
    blender --background --python assets/models/animals/source/build_animals.py -- [especie ...] [--preview=pasta]

Cada espécie vira assets/models/animals/<especie>.glb. As medidas das especificações estão no
espaço do Godot (x = lado esquerdo do bicho, y = cima, z = frente, metros); o script converte
para o Blender (x, -z, y) e o glTF volta com Y para cima.

Como o goblin (polish_goblin.py):
- o corpo é uma união de formas (lofts do tronco, tubos dos membros, bolhas da cabeça e dos
  músculos), fundida por remesh de voxel, suavizada (os encontros viram curvas, não vincos),
  com calombos lentos e reduzida (decimate);
- detalhes finos (orelhas, olhos, focinho, cascos, galhada, presas, bico) são peças à parte,
  presas a um osso só;
- cada face recebe a região do pelo (`bicho.pelo`, `bicho.claro`...) por uma função da posição;
- os pesos vêm da distância de cada vértice ao osso, medida em "raios de carne" do osso: o
  tronco puxa a pele larga e as pernas só a delas, e as juntas misturam suave.
O Godot (CreatureModel) cria um pivô por osso e leva a pele junto com os pivôs.
"""
from pathlib import Path
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

SOURCE = Path(__file__).resolve().parent
ASSET = SOURCE.parent

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = next((a.split("=", 1)[1] for a in ARGS if a.startswith("--preview=")), "")
WANTED = [a for a in ARGS if not a.startswith("--")]

# Cores só para os renders de conferência (no jogo o AnimalLook dá textura e tinta).
PREVIEW_COLORS = {
    "pelo": (0.42, 0.29, 0.18), "pelo_escuro": (0.26, 0.18, 0.11), "claro": (0.82, 0.76, 0.66),
    "nariz": (0.06, 0.05, 0.05), "casco": (0.1, 0.08, 0.07), "olho": (0.02, 0.02, 0.02),
    "interno": (0.55, 0.42, 0.38), "chifre": (0.72, 0.64, 0.5), "presa": (0.86, 0.82, 0.7),
    "crina": (0.12, 0.1, 0.08), "garra": (0.12, 0.11, 0.1), "focinho": (0.35, 0.25, 0.24),
    "bico": (0.14, 0.13, 0.12), "pena": (0.12, 0.12, 0.14), "pena_clara": (0.6, 0.55, 0.45),
    "detalhe": (0.62, 0.12, 0.08), "olho_brilho": (0.9, 0.7, 0.25),
}


def B(p) -> Vector:
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def G(v) -> Vector:
    """Blender -> Godot."""
    return Vector((v[0], v[2], -v[1]))


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


# --- Formas (em bmesh, coordenadas do Godot) ---------------------------------------------

def _frame(tangent: Vector):
    up = Vector((0.0, 1.0, 0.0))
    side = tangent.cross(up)
    if side.length < 0.05:
        side = tangent.cross(Vector((0.0, 0.0, 1.0)))
    side.normalize()
    lift = side.cross(tangent).normalized()
    return side, lift


def _frames(pts):
    """Um referencial (lado, cima) por ponto do caminho, cada um levado do anterior (transporte
    paralelo). Com _frame em cada ponto, uma perna quase vertical que muda de inclinação virava o
    anel de lado e o tubo saía torcido, com uma cintura de ampulheta na junta."""
    frames = []
    for j in range(len(pts)):
        tangent = (pts[min(j + 1, len(pts) - 1)] - pts[max(j - 1, 0)]).normalized()
        side = None
        if frames:
            prev = frames[-1][0]
            side = prev - tangent * prev.dot(tangent)
            side = side.normalized() if side.length > 1e-6 else None
        if side is None:
            side, lift = _frame(tangent)
        else:
            lift = side.cross(tangent).normalized()
        frames.append((side, lift))
    return frames


def ellipsoid(bm, center, radii, rotation=None, segments=18, rings=12, shape=None):
    """Elipsoide; `rotation` é uma Matrix 3x3 no espaço do Godot; `shape(n) -> fator` deforma."""
    c = Vector(center)
    rot = rotation or Matrix.Identity(3)
    verts = []
    for j in range(rings + 1):
        a = -math.pi / 2 + math.pi * j / rings
        row = []
        for i in range(segments if 0 < j < rings else 1):
            t = 2 * math.pi * i / segments
            n = Vector((math.cos(a) * math.cos(t), math.sin(a), math.cos(a) * math.sin(t)))
            k = shape(n) if shape else 1.0
            local = Vector((n.x * radii[0], n.y * radii[1], n.z * radii[2])) * k
            row.append(bm.verts.new(B(c + rot @ local)))
        verts.append(row)
    for j in range(rings):
        lower, upper = verts[j], verts[j + 1]
        for i in range(segments):
            if len(lower) == 1:
                bm.faces.new((lower[0], upper[(i + 1) % segments], upper[i]))
            elif len(upper) == 1:
                bm.faces.new((lower[i], lower[(i + 1) % segments], upper[0]))
            else:
                bm.faces.new((lower[i], lower[(i + 1) % segments], upper[(i + 1) % segments], upper[i]))


def tube(bm, points, radii, sides=14, caps=True):
    """Tubo por `points`; cada raio é r ou (r_lado, r_cima). Pontas arredondadas por elipsoides."""
    pts = [Vector(p) for p in points]
    rs = [(r, r) if isinstance(r, (int, float)) else r for r in radii]
    rings = []
    frames = _frames(pts)
    for j, p in enumerate(pts):
        side, lift = frames[j]
        ring = []
        for i in range(sides):
            t = 2 * math.pi * i / sides
            ring.append(bm.verts.new(B(p + side * math.cos(t) * rs[j][0] + lift * math.sin(t) * rs[j][1])))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for i in range(sides):
            a, b = rings[j], rings[j + 1]
            bm.faces.new((a[i], a[(i + 1) % sides], b[(i + 1) % sides], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    if caps:
        for j in (0, len(pts) - 1):
            r = max(rs[j])
            ellipsoid(bm, pts[j], (rs[j][0], rs[j][1], r), _look(pts[min(j + 1, len(pts) - 1)] - pts[max(j - 1, 0)]), 12, 8)


def horn(bm, points, radii, sides=8):
    """Tubo que fecha em ponta (presas, pontas de galhada, garras, bico)."""
    pts = [Vector(p) for p in points]
    rings = []
    frames = _frames(pts)
    for j, p in enumerate(pts):
        side, lift = frames[j]
        r = radii[j]
        rx, ry = (r, r) if isinstance(r, (int, float)) else r
        rings.append([bm.verts.new(B(p + side * math.cos(2 * math.pi * i / sides) * rx + lift * math.sin(2 * math.pi * i / sides) * ry)) for i in range(sides)])
    for j in range(len(rings) - 1):
        a, b = rings[j], rings[j + 1]
        for i in range(sides):
            bm.faces.new((a[i], a[(i + 1) % sides], b[(i + 1) % sides], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    tip_dir = (pts[-1] - pts[-2]).normalized()
    tip = bm.verts.new(B(pts[-1] + tip_dir * max(radii[-1] if isinstance(radii[-1], (int, float)) else max(radii[-1]), 0.002) * 1.5))
    for i in range(sides):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % sides], tip))


def loft(bm, sections, sides=24):
    """Tronco: seções (z, y_centro, r_lado, r_cima, r_baixo[, x]) ao longo de z (de trás para a frente)."""
    rings = []
    for sec in sections:
        z, yc, rx, ryt, ryb = sec[:5]
        x = sec[5] if len(sec) > 5 else 0.0
        ring = []
        for i in range(sides):
            t = 2 * math.pi * i / sides
            s = math.sin(t)
            # Superelipse leve: costas e barriga mais cheias que uma elipse.
            cx = math.copysign(abs(math.cos(t)) ** 0.85, math.cos(t))
            sy = math.copysign(abs(s) ** 0.85, s)
            ring.append(bm.verts.new(B((x + rx * cx, yc + (ryt if s > 0 else ryb) * sy, z))))
        rings.append(ring)
    for j in range(len(rings) - 1):
        a, b = rings[j], rings[j + 1]
        for i in range(sides):
            bm.faces.new((a[i], b[i], b[(i + 1) % sides], a[(i + 1) % sides]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))


def _look(direction) -> Matrix:
    """Rotação (Godot) que leva o eixo z local para `direction`."""
    d = Vector(direction).normalized()
    side, lift = _frame(d)
    return Matrix((side, lift, d)).transposed()


def rot_xyz(x=0.0, y=0.0, z=0.0) -> Matrix:
    return (Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(z, 3, "Z"))


# --- Objetos ---------------------------------------------------------------------------

def material(key):
    name = "bicho." + key
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        color = PREVIEW_COLORS.get(key, (0.5, 0.5, 0.5))
        mat.diffuse_color = (*color, 1.0)
        mat.use_nodes = True
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (*color, 1.0)
            bsdf.inputs["Roughness"].default_value = 0.4 if key in ("olho", "nariz", "olho_brilho") else 0.9
    return mat


def to_object(bm, name):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    data = bpy.data.meshes.new(name)
    bm.to_mesh(data)
    bm.free()
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def activate(ob):
    for other in bpy.context.selected_objects:
        other.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def apply_modifier(ob, kind, **settings):
    mod = ob.modifiers.new(kind, kind)
    for key, value in settings.items():
        setattr(mod, key, value)
    activate(ob)
    bpy.ops.object.modifier_apply(modifier=mod.name)


class Creature:
    """Uma espécie: ossos, formas do corpo, detalhes, regiões e pesos."""

    def __init__(self, name, voxel, target_faces, bumps):
        self.name = name
        self.voxel = voxel
        self.target_faces = target_faces
        self.bumps = bumps
        self.bones = []          # (nome, pai, cabeça, cauda, raio de carne)
        self.body = bmesh.new()
        self.details = []        # (bmesh, material, osso)

    def bone(self, name, parent, head, tail, flesh):
        self.bones.append((name, parent, Vector(head), Vector(tail), flesh))

    def detail(self, mat, bone):
        bm = bmesh.new()
        self.details.append((bm, mat, bone))
        return bm

    # Região de cada face do corpo (por posição e normal no Godot).
    def paint(self, p: Vector, n: Vector) -> str:
        return "pelo"

    # Ossos que podem puxar o vértice (os de um lado não puxam o outro lado).
    def allowed(self, bone_name: str, p: Vector) -> bool:
        if bone_name.endswith("_E"):
            return p.x > -0.004
        if bone_name.endswith("_D"):
            return p.x < 0.004
        return True

    def build(self):
        body = to_object(self.body, self.name + ".corpo")
        apply_modifier(body, "REMESH", mode="VOXEL", voxel_size=self.voxel, use_smooth_shade=True)
        # Os encontros das formas viram curvas (como músculo sob a pele), não vincos.
        apply_modifier(body, "SMOOTH", factor=0.6, iterations=4)
        # Calombos lentos (nada é liso) e um grão fino.
        size = self.bumps
        body.data.calc_normals_split() if hasattr(body.data, "calc_normals_split") else None
        for v in body.data.vertices:
            p = v.co
            amount = noise.noise(p * (6.0 / size)) * 0.5 + noise.noise(p * (17.0 / size) + Vector((3, 1, 7))) * 0.18
            v.co = p + v.normal * amount * size * 0.018
        faces = len(body.data.polygons)
        if faces > self.target_faces:
            apply_modifier(body, "DECIMATE", decimate_type="COLLAPSE", ratio=self.target_faces / faces)
        keys = []
        for poly in body.data.polygons:
            key = self.paint(G(poly.center), G(poly.normal).normalized())
            if key not in keys:
                keys.append(key)
                body.data.materials.append(material(key))
            poly.material_index = keys.index(key)
            poly.use_smooth = True
        self._weigh(body)
        parts = [body]
        for i, (bm, mat, bone) in enumerate(self.details):
            ob = to_object(bm, f"{self.name}.detalhe{i}")
            ob.data.materials.append(material(mat))
            for poly in ob.data.polygons:
                poly.use_smooth = mat not in ("casco", "chifre", "presa", "garra", "bico")
            group = ob.vertex_groups.new(name=bone)
            group.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
            parts.append(ob)
        activate(body)
        for ob in parts:
            ob.select_set(True)
        bpy.ops.object.join()
        body.name = self.name
        rig = self._rig()
        body.parent = rig
        mod = body.modifiers.new("Pele", "ARMATURE")
        mod.object = rig
        return body, rig

    def _weigh(self, ob):
        segments = [(name, B(h), B(t), flesh) for name, _parent, h, t, flesh in self.bones]
        groups = {name: ob.vertex_groups.new(name=name) for name, *_ in self.bones}
        # Cadeia das pernas: osso -> (cabeça, cauda, pai, filho na mesma perna).
        chain = {}
        for name, parent, h, t, _flesh in self.bones:
            if is_leg(name):
                child = next((n for n, pa, *_ in self.bones if pa == name and is_leg(n)), None)
                chain[name] = (B(h), B(t), parent, child)
        for v in ob.data.vertices:
            p = v.co
            gp = G(p)
            scores = []
            for name, a, b, flesh in segments:
                if not self.allowed(name, gp):
                    continue
                ab = b - a
                t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
                d = (p - (a + ab * t)).length / flesh
                scores.append((d, name))
            scores.sort()
            best = scores[0][0]
            picked = self._joint_blend(scores[0][1], p, chain)
            if picked is None:
                picked = [(math.exp(-((d - best) / 0.35) ** 2), name) for d, name in scores[:4]]
            total = sum(w for w, _ in picked)
            for w, name in picked:
                if w / total > 0.02:
                    groups[name].add([v.index], w / total, "REPLACE")

    @staticmethod
    def _joint_blend(best, p, chain):
        """Na perna, a pele é do osso mais perto e só se mistura com o vizinho perto da junta (pelo
        comprimento ao longo do osso). Pelos raios de carne, a coxa grossa puxava a canela fina por
        um palmo abaixo do joelho, e a perna torcia e afinava ao dobrar."""
        if best not in chain:
            return None
        a, b, parent, child = chain[best]
        ab = b - a
        length = ab.length
        along = (p - a).dot(ab) / max(length, 1e-9)
        # Meia largura da mistura: estreita nas juntas da perna, mais larga no quadril e no ombro.
        zone = min(0.035, 0.2 * length) if parent in chain else min(0.07, 0.3 * length)
        weights = {best: 1.0}
        if parent is not None and along < zone:
            own = smooth01((along + zone) / (2 * zone))
            weights = {best: own, parent: 1.0 - own}
        elif child is not None and length - along < zone:
            own = smooth01((length - along + zone) / (2 * zone))
            weights = {best: own, child: 1.0 - own}
        return [(w, name) for name, w in weights.items() if w > 0.0]

    def _rig(self):
        data = bpy.data.armatures.new(self.name + "_rig")
        rig = bpy.data.objects.new(self.name + "_rig", data)
        bpy.context.scene.collection.objects.link(rig)
        activate(rig)
        bpy.ops.object.mode_set(mode="EDIT")
        for name, parent, head, tail, _flesh in self.bones:
            bone = data.edit_bones.new(name)
            bone.head = B(head)
            bone.tail = B(tail)
            bone.roll = 0.0
            if parent:
                bone.parent = data.edit_bones[parent]
                bone.use_connect = False
        bpy.ops.object.mode_set(mode="OBJECT")
        return rig


# --- Pernas de quadrúpede ------------------------------------------------------------------

def is_leg(name):
    return any(part in name for part in ("_coxa_", "_canela_", "_pata_"))


def smooth01(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


def leg_bones(c, prefix, side, parent, joints, flesh):
    """Três ossos por perna: coxa (até o joelho), canela (até o jarrete/carpo), pata (até o chão)."""
    s = "E" if side > 0 else "D"
    names = [f"{prefix}_coxa_{s}", f"{prefix}_canela_{s}", f"{prefix}_pata_{s}"]
    for i in range(3):
        head = joints[i]
        tail = joints[i + 1]
        c.bone(names[i], parent if i == 0 else names[i - 1], head, tail, flesh[i])


def mirror(p, side):
    return (p[0] * side, p[1], p[2])


# --- Cervo ---------------------------------------------------------------------------------

class Deer(Creature):
    # Cabeça: centro do crânio. Tudo da cabeça (orelhas, olhos, focinho, galhada) parte daqui.
    HEAD = Vector((0.0, 1.47, 0.68))

    def __init__(self, name="deer", old=False):
        super().__init__(name, voxel=0.01, target_faces=9000, bumps=1.0)
        self.old = old
        neck = 1.18 if old else 1.0
        bm = self.body
        H = self.HEAD

        def h(x, y, z):
            return tuple(H + Vector((x, y, z)))

        # Tronco: peito fundo (o esterno desce até o cotovelo, ~0,66 m: o peito é quase metade da
        # altura da cernelha; mais raso, a perna parecia comprida demais e o bicho, um camelo),
        # flanco recolhido na frente da anca, garupa redonda.
        # A garupa fecha aos poucos (um salto de raio no fim virava um prato chato atrás).
        loft(bm, [
            (-0.65, 1.0, 0.035, 0.035, 0.04),
            (-0.625, 1.01, 0.08, 0.075, 0.09),
            (-0.59, 1.015, 0.11, 0.1, 0.125),
            (-0.55, 1.02, 0.13, 0.115, 0.15),
            (-0.47, 1.0, 0.155, 0.13, 0.22),
            (-0.33, 0.99, 0.15, 0.12, 0.22),
            (-0.18, 0.99, 0.16, 0.12, 0.26),
            (0.0, 1.0, 0.175, 0.13, 0.3),
            (0.18, 1.01, 0.175, 0.14, 0.34),
            (0.32, 1.03, 0.16, 0.13, 0.37),
            (0.43, 1.07, 0.125, 0.11, 0.31),
            (0.5, 1.13, 0.08, 0.08, 0.16),
        ])
        # Cernelha, escápulas, costelas e ancas: o relevo dos ossos e músculos sob o pelo.
        ellipsoid(bm, (0, 1.14, 0.27), (0.06, 0.06, 0.16))
        ellipsoid(bm, (0, 1.06, -0.44), (0.085, 0.06, 0.12))
        for s in (1, -1):
            ellipsoid(bm, (0.105 * s, 1.03, 0.31), (0.05, 0.16, 0.1), rot_xyz(x=0.35))
            ellipsoid(bm, (0.1 * s, 0.94, -0.39), (0.08, 0.17, 0.15), rot_xyz(x=-0.2))
            ellipsoid(bm, (0.12 * s, 0.97, 0.08), (0.05, 0.14, 0.2))
        # Pescoço: curto, mais fundo que largo, grosso embaixo (no Velho, com juba).
        # A base nasce funda no peito (o pescoço fino e alto lia como camelo pastando).
        tube(bm, [(0, 1.0, 0.4), (0, 1.18, 0.52), h(0, -0.1, -0.06), h(0, -0.02, -0.03)],
             [(0.1 * neck, 0.17 * neck), (0.078 * neck, 0.12 * neck), (0.058 * neck, 0.08 * neck), (0.052, 0.062)], 16)
        if old:
            ellipsoid(bm, (0, 1.2, 0.54), (0.08, 0.13, 0.1), rot_xyz(x=-0.6),
                      shape=lambda n: 1.0 + 0.12 * noise.noise(n * 4.0))
        # Cabeça: crânio, testa, bochechas e focinho afinando.
        ellipsoid(bm, h(0, 0.005, 0.0), (0.062, 0.066, 0.08), shape=lambda n: 1.0 - 0.08 * max(0.0, n.y) ** 2)
        tube(bm, [h(0, -0.005, 0.045), h(0, -0.035, 0.13), h(0, -0.065, 0.205), h(0, -0.078, 0.237)],
             [(0.047, 0.052), (0.04, 0.046), (0.032, 0.038), (0.028, 0.032)], 14)
        for s in (1, -1):
            ellipsoid(bm, h(0.033 * s, -0.04, 0.06), (0.032, 0.04, 0.06))
            ellipsoid(bm, h(0.044 * s, 0.025, 0.04), (0.022, 0.018, 0.03))  # arco das sobrancelhas
        # Pernas: dianteiras retas, traseiras com o joelho para a frente e o jarrete para trás.
        for s in (1, -1):
            f = [mirror(p, s) for p in self.FRONT]
            tube(bm, [f[0], f[1]], [0.078, 0.058])
            ellipsoid(bm, (0.1 * s, 0.8, 0.39), (0.058, 0.12, 0.075))  # músculo do braço
            # Raios com folga: a suavização da malha come uns milímetros das partes finas.
            tube(bm, [f[1], (0.1 * s, 0.52, 0.41), f[2]], [0.056, 0.046, 0.037])
            ellipsoid(bm, f[2], (0.039, 0.041, 0.041))  # "joelho" (carpo)
            tube(bm, [f[2], f[3]], [0.032, 0.03])
            ellipsoid(bm, f[3], (0.035, 0.037, 0.037))  # boleto
            tube(bm, [f[3], f[4]], [0.03, 0.028], caps=False)
            k = [mirror(p, s) for p in self.HIND]
            tube(bm, [k[0], k[1]], [0.09, 0.066])
            tube(bm, [k[1], (0.105 * s, 0.56, -0.38), k[2]], [0.064, 0.05, 0.036])
            ellipsoid(bm, (0.105 * s, 0.6, -0.355), (0.05, 0.085, 0.064), rot_xyz(x=0.6))  # panturrilha
            ellipsoid(bm, k[2], (0.035, 0.04, 0.045))  # ponta do jarrete
            tube(bm, [k[2], k[3]], [0.032, 0.03])
            ellipsoid(bm, k[3], (0.035, 0.037, 0.037))
            tube(bm, [k[3], k[4]], [0.03, 0.028], caps=False)
        # Rabo curto e chato.
        tube(bm, [(0, 1.07, -0.6), (0, 1.03, -0.67), (0, 0.97, -0.71)], [(0.036, 0.022), (0.034, 0.02), (0.024, 0.015)])

        # Detalhes.
        flat_bottom = lambda n: 1.0 - 0.35 * max(0.0, -n.y) ** 2 - 0.15 * max(0.0, n.y)
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            for prefix, leg in (("d", self.FRONT), ("t", self.HIND)):
                hoof = self.detail("casco", f"{prefix}_pata_{n}")
                x, z = leg[4][0] * s, leg[4][2]
                for toe in (1, -1):
                    ellipsoid(hoof, (x + 0.015 * toe, 0.03, z + 0.01), (0.019, 0.036, 0.045), rot_xyz(x=-0.25), 10, 8, shape=flat_bottom)
                for toe in (1, -1):
                    ellipsoid(hoof, (x + 0.014 * toe, 0.11, z - 0.04), (0.007, 0.011, 0.009), None, 8, 6)  # esporões
            ear = self.detail("pelo", f"orelha_{n}")
            ellipsoid(ear, h(0.085 * s, 0.1, -0.03), (0.013, 0.085, 0.042), rot_xyz(x=-0.15, z=-0.8 * s), 14, 10,
                      shape=lambda n: (1.0 - 0.5 * max(0.0, -n.y)) * (0.55 if n.z > 0 else 1.0))
            inner = self.detail("interno", f"orelha_{n}")
            ellipsoid(inner, h(0.087 * s, 0.1, -0.022), (0.006, 0.07, 0.031), rot_xyz(x=-0.15, z=-0.8 * s), 12, 8)
            eye = self.detail("olho", "cabeca")
            ellipsoid(eye, h(0.05 * s, 0.012, 0.05), (0.012, 0.013, 0.014), rot_xyz(y=0.6 * s), 12, 8)
            nostril = self.detail("nariz", "cabeca")
            ellipsoid(nostril, h(0.014 * s, -0.072, 0.243), (0.009, 0.011, 0.006), rot_xyz(y=0.4 * s), 8, 6)
        nose = self.detail("nariz", "cabeca")
        ellipsoid(nose, h(0, -0.072, 0.238), (0.028, 0.026, 0.012), None, 12, 8)
        if old:
            self._antlers()

        self.bone("corpo", None, (0, 1.0, 0.0), (0, 1.0, 0.25), 0.2)
        self.bone("peito", "corpo", (0, 1.02, 0.18), (0, 1.05, 0.42), 0.2)
        self.bone("pescoco", "peito", (0, 1.1, 0.45), h(0, -0.06, -0.05), 0.09)
        self.bone("cabeca", "pescoco", h(0, -0.02, -0.03), h(0, -0.04, 0.22), 0.07)
        self.bone("cauda", "corpo", (0, 1.06, -0.6), (0, 0.97, -0.71), 0.035)
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            self.bone(f"orelha_{n}", "cabeca", h(0.05 * s, 0.05, -0.02), h(0.13 * s, 0.15, -0.04), 0.04)
            f = [mirror(p, s) for p in self.FRONT]
            k = [mirror(p, s) for p in self.HIND]
            leg_bones(self, "d", s, "peito", [f[0], f[1], f[2], (f[4][0], 0.0, f[4][2])], [0.075, 0.045, 0.03])
            leg_bones(self, "t", s, "corpo", [k[0], k[1], k[2], (k[4][0], 0.0, k[4][2])], [0.095, 0.05, 0.03])

    # Juntas das pernas (lado esquerdo): ombro/quadril, cotovelo/joelho, carpo/jarrete, boleto, quartela.
    FRONT = [(0.1, 0.97, 0.35), (0.1, 0.69, 0.37), (0.1, 0.36, 0.39), (0.1, 0.13, 0.4), (0.1, 0.06, 0.42)]
    HIND = [(0.1, 0.96, -0.37), (0.11, 0.68, -0.28), (0.1, 0.43, -0.46), (0.1, 0.13, -0.41), (0.1, 0.06, -0.385)]

    def _antlers(self):
        """Galhada do Velho: duas hastes que abrem para trás e voltam para a frente, com pontas."""
        for s in (1, -1):
            bm = self.detail("chifre", "cabeca")
            base = self.HEAD + Vector((0.045 * s, 0.06, 0.02))
            beam = [base, base + Vector((0.05 * s, 0.12, -0.04)), base + Vector((0.13 * s, 0.25, -0.08)),
                    base + Vector((0.2 * s, 0.38, -0.05)), base + Vector((0.23 * s, 0.5, 0.03)), base + Vector((0.22 * s, 0.58, 0.1))]
            horn(bm, beam, [0.022, 0.019, 0.016, 0.013, 0.01, 0.007], 8)
            ellipsoid(bm, base + Vector((0, 0.012, 0)), (0.03, 0.018, 0.03), None, 10, 6)  # roseta
            for i, (at, direction, length) in enumerate([(1, (0.02 * s, 0.05, 0.12), 0.13), (2, (0.04 * s, 0.1, 0.09), 0.14),
                                                         (3, (-0.03 * s, 0.12, 0.06), 0.12), (4, (-0.06 * s, 0.1, 0.02), 0.1), (4, (0.05 * s, 0.11, 0.05), 0.09)]):
                start = beam[at]
                d = Vector(direction).normalized()
                bend = Vector((0, 0.03, 0))
                horn(bm, [start, start + d * length * 0.5 + bend * 0.5, start + d * length + bend], [0.011, 0.008, 0.005], 6)

    def paint(self, p, n):
        # Focinho escuro, lábios e queixo claros, anel claro em volta do olho, garganta e
        # barriga claras, espelho branco no traseiro e embaixo do rabo, pernas mais escuras.
        q = p - self.HEAD
        if q.z > 0.19 and q.y < 0.0:
            return "nariz" if q.z > 0.228 and abs(q.x) < 0.03 and q.y > -0.1 else "claro"
        if q.z > 0.0 and q.y < -0.055 and q.y > -0.12 and q.z < 0.2:
            return "claro"  # queixo e lábio de baixo
        if abs(q.x) > 0.035 and abs(q.y - 0.012) < 0.028 and abs(q.z - 0.05) < 0.032:
            return "claro"  # anel do olho
        if p.z > 0.5 and 1.22 < p.y < 1.42 and n.y < -0.2 and abs(p.x) < 0.06:
            return "claro"  # garganta
        if p.z < -0.55 and 0.84 < p.y < 1.04 and abs(p.x) < 0.075 and n.z < -0.3:
            return "claro"  # espelho do traseiro: só embaixo do rabo (o traseiro todo virava uma bola branca)
        if p.y > 0.62 and p.y < 0.86 and n.y < -0.6 and -0.36 < p.z < 0.36:
            return "claro"  # barriga
        if p.y < 0.4:
            return "pelo_escuro"
        if p.y > 1.1 and abs(p.x) < 0.05 and -0.5 < p.z < 0.42:
            return "pelo_escuro"  # faixa do lombo
        return "pelo"


# --- Coelho --------------------------------------------------------------------------------

class Rabbit(Creature):
    def __init__(self):
        super().__init__("rabbit", voxel=0.0045, target_faces=3000, bumps=0.3)
        bm = self.body
        ellipsoid(bm, (0, 0.14, -0.06), (0.085, 0.095, 0.11))
        ellipsoid(bm, (0, 0.14, 0.035), (0.068, 0.08, 0.09))
        ellipsoid(bm, (0, 0.125, 0.09), (0.052, 0.06, 0.05))
        ellipsoid(bm, (0, 0.205, 0.135), (0.044, 0.048, 0.058))
        for s in (1, -1):
            ellipsoid(bm, (0.026 * s, 0.19, 0.155), (0.028, 0.03, 0.038))
            ellipsoid(bm, (0.058 * s, 0.11, -0.07), (0.035, 0.058, 0.068), rot_xyz(x=-0.3))
            tube(bm, [(0.06 * s, 0.1, -0.06), (0.062 * s, 0.05, -0.09), (0.062 * s, 0.03, -0.1)], [0.03, 0.022, 0.017])
            tube(bm, [(0.062 * s, 0.03, -0.1), (0.064 * s, 0.018, -0.03), (0.066 * s, 0.014, 0.025)], [(0.019, 0.015), (0.016, 0.012), (0.014, 0.01)])
            tube(bm, [(0.03 * s, 0.1, 0.09), (0.031 * s, 0.05, 0.1), (0.032 * s, 0.014, 0.112)], [0.014, 0.011, 0.01])
        tube(bm, [(0, 0.2, 0.17), (0, 0.19, 0.188)], [(0.022, 0.02), (0.016, 0.014)], 10)
        tail = self.detail("claro", "cauda")
        ellipsoid(tail, (0, 0.16, -0.175), (0.026, 0.026, 0.022), None, 12, 8, shape=lambda n: 1.0 + 0.1 * noise.noise(n * 5.0))
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            ear = self.detail("pelo", f"orelha_{n}")
            ellipsoid(ear, (0.028 * s, 0.295, 0.11), (0.009, 0.065, 0.02), rot_xyz(x=0.35, z=-0.18 * s), 12, 10,
                      shape=lambda n: (1.0 - 0.35 * max(0.0, -n.y)) * (0.55 if n.z > 0 else 1.0))
            inner = self.detail("interno", f"orelha_{n}")
            ellipsoid(inner, (0.029 * s, 0.295, 0.113), (0.004, 0.055, 0.014), rot_xyz(x=0.35, z=-0.18 * s), 10, 8)
            eye = self.detail("olho", "cabeca")
            ellipsoid(eye, (0.036 * s, 0.218, 0.152), (0.011, 0.013, 0.012), rot_xyz(y=0.9 * s), 10, 8)
        nose = self.detail("focinho", "cabeca")
        ellipsoid(nose, (0, 0.196, 0.197), (0.009, 0.007, 0.004), None, 8, 6)
        self.bone("corpo", None, (0, 0.13, 0.0), (0, 0.13, 0.1), 0.09)
        self.bone("cabeca", "corpo", (0, 0.19, 0.1), (0, 0.2, 0.2), 0.05)
        self.bone("cauda", "corpo", (0, 0.15, -0.15), (0, 0.16, -0.19), 0.02)
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            self.bone(f"orelha_{n}", "cabeca", (0.026 * s, 0.245, 0.115), (0.034 * s, 0.37, 0.09), 0.015)
            self.bone(f"t_coxa_{n}", "corpo", (0.058 * s, 0.13, -0.06), (0.062 * s, 0.035, -0.1), 0.045)
            self.bone(f"t_pata_{n}", f"t_coxa_{n}", (0.062 * s, 0.035, -0.1), (0.066 * s, 0.012, 0.03), 0.016)
            self.bone(f"d_coxa_{n}", "corpo", (0.03 * s, 0.1, 0.09), (0.032 * s, 0.01, 0.112), 0.014)

    def paint(self, p, n):
        if p.y < 0.1 and n.y < -0.3:
            return "claro"
        if p.z > 0.17 and p.y < 0.195:
            return "claro"
        if p.y < 0.13 and p.z > 0.06 and n.y < 0.0:
            return "claro"
        if p.y > 0.2 and abs(p.x) < 0.03 and p.z < 0.14:
            return "pelo_escuro"
        return "pelo"


# --- Javali --------------------------------------------------------------------------------

class Boar(Creature):
    def __init__(self):
        super().__init__("boar", voxel=0.01, target_faces=6000, bumps=0.8)
        bm = self.body
        loft(bm, [
            (-0.52, 0.53, 0.06, 0.06, 0.06),
            (-0.46, 0.53, 0.15, 0.15, 0.15),
            (-0.32, 0.52, 0.19, 0.18, 0.2),
            (-0.08, 0.52, 0.21, 0.2, 0.22),
            (0.16, 0.55, 0.22, 0.25, 0.22),
            (0.32, 0.56, 0.2, 0.27, 0.2),
            (0.44, 0.56, 0.16, 0.22, 0.17),
            (0.5, 0.56, 0.1, 0.13, 0.1),
        ])
        ellipsoid(bm, (0, 0.78, 0.22), (0.08, 0.08, 0.3))  # corcova das cerdas
        for s in (1, -1):
            ellipsoid(bm, (0.11 * s, 0.6, 0.3), (0.08, 0.16, 0.13), rot_xyz(x=0.3))
            ellipsoid(bm, (0.11 * s, 0.5, -0.33), (0.09, 0.16, 0.14), rot_xyz(x=-0.2))
        # Cabeça em cunha até o disco do focinho.
        tube(bm, [(0, 0.6, 0.42), (0, 0.53, 0.58), (0, 0.46, 0.72), (0, 0.42, 0.8)],
             [(0.15, 0.17), (0.115, 0.125), (0.075, 0.08), (0.055, 0.058)], 16)
        for s in (1, -1):
            ellipsoid(bm, (0.08 * s, 0.47, 0.55), (0.065, 0.075, 0.1))  # papadas
            ellipsoid(bm, (0.06 * s, 0.6, 0.6), (0.03, 0.025, 0.04))   # sobrancelha
            f = [mirror(p, s) for p in [(0.12, 0.5, 0.32), (0.13, 0.27, 0.34), (0.13, 0.1, 0.35), (0.13, 0.04, 0.37)]]
            tube(bm, [f[0], f[1]], [0.088, 0.058])
            tube(bm, [f[1], f[2]], [0.045, 0.038])
            ellipsoid(bm, f[2], (0.042, 0.04, 0.042))
            tube(bm, [f[2], f[3]], [0.037, 0.034], caps=False)
            h = [mirror(p, s) for p in [(0.11, 0.5, -0.33), (0.13, 0.3, -0.28), (0.12, 0.19, -0.38), (0.12, 0.09, -0.37), (0.12, 0.04, -0.35)]]
            tube(bm, [h[0], h[1]], [0.095, 0.065])
            tube(bm, [h[1], h[2]], [0.058, 0.042])
            tube(bm, [h[2], h[3]], [0.038, 0.035])
            ellipsoid(bm, h[3], (0.04, 0.04, 0.04))
            tube(bm, [h[3], h[4]], [0.035, 0.033], caps=False)
        tube(bm, [(0, 0.63, -0.5), (0, 0.56, -0.55), (0, 0.48, -0.57)], [0.016, 0.012, 0.01], 8)

        disc = self.detail("focinho", "cabeca")
        tube(disc, [(0, 0.42, 0.8), (0, 0.415, 0.83)], [(0.058, 0.05), (0.056, 0.048)], 16, caps=False)
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            nostril = self.detail("nariz", "cabeca")
            ellipsoid(nostril, (0.02 * s, 0.415, 0.834), (0.011, 0.013, 0.004), None, 8, 6)
            tusk = self.detail("presa", "cabeca")
            horn(tusk, [(0.045 * s, 0.42, 0.72), (0.06 * s, 0.445, 0.74), (0.072 * s, 0.475, 0.735), (0.075 * s, 0.5, 0.715)],
                 [0.011, 0.009, 0.006, 0.003], 6)
            ear = self.detail("pelo", f"orelha_{n}")
            ellipsoid(ear, (0.085 * s, 0.73, 0.47), (0.014, 0.06, 0.035), rot_xyz(x=-0.5, z=-0.5 * s), 12, 8,
                      shape=lambda n: (1.0 - 0.6 * max(0.0, n.y)) if n.y > 0 else 1.0)
            eye = self.detail("olho", "cabeca")
            ellipsoid(eye, (0.072 * s, 0.585, 0.615), (0.011, 0.011, 0.011), None, 8, 6)
            for name, z in (("d", 0.37), ("t", -0.35)):
                hoof = self.detail("casco", f"{name}_pata_{n}")
                for toe in (1, -1):
                    ellipsoid(hoof, (0.13 * s + 0.014 * toe if name == "d" else 0.12 * s + 0.014 * toe, 0.025, z + 0.01),
                              (0.019, 0.03, 0.034), rot_xyz(x=-0.3), 10, 8)
        tuft = self.detail("crina", "cauda")
        ellipsoid(tuft, (0, 0.47, -0.575), (0.018, 0.035, 0.018), None, 8, 6, shape=lambda n: 1.0 + 0.3 * noise.noise(n * 6.0))
        # Crina de cerdas no lombo: tufos em pé, do pescoço ao meio das costas.
        mane = self.detail("crina", "corpo")
        rng = __import__("random").Random(7)
        for i in range(70):
            z = rng.uniform(-0.25, 0.48)
            x = rng.gauss(0.0, 0.025)
            # Em cima do lombo: mais alta na corcova, baixando para a garupa e para a nuca.
            top = 0.78 + 0.075 * math.exp(-((z - 0.2) / 0.22) ** 2)
            length = rng.uniform(0.025, 0.06) * (0.6 + 0.6 * math.exp(-((z - 0.2) / 0.25) ** 2))
            lean = Vector((x * 1.5 + rng.uniform(-0.01, 0.01), 1.0, rng.uniform(-0.7, -0.2))).normalized()
            base = Vector((x, top - 0.02, z))
            horn(mane, [base, base + lean * length * 0.55 + Vector((rng.uniform(-0.006, 0.006), 0, 0)), base + lean * length],
                 [0.011, 0.007, 0.003], 5)

        self.bone("corpo", None, (0, 0.52, 0.0), (0, 0.52, 0.3), 0.22)
        self.bone("cabeca", "corpo", (0, 0.58, 0.4), (0, 0.44, 0.8), 0.11)
        self.bone("cauda", "corpo", (0, 0.63, -0.5), (0, 0.47, -0.58), 0.02)
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            self.bone(f"orelha_{n}", "cabeca", (0.07 * s, 0.68, 0.48), (0.1 * s, 0.79, 0.45), 0.03)
            leg_bones(self, "d", s, "corpo", [mirror(p, s) for p in [(0.12, 0.5, 0.32), (0.13, 0.27, 0.34), (0.13, 0.1, 0.35), (0.13, 0.0, 0.37)]], [0.07, 0.035, 0.03])
            leg_bones(self, "t", s, "corpo", [mirror(p, s) for p in [(0.11, 0.5, -0.33), (0.13, 0.3, -0.28), (0.12, 0.19, -0.38), (0.12, 0.0, -0.35)]], [0.08, 0.04, 0.03])

    def paint(self, p, n):
        if p.y < 0.2:
            return "pelo_escuro"
        if p.z > 0.6 and p.y < 0.5 and n.y < -0.3:
            return "pelo_escuro"
        if p.y > 0.76 and abs(p.x) < 0.07 and -0.3 < p.z < 0.5:
            return "crina"
        return "pelo"


# --- Lobo ----------------------------------------------------------------------------------

class Wolf(Creature):
    def __init__(self):
        super().__init__("wolf", voxel=0.009, target_faces=6500, bumps=0.7)
        bm = self.body
        loft(bm, [
            (-0.49, 0.6, 0.05, 0.05, 0.05),
            (-0.44, 0.59, 0.1, 0.1, 0.1),
            (-0.32, 0.58, 0.11, 0.11, 0.1),
            (-0.14, 0.58, 0.115, 0.12, 0.11),
            (0.06, 0.58, 0.14, 0.14, 0.18),
            (0.24, 0.59, 0.15, 0.15, 0.22),
            (0.38, 0.61, 0.135, 0.14, 0.19),
            (0.47, 0.64, 0.07, 0.08, 0.1),
        ])
        fluffy = lambda n: 1.0 + 0.09 * noise.noise(n * 5.0) + 0.05 * noise.noise(n * 11.0)
        ellipsoid(bm, (0, 0.635, 0.43), (0.145, 0.135, 0.14), shape=fluffy)  # colar de pelo
        for s in (1, -1):
            ellipsoid(bm, (0.075 * s, 0.62, 0.32), (0.045, 0.12, 0.08), rot_xyz(x=0.3))
            ellipsoid(bm, (0.075 * s, 0.53, -0.33), (0.06, 0.12, 0.11), rot_xyz(x=-0.25))
        tube(bm, [(0, 0.64, 0.42), (0, 0.73, 0.55), (0, 0.78, 0.62)], [(0.095, 0.1), (0.075, 0.08), (0.068, 0.072)], 14)
        ellipsoid(bm, (0, 0.805, 0.66), (0.095, 0.082, 0.09), shape=lambda n: 1.0 - 0.1 * max(0.0, n.y) ** 2)
        tube(bm, [(0, 0.79, 0.7), (0, 0.77, 0.78), (0, 0.752, 0.845), (0, 0.746, 0.862)], [(0.066, 0.06), (0.052, 0.049), (0.038, 0.036), (0.032, 0.03)], 12)
        for s in (1, -1):
            ellipsoid(bm, (0.06 * s, 0.775, 0.64), (0.05, 0.058, 0.06), shape=fluffy)  # bochechas peludas
            ellipsoid(bm, (0.04 * s, 0.83, 0.68), (0.025, 0.018, 0.03))  # sobrancelha
            f = [mirror(p, s) for p in [(0.08, 0.62, 0.32), (0.085, 0.43, 0.27), (0.08, 0.13, 0.31), (0.08, 0.035, 0.34)]]
            tube(bm, [f[0], f[1]], [0.066, 0.045])
            tube(bm, [f[1], (0.082 * s, 0.3, 0.29), f[2]], [0.04, 0.031, 0.026])
            tube(bm, [f[2], f[3]], [0.03, 0.028])
            h = [mirror(p, s) for p in [(0.08, 0.56, -0.32), (0.09, 0.38, -0.24), (0.085, 0.2, -0.39), (0.085, 0.035, -0.36)]]
            tube(bm, [h[0], h[1]], [0.08, 0.052])
            tube(bm, [h[1], h[2]], [0.045, 0.028])
            ellipsoid(bm, (0.088 * s, 0.33, -0.29), (0.03, 0.06, 0.04), rot_xyz(x=0.7))
            tube(bm, [h[2], h[3]], [0.03, 0.028])
            for at in (f[3], h[3]):
                ellipsoid(bm, (at[0], 0.026, at[2] + 0.015), (0.033, 0.027, 0.048))  # patas
        tail = [(0, 0.6, -0.46), (0, 0.52, -0.58), (0, 0.41, -0.66), (0, 0.3, -0.7), (0, 0.24, -0.71)]
        tube(bm, tail, [0.035, 0.055, 0.06, 0.045, 0.02], 12)

        for s in (1, -1):
            n = "E" if s > 0 else "D"
            ear = self.detail("pelo", f"orelha_{n}")
            ellipsoid(ear, (0.052 * s, 0.9, 0.61), (0.013, 0.065, 0.036), rot_xyz(x=-0.15, z=-0.3 * s), 12, 10,
                      shape=lambda n: (1.0 - 0.75 * max(0.0, n.y) ** 1.5) * (0.6 if n.z > 0 else 1.0))
            inner = self.detail("interno", f"orelha_{n}")
            ellipsoid(inner, (0.053 * s, 0.895, 0.617), (0.005, 0.05, 0.025), rot_xyz(x=-0.15, z=-0.3 * s), 10, 8,
                      shape=lambda n: 1.0 - 0.7 * max(0.0, n.y) ** 1.5)
            eye = self.detail("olho_brilho", "cabeca")
            ellipsoid(eye, (0.046 * s, 0.82, 0.725), (0.011, 0.009, 0.01), rot_xyz(y=0.5 * s), 10, 6)
            for name, at in (("d", (0.08 * s, 0.024, 0.37)), ("t", (0.085 * s, 0.024, -0.33))):
                claws = self.detail("garra", f"{name}_pata_{n}")
                for toe in range(4):
                    x = at[0] + (toe - 1.5) * 0.011
                    horn(claws, [(x, 0.018, at[2] + 0.035), (x, 0.012, at[2] + 0.05), (x, 0.004, at[2] + 0.058)], [0.005, 0.004, 0.002], 5)
        nose = self.detail("nariz", "cabeca")
        ellipsoid(nose, (0, 0.752, 0.868), (0.022, 0.018, 0.016), None, 10, 8)

        self.bone("corpo", None, (0, 0.56, 0.0), (0, 0.56, 0.25), 0.15)
        self.bone("peito", "corpo", (0, 0.58, 0.15), (0, 0.6, 0.42), 0.15)
        self.bone("pescoco", "peito", (0, 0.64, 0.42), (0, 0.78, 0.6), 0.09)
        self.bone("cabeca", "pescoco", (0, 0.79, 0.62), (0, 0.745, 0.89), 0.065)
        self.bone("cauda", "corpo", (0, 0.6, -0.45), (0, 0.45, -0.62), 0.05)
        self.bone("cauda_ponta", "cauda", (0, 0.45, -0.62), (0, 0.24, -0.71), 0.05)
        for s in (1, -1):
            n = "E" if s > 0 else "D"
            self.bone(f"orelha_{n}", "cabeca", (0.045 * s, 0.85, 0.6), (0.06 * s, 0.94, 0.59), 0.025)
            leg_bones(self, "d", s, "peito", [mirror(p, s) for p in [(0.08, 0.62, 0.32), (0.085, 0.43, 0.27), (0.08, 0.13, 0.31), (0.08, 0.0, 0.35)]], [0.05, 0.026, 0.02])
            leg_bones(self, "t", s, "corpo", [mirror(p, s) for p in [(0.08, 0.56, -0.32), (0.09, 0.38, -0.24), (0.085, 0.2, -0.39), (0.085, 0.0, -0.35)]], [0.065, 0.03, 0.02])

    def paint(self, p, n):
        # Lobo cinzento: sela escura nas costas, garganta, barriga, focinho e pernas por dentro
        # claros, ponta do rabo escura, máscara clara em volta dos olhos.
        if p.z < -0.44:
            # Rabo: ponta escura, o resto com o pelo de cima.
            return "pelo_escuro" if p.y < 0.34 or n.y > 0.4 else "pelo"
        if p.z > 0.7 and p.y < 0.76:
            return "claro"  # queixo e beiço
        if p.z > 0.58 and abs(p.x) > 0.06 and p.y < 0.78 and n.y < 0.2:
            return "claro"  # bochechas por baixo
        if p.y < 0.6 and p.z > 0.3 and n.y < -0.1 and abs(p.x) < 0.07:
            return "claro"
        if p.y < 0.5 and n.y < -0.4 and abs(p.z) < 0.35:
            return "claro"
        if p.y < 0.5 and abs(p.x) < 0.07 and abs(p.z) > 0.2:
            return "claro"
        if p.y > 0.68 and abs(p.x) < 0.09 and -0.45 < p.z < 0.38:
            return "pelo_escuro"
        if p.z < -0.45 and n.y > 0.3:
            return "pelo_escuro"
        return "pelo"


# --- Aves ------------------------------------------------------------------------------------

def wing(bm, side, shoulder, span, chord, thickness, fingers):
    """Asa aberta para o lado `side`: bordo de ataque reto, bordo de fuga arredondado e, na
    ponta, as rêmiges abertas como dedos."""
    sx, sy, sz = shoulder
    ellipsoid(bm, (sx + side * span * 0.42, sy, sz - chord * 0.12), (span * 0.45, thickness, chord * 0.5), None, 16, 8,
              shape=lambda n: (1.0 - 0.35 * max(0.0, n.x * side) ** 2) * (1.0 + 0.25 * max(0.0, -n.z)))
    for i in range(fingers):
        t = i / max(1, fingers - 1)
        root = Vector((sx + side * span * 0.78, sy, sz - chord * (0.05 + 0.5 * t)))
        tip = root + Vector((side * span * (0.24 - 0.1 * t), 0.0, -chord * (0.1 + 0.35 * t)))
        horn(bm, [root, root.lerp(tip, 0.5), tip], [(chord * 0.09, thickness), (chord * 0.07, thickness * 0.8), (chord * 0.03, thickness * 0.5)], 6)


class Crow(Creature):
    def __init__(self):
        super().__init__("crow", voxel=0.004, target_faces=2500, bumps=0.25)
        bm = self.body
        ellipsoid(bm, (0, 0, -0.01), (0.056, 0.052, 0.115))
        ellipsoid(bm, (0, -0.008, 0.07), (0.054, 0.05, 0.07))
        ellipsoid(bm, (0, 0.03, 0.19), (0.04, 0.041, 0.05), shape=lambda n: 1.0 + 0.06 * max(0.0, n.y))
        tube(bm, [(0, 0.012, 0.12), (0, 0.025, 0.17)], [0.04, 0.036], 12)
        beak = self.detail("bico", "cabeca")
        horn(beak, [(0, 0.024, 0.222), (0, 0.018, 0.26), (0, 0.006, 0.3)], [(0.013, 0.016), (0.009, 0.01), (0.003, 0.004)], 8)
        for s in (1, -1):
            eye = self.detail("olho", "cabeca")
            ellipsoid(eye, (0.03 * s, 0.045, 0.21), (0.008, 0.008, 0.008), None, 8, 6)
            n = "E" if s > 0 else "D"
            wing(self.detail("pena", f"asa_{n}"), s, (0.04 * s, 0.03, 0.02), 0.46, 0.2, 0.008, 5)
            legs = self.detail("bico", "pernas")
            tube(legs, [(0.024 * s, -0.035, 0.04), (0.027 * s, -0.1, 0.05), (0.028 * s, -0.145, 0.06)], [0.008, 0.005, 0.005], 6)
            for toe, (dx, dz) in enumerate([(0.0, 0.04), (0.018, 0.03), (-0.018, 0.03), (0.0, -0.03)]):
                horn(legs, [(0.028 * s, -0.148, 0.06), (0.028 * s + dx * s, -0.152, 0.06 + dz)], [0.004, 0.002], 5)
        tail = self.detail("pena", "cauda")
        ellipsoid(tail, (0, 0.0, -0.2), (0.05, 0.007, 0.09), None, 14, 6,
                  shape=lambda n: 1.0 + 0.45 * max(0.0, -n.z) * abs(n.x))
        self.bone("corpo", None, (0, 0, -0.08), (0, 0, 0.12), 0.06)
        self.bone("cabeca", "corpo", (0, 0.03, 0.16), (0, 0.02, 0.3), 0.045)
        self.bone("pernas", "corpo", (0, -0.04, 0.04), (0, -0.15, 0.06), 0.02)
        self.bone("cauda", "corpo", (0, 0, -0.12), (0, 0, -0.28), 0.02)
        for s in (1, -1):
            self.bone(f"asa_{'E' if s > 0 else 'D'}", "corpo", (0.04 * s, 0.03, 0.0), (0.5 * s, 0.03, 0.0), 0.05)

    def paint(self, p, n):
        return "pena"


class Bird(Creature):
    """Pássaros pousados: canoro (meio deitado), pica-pau (de pé no tronco) e coruja (empertigada).
    O corpo vem na pose de pouso; as asas abertas só aparecem em voo (o jogo as encolhe pousado)."""

    def __init__(self, name):
        super().__init__(name, voxel=0.0028 if name != "owl" else 0.005, target_faces=1600 if name != "owl" else 2600, bumps=0.15)
        self.kind = name
        size = {"songbird": (0.055, 0.05, 0.09), "woodpecker": (0.06, 0.06, 0.13), "owl": (0.14, 0.13, 0.17)}[name]
        pitch = {"songbird": -0.35, "woodpecker": -1.2, "owl": -1.0}[name]
        self.size = size
        bm = self.body
        tilt = rot_xyz(x=pitch)
        ellipsoid(bm, (0, 0, 0), (size[0] * 0.5, size[1] * 0.5, size[2] * 0.55), tilt,
                  shape=lambda n: 1.0 + 0.12 * max(0.0, -n.y))
        top = tilt @ Vector((0, 0, size[2] * 0.5))
        r = size[0] * (0.42 if name == "owl" else 0.36)
        head = top + Vector((0, r * 0.7, r * 0.15)) if name != "songbird" else Vector((0, size[1] * 0.45, size[2] * 0.42))
        self.head = head
        ellipsoid(bm, head, (r, r * 0.95, r * (0.9 if name == "owl" else 1.0)))
        tube(bm, [top * 0.6, head], [size[0] * 0.38, r * 0.85], 10, caps=False)
        tail_dir = (tilt @ Vector((0, 0, -1))).normalized()
        tail_base = tilt @ Vector((0, 0, -size[2] * 0.45))
        tail = self.detail("pena", "corpo")
        tail_len = size[2] * (0.6 if name != "owl" else 0.35)
        horn(tail, [tail_base, tail_base + tail_dir * tail_len * 0.6, tail_base + tail_dir * tail_len],
             [(size[0] * 0.3, size[0] * 0.06), (size[0] * 0.34, size[0] * 0.05), (size[0] * 0.3, size[0] * 0.04)], 8)
        beak_len = {"songbird": 0.016, "woodpecker": 0.04, "owl": 0.018}[name]
        beak = self.detail("bico", "cabeca")
        b0 = head + Vector((0, -r * 0.1 if name != "owl" else -r * 0.25, r * 0.85))
        horn(beak, [b0, b0 + Vector((0, -0.002 if name != "owl" else -0.008, beak_len))],
             [r * (0.3 if name != "owl" else 0.18), r * 0.1], 6)
        eye_r = r * (0.28 if name == "owl" else 0.16)
        for s in (1, -1):
            eye = self.detail("olho_brilho" if name == "owl" else "olho", "cabeca")
            ex = r * (0.42 if name == "owl" else 0.62)
            ellipsoid(eye, head + Vector((ex * s, r * 0.18, r * (0.82 if name == "owl" else 0.6))), (eye_r, eye_r, eye_r * 0.6), None, 8, 6)
            if name == "owl":
                pupil = self.detail("olho", "cabeca")
                ellipsoid(pupil, head + Vector((ex * s, r * 0.18, r * 0.82 + eye_r * 0.55)), (eye_r * 0.5, eye_r * 0.5, eye_r * 0.2), None, 8, 6)
                tuft = self.detail("pena", "cabeca")
                horn(tuft, [head + Vector((r * 0.55 * s, r * 0.75, 0.0)), head + Vector((r * 0.7 * s, r * 1.15, -r * 0.1))], [r * 0.14, r * 0.04], 5)
            shoulder = (size[0] * 0.45 * s, size[1] * 0.2, 0.0)
            wing(self.detail("pena", f"asa_{'E' if s > 0 else 'D'}"), s, shoulder, size[2] * 1.6, size[2] * 0.6, 0.004 if name != "owl" else 0.008, 4)
            feet = self.detail("bico", "corpo")
            foot = tilt @ Vector((size[0] * 0.25 * s, -size[1] * 0.45, 0.0))
            for dz in (0.012, -0.01):
                horn(feet, [foot, foot + Vector((0, -0.004, dz))], [0.003, 0.0015], 5)
        self.bone("corpo", None, (0, -0.01, -0.02), (0, 0.01, 0.04), size[0])
        self.bone("cabeca", "corpo", tuple(head - Vector((0, r * 0.6, r * 0.2))), tuple(head + Vector((0, 0, r))), r)
        for s in (1, -1):
            self.bone(f"asa_{'E' if s > 0 else 'D'}", "corpo", (size[0] * 0.45 * s, size[1] * 0.2, 0.0), (size[0] * 0.45 * s + size[2] * 1.6 * s, size[1] * 0.2, 0.0), 0.02)

    def paint(self, p, n):
        q = p - self.head
        if self.kind == "woodpecker":
            if q.y > 0.0 and q.z < 0.01 and q.length < self.size[0] * 0.5:
                return "detalhe"  # boné vermelho
            if n.z > 0.3 and p.y < self.head.y - 0.01:
                return "pena_clara"
            return "pena"
        if self.kind == "owl":
            if q.length < self.size[0] * 0.5 and n.z > 0.35:
                return "pena_clara"  # disco da cara
            if n.z > 0.2 and p.y < self.head.y - 0.03:
                return "pena_clara"
            return "pena"
        if n.z > 0.15 and p.y < self.head.y - 0.005:
            return "pena_clara"  # peito
        return "pena"


# --- Execução ------------------------------------------------------------------------------

SPECIES = {
    "deer": lambda: Deer(),
    "old_deer": lambda: Deer("old_deer", old=True),
    "rabbit": Rabbit,
    "boar": Boar,
    "wolf": Wolf,
    "crow": Crow,
    "songbird": lambda: Bird("songbird"),
    "woodpecker": lambda: Bird("woodpecker"),
    "owl": lambda: Bird("owl"),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def preview(body, name):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.55, 0.57, 0.6)
    size = max(body.dimensions)
    center = Vector(body.matrix_world.to_translation())
    bounds = [body.matrix_world @ Vector(c) for c in body.bound_box]
    center = sum(bounds, Vector()) / 8
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 60
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for view, direction in (("lado", Vector((1, 0, 0.12))), ("frente", Vector((0.7, -1.0, 0.25))), ("tras", Vector((-0.6, 1.0, 0.35)))):
        cam.location = center + direction.normalized() * size * 2.4
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(Path(PREVIEW) / f"{name}_{view}.png")
        bpy.ops.render.render(write_still=True)


def export(body, rig, name):
    activate(rig)
    body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ASSET / f"{name}.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_skins=True, export_animations=False, export_yup=True)


def main():
    for name in WANTED or list(SPECIES):
        reset()
        creature = SPECIES[name]()
        body, rig = creature.build()
        unweighted = sum(1 for v in body.data.vertices if not v.groups)
        print(f"[bichos] {name}: {len(body.data.polygons)} faces, {len(rig.data.bones)} ossos, sem peso: {unweighted}")
        assert unweighted == 0, name
        if PREVIEW:
            preview(body, name)
        export(body, rig, name)
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))


main()
