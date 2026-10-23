class_name Wolf
extends Animal
## Lobo: o caçador da noite. Tem os mesmos sentidos dos outros bichos (vê, ouve e fareja o
## goblin), mas em vez de fugir:
## - ronda: anda pela área de caça, que a matilha arrasta para onde o goblin está;
## - espreita (desconfiado): chega devagar, de cabeça baixa, rosnando, e para a uns metros;
## - caça (percebeu de vez): corre e morde (Tuning.WOLF_BITE a cada WOLF_BITE_INTERVAL).
## Não chega perto de fogo aceso (Tuning.WOLF_FIRE_FEAR): o goblin junto da fogueira está
## salvo. Uma flechada o faz fugir e ir embora; duas matam. Ao amanhecer (leave) vai embora.
## Uiva parado, de focinho para cima (howl): é o aviso da matilha e o chamado das matilhas
## distantes (WolfPack).
##
## A caverna não é proibida para ele, como é para cervos e coelhos: com o fogo apagado,
## ele entra.

enum Mode { PROWL, STALK, HUNT }

const GROWLS := [preload("res://assets/audio/animals/wolf_growl_1.wav"), preload("res://assets/audio/animals/wolf_growl_2.wav")]
const BITE := preload("res://assets/audio/animals/wolf_bite.wav")
const YELP := preload("res://assets/audio/animals/wolf_yelp.wav")
## Na espreita, para a esta distância do goblin.
const STALK_DISTANCE := 9.0
## Some quando está indo embora e fica a esta distância do goblin.
const GONE_DISTANCE := 60.0

## Último dia em que um lobo avisou o jogador da primeira mordida (uma vez por noite).
static var _warned_day := -1

var mode := Mode.PROWL
## Indo embora (amanhecer ou ferido): foge e some longe do goblin.
var leaving := false
## Esperando na borda do vale até a hora de chegar: ronda ali, sem seguir o rastro do goblin.
var waiting := false
## Lobo de uma matilha distante, além do vale: fica parado, uiva de lá e some.
var distant := false

## Segundos que ainda faltam do uivo (parado, cabeça para cima).
var _howl := 0.0
var _body: Node3D
var _neck: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _phase := 0.0
var _bite_timer := 0.0
var _growl_timer := 0.0
var _drift_timer := 0.0
var _lunge := 0.0


func _init() -> void:
	walk_speed = 1.5
	run_speed = 7.0
	turn_speed = 6.0
	home_radius = 30.0
	sight_range = 35.0
	sight_fov_deg = 240.0
	hearing_range = 40.0
	smell_range = 90.0
	step_stride = 0.75
	step_volume_db = -16.0
	step_pitch = 1.1
	eye_height = 0.65
	calm_distance = 80.0
	max_health = 2.0
	meat = 2
	hide = 2
	dead_height = 0.16
	gallop_stride = 1.1
	track_size = Vector2(0.2, 0.23)
	track_side = 0.07
	herd = "wolves"
	kind = &"wolf"


## Amanhecer: a matilha vai embora (e some de vez, mesmo que não se afaste o bastante).
func leave() -> void:
	if state == State.DEAD:
		return
	leaving = true
	if Game.player != null:
		_threat = Vector2(Game.player.global_position.x, Game.player.global_position.z)
	_enter(State.FLEE)
	get_tree().create_timer(45.0, false).timeout.connect(queue_free)


## Um da matilha viu o goblin (ou foi ferido): os outros não fogem, entram na caçada.
func alarm(threat: Vector2) -> void:
	if state == State.DEAD or leaving:
		return
	_threat = threat
	awareness = maxf(awareness, 1.0)


func body_node() -> Node3D:
	return _body


## Para, ergue a cabeça e uiva por `seconds` (o som sai de mouth_position, pelo Ambience).
func howl(seconds: float) -> void:
	if state == State.DEAD:
		return
	_howl = seconds
	_enter(State.IDLE)


## A boca, de onde sai o uivo.
func mouth_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.95, 0.6)


func _alarm_sound() -> AudioStream:
	return GROWLS.pick_random()


func _hurt_sound() -> AudioStream:
	return YELP


## Cabeça e pescoço matam mais; o peito, um pouco.
func _vital_multiplier(local_point: Vector3) -> float:
	if local_point.z > 0.4:
		return 2.0
	if local_point.z > 0.15:
		return 1.4
	return 1.0


func take_hit(power: float, point: Vector3, direction: Vector3, damage := 1.0) -> void:
	super.take_hit(power, point, direction, damage)
	# Ferido, não volta: vai embora da noite.
	if state != State.DEAD:
		leaving = true


# --- Decisão ---------------------------------------------------------------------

func _think(delta: float, here: Vector2) -> void:
	_timer -= delta
	_bite_timer -= delta
	_growl_timer -= delta
	_howl -= delta
	# Uivando (ou longe, além do vale): fica parado onde está.
	if (_howl > 0.0 and state != State.FLEE) or distant:
		if state != State.IDLE:
			_enter(State.IDLE)
		_timer = maxf(_timer, 0.5)
		return
	var player := Game.player
	if state == State.FLEE:
		if leaving and player != null and here.distance_to(_flat(player.global_position)) > GONE_DISTANCE:
			queue_free()
		elif not leaving and _timer <= 0.0:
			_enter(State.WALK)
		return
	if player == null:
		return

	var target := _flat(player.global_position)
	_drift_timer -= delta
	if _drift_timer <= 0.0 and not waiting:
		# A matilha vai seguindo o rastro: a área de caça escorrega para onde o goblin está.
		_drift_timer = Tuning.WOLF_HOME_DRIFT_SECONDS
		home = home.move_toward(target, 14.0)

	if awareness >= FLEE:
		mode = Mode.HUNT
	elif awareness >= SUSPICIOUS and mode != Mode.HUNT:
		mode = Mode.STALK
	elif awareness < SUSPICIOUS * 0.5:
		mode = Mode.PROWL

	match mode:
		Mode.PROWL:
			if state != State.WALK and state != State.IDLE:
				_enter(State.WALK)
			elif state == State.WALK and (here.distance_to(_target) < 0.8 or _timer <= 0.0):
				_enter(State.IDLE if _rng.randf() < 0.4 else State.WALK)
			elif state == State.IDLE and _timer <= 0.0:
				_enter(State.WALK)
		Mode.STALK, Mode.HUNT:
			if state != State.SUSPICIOUS:
				state = State.SUSPICIOUS
			_threat = target
			if _growl_timer <= 0.0:
				_growl_timer = _rng.randf_range(2.5, 5.0)
				_play_voice(GROWLS.pick_random())
			var close := here.distance_to(target) < Tuning.WOLF_BITE_RANGE
			if mode == Mode.HUNT and close and _bite_timer <= 0.0 and not _fire_near(target):
				_bite(player)


func _bite(player: Player) -> void:
	_bite_timer = Tuning.WOLF_BITE_INTERVAL
	_lunge = 1.0
	OccludedAudio.play_at(get_parent(), BITE, global_position + Vector3.UP * 0.5, &"World", -1.0, 4.0, _rng.randf_range(0.9, 1.1))
	var push := (player.global_position - global_position) * Vector3(1.0, 0.0, 1.0)
	player.velocity += push.normalized() * 2.5 + Vector3.UP * 1.2
	Vitals.damage(Tuning.WOLF_BITE, &"wolf")
	if _warned_day != Clock.day:
		_warned_day = Clock.day
		Events.notification_shown.emit("Lobo! Corra para o fogo.")


# --- Movimento -------------------------------------------------------------------

func _move(delta: float, here: Vector2) -> void:
	if state != State.SUSPICIOUS:
		super._move(delta, here)
		return
	var to_target := _threat - here
	var distance := to_target.length()
	var desired_speed := 0.0
	if mode == Mode.HUNT:
		desired_speed = run_speed * clampf((distance - Tuning.WOLF_BITE_RANGE * 0.6) / 2.0, 0.0, 1.0)
	elif distance > STALK_DISTANCE:
		desired_speed = walk_speed * 0.7
	var desired_yaw := _yaw_towards(to_target)
	# Não pisa perto do fogo: para na beira e fica rondando de lado.
	var ahead := here + to_target.normalized() * 1.5
	if _fire_near(ahead):
		desired_speed = walk_speed * 0.5
		desired_yaw = _yaw_towards(to_target.orthogonal())
	if _fire_near(here):
		var fire_away := _away_from_fire(here)
		desired_speed = walk_speed
		desired_yaw = _yaw_towards(fire_away)
	speed = move_toward(speed, desired_speed, (14.0 if mode == Mode.HUNT else 3.0) * delta)
	_yaw = lerp_angle(_yaw, desired_yaw, 1.0 - exp(-turn_speed * delta))
	var next := here + Vector2(sin(_yaw), cos(_yaw)) * speed * delta
	if speed > 0.0 and not _is_walkable(next):
		next = here
		speed = 0.0
	position = Vector3(next.x, terrain.get_height(next.x, next.y), next.y)
	rotation.y = _yaw
	_leave_tracks(speed * delta)
	_play_steps(speed * delta)


func _is_walkable(p: Vector2) -> bool:
	if p.length() >= ForestLayout.VALLEY_RADIUS or terrain.get_normal(p.x, p.y).y <= 0.8:
		return false
	# Pode entrar pela boca da caverna até o fundo do salão; só a rocha é proibida.
	var local := p - ForestLayout.CAVE_CENTER
	var in_hall := absf(local.x) < ForestLayout.CAVE_HALF_WIDTH - 0.8 and local.y < ForestLayout.CAVE_DEPTH * 0.5 - 0.8
	return in_hall or ForestLayout.cave_ellipse(p) > 1.05


func _fire_near(p: Vector2) -> bool:
	return Campfire.distance_to_fire(Vector3(p.x, 0.0, p.y)) < Tuning.WOLF_FIRE_FEAR


func _away_from_fire(p: Vector2) -> Vector2:
	var away := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(Campfire.FIRE_GROUP):
		var fire := node as Node3D
		if fire.is_lit():
			away += p - _flat(fire.global_position)
	return away.normalized() if away.length_squared() > 0.0001 else -p.normalized()


func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


# --- Corpo -----------------------------------------------------------------------

func _build_body() -> void:
	var fur := fur_material(Color(0.36, 0.34, 0.31))
	var pale := fur_material(Color(0.58, 0.55, 0.5))
	var dark := flat_material(Color(0.08, 0.07, 0.07))
	# Olhos que brilham no escuro (a luz voltando da retina): é o que se vê à noite.
	# Emissão acima do limite do glow do ambiente: o brilho aparece de longe no escuro.
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color(0.2, 0.18, 0.08)
	eyes.emission_enabled = true
	eyes.emission = Color(0.95, 0.82, 0.4)
	eyes.emission_energy_multiplier = 3.5

	_body = _joint(self, Vector3(0.0, 0.56, 0.0))
	_box(_body, Vector3(0.3, 0.32, 0.85), Vector3.ZERO, fur)
	_box(_body, Vector3(0.33, 0.37, 0.3), Vector3(0.0, 0.01, 0.3), fur)
	_box(_body, Vector3(0.2, 0.14, 0.5), Vector3(0.0, -0.13, 0.12), pale)

	_neck = _joint(_body, Vector3(0.0, 0.08, 0.42))
	_box(_neck, Vector3(0.19, 0.21, 0.26), Vector3(0.0, 0.04, 0.1), fur, Vector3(-0.35, 0.0, 0.0))
	var head := _joint(_neck, Vector3(0.0, 0.1, 0.24))
	_box(head, Vector3(0.21, 0.18, 0.22), Vector3.ZERO, fur)
	_box(head, Vector3(0.1, 0.09, 0.18), Vector3(0.0, -0.035, 0.18), pale)
	_box(head, Vector3(0.05, 0.04, 0.04), Vector3(0.0, -0.01, 0.28), dark)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.05, 0.11, 0.04), Vector3(0.065 * side, 0.13, -0.03), fur, Vector3(0.0, 0.0, -0.2 * side))
		_box(head, Vector3(0.034, 0.026, 0.012), Vector3(0.055 * side, 0.035, 0.112), eyes)

	_tail = _joint(_body, Vector3(0.0, 0.1, -0.42))
	_box(_tail, Vector3(0.08, 0.08, 0.38), Vector3(0.0, -0.06, -0.17), fur, Vector3(0.5, 0.0, 0.0))

	for leg_pos: Vector3 in [Vector3(0.1, -0.12, 0.32), Vector3(-0.1, -0.12, 0.32), Vector3(0.1, -0.12, -0.32), Vector3(-0.1, -0.12, -0.32)]:
		var hip := _joint(_body, leg_pos)
		_box(hip, Vector3(0.08, 0.26, 0.09), Vector3(0.0, -0.12, 0.0), fur)
		_box(hip, Vector3(0.05, 0.22, 0.05), Vector3(0.0, -0.33, 0.0), fur)
		_box(hip, Vector3(0.06, 0.04, 0.08), Vector3(0.0, -0.43, 0.02), dark)
		_legs.append(hip)


func _build_hitbox(area: Area3D) -> void:
	_hit_shape(area, Vector3(0.34, 0.4, 0.95), Vector3(0.0, 0.56, 0.0))
	_hit_shape(area, Vector3(0.24, 0.24, 0.32), Vector3(0.0, 0.72, 0.62))


func _animate(delta: float) -> void:
	var running := speed > 3.0
	_phase += delta * (speed * (2.2 if running else 4.0))
	var amp := 0.7 if running else clampf(speed / walk_speed, 0.0, 1.0) * 0.4
	var offsets := [0.0, 0.3, 1.5, 1.8] if running else [0.0, PI, PI, 0.0]
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + offsets[i]) * amp
	_lunge = move_toward(_lunge, 0.0, delta * 3.0)
	_body.position = Vector3(0.0, 0.56 + absf(sin(_phase)) * (0.06 if running else 0.015) * amp, 0.25 * _lunge)
	_body.rotation.x = sin(_phase * 2.0) * 0.06 * amp if running else 0.0
	# Espreitando, cabeça baixa e rabo baixo; caçando, cabeça esticada à frente.
	var low := 0.0
	if state == State.SUSPICIOUS:
		low = 0.35 if mode == Mode.STALK else 0.15
	elif _howl > 0.0:
		# Uivando: focinho para o céu.
		low = -0.9
	_neck.rotation.x = lerpf(_neck.rotation.x, low - 0.35 * _lunge, 1.0 - exp(-6.0 * delta))
	_tail.rotation.x = lerpf(_tail.rotation.x, 0.35 if state == State.SUSPICIOUS else 0.0, 1.0 - exp(-4.0 * delta))
	_tail.rotation.y = sin(Time.get_ticks_msec() * 0.004) * (0.25 if state != State.SUSPICIOUS else 0.05)
