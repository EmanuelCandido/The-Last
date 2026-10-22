class_name Cave
extends Node3D
## Caverna procedural: uma casca de rocha (parede interna e externa) apoiada no terreno,
## com a boca virada para -Z. O chão é o próprio terreno, aplainado pelo Terrain.
##
## Os filhos da cena (fogueira, pele de dormir, gotejamento) usam coordenadas locais:
## a origem é o centro do salão, no nível do chão.

const SEGMENTS_ALONG := 30
const SEGMENTS_AROUND := 28
## A parede desce abaixo do chão nas laterais, para não abrir fresta com o terreno.
const ANGLE_MIN := -0.12 * PI
const ANGLE_MAX := 1.12 * PI

const DRIP_SOUNDS := [
	preload("res://assets/audio/sfx/drip_1.wav"),
	preload("res://assets/audio/sfx/drip_2.wav"),
	preload("res://assets/audio/sfx/drip_3.wav"),
]

@export var rock_material: Material

var _noise := FastNoiseLite.new()
var _drip_timer := 2.0

@onready var _drip: AudioStreamPlayer3D = $Drip


func build(floor_height: float) -> void:
	position = Vector3(ForestLayout.CAVE_CENTER.x, floor_height, ForestLayout.CAVE_CENTER.y)
	_noise.seed = 7
	_noise.frequency = 0.35
	_noise.fractal_octaves = 3

	var mesh := _build_mesh()
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	shell.mesh = mesh
	shell.material_override = rock_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(shell)

	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(collision)
	add_child(body)


func _process(delta: float) -> void:
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(1.5, 6.0)
		_drip.stream = DRIP_SOUNDS.pick_random()
		_drip.pitch_scale = randf_range(0.85, 1.2)
		_drip.position = Vector3(randf_range(-2.0, 2.0), ForestLayout.CAVE_HEIGHT * 0.8, randf_range(-1.0, 5.0))
		_drip.play()


func _build_mesh() -> ArrayMesh:
	var w := ForestLayout.CAVE_HALF_WIDTH
	var h := ForestLayout.CAVE_HEIGHT
	var half_depth := ForestLayout.CAVE_DEPTH * 0.5
	var wall := ForestLayout.CAVE_WALL
	var inner := _shell_grid(w, h, half_depth, 0.45, 0.0)
	var outer := _shell_grid(w + wall, h + wall * 0.85, half_depth + wall, 1.5, 50.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS_ALONG:
		for j in SEGMENTS_AROUND:
			# Parede interna: face da frente virada para dentro do salão.
			_add_quad(st, inner[i][j], inner[i + 1][j], inner[i][j + 1], inner[i + 1][j + 1])
			# Parede externa: ordem invertida, face virada para fora.
			_add_quad(st, outer[i][j], outer[i][j + 1], outer[i + 1][j], outer[i + 1][j + 1])
	# Borda da boca, ligando a parede interna à externa.
	var last := SEGMENTS_ALONG
	for j in SEGMENTS_AROUND:
		_add_quad(st, inner[last][j], outer[last][j], inner[last][j + 1], outer[last][j + 1])
	st.index()
	st.generate_normals()
	return st.commit()


## Grade de pontos de uma parede: [ao longo do eixo (fundo -> boca)][em volta do arco].
func _shell_grid(half_width: float, height: float, back_z: float, roughness: float, noise_offset: float) -> Array:
	var mouth_z := -ForestLayout.CAVE_DEPTH * 0.5
	var grid := []
	for i in SEGMENTS_ALONG + 1:
		var t := float(i) / SEGMENTS_ALONG
		var s := _profile(t)
		var ring := []
		for j in SEGMENTS_AROUND + 1:
			var a := lerpf(ANGLE_MIN, ANGLE_MAX, float(j) / SEGMENTS_AROUND)
			var dir := Vector2(cos(a), sin(a))
			# A boca não é um corte reto: ela avança e recua um pouco em volta do arco.
			var z := lerpf(back_z, mouth_z + _noise.get_noise_1d(a * 40.0) * 0.6, t)
			var p := Vector3(dir.x * half_width * s, dir.y * height * s, z)
			var bump := _noise.get_noise_3d(p.x + noise_offset, p.y, p.z) * roughness
			p.x += dir.x * bump
			p.y += dir.y * bump
			ring.append(p)
		grid.append(ring)
	return grid


## Escala da seção ao longo do eixo: fecha em cúpula no fundo e estreita um pouco na boca.
func _profile(t: float) -> float:
	var grow := sqrt(sin(clampf(t / 0.55, 0.0, 1.0) * PI * 0.5))
	return grow * (1.0 - 0.2 * smoothstep(0.6, 1.0, t))


## Quadrilátero a-b-c-d como dois triângulos (a, b, c) e (b, d, c).
func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(st, a, b, c)
	_add_triangle(st, b, d, c)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# No fecho do fundo vários pontos coincidem; triângulos sem área atrapalham a colisão.
	if (b - a).cross(c - a).length_squared() < 1e-8:
		return
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
