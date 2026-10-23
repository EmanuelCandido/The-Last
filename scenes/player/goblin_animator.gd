class_name GoblinAnimator
extends Node
## Anima o goblin por código, direto no esqueleto.
##
## - Passada: cada pé segue uma trajetória (apoio no chão, depois arco no ar) e a perna
##   é resolvida com IK de duas juntas, então o pé não escorrega e o joelho dobra de verdade.
## - Corpo: quadril sobe e balança, tronco gira ao contrário, braços em oposição às pernas,
##   inclinação nas curvas, respiração e olhar em volta parado, orelhas com mola.
## - Pés no chão: cada pé procura o chão embaixo dele (degrau, pedra, encosta) e inclina
##   com ele; o quadril desce para o pé mais baixo alcançar. Pé sem chão fica pendurado.
## - Equilíbrio: na borda, o Player informa o desequilíbrio (teeter) e o goblin abre e gira
##   os braços, joga o corpo para longe do vazio e olha para baixo.
## - Estados: agachar, no ar, aterrissar, mirar com o arco.
## - Mira: os braços são resolvidos com IK. A mão do arco estica até a empunhadura ficar na
##   linha que sai de baixo do queixo para o alvo; a da corda vai até onde a corda está puxada.
## - Ações cronometradas: acordar, pegar algo do chão, coletar a caça, golpear. Cada uma
##   usa o corpo todo, com preparação, ação e continuação (o tronco não é um bloco).
## - Mecânica do corpo (_body_mechanics), por cima de tudo: dobradiça no quadril ao inclinar,
##   braços puxando o tronco e molas que comprimem e esticam a coluna (passos, aterrissagem,
##   arrancar e frear).
## - Jeito de goblin: postura curvada e torta (nada é simétrico), micro-movimentos o tempo
##   todo, passadas que variam, apoio que troca de perna, cansaço depois de correr e
##   manias quando fica parado (coçar a orelha, farejar, olhar para trás, olhar as garras).
##
## Cada frame monta uma pose (dicionário de números, ver _neutral) e só no fim a converte
## em rotações de ossos. Ângulos em radianos, eixos no espaço do modelo: Y para cima,
## +Z para a frente, +X é o lado esquerdo (E); "l" = esquerdo (E), "r" = direito (D).

## Um pé tocou o chão (0 = esquerdo, 1 = direito): hora do som do passo.
signal foot_planted(side: int)
signal action_finished(action: StringName)

const BONES := [
	"quadril", "tronco", "peito", "pescoco", "cabeca", "perna_E", "canela_E", "pe_E", "perna_D", "canela_D", "pe_D",
	"braco_E", "antebraco_E", "mao_E", "braco_D", "antebraco_D", "mao_D", "orelha_E", "orelha_D",
]

## Estado do corpo, preenchido pelo Player a cada frame.
var velocity_local := Vector3.ZERO
var on_floor := true
var crouching := false
var aiming := false
## Faminto: parado, a mania mais comum vira pôr a mão na barriga.
var starving := false
## Frio (0..1): o corpo treme e, parado, ele se abraça e encolhe.
var shiver := 0.0
## Farejando: agachado, focinho erguido, fungadas curtas, cabeça varrendo o vento.
var sniffing := false
## Prendendo o ar: a respiração para (o peito fica cheio) e o arco puxado não treme.
var breath_held := false
## Multiplica o tremor do braço do arco (o arco de teixo e a prática firmam).
var tremor_scale := 1.0
## Tocha acesa na mão direita: o braço a segura erguida à frente.
var holding_torch := false
## Deitado de costas (no sarcófago): a pose do começo do `wake`.
var lying := false
var draw := 0.0
## Buscando outra flecha na aljava (1 = acabou de atirar, 0 = flecha na corda).
var reload := 0.0
## Inclinação da câmera (rad, + olhando para cima).
var aim_pitch := 0.0
## Velocidade de giro do corpo (rad/s).
var turn_rate := 0.0
## Corpo de física de quem pisa: os raios de chão o ignoram. Sem ele, pés no plano da base.
var body: CollisionObject3D
## Desequilíbrio na borda (0..1) e para onde fica o vazio (x, z no espaço do modelo).
var teeter := 0.0
var teeter_dir := Vector2.ZERO
## Chão alcançado por cada pé (lido pelo Player para medir o apoio).
var foot_supported := [true, true]
## Mira com IK (preenchidos pelo Player): ponto do mundo para onde a flecha vai (INF = sem
## alvo), distância da empunhadura até a corda agora e onde a empunhadura fica no espaço do
## osso da mão esquerda.
var aim_point := Vector3.INF
var nock_depth := 0.08
var bow_grip := Vector3(0.0, 0.036, -0.008)
## Topo da aljava (penas das flechas), no espaço do esqueleto: aonde a mão vai recarregar.
var quiver_top := Vector3(-0.08, 0.8, -0.15)

## Quanto o pé desce abaixo da base do corpo procurando chão (m).
const FOOT_REACH := 0.3
## Pé sem chão: fica pendurado um pouco abaixo da borda, com o joelho solto.
const FOOT_HANG := -0.1
## Onde a corda encosta ao puxar: embaixo do queixo, à direita (esqueleto em repouso).
## A cabeça do goblin é enorme (10 cm de meia-largura na boca, queixo até z = 0,14): a
## mão da corda tem de ficar fora dela, e o braço do arco (32 cm) tem de alcançar a linha.
const ANCHOR_REST := Vector3(-0.05, 0.7, 0.16)
## Do punho até onde os dedos seguram a corda (m).
const STRING_FINGERS := 0.045
## Com a corda solta, a corda fica esta distância à frente da ancoragem: o arco começa perto
## do rosto e o braço estica enquanto a outra mão puxa (o braço da corda, com o peito de
## perfil, não alcança mais longe).
const PREDRAW := 0.05

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
var _weights := {"move": 0.0, "run": 0.0, "crouch": 0.0, "aim": 0.0, "air": 0.0, "sniff": 0.0, "breath": 0.0, "torch": 0.0}
var _planted := [true, true]
var _land := 0.0
var _land_eased := 0.0
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
## Sorteado a cada ação (-1..1): o mesmo golpe nunca sai igual duas vezes.
var _action_var := 0.0

## Por passo: altura do pé e quanto ele abre (sorteados quando o pé sai do chão).
var _step_lift := [1.0, 1.0]
var _step_yaw := [0.0, 0.0]
## Fôlego: sobe correndo e desce devagar; muda o ritmo da respiração e a pose parado.
var _exertion := 0.0
var _breath_phase := 0.0
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
## Arco: tempo segurando a corda no fim (o braço começa a tremer) e coice ao soltar.
var _hold_time := 0.0
var _release := 0.0
var _last_draw := 0.0
## Altura do chão sob cada pé em relação à base (suavizada) e a inclinação dele.
var _foot_ground := [0.0, 0.0]
var _foot_tilt := [Basis.IDENTITY, Basis.IDENTITY]
var _ground_weight := 0.0
## Ponto de ancoragem no espaço do osso da cabeça; tremor do braço do arco e mão na aljava.
var _anchor := Vector3.ZERO
var _bow_shake := Vector3.ZERO
var _quiver_reach := 0.0
## Inclinação na curva, suavizada (o giro do corpo chega em degraus da física).
var _lean := 0.0
## Mecânica do corpo (_body_mechanics): o tronco é uma massa presa ao quadril por molas.
## Altura do tronco que segue o quadril (comprime e estica a coluna) e velocidade que
## segue a do corpo (o peito atrasa ao arrancar e continua indo ao frear).
var _torso_y := 0.36
var _torso_vy := 0.0
var _vel_lag := Vector2.ZERO
var _vel_lag_speed := Vector2.ZERO
## Quanto a coluna está comprimida agora (+) ou esticada (-); as orelhas acompanham.
var _squash := 0.0


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
	_anchor = skeleton.get_bone_global_rest(_bones.cabeca).affine_inverse() * ANCHOR_REST
	_last_pelvis_y = _hip_height
	_torso_y = _hip_height
	skeleton.reset_bone_poses()
	return true


## Cansaço (0..1): ofega e apoia as mãos nos joelhos parado; a mira treme.
func exertion() -> float:
	return _exertion


## Cansa o corpo de uma vez (soltar o ar preso, um susto).
func add_exertion(amount: float) -> void:
	_exertion = clampf(maxf(_exertion, amount), 0.0, 1.0)


## Começa uma ação. `events` = [[segundos, Callable], ...], chamados uma vez no tempo certo.
## `start` pula o começo (levantar do sarcófago é o `wake` a partir de quando ele senta).
func play_action(action: StringName, duration: float, events: Array = [], start := 0.0) -> void:
	_action = action
	_action_var = randf_range(-1.0, 1.0)
	_fidget = &""
	_action_time = start
	_action_duration = duration
	_action_events = events.duplicate()


func is_busy() -> bool:
	return _action != &""


func notify_landing(impact_speed: float) -> void:
	_land = maxf(_land, clampf(impact_speed / 7.0, 0.15, 1.0))
	# O tronco vinha caindo junto: os pés param e ele continua, comprimindo a coluna.
	_torso_vy -= clampf(impact_speed, 0.0, 8.0) * 0.2


func update(delta: float) -> void:
	if skeleton == null or _bones.is_empty():
		return
	_time += delta
	_update_weights(delta)
	_update_look(delta)
	_update_bow_state(delta)
	_land = move_toward(_land, 0.0, delta * 2.5)
	# Os joelhos levam um instante para dobrar: o corpo afunda suave, não num degrau.
	_land_eased = lerpf(_land_eased, _land, 1.0 - exp(-25.0 * delta))

	var pose := _locomotion(delta)
	pose = _idle_overlay(delta, pose)
	_cold_overlay(pose)
	_sniff_overlay(pose)
	_torch_overlay(pose)
	_aim_overlay(pose)
	if lying and _action == &"":
		pose = _action_pose(&"wake", 0.0, pose)
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
	_body_mechanics(delta, pose)
	_balance_overlay(pose)
	_ground_feet(delta, pose)
	_update_ears(delta, pose)
	_apply(pose)


# --- Poses -----------------------------------------------------------------------

## Postura de repouso do goblin: corcunda, joelhos frouxos, pés abertos para fora, um
## ombro mais baixo, cabeça torta e braços pendurados à frente, com as mãos meio fechadas.
## Os dois lados nunca são iguais.
func _neutral() -> Dictionary:
	return {
		"pelvis_y": _hip_height - 0.018, "pelvis_x": 0.0, "pelvis_z": 0.0, "pelvis_pitch": 0.05, "pelvis_roll": 0.0, "pelvis_yaw": 0.0,
		"foot_l_z": 0.02, "foot_l_y": _ankle_height, "foot_l_toe": 0.0,
		"foot_r_z": -0.015, "foot_r_y": _ankle_height, "foot_r_toe": 0.0,
		# Perna aberta para o lado e pé girado para fora (+ = para fora nos dois lados).
		"leg_l_out": 0.07, "leg_r_out": 0.05, "foot_l_yaw": 0.22, "foot_r_yaw": 0.32,
		# Giro dos dois pés juntos (postura de arqueiro).
		"feet_yaw": 0.0,
		# 1 = sola paralela ao chão; 0 = pé segue a perna (deitado).
		"foot_flat": 1.0,
		"torso_pitch": 0.12, "torso_roll": 0.04, "torso_yaw": 0.03,
		# Coluna: arch arredonda as costas em cima e arqueia a lombar; bend é a curva de
		# lado (em S, lombar para um lado e peito para o outro); neck projeta a cabeça à frente.
		"spine_arch": 0.13, "spine_bend": 0.035, "neck_fwd": 0.1,
		"head_pitch": -0.13, "head_yaw": 0.0, "head_roll": 0.06,
		# Braço: fwd = para a frente, out = abrir para o lado (braço caído), yaw = girar no
		# plano horizontal (braço levantado; + para fora), twist = torcer no próprio eixo
		# (+ faz o cotovelo dobrar para dentro, como ao puxar a corda até o rosto).
		"arm_l_fwd": 0.12, "arm_l_out": 0.13, "arm_l_yaw": 0.0, "arm_l_twist": 0.0, "elbow_l": 0.42, "hand_l": 0.32,
		"arm_r_fwd": 0.03, "arm_r_out": 0.09, "arm_r_yaw": 0.0, "arm_r_twist": 0.0, "elbow_r": 0.27, "hand_r": 0.2,
		"ear_l": 0.06, "ear_r": -0.02,
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
		# O pé direito sai um pouco atrasado: o ritmo fica manco, de bicho, não de metrônomo.
		var u := fposmod(_phase + side * 0.52, 1.0)
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
			if _planted[side]:
				# O pé saiu do chão: este passo terá a sua altura e abertura.
				_step_lift[side] = randf_range(0.7, 1.25) * (0.8 if side == 1 else 1.0)
				_step_yaw[side] = randf_range(-0.12, 0.12)
			z = stride * (-0.5 + smoothstep(0.0, 1.0, s))
			y += lift * _step_lift[side] * sin(PI * s)
			toe = lerpf(0.45, -0.2, s)
			_planted[side] = false
		pose["foot_%s_z" % key] = lerpf(pose["foot_%s_z" % key], z * backwards, move)
		pose["foot_%s_y" % key] = lerpf(_ankle_height, y, move)
		pose["foot_%s_toe" % key] = toe * move
		pose["foot_%s_yaw" % key] += _step_yaw[side] * move

	# Quadril sobe no meio do apoio, desce na troca de pé e balança para o lado do apoio.
	var bob := cos(TAU * 2.0 * (_phase - stance * 0.5))
	pose.pelvis_y += (-lerpf(0.008, 0.035, run) + bob * lerpf(0.010, 0.026, run)) * move
	pose.pelvis_roll = sin(TAU * (_phase - stance * 0.5)) * lerpf(0.05, 0.025, run) * move
	pose.pelvis_yaw = sin(TAU * _phase) * lerpf(0.10, 0.17, run) * move
	pose.torso_yaw += -pose.pelvis_yaw * 0.85
	# Correndo, o goblin se joga para a frente e estica o pescoço para ver adiante.
	pose.torso_pitch += lerpf(0.04, 0.3, run) * move
	pose.head_pitch -= lerpf(0.02, 0.24, run) * move
	pose.head_pitch += bob * 0.025 * move
	pose.spine_bend += sin(TAU * (_phase - stance * 0.5)) * 0.035 * move
	pose.spine_arch += 0.06 * run * move

	# Braços acompanham a perna do outro lado, cada um com a sua amplitude; correndo,
	# cotovelos dobrados e braços abertos, meio desengonçados.
	var half := maxf(stride * 0.5, 0.001)
	var swing := lerpf(0.32, 0.85, run) * move
	var arm_l := clampf(pose.foot_r_z / half, -1.0, 1.0) * swing
	var arm_r := clampf(pose.foot_l_z / half, -1.0, 1.0) * swing * 0.8
	pose.arm_l_fwd = lerpf(pose.arm_l_fwd, 0.08, move) + arm_l
	pose.arm_r_fwd = lerpf(pose.arm_r_fwd, 0.0, move) + arm_r
	for key in ["l", "r"]:
		pose["elbow_" + key] += (lerpf(0.0, 1.05, run) + maxf(pose["arm_%s_fwd" % key], 0.0) * 0.4) * move
		pose["arm_%s_out" % key] += (0.03 + 0.14 * run) * move
	pose.arm_l_out += absf(arm_l) * 0.12 * run
	pose.arm_r_yaw += _wave(12, 3.0) * 0.12 * run * move

	# Respiração: devagar descansado, ofegante depois de correr. O ritmo é integrado
	# para não pular quando o fôlego muda.
	if run * move > 0.5:
		_exertion = move_toward(_exertion, 1.0, delta * 0.12)
	else:
		_exertion = move_toward(_exertion, 0.0, delta * 0.07)
	var held: float = _weights.breath
	_breath_phase += delta * lerpf(2.0, 6.5, _exertion) * (1.0 - held)
	var idle := 1.0 - move
	# Prendendo o ar, o peito fica parado cheio (no alto da inspiração).
	var breath := lerpf(sin(_breath_phase), 1.0, held)
	var deep := lerpf(lerpf(1.0, 2.6, _exertion), 1.4, held)
	pose.torso_pitch += breath * 0.012 * deep
	# Ao puxar o ar, o peito sobe e as costas esticam um pouco.
	pose.spine_arch -= breath * 0.025 * deep
	pose.neck_fwd -= breath * 0.01 * deep
	pose.arm_l_out += breath * 0.018 * deep * idle
	pose.arm_r_out += breath * 0.015 * deep * idle
	pose.head_pitch -= breath * 0.012 * deep
	# Olha em volta parado e, de vez em quando, também andando.
	var glance := idle + 0.35 * move * (1.0 - run)
	pose.head_yaw += _look.x * glance
	pose.head_pitch += _look.y * glance

	# Ninguém fica imóvel: oscilações lentas e diferentes em cada parte do corpo.
	pose.torso_pitch += _wave(1, 0.45) * 0.025
	pose.spine_arch += _wave(13, 0.38) * 0.045
	pose.spine_bend += _wave(14, 0.29) * 0.04
	pose.neck_fwd += _wave(15, 0.47) * 0.035
	pose.torso_roll += _wave(2, 0.37) * 0.03
	pose.torso_yaw += _wave(3, 0.31) * 0.04
	pose.head_roll += _wave(4, 0.53) * 0.05
	pose.head_pitch += _wave(5, 0.61) * 0.03
	pose.arm_l_fwd += _wave(6, 0.7) * 0.05
	pose.arm_r_fwd += _wave(7, 0.83) * 0.05
	pose.elbow_l += _wave(8, 0.9) * 0.08
	pose.elbow_r += _wave(9, 0.77) * 0.08
	pose.hand_l += _wave(10, 1.1) * 0.12
	pose.hand_r += _wave(11, 1.3) * 0.12

	# Curva: o corpo inclina para dentro.
	_lean = lerpf(_lean, clampf(-turn_rate * speed * 0.035, -0.25, 0.25), 1.0 - exp(-8.0 * delta))
	pose.pelvis_roll += _lean * 0.5
	pose.torso_roll += _lean

	# Agachado: quadril baixo, tronco curvado, cabeça erguida para olhar adiante e mãos
	# à frente como garras, uma mais alta que a outra.
	pose.pelvis_y -= 0.11 * crouch
	pose.torso_pitch += 0.32 * crouch
	pose.spine_arch += 0.2 * crouch
	pose.neck_fwd += 0.05 * crouch
	pose.head_pitch -= 0.36 * crouch
	pose.arm_l_fwd += 0.42 * crouch
	pose.arm_r_fwd += 0.28 * crouch
	pose.elbow_l += 0.7 * crouch
	pose.elbow_r += 0.45 * crouch
	pose.arm_l_out += 0.08 * crouch
	pose.hand_l += 0.3 * crouch
	pose.leg_l_out += 0.06 * crouch
	pose.leg_r_out += 0.05 * crouch
	pose.ear_l -= 0.25 * crouch
	pose.ear_r -= 0.2 * crouch

	# No ar: encolhe as pernas e abre os braços para equilibrar.
	var air: float = _weights.air
	for key in ["l", "r"]:
		pose["foot_%s_y" % key] += 0.10 * air
		pose["foot_%s_z" % key] = lerpf(pose["foot_%s_z" % key], 0.05 if key == "l" else -0.03, air)
		pose["arm_%s_out" % key] += 0.35 * air
		pose["arm_%s_fwd" % key] += 0.25 * air

	# Aterrissagem: o corpo afunda e volta.
	pose.pelvis_y -= _land_eased * 0.09
	pose.torso_pitch += _land_eased * 0.25
	pose.head_pitch -= _land_eased * 0.1
	return pose


## Mira com o arco: braço esquerdo estendido segurando o arco, o direito puxa a corda até o rosto.
func _aim_overlay(pose: Dictionary) -> void:
	var weight: float = _weights.aim
	if weight < 0.001:
		return
	var pitch := aim_pitch
	# Braço do arco aponta para o centro, à frente do rosto; o da corda abre o cotovelo para
	# fora e dobra na horizontal, trazendo a mão até o queixo conforme puxa.
	# Para baixo, o goblin dobra o tronco (não a cabeça, que cairia sobre a mão da corda).
	# O quadril vira de lado e o peito vai junto até ficar quase de perfil (ombro do arco na
	# linha do alvo, senão o braço curto não alcança); a cabeça gira de volta e olha pela
	# flecha. Os braços são acertados depois, por IK (_aim_arms).
	var hips := -0.45
	var aimed := {
		"pelvis_yaw": hips, "feet_yaw": hips * 0.8, "spine_arch": 0.04, "spine_bend": 0.0, "neck_fwd": 0.06,
		"torso_pitch": 0.1 - pitch * (0.35 if pitch > 0.0 else 0.8) - 0.05 * draw, "torso_yaw": -1.1 - hips - 0.05 * draw, "torso_roll": 0.03,
		"head_pitch": -pitch * (0.6 if pitch > 0.0 else 0.15), "head_yaw": 1.0 + 0.05 * draw, "head_roll": 0.06 + 0.1 * draw,
		"arm_l_fwd": 1.5 + pitch * 0.9, "arm_l_out": 0.0, "arm_l_yaw": -0.4, "arm_l_twist": 0.0, "elbow_l": 0.06, "hand_l": 0.0,
		"arm_r_fwd": 1.45 + pitch * 0.9, "arm_r_out": 0.0, "arm_r_yaw": 0.15 + 0.75 * draw, "arm_r_twist": 1.5,
		"elbow_r": 0.7 + 1.7 * draw, "hand_r": 0.2,
		"ear_l": -0.15, "ear_r": -0.1 - 0.2 * draw,
	}
	for key: String in aimed:
		pose[key] = lerpf(pose[key], aimed[key], weight)
	# Base de arqueiro parado: pés afastados, o da frente apontando para o alvo, joelhos dobrados.
	var stance: float = weight * (1.0 - _weights.move)
	pose.pelvis_y -= (0.02 + 0.015 * draw) * weight
	pose.foot_l_z += 0.07 * stance
	pose.foot_r_z -= 0.06 * stance
	pose.leg_l_out += 0.04 * stance
	pose.leg_r_out += 0.05 * stance
	pose.foot_l_yaw -= 0.1 * stance
	pose.foot_r_yaw += 0.25 * stance
	# Segurando a corda no fim, o braço cansa e treme cada vez mais.
	var tired := 0.004 + 0.03 * smoothstep(1.0, 4.0, _hold_time) + 0.05 * _exertion
	# Prendendo o ar, o braço firma; ofegante, a mira dança.
	tired = lerpf(tired, 0.0008, float(_weights.breath)) * tremor_scale
	var shake := (_wave(20, 9.0) * 0.6 + _wave(21, 14.0) * 0.4) * tired * draw
	_bow_shake = Vector3(_wave(22, 11.0) * tired * draw, shake, 0.0) * 0.35
	# Depois do tiro a mão da corda sobe por cima do ombro até a aljava e volta com a flecha.
	var reach := sin(PI * (1.0 - reload)) * weight if reload > 0.0 else 0.0
	_quiver_reach = reach
	pose.arm_r_fwd = lerpf(pose.arm_r_fwd, 2.55, reach)
	pose.arm_r_yaw = lerpf(pose.arm_r_yaw, 0.35, reach)
	pose.arm_r_twist = lerpf(pose.arm_r_twist, 0.4, reach)
	pose.elbow_r = lerpf(pose.elbow_r, 2.1, reach)
	pose.head_roll -= 0.08 * reach
	# Coice da soltura: a mão da corda voa para trás (no IK) e o corpo sente o tranco.
	pose.hand_r -= 0.4 * _release * weight
	pose.torso_yaw += 0.06 * _release * weight


func _action_pose(action: StringName, t: float, base: Dictionary) -> Dictionary:
	var p := base.duplicate()
	match action:
		&"punch":
			# Arma (quadril e ombro direito para trás, peso no pé de trás, costas fechadas),
			# solta (o quadril vira primeiro, o ombro vem atrás e leva o braço; o corpo vai para
			# a frente sobre o pé que pisa) e continua um pouco além antes de voltar. A cabeça
			# segura o olhar no alvo enquanto o corpo gira.
			var force := 1.0 + 0.2 * _action_var
			p.pelvis_yaw = _curve(t, [[0.0, 0.0], [0.13, -0.18], [0.24, 0.22 * force], [0.31, 0.26 * force], [0.5, 0.0]])
			p.torso_yaw = base.torso_yaw + _curve(t, [[0.0, 0.0], [0.13, -0.35 * force], [0.24, 0.45 * force], [0.31, 0.55 * force], [0.5, 0.0]])
			p.pelvis_z = base.pelvis_z + _curve(t, [[0.0, 0.0], [0.13, -0.02], [0.24, 0.04], [0.34, 0.035], [0.5, 0.0]])
			p.pelvis_y = base.pelvis_y + _curve(t, [[0.0, 0.0], [0.13, -0.02], [0.24, -0.035], [0.34, -0.03], [0.5, 0.0]])
			p.torso_pitch = base.torso_pitch + _curve(t, [[0.0, 0.0], [0.13, 0.04], [0.24, 0.2], [0.31, 0.24], [0.5, 0.0]])
			p.spine_arch = base.spine_arch + _curve(t, [[0.0, 0.0], [0.13, 0.1], [0.24, -0.06], [0.34, 0.0], [0.5, 0.0]])
			p.spine_bend = base.spine_bend + _curve(t, [[0.0, 0.0], [0.13, -0.06], [0.24, 0.05], [0.5, 0.0]])
			p.torso_roll = base.torso_roll + _curve(t, [[0.0, 0.0], [0.13, 0.05], [0.24, -0.06], [0.5, 0.0]])
			p.arm_r_fwd = _curve(t, [[0.0, base.arm_r_fwd], [0.13, -0.5 * force], [0.24, 1.65], [0.31, 1.55], [0.5, base.arm_r_fwd]])
			p.elbow_r = _curve(t, [[0.0, base.elbow_r], [0.13, 1.8], [0.24, 0.1], [0.31, 0.2], [0.5, base.elbow_r]])
			p.arm_r_out = _curve(t, [[0.0, 0.06], [0.13, 0.3], [0.24, -0.12], [0.5, 0.06]])
			# A outra mão vem à frente para guardar e volta para trás no golpe.
			p.arm_l_fwd = _curve(t, [[0.0, base.arm_l_fwd], [0.13, 0.6], [0.24, -0.3], [0.34, -0.25], [0.5, base.arm_l_fwd]])
			p.elbow_l = _curve(t, [[0.0, base.elbow_l], [0.13, 1.3], [0.24, 1.1], [0.5, base.elbow_l]])
			p.foot_l_z = base.foot_l_z + _curve(t, [[0.0, 0.0], [0.2, 0.12], [0.4, 0.12], [0.5, 0.0]])
			# O pé de trás gira na ponta quando o quadril vira.
			p.foot_r_toe = base.foot_r_toe + _curve(t, [[0.0, 0.0], [0.24, 0.3], [0.4, 0.2], [0.5, 0.0]])
			p.head_yaw = base.head_yaw - (p.pelvis_yaw + p.torso_yaw - base.torso_yaw) * 0.8
			p.head_pitch = base.head_pitch + _curve(t, [[0.0, 0.0], [0.13, -0.05], [0.24, 0.08], [0.5, 0.0]])
			p.head_roll = base.head_roll + _curve(t, [[0.0, 0.0], [0.2, 0.1 * _action_var], [0.5, 0.0]])
			p.ear_l = base.ear_l + _curve(t, [[0.0, 0.0], [0.24, 0.3], [0.5, 0.0]])
			p.ear_r = base.ear_r + _curve(t, [[0.0, 0.0], [0.24, 0.3], [0.5, 0.0]])
		&"pickup":
			# Olha primeiro, desce dobrando quadril e joelhos com as costas curvadas, o ombro
			# da mão que pega cai e vai à frente; pega, e sobe com a cabeça e o peito na frente,
			# esticando as costas um pouco além do normal antes de assentar.
			p.pelvis_y = _curve(t, [[0.0, base.pelvis_y], [0.12, base.pelvis_y + 0.005], [0.42, 0.2], [0.6, 0.2], [0.95, base.pelvis_y + 0.008], [1.1, base.pelvis_y]])
			p.pelvis_x = base.pelvis_x + _curve(t, [[0.0, 0.0], [0.42, -0.015], [0.8, 0.0]])
			p.foot_l_z = _curve(t, [[0.0, base.foot_l_z], [0.3, 0.12], [0.8, 0.12], [1.1, 0.0]])
			p.foot_r_z = _curve(t, [[0.0, base.foot_r_z], [0.3, -0.08], [0.8, -0.08], [1.1, 0.0]])
			p.torso_pitch = _curve(t, [[0.0, base.torso_pitch], [0.12, base.torso_pitch + 0.03], [0.42, 0.85], [0.6, 0.8], [0.9, base.torso_pitch - 0.06], [1.1, base.torso_pitch]])
			p.spine_arch = _curve(t, [[0.0, base.spine_arch], [0.42, 0.33], [0.6, 0.3], [0.9, -0.06], [1.1, base.spine_arch]])
			p.neck_fwd = _curve(t, [[0.0, base.neck_fwd], [0.42, 0.2], [0.65, 0.2], [1.1, base.neck_fwd]])
			p.head_pitch = _curve(t, [[0.0, base.head_pitch], [0.12, 0.25], [0.42, 0.2], [0.6, 0.15], [0.8, -0.15], [1.1, base.head_pitch]])
			p.head_yaw = _curve(t, [[0.0, base.head_yaw], [0.4, 0.15 * _action_var], [1.1, base.head_yaw]])
			p.torso_roll = base.torso_roll + _curve(t, [[0.0, 0.0], [0.42, 0.1], [0.6, 0.08], [0.9, -0.02], [1.1, 0.0]])
			p.torso_yaw = base.torso_yaw + _curve(t, [[0.0, 0.0], [0.42, 0.12], [0.6, 0.1], [1.1, 0.0]])
			p.arm_r_fwd = _curve(t, [[0.0, 0.0], [0.42, 0.8], [0.52, 0.85], [0.75, 0.6], [0.9, 0.45], [1.1, 0.0]])
			p.elbow_r = _curve(t, [[0.0, 0.15], [0.42, 0.2], [0.52, 0.5], [0.75, 1.1], [0.9, 0.9], [1.1, 0.15]])
			p.hand_r = _curve(t, [[0.0, base.hand_r], [0.45, -0.2], [0.52, 0.6], [1.1, base.hand_r]])
			# A outra mão desce até perto do joelho, como apoio.
			p.arm_l_fwd = _curve(t, [[0.0, 0.0], [0.42, 0.4], [0.7, 0.3], [1.1, 0.0]])
			p.elbow_l = _curve(t, [[0.0, 0.15], [0.42, 0.7], [1.1, 0.15]])
			p.ear_l = base.ear_l + _curve(t, [[0.0, 0.0], [0.42, 0.25], [0.7, 0.2], [1.1, 0.0]])
			p.ear_r = base.ear_r + _curve(t, [[0.0, 0.0], [0.42, 0.2], [0.7, 0.15], [1.1, 0.0]])
		&"harvest":
			# Ajoelhado e curvado sobre a caça: cada puxada da faca balança o tronco e o
			# quadril. Para no meio, ergue o peito e a cabeça e escuta (orelhas em pé), depois
			# volta; no fim levanta esticando as costas.
			var listen := smoothstep(1.1, 1.25, t) * (1.0 - smoothstep(1.45, 1.6, t))
			var work := smoothstep(0.6, 0.8, t) * (1.0 - smoothstep(1.8, 2.0, t)) * (1.0 - listen)
			var stroke := sin(t * 14.0)
			p.pelvis_y = _curve(t, [[0.0, base.pelvis_y], [0.5, 0.17], [2.0, 0.17], [2.4, base.pelvis_y]])
			p.pelvis_x = base.pelvis_x + stroke * 0.006 * work
			p.foot_l_z = _curve(t, [[0.0, 0.0], [0.4, 0.15], [2.0, 0.15], [2.4, 0.0]])
			p.foot_r_z = _curve(t, [[0.0, 0.0], [0.4, -0.12], [2.0, -0.12], [2.4, 0.0]])
			p.torso_pitch = _curve(t, [[0.0, base.torso_pitch], [0.5, 0.85], [2.0, 0.85], [2.25, base.torso_pitch - 0.05], [2.4, base.torso_pitch]]) - 0.45 * listen
			p.spine_arch = _curve(t, [[0.0, base.spine_arch], [0.5, 0.35], [2.0, 0.35], [2.25, -0.05], [2.4, base.spine_arch]]) - 0.3 * listen
			p.neck_fwd = _curve(t, [[0.0, base.neck_fwd], [0.5, 0.2], [2.0, 0.2], [2.4, base.neck_fwd]]) - 0.1 * listen
			p.torso_yaw = base.torso_yaw + stroke * 0.08 * work
			p.torso_roll = base.torso_roll + sin(t * 14.0 + 0.7) * 0.05 * work
			p.spine_bend = base.spine_bend + cos(t * 14.0) * 0.03 * work
			p.head_pitch = _curve(t, [[0.0, base.head_pitch], [0.5, 0.4], [2.0, 0.4], [2.4, base.head_pitch]]) - 0.25 * listen
			p.head_yaw = (0.25 + 0.2 * _action_var) * listen - stroke * 0.05 * work
			p.ear_l = base.ear_l - 0.3 * listen
			p.ear_r = base.ear_r - 0.3 * listen
			p.arm_r_fwd = _curve(t, [[0.0, 0.0], [0.5, 0.9], [2.0, 0.9], [2.4, 0.0]]) + stroke * 0.25 * work
			p.arm_l_fwd = _curve(t, [[0.0, 0.0], [0.5, 0.8], [2.0, 0.8], [2.4, 0.0]]) - stroke * 0.15 * work
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
			# Sentar enrola a coluna (barriga contrai); esfregando os olhos fica corcunda;
			# ao ficar de pé, espreguiça: costas e pescoço esticam para trás e assentam.
			p.spine_arch = _curve(t, [[0.0, 0.0], [2.4, 0.0], [2.9, 0.42], [3.3, 0.3], [3.6, 0.38], [4.2, 0.38], [4.3, 0.3], [4.9, 0.35], [5.25, -0.14], [5.6, base.spine_arch]])
			p.neck_fwd = _curve(t, [[0.0, 0.0], [2.4, 0.0], [3.0, 0.2], [4.2, 0.22], [4.9, 0.15], [5.25, -0.05], [5.6, base.neck_fwd]])
			p.head_pitch = _curve(t, [[0.0, -0.15], [2.4, -0.15], [2.9, 0.2], [3.4, 0.35], [4.3, 0.3], [5.0, 0.0], [5.25, -0.2], [5.6, base.head_pitch]])
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
		&"eat":
			# A outra mão segura o pedaço perto do peito; a direita leva à boca duas vezes,
			# a cabeça desce ao encontro e mastiga, com as costas curvadas sobre a comida.
			var bite := _curve(t, [[0.0, 0.0], [0.35, 1.0], [0.55, 0.75], [0.8, 1.0], [1.3, 0.85], [1.6, 0.0]])
			var chew := smoothstep(0.85, 0.95, t) * (1.0 - smoothstep(1.35, 1.5, t))
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 0.62, bite)
			p.arm_r_out = lerpf(base.arm_r_out, 0.0, bite)
			p.arm_r_twist = 0.85 * bite
			p.arm_r_yaw = 0.1 * bite
			p.elbow_r = lerpf(base.elbow_r, 1.75, bite)
			p.hand_r = lerpf(base.hand_r, 0.6, bite)
			var hold := _curve(t, [[0.0, 0.0], [0.3, 1.0], [1.35, 1.0], [1.6, 0.0]])
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 0.4, hold)
			p.elbow_l = lerpf(base.elbow_l, 1.05, hold)
			p.hand_l = lerpf(base.hand_l, 0.55, hold)
			p.torso_pitch = base.torso_pitch + 0.1 * hold
			p.spine_arch = base.spine_arch + 0.1 * hold
			p.neck_fwd = base.neck_fwd + 0.08 * bite
			p.head_pitch = base.head_pitch + 0.32 * bite + sin(t * 19.0) * 0.035 * chew
			p.head_roll = base.head_roll + 0.06 * _action_var * bite
			p.ear_l = base.ear_l + 0.12 * bite + sin(t * 19.0) * 0.04 * chew
			p.ear_r = base.ear_r + 0.1 * bite + sin(t * 19.0 + 0.6) * 0.04 * chew
		&"cook":
			# Acocorado na frente do fogo, com a carne espetada na mão direita: vira o pedaço
			# de tempos em tempos, a cabeça acompanha e no meio para e escuta a floresta.
			var crouch := _curve(t, [[0.0, 0.0], [0.6, 1.0], [5.5, 1.0], [6.0, 0.0]])
			var turning := sin(t * 2.2) * smoothstep(0.8, 1.2, t) * (1.0 - smoothstep(5.2, 5.5, t))
			var listen := smoothstep(2.9, 3.1, t) * (1.0 - smoothstep(3.7, 3.9, t))
			p.pelvis_y = lerpf(base.pelvis_y, 0.18, crouch)
			p.foot_l_z = lerpf(base.foot_l_z, 0.13, crouch)
			p.foot_r_z = lerpf(base.foot_r_z, -0.06, crouch)
			p.leg_l_out = base.leg_l_out + 0.12 * crouch
			p.leg_r_out = base.leg_r_out + 0.12 * crouch
			p.torso_pitch = lerpf(base.torso_pitch, 0.55, crouch) - 0.3 * listen
			p.spine_arch = lerpf(base.spine_arch, 0.3, crouch) - 0.15 * listen
			p.neck_fwd = base.neck_fwd + 0.1 * crouch
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 1.15, crouch)
			p.elbow_r = lerpf(base.elbow_r, 0.45, crouch)
			p.arm_r_twist = 0.5 * turning * crouch
			p.hand_r = lerpf(base.hand_r, 0.5, crouch)
			# A outra mão apoia no joelho.
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 0.6, crouch)
			p.elbow_l = lerpf(base.elbow_l, 0.6, crouch)
			p.head_pitch = lerpf(base.head_pitch, 0.25, crouch) - 0.3 * listen
			p.head_yaw = base.head_yaw + 0.06 * turning + (0.35 + 0.2 * _action_var) * listen
			p.ear_l = base.ear_l - 0.3 * listen
			p.ear_r = base.ear_r - 0.3 * listen
		&"throw":
			# Arremesso por cima: o braço vai para trás do ombro com o cotovelo dobrado, o quadril
			# e o peito giram para trás e o outro braço aponta o alvo; solta com o quadril na
			# frente, o braço chicoteia e o corpo cai sobre o pé da frente.
			var force := 1.0 + 0.15 * _action_var
			p.pelvis_yaw = _curve(t, [[0.0, 0.0], [0.24, -0.25], [0.34, 0.2 * force], [0.45, 0.22], [0.7, 0.0]])
			p.torso_yaw = base.torso_yaw + _curve(t, [[0.0, 0.0], [0.24, -0.5], [0.34, 0.45 * force], [0.45, 0.5], [0.7, 0.0]])
			p.torso_pitch = base.torso_pitch + _curve(t, [[0.0, 0.0], [0.24, -0.12], [0.34, 0.25], [0.45, 0.3], [0.7, 0.0]])
			p.spine_arch = base.spine_arch + _curve(t, [[0.0, 0.0], [0.24, -0.12], [0.34, 0.1], [0.7, 0.0]])
			p.pelvis_y = base.pelvis_y + _curve(t, [[0.0, 0.0], [0.24, -0.02], [0.34, -0.035], [0.7, 0.0]])
			p.arm_r_fwd = _curve(t, [[0.0, base.arm_r_fwd], [0.24, 2.6], [0.32, 1.9], [0.38, 1.1], [0.5, 0.6], [0.7, base.arm_r_fwd]])
			p.arm_r_yaw = _curve(t, [[0.0, 0.0], [0.24, 0.35], [0.36, 0.0], [0.7, 0.0]])
			p.elbow_r = _curve(t, [[0.0, base.elbow_r], [0.24, 2.0], [0.32, 1.0], [0.38, 0.15], [0.5, 0.3], [0.7, base.elbow_r]])
			p.hand_r = _curve(t, [[0.0, base.hand_r], [0.24, 0.6], [0.34, -0.3], [0.7, base.hand_r]])
			p.arm_l_fwd = _curve(t, [[0.0, base.arm_l_fwd], [0.24, 1.2], [0.34, 0.3], [0.45, -0.2], [0.7, base.arm_l_fwd]])
			p.elbow_l = _curve(t, [[0.0, base.elbow_l], [0.24, 0.3], [0.45, 1.0], [0.7, base.elbow_l]])
			p.foot_l_z = base.foot_l_z + _curve(t, [[0.0, 0.0], [0.24, 0.06], [0.36, 0.14], [0.55, 0.12], [0.7, 0.0]])
			p.foot_r_toe = base.foot_r_toe + _curve(t, [[0.0, 0.0], [0.34, 0.3], [0.55, 0.15], [0.7, 0.0]])
			p.head_yaw = base.head_yaw - (p.pelvis_yaw + p.torso_yaw - base.torso_yaw) * 0.85
			p.head_pitch = base.head_pitch + _curve(t, [[0.0, 0.0], [0.24, -0.15], [0.4, 0.05], [0.7, 0.0]])
			p.ear_l = base.ear_l + _curve(t, [[0.0, 0.0], [0.34, 0.3], [0.7, 0.0]])
			p.ear_r = base.ear_r + _curve(t, [[0.0, 0.0], [0.34, 0.3], [0.7, 0.0]])
		&"craft":
			# Acocorado, as duas mãos trabalham juntas na frente da barriga: a direita puxa e
			# torce (raspa, amarra), a esquerda segura; a cabeça baixa olha o trabalho e, no
			# meio, ergue um pouco e escuta.
			var low := _curve(t, [[0.0, 0.0], [0.35, 1.0], [_action_duration - 0.3, 1.0], [_action_duration, 0.0]])
			var work := smoothstep(0.35, 0.5, t) * (1.0 - smoothstep(_action_duration - 0.45, _action_duration - 0.3, t))
			var listen := smoothstep(0.95, 1.05, t) * (1.0 - smoothstep(1.25, 1.35, t))
			var pull := sin(t * 10.0)
			p.pelvis_y = lerpf(base.pelvis_y, 0.2, low)
			p.foot_l_z = lerpf(base.foot_l_z, 0.1, low)
			p.foot_r_z = lerpf(base.foot_r_z, -0.05, low)
			p.leg_l_out = base.leg_l_out + 0.1 * low
			p.leg_r_out = base.leg_r_out + 0.1 * low
			p.torso_pitch = lerpf(base.torso_pitch, 0.5, low) - 0.2 * listen
			p.spine_arch = lerpf(base.spine_arch, 0.32, low) - 0.1 * listen
			p.neck_fwd = base.neck_fwd + 0.1 * low
			p.head_pitch = lerpf(base.head_pitch, 0.42, low) - 0.3 * listen
			p.head_yaw = base.head_yaw + (0.3 + 0.15 * _action_var) * listen
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 0.8, low)
			p.arm_l_out = lerpf(base.arm_l_out, 0.0, low)
			p.arm_l_twist = -0.5 * low
			p.elbow_l = lerpf(base.elbow_l, 1.25, low)
			p.hand_l = lerpf(base.hand_l, 0.55, low)
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 0.75, low) + pull * 0.12 * work * (1.0 - listen)
			p.arm_r_out = lerpf(base.arm_r_out, 0.0, low)
			p.arm_r_twist = lerpf(0.0, 0.6, low) + sin(t * 10.0 + 1.2) * 0.25 * work
			p.elbow_r = lerpf(base.elbow_r, 1.3, low) - pull * 0.25 * work * (1.0 - listen)
			p.hand_r = lerpf(base.hand_r, 0.4, low)
			p.torso_yaw = base.torso_yaw + pull * 0.04 * work
			p.ear_l = base.ear_l - 0.3 * listen
			p.ear_r = base.ear_r - 0.3 * listen
		&"scratch":
			# Riscando a parede com uma pedra (a memória do ciclo 346): a mão esquerda apoiada na
			# rocha, a direita na altura do peito arrasta a pedra em traços curtos, de cima para
			# baixo e de lado; entre um traço e outro ela para, e a cabeça chega perto para ver.
			var raise := _curve(t, [[0.0, 0.0], [0.5, 1.0], [_action_duration - 0.5, 1.0], [_action_duration, 0.0]])
			var work := smoothstep(0.5, 0.7, t) * (1.0 - smoothstep(_action_duration - 0.7, _action_duration - 0.5, t))
			# Um traço a cada 0,6 s: desce (ou atravessa) depressa e volta devagar, sem raspar.
			var phase := fmod(t, 0.6) / 0.6
			var drag := smoothstep(0.0, 0.35, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
			var across := 1.0 if int(t / 0.6) % 3 == 1 else 0.0
			var peek := smoothstep(0.8, 1.0, sin(t * 0.9) * 0.5 + 0.5)
			p.torso_pitch = base.torso_pitch + 0.15 * raise + 0.05 * peek
			p.spine_arch = base.spine_arch + 0.08 * raise
			p.neck_fwd = base.neck_fwd + 0.12 * raise + 0.08 * peek
			p.head_pitch = base.head_pitch + 0.1 * raise + 0.1 * drag * work
			p.head_roll = base.head_roll + 0.12 * raise * _action_var
			p.head_yaw = base.head_yaw - 0.12 * raise
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 1.25, raise)
			p.arm_l_out = lerpf(base.arm_l_out, 0.25, raise)
			p.elbow_l = lerpf(base.elbow_l, 0.6, raise)
			p.hand_l = lerpf(base.hand_l, -0.5, raise)
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 1.15, raise) + (0.22 - 0.44 * drag) * (1.0 - across) * work
			p.arm_r_yaw = (0.25 - 0.5 * drag) * across * work
			p.arm_r_out = lerpf(base.arm_r_out, -0.1, raise)
			p.elbow_r = lerpf(base.elbow_r, 0.95, raise) + 0.15 * drag * work
			p.hand_r = lerpf(base.hand_r, 0.4, raise)
			p.torso_yaw = base.torso_yaw + 0.06 * drag * work
			p.ear_l = base.ear_l + 0.15 * raise
			p.ear_r = base.ear_r + 0.1 * raise
		&"rub_mud":
			# Agacha na poça, pega lama com as duas mãos e esfrega: a direita no braço e no peito,
			# a esquerda no rosto e atrás da orelha; depois troca. Levanta sacudindo as mãos.
			var low := _curve(t, [[0.0, 0.0], [0.4, 1.0], [2.6, 1.0], [3.0, 0.0]])
			var scoop := smoothstep(0.25, 0.45, t) * (1.0 - smoothstep(0.65, 0.85, t))
			var rub_a := smoothstep(0.8, 1.0, t) * (1.0 - smoothstep(1.65, 1.85, t))
			var rub_b := smoothstep(1.75, 1.95, t) * (1.0 - smoothstep(2.55, 2.75, t))
			var shake := smoothstep(2.6, 2.7, t) * (1.0 - smoothstep(2.85, 3.0, t))
			var stroke := sin(t * 11.0)
			p.pelvis_y = lerpf(base.pelvis_y, 0.21, low)
			p.foot_l_z = lerpf(base.foot_l_z, 0.1, low)
			p.foot_r_z = lerpf(base.foot_r_z, -0.06, low)
			p.leg_l_out = base.leg_l_out + 0.12 * low
			p.leg_r_out = base.leg_r_out + 0.12 * low
			p.torso_pitch = lerpf(base.torso_pitch, 0.45, low) + 0.35 * scoop
			p.spine_arch = lerpf(base.spine_arch, 0.28, low) + 0.1 * scoop
			p.head_pitch = lerpf(base.head_pitch, 0.2, low) + 0.25 * scoop - 0.2 * rub_b
			p.head_roll = base.head_roll + 0.2 * rub_b - 0.12 * rub_a
			p.head_yaw = base.head_yaw + 0.25 * rub_a
			# Pegar a lama: as duas mãos descem até o chão.
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 0.9, scoop)
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 0.9, scoop)
			p.elbow_l = lerpf(base.elbow_l, 0.2, scoop)
			p.elbow_r = lerpf(base.elbow_r, 0.2, scoop)
			# Direita esfrega o braço esquerdo e o peito (cruza o corpo).
			p.arm_r_fwd = lerpf(p.arm_r_fwd, 0.55 + stroke * 0.15, rub_a)
			p.arm_r_out = lerpf(base.arm_r_out, -0.3, rub_a)
			p.arm_r_twist = lerpf(0.0, 0.9, rub_a)
			p.elbow_r = lerpf(p.elbow_r, 1.5 + stroke * 0.2, rub_a)
			p.arm_l_fwd = lerpf(p.arm_l_fwd, 0.5, rub_a)
			p.elbow_l = lerpf(p.elbow_l, 0.9, rub_a)
			# Esquerda no rosto e atrás da orelha; a direita esfrega a coxa.
			p.arm_l_fwd = lerpf(p.arm_l_fwd, 1.4, rub_b)
			p.arm_l_out = lerpf(base.arm_l_out, 0.2, rub_b)
			p.arm_l_twist = lerpf(0.0, -1.2, rub_b)
			p.arm_l_yaw = lerpf(0.0, -0.6 + stroke * 0.12, rub_b)
			p.elbow_l = lerpf(p.elbow_l, 2.2 + stroke * 0.12, rub_b)
			p.arm_r_fwd = lerpf(p.arm_r_fwd, 0.35 + stroke * 0.12, rub_b)
			p.arm_r_out = lerpf(p.arm_r_out, 0.15, rub_b)
			p.elbow_r = lerpf(p.elbow_r, 0.6, rub_b)
			# Sacode as mãos.
			p.hand_l = base.hand_l + sin(t * 30.0) * 0.5 * shake
			p.hand_r = base.hand_r + sin(t * 30.0 + 1.0) * 0.5 * shake
			p.ear_l = base.ear_l + 0.25 * rub_b - 0.1 * rub_a
			p.ear_r = base.ear_r + 0.2 * low
		&"lie_down":
			# Ajoelha, apoia as mãos no chão e vai se deitando (a tela já está escurecendo).
			var kneel := smoothstep(0.0, 0.9, t)
			var down := smoothstep(0.8, 2.0, t)
			p.pelvis_y = lerpf(base.pelvis_y, 0.17, kneel) - 0.06 * down
			p.foot_l_z = lerpf(base.foot_l_z, 0.12, kneel)
			p.foot_r_z = lerpf(base.foot_r_z, -0.12, kneel)
			p.torso_pitch = lerpf(base.torso_pitch, 0.7, kneel) + 0.4 * down
			p.spine_arch = lerpf(base.spine_arch, 0.3, kneel)
			p.head_pitch = lerpf(base.head_pitch, 0.25, kneel)
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 1.1, kneel)
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 1.0, kneel)
			p.elbow_l = lerpf(base.elbow_l, 0.25, kneel)
			p.elbow_r = lerpf(base.elbow_r, 0.3, kneel)
			p.ear_l = base.ear_l + 0.3 * kneel
			p.ear_r = base.ear_r + 0.3 * kneel
	return p


## Parado: o peso troca de perna de tempos em tempos e, depois de um tempo sem fazer
## nada, o goblin tem uma mania. Qualquer movimento corta a mania.
func _idle_overlay(delta: float, pose: Dictionary) -> Dictionary:
	var idle: float = (1.0 - _weights.move) * (1.0 - _weights.aim) * (1.0 - _weights.air)

	# Apoio numa perna: o quadril escorrega para o lado dela, o outro lado cai, o joelho
	# solto dobra e o pé dele vai um pouco à frente, só na ponta.
	_shift_timer -= delta
	if _shift_timer <= 0.0:
		_shift_timer = randf_range(3.5, 8.0)
		_shift_target = [-1.0, -0.45, 0.4, 1.0].pick_random()
	_shift = lerpf(_shift, _shift_target, 1.0 - exp(-1.6 * delta))
	var w: float = _shift * idle * (1.0 - _weights.crouch)
	var free_key := "r" if w > 0.0 else "l"
	pose.pelvis_x += w * 0.028
	pose.pelvis_roll += w * 0.055
	pose.torso_roll -= w * 0.07
	pose.head_roll += w * 0.03
	pose["foot_%s_y" % free_key] += absf(w) * 0.012
	pose["foot_%s_z" % free_key] += absf(w) * 0.035
	pose["foot_%s_toe" % free_key] += absf(w) * 0.14

	# Cansado depois de correr: curva o corpo e apoia as mãos nos joelhos.
	var panting: float = smoothstep(0.45, 0.85, _exertion) * idle * (1.0 - _weights.crouch)
	if panting > 0.001:
		pose = _mix(pose, _merge(pose, {
			"torso_pitch": 0.45 + sin(_breath_phase) * 0.05, "spine_arch": 0.32 - sin(_breath_phase) * 0.06,
			"head_pitch": -0.4, "pelvis_y": pose.pelvis_y - 0.03,
			"arm_l_fwd": 0.85, "arm_r_fwd": 0.8, "elbow_l": 0.12, "elbow_r": 0.18, "arm_l_out": 0.06, "arm_r_out": 0.04,
			"hand_l": 0.5, "hand_r": 0.45, "ear_l": 0.35, "ear_r": 0.3,
		}), panting)

	if _action != &"" or idle < 0.9 or _exertion > 0.4 or sniffing:
		_idle_time = 0.0
	else:
		_idle_time += delta
	if _fidget == &"":
		if _idle_time > _next_fidget:
			# Faminto, metade das vezes ele põe a mão na barriga.
			if starving and randf() < 0.5:
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
	pose = _mix(pose, p, envelope * idle)
	if t >= _fidget_duration or idle < 0.3:
		_fidget = &""
		_idle_time = 0.0
		_next_fidget = randf_range(5.0, 11.0)
	return pose


## Frio: tremor rápido no tronco e na cabeça o tempo todo; quando não está andando nem
## mirando, abraça o próprio corpo, encolhe o pescoço e baixa as orelhas.
func _cold_overlay(pose: Dictionary) -> void:
	if shiver <= 0.001:
		return
	var tremble := sin(_time * 41.0) * 0.6 + sin(_time * 29.0 + 1.3) * 0.4
	pose.torso_roll += tremble * 0.014 * shiver
	pose.torso_yaw += sin(_time * 33.0 + 0.4) * 0.012 * shiver
	pose.head_roll += tremble * 0.016 * shiver
	var hug: float = shiver * (1.0 - 0.7 * float(_weights.move)) * (1.0 - float(_weights.aim))
	for side in ["l", "r"]:
		pose["arm_%s_fwd" % side] += 0.5 * hug
		pose["arm_%s_out" % side] -= 0.06 * hug
		pose["arm_%s_twist" % side] += 0.6 * hug
		pose["elbow_%s" % side] += 1.1 * hug + tremble * 0.03 * shiver
		pose["ear_%s" % side] += 0.35 * shiver
	pose.spine_arch += 0.1 * hug
	pose.neck_fwd += 0.05 * hug
	pose.head_pitch += 0.1 * hug
	pose.pelvis_y -= 0.01 * hug


## Farejando (agachado e parado): o focinho sobe atrás do cheiro, em fungadas curtas; a
## cabeça varre o vento de um lado ao outro, as orelhas vão para trás e uma mão toca o chão.
func _sniff_overlay(pose: Dictionary) -> void:
	var w: float = _weights.sniff
	if w < 0.001:
		return
	var puff := absf(sin(_time * 15.0)) * absf(sin(_time * 2.6))
	var sweep := sin(_time * 0.8) * 0.45 + _wave(30, 0.6) * 0.1
	pose.torso_pitch += 0.12 * w
	pose.spine_arch += 0.06 * w
	pose.neck_fwd += 0.16 * w
	pose.head_pitch += (-0.3 + puff * 0.06) * w
	pose.head_yaw = lerpf(pose.head_yaw, sweep, w)
	pose.torso_yaw += sweep * 0.15 * w
	pose.arm_l_fwd += 0.35 * w
	pose.elbow_l -= 0.45 * w
	pose.hand_l += 0.3 * w
	pose.ear_l = lerpf(pose.ear_l, -0.4 + puff * 0.05, w)
	pose.ear_r = lerpf(pose.ear_r, -0.38, w)


## Tocha acesa: a mão direita a leva erguida um pouco à frente do ombro (o fogo longe do
## rosto). Mirando, o arco manda (a tocha já foi fincada no chão).
func _torch_overlay(pose: Dictionary) -> void:
	var w: float = _weights.torch * (1.0 - float(_weights.aim))
	if w < 0.001:
		return
	pose.arm_r_fwd = lerpf(pose.arm_r_fwd, 0.85 + _wave(31, 1.2) * 0.04, w)
	pose.arm_r_out = lerpf(pose.arm_r_out, 0.22, w)
	pose.arm_r_yaw = lerpf(pose.arm_r_yaw, 0.0, w)
	pose.arm_r_twist = lerpf(pose.arm_r_twist, 0.3, w)
	pose.elbow_r = lerpf(pose.elbow_r, 1.1, w)
	pose.hand_r = lerpf(pose.hand_r, 0.5, w)
	pose.head_roll -= 0.04 * w


## Mecânica do corpo, por cima de qualquer pose (andar, ação, mania, mira): o tronco reage
## ao que o resto do corpo faz, em vez de ser um bloco duro entre pernas e braços.
## - Dobradiça: inclinar para a frente dobra no quadril, que recua para o peso ficar sobre
##   os pés, e as costas arredondam.
## - Braços: esticar um braço traz o ombro junto (o peito gira); erguer um braço acima do
##   ombro inclina o tronco para o outro lado; os dois à frente fecham os ombros.
## - Molas: o tronco é uma massa presa ao quadril. Quando o quadril afunda (passo, agachar,
##   aterrissar), a coluna primeiro estica e depois comprime, passa do ponto e volta; ao
##   arrancar, o corpo inclina para a frente e, ao frear, o peito continua indo e assenta.
##   A cabeça compensa a mola para o olhar ficar firme.
func _body_mechanics(delta: float, pose: Dictionary) -> void:
	var aim: float = _weights.aim
	var lying := _action == &"wake"
	# Braços puxando o tronco (a mira já tem o corpo montado para os braços do IK).
	var couple := (1.0 - aim) * (1.0 - 0.5 * float(_weights.move))
	var reach_l: float = pose.arm_l_fwd - 0.1
	var reach_r: float = pose.arm_r_fwd - 0.05
	pose.torso_yaw += clampf(reach_r - reach_l, -2.0, 2.0) * 0.08 * couple
	pose.torso_roll += (maxf(pose.arm_l_fwd - 1.1, 0.0) - maxf(pose.arm_r_fwd - 1.1, 0.0)) * 0.07 * couple
	pose.spine_arch += clampf(reach_l + reach_r, 0.0, 2.0) * 0.04 * couple

	# Dobradiça no quadril: o que passa de uma leve inclinação vai em parte para a bacia.
	if not lying:
		var bend := maxf(float(pose.torso_pitch) - 0.2, 0.0)
		var hinge := bend * 0.55
		pose.pelvis_pitch += hinge
		pose.torso_pitch -= hinge
		pose.pelvis_z -= sin(minf(bend, 1.2)) * 0.07
		pose.pelvis_y -= bend * 0.02
		pose.spine_arch += bend * 0.3

	# Molas (passos curtos para ficarem estáveis com qualquer taxa de quadros).
	var steps := maxi(1, ceili(delta / (1.0 / 120.0)))
	var dt := delta / steps
	var speed := Vector2(velocity_local.x, velocity_local.z)
	for i in steps:
		# Coluna: ~2,4 Hz, pouco amortecida (quica uma vez e assenta).
		_torso_vy += (220.0 * (float(pose.pelvis_y) - _torso_y) - 10.0 * _torso_vy) * dt
		_torso_y += _torso_vy * dt
		# Velocidade do peito atrás da do corpo: ~1,2 Hz.
		_vel_lag_speed += ((speed - _vel_lag) * 60.0 - _vel_lag_speed * 8.0) * dt
		_vel_lag += _vel_lag_speed * dt
	var springy := (1.0 - 0.6 * aim) * (0.0 if lying else 1.0)
	# + = comprimida (o tronco desceu mais que o quadril e empurra a coluna).
	var squash := clampf((float(pose.pelvis_y) - _torso_y) * 5.0, -0.3, 0.3) * springy
	_squash = squash
	pose.spine_arch += squash * 0.8
	pose.torso_pitch += squash * 0.5
	pose.neck_fwd += squash * 0.3
	pose.head_pitch -= squash * 0.75
	pose.arm_l_fwd += squash * 0.3
	pose.arm_r_fwd += squash * 0.3
	pose.elbow_l += squash * 0.4
	pose.elbow_r += squash * 0.4
	# Arrancar: inclina para a frente (empurra o chão). Frear: o peito continua para a frente.
	var surge := speed.y - _vel_lag.y
	var lean := (clampf(surge, 0.0, 3.0) * 0.05 + clampf(-surge, 0.0, 3.0) * 0.07) * springy
	pose.torso_pitch += lean
	pose.head_pitch -= lean * 0.6
	pose.arm_l_fwd += lean * 0.6
	pose.arm_r_fwd += lean * 0.5


## Na borda: braços abertos girando, corpo jogado para longe do vazio, olhar para baixo
## e um tremor que cresce com o desequilíbrio. No ar, depois de tombar, os braços continuam.
func _balance_overlay(pose: Dictionary) -> void:
	var t := teeter
	if t < 0.001:
		return
	var away := -teeter_dir
	var wobble := _wave(30, 3.5) * 0.08 * t
	pose.torso_pitch -= teeter_dir.y * 0.35 * t
	pose.torso_roll += teeter_dir.x * 0.3 * t + wobble
	pose.spine_bend += teeter_dir.x * 0.1 * t
	pose.pelvis_x += away.x * 0.03 * t
	pose.pelvis_z += away.y * 0.03 * t
	pose.pelvis_y -= 0.03 * t
	pose.head_pitch += 0.3 * t
	pose.head_yaw = lerpf(pose.head_yaw, atan2(teeter_dir.x, teeter_dir.y) * 0.5, t)
	for i in 2:
		var key := "l" if i == 0 else "r"
		var circle := _time * 9.0 + i * 2.2
		pose["arm_%s_out" % key] = lerpf(pose["arm_%s_out" % key], 1.15 + sin(circle) * 0.35, t)
		pose["arm_%s_fwd" % key] = lerpf(pose["arm_%s_fwd" % key], cos(circle) * 0.9, t)
		pose["elbow_" + key] = lerpf(pose["elbow_" + key], 0.35, t)
		pose["ear_" + key] -= 0.3 * t


## Pés no chão: um raio por pé acha a altura e a inclinação do chão embaixo dele. O quadril
## desce até o pé mais baixo que ainda tem apoio; pé sem chão fica pendurado, com a ponta caída.
func _ground_feet(delta: float, pose: Dictionary) -> void:
	var target_weight: float = 0.0 if body == null or _action == &"wake" else (1.0 - _weights.air)
	_ground_weight = lerpf(_ground_weight, target_weight, 1.0 - exp(-10.0 * delta))
	if _ground_weight < 0.01:
		return
	var space := body.get_world_3d().direct_space_state
	var xf := skeleton.global_transform
	var model_basis := xf.basis.orthonormalized()
	var leg_length := _hip_height - _ankle_height
	var drop := 0.0
	for side in 2:
		var key := "l" if side == 0 else "r"
		var outward := 1.0 if side == 0 else -1.0
		var spread: float = 0.075 + pose["leg_%s_out" % key] * leg_length
		var local := Basis(Vector3.UP, pose.pelvis_yaw) * Vector3(outward * spread + pose.pelvis_x, 0.0, pose["foot_%s_z" % key])
		var at := xf * local
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.45, at + Vector3.DOWN * (FOOT_REACH + 0.1), 1, [body.get_rid()])
		var hit := space.intersect_ray(query)
		var offset := FOOT_HANG
		var tilt := Basis.IDENTITY
		foot_supported[side] = false
		if not hit.is_empty() and (hit.position as Vector3).y - xf.origin.y > -FOOT_REACH + 0.01:
			offset = clampf((hit.position as Vector3).y - xf.origin.y, -FOOT_REACH, 0.35)
			foot_supported[side] = true
			var normal := model_basis.inverse() * (hit.normal as Vector3)
			if normal.y > 0.5:
				tilt = Basis(Quaternion(Vector3.UP, normal.normalized()))
		_foot_ground[side] = lerpf(_foot_ground[side], offset, 1.0 - exp(-20.0 * delta))
		_foot_tilt[side] = (_foot_tilt[side] as Basis).slerp(tilt, 1.0 - exp(-12.0 * delta))
		if foot_supported[side]:
			drop = minf(drop, _foot_ground[side])
	drop = maxf(drop, -0.2)
	pose.pelvis_y += drop * _ground_weight
	# Só um pé apoiado: o peso vai para ele (quadril e tronco para aquele lado).
	if foot_supported[0] != foot_supported[1]:
		var toward := 1.0 if foot_supported[0] else -1.0
		pose.pelvis_x += 0.03 * toward * _ground_weight
		pose.torso_roll -= 0.08 * toward * _ground_weight
		pose.head_roll -= 0.05 * toward * _ground_weight
	for side in 2:
		var key := "l" if side == 0 else "r"
		pose["foot_%s_y" % key] += float(_foot_ground[side]) * _ground_weight
		if not foot_supported[side]:
			pose["foot_%s_toe" % key] += 0.5 * _ground_weight


## Arco: conta o tempo segurando a corda no fim e arma o coice quando a corda escapa.
func _update_bow_state(delta: float) -> void:
	_hold_time = _hold_time + delta if aiming and draw >= 0.99 else 0.0
	if aiming and _last_draw > 0.3 and draw <= 0.0:
		_release = 1.0
	_release = move_toward(_release, 0.0, delta * 3.5)
	_last_draw = draw


## Oscilação lenta e irregular (-1..1): três senos de frequências que não se repetem.
func _wave(seed: int, speed: float) -> float:
	var t := _time * speed + seed * 17.31
	return sin(t) * 0.6 + sin(t * 2.31 + 1.7) * 0.3 + sin(t * 4.73 + seed) * 0.1


## Cópia de `pose` com os valores de `values` por cima.
func _merge(pose: Dictionary, values: Dictionary) -> Dictionary:
	var out := pose.duplicate()
	out.merge(values, true)
	return out


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
	_approach("sniff", 1.0 if sniffing else 0.0, 7.0, delta)
	_approach("breath", 1.0 if breath_held else 0.0, 9.0, delta)
	_approach("torch", 1.0 if holding_torch else 0.0, 6.0, delta)


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
		var target: float = pose["ear_l" if i == 0 else "ear_r"] + _land * 0.5 - vertical * 0.12 + _squash * 0.6
		_ear_speed[i] += ((target - _ears[i]) * 160.0 - _ear_speed[i] * 11.0) * delta
		_ears[i] += _ear_speed[i] * delta
		if randf() < delta * 0.15:
			_ear_speed[i] += randf_range(-4.0, 4.0)
		pose["ear_l" if i == 0 else "ear_r"] = _ears[i]


# --- Pose -> ossos ---------------------------------------------------------------

func _apply(pose: Dictionary) -> void:
	skeleton.set_bone_pose_position(_bones.quadril, _pelvis_rest + Vector3(pose.pelvis_x, pose.pelvis_y - _hip_height, pose.pelvis_z))
	_rotate(_bones.quadril, Basis.from_euler(Vector3(pose.pelvis_pitch, pose.pelvis_yaw, pose.pelvis_roll)))

	var pelvis_tilt := Basis(Vector3.RIGHT, pose.pelvis_pitch).inverse()
	var leg_length := _hip_height - _ankle_height
	for key in ["l", "r"]:
		var suffix := "E" if key == "l" else "D"
		var outward := 1.0 if key == "l" else -1.0
		# Alvo do tornozelo em relação ao quadril, no referencial da bacia.
		var target := pelvis_tilt * Vector3(0.0, pose["foot_%s_y" % key] - pose.pelvis_y, pose["foot_%s_z" % key] - pose.pelvis_z)
		var angles := _leg_angles(target.z, -target.y)
		var thigh := angles.x - _rest_leg.x
		var knee := angles.y - _rest_leg.y
		# Abertura da perna; quando o quadril escorrega de lado, a perna compensa e o pé fica onde estava.
		var splay: float = pose["leg_%s_out" % key] - pose.pelvis_x * outward / leg_length
		_rotate(_bones["perna_" + suffix], Basis(Vector3.BACK, splay * outward) * Basis(Vector3.RIGHT, -thigh))
		_rotate(_bones["canela_" + suffix], Basis(Vector3.RIGHT, knee))
		# O pé segue a perna (deitado) ou fica paralelo ao chão, girado para fora.
		var toe: float = pose["foot_%s_toe" % key]
		_rotate(_bones["pe_" + suffix], Basis(Vector3.RIGHT, toe))
		var foot_yaw: float = pose.feet_yaw + pose["foot_%s_yaw" % key] * outward
		var tilt := Basis.IDENTITY.slerp(_foot_tilt[0 if key == "l" else 1], _ground_weight)
		_orient(_bones["pe_" + suffix], tilt * Basis(Vector3.UP, foot_yaw) * Basis(Vector3.RIGHT, toe), pose.foot_flat)

	# Coluna: o giro do tronco se divide entre lombar (tronco) e peito; a curvatura vem por cima.
	# A soma dos dois é o giro de antes mais arch / 2, então os braços (presos no peito)
	# continuam apontando para onde as poses foram calibradas.
	var arch: float = pose.spine_arch
	var bend: float = pose.spine_bend
	_rotate(_bones.tronco, Basis.from_euler(Vector3(pose.torso_pitch * 0.45 - arch * 0.5, pose.torso_yaw * 0.4, pose.torso_roll * 0.5 + bend)))
	_rotate(_bones.peito, Basis.from_euler(Vector3(pose.torso_pitch * 0.55 + arch, pose.torso_yaw * 0.6, pose.torso_roll * 0.5 - bend * 1.4)))
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
	# O pescoço leva parte do olhar; a cabeça compensa a curva das costas e do pescoço.
	var neck: float = pose.neck_fwd
	_rotate(_bones.pescoco, Basis.from_euler(Vector3(pose.head_pitch * 0.35 + neck, pose.head_yaw * 0.4, pose.head_roll * 0.3)))
	_rotate(_bones.cabeca, Basis.from_euler(Vector3(pose.head_pitch * 0.65 - neck - arch * 0.5, pose.head_yaw * 0.6, pose.head_roll * 0.7 + bend * 0.4)))
	_rotate(_bones.orelha_E, Basis(Vector3.BACK, -pose.ear_l))
	_rotate(_bones.orelha_D, Basis(Vector3.BACK, pose.ear_r))
	_aim_arms()


## Mirando: a empunhadura vai para a linha que sai da ancoragem (queixo) até o alvo, à frente
## dela o quanto a corda está puxada; a mão da corda pega a corda onde ela está agora.
## Se o braço não alcança, o arco fica onde a mão chega e a corda vai até ele do mesmo jeito.
func _aim_arms() -> void:
	var weight: float = _weights.aim
	if weight < 0.001 or aim_point == Vector3.INF:
		return
	var target := skeleton.global_transform.affine_inverse() * aim_point
	var anchor := skeleton.get_bone_global_pose(_bones.cabeca) * _anchor
	var aim := (target - anchor).normalized()
	var right := aim.cross(Vector3.UP).normalized()
	var grip_goal := anchor + aim * (nock_depth + PREDRAW * (1.0 - draw)) + _bow_shake - Vector3.UP * 0.03 * _release
	var shoulder_l := skeleton.get_bone_global_pose(_bones.braco_E).origin
	# O cotovelo do arco fica quase reto, virado para fora e para baixo.
	_reach("E", grip_goal - aim * bow_grip.length(), shoulder_l - right * 0.5 + Vector3.DOWN * 0.4, weight)

	var grip := skeleton.get_bone_global_pose(_bones.mao_E) * bow_grip
	var line := (target - grip).normalized()
	var nock := grip - line * nock_depth
	var wrist := nock - line * STRING_FINGERS + (right * 0.05 - line * 0.07) * _release
	var shoulder_r := skeleton.get_bone_global_pose(_bones.braco_D).origin
	# O cotovelo da corda vai para trás e para fora, na altura do ombro, mesmo mirando para
	# baixo (seguindo a linha inclinada ele subiria e o antebraço passaria rente ao queixo).
	var flat := Vector3(line.x, 0.0, line.z).normalized()
	var pole := shoulder_r - flat * 0.6 + right * 0.35
	# Recarga: a mão sai da corda por fora, passa ao lado do ombro (longe da cabeça) e
	# chega às penas da aljava; depois volta pelo mesmo caminho com a flecha.
	if _quiver_reach > 0.0:
		var t := _quiver_reach
		var side := shoulder_r + right * 0.22 + Vector3.UP * 0.12
		wrist = wrist * (1.0 - t) * (1.0 - t) + side * 2.0 * (1.0 - t) * t + (quiver_top + right * 0.03 + Vector3.UP * 0.04) * t * t
		pole = pole.lerp(shoulder_r + right * 0.4 + Vector3.UP * 0.3, t)
	_reach("D", wrist, pole, weight)
	# Os dedos apontam para a corda.
	var hand_r: int = _bones.mao_D
	var fingers := skeleton.get_bone_global_pose(hand_r).basis.y.normalized()
	_swing(hand_r, fingers, line, weight * 0.7 * (1.0 - _quiver_reach))


## IK de duas juntas por giros, no espaço do esqueleto: o braço gira até o cotovelo ficar
## no lugar (dobrando para o lado de `pole`), torce no próprio eixo para o antebraço já
## estar no plano da dobra e o antebraço gira até o punho chegar em `target`.
func _reach(side: String, target: Vector3, pole: Vector3, weight: float) -> void:
	if weight < 0.001:
		return
	var upper: int = _bones["braco_" + side]
	var lower: int = _bones["antebraco_" + side]
	var hand: int = _bones["mao_" + side]
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var elbow := skeleton.get_bone_global_pose(lower).origin
	var wrist := skeleton.get_bone_global_pose(hand).origin
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var to_target := target - shoulder
	var distance := clampf(to_target.length(), absf(a - b) + 0.01, (a + b) * 0.995)
	var along := to_target.normalized()
	var bend := pole - shoulder
	bend = (bend - along * bend.dot(along)).normalized()
	var cos_shoulder := clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0)
	var elbow_goal := shoulder + along * (a * cos_shoulder) + bend * (a * sqrt(1.0 - cos_shoulder * cos_shoulder))
	var wrist_goal := shoulder + along * distance
	_swing(upper, elbow - shoulder, elbow_goal - shoulder, weight)

	elbow = skeleton.get_bone_global_pose(lower).origin
	wrist = skeleton.get_bone_global_pose(hand).origin
	var axis := (elbow - shoulder).normalized()
	var now := (wrist - elbow) - axis * (wrist - elbow).dot(axis)
	var want := (wrist_goal - elbow) - axis * (wrist_goal - elbow).dot(axis)
	if now.length() > 0.05 * b and want.length() > 0.05 * b:
		_turn(upper, Quaternion(axis, now.signed_angle_to(want, axis) * weight))
		wrist = skeleton.get_bone_global_pose(hand).origin
	_swing(lower, wrist - elbow, wrist_goal - elbow, weight)


## Gira o osso (no espaço do esqueleto, em volta da própria junta) levando `from` até `to`.
func _swing(bone: int, from: Vector3, to: Vector3, weight: float) -> void:
	if from.length_squared() < 1e-8 or to.length_squared() < 1e-8:
		return
	_turn(bone, Quaternion.IDENTITY.slerp(Quaternion(from.normalized(), to.normalized()), weight))


func _turn(bone: int, rotation: Quaternion) -> void:
	var parent_now := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
	var now := skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(bone, (parent_now.inverse() * (Basis(rotation) * now)).get_rotation_quaternion())


# --- Consultas do Player ---------------------------------------------------------

func aim_weight() -> float:
	return _weights.aim


## Direção global do antebraço (cotovelo -> punho).
func forearm_direction(left: bool) -> Vector3:
	var side := "E" if left else "D"
	var elbow := skeleton.get_bone_global_pose(_bones["antebraco_" + side]).origin
	var wrist := skeleton.get_bone_global_pose(_bones["mao_" + side]).origin
	return (skeleton.global_basis * (wrist - elbow)).normalized()


## Posição global da empunhadura do arco na mão esquerda, já com a pose deste frame.
func bow_grip_position() -> Vector3:
	return skeleton.global_transform * (skeleton.get_bone_global_pose(_bones.mao_E) * bow_grip)


## Gira o osso por `rotation` (eixos do modelo em repouso), carregado pelo que o pai já girou.
func _rotate(bone: int, rotation: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_now := skeleton.get_bone_global_pose(parent).basis
	var carried: Basis = parent_now * (_rest_global[parent] as Basis).inverse()
	var global_basis: Basis = carried * rotation * _rest_global[bone]
	skeleton.set_bone_pose_rotation(bone, (parent_now.inverse() * global_basis).get_rotation_quaternion())


## Leva o osso, com peso `weight`, à orientação `rotation` (eixos do modelo em repouso)
## no espaço do esqueleto, sem herdar o giro dos pais. Usado para o pé ficar no chão.
func _orient(bone: int, rotation: Basis, weight: float) -> void:
	if weight <= 0.0:
		return
	var parent_now := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis
	var target := (parent_now.inverse() * rotation * (_rest_global[bone] as Basis)).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(target, weight))


## IK da perna no plano de perfil: dado o tornozelo (dz à frente, dy abaixo do quadril),
## devolve (ângulo da coxa para a frente, dobra do joelho).
func _leg_angles(dz: float, dy: float) -> Vector2:
	var distance := clampf(sqrt(dz * dz + dy * dy), 0.04, _thigh + _shin - 0.001)
	var knee_inside := acos(clampf((_thigh * _thigh + _shin * _shin - distance * distance) / (2.0 * _thigh * _shin), -1.0, 1.0))
	var to_target := atan2(dz, dy)
	var offset := acos(clampf((_thigh * _thigh + distance * distance - _shin * _shin) / (2.0 * _thigh * distance), -1.0, 1.0))
	return Vector2(to_target + offset, PI - knee_inside)
