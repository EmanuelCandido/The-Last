class_name ControlRoom
extends Node3D
## A sala de controle do Abrigo 9 (§8, Ato IV): a porta que só abre com o cartão (ou para o
## Zelador, que o tem no peito), a mesa com o terminal e o rádio, as quatro telas das câmeras de
## fora, o servidor da simulação e o aviso da evacuação na parede.
##
## Com o cartão (R4), Ari passa o cartão no leitor e entra: o gatilho "shelter" com
## "control_room" põe a anotação. No terminal, "Abrir as gravações" liga as câmeras (Vilarrasa com
## gente, seis anos depois da Cinza) e dispara "recordings"; o beat liga o flag "confession" e
## esta sala faz a cena: o Zelador entra e conta tudo (StoryBeats.LINES). Depois disso o terminal
## abre o console do Zelador (KeeperConsole), que tem os comandos dos finais.
## Filho do Shelter, no espaço dele (as coordenadas são as do Abrigo).

const FEED_SHADER := preload("res://assets/shaders/camera_feed.gdshader")
const SERVER_HUM := preload("res://assets/audio/sfx/fan_hum.wav")
const STATIC := preload("res://assets/audio/sfx/glitch.wav")
const READER_BEEP := preload("res://assets/audio/sfx/keeper_beep.wav")
const ROOM := Rect2(2.0, 1.0, 6.0, 6.0)
const DOOR_CLOSED_X := 4.0
const DOOR_OPEN_X := 5.0
## O que cada tela mostra (o quadro do camera_feed.gdshader) e a placa dela.
const FEEDS := [["CAM 1 · MERCADO", 0], ["CAM 2 · TELHADOS", 1], ["CAM 3 · RUA DAS PEDRAS", 2], ["CAM 4 · PORTÃO NORTE", 3]]
## A data das gravações (seis anos depois da Cinza, que o aviso da parede data) e a hora em que
## começam.
const RECORDING_DATE := "17/06/2039"
const RECORDING_START := 9 * 3600 + 42 * 60
const SCREEN := Vector2(0.6, 0.42)
## Onde o Zelador para para conversar (dentro, entre a porta e a mesa) e o meio das telas.
const TALK_POINT := Vector3(4.0, 0.0, 3.3)
const SCREENS_CENTER := Vector3(5.0, 1.55, 6.86)

var shelter: Shelter
## Ari passou o cartão nesta visita (ou já houve a conversa): a porta fica aberta.
var unlocked := false
## A conversa está passando.
var talking := false

var _door: StaticBody3D
var _reader: ShelterSwitch
var _reader_led: MeshInstance3D
var _door_open := false
var _door_tween: Tween
var _keeper_near := false
var _body: StaticBody3D
var _feeds: Array[ShaderMaterial] = []
var _stamps: Array[Label3D] = []
var _signal := 0.0
var _clock := 0.0
var _stamp_timer := 0.0
var _terminal_text: Label3D
var _leds: Array[StandardMaterial3D] = []
var _sounds: AudioStreamPlayer3D
var _console: KeeperConsole


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Furniture"
	add_child(_body)
	_build_door()
	_build_desk()
	_build_screens()
	_build_server()
	_build_notice()
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.45, 0.6, 0.65)
	glow.light_energy = 0.4
	glow.omni_range = 4.0
	glow.position = Vector3(5.0, 1.8, 5.8)
	add_child(glow)
	_sounds = AudioStreamPlayer3D.new()
	_sounds.bus = &"Shelter"
	_sounds.unit_size = 2.0
	add_child(_sounds)


## Começo de uma visita: a porta fechada (ou aberta, se a conversa já aconteceu) e as telas como
## a história deixou.
func begin_visit() -> void:
	talking = false
	_keeper_near = false
	unlocked = Story.has_flag(&"confession")
	_reader.enabled = not unlocked
	_reader_led.material_override = ShelterLook.material(&"green" if unlocked else &"red")
	_set_door(unlocked, true)
	_set_signal(1.0 if Story.has_flag(&"confession") else 0.0)
	_refresh_terminal()


## O Zelador está perto da porta: ela abre sozinha para ele (o cartão no peito).
func keeper_near(near: bool) -> void:
	_keeper_near = near


## Fim da visita: a porta fecha.
func close() -> void:
	_keeper_near = false
	unlocked = false
	_set_door(false)


## Onde o Zelador fica para conversar, no mundo.
func talk_point() -> Vector3:
	return shelter.to_global(TALK_POINT)


## Ari está dentro da sala (`point` no mundo).
func has_point(point: Vector3) -> bool:
	var local := shelter.to_local(point)
	return ROOM.has_point(Vector2(local.x, local.z))


func _process(delta: float) -> void:
	_set_door(unlocked or _keeper_near)
	var ari := shelter.ari
	if Game.awake and ari != null and not Story.has_flag(&"control_room") and has_point(ari.global_position):
		Story.trigger(&"shelter", &"control_room")
	_clock += delta
	_stamp_timer -= delta
	if _stamp_timer <= 0.0:
		_stamp_timer = 1.0
		_refresh_stamps()
	# As luzinhas do servidor piscam cada uma no seu ritmo: a simulação está rodando.
	for i in _leds.size():
		var on := fmod(_clock * (1.3 + i * 0.37) + i * 0.61, 1.0) < 0.55
		_leds[i].emission_energy_multiplier = 2.6 if on else 0.3


# --- A conversa -------------------------------------------------------------------------------

## O beat "confession" ligou o flag: o Zelador entra, conta tudo e o terminal se abre.
func confess() -> void:
	var ari := shelter.ari
	if talking or ari == null:
		return
	talking = true
	ari.controls = false
	shelter.visit.active = false
	Game.vision.tunnel = 0.0
	ari.turn_to(shelter.to_global(SCREENS_CENTER), 1.2)
	await get_tree().create_timer(3.0, false).timeout
	shelter.keeper.talk(talk_point())
	var waited := 0.0
	while not shelter.keeper.arrived() and waited < Tuning.KEEPER_TALK_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if shelter.ari == null:
		return
	var lens := shelter.caretaker.head
	ari.turn_to(lens.global_position, 1.4)
	await _line(&"confession_1")
	# As câmeras: o mercado cheio, a fumaça das chaminés e a data no canto.
	ari.turn_to(shelter.to_global(SCREENS_CENTER + Vector3(-0.5, 0.0, 0.0)), 1.6)
	await get_tree().create_timer(4.5, false).timeout
	ari.turn_to(lens.global_position, 1.4)
	await _line(&"confession_2")
	await _line(&"confession_3")
	_refresh_terminal()
	shelter.keeper.say(&"waiting")
	talking = false
	if shelter.ari != null:
		shelter.ari.controls = true


## Uma fala do Zelador e o tempo dela.
func _line(line: StringName) -> void:
	var seconds := shelter.keeper.say(line)
	await get_tree().create_timer(seconds + 0.6, false).timeout


# --- O terminal -------------------------------------------------------------------------------

func _open_recordings() -> void:
	_set_signal(1.0, true)
	Story.trigger(&"shelter", &"recordings")
	if Story.has_flag(&"confession"):
		confess()


func _open_console() -> void:
	if _console != null:
		return
	var ari := shelter.ari
	ari.controls = false
	Game.cutscene = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_console = KeeperConsole.new()
	_console.name = "KeeperConsole"
	add_child(_console)
	_console.closed.connect(_close_console)
	_console.chose.connect(_on_choice)


func _close_console() -> void:
	if _console == null:
		return
	_console.queue_free()
	_console = null
	Game.cutscene = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if shelter.ari != null:
		shelter.ari.controls = true


## Um comando dos finais: o console fecha e a história decide (StoryBeats, gatilho "choice").
func _on_choice(reason: StringName) -> void:
	_close_console()
	if shelter.ari != null:
		shelter.ari.controls = false
	Story.trigger(&"choice", reason)


## Final 3: a transferência do Zelador para a interface da cápsula, de 0 a 1.
func show_transfer(done: float) -> void:
	var filled := roundi(done * 16.0)
	_terminal_text.text = "INTERFACE DA CÁPSULA · LEITO 2714
ZL-0 %s%s %d%%" % ["#".repeat(filled), ".".repeat(16 - filled), roundi(done * 100.0)]


func _refresh_terminal() -> void:
	if Story.has_flag(&"confession"):
		_terminal_text.text = "ZL-0 · CONSOLE DE MANUTENÇÃO\n> _"
	else:
		_terminal_text.text = "GRAVAÇÕES · CÂMERAS EXTERNAS\n4 ARQUIVOS · ACESSO ZL-0"


# --- Peças ------------------------------------------------------------------------------------

func _build_door() -> void:
	_door = StaticBody3D.new()
	_door.name = "Door"
	_door.position = Vector3(DOOR_CLOSED_X, Shelter.DOOR_HEIGHT * 0.5, 1.0)
	add_child(_door)
	ShelterLook.box(_door, Vector3(1.0, Shelter.DOOR_HEIGHT, 0.06), Vector3.ZERO, &"dark_metal")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, Shelter.DOOR_HEIGHT, 0.06)
	shape.shape = box
	_door.add_child(shape)
	# O leitor do lado do corredor: a luz fica verde com o cartão.
	ShelterLook.box(self, Vector3(0.1, 0.16, 0.04), Vector3(4.75, 1.3, 0.87), &"plastic")
	_reader_led = ShelterLook.box(self, Vector3(0.03, 0.02, 0.01), Vector3(4.75, 1.35, 0.848), &"red")
	_reader = _switch(Vector3(4.75, 1.3, 0.85), "Passar o cartão", "Leitor de cartão (precisa do cartão do Zelador)",
		func() -> bool: return Story.has_flag(&"access_card"),
		func(_body: Node) -> void:
			unlocked = true
			_reader.enabled = false
			_reader_led.material_override = ShelterLook.material(&"green")
			_play(READER_BEEP, Vector3(4.75, 1.3, 0.85), -6.0))


func _build_desk() -> void:
	_solid(Vector3(2.4, 0.06, 0.8), Vector3(5.0, 0.76, 6.4), &"metal")
	_solid(Vector3(2.3, 0.73, 0.04), Vector3(5.0, 0.37, 6.78), &"dark_metal")
	# O terminal: um monitor de tubo e o teclado.
	ShelterLook.box(self, Vector3(0.46, 0.36, 0.4), Vector3(5.0, 0.98, 6.5), &"plastic")
	ShelterLook.box(self, Vector3(0.38, 0.27, 0.01), Vector3(5.0, 1.0, 6.295), &"screen")
	ShelterLook.box(self, Vector3(0.44, 0.025, 0.15), Vector3(5.0, 0.805, 6.08), &"plastic", Vector3(0.08, 0.0, 0.0))
	_terminal_text = ShelterLook.label(self, "", Vector3(5.0, 1.02, 6.288), 0.02, Color(0.45, 1.0, 0.6), true, PI)
	_switch(Vector3(5.0, 1.0, 6.3), "Abrir as gravações", "",
		func() -> bool: return Story.has_flag(&"control_room") and not Story.has_flag(&"confession"),
		func(_body: Node) -> void: _open_recordings())
	_switch(Vector3(5.0, 1.0, 6.3), "Usar o terminal", "",
		func() -> bool: return Story.has_flag(&"confession") and not talking and _console == null,
		func(_body: Node) -> void: _open_console())
	# O rádio da última chamada, na ponta da mesa.
	ShelterLook.box(self, Vector3(0.36, 0.16, 0.22), Vector3(3.95, 0.87, 6.45), &"dark_metal")
	ShelterLook.box(self, Vector3(0.12, 0.05, 0.01), Vector3(3.9, 0.9, 6.335), &"amber")
	ShelterLook.label(self, "RÁDIO", Vector3(4.06, 0.9, 6.335), 0.018, Color(0.75, 0.75, 0.7), false, PI)
	ShelterLook.rod(self, Vector3(4.08, 0.95, 6.5), Vector3(4.12, 1.45, 6.55), 0.004, &"metal")
	# A cadeira, puxada para trás.
	ShelterLook.box(self, Vector3(0.45, 0.05, 0.45), Vector3(5.2, 0.46, 5.5), &"plastic")
	ShelterLook.box(self, Vector3(0.45, 0.45, 0.05), Vector3(5.2, 0.7, 5.28), &"plastic")
	for leg in [Vector2(-0.19, -0.19), Vector2(0.19, -0.19), Vector2(-0.19, 0.19), Vector2(0.19, 0.19)]:
		ShelterLook.cylinder(self, 0.012, 0.44, Vector3(5.2 + leg.x, 0.22, 5.5 + leg.y), &"dark_metal")


func _build_screens() -> void:
	for i in FEEDS.size():
		# Da esquerda para a direita de quem olha as telas (de frente para +Z, a esquerda é +X).
		var at := Vector3(6.45 - i * 0.95, 1.55, 6.88)
		ShelterLook.box(self, Vector3(SCREEN.x + 0.05, SCREEN.y + 0.05, 0.05), at + Vector3(0.0, 0.0, 0.01), &"plastic")
		var quad := QuadMesh.new()
		quad.size = SCREEN
		var screen := MeshInstance3D.new()
		screen.mesh = quad
		screen.position = at - Vector3(0.0, 0.0, 0.018)
		screen.rotation.y = PI
		var material := ShaderMaterial.new()
		material.shader = FEED_SHADER
		material.set_shader_parameter(&"view", FEEDS[i][1])
		material.set_shader_parameter(&"aspect", SCREEN.x / SCREEN.y)
		screen.material_override = material
		add_child(screen)
		_feeds.append(material)
		var stamp := ShelterLook.label(self, "", at + Vector3(0.0, -SCREEN.y * 0.5 + 0.035, -0.022), 0.02, Color(0.9, 1.0, 0.92), true, PI)
		_stamps.append(stamp)
	ShelterLook.label(self, "CÂMERAS EXTERNAS", Vector3(5.03, 1.88, 6.875), 0.04, Color(0.7, 0.7, 0.66), false, PI)
	_refresh_stamps()


func _build_server() -> void:
	# O servidor da simulação: a floresta roda aqui. O ventilador é o que vaza nas rajadas (§7).
	_solid(Vector3(0.7, 1.9, 0.6), Vector3(7.4, 0.95, 2.0), &"dark_metal")
	for row in 6:
		ShelterLook.box(self, Vector3(0.01, 0.07, 0.5), Vector3(7.045, 0.4 + row * 0.24, 2.0), &"metal")
		for column in 3:
			var led := ShelterLook.box(self, Vector3(0.01, 0.014, 0.022), Vector3(7.04, 0.44 + row * 0.24, 1.82 + column * 0.06), &"green")
			var material := ShelterLook.light_material(&"green" if (row + column) % 3 != 0 else &"amber")
			led.material_override = material
			_leds.append(material)
	ShelterLook.label(self, "SIMULAÇÃO · A TOCA", Vector3(7.04, 1.8, 2.0), 0.03, Color(0.75, 0.75, 0.7), false, -PI * 0.5)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = SERVER_HUM
	hum.bus = &"Shelter"
	hum.volume_db = -20.0
	hum.unit_size = 1.5
	hum.position = Vector3(7.4, 1.2, 2.0)
	add_child(hum)
	hum.play(randf() * SERVER_HUM.get_length())
	hum.finished.connect(hum.play)


func _build_notice() -> void:
	# A ordem de evacuação, presa na parede: é por ela que a data das gravações faz sentido.
	ShelterLook.box(self, Vector3(0.01, 0.3, 0.21), Vector3(2.11, 1.5, 4.0), &"paper")
	ShelterLook.label(self, "ORDEM DE EVACUAÇÃO\nABRIGO 9 · ALA C\n02/10/2033\n\nA CINZA DESCE SOBRE\nVILARRASA. LEVAR OS\nPACIENTES PARA O SUL.\nZL-0 FICA NA ALA C.", Vector3(2.118, 1.5, 4.0), 0.011, Color(0.2, 0.2, 0.2), false, PI * 0.5)


## O relógio de cada gravação, rodando a partir da hora em que ela começa.
func _refresh_stamps() -> void:
	var seconds := RECORDING_START + int(_clock)
	var time := "%02d:%02d:%02d" % [seconds / 3600 % 24, seconds / 60 % 60, seconds % 60]
	for i in _stamps.size():
		_stamps[i].text = "%s      %s  %s" % [FEEDS[i][0], RECORDING_DATE, time] if _signal > 0.5 else "%s      SEM SINAL" % FEEDS[i][0]


func _set_signal(value: float, animate := false) -> void:
	_signal = value
	if animate:
		_play(STATIC, SCREENS_CENTER, -10.0)
		var tween := create_tween()
		tween.tween_method(_apply_signal, 0.0, value, 1.6).set_trans(Tween.TRANS_SINE)
	else:
		_apply_signal(value)
	_refresh_stamps()


func _apply_signal(value: float) -> void:
	for material in _feeds:
		material.set_shader_parameter(&"signal_amount", value)


func _set_door(open: bool, instant := false) -> void:
	if open == _door_open and not instant:
		return
	_door_open = open
	if _door_tween != null:
		_door_tween.kill()
	var x := DOOR_OPEN_X if open else DOOR_CLOSED_X
	if instant:
		_door.position.x = x
		return
	_door_tween = create_tween()
	_door_tween.tween_property(_door, ^"position:x", x, 0.9).set_trans(Tween.TRANS_SINE)
	_play(Caretaker.SERVO, _door.position + Vector3.UP, -12.0)


func _switch(at: Vector3, prompt: String, locked: String, available: Callable, action: Callable) -> ShelterSwitch:
	var item := ShelterSwitch.new()
	item.prompt = prompt
	item.locked_prompt = locked
	item.available = available
	item.action = action
	item.position = at
	add_child(item)
	return item


## Peça com colisão (Ari não atravessa a mesa nem o servidor).
func _solid(size: Vector3, center: Vector3, material_name: StringName) -> void:
	ShelterLook.box(self, size, center, material_name)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	_body.add_child(shape)


func _play(stream: AudioStream, at: Vector3, volume: float) -> void:
	_sounds.stream = stream
	_sounds.position = at
	_sounds.volume_db = volume
	_sounds.play()
