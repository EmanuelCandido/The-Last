class_name Boar
extends Animal
## Javali (§8b-G): vive na mata fechada, fuçando de cabeça baixa e grunhindo. Enxerga mal, mas
## ouve e fareja bem. Assustado de longe, foge como os outros; de perto (Tuning.BOAR_CHARGE_RANGE)
## ou ferido, **investe**: corre reto até o goblin a BOAR_CHARGE_SPEED, fere (BOAR_DAMAGE) e o
## empurra, passa direto, para e encara. Faz isso até BOAR_CHARGES vezes; depois foge. Vira devagar
## correndo, então dá para sair da frente no último instante. Calmo de novo, recupera as investidas.

const GRUNTS := [preload("res://assets/audio/animals/boar_grunt_1.wav"), preload("res://assets/audio/animals/boar_grunt_2.wav")]
const SQUEAL := preload("res://assets/audio/real/boar_squeal.ogg")
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
const MODEL := preload("res://assets/models/animals/boar.glb")

var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _ears: Array[Node3D] = []
var _gait: QuadrupedGait
var _rest_body := Vector3.ZERO


func _init() -> void:
	walk_speed = 0.6
	run_speed = 4.7
	turn_speed = 5.0
	home_radius = 14.0
	sight_range = 14.0
	sight_fov_deg = 260.0
	hearing_range = 16.0
	smell_range = 27.0
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
	model = CreatureModel.attach(self, MODEL, {
		"pelo": [AnimalLook.BRISTLE, Color(1.35, 1.12, 0.92)],
		"pelo_escuro": [AnimalLook.BRISTLE, Color(0.85, 0.72, 0.6)],
		"crina": [AnimalLook.BRISTLE, Color(0.7, 0.6, 0.5)],
		"focinho": Color(0.3, 0.22, 0.2),
		"nariz": Color(0.06, 0.05, 0.05),
		"olho": Color(0.04, 0.03, 0.02),
		"presa": Color(0.84, 0.8, 0.68),
		"casco": Color(0.09, 0.08, 0.07),
	}, "boar")
	_body = model.joint("corpo")
	_head = model.joint("cabeca")
	_tail = model.joint("cauda")
	_ears = [model.joint("orelha_E"), model.joint("orelha_D")]
	_rest_body = _body.position
	_gait = QuadrupedGait.new()
	_gait.setup(model)
	_gait.stride_walk = 0.75
	_gait.stride_run = 1.6
	_gait.reach_walk = 0.25
	_gait.reach_run = 0.6
	_gait.fold_run = 1.1
	_gait.run_speed = 1.8


## Sem pescoço: a cabeça pesada vira sozinha para o chão. O corpo redondo não deita tão de lado.
func _setup_death(fall: CreatureDeath) -> void:
	fall.roll = 1.3
	fall.shift = 0.14
	fall.head_tilt = 0.1
	fall.head_drop = 0.35


func _build_hitbox(area: Area3D) -> void:
	_hit_shape(area, Vector3(0.46, 0.56, 1.0), Vector3(0.0, 0.54, -0.02))
	_hit_shape(area, Vector3(0.3, 0.32, 0.42), Vector3(0.0, 0.5, 0.62))


func _animate(delta: float) -> void:
	_gait.update(delta, speed)
	var run := _gait.run * _gait.motion
	var t := Time.get_ticks_msec() * 0.001
	var beat := sin(TAU * _gait.phase)
	# Corpo pesado: sacode de lado andando e martela para cima e para baixo correndo.
	_body.position = _rest_body + Vector3(sin(TAU * _gait.phase) * 0.012 * (1.0 - run) * _gait.motion,
		absf(beat) * 0.05 * run + absf(sin(TAU * _gait.phase * 2.0)) * 0.01 * (1.0 - run) * _gait.motion, 0.0)
	_body.rotation = Vector3(beat * 0.05 * run, 0.0, sin(TAU * _gait.phase) * 0.03 * _gait.motion * (1.0 - run))
	# Fuçando: cabeça baixa, focinho cavando aos trancos; investindo, cabeça baixa e firme.
	var root := 0.0
	if state == State.GRAZE:
		root = 0.45 + (sin(t * 8.0) * 0.5 + 0.5) ** 3.0 * 0.15
	elif charge == Charge.RUN:
		root = 0.3
	_head.rotation.x = lerpf(_head.rotation.x, root - beat * 0.05 * run, 1.0 - exp(-6.0 * delta))
	_head.rotation.y = lerpf(_head.rotation.y, sin(t * 1.3) * 0.12 * float(state == State.GRAZE), 1.0 - exp(-3.0 * delta))
	for i in _ears.size():
		var side := 1.0 if i == 0 else -1.0
		var flick := maxf(sin(t * 1.1 + i * 1.7 + position.x), 0.0) ** 10.0
		_ears[i].rotation = Vector3(-0.2 * float(charge != Charge.NONE) - 0.35 * run, 0.0, -side * flick * 0.4)
	# O rabo fino abana sem parar.
	_tail.rotation = Vector3(-0.6 * run, sin(t * (9.0 if state == State.GRAZE else 4.0)) * 0.45, 0.0)
