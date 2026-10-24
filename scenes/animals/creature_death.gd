class_name CreatureDeath
extends RefCounted
## A queda e o corpo morto dos bichos de quatro patas (cervo, javali, lobo, coelho), nos pivôs do
## CreatureModel. Quatro trechos, cada um partindo de onde o anterior parou (o primeiro parte da
## pose em que o bicho estava: no meio do galope, pastando...):
## 1. joelhos: as dianteiras dobram, o corpo afunda de frente e a cabeça pende;
## 2. peito no chão: as traseiras dobram também e o corpo começa a tombar de lado;
## 3. tombo: rola de lado, bate no chão (passa um pouco do ponto) e as pernas se soltam;
## 4. assenta: deitado de lado, pernas esticadas e moles (as de cima caem para o chão), pescoço
##    para trás e a cabeça encostada no chão.
## Por cima da pose deitada vêm o espasmo (a traseira de cima chuta umas vezes) e o último fôlego.
##
## Sinais (como no QuadrupedGait): rotation.x positivo leva a pata para trás e a cabeça para baixo;
## `side` 1 tomba sobre o lado direito (_D), com o esquerdo (_E) para o céu.

## Fim de cada trecho (s, antes de `pace`).
const KEYS: Array[float] = [0.28, 0.62, 1.0, 1.32]
## Depois disto (s) o corpo fica parado de vez.
const STILL := 4.2
const PARTS: Array[String] = ["coxa", "canela", "pata"]

## Altura do pivô do corpo deitado (a meia largura do bicho, no espaço dele).
var height := 0.22
## Rolagem deitado (rad; PI/2 = de lado certinho, menos = o dorso um pouco para cima).
var roll := 1.45
## Mais que 1 cai mais depressa (o coelho).
var pace := 1.0
## Quanto o corpo deitado sai para o lado da queda (m).
var shift := 0.12
## Pescoço deitado: para trás (negativo) e caído para o chão; a cabeça, idem.
var neck_arch := -0.4
var neck_drop := 0.35
var head_tilt := -0.15
var head_drop := 0.3
## Pernas (coxa, canela, pata em rotation.x): dobradas por baixo e soltas, deitado. Uma perna
## sem canela (o coelho) usa só a coxa e a pata.
var fold_front := Vector3(0.35, -0.3, 2.5)
var fold_hind := Vector3(-1.1, 2.3, -2.3)
var limp_front := Vector3(-0.35, 0.15, 0.35)
var limp_hind := Vector3(0.35, 0.3, -0.4)
## As pernas de cima caem para o chão (rad, coxa em rotation.z).
var droop := 0.3

var _joints := {}
var _rest := {}
## Pose de cada ponto do trecho: nome do pivô -> [rotation, position].
var _keys: Array[Dictionary] = []
var _side := 1.0
var _kick := 1.0


func setup(model: CreatureModel) -> void:
	for node in model.joints:
		_joints[String(node.name)] = node
		_rest[String(node.name)] = node.position


## Começa a queda da pose de agora. `kick` é a força do espasmo (0 = nenhum).
func start(side: float, kick: float) -> void:
	_side = side
	_kick = kick
	var now := {}
	for joint_name: String in _joints:
		var node: Node3D = _joints[joint_name]
		now[joint_name] = [node.rotation, node.position]
	_keys = [now, _pose(1), _pose(2), _pose(3), _pose(4)]


## Põe o corpo no instante `t` (s desde a morte).
func apply(t: float) -> void:
	var time := t * pace
	var stage := 0
	while stage < KEYS.size() and time > KEYS[stage]:
		stage += 1
	var from: Dictionary = _keys[mini(stage, KEYS.size())]
	var to := from
	var w := 0.0
	if stage < KEYS.size():
		to = _keys[stage + 1]
		var begin := 0.0 if stage == 0 else KEYS[stage - 1]
		var s := clampf((time - begin) / (KEYS[stage] - begin), 0.0, 1.0)
		# Dobrar os joelhos é um gesto; cair e rolar é peso (acelera); assentar desacelera.
		match stage:
			0:
				w = smoothstep(0.0, 1.0, s)
			1, 2:
				w = s * s
			_:
				w = 1.0 - (1.0 - s) * (1.0 - s)
	for joint_name: String in _joints:
		var node: Node3D = _joints[joint_name]
		var a: Array = from[joint_name]
		var b: Array = to[joint_name]
		node.rotation = (a[0] as Vector3).lerp(b[0], w)
		node.position = (a[1] as Vector3).lerp(b[1], w)
		node.scale = Vector3.ONE
	if time > KEYS[KEYS.size() - 1]:
		_aftermath(time)


## O espasmo (a traseira de cima chuta, a dianteira de cima acompanha fraco) e o último fôlego.
func _aftermath(time: float) -> void:
	var upper := "E" if _side > 0.0 else "D"
	var k := (time - 1.9) / 1.1
	if k > 0.0 and k < 1.0:
		var kick := sin(k * PI * 3.0) * (1.0 - k) * 0.45 * _kick
		_turn("t_coxa_" + upper, Vector3(-kick, 0.0, 0.0))
		_turn("t_canela_" + upper, Vector3(kick * 0.6, 0.0, 0.0))
		_turn("d_coxa_" + upper, Vector3(kick * 0.35, 0.0, 0.0))
	var breath := (time - 3.0) / 0.9
	if breath > 0.0 and breath < 1.0 and _joints.has("peito"):
		(_joints["peito"] as Node3D).scale = Vector3.ONE * (1.0 + sin(breath * PI) * 0.035)


func _turn(joint_name: String, by: Vector3) -> void:
	if _joints.has(joint_name):
		(_joints[joint_name] as Node3D).rotation += by


## A pose do fim do trecho `stage` (1..4).
func _pose(stage: int) -> Dictionary:
	var pose := {}
	for joint_name: String in _joints:
		pose[joint_name] = [Vector3.ZERO, _rest[joint_name]]
	var body_y: float = (_rest["corpo"] as Vector3).y
	var lying := Vector3(-_side * shift, height - body_y, 0.0)
	match stage:
		1:
			_put(pose, "corpo", Vector3(0.2, 0.0, 0.0), Vector3(0.0, -body_y * 0.14, 0.04))
			_legs(pose, fold_front * 0.55, fold_hind * 0.15, 0.0, 0.0)
			_put(pose, "pescoco", Vector3(0.35, 0.0, 0.0))
			_put(pose, "cabeca", Vector3(0.25, 0.0, 0.0))
		2:
			_put(pose, "corpo", Vector3(0.06, 0.0, _side * 0.25), Vector3(-_side * shift * 0.3, -body_y * 0.5, 0.06))
			_legs(pose, fold_front, fold_hind * 0.8, 0.0, 0.0)
			_put(pose, "pescoco", Vector3(0.55, 0.0, _side * 0.1))
			_put(pose, "cabeca", Vector3(0.3, 0.0, 0.0))
		3:
			_put(pose, "corpo", Vector3(0.0, 0.0, _side * roll * 1.07), lying + Vector3(0.0, -0.03, 0.06))
			_legs(pose, fold_front.lerp(limp_front, 0.7), fold_hind.lerp(limp_hind, 0.7), droop * 0.5, 0.7)
			_put(pose, "pescoco", Vector3(neck_arch * 0.5, 0.0, _side * neck_drop * 0.7))
			_put(pose, "cabeca", Vector3(head_tilt * 0.5, 0.0, _side * head_drop * 0.5))
			_put(pose, "cauda", Vector3(0.3, 0.0, _side * 0.2))
		4:
			_put(pose, "corpo", Vector3(0.0, 0.0, _side * roll), lying + Vector3(0.0, 0.0, 0.06))
			_legs(pose, limp_front, limp_hind, droop, 1.0)
			_put(pose, "pescoco", Vector3(neck_arch, 0.0, _side * neck_drop))
			_put(pose, "cabeca", Vector3(head_tilt, 0.0, _side * head_drop))
			_put(pose, "cauda", Vector3(0.3, 0.0, _side * 0.35))
	return pose


func _put(pose: Dictionary, joint_name: String, rotation: Vector3, offset := Vector3.ZERO) -> void:
	if pose.has(joint_name):
		pose[joint_name] = [rotation, (_rest[joint_name] as Vector3) + offset]


## As quatro pernas: `front`/`hind` em (coxa, canela, pata); `drop` faz as de cima caírem para o
## chão e `spread` (0..1) separa as de cima das de baixo (para não se cruzarem deitado).
func _legs(pose: Dictionary, front: Vector3, hind: Vector3, drop: float, spread: float) -> void:
	for prefix in ["d", "t"]:
		var bend := front if prefix == "d" else hind
		for leg_side in ["E", "D"]:
			var s := 1.0 if leg_side == "E" else -1.0
			var upper := s == _side
			var apart := (0.18 if upper else -0.12) * spread * (-1.0 if prefix == "d" else 1.0)
			for i in PARTS.size():
				var rotation := Vector3(bend[i], 0.0, 0.0)
				if i == 0:
					rotation.x += apart
					rotation.z = -s * drop * (1.0 if upper else 0.3)
				_put(pose, "%s_%s_%s" % [prefix, PARTS[i], leg_side], rotation)
