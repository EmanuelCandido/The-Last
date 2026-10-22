class_name Terrain
extends Node3D
## Terreno gerado por ruído: vale com colinas, anel de montanhas e a encosta da caverna.
##
## Gera a malha em blocos (o culling descarta o que está fora da câmera), a colisão
## por HeightMapShape3D e guarda a grade de alturas para consultas rápidas.
## A cor do vértice leva os pesos das texturas: R rocha, G terra, B chão de floresta.

## Células por lado da grade.
const RESOLUTION := 256
## Blocos de malha por lado.
const CHUNKS := 8

@export var terrain_seed := 1337
@export var material: Material

## Altura do chão dentro da caverna (o terreno é aplainado nela).
var cave_floor_height := 0.0
var cell_size := ForestLayout.TERRAIN_SIZE / RESOLUTION

var _side := RESOLUTION + 1
var _half := ForestLayout.TERRAIN_SIZE * 0.5
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

	_heights.resize(_side * _side)
	for gz in _side:
		for gx in _side:
			_heights[gz * _side + gx] = _height_at(_grid_x(gx), _grid_x(gz))
	_compute_normals_and_splat()
	_build_meshes()
	_build_collision()


## Altura do terreno em (x, z), interpolada igual aos triângulos da malha.
func get_height(x: float, z: float) -> float:
	var fx := clampf((x + _half) / cell_size, 0.0, RESOLUTION - 0.001)
	var fz := clampf((z + _half) / cell_size, 0.0, RESOLUTION - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * _side + ix
	var h00 := _heights[i]
	var h10 := _heights[i + 1]
	var h01 := _heights[i + _side]
	var h11 := _heights[i + _side + 1]
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func get_normal(x: float, z: float) -> Vector3:
	return _normals[_nearest_index(x, z)]


## Pesos das texturas no ponto (R rocha, G terra, B floresta).
func get_splat(x: float, z: float) -> Color:
	return _splat[_nearest_index(x, z)]


## Tipo de chão para sons de passos: &"stone", &"dirt" ou &"grass".
func surface_at(world_position: Vector3) -> StringName:
	var p := Vector2(world_position.x, world_position.z)
	if ForestLayout.cave_interior(p) > 0.3:
		return &"stone"
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
	return density


## Publica a grade de alturas como textura global (terrain_height + terrain_height_rect),
## para shaders encostarem vértices no chão (a grama acompanha a encosta).
func publish_height_texture() -> void:
	var image := Image.create(_side, _side, false, Image.FORMAT_RH)
	for gz in _side:
		for gx in _side:
			image.set_pixel(gx, gz, Color(_heights[gz * _side + gx], 0.0, 0.0))
	# O centro do texel i cai exatamente no vértice i da grade.
	var start := -_half - cell_size * 0.5
	var size := _side * cell_size
	RenderingServer.global_shader_parameter_set(&"terrain_height", ImageTexture.create_from_image(image))
	RenderingServer.global_shader_parameter_set(&"terrain_height_rect", Vector4(start, start, size, size))


## Mapa de exposição ao vento para o autoload Wind (0 abrigado .. 1 aberto).
## Topos e clareiras expõem; vales, mata fechada e o interior da caverna abrigam.
func build_wind_exposure(resolution := 128) -> Image:
	var image := Image.create(resolution, resolution, false, Image.FORMAT_L8)
	var step := ForestLayout.TERRAIN_SIZE / resolution
	for iz in resolution:
		for ix in resolution:
			var x := -_half + (ix + 0.5) * step
			var z := -_half + (iz + 0.5) * step
			var h := get_height(x, z)
			var around := 0.0
			for k in 8:
				var angle := TAU * k / 8.0
				around += get_height(x + cos(angle) * 24.0, z + sin(angle) * 24.0)
			var relief := clampf((h - around / 8.0) / 8.0, -1.0, 1.0)
			var exposure := 0.72 + relief * 0.3 - forest_density(x, z) * 0.45 + smoothstep(25.0, 60.0, h) * 0.2
			exposure *= 1.0 - ForestLayout.cave_interior(Vector2(x, z))
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
	var edge := p.length() + _warp.get_noise_2d(x, z) * 28.0
	var mountain := smoothstep(ForestLayout.VALLEY_RADIUS - 15.0, ForestLayout.VALLEY_RADIUS + 70.0, edge)
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
	# Chão da caverna plano, emendando suave com a encosta.
	var flatten := 1.0 - smoothstep(1.0, 1.5, ForestLayout.cave_ellipse(p))
	return lerpf(h, cave_floor_height, flatten)


func _compute_normals_and_splat() -> void:
	_normals.resize(_side * _side)
	_splat.resize(_side * _side)
	for gz in _side:
		for gx in _side:
			var i := gz * _side + gx
			var left := _heights[gz * _side + maxi(gx - 1, 0)]
			var right := _heights[gz * _side + mini(gx + 1, RESOLUTION)]
			var back := _heights[maxi(gz - 1, 0) * _side + gx]
			var front := _heights[mini(gz + 1, RESOLUTION) * _side + gx]
			var normal := Vector3(left - right, 2.0 * cell_size, back - front).normalized()
			_normals[i] = normal

			var x := _grid_x(gx)
			var z := _grid_x(gz)
			var p := Vector2(x, z)
			var rock := smoothstep(0.84, 0.66, normal.y)
			rock = maxf(rock, smoothstep(28.0, 50.0, _heights[i]) * 0.85)
			var dirt := 0.0
			if _trail_bounds.has_point(p):
				var wobble := _detail.get_noise_2d(x * 3.0, z * 3.0) * 0.6
				dirt = 1.0 - smoothstep(ForestLayout.TRAIL_HALF_WIDTH - 0.3, ForestLayout.TRAIL_HALF_WIDTH + 1.2, ForestLayout.distance_to_trail(p) + wobble)
			var cave := 1.0 - smoothstep(0.85, 1.25, ForestLayout.cave_ellipse(p))
			var ruins := 1.0 - smoothstep(5.0, 9.0, p.distance_to(ForestLayout.RUINS))
			var forest := forest_density(x, z) * (1.0 - dirt)
			# Chão da caverna: terra batida com pedrinhas, sem rocha (evita o salpicado da transição).
			rock *= 1.0 - cave
			_splat[i] = Color(rock, maxf(dirt, maxf(cave, ruins * 0.6)), forest * (1.0 - cave), 0.0)


func _build_meshes() -> void:
	var cells := RESOLUTION / CHUNKS
	var row := cells + 1
	var indices := PackedInt32Array()
	for z in cells:
		for x in cells:
			var i := z * row + x
			# Sentido horário visto de cima (face da frente no Godot).
			indices.append_array([i, i + 1, i + row, i + 1, i + row + 1, i + row])

	for cz in CHUNKS:
		for cx in CHUNKS:
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var colors := PackedColorArray()
			for z in row:
				for x in row:
					var gx := cx * cells + x
					var gz := cz * cells + z
					var gi := gz * _side + gx
					vertices.append(Vector3(_grid_x(gx), _heights[gi], _grid_x(gz)))
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


func _build_collision() -> void:
	var data := PackedFloat32Array()
	data.resize(_heights.size())
	for i in _heights.size():
		data[i] = _heights[i] / cell_size
	var shape := HeightMapShape3D.new()
	shape.map_width = _side
	shape.map_depth = _side
	shape.map_data = data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# Escala uniforme: cada célula do heightmap vira cell_size metros.
	collision.scale = Vector3.ONE * cell_size
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(collision)
	add_child(body)


func _grid_x(index: int) -> float:
	return -_half + index * cell_size


func _nearest_index(x: float, z: float) -> int:
	var gx := clampi(roundi((x + _half) / cell_size), 0, RESOLUTION)
	var gz := clampi(roundi((z + _half) / cell_size), 0, RESOLUTION)
	return gz * _side + gx
