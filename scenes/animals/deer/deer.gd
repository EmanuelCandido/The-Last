class_name Deer
extends Animal
## Cervo: anda em manada, pasta de cabeça baixa (e aí enxerga mal), ergue a cabeça e as orelhas
## quando algo chama a atenção, encara quando desconfia, bate a pata e bufa antes de fugir, e
## foge em disparada com a manada. De noite deita e dorme com a manada.

const SNORT := preload("res://assets/audio/animals/deer_snort.wav")
const STOMP := preload("res://assets/audio/animals/deer_stomp.wav")

## Cor do pelo (o cervo branco troca).
var fur_color := Color(0.62, 0.43, 0.27)

const MODEL := preload("res://assets/models/animals/deer.glb")

var _body: Node3D
var _chest: Node3D
var _neck: Node3D
var _head: Node3D
var _tail: Node3D
var _ears: Array[Node3D] = []
var _gait: QuadrupedGait
var _rest_body := Vector3.ZERO
var _graze := 0.0
var _lie := 0.0
var _stomp := 0.0


func _init() -> void:
	walk_speed = 0.73
	run_speed = 6.7
	home_radius = 20.0
	sight_range = 25.0
	hearing_range = 19.0
	smell_range = 19.0
	step_stride = 0.8
	step_volume_db = -11.0
	step_pitch = 0.9
	eye_height = 1.45
	calm_distance = 40.0
	max_health = 2.0
	meat = 3
	hide = 1
	bones = 2
	dead_height = 0.22
	gallop_stride = 1.7
	track_size = Vector2(0.2, 0.25)
	track_side = 0.09
	herd = "deer"
	kind = &"deer"


func body_node() -> Node3D:
	return _body


func _alarm_sound() -> AudioStream:
	return SNORT


func _on_stomp() -> void:
	_stomp = 0.7
	_play_voice(STOMP)


## Peito na frente do tronco e pescoço/cabeça são pontos vitais.
func _vital_multiplier(local_point: Vector3) -> float:
	if local_point.y > 1.25 and local_point.z > 0.35:
		return 3.0
	if local_point.z > 0.2:
		return 1.6
	return 1.0


func _build_body() -> void:
	model = CreatureModel.attach(self, _model_scene(), _palette(), _look_key())
	_body = model.joint("corpo")
	_chest = model.joint("peito")
	_neck = model.joint("pescoco")
	_head = model.joint("cabeca")
	_tail = model.joint("cauda")
	_ears = [model.joint("orelha_E"), model.joint("orelha_D")]
	_rest_body = _body.position
	_gait = QuadrupedGait.new()
	_gait.setup(model)
	_gait.stride_walk = 1.1
	_gait.stride_run = 2.6
	_gait.run_speed = 2.2


func _model_scene() -> PackedScene:
	return MODEL


## Regiões do pelo: [textura, tinta] ou Color (AnimalLook).
func _palette() -> Dictionary:
	return {
		"pelo": [AnimalLook.PELT, fur_color],
		"pelo_escuro": [AnimalLook.PELT, fur_color * Color(0.62, 0.6, 0.58)],
		"claro": [AnimalLook.PELT, Color(0.95, 0.9, 0.82)],
		"interno": [AnimalLook.PELT, Color(0.72, 0.6, 0.55)],
		"nariz": Color(0.06, 0.05, 0.05),
		"olho": Color(0.03, 0.025, 0.02),
		"casco": Color(0.1, 0.085, 0.07),
		"chifre": [AnimalLook.BRISTLE, Color(1.6, 1.45, 1.2)],
	}


func _look_key() -> String:
	return "deer"


func _build_hitbox(area: Area3D) -> void:
	_hit_shape(area, Vector3(0.38, 0.52, 1.2), Vector3(0.0, 1.0, -0.04))
	_hit_shape(area, Vector3(0.22, 0.6, 0.42), Vector3(0.0, 1.3, 0.55))


func _animate(delta: float) -> void:
	_gait.update(delta, speed)
	var run := _gait.run * _gait.motion
	var t := Time.get_ticks_msec() * 0.001
	# Galope: o corpo sobe e desce duas vezes por ciclo (traseiras empurram, dianteiras
	# recebem), a coluna dobra e estica e o pescoço vai e volta como contrapeso.
	var beat := sin(TAU * _gait.phase)
	var bob := (absf(sin(TAU * _gait.phase)) * 0.09 * run + absf(sin(TAU * _gait.phase * 2.0)) * 0.012 * (1.0 - run)) * _gait.motion
	_body.position = _rest_body + Vector3(0.0, bob - 0.03 * run, 0.0)
	_body.rotation.x = beat * 0.07 * run
	_chest.rotation.x = -beat * 0.08 * run
	# Respira: o peito enche devagar.
	_chest.scale = Vector3.ONE * (1.0 + sin(t * 1.8 + position.x) * 0.012)

	_graze = move_toward(_graze, 1.0 if state == State.GRAZE else 0.0, delta * 1.5)
	_lie = move_toward(_lie, 1.0 if state == State.SLEEP else 0.0, delta * 0.8)
	# Atento: cabeça erguida e orelhas em pé; desconfiado, ainda mais alta, encarando.
	var attention := clampf((awareness - Tuning.DEER_ALERT_AT * 0.5) / Tuning.DEER_ALERT_AT, 0.0, 1.0) if state != State.SLEEP else 0.0
	var alert := -0.3 if state == State.SUSPICIOUS else -0.12 * attention
	var chew := sin(t * 7.0) * 0.04 * _graze
	_neck.rotation.x = lerpf(alert, 1.25, _graze) + beat * 0.12 * run + sin(TAU * _gait.phase * 2.0) * 0.04 * (1.0 - run) * _gait.motion
	_head.rotation.x = lerpf(-0.05, 0.45, _graze) + chew - beat * 0.06 * run
	_head.rotation.y = sin(t * 0.37 + position.z) * 0.15 * (1.0 - _graze) * (1.0 - attention) * (1.0 - _gait.motion)
	for i in _ears.size():
		var side := 1.0 if i == 0 else -1.0
		var flick := maxf(sin(t * 0.9 + i * 2.1 + position.x), 0.0) ** 12.0
		_ears[i].rotation.z = -side * (0.45 * attention + flick * 0.5) + sin(t * 0.8 + i) * 0.06 * (1.0 - attention)
		_ears[i].rotation.x = -0.35 * attention - 0.3 * run
	# Rabo: abana de vez em quando; fugindo, ergue e mostra o espelho branco.
	var wag := maxf(sin(t * 0.7 + position.z), 0.0) ** 8.0
	_tail.rotation.x = -0.9 * run - 0.5 * float(state == State.SUSPICIOUS)
	_tail.rotation.y = sin(t * 14.0) * 0.35 * wag
	# Bate a pata da frente no chão.
	if _stomp > 0.0:
		_stomp = maxf(_stomp - delta, 0.0)
		_gait.lift_front("E", sin(clampf(_stomp / 0.7, 0.0, 1.0) * PI))
	# Deitado: o corpo desce, as pernas dobram por baixo e o pescoço vira para o lado.
	if _lie > 0.0:
		var fold := smoothstep(0.0, 1.0, _lie)
		_body.position.y = lerpf(_body.position.y, _rest_body.y * 0.42, fold)
		_gait.fold(fold)
		var nod := sin(Time.get_ticks_msec() * 0.0004 + position.x) > 0.93
		_neck.rotation.x = lerpf(_neck.rotation.x, -0.1 if nod else 0.5, fold)
		_neck.rotation.y = lerpf(0.0, 0.0 if nod else 0.8, fold)
	else:
		_neck.rotation.y = 0.0
