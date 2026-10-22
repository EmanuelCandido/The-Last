class_name GoblinAnimator
extends Node
## Anima o goblin por código, direto no esqueleto.
##
## - Passada: cada pé segue uma trajetória (apoio no chão, depois arco no ar) e a perna
##   é resolvida com IK de duas juntas, então o pé não escorrega e o joelho dobra de verdade.
## - Corpo: quadril sobe e balança, tronco gira ao contrário, braços em oposição às pernas,
##   inclinação nas curvas, respiração e olhar em volta parado, orelhas com mola.
## - Estados: agachar, no ar, aterrissar, mirar com o arco.
## - Ações cronometradas: acordar, pegar algo do chão, coletar a caça, golpear.
##
## Cada frame monta uma pose (dicionário de números, ver _neutral) e só no fim a converte
## em rotações de ossos. Ângulos em radianos, eixos no espaço do modelo: Y para cima,
## +Z para a frente, +X é o lado esquerdo (E); "l" = esquerdo (E), "r" = direito (D).

## Um pé tocou o chão (0 = esquerdo, 1 = direito): hora do som do passo.
signal foot_planted(side: int)
signal action_finished(action: StringName)

const BONES := [
	"quadril", "tronco", "cabeca", "perna_E", "canela_E", "pe_E", "perna_D", "canela_D", "pe_D",
	"braco_E", "antebraco_E", "mao_E", "braco_D", "antebraco_D", "mao_D", "orelha_E", "orelha_D",
]

## Estado do corpo, preenchido pelo Player a cada frame.
var velocity_local := Vector3.ZERO
var on_floor := true
var crouching := false
var aiming := false
var draw := 0.0
## Inclinação da câmera (rad, + olhando para cima).
var aim_pitch := 0.0
## Velocidade de giro do corpo (rad/s).
var turn_rate := 0.0

var skeleton: Skeleton3D
var _bones := {}
var _rest_global := {}
var _pelvis_rest := Vector3.ZERO
var _hip_height := 0.36
var _ankle_height := 0.08
var _thigh := 0.13
var _shin := 0.15
var _rest_leg := Vector2.ZERO

var _time := 0.0
var _phase := 0.0
var _weights := {"move": 0.0, "run": 0.0, "crouch": 0.0, "aim": 0.0, "air": 0.0}
var _planted := [true, true]
var _land := 0.0
var _last_pelvis_y := 0.36
var _ears := [0.0, 0.0]
var _ear_speed := [0.0, 0.0]
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _look_timer := 3.0

var _action := &""
var _action_time := 0.0
var _action_duration := 0.0
var _action_events: Array = []


## Liga no esqueleto. Devolve false se o modelo não tiver os ossos articulados.
func setup(target: Skeleton3D) -> bool:
	skeleton = target
	for bone_name: String in BONES:
		var index := skeleton.find_bone(bone_name)
		if index == -1:
			push_warning("GoblinAnimator: osso '%s' não existe; animação procedural desligada." % bone_name)
			return false
		_bones[bone_name] = index
	for i in skeleton.get_bone_count():
		_rest_global[i] = skeleton.get_bone_global_rest(i).basis
	_pelvis_rest = skeleton.get_bone_rest(_bones.quadril).origin
	var hip := skeleton.get_bone_global_rest(_bones.perna_E).origin
	var knee := skeleton.get_bone_global_rest(_bones.canela_E).origin
	var ankle := skeleton.get_bone_global_rest(_bones.pe_E).origin
	_hip_height = hip.y
	_ankle_height = ankle.y
	_thigh = hip.distance_to(knee)
	_shin = knee.distance_to(ankle)
	_rest_leg = _leg_angles(ankle.z - hip.z, hip.y - ankle.y)
	_last_pelvis_y = _hip_height
	skeleton.reset_bone_poses()
	return true


## Começa uma ação. `events` = [[segundos, Callable], ...], chamados uma vez no tempo certo.
func play_action(action: StringName, duration: float, events: Array = []) -> void:
	_action = action
	_action_time = 0.0
	_action_duration = duration
	_action_events = events.duplicate()


func is_busy() -> bool:
	return _action != &""


func notify_landing(impact_speed: float) -> void:
	_land = maxf(_land, clampf(impact_speed / 7.0, 0.15, 1.0))


func update(delta: float) -> void:
	if skeleton == null or _bones.is_empty():
		return
	_time += delta
	_update_weights(delta)
	_update_look(delta)
	_land = move_toward(_land, 0.0, delta * 2.5)

	var pose := _locomotion(delta)
	_aim_overlay(pose)
	if _action != &"":
		_action_time += delta
		for event: Array in _action_events.duplicate():
			if _action_time >= event[0]:
				_action_events.erase(event)
				(event[1] as Callable).call()
		var acted := _action_pose(_action, _action_time, pose)
		var blend_in := 1.0 if _action == &"wake" else smoothstep(0.0, 0.15, _action_time)
		var blend := blend_in * (1.0 - smoothstep(_action_duration - 0.2, _action_duration, _action_time))
		pose = _mix(pose, acted, blend)
		if _action_time >= _action_duration:
			var finished := _action
			_action = &""
			action_finished.emit(finished)
	_update_ears(delta, pose)
	_apply(pose)


# --- Poses -----------------------------------------------------------------------

func _neutral() -> Dictionary:
	return {
		"pelvis_y": _hip_height, "pelvis_z": 0.0, "pelvis_pitch": 0.0, "pelvis_roll": 0.0, "pelvis_yaw": 0.0,
		"foot_l_z": 0.0, "foot_l_y": _ankle_height, "foot_l_toe": 0.0,
		"foot_r_z": 0.0, "foot_r_y": _ankle_height, "foot_r_toe": 0.0,
		# 1 = sola paralela ao chão; 0 = pé segue a perna (deitado).
		"foot_flat": 1.0,
		"torso_pitch": 0.0, "torso_roll": 0.0, "torso_yaw": 0.0,
		"head_pitch": 0.0, "head_yaw": 0.0, "head_roll": 0.0,
		# Braço: fwd = para a frente, out = abrir para o lado (braço caído), yaw = girar no
		# plano horizontal (braço levantado; + para fora), twist = torcer no próprio eixo
		# (+ faz o cotovelo dobrar para dentro, como ao puxar a corda até o rosto).
		"arm_l_fwd": 0.0, "arm_l_out": 0.06, "arm_l_yaw": 0.0, "arm_l_twist": 0.0, "elbow_l": 0.15, "hand_l": 0.0,
		"arm_r_fwd": 0.0, "arm_r_out": 0.06, "arm_r_yaw": 0.0, "arm_r_twist": 0.0, "elbow_r": 0.15, "hand_r": 0.0,
		"ear_l": 0.0, "ear_r": 0.0,
	}


func _locomotion(delta: float) -> Dictionary:
	var pose := _neutral()
	var speed := Vector2(velocity_local.x, velocity_local.z).length()
	var move: float = _weights.move
	var run: float = _weights.run
	var crouch: float = _weights.crouch

	# Passada: parte do ciclo com o pé no chão, cadência e tamanho do passo.
	var stance := lerpf(0.62, 0.38, run)
	var stride_max := lerpf(0.40, 0.52, run) * lerpf(1.0, 0.65, crouch)
	var period := clampf(stride_max / maxf(speed * stance, 0.01), lerpf(0.46, 0.32, run), 1.1)
	if move > 0.01:
		_phase = fposmod(_phase + delta / period, 1.0)
	var stride := minf(speed * stance * period, stride_max)
	var lift := lerpf(0.05, 0.11, run) * lerpf(1.0, 0.6, crouch)
	var backwards := -1.0 if velocity_local.z < -0.1 else 1.0
	for side in 2:
		var key := "l" if side == 0 else "r"
		var u := fposmod(_phase + side * 0.5, 1.0)
		var z: float
		var y := _ankle_height
		var toe: float
		if u < stance:
			var s := u / stance
			z = stride * (0.5 - s)
			toe = smoothstep(0.65, 1.0, s) * 0.45
			if not _planted[side]:
				_planted[side] = true
				if move > 0.3 and on_floor:
					foot_planted.emit(side)
		else:
			var s := (u - stance) / (1.0 - stance)
			z = stride * (-0.5 + smoothstep(0.0, 1.0, s))
			y += lift * sin(PI * s)
			toe = lerpf(0.45, -0.2, s)
			_planted[side] = false
		pose["foot_%s_z" % key] = z * backwards * move
		pose["foot_%s_y" % key] = lerpf(_ankle_height, y, move)
		pose["foot_%s_toe" % key] = toe * move

	# Quadril sobe no meio do apoio, desce na troca de pé e balança para o lado do apoio.
	var bob := cos(TAU * 2.0 * (_phase - stance * 0.5))
	pose.pelvis_y = _hip_height - lerpf(0.012, 0.035, run) * move + bob * lerpf(0.010, 0.022, run) * move
	pose.pelvis_roll = sin(TAU * (_phase - stance * 0.5)) * 0.05 * move * (1.0 - run)
	pose.pelvis_yaw = sin(TAU * _phase) * lerpf(0.10, 0.16, run) * move
	pose.torso_yaw = -pose.pelvis_yaw * 0.85
	pose.torso_pitch = lerpf(0.05, 0.25, run) * move
	pose.head_pitch = -pose.torso_pitch * 0.6

	# Braços acompanham a perna do outro lado; correndo, cotovelos dobrados.
	var half := maxf(stride * 0.5, 0.001)
	var swing := lerpf(0.35, 0.85, run) * move
	pose.arm_l_fwd = clampf(pose.foot_r_z / half, -1.0, 1.0) * swing
	pose.arm_r_fwd = clampf(pose.foot_l_z / half, -1.0, 1.0) * swing
	for key in ["l", "r"]:
		pose["elbow_" + key] = 0.15 + lerpf(0.15, 1.25, run) * move + maxf(pose["arm_%s_fwd" % key], 0.0) * 0.4
		pose["arm_%s_out" % key] = 0.06 + 0.06 * run * move

	# Parado: respira e olha em volta.
	var idle := 1.0 - move
	var breath := sin(_time * 2.1)
	pose.torso_pitch += breath * 0.025 * idle
	pose.arm_l_out += breath * 0.02 * idle
	pose.arm_r_out += breath * 0.02 * idle
	pose.head_yaw = _look.x * idle
	pose.head_pitch += _look.y * idle

	# Curva: o corpo inclina para dentro.
	var lean := clampf(-turn_rate * speed * 0.035, -0.25, 0.25)
	pose.pelvis_roll += lean * 0.5
	pose.torso_roll += lean

	# Agachado: quadril baixo, tronco curvado, cabeça erguida para olhar adiante.
	pose.pelvis_y -= 0.11 * crouch
	pose.torso_pitch += 0.45 * crouch
	pose.head_pitch -= 0.35 * crouch
	for key in ["l", "r"]:
		pose["arm_%s_fwd" % key] += 0.35 * crouch
		pose["elbow_" + key] += 0.5 * crouch

	# No ar: encolhe as pernas e abre os braços para equilibrar.
	var air: float = _weights.air
	for key in ["l", "r"]:
		pose["foot_%s_y" % key] += 0.10 * air
		pose["foot_%s_z" % key] = lerpf(pose["foot_%s_z" % key], 0.05 if key == "l" else -0.03, air)
		pose["arm_%s_out" % key] += 0.35 * air
		pose["arm_%s_fwd" % key] += 0.25 * air

	# Aterrissagem: o corpo afunda e volta.
	pose.pelvis_y -= _land * 0.09
	pose.torso_pitch += _land * 0.25
	pose.head_pitch -= _land * 0.1
	return pose


## Mira com o arco: braço esquerdo estendido segurando o arco, o direito puxa a corda até o rosto.
func _aim_overlay(pose: Dictionary) -> void:
	var weight: float = _weights.aim
	if weight < 0.001:
		return
	var pitch := aim_pitch
	# Braço do arco aponta para o centro, à frente do rosto; o da corda abre o cotovelo para
	# fora e dobra na horizontal, trazendo a mão até o queixo conforme puxa.
	var aimed := {
		"torso_pitch": 0.08 - pitch * 0.35, "torso_yaw": 0.12, "torso_roll": 0.0,
		"head_pitch": -pitch * 0.6, "head_yaw": -0.08,
		"arm_l_fwd": 1.5 + pitch * 0.9, "arm_l_out": 0.0, "arm_l_yaw": -0.4, "arm_l_twist": 0.0, "elbow_l": 0.06, "hand_l": 0.0,
		"arm_r_fwd": 1.45 + pitch * 0.9, "arm_r_out": 0.0, "arm_r_yaw": 0.15 + 0.75 * draw, "arm_r_twist": 1.5,
		"elbow_r": 0.7 + 1.7 * draw, "hand_r": 0.2,
	}
	for key: String in aimed:
		pose[key] = lerpf(pose[key], aimed[key], weight)
	pose.pelvis_y -= 0.02 * weight


func _action_pose(action: StringName, t: float, base: Dictionary) -> Dictionary:
	var p := base.duplicate()
	match action:
		&"punch":
			p.arm_r_fwd = _curve(t, [[0.0, base.arm_r_fwd], [0.14, -0.5], [0.24, 1.65], [0.34, 1.5], [0.5, base.arm_r_fwd]])
			p.elbow_r = _curve(t, [[0.0, base.elbow_r], [0.14, 1.7], [0.24, 0.1], [0.34, 0.2], [0.5, base.elbow_r]])
			p.arm_r_out = _curve(t, [[0.0, 0.06], [0.14, 0.3], [0.24, -0.15], [0.5, 0.06]])
			p.torso_yaw = _curve(t, [[0.0, base.torso_yaw], [0.14, 0.4], [0.24, -0.45], [0.5, base.torso_yaw]])
			p.pelvis_yaw = _curve(t, [[0.0, 0.0], [0.14, 0.15], [0.24, -0.2], [0.5, 0.0]])
			p.torso_pitch = base.torso_pitch + _curve(t, [[0.0, 0.0], [0.24, 0.2], [0.5, 0.0]])
			p.arm_l_fwd = _curve(t, [[0.0, base.arm_l_fwd], [0.24, -0.4], [0.5, base.arm_l_fwd]])
			p.foot_l_z = base.foot_l_z + _curve(t, [[0.0, 0.0], [0.2, 0.12], [0.4, 0.12], [0.5, 0.0]])
		&"pickup":
			p.pelvis_y = _curve(t, [[0.0, base.pelvis_y], [0.4, 0.2], [0.65, 0.2], [1.1, base.pelvis_y]])
			p.foot_l_z = _curve(t, [[0.0, base.foot_l_z], [0.3, 0.12], [0.8, 0.12], [1.1, 0.0]])
			p.foot_r_z = _curve(t, [[0.0, base.foot_r_z], [0.3, -0.08], [0.8, -0.08], [1.1, 0.0]])
			p.torso_pitch = _curve(t, [[0.0, base.torso_pitch], [0.4, 0.75], [0.65, 0.75], [1.1, base.torso_pitch]])
			p.head_pitch = _curve(t, [[0.0, 0.0], [0.4, 0.35], [0.65, 0.35], [1.1, 0.0]])
			p.arm_r_fwd = _curve(t, [[0.0, 0.0], [0.4, 0.75], [0.55, 0.8], [0.75, 0.55], [1.1, 0.0]])
			p.elbow_r = _curve(t, [[0.0, 0.15], [0.4, 0.25], [0.55, 0.6], [1.1, 0.15]])
			p.arm_l_fwd = _curve(t, [[0.0, 0.0], [0.4, 0.35], [1.1, 0.0]])
			p.elbow_l = _curve(t, [[0.0, 0.15], [0.4, 0.6], [1.1, 0.15]])
		&"harvest":
			var work := smoothstep(0.6, 0.8, t) * (1.0 - smoothstep(1.8, 2.0, t))
			p.pelvis_y = _curve(t, [[0.0, base.pelvis_y], [0.5, 0.17], [2.0, 0.17], [2.4, base.pelvis_y]])
			p.foot_l_z = _curve(t, [[0.0, 0.0], [0.4, 0.15], [2.0, 0.15], [2.4, 0.0]])
			p.foot_r_z = _curve(t, [[0.0, 0.0], [0.4, -0.12], [2.0, -0.12], [2.4, 0.0]])
			p.torso_pitch = _curve(t, [[0.0, base.torso_pitch], [0.5, 0.7], [2.0, 0.7], [2.4, base.torso_pitch]])
			p.head_pitch = _curve(t, [[0.0, 0.0], [0.5, 0.4], [2.0, 0.4], [2.4, 0.0]])
			p.arm_r_fwd = _curve(t, [[0.0, 0.0], [0.5, 0.9], [2.0, 0.9], [2.4, 0.0]]) + sin(t * 14.0) * 0.25 * work
			p.arm_l_fwd = _curve(t, [[0.0, 0.0], [0.5, 0.8], [2.0, 0.8], [2.4, 0.0]]) - sin(t * 14.0) * 0.15 * work
			p.elbow_r = _curve(t, [[0.0, 0.15], [0.5, 0.7], [2.0, 0.7], [2.4, 0.15]])
			p.elbow_l = _curve(t, [[0.0, 0.15], [0.5, 0.5], [2.0, 0.5], [2.4, 0.15]])
		&"wake":
			# Deitado de costas -> senta -> esfrega os olhos -> agacha -> levanta e olha em volta.
			var lying := 1.0 - smoothstep(2.4, 3.2, t)
			p.pelvis_pitch = _curve(t, [[0.0, -1.5], [2.4, -1.5], [3.3, -0.25], [4.3, -0.2], [4.9, 0.45], [5.6, 0.0]])
			p.pelvis_y = _curve(t, [[0.0, 0.09], [2.4, 0.09], [3.3, 0.1], [4.3, 0.1], [4.9, 0.2], [5.6, base.pelvis_y]])
			var feet := _curve(t, [[0.0, 0.27], [2.4, 0.27], [3.3, 0.25], [4.3, 0.24], [4.9, 0.03], [5.6, 0.0]])
			p.foot_l_z = feet
			p.foot_r_z = feet * 0.9
			p.foot_l_y = _ankle_height
			p.foot_r_y = _ankle_height + 0.01
			p.foot_flat = 1.0 - lying
			p.torso_pitch = _curve(t, [[0.0, 0.0], [2.4, 0.0], [3.3, 0.35], [4.3, 0.3], [4.9, 0.55], [5.6, base.torso_pitch]]) + sin(t * 1.6) * 0.04 * lying
			p.head_pitch = _curve(t, [[0.0, -0.15], [2.4, -0.15], [2.9, 0.2], [3.4, 0.35], [4.3, 0.3], [5.0, 0.0]])
			p.head_yaw = _curve(t, [[0.0, 0.35], [2.0, 0.35], [2.6, 0.0]])
			p.arm_l_fwd = _curve(t, [[0.0, 0.05], [2.4, 0.05], [2.8, -0.6], [3.3, -0.3], [4.3, 0.2], [4.9, 0.9], [5.6, 0.0]])
			# Mão direita sobe até os olhos (cotovelo dobra na horizontal) e esfrega.
			p.arm_r_fwd = _curve(t, [[0.0, 0.05], [2.4, 0.05], [2.8, -0.6], [3.3, -0.2], [3.6, 1.65], [4.2, 1.65], [4.5, 0.4], [4.9, 0.9], [5.6, 0.0]])
			var rubbing := smoothstep(3.55, 3.7, t) * (1.0 - smoothstep(4.1, 4.25, t))
			var to_face := smoothstep(3.3, 3.6, t) * (1.0 - smoothstep(4.2, 4.5, t))
			p.elbow_r = _curve(t, [[0.0, 0.2], [3.3, 0.3], [3.6, 2.4], [4.2, 2.4], [4.5, 0.4], [5.6, 0.15]])
			p.arm_r_twist = 1.5 * to_face
			p.arm_r_yaw = (0.35 + sin(t * 18.0) * 0.12 * rubbing) * to_face
			p.elbow_l = _curve(t, [[0.0, 0.2], [2.8, 0.1], [4.3, 0.3], [4.9, 0.6], [5.6, 0.15]])
			p.ear_l = _curve(t, [[0.0, 0.5], [2.6, 0.5], [3.6, 0.1], [5.6, 0.0]])
			p.ear_r = p.ear_l
	return p


func _mix(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	if weight <= 0.0:
		return a
	var out := a.duplicate()
	for key: String in b:
		out[key] = lerpf(a[key], b[key], weight)
	return out


## Valor suave numa lista de chaves [[tempo, valor], ...].
static func _curve(t: float, keys: Array) -> float:
	if t <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= b[0]:
			return lerpf(a[1], b[1], smoothstep(a[0], b[0], t))
	return keys[-1][1]


# --- Estado ----------------------------------------------------------------------

func _update_weights(delta: float) -> void:
	var speed := Vector2(velocity_local.x, velocity_local.z).length()
	_approach("move", smoothstep(0.15, 0.8, speed) if on_floor else 0.0, 10.0, delta)
	_approach("run", smoothstep(2.8, 4.5, speed), 6.0, delta)
	_approach("crouch", 1.0 if crouching else 0.0, 8.0, delta)
	_approach("aim", 1.0 if aiming else 0.0, 10.0, delta)
	_approach("air", 0.0 if on_floor else 1.0, 8.0, delta)


func _approach(key: String, target: float, rate: float, delta: float) -> void:
	_weights[key] = lerpf(_weights[key], target, 1.0 - exp(-rate * delta))


## De tempos em tempos o goblin vira a cabeça para olhar outro ponto.
func _update_look(delta: float) -> void:
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(2.0, 6.0)
		_look_target = Vector2(randf_range(-0.6, 0.6), randf_range(-0.15, 0.2)) if randf() < 0.7 else Vector2.ZERO
	_look = _look.lerp(_look_target, 1.0 - exp(-3.0 * delta))


## Orelhas com mola: quicam com o sobe-e-desce do corpo e caem ao aterrissar.
func _update_ears(delta: float, pose: Dictionary) -> void:
	var vertical: float = (pose.pelvis_y - _last_pelvis_y) / maxf(delta, 0.001)
	_last_pelvis_y = pose.pelvis_y
	for i in 2:
		var target: float = pose["ear_l" if i == 0 else "ear_r"] + _land * 0.5 - vertical * 0.12
		_ear_speed[i] += ((target - _ears[i]) * 160.0 - _ear_speed[i] * 11.0) * delta
		_ears[i] += _ear_speed[i] * delta
		if randf() < delta * 0.15:
			_ear_speed[i] += randf_range(-4.0, 4.0)
		pose["ear_l" if i == 0 else "ear_r"] = _ears[i]


# --- Pose -> ossos ---------------------------------------------------------------

func _apply(pose: Dictionary) -> void:
	skeleton.set_bone_pose_position(_bones.quadril, _pelvis_rest + Vector3(0.0, pose.pelvis_y - _hip_height, pose.pelvis_z))
	_rotate(_bones.quadril, Basis.from_euler(Vector3(pose.pelvis_pitch, pose.pelvis_yaw, pose.pelvis_roll)))

	var pelvis_tilt := Basis(Vector3.RIGHT, pose.pelvis_pitch).inverse()
	for key in ["l", "r"]:
		var suffix := "E" if key == "l" else "D"
		# Alvo do tornozelo em relação ao quadril, no referencial da bacia.
		var target := pelvis_tilt * Vector3(0.0, pose["foot_%s_y" % key] - pose.pelvis_y, pose["foot_%s_z" % key] - pose.pelvis_z)
		var angles := _leg_angles(target.z, -target.y)
		var thigh := angles.x - _rest_leg.x
		var knee := angles.y - _rest_leg.y
		_rotate(_bones["perna_" + suffix], Basis(Vector3.RIGHT, -thigh))
		_rotate(_bones["canela_" + suffix], Basis(Vector3.RIGHT, knee))
		var level: float = (pose.pelvis_pitch - thigh + knee) * float(pose.foot_flat)
		_rotate(_bones["pe_" + suffix], Basis(Vector3.RIGHT, -level + pose["foot_%s_toe" % key]))

	_rotate(_bones.tronco, Basis.from_euler(Vector3(pose.torso_pitch, pose.torso_yaw, pose.torso_roll)))
	for key in ["l", "r"]:
		var suffix := "E" if key == "l" else "D"
		var outward := 1.0 if key == "l" else -1.0
		var shoulder := Basis(Vector3.UP, pose["arm_%s_yaw" % key] * outward) \
			* Basis(Vector3.BACK, pose["arm_%s_out" % key] * outward) \
			* Basis(Vector3.RIGHT, -pose["arm_%s_fwd" % key]) \
			* Basis(Vector3.UP, -pose["arm_%s_twist" % key] * outward)
		_rotate(_bones["braco_" + suffix], shoulder)
		_rotate(_bones["antebraco_" + suffix], Basis(Vector3.RIGHT, -pose["elbow_" + key]))
		_rotate(_bones["mao_" + suffix], Basis(Vector3.RIGHT, -pose["hand_" + key]))
	_rotate(_bones.cabeca, Basis.from_euler(Vector3(pose.head_pitch, pose.head_yaw, pose.head_roll)))
	_rotate(_bones.orelha_E, Basis(Vector3.BACK, -pose.ear_l))
	_rotate(_bones.orelha_D, Basis(Vector3.BACK, pose.ear_r))


## Gira o osso por `rotation` (eixos do modelo em repouso), carregado pelo que o pai já girou.
func _rotate(bone: int, rotation: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_now := skeleton.get_bone_global_pose(parent).basis
	var carried: Basis = parent_now * (_rest_global[parent] as Basis).inverse()
	var global_basis: Basis = carried * rotation * _rest_global[bone]
	skeleton.set_bone_pose_rotation(bone, (parent_now.inverse() * global_basis).get_rotation_quaternion())


## IK da perna no plano de perfil: dado o tornozelo (dz à frente, dy abaixo do quadril),
## devolve (ângulo da coxa para a frente, dobra do joelho).
func _leg_angles(dz: float, dy: float) -> Vector2:
	var distance := clampf(sqrt(dz * dz + dy * dy), 0.04, _thigh + _shin - 0.001)
	var knee_inside := acos(clampf((_thigh * _thigh + _shin * _shin - distance * distance) / (2.0 * _thigh * _shin), -1.0, 1.0))
	var to_target := atan2(dz, dy)
	var offset := acos(clampf((_thigh * _thigh + distance * distance - _shin * _shin) / (2.0 * _thigh * distance), -1.0, 1.0))
	return Vector2(to_target + offset, PI - knee_inside)
