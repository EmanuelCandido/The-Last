class_name Shelter
extends Node3D
## O Abrigo 9 (§6.1), o mundo real: a ala do hospital enterrada na encosta. Fica no mesmo
## mundo da floresta, 2 km abaixo (Tuning.SHELTER_ORIGIN), então ir e voltar não regera nada.
## Montado por código: concreto, tubos, luz de emergência verde e poeira, sem neblina.
##
##                    [Saída blindada]
##                           |
##     [Almoxarifado]---- Corredor (20 m) ----[Estação de recarga]
##                      |    sensor térmico (meio)
##                 [Sala 2714]          [Sala de controle] (cartão)
##
## Coordenadas locais: o corredor corre em X (de -10 a 10), as salas de baixo ficam em +Z.
## Tudo o que se vê aqui fica na camada visual LAYER, que o sol da floresta não ilumina.
## Fora de uso (sem flash nem visita), o Abrigo fica escondido e parado (set_active).

## Camada visual do Abrigo (a 11ª). O Sun da floresta tira esta camada do light_cull_mask.
const LAYER := 1 << 10
const HEIGHT := 2.7
const WALL := 0.2
const DOOR_HEIGHT := 2.05
const AMBIENT := preload("res://assets/audio/ambience/shelter_loop.wav")
const ROOMS := {
	&"room": Rect2(-7.0, 1.0, 5.0, 6.0),
	&"corridor": Rect2(-10.0, -1.0, 20.0, 2.0),
	&"store": Rect2(-14.0, -2.5, 4.0, 5.0),
	&"dock": Rect2(10.0, -1.5, 3.0, 3.0),
	&"control": Rect2(2.0, 1.0, 6.0, 6.0),
	&"exit": Rect2(-1.0, -3.5, 2.0, 2.5),
}

var capsule: CareCapsule
var monitor: VitalsMonitor
var blinds: WindowBlinds
var caretaker: Caretaker
## Onde o Zelador fica encaixado para recarregar.
var dock := Transform3D.IDENTITY
## O sensor térmico do meio do corredor (R2, F6).
var sensor: Node3D
## Os olhos de Ari nos flashes (deitado na cápsula).
var eyes: Camera3D
## Ar limpo, sem neblina: a câmera de Ari e os olhos dos flashes usam este ambiente.
var environment: Environment
var ari: Ari

var _surfaces := {}
var _body: StaticBody3D


func _ready() -> void:
	position = Tuning.SHELTER_ORIGIN
	_body = StaticBody3D.new()
	_body.name = "Walls"
	add_child(_body)
	for room: StringName in ROOMS:
		var rect: Rect2 = ROOMS[room]
		var center := rect.get_center()
		var size := Vector3(rect.size.x + WALL, 0.2, rect.size.y + WALL)
		_add_box(size, Vector3(center.x, -0.1, center.y), &"floor", &"stone")
		_add_box(size, Vector3(center.x, HEIGHT + 0.1, center.y), &"ceiling")
	_build_walls()
	_build_room()
	_build_corridor()
	_build_store()
	_build_dock()
	_build_control()
	_build_exit()
	_commit()
	_build_environment()
	for node in find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = LAYER
	set_active(false)


func _exit_tree() -> void:
	ShelterLook.release()


## Liga (flash ou visita) ou desliga o Abrigo: escondido e parado quando ninguém está aqui.
func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_PAUSABLE if active else Node.PROCESS_MODE_DISABLED


## Ari acordado, de pé ao lado da cápsula.
func spawn_ari() -> Ari:
	remove_ari()
	ari = Ari.new()
	ari.name = "Ari"
	add_child(ari)
	ari.global_position = capsule.out_point()
	ari.camera.environment = environment
	return ari


## A porta da sala 2714 para o corredor (para onde Ari olha ao levantar).
func room_door() -> Vector3:
	return to_global(Vector3(-3.0, 1.6, 1.0))


func remove_ari() -> void:
	if ari != null:
		ari.queue_free()
		ari = null


# --- Paredes -------------------------------------------------------------------------------

func _build_walls() -> void:
	var door := DOOR_HEIGHT
	# Corredor: a saída ao norte (x = 0); a sala 2714 (x = -3) e a de controle (x = 4) ao sul.
	_wall(Vector2(-10.0, -1.0), Vector2(10.0, -1.0), [Vector4(10.0, 2.0, 0.0, door + 0.2)])
	_wall(Vector2(-10.0, 1.0), Vector2(10.0, 1.0), [Vector4(7.0, 1.0, 0.0, door), Vector4(14.0, 1.0, 0.0, door)])
	# Almoxarifado, no fim oeste.
	_wall(Vector2(-10.0, -2.5), Vector2(-10.0, 2.5), [Vector4(2.5, 1.0, 0.0, door)])
	_wall(Vector2(-14.0, -2.5), Vector2(-10.0, -2.5))
	_wall(Vector2(-14.0, 2.5), Vector2(-10.0, 2.5))
	_wall(Vector2(-14.0, -2.5), Vector2(-14.0, 2.5))
	# Estação de recarga, no fim leste: aberta para o corredor.
	_wall(Vector2(10.0, -1.5), Vector2(10.0, 1.5), [Vector4(1.5, 2.0, 0.0, 2.3)])
	_wall(Vector2(10.0, -1.5), Vector2(13.0, -1.5))
	_wall(Vector2(10.0, 1.5), Vector2(13.0, 1.5))
	_wall(Vector2(13.0, -1.5), Vector2(13.0, 1.5))
	# Sala 2714, com a janela na parede sul.
	_wall(Vector2(-7.0, 1.0), Vector2(-7.0, 7.0))
	_wall(Vector2(-2.0, 1.0), Vector2(-2.0, 7.0))
	_wall(Vector2(-7.0, 7.0), Vector2(-2.0, 7.0), [Vector4(3.4, 1.8, 0.95, 2.15)])
	# Sala de controle.
	_wall(Vector2(2.0, 1.0), Vector2(2.0, 7.0))
	_wall(Vector2(8.0, 1.0), Vector2(8.0, 7.0))
	_wall(Vector2(2.0, 7.0), Vector2(8.0, 7.0))
	# Corredorzinho da saída.
	_wall(Vector2(-1.0, -3.5), Vector2(-1.0, -1.0))
	_wall(Vector2(1.0, -3.5), Vector2(1.0, -1.0))
	_wall(Vector2(-1.0, -3.5), Vector2(1.0, -3.5))


## Parede de `a` a `b` (alinhada a X ou Z) com aberturas Vector4(centro ao longo da parede a
## partir de `a`, largura, altura de baixo, altura de cima). Porta (de baixo = 0) ganha batente.
func _wall(a: Vector2, b: Vector2, openings: Array[Vector4] = []) -> void:
	var length := a.distance_to(b)
	var along := (b - a) / length
	var cursor := 0.0
	for opening in openings:
		var start := opening.x - opening.y * 0.5
		var end := opening.x + opening.y * 0.5
		_wall_piece(a, along, length, cursor, start, 0.0, HEIGHT)
		if opening.z > 0.0:
			_wall_piece(a, along, length, start, end, 0.0, opening.z)
		if opening.w < HEIGHT:
			_wall_piece(a, along, length, start, end, opening.w, HEIGHT)
		if opening.z == 0.0:
			_door_frame(a, along, start, end, opening.w)
		cursor = end
	_wall_piece(a, along, length, cursor, length, 0.0, HEIGHT)


func _wall_piece(a: Vector2, along: Vector2, length: float, from: float, to: float, bottom: float, top: float) -> void:
	# As pontas da parede avançam meia espessura para fechar os cantos.
	if from <= 0.0:
		from -= WALL * 0.5
	if to >= length:
		to += WALL * 0.5
	if to - from < 0.01 or top - bottom < 0.01:
		return
	var middle := a + along * (from + to) * 0.5
	var run := to - from
	var size := Vector3(run, top - bottom, WALL) if absf(along.x) > 0.5 else Vector3(WALL, top - bottom, run)
	_add_box(size, Vector3(middle.x, (top + bottom) * 0.5, middle.y), &"concrete")


func _door_frame(a: Vector2, along: Vector2, from: float, to: float, top: float) -> void:
	var x_wall := absf(along.x) > 0.5
	for edge in [from, to]:
		var at: Vector2 = a + along * edge
		var size := Vector3(0.06, top, WALL + 0.04) if x_wall else Vector3(WALL + 0.04, top, 0.06)
		_add_box(size, Vector3(at.x, top * 0.5, at.y), &"metal", &"", false)
	var middle := a + along * (from + to) * 0.5
	var run := to - from + 0.12
	var head := Vector3(run, 0.08, WALL + 0.04) if x_wall else Vector3(WALL + 0.04, 0.08, run)
	_add_box(head, Vector3(middle.x, top + 0.04, middle.y), &"metal", &"", false)


# --- Salas ----------------------------------------------------------------------------------

func _build_room() -> void:
	capsule = CareCapsule.new()
	capsule.name = "Capsule"
	capsule.position = Vector3(-5.0, 0.0, 3.9)
	add_child(capsule)
	monitor = VitalsMonitor.new()
	monitor.name = "Monitor"
	monitor.position = Vector3(-6.0, 0.0, 4.58)
	add_child(monitor)
	var to_eye := capsule.position + Vector3(-0.82, 0.0, 0.0) - monitor.position
	monitor.rotation.y = atan2(to_eye.x, to_eye.z)
	# Suporte do soro: a sonda do braço sobe até a bolsa.
	var drip := capsule.position + capsule.drip_point
	_add_cylinder(0.012, drip.y + 0.12, Vector3(drip.x, (drip.y + 0.12) * 0.5, drip.z), &"metal")
	_add_cylinder(0.16, 0.03, Vector3(drip.x, 0.015, drip.z), &"dark_metal")
	ShelterLook.box(self, Vector3(0.1, 0.17, 0.035), drip + Vector3(0.0, 0.09, 0.0), &"glass")
	blinds = WindowBlinds.new()
	blinds.name = "Blinds"
	blinds.position = Vector3(-3.6, 1.55, 7.0 - WALL * 0.5)
	add_child(blinds)
	# Quadro de fusíveis na parede leste (R2, F6), com o conduíte subindo.
	_add_box(Vector3(0.08, 0.5, 0.36), Vector3(-2.14, 1.4, 5.6), &"metal")
	_add_cylinder(0.02, 1.05, Vector3(-2.14, 2.17, 5.6), &"dark_metal")
	ShelterLook.label(self, "QUADRO 2714", Vector3(-2.19, 1.72, 5.6), 0.04, Color(0.75, 0.75, 0.7), false, -PI * 0.5)
	# Armário, cadeira e a grade da ventilação.
	_add_box(Vector3(0.5, 1.1, 0.45), Vector3(-6.68, 0.55, 1.5), &"metal")
	_add_box(Vector3(0.45, 0.05, 0.45), Vector3(-2.7, 0.46, 3.0), &"plastic", &"", false)
	_add_box(Vector3(0.05, 0.45, 0.45), Vector3(-2.48, 0.7, 3.0), &"plastic", &"", false)
	for leg in [Vector2(-0.19, -0.19), Vector2(0.19, -0.19), Vector2(-0.19, 0.19), Vector2(0.19, 0.19)]:
		_add_cylinder(0.012, 0.44, Vector3(-2.7 + leg.x, 0.22, 3.0 + leg.y), &"dark_metal")
	_add_box(Vector3(0.55, 0.28, 0.03), Vector3(-5.5, 2.35, 1.115), &"dark_metal", &"", false)
	# A luz de emergência acima da cabeceira, a que pisca no flash 1.
	_light(Vector3(-6.25, HEIGHT - 0.03, 3.9), Vector3(0.32, 0.06, 0.16), &"green", 0.55, 4.0, &"blink", 2.4)
	_add_box(Vector3(1.2, 0.05, 0.1), Vector3(-4.5, HEIGHT - 0.03, 4.8), &"plastic", &"", false)
	# A luz da janela batendo no chão e voltando fraca para o teto (sem isto o teto some).
	var bounce := OmniLight3D.new()
	bounce.light_color = Color(0.66, 0.7, 0.74)
	bounce.light_energy = 0.45
	bounce.omni_range = 5.0
	bounce.position = Vector3(-4.6, 1.1, 4.8)
	add_child(bounce)
	ShelterLook.label(self, "2714", Vector3(-2.3, 1.75, 0.885), 0.12, Color(0.72, 0.72, 0.68), false, PI)
	_ambient(Vector3(-4.5, 1.6, 4.0))


func _build_corridor() -> void:
	# Tubos e conduítes no teto, de ponta a ponta.
	ShelterLook.rod(self, Vector3(-10.0, 2.43, -0.76), Vector3(10.0, 2.43, -0.76), 0.06, &"metal")
	ShelterLook.rod(self, Vector3(-10.0, 2.52, -0.56), Vector3(10.0, 2.52, -0.56), 0.035, &"dark_metal")
	ShelterLook.rod(self, Vector3(-10.0, 2.55, 0.8), Vector3(10.0, 2.55, 0.8), 0.025, &"dark_metal")
	for x in [-8.0, -3.5, 1.5, 6.5]:
		_add_box(Vector3(0.12, 0.08, 0.3), Vector3(x, 2.43, -0.76), &"dark_metal", &"", false)
	# Luz de emergência verde a cada cinco metros; duas lâmpadas brancas, uma falhando.
	_light(Vector3(-8.0, HEIGHT - 0.03, 0.0), Vector3(0.24, 0.05, 0.12), &"green", 0.6, 4.5, &"blink", 3.1)
	_light(Vector3(-3.5, HEIGHT - 0.03, 0.0), Vector3(0.24, 0.05, 0.12), &"green", 0.6, 4.5, &"steady")
	_light(Vector3(1.5, HEIGHT - 0.03, 0.0), Vector3(0.24, 0.05, 0.12), &"green", 0.6, 4.5, &"blink", 2.7)
	_light(Vector3(6.5, HEIGHT - 0.03, 0.0), Vector3(0.24, 0.05, 0.12), &"green", 0.6, 4.5, &"steady")
	_light(Vector3(-6.0, HEIGHT - 0.03, 0.2), Vector3(1.2, 0.04, 0.08), &"white", 0.6, 5.0, &"steady")
	_light(Vector3(4.0, HEIGHT - 0.03, 0.2), Vector3(1.2, 0.04, 0.08), &"white", 1.0, 5.5, &"flicker", 1.0, true)
	# O sensor térmico, no meio: uma cúpula escura com a luz vermelha (o "faro" do Zelador).
	sensor = Node3D.new()
	sensor.name = "Sensor"
	sensor.position = Vector3(0.5, HEIGHT - 0.06, 0.0)
	add_child(sensor)
	ShelterLook.sphere(sensor, 0.08, Vector3.ZERO, &"dark_metal")
	ShelterLook.box(sensor, Vector3(0.02, 0.02, 0.02), Vector3(0.0, -0.075, 0.03), &"red")
	var red := OmniLight3D.new()
	red.light_color = Color(1.0, 0.2, 0.15)
	red.light_energy = 0.3
	red.omni_range = 1.2
	red.position = Vector3(0.0, -0.15, 0.0)
	sensor.add_child(red)
	# Placas pintadas na parede.
	var paint := Color(0.7, 0.7, 0.66)
	ShelterLook.label(self, "ALMOXARIFADO", Vector3(-9.89, 2.3, 0.0), 0.09, paint, false, PI * 0.5)
	ShelterLook.label(self, "RECARGA", Vector3(9.89, 2.45, 0.0), 0.09, paint, false, -PI * 0.5)
	ShelterLook.label(self, "CONTROLE", Vector3(5.0, 1.75, 0.885), 0.07, paint, false, PI)
	ShelterLook.label(self, "ABRIGO 9 · ALA C", Vector3(-6.0, 1.6, -0.885), 0.1, paint)
	ShelterLook.label(self, "SAÍDA", Vector3(0.0, 2.45, -0.885), 0.1, paint)
	# Papéis caídos e uma cadeira tombada: saíram com pressa.
	for paper in [Vector3(-7.2, 0.003, 0.3), Vector3(-6.8, 0.003, -0.4), Vector3(2.6, 0.003, 0.5), Vector3(7.4, 0.003, -0.2)]:
		ShelterLook.box(self, Vector3(0.21, 0.004, 0.29), paper, &"paper", Vector3(0.0, randf() * TAU, 0.0))
	_add_box(Vector3(0.45, 0.05, 0.45), Vector3(8.2, 0.24, 0.55), &"plastic", &"", false)
	_ambient(Vector3(0.0, 1.6, 0.0))


func _build_store() -> void:
	# Prateleiras nas duas paredes compridas: dá para se esconder atrás (F6).
	for z in [-2.15, 2.15]:
		for level in 4:
			_add_box(Vector3(3.2, 0.03, 0.5), Vector3(-12.0, 0.15 + level * 0.55, z), &"metal")
		for x in [-13.55, -10.45]:
			_add_box(Vector3(0.04, 1.9, 0.04), Vector3(x, 0.95, z - 0.23), &"dark_metal", &"", false)
			_add_box(Vector3(0.04, 1.9, 0.04), Vector3(x, 0.95, z + 0.23), &"dark_metal", &"", false)
		for box in 7:
			var at := Vector3(-13.3 + box * 0.45, 0.0, z)
			var level := box % 4
			_add_box(Vector3(0.36, 0.28, 0.34), at + Vector3(0.0, 0.31 + level * 0.55, 0.0), &"paper", &"", false)
	# O quadro do clima (R3, F6) com o cabo grosso subindo para o teto.
	_add_box(Vector3(0.12, 0.8, 0.6), Vector3(-13.9, 1.3, 0.6), &"metal")
	_add_cylinder(0.035, 1.0, Vector3(-13.9, 2.2, 0.75), &"rubber")
	ShelterLook.label(self, "CLIMA", Vector3(-13.83, 1.82, 0.6), 0.05, Color(0.75, 0.75, 0.7), false, PI * 0.5)
	_light(Vector3(-12.0, HEIGHT - 0.35, 0.0), Vector3(0.08, 0.1, 0.08), &"amber", 0.45, 4.0, &"steady")
	ShelterLook.rod(self, Vector3(-12.0, HEIGHT, 0.0), Vector3(-12.0, HEIGHT - 0.3, 0.0), 0.006, &"rubber", 4)
	_ambient(Vector3(-12.0, 1.6, 0.0))


func _build_dock() -> void:
	# O nicho onde o Zelador encaixa, com os contatos acesos.
	_add_box(Vector3(0.1, 2.0, 1.1), Vector3(12.9, 1.0, 0.0), &"dark_metal")
	_add_box(Vector3(0.5, 0.08, 1.1), Vector3(12.7, 2.0, 0.0), &"dark_metal", &"", false)
	_add_box(Vector3(0.04, 0.06, 0.1), Vector3(12.84, 1.02, -0.12), &"amber", &"", false)
	_add_box(Vector3(0.04, 0.06, 0.1), Vector3(12.84, 1.02, 0.12), &"amber", &"", false)
	var amber := OmniLight3D.new()
	amber.light_color = Color(1.0, 0.62, 0.2)
	amber.light_energy = 0.5
	amber.omni_range = 3.0
	amber.position = Vector3(12.5, 1.6, 0.0)
	add_child(amber)
	dock = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(12.45, 0.0, 0.0))
	caretaker = Caretaker.new()
	caretaker.name = "Caretaker"
	caretaker.transform = dock
	add_child(caretaker)


func _build_control() -> void:
	# A porta fechada (precisa do cartão, F6) e o leitor do lado do corredor.
	_add_box(Vector3(1.0, DOOR_HEIGHT, 0.06), Vector3(4.0, DOOR_HEIGHT * 0.5, 1.0), &"dark_metal")
	_add_box(Vector3(0.1, 0.16, 0.04), Vector3(4.75, 1.3, 0.87), &"plastic", &"", false)
	_add_box(Vector3(0.03, 0.02, 0.01), Vector3(4.75, 1.35, 0.848), &"red", &"", false)
	# Dentro: mesa, terminal, as quatro telas das câmeras e o servidor (F8).
	_add_box(Vector3(2.4, 0.06, 0.8), Vector3(5.0, 0.76, 6.4), &"metal")
	_add_box(Vector3(2.3, 0.73, 0.04), Vector3(5.0, 0.37, 6.78), &"dark_metal")
	for i in 4:
		_add_box(Vector3(0.6, 0.42, 0.04), Vector3(3.6 + i * 0.95, 1.55, 6.88), &"screen", &"", false)
	_add_box(Vector3(0.7, 1.9, 0.6), Vector3(7.4, 0.95, 2.0), &"dark_metal")
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.45, 0.6, 0.65)
	glow.light_energy = 0.4
	glow.omni_range = 4.0
	glow.position = Vector3(5.0, 1.8, 5.8)
	add_child(glow)


func _build_exit() -> void:
	# A porta blindada da saída (Final 2), com as faixas de aviso gastas.
	_add_box(Vector3(2.0, 2.3, 0.25), Vector3(0.0, 1.15, -3.35), &"dark_metal")
	for y in [0.5, 1.15, 1.8]:
		_add_box(Vector3(1.9, 0.12, 0.04), Vector3(0.0, y, -3.21), &"metal", &"", false)
	_add_box(Vector3(0.12, 0.2, 0.05), Vector3(0.75, 1.3, -3.2), &"plastic", &"", false)
	_add_box(Vector3(0.03, 0.02, 0.01), Vector3(0.75, 1.36, -3.172), &"red", &"", false)
	_light(Vector3(0.0, HEIGHT - 0.03, -2.4), Vector3(0.24, 0.05, 0.12), &"red", 0.4, 3.0, &"blink", 4.0)


# --- Peças -----------------------------------------------------------------------------------

## Luminária com a luz dela (FlickerLight).
func _light(at: Vector3, size: Vector3, color: StringName, energy: float, reach: float, mode: StringName, period := 1.6, buzzing := false) -> FlickerLight:
	var fixture := ShelterLook.box(self, size, at, color)
	var material := ShelterLook.light_material(color)
	fixture.material_override = material
	var light := FlickerLight.new()
	light.mode = mode
	light.period = period
	# Um palmo abaixo da luminária: assim ela também clareia o teto em volta.
	light.position = at - Vector3(0.0, 0.25, 0.0)
	add_child(light)
	light.setup(energy, material.emission, reach, material, buzzing)
	return light


func _ambient(at: Vector3) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = AMBIENT
	sound.bus = &"Shelter"
	sound.volume_db = -16.0
	sound.unit_size = 4.0
	sound.position = at
	add_child(sound)
	# Começa num ponto sorteado, para as salas não soarem em uníssono.
	sound.play(randf() * AMBIENT.get_length())


## Caixa da arquitetura: entra numa malha só por material e, se `collide`, ganha colisão
## (`surface` = o chão para os passos, ver Footsteps).
func _add_box(size: Vector3, center: Vector3, material_name: StringName, surface := &"", collide := true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_append(mesh, Transform3D(Basis.IDENTITY, center), material_name)
	if not collide:
		return
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	if surface != &"":
		shape.set_meta(&"surface", surface)
	_body.add_child(shape)


func _add_cylinder(radius: float, height: float, center: Vector3, material_name: StringName) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	_append(mesh, Transform3D(Basis.IDENTITY, center), material_name)


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


func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.44, 0.46)
	environment.ambient_light_energy = 0.3
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_radius = 0.8
	environment.ssao_intensity = 1.8
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.72
	eyes = Camera3D.new()
	eyes.name = "Eyes"
	eyes.environment = environment
	eyes.fov = 75.0
	eyes.near = 0.03
	add_child(eyes)
