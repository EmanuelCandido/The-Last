class_name Rabbit
extends Animal
## Coelho: anda aos pulinhos, mexe o focinho, congela quando desconfia e dispara
## em zigue-zague quando o perigo chega perto. Morre com uma flechada.

const SQUEAL := preload("res://assets/audio/animals/rabbit_squeal.wav")

const MODEL := preload("res://assets/models/animals/rabbit.glb")

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _ears: Array[Node3D] = []
var _hind: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _front: Array[Node3D] = []
var _rest_body := Vector3.ZERO
var _phase := 0.0


func _init() -> void:
	walk_speed = 0.6
	run_speed = 5.0
	turn_speed = 8.0
	home_radius = 12.0
	sight_range = 16.0
	hearing_range = 12.0
	smell_range = 10.0
	step_stride = 0.5
	gallop_stride = 0.9
	step_volume_db = -24.0
	step_pitch = 1.4
	kind = &"rabbit"
	eye_height = 0.3
	calm_distance = 35.0
	max_health = 0.5
	meat = 1
	hide = 1
	dead_height = 0.08
	track_size = Vector2(0.2, 0.34)


func body_node() -> Node3D:
	return _body


func _hurt_sound() -> AudioStream:
	return SQUEAL


func _build_body() -> void:
	model = CreatureModel.attach(self, MODEL, {
		"pelo": [AnimalLook.PELT, Color(0.66, 0.56, 0.44)],
		"pelo_escuro": [AnimalLook.PELT, Color(0.46, 0.38, 0.3)],
		"claro": [AnimalLook.PELT, Color(0.97, 0.94, 0.88)],
		"interno": [AnimalLook.PELT, Color(0.78, 0.62, 0.58)],
		"focinho": Color(0.55, 0.38, 0.36),
		"olho": Color(0.03, 0.025, 0.02),
	}, "rabbit")
	_body = model.joint("corpo")
	_head = model.joint("cabeca")
	_tail = model.joint("cauda")
	_ears = [model.joint("orelha_E"), model.joint("orelha_D")]
	_hind = [model.joint("t_coxa_E"), model.joint("t_coxa_D")]
	_feet = [model.joint("t_pata_E"), model.joint("t_pata_D")]
	_front = [model.joint("d_coxa_E"), model.joint("d_coxa_D")]
	_rest_body = _body.position


func _build_hitbox(area: Area3D) -> void:
	# Um pouco maior que o corpo: alvo pequeno, mas justo de acertar.
	_hit_shape(area, Vector3(0.26, 0.3, 0.4), Vector3(0.0, 0.17, 0.02))


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var hop := 0.0
	var hopping := minf(1.0, speed / 0.5)
	if speed > 0.1:
		# Pulinhos: as patas de trás empurram juntas (o corpo sobe de frente para trás), as da
		# frente pousam primeiro e as de trás passam por fora delas.
		_phase = fposmod(_phase + delta * (speed / (0.35 if speed > 2.0 else 0.18)), 1.0)
		hop = sin(PI * _phase)
	var height := (0.15 if speed > 2.0 else 0.06) * hopping
	_body.position = _rest_body + Vector3(0.0, hop * height, 0.0)
	_body.rotation.x = lerpf(_body.rotation.x, (-cos(TAU * _phase) * 0.25) * hopping, 1.0 - exp(-20.0 * delta))
	for i in 2:
		var push := smoothstep(0.0, 0.35, _phase) * (1.0 - smoothstep(0.35, 0.8, _phase)) * hopping
		_hind[i].rotation.x = (0.9 * push - 0.5 * smoothstep(0.7, 1.0, _phase) * hopping)
		_feet[i].rotation.x = -0.9 * push
		_front[i].rotation.x = lerpf(0.0, -0.6 + 1.0 * smoothstep(0.4, 0.9, _phase), hopping)
	# Congelado de orelha em pé quando desconfia; correndo, orelhas deitadas para trás;
	# comendo, cabeça baixa e o focinho mexendo sem parar.
	var nibble := 0.0 if state == State.SUSPICIOUS else sin(t * 30.0) * 0.03
	_head.rotation.x = (0.5 if state == State.GRAZE else -0.15) + nibble
	var flat := clampf((speed - 2.0) / 2.0, 0.0, 1.0)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var twitch := maxf(sin(t * 1.3 + i * 2.0 + position.z), 0.0) ** 14.0
		_ears[i].rotation = Vector3(-0.9 * flat + 0.12 * float(state == State.SUSPICIOUS), 0.0, -side * (0.12 + twitch * 0.5) * (1.0 - flat))
	_tail.rotation.x = -0.5 * flat
