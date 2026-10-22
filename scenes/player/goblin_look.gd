class_name GoblinLook
extends RefCounted
## Veste o modelo do goblin no estilo do jogo: texturas pixeladas de pele, trapo e couro.
##
## O modelo vem do kit do blender-agent sem UV e com cores chapadas. Aqui cada malha
## ganha UV por projeção em caixa (no espaço de repouso, então a textura acompanha os
## ossos) e os materiais são trocados pelo nome da cor da paleta ("goblin.pele" etc.).

## Metros cobertos por uma repetição das texturas.
const TEXEL_SPAN := 0.32

const SKIN := preload("res://assets/textures/goblin_skin.png")
const CLOTH := preload("res://assets/textures/goblin_cloth.png")
const LEATHER := preload("res://assets/textures/leather.png")


static func apply(model: Node) -> void:
	var materials := {
		"pele": _textured(SKIN, Color(1.0, 1.0, 1.0)),
		"pele_escura": _textured(SKIN, Color(0.68, 0.7, 0.62)),
		"trapo": _textured(CLOTH, Color(1.0, 1.0, 1.0)),
		"trapo_escuro": _textured(CLOTH, Color(0.62, 0.6, 0.58)),
		"couro": _textured(LEATHER, Color(1.0, 1.0, 1.0)),
		"dente": _flat(Color(0.68, 0.64, 0.52)),
		"boca": _flat(Color(0.09, 0.05, 0.04)),
		"olho": _eye(),
	}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		instance.mesh = _with_box_uvs(instance.mesh as ArrayMesh, materials)


static func _with_box_uvs(source: ArrayMesh, materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs := PackedVector2Array()
		uvs.resize(vertices.size())
		# O kit é facetado (vértices separados por face), então a normal do vértice
		# já diz de qual lado projetar.
		for i in vertices.size():
			var v := vertices[i] / TEXEL_SPAN
			var n := normals[i].abs()
			if n.x >= n.y and n.x >= n.z:
				uvs[i] = Vector2(v.z, -v.y)
			elif n.y >= n.z:
				uvs[i] = Vector2(v.x, v.z)
			else:
				uvs[i] = Vector2(v.x, -v.y)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var flags := 0
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if weights != null and weights.size() == vertices.size() * 8:
			flags |= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var original := source.surface_get_material(surface)
		var key := original.resource_name.get_slice(".", 1) if original != null else ""
		mesh.surface_set_material(surface, materials.get(key, original))
	return mesh


static func _textured(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.9
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
