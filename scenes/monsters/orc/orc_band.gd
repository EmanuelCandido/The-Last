class_name OrcBand
extends Node3D
## Os orcs do vale (F12, docs/plano_combate.md §7 e §9.2; experimental): quem chega, quando, por onde
## anda e como se ajudam. Filho da floresta.
##
## Chegada pelo dia do ciclo: do Tuning.ORC_FIRST_DAY em diante um batedor por dia; do ORC_PATROL_DAY,
## também uma patrulha de dois (batedor e guerreiro). Entram às ORC_ARRIVE_HOUR pela borda do vale,
## longe do goblin, e cada grupo anda uma rota em volta do vale; às ORC_LEAVE_HOUR vão embora.
##
## O grito de um orc chama os que estão perto (alert). Na luta, só os ORC_ATTACKERS_AT_ONCE mais
## perto do goblin atacam (may_attack); os outros rodeiam. Um orc morto abala os que viram.
##
## Não há orcs no Bem-vindo de volta (o Zelador, jogando de goblin, não fere ninguém), depois de
## Ficar, com o flag `orcs_off` (o console do Zelador) e nos testes automáticos sem --orcs.
## Os orcs não vão no save: o dia de chegada sim (não chegam de novo no mesmo dia).

const GROUP := &"orc_band"

var _arrived_day := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)
	_rng.randomize()


func _process(_delta: float) -> void:
	if not enabled():
		if get_child_count() > 0:
			for orc in get_children():
				orc.queue_free()
		return
	# Nos testes automáticos, só os orcs que o roteiro põe (sem --orcs eles não chegam sozinhos).
	if DevTools.automated and not DevTools.orcs:
		return
	if Clock.day < Tuning.ORC_FIRST_DAY or _arrived_day == Clock.day:
		return
	if Clock.hour < Tuning.ORC_ARRIVE_HOUR or Clock.hour >= Tuning.ORC_LEAVE_HOUR - 1.0:
		return
	_arrived_day = Clock.day
	arrive()


## Os orcs podem existir agora.
func enabled() -> bool:
	return not (Game.welcome or Story.has_flag(&"ending_stay") or Story.has_flag(&"orcs_off"))


## Chegam os orcs do dia: um batedor e, mais tarde no ciclo, a patrulha.
func arrive() -> void:
	var route := make_route()
	spawn(&"scout", _edge_spawn(), route)
	if Clock.day >= Tuning.ORC_PATROL_DAY:
		var patrol := make_route()
		var at := _edge_spawn()
		spawn(&"scout", at, patrol)
		spawn(&"warrior", at + Vector3(1.6, 0.0, 1.2), patrol)


## Cria um orc em `at` (no chão), andando `route`.
func spawn(kind: StringName, at: Vector3, route: Array[Vector3] = []) -> Orc:
	var orc := Orc.new()
	orc.kind = kind
	orc.band = self
	orc.route = route
	add_child(orc)
	orc.global_position = Vector3(at.x, _ground(at.x, at.z) + 0.1, at.z)
	orc.died.connect(_on_died)
	return orc


func orcs() -> Array[Orc]:
	var list: Array[Orc] = []
	for node in get_children():
		if node is Orc and not (node as Orc).is_dead():
			list.append(node)
	return list


## Um orc gritou em `at`: os outros por perto vêm.
func alert(source: Orc, at: Vector3) -> void:
	for orc in orcs():
		if orc != source and orc.global_position.distance_to(source.global_position) < Tuning.ORC_SHOUT_RANGE:
			orc.alert(at)


## Só os mais perto do goblin atacam; os outros esperam rodeando.
func may_attack(orc: Orc) -> bool:
	var player := Game.player
	if player == null:
		return true
	var fighting: Array[Orc] = []
	for other in orcs():
		if other.state == Orc.State.COMBAT:
			fighting.append(other)
	fighting.sort_custom(func(a: Orc, b: Orc) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var index := fighting.find(orc)
	return index != -1 and index < Tuning.ORC_ATTACKERS_AT_ONCE


## Uma rota de patrulha: 5 a 6 pontos em volta do vale, em ordem de ângulo, fora da toca, da ruína
## e do vazio do norte.
func make_route() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var start := _rng.randf() * TAU
	var count := _rng.randi_range(5, 6)
	for i in count:
		for attempt in 12:
			var angle := start + TAU * i / count + _rng.randf_range(-0.3, 0.3)
			var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(35.0, ForestLayout.VALLEY_RADIUS - 20.0)
			if _usable(p):
				points.append(Vector3(p.x, _ground(p.x, p.y), p.y))
				break
	return points


func _usable(p: Vector2) -> bool:
	if p.distance_to(ForestLayout.CAVE_CENTER) < Tuning.ORC_CAVE_KEEP_OUT + 4.0:
		return false
	if p.distance_to(ForestLayout.RUINS) < Tuning.ORC_RUIN_KEEP_OUT + 4.0:
		return false
	if Story.has_flag(&"climate_cut") and p.y < Tuning.VOID_EDGE_Z + 10.0:
		return false
	return true


## Um ponto de chegada na borda do vale, longe do goblin.
func _edge_spawn() -> Vector3:
	var player := Game.player
	var best := Vector2.ZERO
	var best_distance := -1.0
	for attempt in 16:
		var angle := _rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * (ForestLayout.VALLEY_RADIUS - 12.0)
		if not _usable(p):
			continue
		var distance := p.distance_to(Vector2(player.global_position.x, player.global_position.z)) if player != null else 999.0
		if distance >= Tuning.ORC_SPAWN_MIN_DISTANCE:
			return Vector3(p.x, 0.0, p.y)
		if distance > best_distance:
			best_distance = distance
			best = p
	return Vector3(best.x, 0.0, best.y)


func _ground(x: float, z: float) -> float:
	var level := Game.current_level
	return float(level.ground_height(x, z)) if level != null and level.has_method("ground_height") else 0.0


func _on_died(dead: Orc) -> void:
	Story.add_count(&"orc_killed", 1)
	for orc in orcs():
		if orc.global_position.distance_to(dead.global_position) < 30.0:
			orc.lose_heart(0.35)


func save_data() -> Dictionary:
	return {"arrived_day": _arrived_day}


func load_data(data: Dictionary) -> void:
	_arrived_day = int(data.get("arrived_day", -1))
