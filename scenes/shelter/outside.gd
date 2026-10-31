class_name Outside
extends Node3D
## Lá fora (§8, Final 2): a escada que sobe da saída blindada do Abrigo 9 e a rua de Vilarrasa,
## abandonada sob a mesma neblina da floresta. No fim da rua, a vitrine da ótica: chegando perto e
## olhando para ela, aparece no vidro o rosto de Ari (ari_reflection.png), a única vez no jogo. Ao
## longe, um sino e vozes: a cidade voltou a ter gente.
##
## Filho do Shelter, no espaço dele, montado só quando a saída abre (Shelter.build_outside). Tudo
## por código, com uma malha por material e colisão em caixas, como o Abrigo. A câmera de Ari
## troca para `environment` (com neblina), que adensa conforme ele sobe.
##
##   z = -3,5   a porta blindada; a escada sobe 5 m até z = -16,5
##   z = -19,5  o muro de arrimo com a porta para a rua (y = 5)
##   z = -44    a rua cruza outra; z = -50, a fachada da ótica fechando a rua

const WIND := preload("res://assets/audio/ambience/wind_loop.wav")
const LEAVES := preload("res://assets/audio/real/leaves_wind_loop.wav")
const BELL := preload("res://assets/audio/real/church_bell_toll.ogg")
const CROWD := preload("res://assets/audio/ambience/crowd_loop.wav")
const FACE := preload("res://assets/textures/ari_reflection.png")
const STAIR_FROM := Vector2(-3.6, 0.0)
const STAIR_TO := Vector2(-16.5, 5.0)
const STREET_Y := 5.0
const WALL_Z := -19.5
const CROSS_Z := -44.0
const FACADE_Z := -50.0
const GLASS_Z := -50.1
## Onde o sino e as vozes ficam (longe, à esquerda, depois da neblina).
const BELL_AT := Vector3(-150.0, 40.0, -120.0)
const CROWD_AT := Vector3(-60.0, 7.0, -47.0)
## O reflexo um pouco maior que o natural, para o rosto ler no vidro escuro.
const FACE_SIZE := Vector2(0.72, 0.9)
## O vulto de respirador (F14) atravessa a rua de cruzamento, de uma ponta à outra.
const WALKER_FROM := Vector3(-17.0, STREET_Y, CROSS_Z - 2.5)
const WALKER_TO := Vector3(17.0, STREET_Y, CROSS_Z - 2.5)

## O ar de fora: o mesmo do Abrigo, com a neblina e o céu cinza.
var environment: Environment
## Quanto do rosto aparece agora (0..1) e se ele já ficou visto o bastante.
var reflection := 0.0
var reflection_seen := false

var _surfaces := {}
var _body: StaticBody3D
var _face: MeshInstance3D
var _face_material: StandardMaterial3D
var _light: DirectionalLight3D
var _wind: AudioStreamPlayer
var _leaves: AudioStreamPlayer
var _bell: AudioStreamPlayer3D
var _crowd: AudioStreamPlayer3D
var _bell_timer := 0.0
var _seen_for := 0.0
var _running := false
var _ari: Ari
var _walker: Node3D
var _walker_legs: Array[Node3D] = []
var _walker_phase := 0.0
var _walker_look := 0.0
var _walker_done := false


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Walls"
	add_child(_body)
	_build_stairs()
	_build_street()
	_build_buildings()
	_build_shop()
	_build_props()
	_commit()
	_build_walker()
	_build_air()
	set_process(false)


## Ari saiu pela porta: o ar de fora entra na câmera e o som da rua começa.
func start(ari: Ari) -> void:
	_ari = ari
	_running = true
	ari.camera.environment = environment
	_light.visible = true
	_wind.play(randf() * WIND.get_length())
	_leaves.play(randf() * LEAVES.get_length())
	set_process(true)


## Quanto Ari já subiu (0 na porta blindada, 1 na rua).
func progress() -> float:
	if _ari == null:
		return 0.0
	var z := to_local(_ari.global_position).z
	return clampf((STAIR_FROM.x - z) / (STAIR_FROM.x - WALL_Z + 2.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if _ari == null or not is_instance_valid(_ari):
		return
	var p := progress()
	environment.fog_density = Tuning.OUTSIDE_FOG_DENSITY * pow(p, 0.7)
	environment.ambient_light_energy = lerpf(0.3, 0.9, p)
	_wind.volume_db = lerpf(-34.0, -10.0, p)
	_leaves.volume_db = lerpf(-50.0, -20.0, smoothstep(0.7, 1.0, p))
	# O sino e as vozes, quando Ari já está na rua.
	var walked := WALL_Z - to_local(_ari.global_position).z
	if walked > Tuning.OUTSIDE_BELL_AFTER:
		if not _crowd.playing:
			_crowd.play(randf() * CROWD.get_length())
		_crowd.volume_db = move_toward(_crowd.volume_db, -2.0, delta * 3.0)
		_bell_timer -= delta
		if _bell_timer <= 0.0:
			# A gravação tem três badaladas: emendada no fim, o sino dobra sem parar no ritmo dele.
			_bell_timer = BELL.get_length()
			_bell.play()
	_update_walker(delta, walked)
	_update_reflection(delta)


## O vulto atravessa a rua quando Ari sai na calçada. Longe o bastante, para no meio e olha para
## ela; depois segue e some na neblina do outro lado.
func _update_walker(delta: float, walked: float) -> void:
	if _walker_done or walked < Tuning.OUTSIDE_WALKER_AFTER:
		return
	_walker.visible = true
	var to_ari := to_local(_ari.global_position) - _walker.position
	to_ari.y = 0.0
	var stopping := _walker.position.x >= 0.0 and _walker_look < Tuning.OUTSIDE_WALKER_LOOK
	if stopping and to_ari.length() > Tuning.OUTSIDE_WALKER_KEEP_AWAY:
		_walker_look += delta
		_walker.rotation.y = lerp_angle(_walker.rotation.y, atan2(to_ari.x, to_ari.z), delta * 2.0)
		_swing_legs(0.0)
		return
	_walker.position = _walker.position.move_toward(WALKER_TO, Tuning.OUTSIDE_WALKER_SPEED * delta)
	_walker.rotation.y = lerp_angle(_walker.rotation.y, PI * 0.5, delta * 2.0)
	_walker_phase += delta * Tuning.OUTSIDE_WALKER_SPEED * 3.6
	_swing_legs(sin(_walker_phase) * 0.4)
	if _walker.position.is_equal_approx(WALKER_TO):
		_walker.visible = false
		_walker_done = true


func _swing_legs(angle: float) -> void:
	for i in _walker_legs.size():
		_walker_legs[i].rotation.x = angle if i == 0 else -angle


## O rosto no vidro: o reflexo fica atrás do vidro, no lugar do espelho de Ari, e só aparece de
## perto e olhando para a vitrine.
func _update_reflection(delta: float) -> void:
	var eye := to_local(_ari.camera.global_position)
	_face.position = Vector3(eye.x, eye.y - 0.06, 2.0 * GLASS_Z - eye.z)
	var distance := eye.z - GLASS_Z
	var forward := _ari.camera.global_basis * Vector3.FORWARD
	var facing := clampf((forward.dot(-global_basis.z) - 0.75) / 0.2, 0.0, 1.0)
	var near := 1.0 - smoothstep(Tuning.REFLECTION_DISTANCE - 1.2, Tuning.REFLECTION_DISTANCE, distance)
	var target := near * facing if distance > 0.0 and absf(eye.x) < 1.8 else 0.0
	reflection = move_toward(reflection, target, delta * 0.6)
	_face_material.albedo_color.a = reflection * 0.92
	_face.visible = reflection > 0.001
	if reflection > 0.8:
		_seen_for += delta
		reflection_seen = _seen_for >= Tuning.REFLECTION_HOLD


# --- A escada --------------------------------------------------------------------------------

func _build_stairs() -> void:
	var run := STAIR_FROM.x - STAIR_TO.x
	var rise := STAIR_TO.y - STAIR_FROM.y
	var angle := atan2(rise, run)
	var length := Vector2(run, rise).length()
	var normal := Vector3(0.0, cos(angle), sin(angle))
	var middle := Vector3(0.0, rise * 0.5, (STAIR_FROM.x + STAIR_TO.x) * 0.5)
	# A rampa é a colisão (Ari não sobe degrau); os degraus são só desenho, por cima dela.
	_box(Vector3(1.8, 0.2, length + 0.2), middle - normal * 0.1, &"floor", true, Vector3(angle, 0.0, 0.0), &"stone")
	var steps := 28
	for i in steps:
		var z := STAIR_FROM.x - (i + 0.5) * run / steps
		var top := (i + 1) * rise / steps
		_box(Vector3(1.8, 0.4, run / steps), Vector3(0.0, top - 0.2, z), &"concrete", false)
		_box(Vector3(1.8, 0.03, 0.04), Vector3(0.0, top - 0.01, z + run / steps * 0.5 - 0.02), &"metal", false)
	_box(Vector3(1.8, 0.2, length + 0.2), middle + normal * 2.7, &"ceiling", false, Vector3(angle, 0.0, 0.0))
	# O patamar de cima, até o muro da rua.
	_box(Vector3(1.8, 0.2, STAIR_TO.x - WALL_Z), Vector3(0.0, STREET_Y - 0.1, (STAIR_TO.x + WALL_Z) * 0.5), &"floor", true, Vector3.ZERO, &"stone")
	_box(Vector3(1.8, 0.2, STAIR_TO.x - WALL_Z + 1.0), Vector3(0.0, STREET_Y + 2.6, (STAIR_TO.x + WALL_Z) * 0.5 + 0.5), &"ceiling", false)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.2, 8.0, STAIR_FROM.x - WALL_Z + 0.1), Vector3(side, 3.6, (STAIR_FROM.x + WALL_Z) * 0.5), &"concrete")
	ShelterLook.rod(self, Vector3(0.82, 0.9, STAIR_FROM.x), Vector3(0.82, 0.9 + rise, STAIR_TO.x), 0.02, &"metal")
	# Uma lâmpada fraca no meio da escada; lá em cima, a luz cinza da rua.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.62, 0.7, 0.66)
	lamp.light_energy = 0.35
	lamp.omni_range = 5.0
	lamp.position = Vector3(0.0, rise * 0.5 + 2.2, (STAIR_FROM.x + STAIR_TO.x) * 0.5)
	add_child(lamp)
	ShelterLook.box(self, Vector3(0.2, 0.05, 0.1), lamp.position + Vector3(0.0, 0.25, 0.0), &"white")
	var daylight := OmniLight3D.new()
	daylight.light_color = Color(0.7, 0.74, 0.78)
	daylight.light_energy = 0.8
	daylight.omni_range = 7.0
	daylight.position = Vector3(0.0, STREET_Y + 1.6, WALL_Z + 0.6)
	add_child(daylight)


# --- A rua ----------------------------------------------------------------------------------

func _build_street() -> void:
	_box(Vector3(12.0, 0.2, WALL_Z - CROSS_Z), Vector3(0.0, STREET_Y - 0.1, (WALL_Z + CROSS_Z) * 0.5), &"cobble", true, Vector3.ZERO, &"stone")
	_box(Vector3(32.0, 0.2, 6.2), Vector3(0.0, STREET_Y - 0.1, CROSS_Z - 3.0), &"cobble", true, Vector3.ZERO, &"stone")
	# As calçadas: uma faixa mais escura junto das casas.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(1.4, 0.02, WALL_Z - CROSS_Z), Vector3(side * 5.3, STREET_Y + 0.01, (WALL_Z + CROSS_Z) * 0.5), &"floor", false)
	# O muro de arrimo, com a porta da escada e o nome apagado do Abrigo.
	_box(Vector3(5.3, 7.0, 0.4), Vector3(-3.35, STREET_Y + 3.5, WALL_Z - 0.2), &"concrete")
	_box(Vector3(5.3, 7.0, 0.4), Vector3(3.35, STREET_Y + 3.5, WALL_Z - 0.2), &"concrete")
	_box(Vector3(1.4, 4.8, 0.4), Vector3(0.0, STREET_Y + 4.6, WALL_Z - 0.2), &"concrete")
	ShelterLook.label(self, "ABRIGO 9", Vector3(0.0, STREET_Y + 2.9, WALL_Z - 0.41), 0.28, Color(0.42, 0.42, 0.4), false, PI)
	# A porta de fora, de chapa, aberta para o lado e enferrujada.
	_box(Vector3(0.05, 2.15, 1.35), Vector3(-1.2, STREET_Y + 1.08, WALL_Z - 1.0), &"rust", false, Vector3(0.0, 0.25, 0.0))
	# Paredes invisíveis: Ari não sai da rua nem passa as barricadas.
	for wall: Array in [
		[Vector3(0.3, 6.0, WALL_Z - CROSS_Z), Vector3(-5.9, STREET_Y + 3.0, (WALL_Z + CROSS_Z) * 0.5)],
		[Vector3(0.3, 6.0, WALL_Z - CROSS_Z), Vector3(5.9, STREET_Y + 3.0, (WALL_Z + CROSS_Z) * 0.5)],
		[Vector3(7.0, 6.0, 0.3), Vector3(-9.5, STREET_Y + 3.0, CROSS_Z + 0.1)],
		[Vector3(7.0, 6.0, 0.3), Vector3(9.5, STREET_Y + 3.0, CROSS_Z + 0.1)],
		[Vector3(0.3, 6.0, 7.0), Vector3(-13.0, STREET_Y + 3.0, CROSS_Z - 3.0)],
		[Vector3(0.3, 6.0, 7.0), Vector3(13.0, STREET_Y + 3.0, CROSS_Z - 3.0)],
	]:
		_collider(wall[0], wall[1])


func _build_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2039
	var names := ["PADARIA", "FARMÁCIA", "ARMARINHO", "BAR DO NICO", "SAPATARIA", "CORREIOS"]
	var sign := 0
	for side: float in [-1.0, 1.0]:
		var z := WALL_Z - 0.4
		while z > CROSS_Z + 0.5:
			var length := minf(rng.randf_range(5.0, 8.0), z - CROSS_Z)
			var height := rng.randf_range(7.0, 13.0)
			var center := Vector3(side * 9.0, STREET_Y + height * 0.5, z - length * 0.5)
			_box(Vector3(6.0, height, length - 0.1), center, &"plaster")
			# A cornija no alto e as janelas vazias, andar por andar.
			_box(Vector3(6.3, 0.25, length), Vector3(side * 9.0, STREET_Y + height - 0.3, center.z), &"concrete", false)
			var face := side * 5.98
			var floors := int((height - 1.5) / 3.0)
			var columns := maxi(int(length / 2.2), 1)
			for f in floors:
				for c in columns:
					var wz := z - (c + 0.5) * length / columns
					var wy := STREET_Y + 1.6 + f * 3.0 + (1.3 if f > 0 else 0.0)
					if f == 0 and c == columns / 2:
						# A porta do térreo, com a placa da loja em cima.
						_box(Vector3(0.06, 2.2, 1.1), Vector3(face, STREET_Y + 1.1, wz), &"window", false)
						if sign < names.size():
							ShelterLook.label(self, names[sign], Vector3(face - side * 0.04, STREET_Y + 2.7, wz), 0.16, Color(0.5, 0.48, 0.44), false, -side * PI * 0.5)
							sign += 1
						continue
					var broken := rng.randf() < 0.3
					_box(Vector3(0.06, 1.3, 0.9), Vector3(face, wy, wz), &"rubber" if broken else &"window", false)
					_box(Vector3(0.1, 0.06, 1.0), Vector3(face, wy - 0.68, wz), &"concrete", false)
			z -= length
	# O pinheiral na encosta, por cima do muro: só a silhueta na neblina.
	for i in 9:
		var x := -14.0 + i * 3.6 + rng.randf_range(-1.0, 1.0)
		var height := rng.randf_range(7.0, 11.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = height * 0.22
		cone.height = height
		cone.radial_segments = 7
		cone.rings = 1
		_append(cone, Transform3D(Basis.IDENTITY, Vector3(x, STREET_Y + 7.0 + height * 0.5, WALL_Z + rng.randf_range(2.0, 7.0))), &"pine")


func _build_shop() -> void:
	# O prédio que fecha a rua, com a ótica no térreo: a fachada tem o vão da vitrine.
	var back := FACADE_Z - 2.3
	var front := (FACADE_Z + back) * 0.5
	_box(Vector3(32.0, 12.0, 7.7), Vector3(0.0, STREET_Y + 6.0, back - 3.85), &"plaster")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(14.25, 12.0, 2.3), Vector3(side * 8.875, STREET_Y + 6.0, front), &"plaster")
	_box(Vector3(3.5, 9.4, 2.3), Vector3(0.0, STREET_Y + 7.3, front), &"plaster")
	_box(Vector3(32.0, 0.3, 0.3), Vector3(0.0, STREET_Y + 3.1, FACADE_Z + 0.1), &"concrete", false)
	ShelterLook.label(self, "ÓTICA SÃO BRÁS", Vector3(0.0, STREET_Y + 2.8, FACADE_Z + 0.02), 0.2, Color(0.55, 0.53, 0.48))
	# A vitrine: o vidro sujo na frente, a loja vazia e escura atrás (é o escuro que faz o reflexo).
	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2, 2.2)
	glass.mesh = quad
	glass.position = Vector3(0.0, STREET_Y + 1.45, GLASS_Z)
	glass.material_override = ShelterLook.material(&"glass")
	add_child(glass)
	# A loja por dentro: escura dos lados, no teto e no fundo.
	_box(Vector3(3.5, 2.6, 0.08), Vector3(0.0, STREET_Y + 1.3, back + 0.05), &"rubber", false)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.05, 2.6, 2.3), Vector3(side * 1.72, STREET_Y + 1.3, front), &"rubber", false)
	_box(Vector3(3.5, 0.05, 2.3), Vector3(0.0, STREET_Y + 2.58, front), &"rubber", false)
	_box(Vector3(3.5, 0.35, 2.1), Vector3(0.0, STREET_Y + 0.17, (GLASS_Z + back) * 0.5), &"dark_metal", false)
	for x: float in [-1.68, 1.68]:
		_box(Vector3(0.12, 2.6, 0.2), Vector3(x, STREET_Y + 1.3, FACADE_Z - 0.05), &"dark_metal", false)
	# Uma armação de óculos esquecida no balcão.
	ShelterLook.box(self, Vector3(0.14, 0.04, 0.01), Vector3(0.3, STREET_Y + 0.38, GLASS_Z - 0.6), &"dark_metal")
	_collider(Vector3(3.6, 3.0, 0.3), Vector3(0.0, STREET_Y + 1.5, GLASS_Z - 0.15))
	# O reflexo: o rosto de Ari, do outro lado do vidro, onde fica o espelho dele.
	_face = MeshInstance3D.new()
	var face_quad := QuadMesh.new()
	face_quad.size = FACE_SIZE
	_face.mesh = face_quad
	_face_material = StandardMaterial3D.new()
	_face_material.albedo_texture = FACE
	_face_material.albedo_color = Color(0.85, 0.87, 0.86, 0.0)
	_face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_face.material_override = _face_material
	_face.visible = false
	add_child(_face)


func _build_props() -> void:
	# Postes apagados, dois carros abandonados e as barricadas da rua de cruzamento.
	for z: float in [-24.0, -33.0, -42.0]:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * 4.7, STREET_Y, z + side * 2.0)
			_box(Vector3(0.12, 4.2, 0.12), at + Vector3(0.0, 2.1, 0.0), &"dark_metal", false)
			_box(Vector3(0.7, 0.08, 0.12), at + Vector3(-side * 0.3, 4.2, 0.0), &"dark_metal", false)
	for car: Array in [[Vector3(-3.6, 0.0, -28.0), 0.1], [Vector3(3.4, 0.0, -38.5), -0.2]]:
		var at: Vector3 = car[0] + Vector3(0.0, STREET_Y, 0.0)
		var yaw: float = car[1]
		_box(Vector3(1.7, 0.75, 4.0), at + Vector3(0.0, 0.55, 0.0), &"rust", true, Vector3(0.0, yaw, 0.0))
		_box(Vector3(1.5, 0.6, 2.0), at + Vector3(0.0, 1.2, -0.2), &"rust", false, Vector3(0.0, yaw, 0.0))
		_box(Vector3(1.52, 0.4, 1.6), at + Vector3(0.0, 1.22, -0.2), &"window", false, Vector3(0.0, yaw, 0.0))
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var at := Vector3(side * (12.6 + i % 2 * 0.6), STREET_Y + 0.35 + (i / 2) * 0.5, CROSS_Z - 1.0 - i * 0.9)
			_box(Vector3(1.0, 0.7, 0.9), at, &"plaster" if i % 3 else &"rust", false, Vector3(0.0, i * 0.4, 0.1))
	# Folhas e papéis acumulados nos cantos.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in 40:
		var at := Vector3(rng.randf_range(-5.6, 5.6), STREET_Y + 0.006, rng.randf_range(CROSS_Z, WALL_Z - 1.0))
		if absf(at.x) < 4.0 and rng.randf() < 0.6:
			at.x = signf(at.x) * rng.randf_range(4.0, 5.6)
		ShelterLook.box(self, Vector3(0.2, 0.004, 0.26), at, &"paper" if i % 4 == 0 else &"blanket", Vector3(0.0, rng.randf() * TAU, 0.0))


## Macacão claro, capuz e o respirador com os dois filtros na frente da boca: a máscara que os
## orcs copiam na floresta. As pernas giram no quadril.
func _build_walker() -> void:
	_walker = Node3D.new()
	_walker.name = "Walker"
	_walker.position = WALKER_FROM
	_walker.rotation.y = PI * 0.5
	_walker.visible = false
	add_child(_walker)
	ShelterLook.box(_walker, Vector3(0.44, 0.62, 0.26), Vector3(0.0, 1.2, 0.0), &"plastic")
	ShelterLook.sphere(_walker, 0.13, Vector3(0.0, 1.64, 0.0), &"plastic")
	ShelterLook.box(_walker, Vector3(0.2, 0.06, 0.04), Vector3(0.0, 1.69, 0.12), &"window")
	ShelterLook.box(_walker, Vector3(0.12, 0.1, 0.08), Vector3(0.0, 1.57, 0.12), &"rubber")
	for side: float in [-1.0, 1.0]:
		ShelterLook.cylinder(_walker, 0.05, 0.07, Vector3(side * 0.085, 1.55, 0.15), &"rubber", Vector3(PI * 0.5, 0.0, 0.0))
		ShelterLook.box(_walker, Vector3(0.1, 0.56, 0.12), Vector3(side * 0.28, 1.17, 0.0), &"plastic")
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.11, 0.89, 0.0)
		_walker.add_child(hip)
		ShelterLook.box(hip, Vector3(0.15, 0.87, 0.16), Vector3(0.0, -0.44, 0.0), &"plastic")
		_walker_legs.append(hip)


func _build_air() -> void:
	var shelter := get_parent() as Shelter
	environment = shelter.environment.duplicate() if shelter != null else Environment.new()
	# O céu nublado: cinza, um pouco mais claro no horizonte, onde a neblina encosta.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.46, 0.49, 0.52)
	sky_material.sky_horizon_color = Color(0.56, 0.58, 0.6)
	sky_material.ground_horizon_color = Color(0.56, 0.58, 0.6)
	sky_material.ground_bottom_color = Color(0.3, 0.31, 0.32)
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_color = Color(0.56, 0.6, 0.63)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.56, 0.58, 0.6)
	environment.fog_density = 0.0
	environment.fog_sky_affect = 1.0
	environment.fog_aerial_perspective = 0.2
	environment.ssao_enabled = false
	# A luz do dia nublado: só para a camada do Abrigo (a floresta tem o sol dela).
	_light = DirectionalLight3D.new()
	_light.light_color = Color(0.74, 0.78, 0.82)
	_light.light_energy = 0.55
	_light.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(28.0), 0.0)
	_light.shadow_enabled = true
	_light.light_cull_mask = Shelter.LAYER
	_light.visible = false
	add_child(_light)
	_wind = _sound(WIND, -40.0)
	_leaves = _sound(LEAVES, -50.0)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = BELL
	_bell.bus = &"Master"
	_bell.position = BELL_AT
	_bell.unit_size = 90.0
	_bell.volume_db = -6.0
	add_child(_bell)
	_crowd = AudioStreamPlayer3D.new()
	_crowd.stream = CROWD
	_crowd.bus = &"Master"
	_crowd.position = CROWD_AT
	_crowd.unit_size = 25.0
	_crowd.volume_db = -30.0
	add_child(_crowd)
	_crowd.finished.connect(_crowd.play)


func _sound(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Master"
	player.volume_db = volume
	add_child(player)
	player.finished.connect(player.play)
	return player


## Caixa da arquitetura: entra na malha do material e, com `collide`, ganha colisão.
func _box(size: Vector3, center: Vector3, material_name: StringName, collide := true, rotation := Vector3.ZERO, surface := &"") -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var at := Transform3D(Basis.from_euler(rotation), center)
	_append(mesh, at, material_name)
	if collide:
		var shape := _collider(size, center)
		shape.basis = at.basis
		if surface != &"":
			shape.set_meta(&"surface", surface)


func _collider(size: Vector3, center: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	_body.add_child(shape)
	return shape


func _append(mesh: Mesh, at: Transform3D, material_name: StringName) -> void:
	if not _surfaces.has(material_name):
		_surfaces[material_name] = SurfaceTool.new()
	(_surfaces[material_name] as SurfaceTool).append_from(mesh, 0, at)


func _commit() -> void:
	for material_name: StringName in _surfaces:
		var instance := MeshInstance3D.new()
		instance.name = "Mesh_%s" % material_name
		instance.mesh = (_surfaces[material_name] as SurfaceTool).commit()
		instance.material_override = ShelterLook.material(material_name)
		add_child(instance)
	_surfaces.clear()
