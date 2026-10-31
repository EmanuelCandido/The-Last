class_name Vegetation
extends Node3D
## Espalha a vegetação pelo terreno: pinheiros, árvores mortas, grama, samambaias,
## pedras, troncos caídos e a árvore velha que solta folhas.
##
## Instâncias iguais viram MultiMesh agrupados em blocos com distância máxima de
## desenho: muita coisa na tela com poucas chamadas de desenho.
## As árvores ficam registradas (posição, tipo, colisão) para os sons e para o
## jogador poder quebrar as árvores secas.

const CHUNK_SIZE := 48.0
## Lado (m) da grade usada para achar árvores perto de um ponto.
const TREE_CELL := 8.0
## Golpes para derrubar uma árvore seca.
const DEAD_TREE_HITS := 4
const FALLING_LEAVES := preload("res://scenes/world/props/falling_leaves.tscn")
const HIT_SOUNDS := [
	preload("res://assets/audio/real/tree_hit_1.ogg"), preload("res://assets/audio/real/tree_hit_2.ogg"),
	preload("res://assets/audio/real/tree_hit_3.ogg"), preload("res://assets/audio/real/tree_hit_4.ogg"),
]
const FALL_SOUND := preload("res://assets/audio/real/tree_fall.ogg")
## Rangido real de madeira (Kenney, CC0) quando o tronco começa a ceder.
const CREAK_SOUNDS := [
	preload("res://assets/audio/real/wood_creak_1.ogg"), preload("res://assets/audio/real/wood_creak_2.ogg"),
	preload("res://assets/audio/real/wood_creak_3.ogg"),
]

## Camadas de física: 1 = mundo (pedras, troncos caídos), 2 = árvores em pé.
const LAYER_WORLD := 1
const LAYER_TREES := 2

@export var vegetation_seed := 2024

@export_group("Materiais")
@export var bark_material: Material
@export var dead_bark_material: Material
@export var needles_material: Material
@export var leaves_material: Material
@export var grass_material: Material
@export var fern_material: Material
@export var rock_material: Material

@export_group("Distâncias de desenho")
@export var tree_draw_distance := 170.0
@export var grass_draw_distance := 55.0
@export var small_draw_distance := 70.0
@export var rock_draw_distance := 160.0

@export_group("Densidade")
## Espaçamento da grade de onde as árvores são sorteadas (metros).
@export var tree_spacing := 5.5
@export var grass_per_m2 := 0.75
@export var fern_count := 1400
@export var rock_count := 80
@export var log_count := 14

## Posições (x, z) das árvores em pé: os pássaros cantam a partir delas.
var tree_positions := PackedVector2Array()
var old_tree_position := Vector3.ZERO

## Uma árvore em pé: onde está, como foi desenhada e se já caiu.
class TreeInfo:
	var base: Vector3
	var transform: Transform3D
	var mesh: Mesh
	var radius := 0.3
	var dead := false
	var hits := 0
	var fallen := false
	var chunk := Vector2i.ZERO
	var index := 0
	var collider: CollisionShape3D

var trees: Array[TreeInfo] = []

## Mesh -> { Vector2i (bloco) -> Array[Transform3D] }
var _instances := {}
## Mesh -> { Vector2i (bloco) -> MultiMesh }
var _multimeshes := {}
## Mesh -> [distância de desenho, projeta sombra]
var _settings := {}
## Vector2i (célula) -> Array[int] (índices em `trees`)
var _tree_grid := {}
var _colliders: StaticBody3D
var _tree_colliders: StaticBody3D
## As malhas da volta principal, reaproveitadas no leste (F14): o mesmo MultiMesh por bloco.
var _pines: Array[Mesh] = []
var _dead_trees: Array[Mesh] = []
var _grass_clump: Mesh
var _ferns: Array[Mesh] = []
var _rocks: Array[Mesh] = []
var _rock_shapes: Array[Shape3D] = []


func populate(terrain: Terrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = vegetation_seed
	_colliders = _make_body("Colliders", LAYER_WORLD)
	_tree_colliders = _make_body("TreeColliders", LAYER_TREES)

	_scatter_trees(terrain, rng)
	_scatter_grass(terrain, rng)
	_scatter_ferns(terrain, rng)
	_scatter_rocks(terrain, rng)
	_scatter_logs(terrain, rng)
	_place_old_tree(terrain, rng)
	_populate_east(terrain)
	_build_multimeshes()


## Índice da árvore em pé cuja casca está a até `max_distance` de p (no plano), ou -1.
func tree_near(p: Vector3, max_distance: float) -> int:
	var here := Vector2(p.x, p.z)
	var cell := Vector2i(floori(p.x / TREE_CELL), floori(p.z / TREE_CELL))
	var best := -1
	var best_gap := max_distance
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for id: int in _tree_grid.get(cell + Vector2i(dx, dz), []):
				var tree := trees[id]
				if tree.fallen:
					continue
				var gap := here.distance_to(Vector2(tree.base.x, tree.base.z)) - tree.radius
				if gap < best_gap:
					best_gap = gap
					best = id
	return best


## Quanto a copa das árvores cobre `p` (0 = céu aberto .. 1 = mata fechada): árvores vivas em
## pé a até 4 m, as mais perto pesando mais. A chuva e a manada usam.
func canopy_at(p: Vector3) -> float:
	var here := Vector2(p.x, p.z)
	var cell := Vector2i(floori(p.x / TREE_CELL), floori(p.z / TREE_CELL))
	var cover := 0.0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for id: int in _tree_grid.get(cell + Vector2i(dx, dz), []):
				var tree := trees[id]
				if tree.fallen or tree.dead:
					continue
				var gap := here.distance_to(Vector2(tree.base.x, tree.base.z))
				if gap < 4.0:
					cover += 1.0 - gap / 4.0
	return clampf(cover * 0.6, 0.0, 1.0)


## O ponto de copa mais fechada a até `radius` de `p` (onde a manada se abriga da chuva). Testa
## a base de cada árvore viva por perto, um pouco ao lado do tronco.
func shelter_near(p: Vector3, radius: float) -> Vector3:
	var best := p
	var best_cover := canopy_at(p)
	var reach := ceili(radius / TREE_CELL)
	var cell := Vector2i(floori(p.x / TREE_CELL), floori(p.z / TREE_CELL))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for id: int in _tree_grid.get(cell + Vector2i(dx, dz), []):
				var tree := trees[id]
				if tree.fallen or tree.dead:
					continue
				var spot := tree.base + Vector3(1.2, 0.0, 0.8)
				if Vector2(spot.x - p.x, spot.z - p.z).length() > radius:
					continue
				var cover := canopy_at(spot)
				if cover > best_cover + 0.05:
					best_cover = cover
					best = spot
	return best


## Bate na árvore `id`, golpeada a partir de `from`. Devolve true se ela caiu agora.
## Só árvores secas quebram; pinheiros vivos só balançam o som do golpe.
## `chop` = golpe de machado (F13): derruba pinheiro vivo em Tuning.AXE_PINE_HITS golpes.
func hit_tree(id: int, from: Vector3, chop := false) -> bool:
	var tree := trees[id]
	OccludedAudio.play_at(self, HIT_SOUNDS.pick_random(), tree.base + Vector3.UP * 1.0, &"World", -2.0, 5.0, randf_range(0.9, 1.1))
	Events.noise_made.emit(tree.base, 25.0)
	if not tree.dead and not chop:
		return false
	tree.hits += 1
	if tree.hits < (DEAD_TREE_HITS if tree.dead else Tuning.AXE_PINE_HITS):
		return false
	_fell_tree(tree, from)
	return true


func _fell_tree(tree: TreeInfo, from: Vector3) -> void:
	tree.fallen = true
	# Esconde a instância (afunda bem abaixo do chão) e tira a colisão.
	var multimesh: MultiMesh = _multimeshes[tree.mesh][tree.chunk]
	var hidden := multimesh.get_instance_transform(tree.index)
	hidden.origin.y -= 1000.0
	multimesh.set_instance_transform(tree.index, hidden)
	tree.collider.queue_free()

	# Uma cópia da árvore cai para longe de quem bateu, girando na base.
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_position = tree.base
	var falling := MeshInstance3D.new()
	falling.mesh = tree.mesh
	falling.transform = Transform3D(tree.transform.basis, Vector3.ZERO)
	pivot.add_child(falling)
	var away := Vector3(tree.base.x - from.x, 0.0, tree.base.z - from.z).normalized()
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var tween := pivot.create_tween()
	tween.tween_property(pivot, "quaternion", Quaternion(axis, deg_to_rad(84.0)), 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	OccludedAudio.play_at(self, CREAK_SOUNDS.pick_random(), tree.base + Vector3.UP * 2.5, &"World", 0.0, 8.0, randf_range(0.6, 0.75))
	OccludedAudio.play_at(self, FALL_SOUND, tree.base + Vector3.UP * 2.0, &"World", 2.0, 10.0)
	Events.noise_made.emit(tree.base, 70.0)


func _scatter_trees(terrain: Terrain, rng: RandomNumberGenerator) -> void:
	for i in 4:
		_pines.append(TreeBuilder.build_pine(rng, bark_material, needles_material))
	for i in 3:
		_dead_trees.append(TreeBuilder.build_dead_tree(rng, dead_bark_material))

	var limit := ForestLayout.VALLEY_RADIUS + 45.0
	var x := -limit
	while x < limit:
		var z := -limit
		while z < limit:
			var p := Vector2(x, z) + Vector2(rng.randf(), rng.randf()) * tree_spacing
			z += tree_spacing
			if p.length() > limit or ForestLayout.cave_ellipse(p) < 2.2 or p.distance_to(ForestLayout.OLD_TREE) < 9.0:
				continue
			_try_tree(terrain, rng, p)
		x += tree_spacing


## Uma das malhas de pedra (e a colisão dela), para quem monta pedras fora do sorteio (F14: a
## Pedra Rachada do acampamento).
func rock_mesh(variant: int) -> Mesh:
	return _rocks[variant % _rocks.size()]


func rock_shape(variant: int) -> Shape3D:
	return _rock_shapes[variant % _rock_shapes.size()]


## Uma árvore em `p`, se o sorteio e o chão deixarem.
func _try_tree(terrain: Terrain, rng: RandomNumberGenerator, p: Vector2) -> void:
	# Algumas árvores solitárias também nascem nas áreas abertas.
	if rng.randf() > terrain.forest_density(p.x, p.y) * 0.9 + 0.03:
		return
	if ForestLayout.distance_to_trail(p) < 3.0 or terrain.get_normal(p.x, p.y).y < 0.78:
		return
	var tree := TreeInfo.new()
	tree.dead = rng.randf() < 0.16
	tree.mesh = _dead_trees[rng.randi() % _dead_trees.size()] if tree.dead else _pines[rng.randi() % _pines.size()]
	var tree_scale := rng.randf_range(0.75, 1.25)
	tree.base = Vector3(p.x, terrain.get_height(p.x, p.y) - 0.25, p.y)
	tree.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_scale), tree.base)
	tree.radius = float(tree.mesh.get_meta("trunk_radius", 0.3)) * tree_scale
	var slot := _add_instance(tree.mesh, tree.transform, tree_draw_distance, true)
	tree.chunk = slot[0]
	tree.index = slot[1]
	tree.collider = _add_cylinder_collider(_tree_colliders, tree.base, tree.radius + 0.03, 8.0)
	var id := trees.size()
	trees.append(tree)
	var cell := Vector2i(floori(p.x / TREE_CELL), floori(p.y / TREE_CELL))
	if not _tree_grid.has(cell):
		_tree_grid[cell] = []
	_tree_grid[cell].append(id)
	tree_positions.append(p)


func _scatter_grass(terrain: Terrain, rng: RandomNumberGenerator) -> void:
	_grass_clump = TreeBuilder.build_grass_clump(grass_material)
	var limit := ForestLayout.VALLEY_RADIUS + 15.0
	for i in int(PI * limit * limit * grass_per_m2):
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if p.length() > limit or ForestLayout.cave_ellipse(p) < 1.15:
			continue
		_try_grass(terrain, rng, p)


## Um tufo de capim em `p`, se o chão deixar (pouco na rocha e na terra).
func _try_grass(terrain: Terrain, rng: RandomNumberGenerator, p: Vector2) -> void:
	var splat := terrain.get_splat(p.x, p.y)
	if rng.randf() > (1.0 - splat.r) * (1.0 - splat.g) * (1.0 - 0.65 * splat.b):
		return
	var width := rng.randf_range(0.7, 1.3)
	var height := rng.randf_range(0.4, 0.95)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
	_add_instance(_grass_clump, Transform3D(basis, Vector3(p.x, terrain.get_height(p.x, p.y) - 0.05, p.y)), grass_draw_distance, false)


func _scatter_ferns(terrain: Terrain, rng: RandomNumberGenerator) -> void:
	var ferns: Array[Mesh] = [TreeBuilder.build_fern(rng, fern_material), TreeBuilder.build_fern(rng, fern_material)]
	_ferns = ferns
	var limit := ForestLayout.VALLEY_RADIUS + 20.0
	var placed := 0
	var attempts := 0
	while placed < fern_count and attempts < fern_count * 12:
		attempts += 1
		var p := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		if p.length() > limit or ForestLayout.cave_ellipse(p) < 1.6 or ForestLayout.distance_to_trail(p) < 2.0:
			continue
		if rng.randf() > terrain.forest_density(p.x, p.y) - 0.2:
			continue
		var fern_scale := rng.randf_range(0.7, 1.4)
		var origin := Vector3(p.x, terrain.get_height(p.x, p.y) - 0.05, p.y)
		_add_instance(ferns[placed % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * fern_scale), origin), small_draw_distance, false)
		placed += 1


func _scatter_rocks(terrain: Terrain, rng: RandomNumberGenerator) -> void:
	var rocks: Array[Mesh] = []
	var shapes: Array[Shape3D] = []
	for i in 5:
		var mesh := TreeBuilder.build_rock(rng, rock_material)
		rocks.append(mesh)
		# Colisão com a malha exata: o casco convexo de uma pedra irregular sobra até
		# 1 m nas reentrâncias e o goblin ficava "em pé no ar".
		shapes.append(mesh.create_trimesh_shape())
	_rocks = rocks
	_rock_shapes = shapes
	for i in rock_count:
		var p: Vector2
		# Parte das pedras se concentra na boca da caverna e no pé das montanhas.
		var spot := rng.randf()
		if spot < 0.2:
			var mouth := ForestLayout.CAVE_CENTER - Vector2(0.0, ForestLayout.CAVE_DEPTH * 0.5 + 4.0)
			p = mouth + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 3.0))
			if absf(p.x - mouth.x) < 3.5:
				continue
		elif spot < 0.55:
			var angle := rng.randf() * TAU
			p = Vector2(cos(angle), sin(angle)) * rng.randf_range(ForestLayout.VALLEY_RADIUS - 20.0, ForestLayout.VALLEY_RADIUS + 15.0)
		else:
			p = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * ForestLayout.VALLEY_RADIUS
		if ForestLayout.cave_ellipse(p) < 1.3 or ForestLayout.distance_to_trail(p) < 2.0:
			continue
		var variant := rng.randi() % rocks.size()
		var rock_scale := rng.randf_range(0.4, 1.4) * (1.8 if rng.randf() < 0.15 else 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))).scaled(Vector3.ONE * rock_scale)
		var xf := Transform3D(basis, Vector3(p.x, terrain.get_height(p.x, p.y) - 0.1 * rock_scale, p.y))
		_add_instance(rocks[variant], xf, rock_draw_distance, true)
		_add_shape_collider(shapes[variant], xf, &"stone")


func _scatter_logs(terrain: Terrain, rng: RandomNumberGenerator) -> void:
	var logs: Array[Mesh] = []
	var shapes: Array[Shape3D] = []
	for i in 3:
		var mesh := TreeBuilder.build_log(rng, bark_material)
		logs.append(mesh)
		shapes.append(mesh.create_convex_shape())
	var placed := 0
	var attempts := 0
	while placed < log_count and attempts < 400:
		attempts += 1
		var p := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * ForestLayout.VALLEY_RADIUS
		if terrain.forest_density(p.x, p.y) < 0.4 or ForestLayout.distance_to_trail(p) < 3.0 or terrain.get_normal(p.x, p.y).y < 0.9:
			continue
		var variant := placed % logs.size()
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, terrain.get_height(p.x, p.y) - 0.12, p.y))
		_add_instance(logs[variant], xf, small_draw_distance, true)
		_add_shape_collider(shapes[variant], xf, &"wood")
		placed += 1


## F14: o desfiladeiro e o vale da Pedra Rachada, com um sorteio próprio (o do vale da toca não
## muda). Só onde as voltas de cima não chegam: fora do círculo de cada uma.
func _populate_east(terrain: Terrain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = vegetation_seed + 14
	var center := ForestLayout.SECOND_VALLEY
	var reach := ForestLayout.SECOND_VALLEY_RADIUS + 45.0
	# Árvores: a mesma grade, cobrindo o desfiladeiro e o vale com as encostas.
	var x := ForestLayout.GORGE_FROM.x - 10.0
	while x < center.x + reach:
		var z := center.y - reach
		while z < center.y + reach:
			var p := Vector2(x, z) + Vector2(rng.randf(), rng.randf()) * tree_spacing
			z += tree_spacing
			if _east_area(p, ForestLayout.VALLEY_RADIUS + 45.0, 40.0):
				_try_tree(terrain, rng, p)
		x += tree_spacing
	# Capim: quatro de cada cinco no vale, o resto no chão do desfiladeiro.
	var disc := ForestLayout.SECOND_VALLEY_RADIUS + 15.0
	var corridor := ForestLayout.GORGE_HALF_WIDTH + 6.0
	var gorge_length := (ForestLayout.GORGE_TO - ForestLayout.GORGE_FROM).length()
	var area := PI * disc * disc + gorge_length * corridor * 2.0
	for i in int(area * grass_per_m2):
		var p := _east_sample(rng, disc, corridor)
		if _east_area(p, ForestLayout.VALLEY_RADIUS + 15.0, 15.0):
			_try_grass(terrain, rng, p)
	# Samambaias na mata do vale.
	for i in 900:
		var p := _east_sample(rng, disc, corridor)
		if not _east_area(p, ForestLayout.VALLEY_RADIUS + 20.0, 15.0) or rng.randf() > terrain.forest_density(p.x, p.y) - 0.2:
			continue
		var origin := Vector3(p.x, terrain.get_height(p.x, p.y) - 0.05, p.y)
		_add_instance(_ferns[i % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), origin), small_draw_distance, false)
	# Pedras: o cascalho grande que caiu dos paredões (fora da ravina e da passagem) e algumas no vale.
	for i in 70:
		var p: Vector2
		if i < 45:
			var side := rng.randf_range(-1.0, 1.0)
			side = signf(side) * lerpf(ForestLayout.GORGE_HALF_WIDTH - 3.0, ForestLayout.GORGE_HALF_WIDTH + 3.0, absf(side))
			p = ForestLayout.gorge_point(rng.randf_range(0.05, 0.98), side)
			if ForestLayout.ravine_depth(p) > 0.05 or absf(ForestLayout.gorge_frame(p).y - ForestLayout.GORGE_LEDGE) < 1.8:
				continue
		else:
			var angle := rng.randf() * TAU
			p = center + Vector2(cos(angle), sin(angle)) * rng.randf_range(10.0, ForestLayout.SECOND_VALLEY_RADIUS + 10.0)
		var variant := rng.randi() % _rocks.size()
		var rock_scale := rng.randf_range(0.5, 1.6) * (1.8 if rng.randf() < 0.2 else 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(Vector3.ONE * rock_scale)
		var xf := Transform3D(basis, Vector3(p.x, terrain.get_height(p.x, p.y) - 0.1 * rock_scale, p.y))
		_add_instance(_rocks[variant], xf, rock_draw_distance, true)
		_add_shape_collider(_rock_shapes[variant], xf, &"stone")


## Um ponto para sortear no leste: no vale da Pedra Rachada (até `disc` do centro) ou no
## desfiladeiro (até `corridor` de lado do eixo).
func _east_sample(rng: RandomNumberGenerator, disc: float, corridor: float) -> Vector2:
	if rng.randf() < 0.8:
		var angle := rng.randf() * TAU
		return ForestLayout.SECOND_VALLEY + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * disc
	return ForestLayout.gorge_point(rng.randf(), rng.randf_range(-corridor, corridor))


## `p` fica no leste e fora do círculo `main_limit` (o que a volta principal espalha): no
## desfiladeiro ou no vale da Pedra Rachada, até `margin` além do chão deles.
static func _east_area(p: Vector2, main_limit: float, margin: float) -> bool:
	if p.length() <= main_limit:
		return false
	return ForestLayout.distance_to_gorge(p) < ForestLayout.GORGE_HALF_WIDTH + margin \
		or p.distance_to(ForestLayout.SECOND_VALLEY) < ForestLayout.SECOND_VALLEY_RADIUS + margin


func _place_old_tree(terrain: Terrain, rng: RandomNumberGenerator) -> void:
	var p := ForestLayout.OLD_TREE
	old_tree_position = Vector3(p.x, terrain.get_height(p.x, p.y) - 0.3, p.y)
	var tree := MeshInstance3D.new()
	tree.name = "OldTree"
	tree.mesh = TreeBuilder.build_old_tree(rng, bark_material, leaves_material)
	tree.position = old_tree_position
	tree.rotation.y = 0.7
	add_child(tree)
	_add_cylinder_collider(_tree_colliders, old_tree_position, 0.8, 5.0)
	var leaves := FALLING_LEAVES.instantiate() as Node3D
	leaves.position = old_tree_position + Vector3(0.0, 7.0, 0.0)
	add_child(leaves)


## Guarda a instância para o MultiMesh do seu bloco. Devolve [bloco, índice no bloco].
func _add_instance(mesh: Mesh, xf: Transform3D, draw_distance: float, cast_shadow: bool) -> Array:
	if not _instances.has(mesh):
		_instances[mesh] = {}
		_settings[mesh] = [draw_distance, cast_shadow]
	var chunks: Dictionary = _instances[mesh]
	var key := Vector2i(floori(xf.origin.x / CHUNK_SIZE), floori(xf.origin.z / CHUNK_SIZE))
	if not chunks.has(key):
		chunks[key] = []
	chunks[key].append(xf)
	return [key, chunks[key].size() - 1]


func _build_multimeshes() -> void:
	for mesh: Mesh in _instances:
		var chunks: Dictionary = _instances[mesh]
		var settings: Array = _settings[mesh]
		_multimeshes[mesh] = {}
		for key: Vector2i in chunks:
			var transforms: Array = chunks[key]
			# O nó fica no centro do bloco, para a distância de desenho ser medida dali.
			var center := Vector3((key.x + 0.5) * CHUNK_SIZE, 0.0, (key.y + 0.5) * CHUNK_SIZE)
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = mesh
			multimesh.instance_count = transforms.size()
			for i in transforms.size():
				var xf: Transform3D = transforms[i]
				multimesh.set_instance_transform(i, Transform3D(xf.basis, xf.origin - center))
			_multimeshes[mesh][key] = multimesh
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.position = center
			instance.visibility_range_end = settings[0]
			instance.visibility_range_end_margin = 10.0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if settings[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)


## Esconde os blocos de vegetação que ficam inteiros ao norte de `z` (R3). -INF mostra tudo.
func set_north_cut(z: float) -> void:
	for child in get_children():
		if child is MultiMeshInstance3D:
			var block := child as MultiMeshInstance3D
			block.visible = block.position.z + CHUNK_SIZE * 0.5 > z + 0.01


func _make_body(body_name: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body


func _add_cylinder_collider(body: StaticBody3D, base: Vector3, radius: float, height: float) -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = base + Vector3(0.0, height * 0.5, 0.0)
	body.add_child(collision)
	return collision


## `surface` é o chão que os passos tocam em cima dessa colisão (Footsteps lê o meta).
func _add_shape_collider(shape: Shape3D, xf: Transform3D, surface: StringName) -> void:
	var collision := CollisionShape3D.new()
	collision.set_meta(&"surface", surface)
	collision.shape = shape
	collision.transform = xf
	_colliders.add_child(collision)
