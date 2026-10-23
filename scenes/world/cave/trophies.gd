class_name Trophies
extends Node3D
## A caverna vira lar (§8b-F): cada cervo coletado deixa uma galhada pendurada na parede da
## esquerda (de quem entra), até Tuning.TROPHY_MAX; cada javali, um par de presas; o Velho, um
## crânio grande com a galhada enorme, no lugar de honra, no fundo. Montados a partir dos
## contadores do Story ("deer_harvested", "boar_harvested", "old_deer_harvested"), que ficam na
## Reciclagem.
##
## A parede é irregular: cada troféu acha o seu ponto com um raio, depois da primeira volta da
## física (a casca da caverna é montada depois do _ready). Filho da Cave, no espaço dela.

## Onde vão as galhadas (z ao longo da caverna) e as presas, na parede -X.
const ANTLER_Z := [-2.6, -1.8, -1.0, -0.2, 0.6, 1.4, 2.2, 3.0]
const ANTLER_HEIGHT := 1.75
const TUSK_Z := [-2.2, -1.4, -0.6, 0.2]
const TUSK_HEIGHT := 1.2
## O Velho: no fundo da caverna, alto.
const OLD_SPOT := Vector3(0.0, 2.3, 6.0)

var _built := ""


func _ready() -> void:
	Story.changed.connect(_refresh)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var deer := mini(Story.count(&"deer_harvested"), Tuning.TROPHY_MAX)
	var boars := mini(Story.count(&"boar_harvested"), TUSK_Z.size())
	var old := Story.count(&"old_deer_harvested") > 0
	var key := "%d/%d/%s" % [deer, boars, old]
	if key == _built:
		return
	_built = key
	for child in get_children():
		child.queue_free()
	var space := get_world_3d().direct_space_state
	for i in deer:
		var spot := _wall(space, Vector3(0.0, ANTLER_HEIGHT + (0.12 if i % 2 else 0.0), ANTLER_Z[i]), Vector3.LEFT)
		if not spot.is_empty():
			_antlers(spot[0], spot[1], 1.0, i)
	for i in boars:
		var spot := _wall(space, Vector3(0.0, TUSK_HEIGHT, TUSK_Z[i]), Vector3.LEFT)
		if not spot.is_empty():
			_tusks(spot[0], spot[1])
	if old:
		var spot := _wall(space, Vector3(0.0, OLD_SPOT.y, 2.0), Vector3.BACK)
		if not spot.is_empty():
			_antlers(spot[0], spot[1], 1.8, 99)


## Ponto da parede a partir de `from` (no espaço da caverna) indo para `direction`: [ponto, normal].
func _wall(space: PhysicsDirectSpaceState3D, from: Vector3, direction: Vector3) -> Array:
	var start := to_global(from)
	var query := PhysicsRayQueryParameters3D.create(start, start + global_basis * direction * 8.0, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return []
	return [to_local(hit.position), (global_basis.inverse() * (hit.normal as Vector3)).normalized()]


## Um crânio de cervo e a galhada, preso na parede com a cara para fora. Osso e chifre no
## material de osso (textura pixelada); a galhada é feita de galhos afunilados e tortos.
func _antlers(at: Vector3, normal: Vector3, size: float, variant: int) -> void:
	var mount := _mount(at, normal)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 31 + 7
	var builder := TreeBuilder.Builder.new()
	var st := builder.tool_for(PropLook.bone())
	# Crânio: a caixa atrás, o focinho comprido para fora e para baixo.
	_lump(st, rng, Vector3(0.0, 0.0, 0.07) * size, Vector3(0.052, 0.048, 0.085) * size)
	_lump(st, rng, Vector3(0.0, -0.045, 0.18) * size, Vector3(0.03, 0.024, 0.09) * size)
	var tines := 3 if size < 1.5 else 5
	for side: float in [-1.0, 1.0]:
		# A haste sai do alto do crânio, abre para o lado e curva para cima e para a frente.
		var beam := TreeBuilder.crooked_line(rng, Vector3(0.035 * side, 0.04, 0.05) * size,
			Vector3(0.7 * side, 1.0, 0.25), 0.36 * size, 4, 0.12)
		for i in beam.size() - 1:
			TreeBuilder.add_branch(st, beam[i], beam[i + 1], (0.014 - i * 0.002) * size, (0.012 - i * 0.002) * size, 5)
		for t in tines:
			var start: Vector3 = beam[mini(t + 1, beam.size() - 2)].lerp(beam[mini(t + 2, beam.size() - 1)], rng.randf_range(0.0, 0.5))
			var dir := Vector3(rng.randf_range(-0.2, 0.2) * side, rng.randf_range(0.6, 1.0), rng.randf_range(0.5, 0.9)).normalized()
			var tip := start + dir * rng.randf_range(0.08, 0.13) * size
			TreeBuilder.add_branch(st, start, tip, 0.008 * size, 0.003 * size, 4)
	mount.add_child(_instance(builder.commit()))


## Um par de presas de javali, curvas e afiladas, cruzadas sobre um toco de galho.
func _tusks(at: Vector3, normal: Vector3) -> void:
	var mount := _mount(at, normal)
	var builder := TreeBuilder.Builder.new()
	TreeBuilder.add_branch(builder.tool_for(PropLook.bark()), Vector3(-0.13, -0.01, 0.025), Vector3(0.13, 0.01, 0.025), 0.03, 0.026, 6)
	var st := builder.tool_for(PropLook.bone())
	for side: float in [-1.0, 1.0]:
		var points := [Vector3(0.1 * side, -0.07, 0.05)]
		var dir := Vector3(-0.35 * side, 1.0, 0.1).normalized()
		for i in 4:
			# Cada trecho vira mais para o lado: a presa faz o arco.
			dir = dir.rotated(Vector3.BACK, -0.32 * side)
			points.append(points[-1] + dir * 0.05)
		for i in points.size() - 1:
			TreeBuilder.add_branch(st, points[i], points[i + 1], 0.016 - i * 0.0035, 0.0125 - i * 0.0035, 6)
	mount.add_child(_instance(builder.commit()))


## Um caroço de osso: esfera baixa deformada (como as pedras), com a textura de osso.
func _lump(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3, radii: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 6
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bumps := {}
	for idx in indices:
		var p := verts[idx].normalized()
		var key := Vector3i((p * 100.0).round())
		if not bumps.has(key):
			bumps[key] = rng.randf_range(0.94, 1.06)
		var q: Vector3 = p * float(bumps[key])
		# A normal do elipsoide (a da esfera, esticada, dava listras de luz).
		st.set_normal((p / radii).normalized())
		# Sem uso (o osso é triplanar), mas a superfície também tem galhos com UV.
		st.set_uv(Vector2.ZERO)
		st.add_vertex(center + q * radii)


func _instance(mesh: ArrayMesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node


func _mount(at: Vector3, normal: Vector3) -> Node3D:
	var mount := Node3D.new()
	add_child(mount)
	mount.position = at + normal * 0.03
	# +Z do troféu sai da parede.
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	mount.basis = Basis.looking_at(-normal, up)
	return mount

