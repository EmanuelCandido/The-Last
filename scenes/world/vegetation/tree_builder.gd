class_name TreeBuilder
extends RefCounted
## Monta as malhas da vegetação por código: pinheiro, árvore morta, árvore velha,
## tufo de grama, samambaia, pedra e tronco caído.
##
## Convenções das malhas:
## - base no Y = 0, crescendo para +Y;
## - superfícies separadas por material (casca, folhagem);
## - folhagem leva o peso do balanço do vento no canal R da cor do vértice;
## - árvores guardam o raio do tronco na base em get_meta("trunk_radius") (colisão).

const UP := Vector3.UP


## Acumula superfícies por material e monta a ArrayMesh no fim.
class Builder:
	var _tools := {}

	func tool_for(material: Material) -> SurfaceTool:
		if not _tools.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[material] = st
		return _tools[material]

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for material: Material in _tools:
			var st: SurfaceTool = _tools[material]
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		return mesh


## Cilindro afunilado de a até b, com UV de casca (v repete a cada 2 m).
static func add_branch(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, v0 := 0.0) -> float:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	var v1 := v0 + a.distance_to(b) / 2.0
	# Avança um pouco além de b: nas dobras do galho os anéis não coincidem e abririam fresta.
	b += axis * minf(0.15, a.distance_to(b) * 0.06)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := side * cos(a0) + other * sin(a0)
		var d1 := side * cos(a1) + other * sin(a1)
		var u0 := float(k) / sides
		var u1 := float(k + 1) / sides
		var quad := [
			[a + d0 * r0, d0, Vector2(u0, v0)], [b + d0 * r1, d0, Vector2(u0, v1)],
			[a + d1 * r0, d1, Vector2(u1, v0)], [b + d1 * r1, d1, Vector2(u1, v1)],
		]
		# Sentido horário visto de fora (face da frente para fora do galho).
		for idx: int in [0, 1, 2, 1, 3, 2]:
			st.set_normal(quad[idx][1])
			st.set_uv(quad[idx][2])
			st.add_vertex(quad[idx][0])
	return v1


## Cartão retangular (dois triângulos) com cor de vértice R = peso do balanço.
static func add_card(st: SurfaceTool, corners: Array, uvs: Array, sway: Array, normals: Array) -> void:
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normals[idx])
		st.set_color(Color(sway[idx], 0.0, 0.0))
		st.set_uv(uvs[idx])
		st.add_vertex(corners[idx])


## Tronco torto: lista de pontos subindo com desvios aleatórios.
static func crooked_line(rng: RandomNumberGenerator, start: Vector3, direction: Vector3, length: float, segments: int, wobble: float) -> Array:
	var points := [start]
	var dir := direction.normalized()
	var step := length / segments
	for i in segments:
		dir = (dir + Vector3(rng.randf_range(-wobble, wobble), 0.0, rng.randf_range(-wobble, wobble))).normalized()
		points.append(points[-1] + dir * step)
	return points


static func build_pine(rng: RandomNumberGenerator, bark: Material, needles: Material) -> ArrayMesh:
	var builder := Builder.new()
	var height := rng.randf_range(11.0, 17.0)
	var radius := height * rng.randf_range(0.016, 0.022)
	var trunk := crooked_line(rng, Vector3.ZERO, UP, height, 4, 0.04)
	var bark_st := builder.tool_for(bark)
	var v := 0.0
	for i in trunk.size() - 1:
		var r0 := radius * (1.0 - float(i) / (trunk.size() - 1) * 0.85)
		var r1 := radius * (1.0 - float(i + 1) / (trunk.size() - 1) * 0.85)
		v = add_branch(bark_st, trunk[i], trunk[i + 1], r0, r1, 7, v)

	var leaf_st := builder.tool_for(needles)
	var crown_start := height * rng.randf_range(0.22, 0.38)
	var crown_center := Vector3(0.0, (crown_start + height) * 0.5, 0.0)
	var y := crown_start
	while y < height - 0.3:
		var frac := (y - crown_start) / (height - crown_start)
		var count := rng.randi_range(5, 7)
		var turn := rng.randf() * TAU
		for b in count:
			var angle := turn + TAU * b / count + rng.randf_range(-0.25, 0.25)
			var length := lerpf(3.2, 0.5, frac) * rng.randf_range(0.8, 1.15) * height / 14.0
			var droop := lerpf(0.45, 0.15, frac) + rng.randf_range(-0.1, 0.1)
			var dir := Vector3(cos(angle), -droop, sin(angle)).normalized()
			var base := _point_on_line(trunk, y / height)
			_add_branch_cards(leaf_st, base, dir, length, length * 0.55, frac, crown_center)
		y += rng.randf_range(0.45, 0.65)
	# Ponta do pinheiro: dois cartões verticais cruzados.
	var tip := _point_on_line(trunk, 1.0)
	for k in 2:
		var side := Vector3(cos(k * PI * 0.5), 0.0, sin(k * PI * 0.5)) * 0.45
		var top := tip + UP * 1.4
		add_card(leaf_st, [tip - side - UP * 0.6, tip + side - UP * 0.6, top + side * 0.2, top - side * 0.2],
			[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [0.4, 0.4, 1.0, 1.0], [UP, UP, UP, UP])
	var mesh := builder.commit()
	mesh.set_meta("trunk_radius", radius)
	return mesh


static func build_dead_tree(rng: RandomNumberGenerator, bark: Material) -> ArrayMesh:
	var builder := Builder.new()
	var st := builder.tool_for(bark)
	var height := rng.randf_range(6.0, 10.0)
	var radius := rng.randf_range(0.18, 0.3)
	var trunk := crooked_line(rng, Vector3.ZERO, UP, height, 5, 0.12)
	var v := 0.0
	for i in trunk.size() - 1:
		var r0 := radius * (1.0 - float(i) / trunk.size() * 0.8)
		var r1 := radius * (1.0 - float(i + 1) / trunk.size() * 0.8)
		v = add_branch(st, trunk[i], trunk[i + 1], r0, r1, 6, v)
	for b in rng.randi_range(4, 7):
		var t := rng.randf_range(0.4, 0.95)
		var start := _point_on_line(trunk, t)
		var angle := rng.randf() * TAU
		var dir := Vector3(cos(angle), rng.randf_range(0.5, 1.4), sin(angle)).normalized()
		var length := rng.randf_range(1.5, 3.5) * (1.2 - t * 0.5)
		var r := radius * (1.0 - t * 0.8) * 0.6
		var limb := crooked_line(rng, start, dir, length, 2, 0.25)
		for i in limb.size() - 1:
			add_branch(st, limb[i], limb[i + 1], r * (1.0 - i * 0.4), r * (0.6 - i * 0.3), 5)
		for twig in rng.randi_range(1, 3):
			var twig_start := _point_on_line(limb, rng.randf_range(0.4, 1.0))
			var twig_dir := (dir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.1, 0.6), rng.randf_range(-0.8, 0.8))).normalized()
			add_branch(st, twig_start, twig_start + twig_dir * rng.randf_range(0.6, 1.4), r * 0.35, 0.01, 4)
	var mesh := builder.commit()
	mesh.set_meta("trunk_radius", radius)
	return mesh


## Árvore velha: tronco grosso com raízes, galhos largos e copa rala de folhas de outono.
static func build_old_tree(rng: RandomNumberGenerator, bark: Material, leaves: Material) -> ArrayMesh:
	var builder := Builder.new()
	var bark_st := builder.tool_for(bark)
	var leaf_st := builder.tool_for(leaves)
	var trunk := crooked_line(rng, Vector3.ZERO, UP, 4.6, 4, 0.12)
	var radii := [0.95, 0.72, 0.62, 0.55, 0.48]
	var v := 0.0
	for i in trunk.size() - 1:
		v = add_branch(bark_st, trunk[i], trunk[i + 1], radii[i], radii[i + 1], 10, v)
	for r in 5:
		var angle := TAU * r / 5 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		add_branch(bark_st, out * 0.3 + UP * 0.9, out * 1.7 + UP * -0.3, 0.32, 0.08, 6)

	var crown_center := Vector3(0.0, 7.5, 0.0)
	for l in 6:
		var angle := TAU * l / 6 + rng.randf_range(-0.35, 0.35)
		var start := _point_on_line(trunk, rng.randf_range(0.7, 1.0))
		var dir := Vector3(cos(angle), rng.randf_range(0.6, 1.1), sin(angle)).normalized()
		var limb := crooked_line(rng, start, dir, rng.randf_range(4.0, 6.0), 3, 0.3)
		for i in limb.size() - 1:
			add_branch(bark_st, limb[i], limb[i + 1], 0.38 - i * 0.1, 0.28 - i * 0.09, 7)
		for s in rng.randi_range(3, 4):
			var sub_start := _point_on_line(limb, rng.randf_range(0.35, 1.0))
			var sub_dir := (dir + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.9, 0.9))).normalized()
			var sub_end := sub_start + sub_dir * rng.randf_range(1.8, 3.0)
			add_branch(bark_st, sub_start, sub_end, 0.1, 0.03, 5)
			for c in rng.randi_range(1, 3):
				var center := sub_start.lerp(sub_end, rng.randf_range(0.5, 1.0)) + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.4), rng.randf_range(-0.5, 0.5))
				_add_leaf_cluster(leaf_st, rng, center, rng.randf_range(1.4, 2.3), crown_center)
	return builder.commit()


## Tufo de grama: três cartões cruzados de 1 m (a escala vem da instância).
static func build_grass_clump(grass: Material) -> ArrayMesh:
	var builder := Builder.new()
	var st := builder.tool_for(grass)
	for k in 3:
		var angle := PI * k / 3.0
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.5
		add_card(st, [-side, -side + UP, side + UP, side],
			[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)], [0.0, 1.0, 1.0, 0.0], [UP, UP, UP, UP])
	return builder.commit()


## Samambaia: frondes do cartão de pinheiro saindo do centro e arqueando.
static func build_fern(rng: RandomNumberGenerator, fronds: Material) -> ArrayMesh:
	var builder := Builder.new()
	var st := builder.tool_for(fronds)
	for f in 8:
		var angle := TAU * f / 8 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.22
		var length := rng.randf_range(0.7, 1.1)
		var mid := dir * length * 0.55 + UP * rng.randf_range(0.35, 0.55)
		var tip := dir * length + UP * rng.randf_range(0.1, 0.25)
		add_card(st, [-side * 0.3, mid - side, mid + side, side * 0.3],
			[Vector2(0, 0), Vector2(0.55, 0), Vector2(0.55, 1), Vector2(0, 1)], [0.0, 0.6, 0.6, 0.0], [UP, UP, UP, UP])
		add_card(st, [mid - side, tip - side * 0.4, tip + side * 0.4, mid + side],
			[Vector2(0.55, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.55, 1)], [0.6, 1.0, 1.0, 0.6], [UP, UP, UP, UP])
	return builder.commit()


## Pedra: esfera deformada por ruído, achatada na base.
static func build_rock(rng: RandomNumberGenerator, rock: Material) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 7
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stretch := Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.3))
	var builder := Builder.new()
	var st := builder.tool_for(rock)
	for idx in indices:
		var p := verts[idx].normalized()
		var bump := 1.0 + noise.get_noise_3dv(p * 2.0) * 0.35
		var q := p * bump * stretch
		if q.y < -0.15:
			q.y = -0.15 + (q.y + 0.15) * 0.3
		st.add_vertex(q)
	st.index()
	st.generate_normals()
	return builder.commit()


## Tronco caído deitado ao longo de X, com tampas nas pontas.
static func build_log(rng: RandomNumberGenerator, bark: Material) -> ArrayMesh:
	var builder := Builder.new()
	var st := builder.tool_for(bark)
	var length := rng.randf_range(3.0, 5.5)
	var radius := rng.randf_range(0.22, 0.35)
	var a := Vector3(-length * 0.5, radius * 0.8, 0.0)
	var b := Vector3(length * 0.5, radius * 0.7, rng.randf_range(-0.3, 0.3))
	add_branch(st, a, b, radius, radius * 0.85, 8)
	for end: Array in [[a, radius, -1.0], [b, radius * 0.85, 1.0]]:
		var center: Vector3 = end[0]
		var r: float = end[1]
		var facing: float = end[2]
		var normal: Vector3 = (b - a).normalized() * facing
		var side: Vector3 = normal.cross(UP).normalized()
		for k in 8:
			var p0: Vector3 = center + (side * cos(TAU * k / 8) + UP * sin(TAU * k / 8)) * r
			var p1: Vector3 = center + (side * cos(TAU * (k + 1) / 8) + UP * sin(TAU * (k + 1) / 8)) * r
			# As duas ordens: a tampa aparece dos dois lados, sem depender do sentido.
			for tri: Array in [[center, p0, p1], [center, p1, p0]]:
				for p: Vector3 in tri:
					st.set_normal(normal)
					st.set_uv(Vector2(0.5, 0.5))
					st.add_vertex(p)
	return builder.commit()


static func _point_on_line(points: Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (points.size() - 1)
	var i := mini(int(f), points.size() - 2)
	return (points[i] as Vector3).lerp(points[i + 1], f - i)


## Galho de pinheiro como dois cartões cruzados (horizontal e vertical) ao longo de dir.
static func _add_branch_cards(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float, frac: float, crown_center: Vector3) -> void:
	var tip := base + dir * length
	var flat := dir.cross(UP).normalized() * width * 0.5
	var upright := dir.cross(flat).normalized() * width * 0.3
	var sway_tip := 0.5 + 0.5 * frac
	for side: Vector3 in [flat, upright]:
		var corners := [base - side, base + side, tip + side, tip - side]
		var normals := []
		for c: Vector3 in corners:
			normals.append((c - crown_center).normalized().lerp(UP, 0.4).normalized())
		add_card(st, corners, [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [0.0, 0.0, sway_tip, sway_tip], normals)


## Cacho de folhas: três cartões quadrados cruzados em ângulos aleatórios.
static func _add_leaf_cluster(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, size: float, crown_center: Vector3) -> void:
	var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
	for axis in 3:
		var u := basis[axis] * size * 0.5
		var w := basis[(axis + 1) % 3] * size * 0.5
		var corners := [center - u - w, center - u + w, center + u + w, center + u - w]
		var normals := []
		for c: Vector3 in corners:
			normals.append((c - crown_center).normalized().lerp(UP, 0.3).normalized())
		add_card(st, corners, [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [1.0, 1.0, 1.0, 1.0], normals)
