class_name BowMesh
extends RefCounted
## Malhas do arco, da aljava e da flecha, montadas por código.
##
## Arco: em pé no eixo Y, empunhadura na origem, barriga para +Z e corda atrás.
## Flecha: ao longo de -Z (ponta em -Z), centro na origem.

const ARROW_LENGTH := 0.7

static var _arrow: ArrayMesh


static func build_bow() -> ArrayMesh:
	var builder := TreeBuilder.Builder.new()
	var wood := builder.tool_for(_material(preload("res://assets/textures/wood.png"), Color(0.85, 0.75, 0.65)))
	var radius := 0.5
	var points := []
	for i in 9:
		var angle := deg_to_rad(lerpf(-52.0, 52.0, i / 8.0))
		points.append(Vector3(0.0, radius * sin(angle), radius * (cos(angle) - 1.0)))
	for i in points.size() - 1:
		var from_center := absf(i - 3.5) / 3.5
		TreeBuilder.add_branch(wood, points[i], points[i + 1], lerpf(0.017, 0.008, from_center), lerpf(0.017, 0.008, absf(i + 1 - 3.5) / 3.5), 5)
	var grip := builder.tool_for(_material(preload("res://assets/textures/leather.png"), Color.WHITE))
	TreeBuilder.add_branch(grip, Vector3(0.0, -0.06, 0.0), Vector3(0.0, 0.06, 0.0), 0.021, 0.021, 6)
	var string := builder.tool_for(_flat(Color(0.75, 0.72, 0.65)))
	TreeBuilder.add_branch(string, points[0], points[-1], 0.003, 0.003, 3)
	return builder.commit()


static func build_quiver() -> ArrayMesh:
	var builder := TreeBuilder.Builder.new()
	var leather := builder.tool_for(_material(preload("res://assets/textures/leather.png"), Color.WHITE))
	TreeBuilder.add_branch(leather, Vector3(0.0, -0.22, 0.0), Vector3(0.0, 0.2, 0.0), 0.05, 0.055, 7)
	var shafts := builder.tool_for(_material(preload("res://assets/textures/wood.png"), Color.WHITE))
	var feathers := builder.tool_for(_flat(Color(0.7, 0.68, 0.62)))
	for i in 5:
		var offset := Vector3(cos(i * 1.3) * 0.025, 0.0, sin(i * 1.3) * 0.025)
		var top := Vector3(0.0, 0.3 + (i % 2) * 0.03, 0.0) + offset
		TreeBuilder.add_branch(shafts, offset + Vector3(0.0, 0.15, 0.0), top, 0.005, 0.005, 3)
		_add_fletching(feathers, top + Vector3(0.0, -0.08, 0.0), top, 0.018)
	return builder.commit()


## Malha da flecha (compartilhada por todas as flechas).
static func arrow() -> ArrayMesh:
	if _arrow != null:
		return _arrow
	var builder := TreeBuilder.Builder.new()
	var half := ARROW_LENGTH * 0.5
	var shaft := builder.tool_for(_material(preload("res://assets/textures/wood.png"), Color.WHITE))
	TreeBuilder.add_branch(shaft, Vector3(0.0, 0.0, half), Vector3(0.0, 0.0, -half), 0.006, 0.006, 4)
	var flint := builder.tool_for(_flat(Color(0.2, 0.2, 0.22)))
	TreeBuilder.add_branch(flint, Vector3(0.0, 0.0, -half), Vector3(0.0, 0.0, -half - 0.07), 0.013, 0.001, 4)
	var feathers := builder.tool_for(_flat(Color(0.7, 0.68, 0.62)))
	_add_fletching(feathers, Vector3(0.0, 0.0, half - 0.12), Vector3(0.0, 0.0, half - 0.01), 0.022)
	_arrow = builder.commit()
	return _arrow


## Três penas em volta de um eixo (de `from` até `to`), como cartões de dois lados.
static func _add_fletching(st: SurfaceTool, from: Vector3, to: Vector3, width: float) -> void:
	var axis := (to - from).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	for k in 3:
		var out := side.rotated(axis, TAU * k / 3.0) * width
		var corners := [from, from + out * 0.6, to + out, to]
		TreeBuilder.add_card(st, corners, [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
			[0.0, 0.0, 0.0, 0.0], [out.normalized(), out.normalized(), out.normalized(), out.normalized()])


static func _material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.85
	return material


static func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
