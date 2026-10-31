extends RefCounted
## O segundo vale (F14, experimental): o vale da Pedra Rachada a leste, separado do vale da toca por
## montanhas, e o desfiladeiro (com a ravina e a ponte caída) como o único caminho. Os orcs vêm e
## vão por ele; o acampamento e o troll moram do lado de lá.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	for case: String in ["terrain", "ravine", "places", "arrive", "walk", "leave", "visit"]:
		print("[T] --- %s" % case)
		for orc in _band.get_children():
			orc.queue_free()
		await _wait(0.2)
		await call("_" + case)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _terrain() -> void:
	# Pelo eixo do desfiladeiro o chão quase não sobe; por qualquer outra reta entre os dois vales
	# passa uma montanha.
	var from := Vector2(60.0, -6.0)
	var to := ForestLayout.SECOND_VALLEY
	_check(_rise(ForestLayout.GORGE_FROM, ForestLayout.GORGE_TO) < 10.0, "o desfiladeiro passa (sobe %.1f m)" % _rise(ForestLayout.GORGE_FROM, ForestLayout.GORGE_TO))
	var lowest := INF
	var floors := maxf(_height(from), _height(to))
	for shift: float in [-90.0, -60.0, -40.0, 40.0, 60.0, 90.0]:
		var bend := Vector2(160.0, -15.0 + shift)
		var top := maxf(_rise(from, bend) + maxf(_height(from), _height(bend)), _rise(bend, to) + maxf(_height(bend), _height(to)))
		lowest = minf(lowest, top - floors)
	_check(lowest > 25.0, "fora dele, montanha entre os vales (a mais baixa sobe %.0f m)" % lowest)
	var center := ForestLayout.SECOND_VALLEY
	_check(_level.ground_height(center.x, center.y) < _level.ground_height(center.x + 90.0, center.y) - 30.0, "o vale novo é cercado de montanha")
	# O desfiladeiro é um corredor de vento; o vale abriga.
	var gorge := ForestLayout.gorge_point(0.5, 0.0)
	_check(Wind.exposure_at(gorge) > 0.85, "o vento passa forte no desfiladeiro (%.2f)" % Wind.exposure_at(gorge))


func _ravine() -> void:
	var floor_height := _height(ForestLayout.gorge_point(ForestLayout.RAVINE_AT, ForestLayout.GORGE_LEDGE))
	var bottom := _height(ForestLayout.gorge_point(ForestLayout.RAVINE_AT, -4.0))
	_check(floor_height - bottom > 3.5, "a ravina é funda (%.1f m)" % (floor_height - bottom))
	# A passagem plana junto do paredão norte e a rampa para sair do fundo.
	var worst := 0.0
	for path: Array in [ForestLayout.gorge_path(true), [ForestLayout.gorge_point(ForestLayout.RAVINE_AT, -3.0), ForestLayout.gorge_point(ForestLayout.RAVINE_AT, ForestLayout.GORGE_LEDGE)]]:
		for i in path.size() - 1:
			worst = maxf(worst, _steepest(path[i], path[i + 1]))
	_check(worst < 42.0, "o caminho dos orcs e a rampa da ravina dão para andar (%.0f graus)" % worst)
	# A ponte: dois troncos por cima da ravina, com colisão (o raio desce em cima de um deles).
	var bridge := _tree.get_first_node_in_group(TrollBridge.GROUP) as TrollBridge
	var middle := ForestLayout.gorge_point(ForestLayout.RAVINE_AT, TrollBridge.SIDE + TrollBridge.GAP)
	var space := _level.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(middle.x, floor_height + 5.0, middle.y), Vector3(middle.x, bottom - 2.0, middle.y), 1)
	var hit := space.intersect_ray(query)
	_check(not hit.is_empty() and float((hit["position"] as Vector3).y) > bottom + 3.0, "a ponte segura em cima da ravina")
	_check(bridge.den.y < floor_height - 3.0, "a toca do troll fica no fundo, embaixo da ponte")


func _places() -> void:
	var camp := _tree.get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	var flat := Vector2(camp.global_position.x, camp.global_position.z)
	_check(ForestLayout.in_second_valley(flat, OrcCamp.RADIUS), "o acampamento fica no vale da Pedra Rachada")
	_check(camp.get_node_or_null(^"SplitRock") != null, "com a pedra rachada atrás")
	var animals := _level.get_node(^"Animals")
	var east := animals.get_children().filter(func(node: Node) -> bool:
		return node is Animal and ForestLayout.in_second_valley(Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z), -10.0))
	_check(east.is_empty(), "nenhum bicho do lado de lá")


func _arrive() -> void:
	Clock.day = Tuning.ORC_PATROL_DAY
	_put(Vector3(ForestLayout.SPAWN.x, 0.0, ForestLayout.SPAWN.y))
	_band.arrive()
	await _wait(0.3)
	var orc := _band.orcs()[0]
	var at := Vector2(orc.global_position.x, orc.global_position.z)
	_check(at.distance_to(ForestLayout.GORGE_FROM) < 3.0, "com o goblin longe, entram pela boca do desfiladeiro")
	for other in _band.get_children():
		other.queue_free()
	await _wait(0.2)
	# O goblin perto da boca: aparecem lá dentro e andam o resto.
	_put(Vector3(ForestLayout.GORGE_FROM.x - 8.0, 0.0, ForestLayout.GORGE_FROM.y))
	_band.arrive()
	await _wait(0.3)
	orc = _band.orcs()[0]
	at = Vector2(orc.global_position.x, orc.global_position.z)
	_check(ForestLayout.gorge_frame(at).x > 0.3 and not orc.approach.is_empty(), "com o goblin perto, aparecem dentro do desfiladeiro e vêm andando")
	Clock.day = 1


func _walk() -> void:
	# Um batedor atravessa o desfiladeiro inteiro pela passagem, sem cair na ravina.
	_put(Vector3(ForestLayout.SPAWN.x, 0.0, ForestLayout.SPAWN.y))
	var path := ForestLayout.gorge_path(true)
	var orc := _band.spawn(&"scout", Vector3(path[0].x, 0.0, path[0].y))
	orc.route = []
	for i in range(1, path.size()):
		orc.approach.append(Vector3(path[i].x, _height(path[i]), path[i].y))
	var lowest := INF
	var waited := 0.0
	while not orc.approach.is_empty() and waited < 140.0:
		await _wait(0.5)
		waited += 0.5
		var here := Vector2(orc.global_position.x, orc.global_position.z)
		lowest = minf(lowest, orc.global_position.y - _height(ForestLayout.gorge_point(ForestLayout.gorge_frame(here).x, ForestLayout.GORGE_LEDGE)))
	var end := Vector2(orc.global_position.x, orc.global_position.z)
	_check(orc.approach.is_empty() and end.distance_to(ForestLayout.GORGE_FROM) < 3.0, "atravessou até a boca do lado da toca (%.0f s)" % waited)
	_check(lowest > -2.0, "sem descer na ravina (%.1f m)" % lowest)


func _leave() -> void:
	_put(Vector3(ForestLayout.SPAWN.x, 0.0, ForestLayout.SPAWN.y))
	var orc := _band.spawn(&"scout", Vector3(60.0, 0.0, 10.0))
	orc.route = []
	await _wait(0.3)
	Clock.hour = Tuning.ORC_LEAVE_HOUR + 0.1
	await _wait(0.3)
	var goal := Vector2(orc._goal.x, orc._goal.z)
	_check(orc.state == Orc.State.LEAVE and goal.distance_to(ForestLayout.GORGE_FROM) < 1.0 and orc.approach.size() == 3,
		"vai embora pelo desfiladeiro, para o vale dele")
	Clock.hour = 10.0
	orc.queue_free()


func _visit() -> void:
	_check(not Story.has_flag(&"second_valley_seen"), "ainda não foi lá")
	var p := ForestLayout.SECOND_VALLEY + Vector2(-20.0, 0.0)
	_put(Vector3(p.x, 0.0, p.y))
	await _wait(1.5)
	_check(Story.has_flag(&"second_valley_seen") and "pedra rachada" in "\n".join(Story.notes), "chegando lá, a anotação de Ari")


## Quanto o chão sobe acima da ponta mais alta de `a` a `b`.
func _rise(a: Vector2, b: Vector2) -> float:
	var top := -INF
	for k in 61:
		var p := a.lerp(b, k / 60.0)
		top = maxf(top, _height(p))
	return top - maxf(_height(a), _height(b))


## A rampa mais íngreme de `a` a `b`, em graus, de metro em metro.
func _steepest(a: Vector2, b: Vector2) -> float:
	var worst := 0.0
	var steps := maxi(int(a.distance_to(b)), 1)
	for k in steps:
		var p := a.lerp(b, float(k) / steps)
		var q := a.lerp(b, float(k + 1) / steps)
		worst = maxf(worst, rad_to_deg(atan(absf(_height(q) - _height(p)) / p.distance_to(q))))
	return worst


func _height(p: Vector2) -> float:
	return _level.ground_height(p.x, p.y)


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
