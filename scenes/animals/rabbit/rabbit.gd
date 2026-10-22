class_name Rabbit
extends Animal
## Coelho: anda aos pulinhos, mexe o focinho, congela quando desconfia e dispara
## em zigue-zague quando o perigo chega perto. Morre com uma flechada.

const SQUEAL := preload("res://assets/audio/animals/rabbit_squeal.wav")

var _body: Node3D
var _head: Node3D
var _phase := 0.0


func _init() -> void:
	walk_speed = 0.9
	run_speed = 7.5
	turn_speed = 8.0
	home_radius = 12.0
	sight_range = 30.0
	hearing_range = 22.0
	smell_range = 30.0
	eye_height = 0.3
	calm_distance = 35.0
	max_health = 0.5
	meat = 1
	hide = 1
	dead_height = 0.08


func body_node() -> Node3D:
	return _body


func _hurt_sound() -> AudioStream:
	return SQUEAL


func _build_body() -> void:
	var fur := fur_material(Color(0.5, 0.44, 0.36))
	var light := flat_material(Color(0.86, 0.84, 0.8))

	_body = _joint(self, Vector3(0.0, 0.13, 0.0))
	_box(_body, Vector3(0.2, 0.18, 0.3), Vector3.ZERO, fur)
	_box(_body, Vector3(0.07, 0.07, 0.06), Vector3(0.0, 0.03, -0.17), light)
	_head = _joint(_body, Vector3(0.0, 0.09, 0.15))
	_box(_head, Vector3(0.13, 0.13, 0.14), Vector3(0.0, 0.0, 0.03), fur)
	for side in [-1.0, 1.0]:
		_box(_head, Vector3(0.035, 0.16, 0.02), Vector3(0.035 * side, 0.13, -0.02), fur, Vector3(-0.25, 0.0, -0.15 * side))
		_box(_body, Vector3(0.06, 0.08, 0.16), Vector3(0.08 * side, -0.08, -0.06), fur)
		_box(_body, Vector3(0.04, 0.1, 0.04), Vector3(0.05 * side, -0.08, 0.1), fur)


func _build_hitbox(area: Area3D) -> void:
	# Um pouco maior que o corpo: alvo pequeno, mas justo de acertar.
	_hit_shape(area, Vector3(0.26, 0.3, 0.4), Vector3(0.0, 0.17, 0.02))


func _animate(delta: float) -> void:
	if speed > 0.1:
		_phase += delta * (speed * 3.0 + 4.0)
		_body.position.y = 0.13 + absf(sin(_phase)) * 0.15 * minf(1.0, speed)
		_body.rotation.x = -cos(_phase) * 0.25 * minf(1.0, speed)
	else:
		_body.position.y = move_toward(_body.position.y, 0.13, delta)
		_body.rotation.x = 0.0
	# Congelado de orelha em pé quando desconfia; focinho mexendo e cabeça baixa comendo.
	var nibble := 0.0 if state == State.SUSPICIOUS else sin(Time.get_ticks_msec() * 0.03) * 0.03
	_head.rotation.x = (0.5 if state == State.GRAZE else -0.15) + nibble
