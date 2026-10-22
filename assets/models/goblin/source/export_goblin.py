"""Valida e exporta goblin.blend sem reconstruir o blueprint original."""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Matrix

SOURCE=Path(__file__).resolve().parent
ASSET=SOURCE.parent
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'goblin.blend'))
rig=bpy.data.objects['goblin.rig']
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks: track.mute=True
for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()

report={'meshes':[], 'bones':len(rig.data.bones), 'animations':[a.name for a in bpy.data.actions]}
collection=bpy.data.collections['BA goblin']
for ob in collection.objects:
    if ob.type!='MESH': continue
    bm=bmesh.new(); bm.from_mesh(ob.data)
    unseen=set(bm.verts); components=[]
    while unseen:
        stack=[unseen.pop()]; connected=[]
        while stack:
            v=stack.pop(); connected.append(v)
            for edge in v.link_edges:
                other=edge.other_vert(v)
                if other in unseen: unseen.remove(other); stack.append(other)
        components.append(len(connected))
    before=[face.normal.copy() for face in bm.faces]
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    item={'name':ob.name,'vertices':len(bm.verts),'triangles':sum(len(p.vertices)-2 for p in ob.data.polygons),
          'components':len(components),'open_edges':sum(not edge.is_manifold for edge in bm.edges),
          'flipped_normals':sum(face.normal.dot(n)<0 for face,n in zip(bm.faces,before)),
          'unweighted_vertices':sum(not v.groups for v in ob.data.vertices),
          'invalid_weights':sum(abs(sum(g.weight for g in v.groups)-1)>.0001 for v in ob.data.vertices),
          'nonfinite_vertices':sum(not all(math.isfinite(c) for c in v.co) for v in ob.data.vertices)}
    bm.free()
    assert not any(item[k] for k in ['open_edges','flipped_normals','unweighted_vertices','invalid_weights','nonfinite_vertices']),item
    if ob.name=='Corpo_continuo': assert len(components)==1,item
    assert ob.matrix_world.determinant()>0,ob.name
    report['meshes'].append(item)

assert {'parado','andando'}.issubset(report['animations'])
for side in ['D','E']:
    assert rig.data.bones.get('braco_'+side)
    assert bpy.data.objects.get('braco_'+side+'.mao')
report['triangles']=sum(item['triangles'] for item in report['meshes'])
report['hand_sockets']={s:list(bpy.data.objects['braco_'+s+'.mao'].matrix_world.translation) for s in ['D','E']}
report['height_m']=round(max((ob.matrix_world@v.co).z for ob in collection.objects if ob.type=='MESH' for v in ob.data.vertices),4)

bpy.ops.object.select_all(action='DESELECT')
for ob in collection.objects: ob.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ASSET/'goblin.glb'),export_format='GLB',use_selection=True,
    export_apply=True,export_skins=True,export_animations=True,export_animation_mode='ACTIONS',
    export_force_sampling=True,export_extras=True,export_yup=True)

meta=json.loads((ASSET/'goblin.json').read_text(encoding='utf-8'))
meta['altura_m']=report['height_m']
meta['polimento']={'versao':1,'fonte':'source/goblin.blend','gerador':'source/polish_goblin.py',
    'exportador':'source/export_goblin.py','triangulos':report['triangles'],
    'corpo_continuo':True,'observacao':'Nao reexportar diretamente o blueprint do kit: o polimento esta na fonte Blender.'}
(ASSET/'goblin.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(SOURCE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
