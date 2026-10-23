class_name MeatMesh
extends RefCounted
## Pedaço de carne que aparece na mão do goblin ao comer e ao assar, montado por código.

const RAW_COLOR := Color(0.55, 0.17, 0.14)
const COOKED_COLOR := Color(0.33, 0.18, 0.09)

static var _mesh: SphereMesh


## Um pedaço de carne (material próprio, para poder mudar de cor enquanto assa).
static func instance(cooked: bool) -> MeshInstance3D:
	if _mesh == null:
		# Poucas faces e achatado: um naco torto, no estilo pixelado do resto.
		_mesh = SphereMesh.new()
		_mesh.radius = 0.055
		_mesh.height = 0.08
		_mesh.radial_segments = 7
		_mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = COOKED_COLOR if cooked else RAW_COLOR
	material.roughness = 0.75
	var meat := MeshInstance3D.new()
	meat.mesh = _mesh
	meat.material_override = material
	meat.scale = Vector3(1.25, 0.85, 1.0)
	meat.rotation = Vector3(0.4, 0.3, 0.2)
	return meat


## Escurece a carne de crua para assada em `seconds` segundos.
static func cook(meat: MeshInstance3D, seconds: float) -> void:
	var material := meat.material_override as StandardMaterial3D
	meat.create_tween().tween_property(material, "albedo_color", COOKED_COLOR, seconds)
