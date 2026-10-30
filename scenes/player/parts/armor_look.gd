class_name ArmorLook
extends Node
## A armadura e o escudo no corpo do goblin (F13, docs/plano_combate.md §5.2 e §5.3; experimental),
## só o visual: o que ele veste (Armor.worn) aparece preso aos ossos, como o manto da LeatherClothes.
## Capuz de couro, elmo de crânio ou elmo orc ajustado na cabeça; gibão de couro curtido ou peitoral
## orc ajustado no peito; o escudo de galhos no antebraço esquerdo quando a arma na mão é de uma mão.
## Os efeitos (proteção, barulho, peso, frio) ficam no Player, pela Armor.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira o visual.

## Onde cada peça fica no espaço do osso (Y sobe pelo osso).
const HEAD_OFFSET := Vector3(0.0, 0.165, 0.005)
const CHEST_OFFSET := Vector3(0.0, 0.035, 0.0)
const SHIELD_OFFSET := Vector3(0.045, 0.1, 0.0)

var _head: BoneAttachment3D
var _chest: BoneAttachment3D
var _shield: BoneAttachment3D
var _shown := {}

@onready var _player: Player = get_parent()


func _ready() -> void:
	Inventory.changed.connect(func(_item: StringName, _amount: int) -> void: _update())
	Inventory.held_changed.connect(func(_item: StringName) -> void: _update())
	_update.call_deferred()


func _update() -> void:
	var skeleton := _player.skeleton()
	if skeleton == null:
		return
	_head = _wear(skeleton, _head, "cabeca", Armor.worn(&"head"), &"head")
	_chest = _wear(skeleton, _chest, "peito", Armor.worn(&"body"), &"body")
	var shield := Armor.shield_in_use()
	_shield = _wear(skeleton, _shield, "antebraco_E", shield, &"shield")


## Troca a peça presa a `bone` quando o item vestido mudou.
func _wear(skeleton: Skeleton3D, holder: BoneAttachment3D, bone: String, item: StringName, slot: StringName) -> BoneAttachment3D:
	if _shown.get(slot, &"") == item and holder != null:
		return holder
	_shown[slot] = item
	if holder != null:
		holder.queue_free()
		holder = null
	if item == &"" or skeleton.find_bone(bone) == -1:
		return null
	holder = BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	holder.add_child(_build(item))
	return holder


func _build(item: StringName) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	match item:
		&"leather_hood":
			node.mesh = _dome(0.135, 0.1, 0.135, _mat(GoblinLook.LEATHER, Color(0.85, 0.7, 0.58)))
			node.position = HEAD_OFFSET
		&"skull_helm":
			node.mesh = _dome(0.14, 0.1, 0.145, PropLook.bone())
			node.position = HEAD_OFFSET + Vector3(0.0, 0.01, 0.0)
		&"fitted_helmet":
			node.mesh = _dome(0.138, 0.105, 0.14, _mat(GoblinLook.METAL, Color(0.75, 0.73, 0.7)))
			node.position = HEAD_OFFSET
		&"leather_vest":
			node.mesh = _band(0.135, 0.16, 0.16, _mat(GoblinLook.LEATHER, Color(0.7, 0.55, 0.44)))
			node.position = CHEST_OFFSET
		&"fitted_chest":
			node.mesh = _band(0.14, 0.165, 0.15, _mat(GoblinLook.METAL, Color(0.7, 0.68, 0.66)))
			node.position = CHEST_OFFSET
		&"hide_shield":
			node.mesh = _disc(0.15, 0.022)
			# O disco fica de pé, com a face para fora do braço.
			node.basis = Basis(Vector3.BACK, PI * 0.5)
			node.position = SHIELD_OFFSET
	return node


## Uma calota (meia esfera) do tamanho da cabeça: capuz e elmos.
static func _dome(radius_x: float, height: float, radius_z: float, material: Material) -> Mesh:
	var sphere := SphereMesh.new()
	sphere.is_hemisphere = true
	sphere.radius = 1.0
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(radius_x, height, radius_z)), Vector3.ZERO))
	st.set_material(material)
	return st.commit()


## Uma faixa em volta do peito (cilindro aberto, mais largo embaixo): gibão e peitoral.
static func _band(radius_top: float, radius_bottom: float, height: float, material: Material) -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_top
	cylinder.bottom_radius = radius_bottom
	cylinder.height = height
	cylinder.radial_segments = 10
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Achatado na frente e atrás, como o peito do goblin.
	st.append_from(cylinder, 0, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.78)), Vector3.ZERO))
	st.set_material(material)
	var mesh := st.commit()
	return mesh


## O escudo de galhos: um disco de madeira com a borda de couro.
static func _disc(radius: float, thickness: float) -> Mesh:
	var builder := TreeBuilder.Builder.new()
	var wood := builder.tool_for(_mat(preload("res://assets/textures/wood.png"), Color(0.85, 0.75, 0.62)))
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = thickness
	cylinder.radial_segments = 12
	wood.append_from(cylinder, 0, Transform3D.IDENTITY)
	var leather := builder.tool_for(_mat(GoblinLook.LEATHER, Color(0.8, 0.65, 0.5)))
	var rim := CylinderMesh.new()
	rim.top_radius = radius + 0.012
	rim.bottom_radius = radius + 0.012
	rim.height = thickness * 0.6
	rim.radial_segments = 12
	rim.cap_top = false
	rim.cap_bottom = false
	leather.append_from(rim, 0, Transform3D.IDENTITY)
	return builder.commit()


## Textura pixelada projetada dos três lados (a malha da peça não tem UV): couro, ferro, madeira.
static func _mat(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_scale = Vector3.ONE * 3.0
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

