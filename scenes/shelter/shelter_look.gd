class_name ShelterLook
extends RefCounted
## Materiais e peças do Abrigo 9 (§6.1): concreto, chapa pintada, plástico, vidro e as luzes
## que brilham. Mesmo estilo da floresta (texturas pixeladas, filtro nearest), sem neblina.
## Os materiais são criados uma vez e reaproveitados por todas as peças.

const TEXTURES := {
	&"concrete": preload("res://assets/textures/concrete.png"),
	&"floor": preload("res://assets/textures/concrete_floor.png"),
	&"metal": preload("res://assets/textures/metal.png"),
}

static var _materials := {}


## Material pelo nome: "concrete", "floor", "ceiling", "metal", "dark_metal", "plastic",
## "cloth", "blanket", "skin", "rubber", "glass", "paper" e as luzes "green", "red", "amber",
## "white" e "screen".
static func material(name: StringName) -> Material:
	if _materials.has(name):
		return _materials[name]
	var made := StandardMaterial3D.new()
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	match name:
		&"concrete":
			_triplanar(made, TEXTURES[&"concrete"], 0.5)
		&"floor":
			_triplanar(made, TEXTURES[&"floor"], 0.5)
		&"ceiling":
			_triplanar(made, TEXTURES[&"concrete"], 0.6)
			made.albedo_color = Color(0.7, 0.72, 0.7)
		&"metal":
			_triplanar(made, TEXTURES[&"metal"], 1.5)
			made.metallic = 0.3
			made.roughness = 0.6
		&"dark_metal":
			_triplanar(made, TEXTURES[&"metal"], 1.5)
			made.albedo_color = Color(0.35, 0.36, 0.35)
			made.metallic = 0.5
			made.roughness = 0.5
		&"plastic":
			made.albedo_color = Color(0.68, 0.67, 0.6)
			made.roughness = 0.45
		&"cloth":
			made.albedo_color = Color(0.36, 0.42, 0.44)
			made.roughness = 1.0
		&"blanket":
			made.albedo_color = Color(0.45, 0.5, 0.43)
			made.roughness = 1.0
		&"skin":
			# A mão de quem não vê o sol há onze anos.
			made.albedo_color = Color(0.78, 0.7, 0.64)
			made.roughness = 0.7
			made.subsurf_scatter_enabled = true
			made.subsurf_scatter_strength = 0.3
		&"rubber":
			made.albedo_color = Color(0.06, 0.06, 0.06)
			made.roughness = 0.9
		&"paper":
			made.albedo_color = Color(0.72, 0.7, 0.62)
			made.roughness = 1.0
		&"glass":
			made.albedo_color = Color(0.6, 0.72, 0.7, 0.18)
			made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			made.roughness = 0.05
			made.metallic_specular = 0.9
			made.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"green", &"red", &"amber", &"white", &"screen":
			var colors := {
				&"green": Color(0.35, 1.0, 0.5), &"red": Color(1.0, 0.18, 0.12),
				&"amber": Color(1.0, 0.62, 0.18), &"white": Color(0.85, 0.92, 0.95),
				&"screen": Color(0.2, 0.32, 0.3),
			}
			made.albedo_color = Color(0.05, 0.05, 0.05)
			made.emission_enabled = true
			made.emission = colors[name]
			made.emission_energy_multiplier = 0.6 if name == &"screen" else 3.0
		_:
			push_warning("ShelterLook: material desconhecido '%s'." % name)
	_materials[name] = made
	return made


## Solta os materiais guardados (o Abrigo saiu da árvore; senão sobram no fim do jogo).
static func release() -> void:
	_materials.clear()


## Uma luz que pisca precisa do próprio material (o brilho muda sozinho).
static func light_material(name: StringName) -> StandardMaterial3D:
	return (material(name) as StandardMaterial3D).duplicate()


## Caixa com `size`, centrada em `center` (no espaço de `parent`).
static func box(parent: Node3D, size: Vector3, center: Vector3, material_name: StringName, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, center, rotation, material_name)


static func cylinder(parent: Node3D, radius: float, height: float, center: Vector3, material_name: StringName, rotation := Vector3.ZERO, sides := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _instance(parent, mesh, center, rotation, material_name)


## Bastão de `a` até `b` (tubos, cabos, braços).
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material_name: StringName, sides := 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := _instance(parent, mesh, (a + b) * 0.5, Vector3.ZERO, material_name)
	var along := (b - a).normalized()
	var side := along.cross(Vector3.FORWARD if absf(along.y) > 0.9 else Vector3.UP).normalized()
	instance.basis = Basis(side, along, side.cross(along))
	return instance


static func sphere(parent: Node3D, radius: float, center: Vector3, material_name: StringName) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _instance(parent, mesh, center, Vector3.ZERO, material_name)


## Texto pintado na parede ou aceso numa tela.
static func label(parent: Node3D, text: String, center: Vector3, size: float, color: Color, glowing := false, yaw := 0.0) -> Label3D:
	var label3d := Label3D.new()
	label3d.text = text
	label3d.position = center
	label3d.rotation.y = yaw
	label3d.font_size = 32
	label3d.pixel_size = size / 32.0
	label3d.modulate = color
	label3d.outline_size = 0
	label3d.shaded = not glowing
	label3d.double_sided = false
	label3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label3d.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(label3d)
	return label3d


static func _instance(parent: Node3D, mesh: Mesh, center: Vector3, rotation: Vector3, material_name: StringName) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.rotation = rotation
	instance.material_override = material(material_name)
	parent.add_child(instance)
	return instance


static func _triplanar(made: StandardMaterial3D, texture: Texture2D, scale: float) -> void:
	made.albedo_texture = texture
	made.uv1_triplanar = true
	made.uv1_world_triplanar = true
	made.uv1_scale = Vector3.ONE * scale
	made.roughness = 0.9
