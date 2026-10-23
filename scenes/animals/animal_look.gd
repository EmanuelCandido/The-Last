class_name AnimalLook
extends RefCounted
## Veste os modelos dos bichos (assets/models/animals/*.glb) no estilo do jogo.
##
## O modelo vem com uma cor chapada por região ("bicho.pelo", "bicho.claro"...). Cada espécie
## passa uma paleta: região -> [textura, tinta] (pelo, cerda, pena: animal_skin.gdshader, que
## projeta a textura pixelada na pose de repouso, como no goblin) ou uma Color (material liso:
## olho, casco, focinho). Os materiais e a malha com os atributos de repouso são feitos uma vez
## por espécie e divididos entre todos os bichos dela.

const SHADER := preload("res://assets/shaders/animal_skin.gdshader")
const PELT := preload("res://assets/textures/pelt.png")
const BRISTLE := preload("res://assets/textures/bristle.png")
const PLUMAGE := preload("res://assets/textures/plumage.png")

## Metros cobertos por uma repetição da textura (o pelo dos bichos é mais grosso que a pele do goblin).
const TEXEL_SPAN := 0.36

static var _meshes := {}


## Malha de `source` com posição e normal de repouso nos atributos e os materiais da paleta.
## `key` identifica a espécie + paleta (para dividir o resultado entre os bichos iguais).
static func dressed(key: String, source: ArrayMesh, palette: Dictionary) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var materials := {}
	for region: String in palette:
		materials[region] = _material(palette[region])
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs := PackedVector2Array()
		var uvs2 := PackedVector2Array()
		var colors := PackedColorArray()
		uvs.resize(vertices.size())
		uvs2.resize(vertices.size())
		colors.resize(vertices.size())
		for i in vertices.size():
			var v := vertices[i]
			var n := normals[i] * 0.5 + Vector3(0.5, 0.5, 0.5)
			uvs[i] = Vector2(v.x, v.y)
			uvs2[i] = Vector2(v.z, 0.0)
			colors[i] = Color(n.x, n.y, n.z)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uvs2
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags := 0
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if weights != null and weights.size() == vertices.size() * 8:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var original := source.surface_get_material(surface)
		var region := original.resource_name.get_slice(".", 1) if original != null else ""
		mesh.surface_set_material(surface, materials.get(region, original))
	_meshes[key] = mesh
	return mesh


## [textura, tinta] ou [textura, tinta, brilho] -> pelo pixelado; Color -> liso.
static func _material(entry: Variant) -> Material:
	if entry is Material:
		return entry
	if entry is Color:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = entry
		flat.roughness = 0.45 if (entry as Color).v < 0.15 else 0.8
		return flat
	var spec: Array = entry
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"albedo_texture", spec[0])
	material.set_shader_parameter(&"tint", spec[1])
	material.set_shader_parameter(&"texel_span", TEXEL_SPAN)
	if spec.size() > 2:
		material.set_shader_parameter(&"emission_color", spec[1])
		material.set_shader_parameter(&"emission_energy", spec[2])
	return material


## Olhos que brilham no escuro (a luz voltando da retina, como nos lobos).
static func glowing_eye(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color * 0.25
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
