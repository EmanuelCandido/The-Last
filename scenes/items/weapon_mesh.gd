class_name WeaponMesh
extends RefCounted
## Malhas das armas de mão (F11), montadas por código como o arco: cabo no punho, na origem, e a
## arma ao longo de +Y (a ponta em +Y). A lança tem o cabo para trás do punho também: a mão de trás
## segura a 30% do comprimento. Texturas pixeladas (madeira, couro, rocha, osso), nada chapado.

## Onde a mão segura a lança, em fração do comprimento a partir do pé.
const SPEAR_GRIP := 0.3
## Arma de uma mão: o cabo sai do punho este ângulo (rad) acima do antebraço, como com o pulso
## dobrado de quem segura a faca para a frente (a 90°, punho reto, a faca apontava para o rosto).
const ONE_HAND_TILT := 0.65

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
		&"orc_axe":
			# Cabo de pau escuro e uma lâmina de ferro batido, larga e torta, presa por tiras.
			TreeBuilder.add_branch(wood, Vector3(0.0, -0.06, 0.0), Vector3(0.0, length, 0.0), 0.018, 0.016, 6)
			TreeBuilder.add_branch(leather, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.08, 0.0), 0.021, 0.021, 6)
			var iron := builder.tool_for(_material(preload("res://assets/textures/metal.png"), Color(0.62, 0.6, 0.58)))
			var head := Vector3(0.0, length - 0.1, 0.0)
			_tri(iron, head + Vector3(0.0, 0.07, 0.0), head + Vector3(0.0, -0.05, 0.0), head + Vector3(0.0, 0.0, 0.16))
			_tri(iron, head + Vector3(0.0, 0.07, 0.0), head + Vector3(0.0, 0.0, 0.16), head + Vector3(0.0, 0.11, 0.17))
			_tri(iron, head + Vector3(0.0, -0.05, 0.0), head + Vector3(0.0, -0.06, 0.15), head + Vector3(0.0, 0.0, 0.16))
			TreeBuilder.add_branch(leather, head + Vector3(0.0, -0.04, 0.0), head + Vector3(0.0, 0.06, 0.0), 0.022, 0.022, 6)
		&"orc_sword":
			# Uma lâmina larga e reta de ferro, gasta, com a ponta quebrada, e o punho de couro.
			TreeBuilder.add_branch(leather, Vector3(0.0, -0.07, 0.0), Vector3(0.0, 0.07, 0.0), 0.017, 0.017, 6)
			# O pomo é um nó de madeira (toda superfície criada precisa de algo, senão a malha reclama).
			TreeBuilder.add_branch(wood, Vector3(0.0, -0.1, 0.0), Vector3(0.0, -0.07, 0.0), 0.024, 0.02, 6)
			var guard := builder.tool_for(_material(preload("res://assets/textures/metal.png"), Color(0.5, 0.48, 0.46)))
			TreeBuilder.add_branch(guard, Vector3(-0.06, 0.075, 0.0), Vector3(0.06, 0.075, 0.0), 0.012, 0.012, 5)
			_add_blade(builder.tool_for(_material(preload("res://assets/textures/metal.png"), Color(0.66, 0.65, 0.63))),
				Vector3(0.0, 0.08, 0.0), length - 0.08, 0.035, 0.006)
	var mesh := builder.commit()
	_cache[item] = mesh
	return mesh


## Põe `weapon` (a malha de `item`) na mão direita no mesmo quadro da pose. Com uma mão, o cabo sai
## do punho ONE_HAND_TILT acima do antebraço; com duas (a lança), vai da mão direita para a
## esquerda. `visual` dá o lado do corpo. Devolve o eixo da arma (da mão para a ponta).
static func hold(weapon: Node3D, item: StringName, animator: GoblinAnimator, visual: Node3D) -> Vector3:
	var grip := animator.weapon_grip_position()
	var side := visual.global_basis.x.normalized()
	var axis: Vector3
	if Weapons.two_handed(item) and Weapons.style_of(item) == &"spear":
		axis = animator.hand_position(true) - grip
		if axis.length() < 0.06:
			axis = visual.global_basis.z.normalized()
	else:
		axis = animator.forearm_direction(false).rotated(side, -ONE_HAND_TILT)
	axis = axis.normalized()
	var x := side - axis * side.dot(axis)
	if x.length_squared() < 0.0001:
		x = visual.global_basis.z.normalized().cross(axis)
	x = x.normalized()
	# A malha pode estar escalada (o orc): a base guarda a escala do pai.
	var scale := visual.global_basis.get_scale()
	weapon.global_transform = Transform3D(Basis(x, axis, x.cross(axis).normalized()).scaled(scale), grip)
	return axis


## Por onde a lâmina passa: [começo, ponta] no mundo, com a arma em `grip` e o eixo `axis`.
static func blade(item: StringName, grip: Vector3, axis: Vector3, scale := 1.0) -> Array[Vector3]:
	var length: float = Weapons.spec(item).get("length", 0.3) * scale
	if Weapons.style_of(item) == &"spear":
		var ahead := length * (1.0 - SPEAR_GRIP)
		return [grip + axis * ahead * 0.35, grip + axis * ahead]
	return [grip + axis * 0.04 * scale, grip + axis * length]


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
