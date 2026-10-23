class_name QuadrupedGait
extends RefCounted
## O passo dos quadrúpedes (cervo, javali, lobo) nos pivôs das pernas de três juntas
## (`<d|t>_coxa_<E|D>` → `_canela_` → `_pata_`, do CreatureModel).
##
## - Andando: quatro tempos (traseira esquerda, dianteira esquerda, traseira direita,
##   dianteira direita), cada pé 62% do ciclo no chão.
## - Correndo: galope (as traseiras quase juntas, depois as dianteiras), cada pé só 38% no chão:
##   o corpo voa entre uma batida e outra.
## - No apoio a perna vai reta de frente para trás; no ar, as juntas dobram: na dianteira o
##   carpo dobra e a canela vai para trás; na traseira o joelho e o jarrete recolhem o casco
##   para baixo da barriga.
## O ciclo anda com a distância percorrida (`stride` m por ciclo), então o casco não patina.

const WALK_OFFSETS := {"t_E": 0.0, "d_E": 0.25, "t_D": 0.5, "d_D": 0.75}
const RUN_OFFSETS := {"t_E": 0.0, "t_D": 0.1, "d_E": 0.48, "d_D": 0.6}

var stride_walk := 0.9
var stride_run := 2.0
var reach_walk := 0.28
var reach_run := 0.7
var fold_walk := 0.6
var fold_run := 1.4
## Acima disto (m/s) galopa.
var run_speed := 2.5
## Ciclo (0..1) e o quanto está galopando (0..1, suavizado).
var phase := 0.0
var run := 0.0
## Força do passo (0 parado .. 1 andando).
var motion := 0.0

var _legs: Array[Dictionary] = []


func setup(model: CreatureModel) -> void:
	for prefix in ["d", "t"]:
		for side in ["E", "D"]:
			_legs.append({
				"key": "%s_%s" % [prefix, side], "front": prefix == "d",
				"coxa": model.joint("%s_coxa_%s" % [prefix, side]),
				"canela": model.joint("%s_canela_%s" % [prefix, side]),
				"pata": model.joint("%s_pata_%s" % [prefix, side]),
			})


func update(delta: float, speed: float) -> void:
	run = lerpf(run, 1.0 if speed > run_speed else 0.0, 1.0 - exp(-5.0 * delta))
	motion = lerpf(motion, clampf(speed / 0.35, 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	var stride := lerpf(stride_walk, stride_run, run)
	phase = fposmod(phase + delta * speed / stride, 1.0)
	for leg: Dictionary in _legs:
		var key: String = leg.key
		var front: bool = leg.front
		var walk := _pose(fposmod(phase + WALK_OFFSETS[key], 1.0), 0.62, reach_walk, fold_walk, front)
		var gallop := _pose(fposmod(phase + RUN_OFFSETS[key], 1.0), 0.38, reach_run, fold_run, front)
		var pose := walk.lerp(gallop, run) * motion
		(leg.coxa as Node3D).rotation = Vector3(pose.x, 0.0, 0.0)
		(leg.canela as Node3D).rotation = Vector3(pose.y, 0.0, 0.0)
		(leg.pata as Node3D).rotation = Vector3(pose.z, 0.0, 0.0)


## Giro (coxa, canela, pata) de uma perna no instante `u` do ciclo dela.
## rotation.x negativo leva a perna para a frente.
func _pose(u: float, stance: float, reach: float, fold: float, front: bool) -> Vector3:
	var forward: float
	var flex := 0.0
	if u < stance:
		var s := u / stance
		forward = lerpf(reach, -reach, s)
		# Empurrando o chão no fim do apoio, a pata estica um pouco para trás.
		flex = -0.15 * smoothstep(0.7, 1.0, s) * fold
	else:
		var s := (u - stance) / (1.0 - stance)
		forward = lerpf(-reach, reach * 1.1, smoothstep(0.0, 1.0, s))
		flex = fold * sin(PI * pow(s, 0.8))
	if front:
		return Vector3(-forward, -0.35 * maxf(flex, 0.0), flex * 1.1)
	return Vector3(-forward + 0.15 * maxf(flex, 0.0), 0.55 * flex, -0.95 * flex)


## Deitado (peso 0..1): as pernas dobram por baixo do corpo.
func fold(weight: float) -> void:
	if weight <= 0.0:
		return
	for leg: Dictionary in _legs:
		var tucked := Vector3(0.35, -0.3, 2.5) if leg.front else Vector3(-1.1, 2.3, -2.3)
		for i in 3:
			var node: Node3D = leg[["coxa", "canela", "pata"][i]]
			node.rotation.x = lerpf(node.rotation.x, tucked[i], weight)


## Ergue a dianteira `side` ("E"/"D") com peso `amount` (bater a pata, cavar).
func lift_front(side: String, amount: float) -> void:
	for leg: Dictionary in _legs:
		if leg.key == "d_" + side:
			(leg.coxa as Node3D).rotation.x = lerpf((leg.coxa as Node3D).rotation.x, -0.55, amount)
			(leg.canela as Node3D).rotation.x = lerpf((leg.canela as Node3D).rotation.x, -0.5, amount)
			(leg.pata as Node3D).rotation.x = lerpf((leg.pata as Node3D).rotation.x, 1.3, amount)
