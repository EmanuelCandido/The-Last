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
## A luz do olho acostumado (só de noite) e a última noite aplicada.
var _night_fill: SpotLight3D
var _last_night := -1.0

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
	var shape := mesh.create_trimesh_shape()
	# Casca de face única: sem isto, quem vem pelo lado de trás de um triângulo (a câmera
	# raspando na borda da boca, por exemplo) atravessa a parede.
	shape.backface_collision = true
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(collision)
	add_child(body)

	_dress_bones()
	var smoke := CaveSmoke.new()
	smoke.name = "Smoke"
	smoke.fire = $Campfire
	add_child(smoke)
	# Por fora, acima da boca: a fumaça aparece já subindo pela encosta (de dentro, na boca, os
	# bolos em dither viravam um chuvisco de pontos contra o céu).
	smoke.position = Vector3(0.0, ForestLayout.CAVE_HEIGHT + 1.4, -ForestLayout.CAVE_DEPTH * 0.5 - 1.2)
	_build_night_fill()


func _process(delta: float) -> void:
	var night := Clock.night()
	if _night_fill != null and absf(night - _last_night) > 0.01:
		_last_night = night
		_night_fill.light_energy = Tuning.CAVE_NIGHT_FILL * night
		_night_fill.visible = night > 0.01
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(1.5, 6.0)
		_drip.stream = DRIP_SOUNDS.pick_random()
		_drip.pitch_scale = randf_range(0.85, 1.2)
		_drip.position = Vector3(randf_range(-2.0, 2.0), ForestLayout.CAVE_HEIGHT * 0.8, randf_range(-1.0, 5.0))
		_drip.play()


## De noite, o olho se acostuma: uma luz fraca, fria, sem sombra e sem brilho, só o bastante
## para as silhuetas (a pele, as paredes, o goblin) aparecerem longe do fogo. A luz ambiente da
## sonda quase não mexia na imagem: a rocha é escura e o tonemap esmaga os escuros. É um
## holofote do alto apontado para o chão, aberto: não alcança o teto, e a pintura (o código da
## porta) continua só legível com a fogueira cheia. De dia fica apagada.
func _build_night_fill() -> void:
	_night_fill = SpotLight3D.new()
	_night_fill.name = "NightFill"
	_night_fill.light_color = Tuning.CAVE_NIGHT_FILL_COLOR
	_night_fill.light_specular = 0.0
	_night_fill.spot_range = ForestLayout.CAVE_HEIGHT + 3.0
	_night_fill.spot_angle = 72.0
	_night_fill.spot_attenuation = 0.4
	_night_fill.shadow_enabled = false
	add_child(_night_fill)
	_night_fill.position = Vector3(0.0, ForestLayout.CAVE_HEIGHT - 1.2, 0.5)
	_night_fill.rotation.x = -PI * 0.5


## Os ossos largados no chão (BoneA e BoneB da cena): uma haste com as duas pontas grossas
## (as epífises), no material de osso dos troféus (PropLook), em vez de uma cápsula lisa.
func _dress_bones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2714
	for node_name in [&"BoneA", &"BoneB"]:
		var bone := get_node_or_null(NodePath(node_name)) as MeshInstance3D
		if bone != null:
			bone.mesh = _bone_mesh(rng, rng.randf_range(0.26, 0.34))


## Osso longo ao longo de Y, centrado na origem: haste um pouco torta e mais fina no meio,
## e em cada ponta dois côndilos achatados.
static func _bone_mesh(rng: RandomNumberGenerator, length: float) -> ArrayMesh:
	var builder := TreeBuilder.Builder.new()
	var st := builder.tool_for(PropLook.bone())
	var half := length * 0.5
	var bend := Vector3(rng.randf_range(-0.01, 0.01), 0.0, rng.randf_range(-0.01, 0.01))
	var points := [Vector3.DOWN * half, Vector3.DOWN * half * 0.3 + bend, Vector3.UP * half * 0.3 + bend, Vector3.UP * half]
	var radii := [0.022, 0.015, 0.015, 0.022]
	for i in points.size() - 1:
		TreeBuilder.add_branch(st, points[i], points[i + 1], radii[i], radii[i + 1], 7)
	for end: Vector3 in [Vector3.DOWN * half, Vector3.UP * half]:
		var tip := end + end.normalized() * 0.008
		for side: float in [-1.0, 1.0]:
			var knob := SphereMesh.new()
			knob.radius = 0.02
			knob.height = 0.032
			knob.radial_segments = 7
			knob.rings = 4
			st.append_from(knob, 0, Transform3D(Basis.IDENTITY, tip + Vector3(side * 0.013, 0.0, 0.0)))
	return builder.commit()


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
