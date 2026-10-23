"""Polimento reproduzível do goblin. Executar no Blender, a partir deste arquivo.

Mantém o esqueleto, ações e sockets originais. A fonte editável final é goblin.blend.
O blueprint antigo serve apenas de base: export_game o reconstruiria sem o polimento.
"""
from pathlib import Path
import json
import math
import random
import bpy
import bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

SOURCE = Path(__file__).resolve().parent
ASSET = SOURCE.parent
bpy.ops.wm.open_mainfile(filepath=str(SOURCE / 'goblin_before_polish.blend'))
rig = bpy.data.objects['goblin.rig']
collection = bpy.data.collections['BA goblin']
root = bpy.data.objects['goblin']
bpy.context.scene.frame_set(1)
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()

# Preserve a rig-compatible bind pose and all gameplay attachment nodes.
for ob in list(collection.objects):
    if ob.type == 'MESH':
        bpy.data.objects.remove(ob, do_unlink=True)

# Articulated limbs: knee, ankle, elbow and wrist bones replace the kit's one-bone limbs,
# so the game can bend legs and arms. Sockets keep their world position and follow the
# bone that now carries that part of the body.
KNEE_Z, ANKLE_Z, ELBOW_Z, WRIST_Z = .228, .080, .525, .362
sockets = {ob.name: ob.matrix_world.copy() for ob in bpy.data.objects if ob.parent == rig and ob.parent_type == 'BONE'}
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
edit_bones = rig.data.edit_bones

def set_bone(name, head, tail, parent=None):
    bone = edit_bones.get(name) or edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.roll = 0
    bone.use_connect = False
    if parent:
        bone.parent = edit_bones[parent]

for s, side in [(-1, 'D'), (1, 'E')]:
    knee, ankle = (s*.090, -.015, KNEE_Z), (s*.095, .008, ANKLE_Z)
    elbow, wrist = (s*.198, .024, ELBOW_Z), (s*.237, -.030, WRIST_Z)
    set_bone('perna_'+side, (s*.070, 0, .360), knee)
    set_bone('canela_'+side, knee, ankle, 'perna_'+side)
    set_bone('pe_'+side, ankle, (s*.095, -.110, .025), 'canela_'+side)
    set_bone('braco_'+side, (s*.150, .060, .655), elbow)
    set_bone('antebraco_'+side, elbow, wrist, 'braco_'+side)
    set_bone('mao_'+side, wrist, (s*.242, -.050, .280), 'antebraco_'+side)
# Spine: the kit's single torso bone made the back a rigid board. The torso keeps the
# lumbar region, a chest bone carries the arms and the upper back, and a neck bone sits
# between chest and head, so the back can round, arch and bend sideways.
SPINE_BASE = edit_bones['tronco'].head.copy()
NECK_TOP = edit_bones['cabeca'].head.copy()
CHEST_Z = SPINE_BASE.lerp(NECK_TOP, .40).z
NECK_Z = SPINE_BASE.lerp(NECK_TOP, .88).z
set_bone('peito', SPINE_BASE.lerp(NECK_TOP, .40), SPINE_BASE.lerp(NECK_TOP, .88), 'tronco')
set_bone('pescoco', SPINE_BASE.lerp(NECK_TOP, .88), NECK_TOP, 'peito')
for name in ['braco_D', 'braco_E', 'trapo']:
    edit_bones[name].parent = edit_bones['peito']
edit_bones['cabeca'].parent = edit_bones['pescoco']
bpy.ops.object.mode_set(mode='OBJECT')
moved = {'.mao': 'mao_', '.punho': 'antebraco_', '.pe': 'pe_', '.tornozelo': 'canela_'}
for name, world in sockets.items():
    ob = bpy.data.objects[name]
    for suffix, bone in moved.items():
        if name.endswith(suffix) and name.split('.')[0][-1] in 'DE':
            ob.parent_bone = bone + name.split('.')[0][-1]
    # Torso sockets on the upper back (quiver) now ride on the chest.
    if ob.parent_bone == 'tronco' and world.translation.z > CHEST_Z - .02:
        ob.parent_bone = 'peito'
    ob.matrix_world = world
bpy.context.view_layer.update()

def material(key, color=None, roughness=.86):
    name = 'goblin.' + key
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    # Blender 5 may create a material without the default Principled node.
    bsdf = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        bsdf = nodes.new('ShaderNodeBsdfPrincipled')
        output = next((n for n in nodes if n.type == 'OUTPUT_MATERIAL'), None) or nodes.new('ShaderNodeOutputMaterial')
        mat.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    if color:
        rgb = [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]
        linear = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in rgb]
        mat.diffuse_color = (*linear, 1)
        bsdf.inputs['Base Color'].default_value = (*linear, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    return mat

mats = {key: material(key) for key in ['pele','pele_escura','trapo','trapo_escuro','couro','olho','boca','dente']}
mats['orelha_interna'] = material('orelha_interna', '#596441')
mats['pupila'] = material('pupila', '#14180F', .45)
mats['unha'] = material('unha', '#7C7855')
mats['metal'] = material('metal', '#8A7953', .7)
mats['costura'] = material('costura', '#9B8B69')

def activate(ob):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

def mesh(name, verts, faces, mat='pele'):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    ob = bpy.data.objects.new(name, data)
    collection.objects.link(ob)
    data.materials.append(mats[mat])
    return ob

def ellipsoid(name, center, scale, mat='pele', segments=16, rings=10):
    verts = [(center[0], center[1], center[2]-scale[2])]
    for j in range(1, rings):
        a = -math.pi/2 + math.pi*j/rings
        for i in range(segments):
            t = 2*math.pi*i/segments
            verts.append((center[0]+scale[0]*math.cos(a)*math.cos(t),
                          center[1]+scale[1]*math.cos(a)*math.sin(t),
                          center[2]+scale[2]*math.sin(a)))
    verts.append((center[0],center[1],center[2]+scale[2]))
    faces = [(0, 1+(i+1)%segments, 1+i) for i in range(segments)]
    for j in range(rings-2):
        for i in range(segments):
            a=1+j*segments+i; b=1+j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    last=len(verts)-1
    faces += [(last,last-1-i,last-1-(i+1)%segments) for i in range(segments)]
    return mesh(name,verts,faces,mat)

def blob(name, center, scale, shape, mat='pele', segments=24, rings=16):
    """An ellipsoid bent by shape(n) -> n', in unit-sphere space: lumpy skulls, not balls."""
    ob=ellipsoid(name,(0,0,0),(1,1,1),mat,segments,rings)
    for v in ob.data.vertices:
        n=Vector(shape(v.co.copy()))
        v.co=Vector((center[0]+n.x*scale[0],center[1]+n.y*scale[1],center[2]+n.z*scale[2]))
    ob.data.update()
    return ob

def gauss(n, at, width):
    return math.exp(-(n-Vector(at).normalized()).length_squared/(width*width))

def skull_shape(n):
    """Goblin skull: low sloping forehead, a crown that narrows and rises toward the back (an
    egg, not a ball), knobs, hollow temples and a left side a little fuller than the right."""
    x,y,z=n
    r=1.0
    r*=1-.13*max(0,z)**2                        # flatter crown
    r*=1+.11*max(0,y)*(1-abs(z))                # occiput sticks out behind
    r*=1+.06*max(0,y)*max(0,z)*abs(x)*2         # parietal bossing, wide at the back
    r*=1-.09*gauss(n,(1,-.25,.25),.45)-.10*gauss(n,(-1,-.25,.25),.42)  # temples sink in
    r*=1-.05*gauss(n,(0,-.55,.75),.35)          # dip above the brows
    for at,width,amount in [((.25,.10,1),.32,.04),((-.35,.45,.85),.30,.045),((.55,.60,.6),.28,.03),
                            ((-.15,-.35,.9),.25,.025),((.05,.85,.35),.30,.035),((-.6,.2,.7),.22,-.03)]:
        r*=1+amount*gauss(n,at,width)
    out=Vector((x,y,z))*r
    out.x*=(1.035 if x>0 else .985)*(1-.15*max(0,z))  # asymmetric, narrower on top
    out.z+=.09*max(0,y)*max(0,z)               # the dome rises toward the back
    out.y+=.16*max(0,-y)*max(0,z-.35)          # forehead slopes back above the brows
    out.z+=.035*x-.05*max(0,y)*max(0,-z)       # tilted crown; back of the jaw tucks under
    return out

def nape_shape(n):
    x,y,z=n
    out=Vector((x*(1.04 if x>0 else .97),y,z))*(1-.06*gauss(n,(0,1,-.3),.5)+.05*gauss(n,(.6,.5,.4),.4))
    return out

def loft(name, profiles, mat='pele', sides=16):
    # Cross sections in XY; explicit taper makes elbows, wrists, knees and ankles.
    verts=[]; faces=[]
    for x,y,z,rx,ry in profiles:
        for i in range(sides):
            t=2*math.pi*i/sides
            verts.append((x+rx*math.cos(t),y+ry*math.sin(t),z))
    for j in range(len(profiles)-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))),tuple((len(profiles)-1)*sides+i for i in range(sides))]
    return mesh(name,verts,faces,mat)

def tube(name, points, radii, mat='pele', sides=8):
    verts=[]; faces=[]
    points=[Vector(p) for p in points]
    for j,p in enumerate(points):
        tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
        u=tangent.cross(Vector((0,1,0)))
        if u.length < .01: u=tangent.cross(Vector((1,0,0)))
        u.normalize(); v=tangent.cross(u).normalized()
        for i in range(sides):
            t=2*math.pi*i/sides
            verts.append(tuple(p+radii[j]*(math.cos(t)*u+math.sin(t)*v)))
    for j in range(len(points)-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points)-1)*sides+i for i in range(sides))])
    return mesh(name,verts,faces,mat)

def bind(ob, bone=None, weights=None):
    if bone:
        group=ob.vertex_groups.new(name=bone)
        group.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    if weights:
        for vert in ob.data.vertices:
            values=weights(vert.co)
            total=sum(values.values())
            for name,value in values.items():
                if value < .00001: continue
                group=ob.vertex_groups.get(name) or ob.vertex_groups.new(name=name)
                group.add([vert.index],value/total,'REPLACE')
    ob.parent=rig
    ob.matrix_parent_inverse=rig.matrix_world.inverted()
    modifier=ob.modifiers.new('Goblin skin','ARMATURE')
    modifier.object=rig
    return ob

def smoothstep(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)))
    return t*t*(3-2*t)

def body_weights(p):
    x,y,z=p; side='E' if x >= 0 else 'D'
    lower=1-smoothstep(.42,.59,z)
    arm=smoothstep(.112+.033*lower,.177-.002*lower,abs(x))*(1-smoothstep(.650,.718,z))
    if z<.255: arm=0
    head=smoothstep(.705,.780,z)
    leg=(1-smoothstep(.305,.393,z)) if abs(x)>.015 else 0
    torso=smoothstep(.412,.535,z)
    remainder=(1-arm)*(1-head)
    # The back blends lumbar -> chest -> neck over a few centimetres at each vertebra group.
    chest=smoothstep(CHEST_Z-.045,CHEST_Z+.045,z); neck=smoothstep(NECK_Z-.025,NECK_Z+.02,z)
    trunk=torso*(1-leg)*remainder
    values={'tronco':trunk*(1-chest),'peito':trunk*chest*(1-neck),'pescoco':trunk*chest*neck,
            'quadril':(1-torso)*(1-leg)*remainder}
    # Limbs blend across each joint over a few centimetres, like skin over a knee.
    fore=smoothstep(ELBOW_Z+.025,ELBOW_Z-.025,z); hand=smoothstep(WRIST_Z+.012,WRIST_Z-.018,z)
    values['braco_'+side]=arm*(1-fore)
    values['antebraco_'+side]=arm*fore*(1-hand)
    values['mao_'+side]=arm*hand
    shin=smoothstep(KNEE_Z+.030,KNEE_Z-.030,z); foot=smoothstep(ANKLE_Z+.012,ANKLE_Z-.028,z)
    values['perna_'+side]=leg*remainder*(1-shin)
    values['canela_'+side]=leg*remainder*shin*(1-foot)
    values['pe_'+side]=leg*remainder*foot
    # Ears hang on their own bones so they can flop; the root stays on the skull.
    ear=smoothstep(.135,.170,abs(x))*smoothstep(.825,.850,z)*head*(1-arm)
    values['orelha_'+side]=ear
    values['cabeca']=head*(1-arm)-ear
    return values

skin=[]
skin.append(loft('anatomia_tronco',[
    (0,0,.328,.062,.055),(0,0,.357,.108,.076),(0,.006,.405,.111,.079),
    (0,.005,.449,.092,.073),(0,-.002,.493,.093,.080),(0,.008,.541,.109,.086),
    (0,.025,.588,.128,.096),(0,.042,.631,.143,.096),(0,.055,.662,.129,.085),
    (0,.042,.692,.083,.064),(0,.015,.721,.052,.050)]))
skin.append(ellipsoid('pescoco',(0,.005,.726),(.053,.054,.069)))
skin.append(ellipsoid('trapezio',(0,.078,.666),(.126,.070,.053)))
# Facial masses, continuous from skull through jaw, cheeks, nose and neck.
# Skull a little longer at the back and lower on top; a hooked nose; real lips and a chin.
skin.append(blob('cranio',(0,.012,.857),(.124,.116,.118),skull_shape,segments=32,rings=20))
skin.append(blob('nuca',(0,.062,.842),(.098,.078,.096),nape_shape,segments=20,rings=12))
skin.append(ellipsoid('maxilar',(0,-.028,.790),(.097,.088,.054),segments=20,rings=12))
skin.append(ellipsoid('queixo',(0,-.084,.768),(.052,.050,.033)))
skin.append(ellipsoid('focinho',(0,-.100,.813),(.069,.040,.027)))
# The nose grows out of the brow: a broad root that narrows down the bridge to a bulbous,
# hooked tip with flared nostril wings (a thin root read as a sausage stuck on the face).
skin.append(tube('ponte_nasal',[(0,-.095,.896),(0,-.132,.876),(0,-.170,.855),(0,-.200,.838),(0,-.208,.824)], [.023,.020,.020,.017,.011],sides=12))
skin.append(ellipsoid('ponta_nariz',(0,-.192,.834),(.024,.027,.021)))
# The body of the nose: a wedge that is tall and wide where it leaves the face (brow down to
# the upper lip) and tapers to the tip, so in profile the nose is a triangle grown from the
# face, not a tube stuck on it. Sections across the nose (XZ ellipses) along -Y.
def wedge(name, stations, sides=14):
    verts=[]; faces=[]
    for y,zc,rx,rz in stations:
        for i in range(sides):
            t=2*math.pi*i/sides
            verts.append((rx*math.cos(t),y,zc+rz*math.sin(t)))
    for j in range(len(stations)-1):
        for i in range(sides):
            a=j*sides+i; b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))),tuple((len(stations)-1)*sides+i for i in range(sides))]
    return mesh(name,verts,faces)
skin.append(wedge('corpo_nariz',[(-.100,.8565,.028,.0415),(-.130,.8515,.025,.0325),(-.155,.8445,.021,.0215),(-.180,.8365,.019,.0145)]))
skin.append(ellipsoid('labio_superior',(0,-.127,.807),(.058,.020,.011)))
skin.append(ellipsoid('labio_inferior',(0,-.121,.787),(.064,.025,.016)))

for s,side in [(-1,'D'),(1,'E')]:
    skin.append(ellipsoid('malar_'+side,(s*.084,-.060,.826),(.041,.045,.034)))
    skin.append(ellipsoid('asa_nariz_'+side,(s*.018,-.186,.826),(.012,.015,.011)))
    # Brow ridge sunk into the skull: two flat swells of bone under the skin over each eye,
    # not a log laid across it (a tube read as a horn in profile).
    skin.append(ellipsoid('sobrancelha_'+side,(s*.040,-.088,.892),(.026,.011,.010)))
    skin.append(ellipsoid('sobrancelha_fora_'+side,(s*.077,-.071,.895),(.024,.011,.010)))
    skin.append(loft('anatomia_braco_'+side,[(s*x,y,z,rx,ry) for x,y,z,rx,ry in [
        (.135,.064,.691,.026,.030),(.151,.065,.668,.049,.051),(.165,.060,.637,.050,.050),
        (.180,.044,.590,.042,.041),(.192,.028,.545,.031,.032),(.198,.024,.521,.030,.032),
        (.211,.006,.483,.038,.039),(.226,-.011,.431,.033,.032),(.235,-.028,.377,.022,.025),
        (.239,-.033,.358,.025,.027),(.241,-.035,.333,.038,.030),(.241,-.036,.309,.034,.026)]]))
    for i,dx in enumerate([-.023,0,.023]):
        ztip=[.278,.271,.281][i]
        skin.append(tube('dedo_'+side+str(i),[(s*(.241+dx),-.037,.325),(s*(.242+dx),-.040,.295),(s*(.242+dx),-.051,ztip)],[.013,.012,.009],sides=10))
    skin.append(tube('polegar_'+side,[(s*.213,-.031,.349),(s*.197,-.044,.331),(s*.203,-.064,.315)],[.017,.014,.010],sides=10))
    skin.append(loft('anatomia_perna_'+side,[(s*x,y,z,rx,ry) for x,y,z,rx,ry in [
        (.067,0,.389,.050,.060),(.077,.003,.353,.056,.060),(.085,-.001,.302,.049,.053),
        (.090,-.012,.256,.037,.040),(.092,-.020,.231,.034,.037),(.094,-.003,.198,.041,.045),
        (.095,.008,.163,.041,.044),(.095,.012,.115,.030,.032),(.095,.006,.067,.025,.029),
        (.095,-.015,.039,.032,.047)]]))
    skin.append(ellipsoid('pe_'+side,(s*.095,-.036,.041),(.048,.083,.038)))
    for i,(dx,length) in enumerate([(-.027,.025),(0,.032),(.028,.021)]):
        skin.append(ellipsoid('dedo_pe_'+side+str(i),(s*(.095+dx),-.105,.028),(.020,length,.023),segments=12,rings=8))
    # Leaf-shaped ears have a real rim, a root sunk into the skull, a slightly drooping
    # tip, a nick in the upper edge and a bowl (the centre sits behind the rim).
    outline=[(.093,-.008,.839),(.107,.007,.901),(.174,.025,.924),(.238,.040,.943),(.252,.043,.931),
             (.268,.047,.948),(.320,.058,.952),(.262,.040,.893),(.165,.012,.840)]
    n=len(outline)
    front=[(s*x,y-.015,z) for x,y,z in outline]
    back=[(s*x,y+.014,z) for x,y,z in outline]
    verts=front+back+[(s*.172,.020,.885),(s*.178,.048,.889)]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(2*n,i,j),(2*n+1,n+j,n+i),(i,n+i,n+j,j)])
    skin.append(mesh('orelha_'+side,verts,faces))

# Fuse the skin into one watertight component, then retain a deliberate low-poly surface.
bpy.ops.object.select_all(action='DESELECT')
for ob in skin: ob.select_set(True)
bpy.context.view_layer.objects.active=skin[0]
bpy.ops.object.join()
body=skin[0]; body.name='Corpo_continuo'
activate(body)
remesh=body.modifiers.new('Uniao anatomica','REMESH')
remesh.mode='VOXEL'; remesh.voxel_size=.0030; remesh.use_smooth_shade=False
bpy.ops.object.modifier_apply(modifier=remesh.name)
sm=body.modifiers.new('Transicoes organicas','SMOOTH'); sm.factor=.65; sm.iterations=4
bpy.ops.object.modifier_apply(modifier=sm.name)
# Nothing perfect: slow lumps over the whole skin (bumpy scalp, knobby joints, a lopsided
# chest), wide enough to survive the decimation. The face keeps its features readable.
rng=random.Random(346)
waves=[]
for _ in range(9):
    k=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-1,1))).normalized()*(math.tau/rng.uniform(.035,.085))
    waves.append((k,rng.uniform(0,math.tau)))
EYES=[Vector((s*.062,-.111,.869)) for s in (-1,1)]
bm=bmesh.new(); bm.from_mesh(body.data); bm.normal_update()
for v in bm.verts:
    p=v.co
    lump=sum(math.sin(k.dot(p)+phase) for k,phase in waves)/3
    amount=.0026+.0016*smoothstep(.74,.80,p.z)
    face=smoothstep(-.05,-.10,p.y)*smoothstep(.75,.79,p.z)*(1-smoothstep(.90,.93,p.z))
    eyes=min(smoothstep(.02,.045,(p-e).length) for e in EYES)
    amount*=(1-.7*face)*eyes
    v.co=p+v.normal*lump*amount
bm.to_mesh(body.data); bm.free()

dec=body.modifiers.new('Topologia de jogo','DECIMATE'); dec.ratio=.038
bpy.ops.object.modifier_apply(modifier=dec.name)
bm=bmesh.new(); bm.from_mesh(body.data)
unseen=set(bm.verts)
while unseen:
    stack=[unseen.pop()]; connected=[]
    while stack:
        v=stack.pop(); connected.append(v)
        for edge in v.link_edges:
            other=edge.other_vert(v)
            if other in unseen: unseen.remove(other); stack.append(other)
    if len(connected)<100:
        bmesh.ops.delete(bm,geom=connected,context='VERTS')
bm.to_mesh(body.data); bm.free()
for v in body.data.vertices:
    # Broad, stable soles; no toe or heel floating above the floor.
    if v.co.z < .015: v.co.z=0.0

# Face features carved into the skin itself, not pieces laid on top of it: the mouth is a
# groove between the lips, the nostrils are pits under the tip, the eyes sit in sockets whose
# lids are the same skin, and each ear has a bowl. The game mesh is too coarse there, so only
# those spots (and the finger and toe tips, for the nails) are subdivided before carving;
# the rest of the body keeps the decimated topology. Then each feature is painted face by face.
def flat_distance(p, line):
    """Distance in the XZ plane (seen from the front) from p to a polyline."""
    best=1.0
    for a,b in zip(line,line[1:]):
        ab=Vector((b.x-a.x,b.z-a.z)); ap=Vector((p.x-a.x,p.z-a.z))
        t=max(0,min(1,ap.dot(ab)/max(ab.length_squared,1e-9)))
        best=min(best,(ap-ab*t).length)
    return best

def inside_polygon(x, z, poly):
    inside=False
    for (ax,ay,az),(bx,by,bz) in zip(poly,poly[1:]+poly[:1]):
        if (az>z)!=(bz>z) and x<(bx-ax)*(z-az)/(bz-az)+ax: inside=not inside
    return inside

def polygon_edge_distance(x, z, poly):
    return flat_distance(Vector((x,0,z)),[Vector(p) for p in poly+poly[:1]])

# Sour grimace: corners pulled down and back around the muzzle.
MOUTH=[Vector(p) for p in [(-.071,-.110,.790),(-.047,-.133,.797),(-.021,-.142,.799),(0,-.144,.799),
                           (.021,-.142,.799),(.047,-.133,.797),(.071,-.110,.790)]]
MOUTH_HALF=.0040
EYE_R=.019
EAR_BOWL={s:[(s*.130,-.015,.858),(s*.140,-.005,.894),(s*.278,.034,.943),(s*.224,.012,.896),(s*.168,-.009,.868)] for s in (-1,1)}
# Where the nails go: fingertips (front of the finger) and the top of each toe.
FINGER_NAILS=[Vector((s*(.242+dx),-.057,tip+.004)) for s in (-1,1) for dx,tip in [(-.023,.278),(0,.271),(.023,.281)]]
TOE_NAILS=[Vector((s*(.095+dx),-.113-length*.40,.045)) for s in (-1,1) for dx,length in [(-.027,.025),(0,.032),(.028,.021)]]
probe=BVHTree.FromPolygons([v.co for v in body.data.vertices],[tuple(p.vertices) for p in body.data.polygons])
def front_hit(x, z):
    hit,normal,idx,dist=probe.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2)
    return hit
NOSTRILS=[]
for s in (-1,1):
    hit,normal,idx,dist=probe.ray_cast(Vector((s*.011,-.206,.70)),Vector((0,0,1)),.3)
    NOSTRILS.append(hit if hit is not None else Vector((s*.011,-.206,.814)))
EYE_CENTERS=[]
for s in (-1,1):
    surface=front_hit(s*.062,.869)
    # The eyeball sits 3 mm behind the old surface: the lids stand in front of it.
    EYE_CENTERS.append(Vector((s*.062,surface.y+.003+EYE_R,.869)))

def eye_opening(p, c):
    """0..1: inside the almond opening of the eye centred at c (heavy upper lid: low opening)."""
    s=1 if c.x>0 else -1
    dx=(p.x-c.x)*s; dz=p.z-c.z+.0025-.08*dx   # the outer corner droops a little
    q=math.sqrt((dx/.0175)**2+(dz/.0095)**2)
    return 1-smoothstep(.75,1.1,q)

def near_feature(p, fine):
    if p.y<-.07 and flat_distance(p,MOUTH)<.010: return True
    if any((p-c).length<.012 for c in NOSTRILS): return True
    if any((p-c).length<EYE_R*1.7 for c in EYE_CENTERS): return True
    # The ear bowl is broad and shallow: one subdivision is enough.
    if not fine and p.y<.05 and abs(p.x)>.12 and any(inside_polygon(p.x,p.z,poly) or polygon_edge_distance(p.x,p.z,poly)<.006 for poly in EAR_BOWL.values()): return True
    return any((p-h).length<.012 for h in FINGER_NAILS+TOE_NAILS)

bm=bmesh.new(); bm.from_mesh(body.data)
for fine in (False,True):
    edges=[e for e in bm.edges if near_feature((e.verts[0].co+e.verts[1].co)/2,fine)]
    bmesh.ops.subdivide_edges(bm,edges=edges,cuts=1,use_grid_fill=True,smooth=.5)
bm.normal_update()
for v in bm.verts:
    p=v.co.copy(); n=v.normal
    if n.y<-.2 and p.y<-.08:
        # Mouth: a groove deepest in the middle, shallower at the drooping corners.
        d=flat_distance(p,MOUTH)
        if d<MOUTH_HALF*1.6:
            corner=smoothstep(.071,.040,abs(p.x))
            v.co-=n*(.0028+.0030*corner)*(1-smoothstep(MOUTH_HALF*.4,MOUTH_HALF*1.6,d))
    for c in NOSTRILS:
        d=(p-c).length
        if d<.0065 and n.z<.2:
            v.co-=n*.006*(1-smoothstep(.002,.0065,d))
    for c in EYE_CENTERS:
        if n.y<.1 and abs(p.y-(c.y-EYE_R))<.025:
            m=eye_opening(p,c)
            if m>0:
                dx=p.x-c.x; dz=p.z-c.z
                inside=EYE_R*EYE_R-dx*dx-dz*dz
                target=c.y-math.sqrt(inside)+.0025 if inside>0 else c.y
                v.co.y=p.y+(max(p.y,target)-p.y)*m
    for s,poly in EAR_BOWL.items():
        if n.y<-.25 and p.y<.04 and inside_polygon(p.x,p.z,poly):
            v.co-=n*.0065*smoothstep(0,.009,polygon_edge_distance(p.x,p.z,poly))
bm.to_mesh(body.data); bm.free()
# Smooth skin: flat facets showed every polygon edge as a line on the back and arms.
for p in body.data.polygons: p.use_smooth=True

# Paint the carved features on the skin's own faces: the inside of the mouth groove and the
# nostrils, the ear bowls, and the nails at the finger and toe tips.
for key in ['boca','orelha_interna','unha']:
    body.data.materials.append(mats[key])
SLOT={m.name.split('.')[-1]:i for i,m in enumerate(body.data.materials)}
for poly in body.data.polygons:
    c=poly.center; n=poly.normal
    if n.y<0 and c.y<-.09 and flat_distance(c,MOUTH)<MOUTH_HALF*.75:
        poly.material_index=SLOT['boca']
    elif any((c-h).length<.0042 for h in NOSTRILS):
        poly.material_index=SLOT['boca']
    elif n.y<-.2 and c.y<.04 and any(inside_polygon(c.x,c.z,poly_) and polygon_edge_distance(c.x,c.z,poly_)>.0025 for poly_ in EAR_BOWL.values()):
        poly.material_index=SLOT['orelha_interna']
    elif n.y<-.3 and any((c-h).length<.0085 for h in FINGER_NAILS):
        poly.material_index=SLOT['unha']
    elif n.z>.3 and any((c-h).length<.011 for h in TOE_NAILS):
        poly.material_index=SLOT['unha']
skin_bvh=BVHTree.FromPolygons([v.co for v in body.data.vertices],[tuple(p.vertices) for p in body.data.polygons])

def conform_y(ob, back=False, offset=.008, cuts=1):
    """Fit cloth/ear interiors to the final surface, with room between faces."""
    if cuts:
        bm=bmesh.new(); bm.from_mesh(ob.data)
        bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=cuts,use_grid_fill=True)
        bm.to_mesh(ob.data); bm.free()
    for v in ob.data.vertices:
        origin=Vector((v.co.x,1 if back else -1,v.co.z))
        hit,normal,idx,dist=skin_bvh.ray_cast(origin,Vector((0,-1 if back else 1,0)),2)
        if hit is not None:
            v.co=hit+normal*offset+Vector((0,.002 if back else -.002,0))
    ob.data.update()
    return ob

bind(body,weights=body_weights)

# Eyeballs: round globes set in the carved sockets (the lids are the skin around them), with
# a vertical slit pupil painted on the globe itself, looking a little outward.
for c in EYE_CENTERS:
    s=1 if c.x>0 else -1
    globe=ellipsoid('Olho_'+('E' if s>0 else 'D'),tuple(c),(EYE_R,EYE_R,EYE_R),'olho',32,20)
    globe.data.materials.append(mats['pupila'])
    look=Vector((s*.16,-1,0)).normalized()
    side_axis=Vector((0,0,1)).cross(look).normalized()
    for poly in globe.data.polygons:
        d=(poly.center-c).normalized()
        if d.dot(look)>0:
            u=d.dot(side_axis); w=d.z
            if (u/.27)**2+(w/.62)**2<1: poly.material_index=1
    bind(globe,'cabeca')
for s,side in [(-1,'D'),(1,'E')]:
    # Tusks grow from the lower jaw inside the mouth groove and curve up past the upper lip.
    bind(tube('Presa_'+side,[(s*.045,-.127,.795),(s*.049,-.145,.806),(s*.046,-.150,.826)],[.0085,.0062,.0012],'dente',8),'cabeca')

def solidify(ob, thickness=.004):
    activate(ob)
    mod=ob.modifiers.new('Bordas com espessura','SOLIDIFY'); mod.thickness=thickness
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob

def cloth_weights(p):
    t=smoothstep(.43,.58,p.z); c=smoothstep(CHEST_Z-.045,CHEST_Z+.045,p.z)
    return {'quadril':1-t,'tronco':t*(1-c),'peito':t*c}

# Fitted sleeveless rag: open armholes, a V neckline, actual thickness and an uneven hem.
xs=[-1,-.72,-.40,0,.40,.72,1]
front_top=[.626,.658,.637,.581,.637,.658,.626]
back_top=[.626,.680,.694,.701,.694,.680,.626]
panels=[]
for back in [False,True]:
    verts=[]; faces=[]
    tops=back_top if back else front_top
    for row in range(4):
        for i,u in enumerate(xs):
            if row==0: z=tops[i]; rx=.139; yc=.032; ry=.112
            elif row==1: z=.576; rx=.133; yc=.018; ry=.108
            elif row==2: z=.499; rx=.110; yc=-.003; ry=.094
            else: z=[.429,.414,.436,.416,.438,.420,.432][i]; rx=.123; yc=.003; ry=.091
            y=yc+(1 if back else -1)*ry*math.sqrt(max(.0,1-u*u))
            y += (.003 if back else -.003)*math.sin(i*2.6+row)
            verts.append((u*rx,y,z))
    for j in range(3):
        for i in range(6):
            a=j*7+i; faces.append((a,a+1,a+8,a+7))
    panel=conform_y(mesh('Trapo_costas' if back else 'Trapo_frente',verts,faces,'trapo'),back=back,offset=.013,cuts=3)
    panels.append(panel)

# Side seams close the garment only below the armholes.
for s in [-1,1]:
    verts=[(s*.133,.018,.576),(s*.125,.045,.576),(s*.110,-.003,.499),(s*.112,.014,.499),(s*.123,.003,.429),(s*.124,.020,.429)]
    panels.append(mesh('Costura_lateral',verts,[(0,1,3,2),(2,3,5,4)],'trapo_escuro'))
for s in [-1,1]:
    verts=[]
    for y,z in [(-.025,.658),(.010,.686),(.055,.707),(.102,.698),(.135,.680)]:
        verts.extend([(s*.082,y,z),(s*.118,y,z-.007)])
    strap=mesh('Ombreira_trapo',verts,[(i,i+1,i+3,i+2) for i in range(0,8,2)],'trapo')
    for v in strap.data.vertices:
        hit,normal,idx,dist=skin_bvh.ray_cast(Vector((v.co.x,v.co.y,.739)),Vector((0,0,-1)),.25)
        if hit is not None: v.co=hit+normal*.013
    panels.append(strap)
for ob in panels: bind(solidify(ob,.005),weights=cloth_weights)

# Sewn neckline and a small repaired patch, visible in close views.
for s in [-1,1]:
    neckline=[]
    for x,z in [(s*.100,.658),(s*.080,.648),(s*.056,.637),(s*.028,.609),(0,.581)]:
        hit,normal,idx,dist=skin_bvh.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2)
        neckline.append(tuple(hit+normal*.016) if hit is not None else (x,-.06,z))
    bind(tube('Bainha_gola',neckline,[.003]*len(neckline),'trapo_escuro',6),weights=cloth_weights)
patch=conform_y(mesh('Remendo',[(-.095,-.070,.547),(-.044,-.093,.551),(-.045,-.096,.507),(-.092,-.073,.503)],[(0,1,2,3)],'trapo_escuro'),offset=.018,cuts=2)
bind(solidify(patch,.002),weights=cloth_weights)
for i in range(3):
    x=-.083+i*.014
    bind(conform_y(tube('Ponto_remendo',[(x,-.081-i*.005,.551),(x+.004,-.084-i*.005,.543)],[.0015,.0015],'costura',5),offset=.021,cuts=0),weights=cloth_weights)

# A real belt ring, not a solid block through the hips.
def band(name,cx,cy,cz,rx,ry,height,mat,bone):
    n=24; verts=[]; faces=[]
    for z,r in [(cz-height/2,1),(cz+height/2,1),(cz-height/2,.94),(cz+height/2,.94)]:
        for i in range(n):
            a=math.tau*i/n; verts.append((cx+r*rx*math.cos(a),cy+r*ry*math.sin(a),z))
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+j,2*n+i,3*n+i,3*n+j),(n+i,n+j,3*n+j,3*n+i),(j,i,2*n+i,2*n+j)])
    return bind(mesh(name,verts,faces,mat),bone)

band('Cinto',0,.003,.452,.122,.093,.028,'couro','quadril')
bind(tube('Fivela',[(-.016,-.094,.442),(.016,-.094,.442),(.016,-.094,.465),(-.016,-.094,.465),(-.016,-.094,.442)],[.003]*5,'metal',6),'quadril')
bind(tube('Pino_fivela',[(0,-.097,.441),(0,-.097,.463)],[.0018,.0018],'metal',6),'quadril')

# Front/back loincloths with folds and a ragged lower edge; roots sit under the belt.
for back in [False,True]:
    verts=[]; faces=[]
    for row in range(3):
        for i in range(5):
            u=(i-2)/2
            z=([.446]*5 if row==0 else [.358]*5 if row==1 else [.297,.278,.303,.285,.310])[i]
            width=[.087,.082,.071][row]
            y=(.101+row*.006)*(1 if back else -1)+.004*math.cos(i*math.pi)
            verts.append((u*width,y,z))
    for row in range(2):
        for i in range(4):
            a=row*5+i; faces.append((a,a+1,a+6,a+5))
    bind(solidify(mesh('Tanga_tras' if back else 'Tanga_frente',verts,faces,'trapo_escuro'),.004),'quadril')

bag=ellipsoid('Bolsa',(.130,.039,.388),(.036,.046,.053),'couro',12,8)
bind(bag,'quadril')
flap=ellipsoid('Aba_bolsa',(.148,.012,.411),(.026,.031,.017),'trapo_escuro',12,6)
bind(flap,'quadril')
bind(tube('Alca_bolsa',[(.120,.032,.459),(.137,.033,.447),(.143,.035,.424)],[.008,.008,.008],'couro',6),'quadril')
bind(ellipsoid('Fecho_bolsa',(.156,-.011,.404),(.005,.004,.005),'metal',8,6),'quadril')
for s,side in [(-1,'D'),(1,'E')]:
    for i in range(2):
        band('Faixa_punho_'+side,s*.234,-.025,.381+i*.013,.025+i*.002,.029,.010,'trapo_escuro','antebraco_'+side)
        band('Faixa_tornozelo_'+side,s*.095,.010,.088+i*.014,.028+i*.001,.032,.011,'trapo_escuro','canela_'+side)

# The bow socket follows the center of the newly shaped palm, preserving its name/orientation.
bpy.context.view_layer.update()
for s,side in [(-1,'D'),(1,'E')]:
    for suffix,point in [('mao',(s*.239,-.046,.329)),('punho',(s*.235,-.028,.371)),('ombro',(s*.14,.070,.660))]:
        ob=bpy.data.objects.get('braco_'+side+'.'+suffix)
        if ob:
            world=ob.matrix_world.copy(); world.translation=point; ob.matrix_world=world

# Merge render objects by role while preserving material slots and bone weights.
LIMBS=('braco_','antebraco_','mao_','perna_','canela_','pe_','orelha_')
for label,predicate in [('Rosto',lambda ob:any(g.name=='cabeca' or g.name.startswith('orelha_') for g in ob.vertex_groups)),
                        ('Vestuario',lambda ob:not any(g.name.startswith(LIMBS) for g in ob.vertex_groups)),
                        ('Detalhes_membros',lambda ob:True)]:
    objs=[ob for ob in collection.objects if ob.type=='MESH' and ob!=body and not ob.get('polish_group') and predicate(ob)]
    if not objs: continue
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs: ob.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.join(); objs[0].name=label; objs[0]['polish_group']=True

for ob in collection.objects:
    if ob.type!='MESH': continue
    bm=bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(ob.data); bm.free()
    # Skin, eyes and teeth are smooth; cloth and leather keep crisp folds.
    for poly in ob.data.polygons:
        slot=ob.material_slots[poly.material_index].material if ob.material_slots else None
        if slot and any(k in slot.name for k in ('pele','olho','pupila','dente')):
            poly.use_smooth=True
    # Explicit loop UVs remain useful when the model is used outside GoblinLook.
    uv=ob.data.uv_layers.new(name='BoxUV')
    for face in ob.data.polygons:
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        for li in face.loop_indices:
            v=ob.data.vertices[ob.data.loops[li].vertex_index].co/.32
            uv.data[li].uv=(v.y,v.z) if axis==0 else (v.x,v.z) if axis==1 else (v.x,v.y)

root['polish_version']=3
root['source_of_truth']='source/goblin.blend; source/polish_goblin.py'
root['style']='realista retro; malha continua; materiais pixelados do jogo'
bpy.context.scene.frame_set(1)
bpy.context.view_layer.update()
activate(body)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'goblin.blend'))
print(json.dumps({'source':str(SOURCE/'goblin.blend'),'meshes':[(o.name,len(o.data.vertices),sum(len(p.vertices)-2 for p in o.data.polygons)) for o in collection.objects if o.type=='MESH']},ensure_ascii=False))
