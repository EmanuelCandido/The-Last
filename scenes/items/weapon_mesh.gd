class_name WeaponMesh
extends RefCounted
## Malhas das armas de mão (F11), montadas por código como o arco: cabo no punho, na origem, e a
## arma ao longo de +Y (a ponta em +Y). A lança tem o cabo para trás do punho também: a mão de trás
## segura a 30% do comprimento. Texturas pixeladas (madeira, couro, rocha, osso), nada chapado.

## Onde a mão segura a lança, em fração do comprimento a partir do pé.
const SPEAR_GRIP := 0.3

static var _cache := {}


static func build(item: StringName) -> ArrayMesh:
	if _cache.has(item):
		return _cache[item]
	var length: float = Weapons.spec(item).get("length", 0.3)
	var builder := TreeBuilder.Builder.new()
	var wood := builder.tool_for(_material(preload("res://assets/textures/wood.png"), Color(0.9, 0.82, 0.7)))
	var leather := builder.tool_for(_material(preload("res://assets/textures/leather.png"), Color.WHITE))
	match item:
		&"stone_knife":
			TreeBuilder.add_branch(wood, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.05, 0.0), 0.013, 0.012, 5)
			TreeBuilder.add_branch(leather, Vector3(0.0, 0.035, 0.0), Vector3(0.0, 0.06, 0.0), 0.016, 0.016, 5)
			_add_blade(builder.tool_for(_material(preload("res://assets/textures/rock.png"), Color(0.62, 0.62, 0.66))),
				Vector3(0.0, 0.06, 0.0), length - 0.06, 0.022, 0.007)
		&"bone_knife":
			var bone := builder.tool_for(PropLook.bone())
			TreeBuilder.add_branch(leather, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.05, 0.0), 0.014, 0.013, 5)
			_add_blade(bone, Vector3(0.0, 0.05, 0.0), length - 0.05, 0.018, 0.006)
		&"club":
			# Um galho grosso e torto, mais largo na cabeça, com uma pedra amarrada.
			var rng := RandomNumberGenerator.new()
			rng.seed = 2714
			var points := TreeBuilder.crooked_line(rng, Vector3(0.0, -0.06, 0.0), Vector3.UP, length, 4, 0.02)
			for i in points.size() - 1:
				var t := float(i) / (points.size() - 1)
				TreeBuilder.add_branch(wood, points[i], points[i + 1], lerpf(0.016, 0.03, t), lerpf(0.016, 0.03, t + 1.0 / (points.size() - 1)), 6)
			TreeBuilder.add_branch(leather, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.05, 0.0), 0.019, 0.019, 6)
			var stone := builder.tool_for(_material(preload("res://assets/textures/rock.png"), Color(0.7, 0.68, 0.66)))
			var head: Vector3 = points[points.size() - 2]
			TreeBuilder.add_branch(stone, head + Vector3(-0.035, 0.0, 0.0), head + Vector3(0.04, 0.02, 0.0), 0.034, 0.028, 5)
			TreeBuilder.add_branch(leather, head + Vector3(0.0, -0.03, 0.0), head + Vector3(0.0, 0.03, 0.0), 0.033, 0.033, 6)
		&"spear":
			var foot := -length * SPEAR_GRIP
			TreeBuilder.add_branch(wood, Vector3(0.0, foot, 0.0), Vector3(0.0, length + foot - 0.1, 0.0), 0.012, 0.01, 5)
			TreeBuilder.add_branch(leather, Vector3(0.0, length + foot - 0.13, 0.0), Vector3(0.0, length + foot - 0.08, 0.0), 0.015, 0.015, 5)
			_add_blade(builder.tool_for(_material(preload("res://assets/textures/rock.png"), Color(0.6, 0.6, 0.64))),
				Vector3(0.0, length + foot - 0.1, 0.0), 0.12, 0.024, 0.008)
	var mesh := builder.commit()
	_cache[item] = mesh
	return mesh


## Uma lâmina lascada: losango achatado de `from` até `length` acima, larga `width`, grossa `thick`.
static func _add_blade(st: SurfaceTool, from: Vector3, length: float, width: float, thick: float) -> void:
	var tip := from + Vector3(0.0, length, 0.0)
	var shoulder := from + Vector3(0.0, length * 0.3, 0.0)
	var ring := [Vector3(width, 0.0, 0.0), Vector3(0.0, 0.0, thick), Vector3(-width * 0.85, 0.0, 0.0), Vector3(0.0, 0.0, -thick)]
	for i in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % ring.size()]
		_tri(st, from + a * 0.5, from + b * 0.5, shoulder + b)
		_tri(st, from + a * 0.5, shoulder + b, shoulder + a)
		_tri(st, shoulder + a, shoulder + b, tip)


## Triângulo de dois lados (a lâmina é fina: o verso também aparece).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for points: Array in [[a, b, c], [a, c, b]]:
		var n := normal if points[1] == b else -normal
		for k in 3:
			var p: Vector3 = points[k]
			st.set_normal(n)
			st.set_uv(Vector2(p.x * 8.0 + 0.5, p.y * 4.0))
			st.add_vertex(p)


static func _material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.85
	return material
