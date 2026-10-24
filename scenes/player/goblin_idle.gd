class_name GoblinIdle
extends RefCounted
## O goblin parado (tirado do GoblinAnimator na F10): o peso troca de perna de tempos em tempos
## e, depois de um tempo sem fazer nada, vem uma mania (coçar a orelha, farejar, olhar para
## trás, examinar as garras; faminto, a mão na barriga). Qualquer movimento corta a mania.

## Apoio parado: -1 peso na perna direita, +1 na esquerda.
var _shift := 0.0
var _shift_target := 0.0
var _shift_timer := 2.0
## Manias de quando fica parado.
var _fidget := &""
var _fidget_time := 0.0
var _fidget_duration := 0.0
var _fidget_side := 1.0
var _idle_time := 0.0
var _next_fidget := 4.0

var _a: GoblinAnimator


func _init(animator: GoblinAnimator) -> void:
	_a = animator


## Uma ação começou: a mania para na hora.
func stop_fidget() -> void:
	_fidget = &""


func overlay(delta: float, pose: Dictionary) -> Dictionary:
	var idle: float = (1.0 - _a._weights.move) * (1.0 - _a._weights.aim) * (1.0 - _a._weights.air)

	# Apoio numa perna: o quadril escorrega para o lado dela, o outro lado cai, o joelho
	# solto dobra e o pé dele vai um pouco à frente, só na ponta.
	_shift_timer -= delta
	if _shift_timer <= 0.0:
		_shift_timer = randf_range(3.5, 8.0)
		_shift_target = [-1.0, -0.45, 0.4, 1.0].pick_random()
	_shift = lerpf(_shift, _shift_target, 1.0 - exp(-1.6 * delta))
	var w: float = _shift * idle * (1.0 - _a._weights.crouch)
	var free_key := "r" if w > 0.0 else "l"
	pose.pelvis_x += w * 0.028
	pose.pelvis_roll += w * 0.055
	pose.torso_roll -= w * 0.07
	pose.head_roll += w * 0.03
	pose["foot_%s_y" % free_key] += absf(w) * 0.012
	pose["foot_%s_z" % free_key] += absf(w) * 0.035
	pose["foot_%s_toe" % free_key] += absf(w) * 0.14

	# Cansado depois de correr: curva o corpo e apoia as mãos nos joelhos.
	var panting: float = smoothstep(0.45, 0.85, _a._exertion) * idle * (1.0 - _a._weights.crouch)
	if panting > 0.001:
		pose = _a._mix(pose, _a._merge(pose, {
			"torso_pitch": 0.45 + sin(_a._breath_phase) * 0.05, "spine_arch": 0.32 - sin(_a._breath_phase) * 0.06,
			"head_pitch": -0.4, "pelvis_y": pose.pelvis_y - 0.03,
			"arm_l_fwd": 0.85, "arm_r_fwd": 0.8, "elbow_l": 0.12, "elbow_r": 0.18, "arm_l_out": 0.06, "arm_r_out": 0.04,
			"hand_l": 0.5, "hand_r": 0.45, "ear_l": 0.35, "ear_r": 0.3,
		}), panting)

	if _a._action != &"" or idle < 0.9 or _a._exertion > 0.4 or _a.sniffing:
		_idle_time = 0.0
	else:
		_idle_time += delta
	if _fidget == &"":
		if _idle_time > _next_fidget:
			# Faminto, metade das vezes ele põe a mão na barriga.
			if _a.starving and randf() < 0.5:
				_fidget = &"belly"
			else:
				_fidget = [&"scratch", &"sniff", &"look_back", &"claws"].pick_random()
			_fidget_time = 0.0
			_fidget_duration = {&"scratch": 2.8, &"sniff": 2.2, &"look_back": 2.8, &"claws": 2.6, &"belly": 3.0}[_fidget]
			_fidget_side = [-1.0, 1.0].pick_random()
		return pose
	_fidget_time += delta
	var t := _fidget_time
	var envelope := smoothstep(0.0, 0.45, t) * (1.0 - smoothstep(_fidget_duration - 0.5, _fidget_duration, t))
	var p := pose.duplicate()
	match _fidget:
		&"scratch":
			# Coça atrás da orelha direita com a mão livre, entortando a cabeça para ela.
			var scratch := smoothstep(0.55, 0.75, t) * (1.0 - smoothstep(_fidget_duration - 0.8, _fidget_duration - 0.6, t))
			p.arm_r_fwd = 1.55
			p.arm_r_out = 0.25
			p.arm_r_twist = 1.2
			p.arm_r_yaw = 0.8 + sin(t * 23.0) * 0.08 * scratch
			p.elbow_r = 2.3 + sin(t * 23.0 + 1.3) * 0.15 * scratch
			p.hand_r = 0.5
			p.head_roll = pose.head_roll + 0.25
			p.head_pitch = pose.head_pitch + 0.12
			p.ear_r = 0.3 * scratch
			# O corpo vai junto: tronco dobra de lado para a mão, ombros sobem e o peso passa
			# para a outra perna.
			p.torso_roll = pose.torso_roll + 0.05
			p.spine_bend = pose.spine_bend + 0.07
			p.spine_arch = pose.spine_arch + 0.06
			p.pelvis_x = pose.pelvis_x + 0.012
		&"sniff":
			# Ergue o focinho, fareja em golpes curtos e fica com as orelhas em pé.
			var sniffing := smoothstep(0.4, 0.6, t) * (1.0 - smoothstep(1.6, 1.8, t))
			p.head_pitch = pose.head_pitch - 0.38 + sin(t * 17.0) * 0.035 * sniffing * absf(sin(t * 3.0))
			p.head_yaw = pose.head_yaw + 0.25 * _fidget_side * smoothstep(0.9, 1.4, t)
			# O corpo todo se estica para cima e para a frente atrás do cheiro; o peito enche
			# a cada fungada.
			p.torso_pitch = pose.torso_pitch - 0.08 + sin(t * 17.0) * 0.012 * sniffing
			p.spine_arch = pose.spine_arch - 0.12 - absf(sin(t * 3.0)) * 0.03 * sniffing
			p.neck_fwd = pose.neck_fwd + 0.14
			p.pelvis_y = pose.pelvis_y + 0.008
			p.ear_l = -0.3
			p.ear_r = -0.28
		&"look_back":
			# Olha por cima do ombro, como se tivesse ouvido algo atrás.
			# O giro passa por todo o corpo (quadril, lombar, peito, pescoço), o peso vai para
			# o pé do lado em que olha e o tronco dobra um pouco para lá.
			p.pelvis_yaw = pose.pelvis_yaw + 0.16 * _fidget_side
			p.torso_yaw = pose.torso_yaw + 0.5 * _fidget_side
			p.spine_bend = pose.spine_bend - 0.05 * _fidget_side
			p.pelvis_x = pose.pelvis_x + 0.015 * _fidget_side
			p.torso_roll = pose.torso_roll - 0.04 * _fidget_side
			p.head_yaw = 0.75 * _fidget_side
			p.head_pitch = pose.head_pitch + 0.06
			p.arm_l_fwd = pose.arm_l_fwd + 0.15
			p["ear_l" if _fidget_side > 0.0 else "ear_r"] = -0.35
		&"claws":
			# Traz a mão direita perto do queixo, examina as unhas virando a mão e rói uma.
			var turning := smoothstep(0.8, 1.0, t) * (1.0 - smoothstep(1.8, 2.0, t))
			p.arm_r_fwd = 0.55
			p.arm_r_out = 0.05
			p.arm_r_twist = 0.9 + sin(t * 4.0) * 0.35 * turning
			p.elbow_r = 1.35
			p.hand_r = -0.35 + sin(t * 4.0 + 0.5) * 0.25 * turning
			# Encolhido sobre a mão: costas redondas, pescoço à frente.
			p.torso_pitch = pose.torso_pitch + 0.1
			p.spine_arch = pose.spine_arch + 0.16
			p.neck_fwd = pose.neck_fwd + 0.1
			p.head_pitch = pose.head_pitch + 0.55
			p.head_yaw = -0.25
			p.head_roll = pose.head_roll + 0.1
		&"belly":
			# Mão na barriga, corpo dobrado em volta dela e a cabeça baixa; esfrega devagar.
			var rub := smoothstep(0.6, 0.8, t) * (1.0 - smoothstep(2.3, 2.5, t))
			p.arm_r_fwd = 0.42
			p.arm_r_out = -0.04 + sin(t * 3.0) * 0.03 * rub
			p.arm_r_twist = 0.7
			p.elbow_r = 1.45 + sin(t * 3.0 + 0.8) * 0.08 * rub
			p.hand_r = 0.15
			p.torso_pitch = pose.torso_pitch + 0.14
			p.spine_arch = pose.spine_arch + 0.12
			p.neck_fwd = pose.neck_fwd + 0.05
			p.head_pitch = pose.head_pitch + 0.3
			p.head_roll = pose.head_roll - 0.06
			p.pelvis_y = pose.pelvis_y - 0.008
			p.ear_l = 0.3
			p.ear_r = 0.25
	pose = _a._mix(pose, p, envelope * idle)
	if t >= _fidget_duration or idle < 0.3:
		_fidget = &""
		_idle_time = 0.0
		_next_fidget = randf_range(5.0, 11.0)
	return pose


## Frio: tremor rápido no tronco e na cabeça o tempo todo; quando não está andando nem
## mirando, abraça o próprio corpo, encolhe o pescoço e baixa as orelhas.
