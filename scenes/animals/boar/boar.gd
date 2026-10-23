class_name Boar
extends Animal
## Javali (§8b-G): vive na mata fechada, fuçando de cabeça baixa e grunhindo. Enxerga mal, mas
## ouve e fareja bem. Assustado de longe, foge como os outros; de perto (Tuning.BOAR_CHARGE_RANGE)
## ou ferido, **investe**: corre reto até o goblin a BOAR_CHARGE_SPEED, fere (BOAR_DAMAGE) e o
## empurra, passa direto, para e encara. Faz isso até BOAR_CHARGES vezes; depois foge. Vira devagar
## correndo, então dá para sair da frente no último instante. Calmo de novo, recupera as investidas.

const GRUNTS := [preload("res://assets/audio/animals/boar_grunt_1.wav"), preload("res://assets/audio/animals/boar_grunt_2.wav")]
const SQUEAL := preload("res://assets/audio/animals/boar_squeal.wav")
const HIT_SOUND := preload("res://assets/audio/animals/wolf_bite.wav")
const HIT_RANGE := 1.1
const RUN_SECONDS := 3.5
const PAST_SECONDS := 1.0
const GLARE_SECONDS := 1.3
## Virando enquanto investe (rad/s): devagar, para o goblin conseguir se desviar.
const CHARGE_TURN := 2.2

enum Charge { NONE, RUN, PAST, GLARE }

var charge := Charge.NONE
var charges_left := 0

var _charge_timer := 0.0
var _charge_yaw := 0.0
var _grunt_timer := 4.0
var _warned_day := -1
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _phase := 0.0


func _init() -> void:
	walk_speed = 0.9
	run_speed = 7.0
	turn_speed = 5.0
	home_radius = 14.0
	sight_range = 26.0
	sight_fov_deg = 260.0
	hearing_range = 30.0
	smell_range = 50.0
	eye_height = 0.6
	calm_distance = 45.0
	max_health = 3.0
	meat = 4
	hide = 1
	bones = 2
	dead_height = 0.22
	step_stride = 0.6
	gallop_stride = 1.0
	step_volume_db = -14.0
	step_pitch = 0.8
	kind = &"boar"
	charges_left = Tuning.BOAR_CHARGES


func body_node() -> Node3D:
	return _body


func _alarm_sound() -> AudioStream:
	return GRUNTS[0]


func _hurt_sound() -> AudioStream:
	return SQUEAL


func _vital_multiplier(local_point: Vector3) -> float:
	return 1.5 if local_point.z > 0.25 else 1.0


func take_hit(power: float, point: Vector3, direction: Vector3, damage := 1.0) -> void:
	super.take_hit(power, point, direction, damage)
	# Ferido e perto, vem para cima em vez de fugir.
	var player := Game.player
	if state != State.DEAD and charges_left > 0 and charge == Charge.NONE and player != null \
			and player.global_position.distance_to(global_position) < Tuning.BOAR_CHARGE_RANGE * 1.7:
		_start_charge()


# --- Decisão ---------------------------------------------------------------------

func _think(delta: float, here: Vector2) -> void:
	_grunt_timer -= delta
	if _grunt_timer <= 0.0:
		_grunt_timer = _rng.randf_range(5.0, 12.0)
		if state in [State.IDLE, State.GRAZE, State.WALK]:
			_play_voice(GRUNTS.pick_random())
	if charge != Charge.NONE:
		_think_charge(delta, here)
		return
	var player := Game.player
	if player != null and awareness >= FLEE and charges_left > 0 and state != State.FLEE \
			and here.distance_to(_flat(player.global_position)) < Tuning.BOAR_CHARGE_RANGE:
		_start_charge()
		return
	if state in [State.IDLE, State.GRAZE, State.WALK] and awareness < 0.1:
		charges_left = Tuning.BOAR_CHARGES
	super._think(delta, here)


func _start_charge() -> void:
	charge = Charge.RUN
	_charge_timer = RUN_SECONDS
	state = State.SUSPICIOUS
	_play_voice(SQUEAL)


func _think_charge(delta: float, here: Vector2) -> void:
	_charge_timer -= delta
	var player := Game.player
	if player == null:
		charge = Charge.NONE
		return
	var target := _flat(player.global_position)
	match charge:
		Charge.RUN:
			var close := here.distance_to(target) < HIT_RANGE and absf(player.global_position.y - global_position.y) < 1.2
			if close:
				_hit(player)
			if close or _charge_timer <= 0.0:
				charge = Charge.PAST
				_charge_timer = PAST_SECONDS
		Charge.PAST:
			if _charge_timer <= 0.0:
				charges_left -= 1
				charge = Charge.GLARE
				_charge_timer = GLARE_SECONDS
				_play_voice(GRUNTS.pick_random())
		Charge.GLARE:
			if _charge_timer <= 0.0:
				if charges_left > 0 and here.distance_to(target) < Tuning.BOAR_CHARGE_RANGE * 1.3:
					_start_charge()
				else:
					charge = Charge.NONE
					_threat = target
					awareness = 1.5
					_enter(State.FLEE)


func _hit(player: Player) -> void:
	OccludedAudio.play_at(get_parent(), HIT_SOUND, global_position + Vector3.UP * 0.5, &"World", -1.0, 4.0, _rng.randf_range(0.7, 0.85))
	var push := Vector3(sin(_yaw), 0.0, cos(_yaw))
	player.velocity += push * 4.0 + Vector3.UP * 2.0
	Vitals.damage(Tuning.BOAR_DAMAGE, &"boar")
	if _warned_day != Clock.day:
		_warned_day = Clock.day
		Events.notification_shown.emit("Javali! Saia da frente dele.")


# --- Movimento -------------------------------------------------------------------

func _move(delta: float, here: Vector2) -> void:
	if charge == Charge.NONE:
		super._move(delta, here)
		return
	var player := Game.player
	var desired_speed := Tuning.BOAR_CHARGE_SPEED
	if charge == Charge.RUN and player != null:
		_charge_yaw = rotate_toward(_charge_yaw, _yaw_towards(_flat(player.global_position) - here), CHARGE_TURN * delta)
	elif charge == Charge.GLARE:
		desired_speed = 0.0
		if player != null:
			_charge_yaw = rotate_toward(_charge_yaw, _yaw_towards(_flat(player.global_position) - here), 3.0 * delta)
	speed = move_toward(speed, desired_speed, 16.0 * delta)
	_yaw = _charge_yaw
	var next := here + Vector2(sin(_yaw), cos(_yaw)) * speed * delta
	if speed > 0.0 and not _is_walkable(next):
		next = here
		speed = 0.0
		if charge != Charge.GLARE:
			charge = Charge.PAST
			_charge_timer = 0.0
	position = Vector3(next.x, terrain.get_height(next.x, next.y), next.y)
	rotation.y = _yaw
	_leave_tracks(speed * delta)
	_play_steps(speed * delta)


func _enter(new_state: State) -> void:
	super._enter(new_state)
	_charge_yaw = _yaw


func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


# --- Corpo -----------------------------------------------------------------------

func _build_body() -> void:
	var bristle := fur_material(Color(0.2, 0.16, 0.13))
	var dark := flat_material(Color(0.1, 0.08, 0.07))
	var tusk := flat_material(Color(0.86, 0.82, 0.7))
	var snout := flat_material(Color(0.32, 0.24, 0.22))

	_body = _joint(self, Vector3(0.0, 0.52, 0.0))
	_box(_body, Vector3(0.46, 0.5, 0.95), Vector3.ZERO, bristle)
	_box(_body, Vector3(0.5, 0.56, 0.35), Vector3(0.0, 0.04, 0.3), bristle)
	# A crina de cerdas no lombo.
	_box(_body, Vector3(0.1, 0.1, 0.8), Vector3(0.0, 0.3, 0.05), dark)

	_head = _joint(_body, Vector3(0.0, 0.0, 0.5))
	_box(_head, Vector3(0.32, 0.32, 0.34), Vector3(0.0, -0.03, 0.12), bristle, Vector3(0.25, 0.0, 0.0))
	_box(_head, Vector3(0.16, 0.14, 0.18), Vector3(0.0, -0.13, 0.32), snout)
	_box(_head, Vector3(0.13, 0.11, 0.03), Vector3(0.0, -0.15, 0.42), dark)
	for side: float in [-1.0, 1.0]:
		_box(_head, Vector3(0.025, 0.09, 0.025), Vector3(0.08 * side, -0.1, 0.36), tusk, Vector3(-0.5, 0.0, 0.3 * side))
		_box(_head, Vector3(0.06, 0.09, 0.03), Vector3(0.11 * side, 0.15, 0.0), bristle, Vector3(0.0, 0.0, -0.4 * side))

	for leg_pos: Vector3 in [Vector3(0.14, -0.2, 0.35), Vector3(-0.14, -0.2, 0.35), Vector3(0.14, -0.2, -0.35), Vector3(-0.14, -0.2, -0.35)]:
		var hip := _joint(_body, leg_pos)
		_box(hip, Vector3(0.1, 0.22, 0.12), Vector3(0.0, -0.08, 0.0), bristle)
		_box(hip, Vector3(0.06, 0.12, 0.06), Vector3(0.0, -0.24, 0.0), bristle)
		_box(hip, Vector3(0.07, 0.04, 0.08), Vector3(0.0, -0.31, 0.02), dark)
		_legs.append(hip)


func _build_hitbox(area: Area3D) -> void:
	_hit_shape(area, Vector3(0.5, 0.56, 1.05), Vector3(0.0, 0.52, 0.0))
	_hit_shape(area, Vector3(0.34, 0.34, 0.4), Vector3(0.0, 0.5, 0.65))


func _animate(delta: float) -> void:
	var running := speed > 3.0
	_phase += delta * (speed * (2.4 if running else 5.0))
	var amp := 0.7 if running else clampf(speed / walk_speed, 0.0, 1.0) * 0.4
	var offsets := [0.0, 0.3, 1.5, 1.8] if running else [0.0, PI, PI, 0.0]
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + offsets[i]) * amp
	_body.position.y = 0.52 + absf(sin(_phase)) * (0.05 if running else 0.015) * amp
	# Fuçando: cabeça baixa, mexendo; investindo, cabeça baixa e firme, presas para a frente.
	var root := 0.0
	if state == State.GRAZE:
		root = 0.5 + sin(Time.get_ticks_msec() * 0.008) * 0.12
	elif charge == Charge.RUN:
		root = 0.35
	_head.rotation.x = lerpf(_head.rotation.x, root, 1.0 - exp(-6.0 * delta))
