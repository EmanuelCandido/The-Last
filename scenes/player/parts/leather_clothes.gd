class_name LeatherClothes
extends Node
## Roupa de couro (§4.6 e §4.10), só o visual: com o item `clothes`, o goblin ganha um manto
## curto de pele nos ombros (preso ao osso do peito) e o trapo vira couro curtido. O efeito
## no frio fica no ColdExposure. Vestida para sempre.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira o visual.

## Couro da roupa: mais escuro e avermelhado que o do cinto, para se ver que é novo.
const TINT := Color(0.78, 0.6, 0.48)
const FUR_COLOR := Color(0.72, 0.64, 0.52)
## Osso que leva o manto e onde ele fica no espaço do osso (Y sobe pela coluna).
const MANTLE_BONE := "peito"
const MANTLE_OFFSET := Vector3(0.0, 0.07, -0.005)

var _worn := false
var _mantle: BoneAttachment3D

@onready var _player: Player = get_parent()


func _ready() -> void:
	Inventory.changed.connect(func(item: StringName, _amount: int) -> void:
		if item == &"clothes":
			_update())
	_update.call_deferred()


func _update() -> void:
	var wear := Inventory.has(&"clothes")
	var skeleton := _player.skeleton()
	if wear == _worn or skeleton == null:
		return
	_worn = wear
	var leather := GoblinLook._textured(GoblinLook.LEATHER, TINT)
	for node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.get_parent() is BoneAttachment3D:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as ShaderMaterial
			if material != null and material.get_shader_parameter(&"albedo_texture") == GoblinLook.CLOTH:
				mesh_instance.set_surface_override_material(surface, leather if wear else null)
	if wear and _mantle == null and skeleton.find_bone(MANTLE_BONE) != -1:
		_mantle = BoneAttachment3D.new()
		_mantle.bone_name = MANTLE_BONE
		skeleton.add_child(_mantle)
		_mantle.add_child(_build_mantle())
	if _mantle != null:
		_mantle.visible = wear


## Manto de pele: um cone baixo e aberto em volta dos ombros, com a borda franjada.
func _build_mantle() -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.07
	cone.bottom_radius = 0.17
	cone.height = 0.11
	cone.radial_segments = 9
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var fur := StandardMaterial3D.new()
	fur.albedo_texture = preload("res://assets/textures/fur.png")
	fur.albedo_color = FUR_COLOR
	fur.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	fur.uv1_triplanar = true
	fur.uv1_scale = Vector3.ONE * 5.0
	fur.cull_mode = BaseMaterial3D.CULL_DISABLED
	fur.roughness = 1.0
	var mantle := MeshInstance3D.new()
	mantle.name = "Mantle"
	mantle.mesh = cone
	mantle.material_override = fur
	mantle.position = MANTLE_OFFSET
	# Um pouco mais largo de ombro a ombro que de frente para trás.
	mantle.scale = Vector3(1.15, 1.0, 0.9)
	return mantle
