class_name GoblinLook
extends RefCounted
## Veste o modelo do goblin no estilo do jogo: texturas pixeladas de pele, trapo e couro.
##
## O modelo vem com cores chapadas por nome da paleta ("goblin.pele" etc.). Aqui os
## materiais com textura viram o goblin_skin.gdshader, que projeta a textura dos três
## lados e mistura pela normal: sem as emendas que a projeção em caixa por face deixava
## como linhas na pele. Posição e normal de repouso vão nos atributos do vértice, então
## a textura acompanha os ossos.

## Metros cobertos por uma repetição das texturas.
const TEXEL_SPAN := 0.32

const SHADER := preload("res://assets/shaders/goblin_skin.gdshader")
const SKIN := preload("res://assets/textures/goblin_skin.png")
const CLOTH := preload("res://assets/textures/goblin_cloth.png")
const LEATHER := preload("res://assets/textures/leather.png")
const METAL := preload("res://assets/textures/metal.png")


## `tints` troca a tinta de uma parte da paleta (o orc, F12: {"pele": cor, ...}); `span` é o
## tamanho de uma repetição da textura no espaço do modelo (o orc é escalado no nó: menor aqui).
static func apply(model: Node, tints := {}, span := TEXEL_SPAN) -> void:
	var materials := {
		"pele": _textured(SKIN, tints.get("pele", Color(1.0, 1.0, 1.0)), span),
		"pele_escura": _textured(SKIN, tints.get("pele_escura", Color(0.68, 0.7, 0.62)), span),
		"trapo": _textured(CLOTH, tints.get("trapo", Color(1.0, 1.0, 1.0)), span),
		"trapo_escuro": _textured(CLOTH, tints.get("trapo_escuro", Color(0.62, 0.6, 0.58)), span),
		"couro": _textured(LEATHER, tints.get("couro", Color(1.0, 1.0, 1.0)), span),
		# O ferro: a fivela do goblin e, no orc (F12), o elmo e o peitoral.
		"metal": _textured(METAL, tints.get("metal", Color(0.7, 0.68, 0.66)), span),
		"dente": _flat(Color(0.68, 0.64, 0.52)),
		"boca": _flat(Color(0.09, 0.05, 0.04)),
		"olho": _eye(),
	}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		instance.mesh = _with_rest_attributes(instance.mesh as ArrayMesh, materials)


static func _with_rest_attributes(source: ArrayMesh, materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		# UV = (x, y) e UV2 = (z, 0) da posição de repouso; COLOR = normal de repouso.
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
		var key := original.resource_name.get_slice(".", 1) if original != null else ""
		mesh.surface_set_material(surface, materials.get(key, original))
	return mesh


static func _textured(texture: Texture2D, tint: Color, span := TEXEL_SPAN) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"texel_span", span)
	return material


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	return material


## Olhos âmbar com um brilho fraco: aparecem no escuro da caverna.
static func _eye() -> StandardMaterial3D:
	var material := _flat(Color(0.8, 0.6, 0.18))
	material.emission_enabled = true
	material.emission = Color(0.95, 0.62, 0.15)
	material.emission_energy_multiplier = 0.7
	return material
