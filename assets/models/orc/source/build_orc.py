"""Monta o orc (F12, docs/plano_combate.md §7) a partir do goblin, no mesmo esqueleto de 31 ossos.

O orc usa o mesmo GoblinAnimator do goblin, então precisa dos mesmos ossos. Em vez de modelar do
zero, este script abre o goblin.blend e muda as proporções pelos ossos: pernas e tronco maiores e
mais grossos, pescoço de touro, cabeça e orelhas pequenas, presas grandes. A pose com as escalas é
"assada" na malha (o modificador de armadura é aplicado) e vira a nova pose de repouso. Depois
entram as peças do orc, cada uma presa a um osso: a máscara de couro com dois discos de osso no
lugar da boca (a primeira leitura; na segunda, o respirador da equipe de evacuação), o elmo e o
peitoral de ferro (o guerreiro; o jogo esconde no batedor). A escala final (o dobro do goblin) é
do nó no Godot (Orc.MODEL_SCALE): assim as poses do animador, que estão no espaço do esqueleto,
crescem junto.

Uso (na raiz do projeto):
  & $blender --background --python assets\\models\\orc\\source\\build_orc.py
Depois rode o --import do Godot.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

SOURCE = Path(__file__).resolve().parent
ASSET = SOURCE.parent
GOBLIN = ASSET.parent / "goblin" / "source" / "goblin.blend"

# Escala de cada osso (x, y = comprimento, z), relativa ao pai: com "AVERAGE" o filho herda só a
# média da escala do pai (sem cisalhar os braços, que saem do peito em outro ângulo).
PROPORTIONS = {
    "quadril": (1.2, 1.0, 1.15),
    "perna_D": (1.1, 1.5, 1.1), "perna_E": (1.1, 1.5, 1.1),
    "canela_D": (1.0, 1.3, 1.0), "canela_E": (1.0, 1.3, 1.0),
    "pe_D": (1.0, 1.05, 1.0), "pe_E": (1.0, 1.05, 1.0),
    "tronco": (1.3, 1.35, 1.25),
    "peito": (1.15, 1.1, 1.1),
    "braco_D": (0.92, 1.15, 0.92), "braco_E": (0.92, 1.15, 0.92),
    "antebraco_D": (1.05, 1.1, 1.05), "antebraco_E": (1.05, 1.1, 1.05),
    "mao_D": (1.1, 1.0, 1.1), "mao_E": (1.1, 1.0, 1.1),
    "pescoco": (1.5, 1.2, 1.4),
    "cabeca": (0.62, 0.6, 0.62),
    "orelha_D": (0.75, 0.42, 0.75), "orelha_E": (0.75, 0.42, 0.75),
    "nariz": (0.85, 0.55, 0.85),
    "sobrancelha": (1.25, 1.0, 1.25),
    "presa_D": (1.8, 1.8, 1.8), "presa_E": (1.8, 1.8, 1.8),
}


def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.8
    mat.diffuse_color = (*color, 1.0)
    return mat


def piece(name, bm, mat, bone, rig, collection):
    """Uma peça rígida presa a um osso (todo vértice com peso 1 nele)."""
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    collection.objects.link(ob)
    ob.parent = rig
    ob.data.materials.append(mat)
    group = ob.vertex_groups.new(name=bone)
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return ob


def bone_frame(rig, bone):
    """Cabeça do osso e seus eixos (x, y = ao longo do osso, z) no espaço do objeto, em repouso."""
    b = rig.data.bones[bone]
    m = b.matrix_local
    return m.translation.copy(), m.col[0].xyz.normalized(), m.col[1].xyz.normalized(), m.col[2].xyz.normalized()


def disc(bm, center, normal, radius, depth, segments=10):
    """Um disco grosso (cilindro baixo) de `center` ao longo de `normal`."""
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments,
                                radius1=radius, radius2=radius * 0.9, depth=depth)
    rot = normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rot, verts=ret["verts"])


def shell(bm, center, scale, rot=Matrix.Identity(4), segments=12, rings=8, keep=lambda co: True):
    """Um elipsoide (pedaço dele, pelo `keep` no espaço da esfera unitária)."""
    ret = bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    verts = ret["verts"]
    drop = [v for v in verts if not keep(v.co)]
    bmesh.ops.delete(bm, geom=drop, context="VERTS")
    left = [v for v in bm.verts if v.is_valid]
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rot @ Matrix.Diagonal((*scale, 1.0)), verts=left)


def main():
    bpy.ops.wm.open_mainfile(filepath=str(GOBLIN))
    rig = bpy.data.objects["goblin.rig"]
    collection = bpy.data.collections["BA goblin"]
    if rig.animation_data is not None:
        rig.animation_data.action = None
        for track in rig.animation_data.nla_tracks:
            track.mute = True
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    for b in rig.data.bones:
        b.inherit_scale = "AVERAGE"
    for name, scale in PROPORTIONS.items():
        rig.pose.bones[name].scale = scale
    bpy.context.view_layer.update()

    # Assa a pose na malha e faz dela o novo repouso.
    meshes = [ob for ob in collection.objects if ob.type == "MESH"]
    for ob in meshes:
        activate(ob)
        for mod in list(ob.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)
    activate(rig)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for b in rig.data.bones:
        b.inherit_scale = "FULL"
    for ob in meshes:
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = rig

    # Cores do orc (o jogo troca pelos materiais com textura, por nome da paleta, em GoblinLook).
    material("goblin.pele", (0.33, 0.36, 0.3))

    # As peças se encaixam na malha medida (os ossos ficam dentro do focinho e do crânio).
    body = bpy.data.objects["Corpo_continuo"]
    verts = [v.co.copy() for v in body.data.vertices]
    mouth, _, _, _ = bone_frame(rig, "boca")
    chest, _, _, _ = bone_frame(rig, "peito")
    leather = material("goblin.couro", (0.18, 0.14, 0.11))
    bone_mat = material("orc.osso", (0.5, 0.46, 0.38))
    iron = material("goblin.metal", (0.32, 0.32, 0.34))

    # A máscara: uma meia casca de couro sobre o focinho e a boca, com dois discos de osso (os
    # "filtros") dos lados. A frente do rosto é o vértice mais à frente (-Y) na altura da boca.
    snout = [c for c in verts if abs(c.x) < 0.035 and abs(c.z - mouth.z) < 0.03]
    front = min(c.y for c in snout)
    bm = bmesh.new()
    shell(bm, Vector((0.0, front + 0.045, mouth.z + 0.012)), (0.085, 0.07, 0.062), keep=lambda co: co.y < 0.2)
    piece("Mascara", bm, leather, "cabeca", rig, collection)
    bm = bmesh.new()
    for side in (-1.0, 1.0):
        disc(bm, Vector((side * 0.06, front + 0.012, mouth.z - 0.005)), Vector((side * 0.55, -1.0, -0.1)).normalized(), 0.026, 0.022)
    piece("Filtros", bm, bone_mat, "cabeca", rig, collection)

    # O elmo: meia casca de ferro sobre o crânio, um pouco maior que ele. O peitoral: uma casca em
    # volta do peito. São do guerreiro (o jogo esconde no batedor).
    top = max(c.z for c in verts if abs(c.x) < 0.04)
    # Sem as orelhas: só o miolo do crânio.
    skull = [c for c in verts if c.z > top - 0.1 and abs(c.x) < 0.1]
    lo = Vector((min(c.x for c in skull), min(c.y for c in skull), min(c.z for c in skull)))
    hi = Vector((max(c.x for c in skull), max(c.y for c in skull), max(c.z for c in skull)))
    middle = (lo + hi) * 0.5
    bm = bmesh.new()
    shell(bm, Vector((middle.x, middle.y, top - 0.085)), ((hi.x - lo.x) * 0.5 + 0.02, (hi.y - lo.y) * 0.5 + 0.02, 0.105),
          keep=lambda co: co.z > -0.25)
    piece("Elmo", bm, iron, "cabeca", rig, collection)
    torso = [c for c in verts if abs(c.z - (chest.z + 0.02)) < 0.08 and abs(c.x) < 0.3]
    tlo = Vector((min(c.x for c in torso), min(c.y for c in torso), 0.0))
    thi = Vector((max(c.x for c in torso), max(c.y for c in torso), 0.0))
    bm = bmesh.new()
    shell(bm, Vector(((tlo.x + thi.x) * 0.5, (tlo.y + thi.y) * 0.5, chest.z + 0.02)),
          ((thi.x - tlo.x) * 0.5 + 0.012, (thi.y - tlo.y) * 0.5 + 0.012, 0.13), keep=lambda co: abs(co.z) < 0.8)
    piece("Peitoral", bm, iron, "peito", rig, collection)
    print("ORC rosto %.3f, crânio %.3f, peito %.3f x %.3f" % (front, top, thi.x - tlo.x, thi.y - tlo.y))

    root = bpy.data.objects["goblin"]
    root.name = "orc"
    rig.name = "orc.rig"
    bpy.ops.object.select_all(action="DESELECT")
    for ob in collection.objects:
        ob.select_set(True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = rig
    ASSET.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(ASSET / "orc.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_skins=True, export_animations=False,
                              export_extras=True, export_yup=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "orc.blend"))
    height = max((ob.matrix_world @ v.co).z for ob in collection.objects if ob.type == "MESH" for v in ob.data.vertices)
    print("ORC altura (sem a escala do jogo): %.3f m" % height)


main()
