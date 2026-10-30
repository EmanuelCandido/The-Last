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
## Velocidade vertical do corpo (m/s, + subindo): o pulo muda de pose na subida, no alto e na queda.
var vertical_speed := 0.0
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
## Luta (F11): a família da arma na mão (&"knife", &"club", &"spear"; &"" = sem arma de mão),
## defendendo (segurando a defesa; com a lança, firmada), a janela do golpe em andamento (segundos,
## começo e fim: as poses dos golpes se medem por ela) e onde a arma fica na mão direita (espaço do
## osso da mão, como o `bow_grip`).
var weapon_style := &""
var guarding := false
var strike_window := Vector2(0.2, 0.35)
## Quanto o corpo se curva para golpear algo menor que ele (rad; F12: o orc contra o goblin, que tem
## metade da altura: sem isto o golpe de lado passava por cima da cabeça dele).
var strike_bend := 0.0
var weapon_grip := Vector3(0.0, 0.036, 0.008)

## Quanto o pé desce abaixo da base do corpo procurando chão (m).
const FOOT_REACH := 0.3
## Pé sem chão: fica pendurado um pouco abaixo da borda, com o joelho solto.
const FOOT_HANG := -0.1
## Onde a corda encosta ao puxar: no canto da mandíbula, por fora da bochecha direita
## (esqueleto em repouso). A cabeça do goblin é enorme (10 cm de meia-largura na boca, queixo
## até z = 0,14): ancorada embaixo do queixo, a mão ficava 26 cm à frente do ombro (o braço tem
## 32), o cotovelo não tinha como ir para trás e o antebraço atravessava o pescoço. Do lado do
## rosto, a mão fica perto do ombro, o cotovelo dobra para trás e o antebraço segue a flecha.
const ANCHOR_REST := Vector3(-0.13, 0.7, 0.07)
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
## Marcha (0 = andar, 1 = disparar), suavizada: muda o desenho do passo, não só o ritmo.
var _gait := 0.0
var _weights := {"move": 0.0, "run": 0.0, "crouch": 0.0, "aim": 0.0, "air": 0.0, "sniff": 0.0, "breath": 0.0, "torch": 0.0, "weapon": 0.0, "guard": 0.0}
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
## Parado: o peso que troca de perna e as manias (GoblinIdle).
var _idle := GoblinIdle.new(self)
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
## Pulo: preparo (agacha antes de sair do chão), impulso (pernas esticando logo depois de
## sair, 1 → 0) e a perna que vai à frente no salto correndo (+1 esquerda, -1 direita).
var _jump_prep := 0.0
var _prep_weight := 0.0
var _takeoff := 0.0
var _jump_lead := 1.0
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
	_idle.stop_fidget()
	_action_time = start
	_action_duration = duration
	_action_events = events.duplicate()


func is_busy() -> bool:
	return _action != &""


## O pulo foi pedido: o corpo agacha por `seconds` antes do Player soltar o impulso.
func begin_jump(seconds: float) -> void:
	_jump_prep = seconds


## Saiu do chão: as pernas terminam de esticar e, correndo, a perna de trás vira a da frente.
func jump_launched() -> void:
	_jump_prep = 0.0
	_takeoff = 1.0
	_jump_lead = 1.0 if sin(_phase) >= 0.0 else -1.0


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
	_jump_prep = maxf(_jump_prep - delta, 0.0)
	_prep_weight = move_toward(_prep_weight, 1.0 if _jump_prep > 0.0 else 0.0, delta * (14.0 if _jump_prep > 0.0 else 9.0))
	_takeoff = move_toward(_takeoff, 0.0, delta * 4.0)
	# Os joelhos levam um instante para dobrar: o corpo afunda suave, não num degrau.
	_land_eased = lerpf(_land_eased, _land, 1.0 - exp(-25.0 * delta))

	var pose := _locomotion(delta)
	pose = _idle.overlay(delta, pose)
	_cold_overlay(pose)
	_sniff_overlay(pose)
	_torch_overlay(pose)
	_weapon_overlay(pose)
	_aim_overlay(pose)
	if lying and _action == &"":
		pose = GoblinActions.pose(self, &"wake", 0.0, pose)
	if _action != &"":
		_action_time += delta
		for event: Array in _action_events.duplicate():
			if _action_time >= event[0]:
				_action_events.erase(event)
				(event[1] as Callable).call()
		var acted := GoblinActions.pose(self, _action, _action_time, pose)
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

	# Marcha pela velocidade (0 = andar, 1 = disparar). A perna tem 28 cm: acima de ~1,5 m/s
	# só dá para acompanhar o chão trotando, com um instante no ar entre os passos.
	_gait = lerpf(_gait, smoothstep(0.8, 4.6, speed), 1.0 - exp(-6.0 * delta))
	var g := _gait
	# Parte do ciclo com o pé no chão, quanto o pé anda apoiado (o alcance da perna) e cadência.
	# Correndo, a cadência tem teto (passos rápidos demais parecem filme acelerado): a
	# velocidade a mais vira tempo no ar, não mais passos.
	var stance := lerpf(0.6, 0.26, g)
	var reach := lerpf(0.32, 0.4, g) * lerpf(1.0, 1.1, crouch)
	var period := clampf(reach / maxf(speed * stance, 0.01), lerpf(0.46, 0.33, g), 1.1)
	if move > 0.01:
		_phase = fposmod(_phase + delta / period, 1.0)
	# O pé apoiado vai para trás na velocidade do chão (não patina); só passa do alcance da
	# perna quando a cadência já está no máximo.
	var travel := minf(speed * stance * period, reach * 1.2)
	# Onde o pé pousa: andando, à frente do quadril; correndo, quase embaixo dele (a perna de
	# trás é a que estica, empurrando o chão).
	var land := travel * lerpf(0.5, 0.3, g)
	var lift := lerpf(1.0, 0.55, crouch)
	var heel := lerpf(0.025, 0.045, g)
	var toe_off := lerpf(0.45, 0.75, g)
	var touch := lerpf(-0.22, 0.08, g)
	var backwards := -1.0 if velocity_local.z < -0.1 else 1.0
	for side in 2:
		var key := "l" if side == 0 else "r"
		# O pé direito sai um pouco atrasado: o ritmo fica manco, de bicho, não de metrônomo.
		var u := fposmod(_phase + side * 0.51, 1.0)
		var z: float
		var y := _ankle_height
		var toe: float
		if u < stance:
			# Apoio: pousa (calcanhar andando, meia-sola correndo), assenta e, no fim, o calcanhar
			# sobe e o tornozelo sobe junto, rolando sobre os dedos.
			var s := u / stance
			z = land - travel * s
			var roll := smoothstep(0.55, 1.0, s)
			y += roll * roll * heel
			toe = lerpf(touch, 0.0, smoothstep(0.0, 0.2, s)) + roll * toe_off
			if not _planted[side]:
				_planted[side] = true
				if move > 0.3 and on_floor:
					foot_planted.emit(side)
		else:
			# No ar: o calcanhar sobe atrás primeiro (correndo, quase até o traseiro), o joelho
			# puxa o pé para a frente por baixo do quadril, a perna estica à frente e o pé volta
			# um pouco antes de pousar, acompanhando o chão.
			var s := (u - stance) / (1.0 - stance)
			if _planted[side]:
				# O pé saiu do chão: este passo terá a sua altura e abertura.
				_step_lift[side] = randf_range(0.75, 1.2) * (0.85 if side == 1 else 1.0)
				_step_yaw[side] = randf_range(-0.12, 0.12)
			var h: float = lift * _step_lift[side]
			var back := land - travel
			var top := lerpf(0.045, 0.16, g) * h
			z = _curve(s, [[0.0, back], [0.3, back + travel * 0.2], [0.6, back + travel * 0.75], [0.85, land + travel * 0.05], [1.0, land]])
			y += _curve(s, [[0.0, heel], [0.12, lerpf(heel, top, 0.6)], [0.3, top], [0.6, lerpf(0.035, 0.11, g) * h], [0.87, lerpf(0.012, 0.045, g) * h], [1.0, 0.0]])
			toe = _curve(s, [[0.0, toe_off], [0.3, lerpf(0.55, 1.0, g)], [0.6, lerpf(0.0, 0.35, g)], [0.85, lerpf(-0.25, 0.0, g)], [1.0, touch]])
			_planted[side] = false
		pose["foot_%s_z" % key] = lerpf(pose["foot_%s_z" % key], z * backwards, move)
		pose["foot_%s_y" % key] = lerpf(_ankle_height, y, move)
		pose["foot_%s_toe" % key] = toe * move
		# Correndo, os pés apontam mais para a frente e pousam mais perto da linha do corpo.
		pose["foot_%s_yaw" % key] = pose["foot_%s_yaw" % key] * lerpf(1.0, 0.5, g * move) + _step_yaw[side] * move
		pose["leg_%s_out" % key] -= 0.03 * g * move

	# Quadril: andando, sobe no meio do apoio (a perna passa reta embaixo dele) e desce na
	# troca de pé; correndo é o contrário, afunda no apoio (o joelho amortece) e sobe no ar.
	var mid := cos(TAU * 2.0 * (_phase - stance * 0.5))
	var flight := 1.0 - smoothstep(0.38, 0.52, stance)
	pose.pelvis_y += (-lerpf(0.03, 0.06, g) + mid * lerpf(0.012, -0.03, flight)) * move
	# O peso passa para o pé de apoio: o quadril escorrega para ele e cai do outro lado.
	var sway := cos(TAU * (_phase - stance * 0.5))
	pose.pelvis_x += sway * lerpf(0.012, 0.004, g) * move
	pose.pelvis_roll = sin(TAU * (_phase - stance * 0.5)) * lerpf(0.05, 0.025, g) * move
	# A bacia gira com a perna que vai à frente e os ombros giram ao contrário.
	pose.pelvis_yaw = clampf((pose.foot_r_z - pose.foot_l_z) / maxf(travel, 0.05), -1.0, 1.0) * lerpf(0.1, 0.14, g) * move
	pose.torso_yaw += -pose.pelvis_yaw * 1.7
	# Correndo, o goblin se joga para a frente e estica o pescoço para ver adiante; a cabeça
	# segura o olhar contra o sobe-e-desce.
	pose.torso_pitch += lerpf(0.04, 0.26, g) * move
	pose.head_pitch -= lerpf(0.02, 0.22, g) * move
	pose.head_pitch += mid * 0.02 * move
	pose.spine_bend += sin(TAU * (_phase - stance * 0.5)) * 0.035 * move
	pose.spine_arch += 0.06 * run * move

	# Braços: pêndulos em oposição às pernas, um pouco atrasados. Vão mais à frente do que
	# para trás; correndo, cotovelos dobrados (mais na frente que atrás) e a mão da frente
	# cruza para o meio do corpo.
	var swing := lerpf(0.3, 0.55, g) * move
	var arm_l := cos(TAU * (_phase + 0.51 - 0.05))
	var arm_r := cos(TAU * (_phase - 0.05))
	arm_l = arm_l if arm_l > 0.0 else arm_l * 0.75
	arm_r = arm_r if arm_r > 0.0 else arm_r * 0.75
	pose.arm_l_fwd = lerpf(pose.arm_l_fwd, lerpf(0.06, 0.2, g), move) + arm_l * swing
	pose.arm_r_fwd = lerpf(pose.arm_r_fwd, lerpf(0.0, 0.15, g), move) + arm_r * swing * 0.85
	for key in ["l", "r"]:
		var forward: float = maxf(arm_l if key == "l" else arm_r, 0.0)
		pose["elbow_" + key] += (lerpf(-0.1, 0.75, g) + forward * lerpf(0.25, 0.45, g)) * move
		pose["arm_%s_out" % key] += (0.03 + 0.08 * g - forward * 0.06 * g) * move
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

	_jump_pose(pose, run)

	# Aterrissagem: o corpo afunda e volta.
	pose.pelvis_y -= _land_eased * 0.09
	pose.torso_pitch += _land_eased * 0.25
	pose.head_pitch -= _land_eased * 0.1
	# Os braços vêm à frente para segurar o peso.
	pose.arm_l_fwd += _land_eased * 0.35
	pose.arm_r_fwd += _land_eased * 0.3
	pose.arm_l_out += _land_eased * 0.15
	pose.arm_r_out += _land_eased * 0.15
	return pose


## O pulo em fases, como um bicho de verdade:
## - preparo: afunda nos joelhos, joga o peito à frente e os braços para trás;
## - impulso: as pernas terminam de esticar com a ponta dos pés, os braços vêm para a frente;
## - subida e alto: os joelhos sobem (encolhe), mais no alto do arco;
## - queda: as pernas descem à frente procurando o chão, os braços abrem para equilibrar e a
##   cabeça olha para onde vai pisar.
## Correndo, vira um salto: uma perna à frente e a outra dobrada para trás, braços cruzados.
func _jump_pose(pose: Dictionary, run: float) -> void:
	var prep: float = _prep_weight * (1.0 - _weights.air)
	if prep > 0.001:
		pose.pelvis_y -= 0.075 * prep
		pose.pelvis_pitch += 0.12 * prep
		pose.torso_pitch += 0.34 * prep
		pose.spine_arch += 0.08 * prep
		pose.head_pitch -= 0.28 * prep
		for key in ["l", "r"]:
			pose["arm_%s_fwd" % key] -= 0.55 * prep
			pose["elbow_%s" % key] += 0.15 * prep
			pose["foot_%s_z" % key] -= 0.01 * prep
		pose.ear_l -= 0.15 * prep
		pose.ear_r -= 0.15 * prep
	var air: float = _weights.air
	if air < 0.001:
		return
	# Subindo (1) .. no alto (0) .. caindo (-1): no pulo a pé, a subida dura ~0,3 s.
	var rise := clampf(vertical_speed / 2.6, -1.0, 1.0)
	var up := maxf(rise, 0.0)
	var down := maxf(-rise, 0.0)
	var apex := 1.0 - absf(rise)
	var push := _takeoff * air
	var leap := run * air
	for key in ["l", "r"]:
		var lead := (1.0 if key == "l" else -1.0) * _jump_lead
		# Impulso: perna esticada e ponta do pé estendida, um pouco para trás.
		pose["foot_%s_toe" % key] += 0.7 * push
		pose["foot_%s_z" % key] -= 0.035 * push
		# Encolhe: o pé sobe (o joelho dobra) e vem para baixo do corpo; mais no alto. No salto
		# correndo a perna da frente encolhe menos (vai esticada à frente).
		var tuck := (0.09 * up + 0.13 * apex + 0.04 * down) * air * (1.0 - push) * (1.0 - (0.6 * leap if lead > 0.0 else 0.0))
		pose["foot_%s_y" % key] += tuck
		pose["foot_%s_z" % key] += 0.03 * apex * air * (1.0 - leap)
		# Caindo: as pernas descem à frente para receber o chão, sola plana.
		pose["foot_%s_z" % key] += 0.05 * down * air * (1.0 - leap)
		pose["foot_%s_toe" % key] += 0.25 * up * air * (1.0 - push)
		# Salto correndo: a perna da frente vai à frente, a de trás fica para trás com o joelho
		# dobrado; o braço do lado da perna de trás vem à frente (braços cruzados com as pernas).
		pose["foot_%s_z" % key] += (0.12 if lead > 0.0 else -0.2) * leap
		pose["foot_%s_y" % key] += (0.0 if lead > 0.0 else 0.09) * leap
		pose["foot_%s_toe" % key] += (0.0 if lead > 0.0 else 0.5) * leap
		pose["arm_%s_fwd" % key] += (-0.45 if lead > 0.0 else 0.45) * leap
		# Braços: sobem à frente no impulso e voltam meio dobrados; abrem na queda.
		pose["arm_%s_fwd" % key] += (0.5 * push + 0.12 * up + 0.05 * apex + 0.1 * down) * air * (1.0 - leap)
		pose["arm_%s_out" % key] += (0.15 * apex + 0.5 * down) * air
		pose["elbow_%s" % key] += (0.35 * apex + 0.2 * up) * air
		pose["hand_%s" % key] -= 0.15 * down * air
	pose.torso_pitch += (0.1 * push + 0.1 * apex - 0.08 * down) * air * (1.0 - leap)
	# Correndo, o corpo vai inclinado para a frente pela bacia (o tronco sozinho dobraria o
	# quadril para trás e jogaria os pés à frente).
	pose.pelvis_pitch += 0.12 * leap
	pose.torso_pitch += 0.05 * leap
	pose.spine_arch += 0.06 * apex * air
	pose.head_pitch += (-0.12 * push + 0.18 * down) * air
	pose.neck_fwd += 0.05 * down * air
	pose.pelvis_y -= 0.02 * apex * air


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
		"torso_pitch": 0.1 - pitch * (0.35 if pitch > 0.0 else 0.8) - 0.05 * draw, "torso_yaw": -1.35 - hips - 0.05 * draw, "torso_roll": 0.03,
		"head_pitch": -pitch * (0.6 if pitch > 0.0 else 0.15), "head_yaw": 1.25 + 0.05 * draw, "head_roll": 0.06 + 0.1 * draw,
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


## Arma de mão (F11): com a faca ou o porrete, o braço direito fica dobrado à frente da barriga,
## a ponta da arma para a frente; com a lança, a mão de trás no quadril e a da frente estendida, a
## lança na diagonal. Defendendo, os antebraços sobem cruzados à frente do rosto (faca e porrete) ou,
## com a lança, o corpo afunda, o pé da frente avança e a ponta desce para a altura do peito de um bicho.
func _weapon_overlay(pose: Dictionary) -> void:
	var w: float = _weights.weapon * (1.0 - float(_weights.aim))
	if w < 0.001:
		return
	var guard: float = _weights.guard
	var sway := _wave(41, 0.9) * 0.04
	if weapon_style == &"spear":
		pose.arm_r_fwd = lerpf(pose.arm_r_fwd, lerpf(0.35, 0.25, guard) + sway, w)
		pose.arm_r_out = lerpf(pose.arm_r_out, 0.18, w)
		pose.arm_r_twist = lerpf(pose.arm_r_twist, 0.6, w)
		pose.elbow_r = lerpf(pose.elbow_r, lerpf(1.35, 1.05, guard), w)
		pose.hand_r = lerpf(pose.hand_r, 0.2, w)
		pose.arm_l_fwd = lerpf(pose.arm_l_fwd, lerpf(0.95, 0.85, guard) - sway, w)
		pose.arm_l_out = lerpf(pose.arm_l_out, -0.12, w)
		pose.arm_l_twist = lerpf(pose.arm_l_twist, -0.5, w)
		pose.elbow_l = lerpf(pose.elbow_l, lerpf(0.75, 0.35, guard), w)
		pose.hand_l = lerpf(pose.hand_l, 0.1, w)
		pose.torso_yaw -= 0.25 * w
		pose.pelvis_yaw -= 0.15 * w
		# Firmada: afunda, abre a base e joga o peso para a frente, como quem espera a investida.
		pose.pelvis_y -= 0.05 * guard * w
		pose.foot_l_z += 0.1 * guard * w
		pose.foot_r_z -= 0.08 * guard * w
		pose.torso_pitch += 0.15 * guard * w
		pose.head_pitch -= 0.1 * guard * w
		return
	pose.arm_r_fwd = lerpf(pose.arm_r_fwd, lerpf(0.45, 1.3, guard) + sway, w)
	pose.arm_r_out = lerpf(pose.arm_r_out, lerpf(0.15, 0.0, guard), w)
	pose.arm_r_yaw = lerpf(pose.arm_r_yaw, lerpf(0.0, -0.45, guard), w)
	pose.arm_r_twist = lerpf(pose.arm_r_twist, lerpf(0.2, 0.9, guard), w)
	pose.elbow_r = lerpf(pose.elbow_r, lerpf(1.1, 1.0, guard), w)
	pose.hand_r = lerpf(pose.hand_r, 0.35, w)
	# A outra mão: solta e meio aberta, à frente para equilibrar; defendendo, sobe e cruza.
	pose.arm_l_fwd = lerpf(pose.arm_l_fwd, lerpf(0.3, 1.15, guard), w)
	pose.arm_l_yaw = lerpf(pose.arm_l_yaw, lerpf(0.0, 0.3, guard), w)
	pose.arm_l_twist = lerpf(pose.arm_l_twist, lerpf(0.0, -0.8, guard), w)
	pose.elbow_l = lerpf(pose.elbow_l, lerpf(0.7, 1.8, guard), w)
	pose.pelvis_y -= 0.03 * guard * w
	pose.torso_pitch += 0.12 * guard * w
	pose.spine_arch += 0.06 * guard * w
	pose.head_pitch += 0.12 * guard * w
	pose.ear_l -= 0.25 * guard * w
	pose.ear_r -= 0.25 * guard * w


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


## Valor suave numa lista de chaves [[tempo, valor], ...]: cúbica monotônica (Fritsch-Carlson).
## O movimento passa pelas chaves do meio sem parar (velocidade contínua), só desacelera
## onde muda de sentido ou fica parado, e nunca passa do valor das chaves vizinhas.
static func _curve(t: float, keys: Array) -> float:
	if t <= keys[0][0]:
		return keys[0][1]
	var last := keys.size() - 1
	for i in last:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t > b[0]:
			continue
		var h: float = b[0] - a[0]
		if h <= 0.0:
			return b[1]
		var m0 := _curve_tangent(keys, i)
		var m1 := _curve_tangent(keys, i + 1)
		var s: float = (t - a[0]) / h
		var s2 := s * s
		var s3 := s2 * s
		return (2.0 * s3 - 3.0 * s2 + 1.0) * a[1] + (s3 - 2.0 * s2 + s) * h * m0 \
			+ (-2.0 * s3 + 3.0 * s2) * b[1] + (s3 - s2) * h * m1
	return keys[last][1]


## Inclinação da curva na chave `i`: zero nas pontas e onde o valor muda de sentido.
static func _curve_tangent(keys: Array, i: int) -> float:
	if i <= 0 or i >= keys.size() - 1:
		return 0.0
	var h0: float = keys[i][0] - keys[i - 1][0]
	var h1: float = keys[i + 1][0] - keys[i][0]
	if h0 <= 0.0 or h1 <= 0.0:
		return 0.0
	var d0: float = (keys[i][1] - keys[i - 1][1]) / h0
	var d1: float = (keys[i + 1][1] - keys[i][1]) / h1
	if d0 * d1 <= 0.0:
		return 0.0
	return 3.0 * (h0 + h1) / ((2.0 * h1 + h0) / d0 + (h1 + 2.0 * h0) / d1)


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
	_approach("weapon", 1.0 if weapon_style != &"" else 0.0, 8.0, delta)
	_approach("guard", 1.0 if guarding and weapon_style != &"" else 0.0, 14.0, delta)


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


## Posição global da junta de um osso qualquer (o orc mede a zona do golpe pela cabeça).
func bone_position(bone_name: String) -> Vector3:
	var index := skeleton.find_bone(bone_name)
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin if index != -1 else skeleton.global_position


## Posição global do punho (osso da mão), já com a pose deste frame.
func hand_position(left: bool) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones["mao_E" if left else "mao_D"]).origin


## Posição global de onde a mão direita segura a arma, já com a pose deste frame.
func weapon_grip_position() -> Vector3:
	return skeleton.global_transform * (skeleton.get_bone_global_pose(_bones.mao_D) * weapon_grip)


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
