class_name ForageSpot
extends Node3D
## Um lugar de coleta (§8b-D): um tufo de cogumelos ao pé de uma árvore ou um arbusto de
## frutinhas na borda da mata. E colhe; colhido, volta a dar depois de Tuning.FORAGE_REGROW_DAYS
## dias (o arbusto fica, sem as frutinhas). Quem guarda o dia da colheita é o ForageField.

const PICK_SOUND := preload("res://assets/audio/real/pickup_2.ogg")

## &"mushroom", &"berries", &"moss" ou &"herb" (F11).
var kind := &"mushroom"
## Dia em que foi colhido (-1 = pronto para colher).
var picked_day := -1
## O musgo cresce no tronco desta árvore seca (-1 = no chão); derrubada, ele vai junto.
var tree_id := -1

var _fruit: Node3D


func build(spot_kind: StringName, rng: RandomNumberGenerator) -> void:
	kind = spot_kind
	add_to_group(&"interactable")
	var plant := MeshInstance3D.new()
	var fruit := MeshInstance3D.new()
	add_child(plant)
	add_child(fruit)
	_fruit = fruit
	if kind == &"mushroom":
		# Todo o tufo é "fruta": colhido, não sobra nada até voltar.
		fruit.mesh = _mushrooms(rng)
	elif kind == &"moss":
		fruit.mesh = _moss(rng)
	elif kind == &"herb":
		# Uma moita baixa de folhas escuras com as flores vermelhas: arrancada inteira.
		var meshes := _bush(rng)
		fruit.mesh = meshes[0]
		var flowers := MeshInstance3D.new()
		flowers.mesh = meshes[1]
		fruit.add_child(flowers)
		fruit.scale = Vector3(0.75, 0.7, 0.75)
		fruit.material_override = _herb_leaves()
	else:
		var meshes := _bush(rng)
		plant.mesh = meshes[0]
		fruit.mesh = meshes[1]


## Um tufo de 3 a 5 cogumelos tortos, de pé creme e chapéu castanho, com as lamelas embaixo.
func _mushrooms(rng: RandomNumberGenerator) -> ArrayMesh:
	var builder := TreeBuilder.Builder.new()
	var stem_st := builder.tool_for(PropLook.mushroom_stem())
	var cap_st := builder.tool_for(PropLook.mushroom_cap())
	for i in rng.randi_range(3, 5):
		var at := Vector3(rng.randf_range(-0.2, 0.2), -0.01, rng.randf_range(-0.2, 0.2))
		var height := rng.randf_range(0.05, 0.12)
		var lean := Vector3(rng.randf_range(-0.35, 0.35), 1.0, rng.randf_range(-0.35, 0.35)).normalized()
		var top := at + lean * height
		var radius := rng.randf_range(0.03, 0.055) * (0.7 + height * 4.0)
		TreeBuilder.add_branch(stem_st, at, top, radius * 0.38, radius * 0.26, 6)
		_cap(cap_st, stem_st, rng, top, lean.lerp(Vector3.UP, 0.5).normalized(), radius)
	return builder.commit()


## Chapéu em domo, um pouco amassado, e a face de baixo (lamelas) no material do pé.
func _cap(cap_st: SurfaceTool, under_st: SurfaceTool, rng: RandomNumberGenerator, top: Vector3, up: Vector3, radius: float) -> void:
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var other := up.cross(side)
	var sides := 8
	var rings := 3
	var dome := radius * rng.randf_range(0.45, 0.7)
	var center := top - up * dome * 0.3
	var wobble: Array[float] = []
	for k in sides:
		wobble.append(rng.randf_range(0.85, 1.12))
	var grid := []
	for j in rings + 1:
		var phi := PI * 0.5 * (1.0 + 0.12) * j / rings
		var row := []
		for k in sides:
			var t := TAU * k / sides
			var r := sin(phi) * radius * (1.0 if j == 0 else wobble[k])
			row.append(center + (side * cos(t) + other * sin(t)) * r + up * cos(phi) * dome)
		grid.append(row)
	for j in rings:
		for k in sides:
			var n := (k + 1) % sides
			var a: Vector3 = grid[j][k]
			var b: Vector3 = grid[j][n]
			var c: Vector3 = grid[j + 1][k]
			var d: Vector3 = grid[j + 1][n]
			_tri(cap_st, a, b, c, center)
			_tri(cap_st, b, d, c, center)
	var gills := center - up * dome * 0.15
	for k in sides:
		_tri(under_st, grid[rings][k], grid[rings][(k + 1) % sides], gills, gills + up * dome * 4.0)


## Triângulo com a face da frente para longe de `inside` (sentido horário visto de fora).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var out := ((a + b + c) / 3.0 - inside).normalized()
	if (b - a).cross(c - a).dot(out) > 0.0:
		var swap := b
		b = c
		c = swap
	for p: Vector3 in [a, b, c]:
		st.set_normal((p - inside).normalized())
		# Sem uso (material triplanar), mas o pé, na mesma superfície, tem UV.
		st.set_uv(Vector2.ZERO)
		st.add_vertex(p)


## O arbusto: galhos tortos saindo do chão com cachos de folhas miúdas (cartões no
## foliage.gdshader, como a copa das árvores) e, numa malha à parte, os cachos de frutinhas.
## Mais alto que o capim, para se achar de longe.
func _bush(rng: RandomNumberGenerator) -> Array[ArrayMesh]:
	var builder := TreeBuilder.Builder.new()
	var bark_st := builder.tool_for(PropLook.bark())
	var leaf_st := builder.tool_for(PropLook.bush())
	var fruit := TreeBuilder.Builder.new()
	var berry_st := fruit.tool_for(PropLook.berries())
	var crown := Vector3(0.0, 0.3, 0.0)
	for s in rng.randi_range(5, 7):
		var angle := TAU * s / 6.0 + rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(angle) * rng.randf_range(0.3, 0.7), 1.0, sin(angle) * rng.randf_range(0.3, 0.7))
		var base := Vector3(rng.randf_range(-0.08, 0.08), -0.02, rng.randf_range(-0.08, 0.08))
		var stem := TreeBuilder.crooked_line(rng, base, dir, rng.randf_range(0.7, 1.1), 3, 0.3)
		for i in stem.size() - 1:
			TreeBuilder.add_branch(bark_st, stem[i], stem[i + 1], 0.022 - i * 0.006, 0.016 - i * 0.005, 5)
		# Um cacho na ponta (galho pelado espetado para fora não parece arbusto) e outro no meio.
		for c in 2:
			var t := 1.0 if c == 0 else rng.randf_range(0.45, 0.85)
			var i := mini(int(t * (stem.size() - 1)), stem.size() - 2)
			var at: Vector3 = (stem[i] as Vector3).lerp(stem[i + 1], t * (stem.size() - 1) - i)
			at += Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.05, 0.1), rng.randf_range(-0.1, 0.1))
			var size := rng.randf_range(0.45, 0.65)
			_cluster(leaf_st, rng, at, size, crown)
			if rng.randf() < 0.75:
				_cluster(berry_st, rng, at + Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05)), size * 0.9, crown)
	return [builder.commit(), fruit.commit()]


## Três cartões quadrados cruzados em ângulos sorteados; o balanço cresce com a altura.
func _cluster(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, size: float, crown: Vector3) -> void:
	var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
	for axis in 3:
		var u := basis[axis] * size * 0.5
		var w := basis[(axis + 1) % 3] * size * 0.5
		var corners := [center - u - w, center - u + w, center + u + w, center + u - w]
		var normals := []
		var sway := []
		for c: Vector3 in corners:
			normals.append((c - crown).normalized().lerp(Vector3.UP, 0.3).normalized())
			sway.append(clampf(c.y, 0.0, 1.0))
		TreeBuilder.add_card(st, corners, [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], sway, normals)


## Tufos de musgo colados no tronco: almofadas achatadas contra a casca (a frente é +Z), de 10 a
## 55 cm do chão, acima do capim.
func _moss(rng: RandomNumberGenerator) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/ground_grass.png")
	material.albedo_color = Color(0.78, 0.98, 0.48)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 4.0
	material.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rng.randi_range(5, 7):
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.07, 0.11)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		var center := Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.12, 0.5), 0.0)
		# Achatada contra o tronco e um pouco mais comprida na vertical.
		st.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(1.1, 1.4, 0.45)), center))
	st.set_material(material)
	return st.commit(mesh)


static var _herb_material: ShaderMaterial


## As folhas da erva: as do arbusto, mais escuras e avermelhadas (uma cópia só para todas).
static func _herb_leaves() -> Material:
	if _herb_material == null:
		_herb_material = PropLook.bush().duplicate() as ShaderMaterial
		_herb_material.set_shader_parameter(&"tint", Color(0.62, 0.42, 0.36))
	return _herb_material


func ready_to_pick() -> bool:
	if tree_id >= 0 and _tree_fell():
		return false
	return picked_day < 0 or Clock.day - picked_day >= Tuning.FORAGE_REGROW_DAYS


func _process(_delta: float) -> void:
	if tree_id < 0:
		set_process(false)
		return
	# O musgo do tronco some quando a árvore cai (não fica flutuando no ar).
	if _fruit.visible and _tree_fell():
		_fruit.visible = false


func _tree_fell() -> bool:
	var level := Game.current_level
	return level != null and level.has_method("tree_standing") and not level.tree_standing(tree_id)


func refresh() -> void:
	if picked_day >= 0 and ready_to_pick():
		picked_day = -1
	_fruit.visible = ready_to_pick()


func interaction_prompt() -> String:
	if not ready_to_pick():
		return ""
	match kind:
		&"mushroom":
			return "Colher cogumelos"
		&"moss":
			return "Arrancar musgo"
		&"herb":
			return "Colher erva-de-sangue"
	return "Colher frutinhas"


func interact(_player: Node) -> void:
	if not ready_to_pick():
		return
	var amount := 2 if kind == &"mushroom" or kind == &"moss" else 1 if kind == &"herb" else 3
	Inventory.add(kind, amount)
	picked_day = Clock.day
	refresh()
	Events.notification_shown.emit("+%d %s" % [amount, String(Inventory.NAMES[kind]).to_lower()])
	OccludedAudio.play_at(get_parent(), PICK_SOUND, global_position + Vector3.UP * 0.3, &"World", -6.0, 2.5)

