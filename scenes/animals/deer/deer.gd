class_name Deer
extends Animal
## Cervo: anda em manada, pasta de cabeça baixa (e aí enxerga mal), levanta a cabeça
## e bufa quando desconfia, e foge em disparada com a manada.

const SNORT := preload("res://assets/audio/animals/deer_snort.wav")

## Cor do pelo (o cervo branco troca).
var fur_color := Color(0.62, 0.43, 0.27)

var _body: Node3D
var _neck: Node3D
var _legs: Array[Node3D] = []
var _phase := 0.0
var _graze := 0.0


func _init() -> void:
	walk_speed = 1.1
	run_speed = 10.0
	home_radius = 20.0
	sight_range = 45.0
	hearing_range = 35.0
	smell_range = 35.0
	step_stride = 0.8
	step_volume_db = -11.0
	step_pitch = 0.9
	eye_height = 1.45
	calm_distance = 70.0
	max_health = 2.0
	meat = 3
	hide = 1
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


## Peito na frente do tronco e pescoço/cabeça são pontos vitais.
func _vital_multiplier(local_point: Vector3) -> float:
	if local_point.y > 1.25 and local_point.z > 0.35:
		return 3.0
	if local_point.z > 0.2:
		return 1.6
	return 1.0


func _build_body() -> void:
	var fur := fur_material(fur_color)
	var light := fur_material(Color(0.88, 0.84, 0.76))
	var dark := flat_material(Color(0.12, 0.1, 0.09))

	_body = _joint(self, Vector3(0.0, 1.0, 0.0))
	_box(_body, Vector3(0.42, 0.46, 1.15), Vector3.ZERO, fur)
	_box(_body, Vector3(0.3, 0.26, 0.06), Vector3(0.0, 0.04, -0.58), light)
	_box(_body, Vector3(0.1, 0.15, 0.06), Vector3(0.0, 0.16, -0.62), light, Vector3(-0.4, 0.0, 0.0))

	_neck = _joint(_body, Vector3(0.0, 0.12, 0.48))
	_box(_neck, Vector3(0.17, 0.6, 0.2), Vector3(0.0, 0.26, 0.1), fur, Vector3(0.4, 0.0, 0.0))
	var head := _joint(_neck, Vector3(0.0, 0.54, 0.24))
	_box(head, Vector3(0.2, 0.2, 0.32), Vector3(0.0, 0.0, 0.08), fur)
	_box(head, Vector3(0.12, 0.11, 0.12), Vector3(0.0, -0.04, 0.28), dark)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.05, 0.17, 0.1), Vector3(0.12 * side, 0.15, -0.04), fur, Vector3(0.0, 0.0, -0.55 * side))

	for leg_pos: Vector3 in [Vector3(0.14, -0.15, 0.45), Vector3(-0.14, -0.15, 0.45), Vector3(0.14, -0.15, -0.45), Vector3(-0.14, -0.15, -0.45)]:
		var hip := _joint(_body, leg_pos)
		_box(hip, Vector3(0.11, 0.48, 0.13), Vector3(0.0, -0.22, 0.0), fur)
		_box(hip, Vector3(0.07, 0.4, 0.07), Vector3(0.0, -0.62, 0.0), fur)
		_box(hip, Vector3(0.08, 0.06, 0.09), Vector3(0.0, -0.84, 0.02), dark)
		_legs.append(hip)


func _build_hitbox(area: Area3D) -> void:
	_hit_shape(area, Vector3(0.46, 0.56, 1.25), Vector3(0.0, 1.0, 0.0))
	_hit_shape(area, Vector3(0.26, 0.7, 0.42), Vector3(0.0, 1.5, 0.62))


func _animate(delta: float) -> void:
	var running := speed > 3.0
	_phase += delta * (speed * (1.6 if running else 3.2))
	var amp := 0.65 if running else clampf(speed / walk_speed, 0.0, 1.0) * 0.35
	# Passo: pares em diagonal. Galope: dianteiras juntas e traseiras juntas.
	var offsets := [0.0, 0.25, 1.4, 1.65] if running else [0.0, PI, PI, 0.0]
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + offsets[i]) * amp
	_body.position.y = 1.0 + absf(sin(_phase)) * (0.08 if running else 0.02) * amp
	_body.rotation.x = sin(_phase * 2.0) * 0.05 * amp if running else 0.0

	_graze = move_toward(_graze, 1.0 if state == State.GRAZE else 0.0, delta * 1.5)
	# Desconfiado: cabeça bem erguida, encarando o perigo.
	var alert := -0.3 if state == State.SUSPICIOUS else 0.0
	_neck.rotation.x = lerpf(alert, 1.35, _graze) + (sin(Time.get_ticks_msec() * 0.006) * 0.04 * _graze)
