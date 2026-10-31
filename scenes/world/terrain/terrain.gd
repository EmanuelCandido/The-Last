class_name Terrain
extends Node3D
## Terreno gerado por ruído: vale com colinas, anel de montanhas e a encosta da caverna; a leste,
## o desfiladeiro com a ravina e o vale da Pedra Rachada (F14).
##
## Gera a malha em blocos (o culling descarta o que está fora da câmera), a colisão
## por HeightMapShape3D e guarda a grade de alturas para consultas rápidas. A grade cobre o
## retângulo de ForestLayout.TERRAIN_MIN a TERRAIN_MAX.
## A cor do vértice leva os pesos das texturas: R rocha, G terra, B chão de floresta.

## Lado de uma célula da grade (m).
const CELL := 1.5
## Células por lado de um bloco de malha (48 m).
const CHUNK_CELLS := 32

@export var terrain_seed := 1337
@export var material: Material

## Altura do chão dentro da caverna (o terreno é aplainado nela).
var cave_floor_height := 0.0
var cell_size := CELL
## Células da grade em x e em z.
var cells_x := int((ForestLayout.TERRAIN_MAX.x - ForestLayout.TERRAIN_MIN.x) / CELL)
var cells_z := int((ForestLayout.TERRAIN_MAX.y - ForestLayout.TERRAIN_MIN.y) / CELL)

var _origin := ForestLayout.TERRAIN_MIN
var _side_x := cells_x + 1
var _side_z := cells_z + 1
var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()
var _splat := PackedColorArray()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _forest := FastNoiseLite.new()
var _trail_bounds: Rect2


func generate() -> void:
	_setup_noise()
	var mouth := ForestLayout.CAVE_CENTER - Vector2(0.0, ForestLayout.CAVE_DEPTH * 0.5)
	cave_floor_height = _raw_height(mouth.x, mouth.y)

	_heights.resize(_side_x * _side_z)
	for gz in _side_z:
		for gx in _side_x:
			_heights[gz * _side_x + gx] = _height_at(_grid_x(gx), _grid_z(gz))
	_compute_normals_and_splat()
	_build_meshes()
	_build_collision()


## O retângulo coberto pelo terreno, no chão (x, z).
func rect() -> Rect2:
	return Rect2(_origin, Vector2(cells_x, cells_z) * cell_size)


## Altura do terreno em (x, z), interpolada igual aos triângulos da malha.
func get_height(x: float, z: float) -> float:
	var fx := clampf((x - _origin.x) / cell_size, 0.0, cells_x - 0.001)
	var fz := clampf((z - _origin.y) / cell_size, 0.0, cells_z - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * _side_x + ix
	var h00 := _heights[i]
	var h10 := _heights[i + 1]
	var h01 := _heights[i + _side_x]
	var h11 := _heights[i + _side_x + 1]
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func get_normal(x: float, z: float) -> Vector3:
	return _normals[_nearest_index(x, z)]


## Pesos das texturas no ponto (R rocha, G terra, B floresta).
func get_splat(x: float, z: float) -> Color:
	return _splat[_nearest_index(x, z)]


## Tipo de chão para sons de passos: &"cave", &"stone", &"dirt" ou &"grass".
func surface_at(world_position: Vector3) -> StringName:
	var p := Vector2(world_position.x, world_position.z)
	# O salão da caverna é terra batida com cascalho, não rocha lisa.
	if ForestLayout.cave_interior(p) > 0.3:
		return &"cave"
	var splat := get_splat(p.x, p.y)
	if splat.r > 0.5:
		return &"stone"
	if splat.g > 0.45:
		return &"dirt"
	return &"grass"


## Densidade de árvores (0..1): manchas de mata fechada e clareiras.
func forest_density(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var density := smoothstep(-0.25, 0.45, _forest.get_noise_2d(x, z))
	density *= smoothstep(ForestLayout.MEADOW_RADIUS * 0.7, ForestLayout.MEADOW_RADIUS * 1.4, p.distance_to(ForestLayout.MEADOW))
	density *= smoothstep(9.0, 16.0, p.distance_to(ForestLayout.OLD_TREE))
	density *= smoothstep(10.0, 18.0, p.distance_to(ForestLayout.RUINS))
	density *= smoothstep(1.6, 3.0, ForestLayout.cave_ellipse(p))
	# O chão do desfiladeiro é cascalho, quase sem árvore; na ravina, nenhuma (F14).
	if density > 0.0 and ForestLayout.near_gorge(p, ForestLayout.GORGE_HALF_WIDTH + 14.0):
		density *= lerpf(0.15, 1.0, smoothstep(ForestLayout.GORGE_HALF_WIDTH - 2.0, ForestLayout.GORGE_HALF_WIDTH + 8.0, ForestLayout.distance_to_gorge(p)))
		density *= 1.0 - smoothstep(0.2, 1.0, ForestLayout.ravine_depth(p))
	return density


## Publica a grade de alturas como textura global (terrain_height + terrain_height_rect),
## para shaders encostarem vértices no chão (a grama acompanha a encosta).
func publish_height_texture() -> void:
	var image := Image.create(_side_x, _side_z, false, Image.FORMAT_RH)
	for gz in _side_z:
		for gx in _side_x:
			image.set_pixel(gx, gz, Color(_heights[gz * _side_x + gx], 0.0, 0.0))
	# O centro do texel i cai exatamente no vértice i da grade.
	var start := _origin - Vector2(cell_size, cell_size) * 0.5
	var size := Vector2(_side_x, _side_z) * cell_size
	RenderingServer.global_shader_parameter_set(&"terrain_height", ImageTexture.create_from_image(image))
	RenderingServer.global_shader_parameter_set(&"terrain_height_rect", Vector4(start.x, start.y, size.x, size.y))


## Mapa de exposição ao vento para o autoload Wind (0 abrigado .. 1 aberto), cobrindo rect() com
## um pixel a cada `step` m. Topos e clareiras expõem; vales, mata fechada e o interior da caverna
## abrigam. O desfiladeiro é um corredor de vento (F14), menos no fundo da ravina.
func build_wind_exposure(step := 3.0) -> Image:
	var area := rect()
	var width := ceili(area.size.x / step)
	var height := ceili(area.size.y / step)
	var image := Image.create(width, height, false, Image.FORMAT_L8)
	for iz in height:
		for ix in width:
			var x := area.position.x + (ix + 0.5) * area.size.x / width
			var z := area.position.y + (iz + 0.5) * area.size.y / height
			var h := get_height(x, z)
			var around := 0.0
			for k in 8:
				var angle := TAU * k / 8.0
				around += get_height(x + cos(angle) * 24.0, z + sin(angle) * 24.0)
			var relief := clampf((h - around / 8.0) / 8.0, -1.0, 1.0)
			var exposure := 0.72 + relief * 0.3 - forest_density(x, z) * 0.45 + smoothstep(25.0, 60.0, h) * 0.2
			var p := Vector2(x, z)
			var frame := ForestLayout.gorge_frame(p) if ForestLayout.near_gorge(p, ForestLayout.GORGE_HALF_WIDTH + 14.0) else Vector2(-1.0, 0.0)
			if frame.x > 0.1 and frame.x < 1.0:
				var channel := 1.0 - smoothstep(ForestLayout.GORGE_HALF_WIDTH, ForestLayout.GORGE_HALF_WIDTH + 6.0, absf(frame.y))
				channel *= smoothstep(0.1, 0.35, frame.x) * (1.0 - smoothstep(0.85, 1.0, frame.x))
				exposure = lerpf(exposure, 1.0, channel)
				exposure *= 1.0 - 0.8 * ForestLayout.ravine_depth(p) / ForestLayout.RAVINE_DEPTH
			exposure *= 1.0 - ForestLayout.cave_interior(p)
			var value := clampf(exposure, 0.05, 1.0)
			image.set_pixel(ix, iz, Color(value, value, value))
	return image


func _setup_noise() -> void:
	_hills.seed = terrain_seed
	_hills.frequency = 0.008
	_hills.fractal_octaves = 4

	_detail.seed = terrain_seed + 1
	_detail.frequency = 0.05
	_detail.fractal_octaves = 2

	_ridges.seed = terrain_seed + 2
	_ridges.frequency = 0.012
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 5

	_warp.seed = terrain_seed + 3
	_warp.frequency = 0.01

	_forest.seed = terrain_seed + 4
	_forest.frequency = 0.02
	_forest.fractal_octaves = 3

	_trail_bounds = Rect2(ForestLayout.TRAIL[0], Vector2.ZERO)
	for point: Vector2 in ForestLayout.TRAIL:
		_trail_bounds = _trail_bounds.expand(point)
	_trail_bounds = _trail_bounds.grow(6.0)


## Altura natural, sem o aplainamento da caverna.
func _raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _hills.get_noise_2d(x, z) * 9.0 + _detail.get_noise_2d(x, z) * 1.0

	# Anel de montanhas em volta do vale, com borda irregular.
	var warp := _warp.get_noise_2d(x, z)
	var edge := p.length() + warp * 28.0
	var mountain := smoothstep(ForestLayout.VALLEY_RADIUS - 15.0, ForestLayout.VALLEY_RADIUS + 70.0, edge)
	# F14: o vale da Pedra Rachada, com um anel mais curto e mais íngreme, e o desfiladeiro que
	# atravessa as montanhas entre os dois (paredões de pedra dos lados do chão).
	if mountain > 0.0 and x > ForestLayout.GORGE_FROM.x - 40.0:
		var second := p.distance_to(ForestLayout.SECOND_VALLEY) + warp * 14.0
		mountain = minf(mountain, smoothstep(ForestLayout.SECOND_VALLEY_RADIUS - 8.0, ForestLayout.SECOND_VALLEY_RADIUS + 35.0, second))
		if ForestLayout.near_gorge(p, ForestLayout.GORGE_HALF_WIDTH + 25.0):
			var gorge := ForestLayout.distance_to_gorge(p) + warp * 3.0
			mountain = minf(mountain, smoothstep(ForestLayout.GORGE_HALF_WIDTH, ForestLayout.GORGE_HALF_WIDTH + 20.0, gorge))
	if mountain > 0.0:
		var ridge := clampf(_ridges.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		h += mountain * mountain * (40.0 + ridge * 70.0)

	# Colina atrás da caverna: íngreme atrás, descida longa e suave na frente.
	var hill_center := ForestLayout.CAVE_CENTER + Vector2(0.0, 20.0)
	var d := p - hill_center
	if d.y < 0.0:
		d.y *= 0.55
	h += exp(-d.length_squared() / (30.0 * 30.0)) * 24.0
	# Paredão logo atrás da caverna: enterra o fundo da rocha na encosta.
	var cave_back := ForestLayout.CAVE_CENTER.y + ForestLayout.CAVE_DEPTH * 0.5
	var lateral := exp(-pow(x - ForestLayout.CAVE_CENTER.x, 2.0) / (16.0 * 16.0))
	h += smoothstep(cave_back - 8.0, cave_back + 4.0, z) * 10.0 * lateral
	return h


func _height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _raw_height(x, z)
	# Trilha levemente afundada.
	if _trail_bounds.has_point(p):
		h -= 0.15 * (1.0 - smoothstep(0.5, 2.5, ForestLayout.distance_to_trail(p)))
	# A ravina do desfiladeiro (F14).
	if ForestLayout.near_gorge(p, ForestLayout.GORGE_HALF_WIDTH + 14.0):
		h -= ForestLayout.ravine_depth(p)
	# Chão da caverna plano, emendando suave com a encosta.
	var flatten := 1.0 - smoothstep(1.0, 1.5, ForestLayout.cave_ellipse(p))
	return lerpf(h, cave_floor_height, flatten)


func _compute_normals_and_splat() -> void:
	_normals.resize(_side_x * _side_z)
	_splat.resize(_side_x * _side_z)
	for gz in _side_z:
		for gx in _side_x:
			var i := gz * _side_x + gx
			var left := _heights[gz * _side_x + maxi(gx - 1, 0)]
			var right := _heights[gz * _side_x + mini(gx + 1, cells_x)]
			var back := _heights[maxi(gz - 1, 0) * _side_x + gx]
			var front := _heights[mini(gz + 1, cells_z) * _side_x + gx]
			var normal := Vector3(left - right, 2.0 * cell_size, back - front).normalized()
			_normals[i] = normal

			var x := _grid_x(gx)
			var z := _grid_z(gz)
			var p := Vector2(x, z)
			var rock := smoothstep(0.84, 0.66, normal.y)
			rock = maxf(rock, smoothstep(28.0, 50.0, _heights[i]) * 0.85)
			var dirt := 0.0
			if _trail_bounds.has_point(p):
				var wobble := _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.6
				dirt = 1.0 - smoothstep(ForestLayout.TRAIL_HALF_WIDTH - 0.3, ForestLayout.TRAIL_HALF_WIDTH + 1.2, ForestLayout.distance_to_trail(p) + wobble)
			var cave := 1.0 - smoothstep(0.85, 1.25, ForestLayout.cave_ellipse(p))
			var ruins := 1.0 - smoothstep(5.0, 9.0, p.distance_to(ForestLayout.RUINS))
			# O chão do desfiladeiro: cascalho e terra (F14).
			if ForestLayout.near_gorge(p, ForestLayout.GORGE_HALF_WIDTH + 3.0) and ForestLayout.in_gorge(p):
				var floor_gravel := 1.0 - smoothstep(ForestLayout.GORGE_HALF_WIDTH - 3.0, ForestLayout.GORGE_HALF_WIDTH + 1.0, absf(ForestLayout.gorge_frame(p).y))
				dirt = maxf(dirt, floor_gravel * (0.78 + _detail.get_noise_2d(x * 2.0, z * 2.0) * 0.2))
			var forest := forest_density(x, z) * (1.0 - dirt)
			# Chão da caverna: terra batida com pedrinhas, sem rocha (evita o salpicado da transição).
			rock *= 1.0 - cave
			_splat[i] = Color(rock, maxf(dirt, maxf(cave, ruins * 0.6)), forest * (1.0 - cave), 0.0)


func _build_meshes() -> void:
	var cells := CHUNK_CELLS
	var row := cells + 1
	var indices := PackedInt32Array()
	for z in cells:
		for x in cells:
			var i := z * row + x
			# Sentido horário visto de cima (face da frente no Godot).
			indices.append_array([i, i + 1, i + row, i + 1, i + row + 1, i + row])

	for cz in cells_z / CHUNK_CELLS:
		for cx in cells_x / CHUNK_CELLS:
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			for z in row:
				for x in row:
					var gx := cx * cells + x
					var gz := cz * cells + z
					var gi := gz * _side_x + gx
					vertices.append(Vector3(_grid_x(gx), _heights[gi], _grid_z(gz)))
					normals.append(_normals[gi])
					colors.append(_splat[gi])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = colors
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var chunk := MeshInstance3D.new()
			chunk.name = "Chunk_%d_%d" % [cx, cz]
			chunk.mesh = mesh
			chunk.material_override = material
			# Camada 2: só o terreno entra no chão das partículas (folhas caindo).
			chunk.layers = 1 | 2
			add_child(chunk)


## Esconde os blocos da malha que ficam inteiros ao norte de `z` (o mundo acabando, R3).
## `z` = -INF mostra tudo.
func set_north_cut(z: float) -> void:
	var span := CHUNK_CELLS * cell_size
	for cz in cells_z / CHUNK_CELLS:
		var hidden := _origin.y + (cz + 1) * span <= z + 0.01
		for cx in cells_x / CHUNK_CELLS:
			(get_node("Chunk_%d_%d" % [cx, cz]) as Node3D).visible = not hidden


func _build_collision() -> void:
	var data := PackedFloat32Array()
	data.resize(_heights.size())
	for i in _heights.size():
		data[i] = _heights[i] / cell_size
	var shape := HeightMapShape3D.new()
	shape.map_width = _side_x
	shape.map_depth = _side_z
	shape.map_data = data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# Escala uniforme: cada célula do heightmap vira cell_size metros. O heightmap fica centrado
	# no nó: o nó vai para o meio do retângulo.
	collision.scale = Vector3.ONE * cell_size
	var center := rect().get_center()
	collision.position = Vector3(center.x, 0.0, center.y)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(collision)
	add_child(body)


func _grid_x(index: int) -> float:
	return _origin.x + index * cell_size


func _grid_z(index: int) -> float:
	return _origin.y + index * cell_size


func _nearest_index(x: float, z: float) -> int:
	var gx := clampi(roundi((x - _origin.x) / cell_size), 0, cells_x)
	var gz := clampi(roundi((z - _origin.y) / cell_size), 0, cells_z)
	return gz * _side_x + gx
