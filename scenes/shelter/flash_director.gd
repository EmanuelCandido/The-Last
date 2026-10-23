class_name FlashDirector
extends Node
## Os flashes do mundo real (§7): alguns segundos nos olhos de Ari deitado na cápsula, com a
## visão borrada e o bipe. Sem controle; o mouse só mexe a cabeça um pouco. Usam o mesmo
## Abrigo das visitas (Shelter), e cada flash é uma função do tempo (câmera, Zelador,
## pálpebras, legendas), então qualquer instante pode ser reproduzido num print.
##
## 1: o teto, a luz verde piscando e uma silhueta que passa na frente dela.
## 2: a cabeça cai para o lado: o monitor (LEITO 2714 · CICLO · DIA) e a mão com a sonda.
## 3: pela persiana, a ruína na neblina; a lente verde chega perto: "Durma, Ari."
##
## O flash de morte (§3) é o mesmo flash, mais curto: a linha do tempo inteira passa depressa.

const TEXTS := {1: "Batimento 112. Leve agitação.", 3: "Durma, Ari."}
## No flash 3 a cabeça está erguida no travesseiro (m acima dos olhos deitados).
const FLASH_3_LIFT := 0.14

var shelter: Shelter
var vision: BlurredVision

var _number := 0
var _time := 0.0
var _tempo := 1.0
var _look := Vector2.ZERO
var _done := {}
var _playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Mostra o flash `number` por `seconds` segundos. Começa e termina com a tela preta.
func play(number: int, seconds: float) -> void:
	var full: float = Tuning.FLASH_SECONDS.get(number, seconds)
	_tempo = full / seconds
	_number = number
	_time = 0.0
	_look = Vector2.ZERO
	_done.clear()
	shelter.set_active(true)
	_prepare()
	var previous := get_viewport().get_camera_3d()
	shelter.eyes.make_current()
	_playing = true
	_update(0.0)
	Events.prompt_changed.emit("")
	Events.screen_fade_requested.emit(0.0, 1.0)
	Game.open_ears(1.5, -20.0, 900.0)
	await get_tree().create_timer(maxf(seconds - 0.9, 0.5), false).timeout
	Events.screen_fade_requested.emit(1.0, 0.8)
	Game.close_ears(0.8)
	await get_tree().create_timer(0.9, false).timeout
	_playing = false
	vision.clear()
	_restore()
	if previous != null:
		previous.make_current()
	shelter.set_active(false)


func is_playing() -> bool:
	return _playing


## Põe o flash no instante `at` (s da linha do tempo inteira), para prints e testes.
func seek(at: float) -> void:
	_time = at
	_done.clear()
	_update(at)


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta * _tempo
	# A cabeça volta devagar para onde o corpo deixa.
	_look = _look.lerp(Vector2.ZERO, 1.0 - exp(-0.8 * delta))
	_update(_time)


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or event is not InputEventMouseMotion:
		return
	var limit := deg_to_rad(Tuning.FLASH_LOOK_DEGREES)
	var motion := (event as InputEventMouseMotion).relative * 0.0015
	_look = Vector2(clampf(_look.x - motion.x, -limit, limit), clampf(_look.y - motion.y, -limit, limit))


func _prepare() -> void:
	shelter.capsule.set_occupied(true)
	shelter.monitor.bpm = Tuning.FLASH_BPM if _number == 1 else Tuning.SHELTER_BPM
	shelter.blinds.set_open(0.8 if _number == 3 else 0.25, 0.0)
	# No flash 3 alguém deixou a persiana meio erguida: embaixo, a vista está livre.
	shelter.blinds.raised = 0.55 if _number == 3 else 0.0
	# No flash 3 a vista fecha na janela, como quem força o olho para enxergar longe.
	shelter.eyes.fov = 42.0 if _number == 3 else 75.0
	var caretaker := shelter.caretaker
	caretaker.set_light(&"green")
	caretaker.set_glow(1.0)
	if _number == 3:
		# Parado ao lado da cabeceira, fora da vista, virado para Ari.
		caretaker.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), _local(Vector3(-1.55, 0.0, 0.9)))


func _restore() -> void:
	var caretaker := shelter.caretaker
	caretaker.transform = shelter.dock
	caretaker.head.position = Vector3(0.0, Caretaker.NECK_HEIGHT, 0.0)
	caretaker.head.rotation = Vector3.ZERO
	caretaker.moving = false
	caretaker.set_glow(1.0)
	shelter.capsule.set_occupied(false)
	shelter.monitor.bpm = Tuning.SHELTER_BPM
	shelter.blinds.raised = 0.0


func _update(t: float) -> void:
	match _number:
		1:
			_flash_ceiling(t)
		2:
			_flash_monitor(t)
		3:
			_flash_window(t)


# --- Os três flashes ---------------------------------------------------------------------------

func _flash_ceiling(t: float) -> void:
	vision.lids = _keys(t, [[0.0, 0.85], [1.4, 0.3], [4.2, 0.3], [4.4, 0.95], [4.75, 0.25], [6.6, 0.4], [7.6, 1.0]])
	vision.amount = _keys(t, [[0.0, 0.9], [2.5, 0.6], [4.0, 0.45], [6.0, 0.6], [7.6, 0.9]])
	# Olha para cima, um pouco para a luz de emergência atrás da cabeceira.
	var lamp := _local(Vector3(-1.25, Shelter.HEIGHT, 0.0)) - shelter.capsule.eye_point()
	_aim(Vector3.UP.slerp(lamp.normalized(), 0.55), 0.0, t)
	# O Zelador passa atrás da cabeceira, debruçado sobre a cápsula e olhando para a frente:
	# de baixo, a cabeça é uma silhueta escura cruzando a luz verde.
	var caretaker := shelter.caretaker
	var pass_weight := clampf((t - 2.4) / 3.6, 0.0, 1.0)
	var base := _local(Vector3(-1.55, 0.0, lerpf(-1.8, 1.8, pass_weight)))
	caretaker.global_transform = Transform3D(Basis.IDENTITY, base)
	caretaker.moving = t > 2.4 and t < 6.0
	var lean := sin(pass_weight * PI)
	caretaker.head.position = Vector3(0.45 * lean, Caretaker.NECK_HEIGHT + 0.42 * lean, 0.0)
	caretaker.head.rotation = Vector3(0.5 * lean, 0.0, 0.0)
	if _once(&"servo", t >= 3.0):
		caretaker.servo()
	if _once(&"say", t >= 4.0):
		caretaker.speak(1)
		vision.say(TEXTS[1], 3.0 / _tempo)


func _flash_monitor(t: float) -> void:
	vision.lids = _keys(t, [[0.0, 0.8], [1.2, 0.35], [2.1, 0.5], [2.5, 0.25], [4.5, 0.25], [4.7, 0.95], [5.0, 0.25], [6.0, 0.4], [7.0, 1.0]])
	# Depois da queda, a vista firma no monitor: dá para ler o leito e o ciclo.
	vision.amount = _keys(t, [[0.0, 0.9], [2.2, 0.8], [3.2, 0.3], [5.2, 0.3], [6.2, 0.7]])
	# A cabeça cai para a direita: acelera como peso morto e quica no travesseiro.
	var fall := clampf((t - 1.3) / 0.8, 0.0, 1.0)
	fall = fall * fall
	if t > 2.1:
		fall = 1.0 + 0.06 * sin(clampf((t - 2.1) / 0.35, 0.0, 1.0) * PI)
	# Entre o monitor e o braço com a sonda, mais para o monitor. A vista não gira os 90° da
	# cabeça deitada de lado: o olho compensa em parte, e o texto continua legível.
	var screen := shelter.monitor.global_transform * Vector3(0.0, VitalsMonitor.SCREEN_HEIGHT, 0.0)
	var target := screen.lerp(_local(Vector3(-0.18, 0.88, 0.32)), 0.3) - shelter.capsule.eye_point()
	_aim(Vector3.UP.slerp(target.normalized(), clampf(fall, 0.0, 1.06)), 0.6 * clampf(fall, 0.0, 1.0), t)


func _flash_window(t: float) -> void:
	vision.lids = _keys(t, [[0.0, 0.75], [1.2, 0.3], [3.6, 0.3], [3.8, 0.9], [4.1, 0.25], [6.6, 0.4], [8.0, 1.0]])
	vision.amount = _keys(t, [[0.0, 0.85], [1.4, 0.25], [3.0, 0.3], [4.4, 0.6], [6.6, 0.7], [8.0, 0.9]])
	# A cabeça está erguida no travesseiro, olhando por cima do monitor.
	var eye := shelter.capsule.eye_point() + Vector3.UP * FLASH_3_LIFT
	# Olha a metade de baixo da janela, a que está livre (a persiana subiu até o meio).
	var window := (shelter.blinds.global_position + Vector3.DOWN * 0.3 - eye).normalized()
	# A cabeça do Zelador estica até ficar a um palmo dos olhos, com a lente acendendo.
	var caretaker := shelter.caretaker
	var approach := smoothstep(2.8, 5.2, t)
	var neck := caretaker.global_transform * Vector3(0.0, Caretaker.NECK_HEIGHT, 0.0)
	var near := eye + window.slerp((neck - eye).normalized(), 0.18) * 0.34
	var head := neck.lerp(near, approach) + Vector3.UP * 0.25 * sin(approach * PI)
	caretaker.head.global_position = head
	caretaker.head.look_at(eye, Vector3.UP, true)
	caretaker.set_glow(lerpf(1.0, 1.7, approach))
	# Os olhos acompanham a lente quando ela entra na vista.
	var follow := smoothstep(3.4, 4.6, t) * 0.75
	_aim(window.slerp((head - eye).normalized(), follow), 0.85, t, FLASH_3_LIFT)
	if _once(&"servo", t >= 2.8):
		caretaker.servo()
	if _once(&"say", t >= 5.0):
		caretaker.speak(0)
		vision.say(TEXTS[3], 2.4 / _tempo)


# --- Peças ---------------------------------------------------------------------------------

## Olha na direção `direction` deitado na cápsula. `up_blend` 0 = deitado reto (o alto da tela é
## o topo da cabeça), 1 = cabeça erguida (o alto da tela é o teto). `lift` ergue os olhos. Por
## cima, a cabeça boia e segue um pouco o mouse.
func _aim(direction: Vector3, up_blend: float, t: float, lift := 0.0) -> void:
	var up := shelter.capsule.crown_direction().lerp(Vector3.UP, up_blend).normalized()
	if absf(direction.normalized().dot(up)) > 0.98:
		up = shelter.capsule.crown_direction()
	var basis := Basis.looking_at(direction.normalized(), up)
	var sway := Vector2(sin(t * 0.7) * 0.015, sin(t * 0.5 + 1.0) * 0.012)
	basis = basis * Basis.from_euler(Vector3(_look.y + sway.y, _look.x + sway.x, 0.0))
	shelter.eyes.global_transform = Transform3D(basis, shelter.capsule.eye_point() + Vector3.UP * lift)


## Ponto no espaço da cápsula, no mundo.
func _local(point: Vector3) -> Vector3:
	return shelter.capsule.global_transform * point


## Interpola linearmente (suavizado) entre pares [tempo, valor].
static func _keys(t: float, keys: Array) -> float:
	var first: Array = keys[0]
	if t <= float(first[0]):
		return float(first[1])
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if t <= float(b[0]):
			var w := smoothstep(float(a[0]), float(b[0]), t)
			return lerpf(float(a[1]), float(b[1]), w)
	var last: Array = keys[keys.size() - 1]
	return float(last[1])


## true só na primeira vez que `condition` vale (eventos com hora marcada).
func _once(id: StringName, condition: bool) -> bool:
	if not condition or _done.has(id):
		return false
	_done[id] = true
	return true
