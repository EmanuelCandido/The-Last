class_name GoblinActions
extends RefCounted
## As poses das ações cronometradas do goblin (tiradas do GoblinAnimator na F10): acordar,
## pegar, coletar, golpe, comer, assar, deitar, fabricar, riscar... Cada ação parte da pose
## base do frame e mexe o corpo todo, com preparação e continuação. `t` é o tempo dentro da
## ação; a duração e o sorteio da ação vêm do animador (`a`).


static func pose(a: GoblinAnimator, action: StringName, t: float, base: Dictionary) -> Dictionary:
	var p := base.duplicate()
	match action:
		&"punch":
			# Arma (quadril e ombro direito para trás, peso no pé de trás, costas fechadas),
			# solta (o quadril vira primeiro, o ombro vem atrás e leva o braço; o corpo vai para
			# a frente sobre o pé que pisa) e continua um pouco além antes de voltar. A cabeça
			# segura o olhar no alvo enquanto o corpo gira.
			var force := 1.0 + 0.2 * a._action_var
			p.pelvis_yaw = GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, -0.18], [0.24, 0.22 * force], [0.31, 0.26 * force], [0.5, 0.0]])
			p.torso_yaw = base.torso_yaw + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, -0.35 * force], [0.24, 0.45 * force], [0.31, 0.55 * force], [0.5, 0.0]])
			p.pelvis_z = base.pelvis_z + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, -0.02], [0.24, 0.04], [0.34, 0.035], [0.5, 0.0]])
			p.pelvis_y = base.pelvis_y + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, -0.02], [0.24, -0.035], [0.34, -0.03], [0.5, 0.0]])
			p.torso_pitch = base.torso_pitch + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, 0.04], [0.24, 0.2], [0.31, 0.24], [0.5, 0.0]])
			p.spine_arch = base.spine_arch + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, 0.1], [0.24, -0.06], [0.34, 0.0], [0.5, 0.0]])
			p.spine_bend = base.spine_bend + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, -0.06], [0.24, 0.05], [0.5, 0.0]])
			p.torso_roll = base.torso_roll + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, 0.05], [0.24, -0.06], [0.5, 0.0]])
			p.arm_r_fwd = GoblinAnimator._curve(t, [[0.0, base.arm_r_fwd], [0.13, -0.5 * force], [0.24, 1.65], [0.31, 1.55], [0.5, base.arm_r_fwd]])
			p.elbow_r = GoblinAnimator._curve(t, [[0.0, base.elbow_r], [0.13, 1.8], [0.24, 0.1], [0.31, 0.2], [0.5, base.elbow_r]])
			p.arm_r_out = GoblinAnimator._curve(t, [[0.0, 0.06], [0.13, 0.3], [0.24, -0.12], [0.5, 0.06]])
			# A outra mão vem à frente para guardar e volta para trás no golpe.
			p.arm_l_fwd = GoblinAnimator._curve(t, [[0.0, base.arm_l_fwd], [0.13, 0.6], [0.24, -0.3], [0.34, -0.25], [0.5, base.arm_l_fwd]])
			p.elbow_l = GoblinAnimator._curve(t, [[0.0, base.elbow_l], [0.13, 1.3], [0.24, 1.1], [0.5, base.elbow_l]])
			p.foot_l_z = base.foot_l_z + GoblinAnimator._curve(t, [[0.0, 0.0], [0.2, 0.12], [0.4, 0.12], [0.5, 0.0]])
			# O pé de trás gira na ponta quando o quadril vira.
			p.foot_r_toe = base.foot_r_toe + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, 0.3], [0.4, 0.2], [0.5, 0.0]])
			p.head_yaw = base.head_yaw - (p.pelvis_yaw + p.torso_yaw - base.torso_yaw) * 0.8
			p.head_pitch = base.head_pitch + GoblinAnimator._curve(t, [[0.0, 0.0], [0.13, -0.05], [0.24, 0.08], [0.5, 0.0]])
			p.head_roll = base.head_roll + GoblinAnimator._curve(t, [[0.0, 0.0], [0.2, 0.1 * a._action_var], [0.5, 0.0]])
			p.ear_l = base.ear_l + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, 0.3], [0.5, 0.0]])
			p.ear_r = base.ear_r + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, 0.3], [0.5, 0.0]])
		&"pickup":
			# Olha primeiro, desce dobrando quadril e joelhos com as costas curvadas, o ombro
			# da mão que pega cai e vai à frente; pega, e sobe com a cabeça e o peito na frente,
			# esticando as costas um pouco além do normal antes de assentar.
			p.pelvis_y = GoblinAnimator._curve(t, [[0.0, base.pelvis_y], [0.12, base.pelvis_y + 0.005], [0.42, 0.2], [0.6, 0.2], [0.95, base.pelvis_y + 0.008], [1.1, base.pelvis_y]])
			p.pelvis_x = base.pelvis_x + GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, -0.015], [0.8, 0.0]])
			p.foot_l_z = GoblinAnimator._curve(t, [[0.0, base.foot_l_z], [0.3, 0.12], [0.8, 0.12], [1.1, 0.0]])
			p.foot_r_z = GoblinAnimator._curve(t, [[0.0, base.foot_r_z], [0.3, -0.08], [0.8, -0.08], [1.1, 0.0]])
			p.torso_pitch = GoblinAnimator._curve(t, [[0.0, base.torso_pitch], [0.12, base.torso_pitch + 0.03], [0.42, 0.85], [0.6, 0.8], [0.9, base.torso_pitch - 0.06], [1.1, base.torso_pitch]])
			p.spine_arch = GoblinAnimator._curve(t, [[0.0, base.spine_arch], [0.42, 0.33], [0.6, 0.3], [0.9, -0.06], [1.1, base.spine_arch]])
			p.neck_fwd = GoblinAnimator._curve(t, [[0.0, base.neck_fwd], [0.42, 0.2], [0.65, 0.2], [1.1, base.neck_fwd]])
			p.head_pitch = GoblinAnimator._curve(t, [[0.0, base.head_pitch], [0.12, 0.25], [0.42, 0.2], [0.6, 0.15], [0.8, -0.15], [1.1, base.head_pitch]])
			p.head_yaw = GoblinAnimator._curve(t, [[0.0, base.head_yaw], [0.4, 0.15 * a._action_var], [1.1, base.head_yaw]])
			p.torso_roll = base.torso_roll + GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, 0.1], [0.6, 0.08], [0.9, -0.02], [1.1, 0.0]])
			p.torso_yaw = base.torso_yaw + GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, 0.12], [0.6, 0.1], [1.1, 0.0]])
			p.arm_r_fwd = GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, 0.8], [0.52, 0.85], [0.75, 0.6], [0.9, 0.45], [1.1, 0.0]])
			p.elbow_r = GoblinAnimator._curve(t, [[0.0, 0.15], [0.42, 0.2], [0.52, 0.5], [0.75, 1.1], [0.9, 0.9], [1.1, 0.15]])
			p.hand_r = GoblinAnimator._curve(t, [[0.0, base.hand_r], [0.45, -0.2], [0.52, 0.6], [1.1, base.hand_r]])
			# A outra mão desce até perto do joelho, como apoio.
			p.arm_l_fwd = GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, 0.4], [0.7, 0.3], [1.1, 0.0]])
			p.elbow_l = GoblinAnimator._curve(t, [[0.0, 0.15], [0.42, 0.7], [1.1, 0.15]])
			p.ear_l = base.ear_l + GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, 0.25], [0.7, 0.2], [1.1, 0.0]])
			p.ear_r = base.ear_r + GoblinAnimator._curve(t, [[0.0, 0.0], [0.42, 0.2], [0.7, 0.15], [1.1, 0.0]])
		&"harvest":
			# Ajoelhado e curvado sobre a caça: cada puxada da faca balança o tronco e o
			# quadril. Para no meio, ergue o peito e a cabeça e escuta (orelhas em pé), depois
			# volta; no fim levanta esticando as costas.
			var listen := smoothstep(1.1, 1.25, t) * (1.0 - smoothstep(1.45, 1.6, t))
			var work := smoothstep(0.6, 0.8, t) * (1.0 - smoothstep(1.8, 2.0, t)) * (1.0 - listen)
			var stroke := sin(t * 14.0)
			p.pelvis_y = GoblinAnimator._curve(t, [[0.0, base.pelvis_y], [0.5, 0.17], [2.0, 0.17], [2.4, base.pelvis_y]])
			p.pelvis_x = base.pelvis_x + stroke * 0.006 * work
			p.foot_l_z = GoblinAnimator._curve(t, [[0.0, 0.0], [0.4, 0.15], [2.0, 0.15], [2.4, 0.0]])
			p.foot_r_z = GoblinAnimator._curve(t, [[0.0, 0.0], [0.4, -0.12], [2.0, -0.12], [2.4, 0.0]])
			p.torso_pitch = GoblinAnimator._curve(t, [[0.0, base.torso_pitch], [0.5, 0.85], [2.0, 0.85], [2.25, base.torso_pitch - 0.05], [2.4, base.torso_pitch]]) - 0.45 * listen
			p.spine_arch = GoblinAnimator._curve(t, [[0.0, base.spine_arch], [0.5, 0.35], [2.0, 0.35], [2.25, -0.05], [2.4, base.spine_arch]]) - 0.3 * listen
			p.neck_fwd = GoblinAnimator._curve(t, [[0.0, base.neck_fwd], [0.5, 0.2], [2.0, 0.2], [2.4, base.neck_fwd]]) - 0.1 * listen
			p.torso_yaw = base.torso_yaw + stroke * 0.08 * work
			p.torso_roll = base.torso_roll + sin(t * 14.0 + 0.7) * 0.05 * work
			p.spine_bend = base.spine_bend + cos(t * 14.0) * 0.03 * work
			p.head_pitch = GoblinAnimator._curve(t, [[0.0, base.head_pitch], [0.5, 0.4], [2.0, 0.4], [2.4, base.head_pitch]]) - 0.25 * listen
			p.head_yaw = (0.25 + 0.2 * a._action_var) * listen - stroke * 0.05 * work
			p.ear_l = base.ear_l - 0.3 * listen
			p.ear_r = base.ear_r - 0.3 * listen
			p.arm_r_fwd = GoblinAnimator._curve(t, [[0.0, 0.0], [0.5, 0.9], [2.0, 0.9], [2.4, 0.0]]) + stroke * 0.25 * work
			p.arm_l_fwd = GoblinAnimator._curve(t, [[0.0, 0.0], [0.5, 0.8], [2.0, 0.8], [2.4, 0.0]]) - stroke * 0.15 * work
			p.elbow_r = GoblinAnimator._curve(t, [[0.0, 0.15], [0.5, 0.7], [2.0, 0.7], [2.4, 0.15]])
			p.elbow_l = GoblinAnimator._curve(t, [[0.0, 0.15], [0.5, 0.5], [2.0, 0.5], [2.4, 0.15]])
		&"wake":
			# Deitado de costas, mas vivo (respira, vira a cabeça, a mão e as orelhas mexem) ->
			# puxa os joelhos -> rola um pouco para o lado e senta empurrando o chão com os
			# braços -> sentado, esfrega os olhos -> joga o peso para a frente com as mãos no
			# chão -> agacha sobre os pés -> levanta espreguiçando e assenta. O `_curve` passa
			# pelas chaves sem parar, então o corpo nunca congela entre uma e outra.
			# Até 2,6 s o corpo fica no lugar: levantar do sarcófago começa dali.
			var flat := 1.0 - smoothstep(2.9, 3.6, t)
			var breath := sin(t * 1.7)
			p.pelvis_pitch = GoblinAnimator._curve(t, [[0.0, -1.5], [3.0, -1.48], [3.35, -0.75], [3.7, -0.32], [4.5, -0.28], [4.8, 0.05], [5.05, 0.42], [5.4, 0.08], [5.8, base.pelvis_pitch]])
			p.pelvis_y = GoblinAnimator._curve(t, [[0.0, 0.09], [3.0, 0.09], [3.7, 0.1], [4.5, 0.1], [4.8, 0.13], [5.05, 0.19], [5.4, base.pelvis_y + 0.008], [5.8, base.pelvis_y]])
			# O quadril vai para a frente, por cima dos pés, ao sair do chão.
			p.pelvis_z = GoblinAnimator._curve(t, [[0.0, -0.08], [3.0, -0.08], [3.7, -0.1], [4.5, -0.1], [4.8, -0.05], [5.05, 0.0], [5.8, base.pelvis_z]])
			p.torso_roll = GoblinAnimator._curve(t, [[0.0, 0.0], [3.0, 0.0], [3.2, -0.14], [3.6, -0.04], [5.8, base.torso_roll]])
			p.torso_yaw = GoblinAnimator._curve(t, [[0.0, 0.0], [3.0, 0.0], [3.2, 0.16], [3.7, 0.02], [5.8, base.torso_yaw]])
			# Pernas: um joelho mexe dormindo; depois os dois sobem (pé esquerdo primeiro) e, de
			# pé, o direito dá um passinho para firmar.
			p.foot_l_z = GoblinAnimator._curve(t, [[0.0, 0.19], [2.6, 0.19], [3.0, 0.06], [4.6, 0.06], [5.05, 0.05], [5.8, base.foot_l_z]])
			p.foot_r_z = GoblinAnimator._curve(t, [[0.0, 0.18], [1.6, 0.18], [1.9, 0.15], [2.3, 0.18], [2.75, 0.18], [3.15, 0.08], [4.6, 0.08], [5.05, 0.06], [5.3, 0.02], [5.8, base.foot_r_z]])
			p.foot_l_y = a._ankle_height
			p.foot_r_y = a._ankle_height + GoblinAnimator._curve(t, [[0.0, 0.01], [3.0, 0.01], [3.2, 0.0], [5.1, 0.0], [5.22, 0.03], [5.35, 0.0]])
			p.foot_flat = GoblinAnimator._curve(t, [[0.0, 0.0], [2.6, 0.0], [3.05, 1.0]])
			p.leg_l_out = GoblinAnimator._curve(t, [[0.0, base.leg_l_out], [3.0, base.leg_l_out], [3.5, 0.16], [4.6, 0.16], [5.1, 0.1], [5.8, base.leg_l_out]])
			p.leg_r_out = GoblinAnimator._curve(t, [[0.0, base.leg_r_out], [3.0, base.leg_r_out], [3.5, 0.15], [4.6, 0.15], [5.1, 0.09], [5.8, base.leg_r_out]])
			# Tronco: enrola para sentar (passa um pouco e volta), fica corcunda esfregando os
			# olhos, dobra sobre os joelhos para sair do chão e, de pé, espreguiça para trás.
			p.torso_pitch = GoblinAnimator._curve(t, [[0.0, 0.0], [3.0, 0.0], [3.35, 0.32], [3.7, 0.5], [3.95, 0.38], [4.5, 0.4], [4.8, 0.85], [5.05, 0.6], [5.4, 0.05], [5.8, base.torso_pitch]]) + breath * 0.04 * flat
			p.spine_arch = GoblinAnimator._curve(t, [[0.0, 0.0], [3.0, 0.05], [3.35, 0.45], [3.7, 0.32], [4.5, 0.36], [4.8, 0.3], [5.05, 0.25], [5.35, -0.16], [5.8, base.spine_arch]]) - breath * 0.03 * flat
			p.neck_fwd = GoblinAnimator._curve(t, [[0.0, 0.0], [3.0, 0.05], [3.35, 0.22], [4.5, 0.22], [5.05, 0.12], [5.35, -0.06], [5.8, base.neck_fwd]])
			p.head_pitch = GoblinAnimator._curve(t, [[0.0, -0.15], [1.1, -0.05], [2.0, -0.18], [3.0, 0.2], [3.4, 0.3], [3.9, 0.4], [4.4, 0.35], [4.8, -0.15], [5.1, 0.0], [5.35, -0.28], [5.8, base.head_pitch]])
			p.head_yaw = GoblinAnimator._curve(t, [[0.0, 0.35], [0.9, 0.35], [1.5, -0.1], [2.3, 0.15], [3.0, 0.0], [4.4, 0.0], [5.0, -0.1], [5.45, 0.3], [5.8, base.head_yaw]])
			p.head_roll = GoblinAnimator._curve(t, [[0.0, 0.2], [1.5, -0.1], [2.6, 0.1], [3.4, 0.05], [5.8, base.head_roll]])
			# Braço esquerdo: empurra o chão atrás para sentar, apoia no joelho, vai ao chão à
			# frente para levantar e abre na espreguiçada.
			p.arm_l_fwd = GoblinAnimator._curve(t, [[0.0, 0.05], [2.6, 0.05], [3.0, -0.45], [3.3, -0.75], [3.7, -0.55], [3.95, 0.35], [4.5, 0.4], [4.8, 0.95], [5.05, 0.7], [5.35, 0.3], [5.8, base.arm_l_fwd]])
			p.elbow_l = GoblinAnimator._curve(t, [[0.0, 0.2], [2.6, 0.25], [3.0, 1.1], [3.3, 0.35], [3.7, 0.15], [3.95, 0.6], [4.5, 0.6], [4.8, 0.15], [5.05, 0.3], [5.35, 0.7], [5.8, base.elbow_l]])
			p.arm_l_out = GoblinAnimator._curve(t, [[0.0, 0.15], [4.9, 0.12], [5.35, 0.45], [5.8, base.arm_l_out]])
			p.hand_l = GoblinAnimator._curve(t, [[0.0, base.hand_l], [3.0, 0.2], [3.3, -0.6], [3.7, -0.4], [3.95, 0.4], [4.5, 0.4], [4.8, -0.5], [5.05, -0.3], [5.5, base.hand_l]])
			# Braço direito: a mão estremece dormindo, empurra o chão, sobe aos olhos e esfrega
			# (cotovelo dobrado na horizontal), vai ao chão à frente e abre na espreguiçada.
			p.arm_r_fwd = GoblinAnimator._curve(t, [[0.0, 0.05], [1.1, 0.05], [1.4, 0.3], [1.9, 0.08], [2.75, 0.05], [3.1, -0.5], [3.35, -0.7], [3.65, -0.35], [3.9, 1.65], [4.35, 1.65], [4.55, 0.6], [4.8, 0.9], [5.05, 0.65], [5.35, 0.3], [5.8, base.arm_r_fwd]])
			p.elbow_r = GoblinAnimator._curve(t, [[0.0, 0.2], [2.75, 0.25], [3.1, 1.0], [3.35, 0.35], [3.65, 0.4], [3.9, 2.4], [4.35, 2.4], [4.55, 0.6], [4.8, 0.15], [5.05, 0.3], [5.35, 0.7], [5.8, base.elbow_r]])
			p.arm_r_out = GoblinAnimator._curve(t, [[0.0, 0.1], [4.9, 0.1], [5.35, 0.4], [5.8, base.arm_r_out]])
			p.hand_r = GoblinAnimator._curve(t, [[0.0, base.hand_r], [3.1, 0.2], [3.35, -0.6], [3.65, -0.3], [3.9, 0.3], [4.35, 0.3], [4.8, -0.5], [5.05, -0.3], [5.5, base.hand_r]])
			var to_face := smoothstep(3.6, 3.9, t) * (1.0 - smoothstep(4.35, 4.6, t))
			var rubbing := smoothstep(3.85, 3.95, t) * (1.0 - smoothstep(4.25, 4.35, t))
			p.arm_r_twist = 1.5 * to_face
			p.arm_r_yaw = (0.35 + sin(t * 18.0) * 0.12 * rubbing) * to_face
			p.ear_l = GoblinAnimator._curve(t, [[0.0, 0.5], [0.8, 0.3], [1.3, 0.55], [2.6, 0.45], [3.4, 0.15], [4.4, 0.2], [5.0, 0.05], [5.35, -0.15], [5.8, base.ear_l]])
			p.ear_r = GoblinAnimator._curve(t, [[0.0, 0.45], [1.0, 0.55], [1.6, 0.3], [2.6, 0.45], [3.4, 0.1], [4.4, 0.25], [5.0, 0.1], [5.35, -0.1], [5.8, base.ear_r]])
		&"eat":
			# A outra mão segura o pedaço perto do peito; a direita leva à boca duas vezes,
			# a cabeça desce ao encontro e mastiga, com as costas curvadas sobre a comida.
			var bite := GoblinAnimator._curve(t, [[0.0, 0.0], [0.35, 1.0], [0.55, 0.75], [0.8, 1.0], [1.3, 0.85], [1.6, 0.0]])
			var chew := smoothstep(0.85, 0.95, t) * (1.0 - smoothstep(1.35, 1.5, t))
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 0.62, bite)
			p.arm_r_out = lerpf(base.arm_r_out, 0.0, bite)
			p.arm_r_twist = 0.85 * bite
			p.arm_r_yaw = 0.1 * bite
			p.elbow_r = lerpf(base.elbow_r, 1.75, bite)
			p.hand_r = lerpf(base.hand_r, 0.6, bite)
			var hold := GoblinAnimator._curve(t, [[0.0, 0.0], [0.3, 1.0], [1.35, 1.0], [1.6, 0.0]])
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 0.4, hold)
			p.elbow_l = lerpf(base.elbow_l, 1.05, hold)
			p.hand_l = lerpf(base.hand_l, 0.55, hold)
			p.torso_pitch = base.torso_pitch + 0.1 * hold
			p.spine_arch = base.spine_arch + 0.1 * hold
			p.neck_fwd = base.neck_fwd + 0.08 * bite
			p.head_pitch = base.head_pitch + 0.32 * bite + sin(t * 19.0) * 0.035 * chew
			p.head_roll = base.head_roll + 0.06 * a._action_var * bite
			p.ear_l = base.ear_l + 0.12 * bite + sin(t * 19.0) * 0.04 * chew
			p.ear_r = base.ear_r + 0.1 * bite + sin(t * 19.0 + 0.6) * 0.04 * chew
		&"cook":
			# Acocorado na frente do fogo, com a carne espetada na mão direita: vira o pedaço
			# de tempos em tempos, a cabeça acompanha e no meio para e escuta a floresta.
			var crouch := GoblinAnimator._curve(t, [[0.0, 0.0], [0.6, 1.0], [5.5, 1.0], [6.0, 0.0]])
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
			p.head_yaw = base.head_yaw + 0.06 * turning + (0.35 + 0.2 * a._action_var) * listen
			p.ear_l = base.ear_l - 0.3 * listen
			p.ear_r = base.ear_r - 0.3 * listen
		&"throw":
			# Arremesso por cima: o braço vai para trás do ombro com o cotovelo dobrado, o quadril
			# e o peito giram para trás e o outro braço aponta o alvo; solta com o quadril na
			# frente, o braço chicoteia e o corpo cai sobre o pé da frente.
			var force := 1.0 + 0.15 * a._action_var
			p.pelvis_yaw = GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, -0.25], [0.34, 0.2 * force], [0.45, 0.22], [0.7, 0.0]])
			p.torso_yaw = base.torso_yaw + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, -0.5], [0.34, 0.45 * force], [0.45, 0.5], [0.7, 0.0]])
			p.torso_pitch = base.torso_pitch + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, -0.12], [0.34, 0.25], [0.45, 0.3], [0.7, 0.0]])
			p.spine_arch = base.spine_arch + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, -0.12], [0.34, 0.1], [0.7, 0.0]])
			p.pelvis_y = base.pelvis_y + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, -0.02], [0.34, -0.035], [0.7, 0.0]])
			p.arm_r_fwd = GoblinAnimator._curve(t, [[0.0, base.arm_r_fwd], [0.24, 2.6], [0.32, 1.9], [0.38, 1.1], [0.5, 0.6], [0.7, base.arm_r_fwd]])
			p.arm_r_yaw = GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, 0.35], [0.36, 0.0], [0.7, 0.0]])
			p.elbow_r = GoblinAnimator._curve(t, [[0.0, base.elbow_r], [0.24, 2.0], [0.32, 1.0], [0.38, 0.15], [0.5, 0.3], [0.7, base.elbow_r]])
			p.hand_r = GoblinAnimator._curve(t, [[0.0, base.hand_r], [0.24, 0.6], [0.34, -0.3], [0.7, base.hand_r]])
			p.arm_l_fwd = GoblinAnimator._curve(t, [[0.0, base.arm_l_fwd], [0.24, 1.2], [0.34, 0.3], [0.45, -0.2], [0.7, base.arm_l_fwd]])
			p.elbow_l = GoblinAnimator._curve(t, [[0.0, base.elbow_l], [0.24, 0.3], [0.45, 1.0], [0.7, base.elbow_l]])
			p.foot_l_z = base.foot_l_z + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, 0.06], [0.36, 0.14], [0.55, 0.12], [0.7, 0.0]])
			p.foot_r_toe = base.foot_r_toe + GoblinAnimator._curve(t, [[0.0, 0.0], [0.34, 0.3], [0.55, 0.15], [0.7, 0.0]])
			p.head_yaw = base.head_yaw - (p.pelvis_yaw + p.torso_yaw - base.torso_yaw) * 0.85
			p.head_pitch = base.head_pitch + GoblinAnimator._curve(t, [[0.0, 0.0], [0.24, -0.15], [0.4, 0.05], [0.7, 0.0]])
			p.ear_l = base.ear_l + GoblinAnimator._curve(t, [[0.0, 0.0], [0.34, 0.3], [0.7, 0.0]])
			p.ear_r = base.ear_r + GoblinAnimator._curve(t, [[0.0, 0.0], [0.34, 0.3], [0.7, 0.0]])
		&"craft":
			# Acocorado, as duas mãos trabalham juntas na frente da barriga: a direita puxa e
			# torce (raspa, amarra), a esquerda segura; a cabeça baixa olha o trabalho e, no
			# meio, ergue um pouco e escuta.
			var low := GoblinAnimator._curve(t, [[0.0, 0.0], [0.35, 1.0], [a._action_duration - 0.3, 1.0], [a._action_duration, 0.0]])
			var work := smoothstep(0.35, 0.5, t) * (1.0 - smoothstep(a._action_duration - 0.45, a._action_duration - 0.3, t))
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
			p.head_yaw = base.head_yaw + (0.3 + 0.15 * a._action_var) * listen
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
			var raise := GoblinAnimator._curve(t, [[0.0, 0.0], [0.5, 1.0], [a._action_duration - 0.5, 1.0], [a._action_duration, 0.0]])
			var work := smoothstep(0.5, 0.7, t) * (1.0 - smoothstep(a._action_duration - 0.7, a._action_duration - 0.5, t))
			# Um traço a cada 0,6 s: desce (ou atravessa) depressa e volta devagar, sem raspar.
			var phase := fmod(t, 0.6) / 0.6
			var drag := smoothstep(0.0, 0.35, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
			var across := 1.0 if int(t / 0.6) % 3 == 1 else 0.0
			var peek := smoothstep(0.8, 1.0, sin(t * 0.9) * 0.5 + 0.5)
			p.torso_pitch = base.torso_pitch + 0.15 * raise + 0.05 * peek
			p.spine_arch = base.spine_arch + 0.08 * raise
			p.neck_fwd = base.neck_fwd + 0.12 * raise + 0.08 * peek
			p.head_pitch = base.head_pitch + 0.1 * raise + 0.1 * drag * work
			p.head_roll = base.head_roll + 0.12 * raise * a._action_var
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
			var low := GoblinAnimator._curve(t, [[0.0, 0.0], [0.4, 1.0], [2.6, 1.0], [3.0, 0.0]])
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
		&"knife_1", &"club_1":
			p = _slash(a, t, base, 1.0, 1.0 if action == &"knife_1" else 1.15)
		&"knife_2", &"club_2":
			p = _slash(a, t, base, -1.0, 1.0 if action == &"knife_2" else 1.15)
		&"knife_heavy", &"club_heavy":
			p = _overhead(a, t, base)
		&"spear_1", &"spear_2":
			p = _thrust(a, t, base, 1.0)
		&"spear_heavy":
			p = _thrust(a, t, base, 1.35)
		&"dodge":
			# Pulo curto e baixo para o lado: afunda, sai do chão quase sem subir e cai abaixado,
			# os braços abertos para equilibrar e as orelhas para trás.
			var d := a._action_duration
			p.pelvis_y = base.pelvis_y + GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.15, -0.06], [d * 0.45, 0.015], [d * 0.75, -0.045], [d, 0.0]])
			p.torso_pitch = base.torso_pitch + GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.15, 0.25], [d * 0.5, 0.1], [d * 0.8, 0.3], [d, 0.0]])
			p.spine_arch = base.spine_arch + GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.3, 0.12], [d, 0.0]])
			p.arm_l_out = GoblinAnimator._curve(t, [[0.0, base.arm_l_out], [d * 0.35, 0.65], [d * 0.8, 0.4], [d, base.arm_l_out]])
			p.arm_r_out = GoblinAnimator._curve(t, [[0.0, base.arm_r_out], [d * 0.35, 0.55], [d * 0.8, 0.35], [d, base.arm_r_out]])
			p.elbow_l = GoblinAnimator._curve(t, [[0.0, base.elbow_l], [d * 0.35, 0.5], [d, base.elbow_l]])
			p.foot_l_z = base.foot_l_z + GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.4, 0.08], [d * 0.75, 0.04], [d, 0.0]])
			p.foot_r_z = base.foot_r_z + GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.4, -0.06], [d * 0.75, -0.04], [d, 0.0]])
			p.head_pitch = base.head_pitch + GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.3, -0.12], [d, 0.0]])
			p.ear_l = base.ear_l - 0.4 * sin(PI * clampf(t / d, 0.0, 1.0))
			p.ear_r = base.ear_r - 0.4 * sin(PI * clampf(t / d, 0.0, 1.0))
		&"stagger":
			# Levou o golpe: o tronco vai para trás, a cabeça tomba, os braços sobem para se proteger
			# e um pé recua para não cair.
			var d := a._action_duration
			var hit := GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.18, 1.0], [d * 0.55, 0.6], [d, 0.0]])
			p.torso_pitch = base.torso_pitch - 0.3 * hit
			p.spine_arch = base.spine_arch - 0.12 * hit
			p.torso_roll = base.torso_roll + 0.12 * hit * a._action_var
			p.pelvis_z = base.pelvis_z - 0.04 * hit
			p.head_pitch = base.head_pitch - 0.35 * hit
			p.head_roll = base.head_roll + 0.2 * hit * a._action_var
			p.arm_l_fwd = lerpf(base.arm_l_fwd, 0.95, hit)
			p.arm_r_fwd = lerpf(base.arm_r_fwd, 0.85, hit)
			p.elbow_l = lerpf(base.elbow_l, 1.6, hit)
			p.elbow_r = lerpf(base.elbow_r, 1.5, hit)
			p.foot_r_z = base.foot_r_z - 0.09 * hit
			p.ear_l = base.ear_l - 0.5 * hit
			p.ear_r = base.ear_r - 0.5 * hit
		&"knockdown":
			# Derrubado: cai sentado (o começo é a queda até a pose de sentado do `wake`) e levanta
			# depressa pelo resto do `wake`, empurrando o chão.
			var fall := Tuning.KNOCKDOWN_FALL
			if t < fall:
				var sat := pose(a, &"wake", 3.45, base)
				var w := smoothstep(0.0, fall, t)
				for key: String in p:
					p[key] = lerpf(float(base[key]), float(sat[key]), w)
			else:
				var up := (t - fall) / maxf(a._action_duration - fall, 0.01)
				p = pose(a, &"wake", lerpf(3.45, 5.8, up), base)
		&"equip":
			# A mão vai ao quadril e às costas, pega (ou guarda) a arma e volta para a frente.
			var d := a._action_duration
			var reach := GoblinAnimator._curve(t, [[0.0, 0.0], [d * 0.45, 1.0], [d, 0.0]])
			p.arm_r_fwd = lerpf(base.arm_r_fwd, -0.55, reach)
			p.arm_r_out = lerpf(base.arm_r_out, 0.35, reach)
			p.elbow_r = lerpf(base.elbow_r, 1.4, reach)
			p.arm_r_twist = lerpf(base.arm_r_twist, -0.4, reach)
			p.torso_yaw = base.torso_yaw + 0.25 * reach
			p.torso_roll = base.torso_roll - 0.08 * reach
			p.head_yaw = base.head_yaw - 0.35 * reach
			p.head_pitch = base.head_pitch + 0.15 * reach
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


# --- Luta (F11) ------------------------------------------------------------------
# Os golpes se medem pela janela do golpe (`a.strike_window`): até o começo dela o corpo arma, no
# meio dela a arma passa pelo alvo, no fim termina o arco, e depois volta para a pose base. Cada
# chave é [base, armado, meio do golpe, fim do golpe, voltando, base].

static func _phase(a: GoblinAnimator, t: float, values: Array) -> float:
	var s := a.strike_window.x
	var e := a.strike_window.y
	var d := maxf(a._action_duration, e + 0.05)
	return GoblinAnimator._curve(t, [[0.0, values[0]], [s, values[1]], [(s + e) * 0.5, values[2]], [e, values[3]],
		[e + (d - e) * 0.45, values[4]], [d, values[5]]])


## Corte de lado (faca, porrete): `side` 1 = de fora para dentro, da direita para a esquerda, com
## o quadril e o ombro girando atrás do braço; -1 = o revés, do ombro esquerdo para fora. `size`
## abre o arco (o porrete é mais largo e mais pesado).
static func _slash(a: GoblinAnimator, t: float, base: Dictionary, side: float, size: float) -> Dictionary:
	var p := base.duplicate()
	var force := 1.0 + 0.15 * a._action_var
	if side > 0.0:
		p.arm_r_fwd = _phase(a, t, [base.arm_r_fwd, 1.9 * size, 1.5, 1.05, 0.8, base.arm_r_fwd])
		p.arm_r_yaw = _phase(a, t, [base.arm_r_yaw, 0.9 * size, 0.1, -0.6 * force, -0.3, base.arm_r_yaw])
		p.arm_r_out = _phase(a, t, [base.arm_r_out, 0.35, 0.1, -0.05, 0.05, base.arm_r_out])
		p.elbow_r = _phase(a, t, [base.elbow_r, 1.9, 0.6, 0.35, 0.8, base.elbow_r])
		p.arm_r_twist = _phase(a, t, [base.arm_r_twist, 0.3, 0.6, 0.9, 0.5, base.arm_r_twist])
		p.torso_yaw = base.torso_yaw + _phase(a, t, [0.0, -0.45 * size, 0.1, 0.45 * force, 0.2, 0.0])
		p.pelvis_yaw = base.pelvis_yaw + _phase(a, t, [0.0, -0.2, 0.05, 0.25 * force, 0.1, 0.0])
		p.arm_l_fwd = _phase(a, t, [base.arm_l_fwd, 0.7, 0.2, -0.2, 0.1, base.arm_l_fwd])
	else:
		p.arm_r_fwd = _phase(a, t, [base.arm_r_fwd, 1.6 * size, 1.4, 1.1, 0.8, base.arm_r_fwd])
		p.arm_r_yaw = _phase(a, t, [base.arm_r_yaw, -0.7, 0.0, 0.8 * force * size, 0.4, base.arm_r_yaw])
		p.arm_r_out = _phase(a, t, [base.arm_r_out, -0.1, 0.05, 0.25, 0.15, base.arm_r_out])
		p.elbow_r = _phase(a, t, [base.elbow_r, 2.0, 0.7, 0.3, 0.8, base.elbow_r])
		p.arm_r_twist = _phase(a, t, [base.arm_r_twist, 1.1, 0.6, 0.2, 0.3, base.arm_r_twist])
		p.torso_yaw = base.torso_yaw + _phase(a, t, [0.0, 0.35, 0.05, -0.35 * force, -0.15, 0.0])
		p.pelvis_yaw = base.pelvis_yaw + _phase(a, t, [0.0, 0.15, 0.0, -0.18, -0.08, 0.0])
		p.arm_l_fwd = _phase(a, t, [base.arm_l_fwd, 0.2, 0.4, 0.6, 0.4, base.arm_l_fwd])
	p.elbow_l = _phase(a, t, [base.elbow_l, 1.2, 1.0, 0.8, 1.0, base.elbow_l])
	p.torso_pitch = base.torso_pitch + _phase(a, t, [0.0, -0.05, 0.12, 0.22, 0.1, 0.0])
	p.spine_bend = base.spine_bend + _phase(a, t, [0.0, -0.05 * side, 0.0, 0.06 * side, 0.02, 0.0])
	p.pelvis_y = base.pelvis_y + _phase(a, t, [0.0, -0.015, -0.03, -0.035, -0.02, 0.0])
	p.foot_l_z = base.foot_l_z + _phase(a, t, [0.0, 0.03, 0.1, 0.12, 0.08, 0.0])
	p.foot_r_toe = base.foot_r_toe + _phase(a, t, [0.0, 0.0, 0.2, 0.3, 0.15, 0.0])
	p.head_yaw = base.head_yaw - (p.pelvis_yaw - base.pelvis_yaw + p.torso_yaw - base.torso_yaw) * 0.75
	p.ear_l = base.ear_l + _phase(a, t, [0.0, -0.2, 0.2, 0.3, 0.1, 0.0])
	p.ear_r = base.ear_r + _phase(a, t, [0.0, -0.2, 0.2, 0.3, 0.1, 0.0])
	return p


## Golpe forte de cima (faca e porrete): os dois braços sobem, o corpo estica para trás e desce
## inteiro com a arma, dobrando no quadril, com o pé da frente avançando.
static func _overhead(a: GoblinAnimator, t: float, base: Dictionary) -> Dictionary:
	var p := base.duplicate()
	p.arm_r_fwd = _phase(a, t, [base.arm_r_fwd, 2.9, 2.0, 0.9, 0.7, base.arm_r_fwd])
	p.arm_r_yaw = _phase(a, t, [base.arm_r_yaw, 0.2, 0.1, 0.0, 0.0, base.arm_r_yaw])
	p.arm_r_out = _phase(a, t, [base.arm_r_out, 0.1, 0.05, 0.0, 0.05, base.arm_r_out])
	p.elbow_r = _phase(a, t, [base.elbow_r, 2.2, 0.8, 0.25, 0.6, base.elbow_r])
	p.arm_r_twist = _phase(a, t, [base.arm_r_twist, 0.5, 0.6, 0.6, 0.4, base.arm_r_twist])
	p.arm_l_fwd = _phase(a, t, [base.arm_l_fwd, 1.6, 1.0, 0.3, 0.3, base.arm_l_fwd])
	p.elbow_l = _phase(a, t, [base.elbow_l, 1.4, 1.0, 0.6, 0.8, base.elbow_l])
	p.torso_pitch = base.torso_pitch + _phase(a, t, [0.0, -0.22, 0.15, 0.45, 0.25, 0.0])
	p.spine_arch = base.spine_arch + _phase(a, t, [0.0, -0.12, 0.05, 0.16, 0.1, 0.0])
	p.torso_yaw = base.torso_yaw + _phase(a, t, [0.0, -0.25, 0.0, 0.15, 0.05, 0.0])
	p.pelvis_y = base.pelvis_y + _phase(a, t, [0.0, 0.01, -0.03, -0.06, -0.04, 0.0])
	p.pelvis_z = base.pelvis_z + _phase(a, t, [0.0, -0.02, 0.02, 0.04, 0.02, 0.0])
	p.foot_l_z = base.foot_l_z + _phase(a, t, [0.0, 0.02, 0.12, 0.15, 0.1, 0.0])
	p.head_pitch = base.head_pitch + _phase(a, t, [0.0, -0.18, 0.05, 0.2, 0.1, 0.0])
	p.ear_l = base.ear_l + _phase(a, t, [0.0, -0.3, 0.2, 0.35, 0.1, 0.0])
	p.ear_r = base.ear_r + _phase(a, t, [0.0, -0.3, 0.2, 0.35, 0.1, 0.0])
	return p


## Estocada da lança: as duas mãos puxam a lança para trás junto ao quadril, e o corpo inteiro vai
## para a frente atrás da ponta (o pé da frente avança, o quadril e o peito vão junto). `depth` é
## o tamanho da estocada (a forte arma mais e avança mais).
static func _thrust(a: GoblinAnimator, t: float, base: Dictionary, depth: float) -> Dictionary:
	var p := base.duplicate()
	p.arm_r_fwd = _phase(a, t, [base.arm_r_fwd, -0.1 * depth, 0.8, 1.25, 0.8, base.arm_r_fwd])
	p.elbow_r = _phase(a, t, [base.elbow_r, 1.65, 0.7, 0.2, 0.7, base.elbow_r])
	p.arm_r_out = _phase(a, t, [base.arm_r_out, 0.25, 0.1, 0.0, 0.1, base.arm_r_out])
	p.arm_l_fwd = _phase(a, t, [base.arm_l_fwd, 0.75, 1.2, 1.45, 1.1, base.arm_l_fwd])
	p.elbow_l = _phase(a, t, [base.elbow_l, 1.2, 0.5, 0.12, 0.5, base.elbow_l])
	p.arm_l_out = _phase(a, t, [base.arm_l_out, -0.05, -0.12, -0.15, -0.12, base.arm_l_out])
	p.torso_pitch = base.torso_pitch + _phase(a, t, [0.0, -0.08, 0.15, 0.3 * depth, 0.15, 0.0])
	p.torso_yaw = base.torso_yaw + _phase(a, t, [0.0, -0.3 * depth, -0.05, 0.12, 0.0, 0.0])
	p.pelvis_yaw = base.pelvis_yaw + _phase(a, t, [0.0, -0.15, 0.0, 0.1, 0.0, 0.0])
	p.pelvis_z = base.pelvis_z + _phase(a, t, [0.0, -0.03, 0.03, 0.06 * depth, 0.03, 0.0])
	p.pelvis_y = base.pelvis_y + _phase(a, t, [0.0, -0.01, -0.025, -0.04 * depth, -0.02, 0.0])
	p.foot_l_z = base.foot_l_z + _phase(a, t, [0.0, 0.0, 0.1, 0.16 * depth, 0.1, 0.0])
	p.foot_r_toe = base.foot_r_toe + _phase(a, t, [0.0, 0.0, 0.2, 0.3, 0.15, 0.0])
	p.head_yaw = base.head_yaw - (p.pelvis_yaw - base.pelvis_yaw + p.torso_yaw - base.torso_yaw) * 0.8
	p.head_pitch = base.head_pitch + _phase(a, t, [0.0, 0.05, -0.05, -0.1, 0.0, 0.0])
	return p

