extends RefCounted
## O que faltava do plano de combate, rastros (experimental): o orc deixa pegadas de bota, o goblin
## fareja orcs de longe contra o vento, os sinais dos dias 1 e 2 (a flecha, os ossos, as pegadas) e
## os troncos riscados chamando a rota da patrulha.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	for case: String in ["boots", "sniff", "signs", "route"]:
		print("[T] --- %s" % case)
		for orc in _band.get_children():
			orc.queue_free()
		Inventory.clear()
		Clock.hour = 10.0
		await _wait(0.2)
		await call("_" + case)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _boots() -> void:
	_put(Vector3(30.0, 0.0, -40.0))
	var orc := _band.spawn(&"scout", Vector3(30.0, 0.0, 0.0))
	orc.route = [Vector3(30.0, 0.0, 12.0)]
	await _wait(5.0)
	var print_at := Tracks.nearest(&"orc", orc.global_position, 8.0)
	_check(print_at != Vector3.INF, "o orc deixa pegadas de bota andando")
	_check(Tracks.SHAPES.has(&"orc"), "a bota tem desenho próprio")


func _sniff() -> void:
	var sniff := Game.player.get_node("SniffAbility") as SniffAbility
	_put(Vector3(30.0, 0.0, -10.0))
	# O orc a 50 m, o vento soprando dele para o goblin.
	var orc := _band.spawn(&"scout", Vector3(30.0, 0.0, 40.0))
	orc.route = []
	await _wait(0.3)
	Wind.direction = Vector2(0.0, -1.0)
	_check(sniff.scented_orcs().has(orc), "fareja o orc a 50 m contra o vento")
	_check(Tuning.ORC_SMELL_RANGE > Tuning.SNIFF_RANGE, "de mais longe que qualquer bicho")
	Wind.direction = Vector2(0.0, 1.0)
	_check(not sniff.scented_orcs().has(orc), "a favor do vento, não")


func _signs() -> void:
	var signs := _tree.get_first_node_in_group(OrcSigns.GROUP) as OrcSigns
	_check(signs != null and signs._arrow != null and signs._bones != null, "os sinais existem desde o dia 1")
	var notes := Story.notes.size()
	signs._arrow.interact(Game.player)
	_check(signs.arrow_taken and Inventory.has(&"iron_scrap") and Story.notes.size() > notes, "a flecha grande: ponta de ferro e a anotação de Ari")
	_check(signs._arrow.interaction_prompt() == "", "só uma vez")
	signs._bones.interact(Game.player)
	_check(signs.bones_taken and Inventory.count(&"bone") == 2, "os ossos do cervo esfolado")
	_put(Vector3(40.0, 0.0, -8.0))
	signs._stamped = -999.0
	await _wait(0.3)
	_check(Tracks.nearest(&"orc", Vector3(44.0, _level.ground_height(44.0, -15.0), -15.0), 6.0) != Vector3.INF, "as pegadas de bota passam perto")
	var saved := signs.save_data()
	signs.load_data({})
	signs.load_data(saved)
	_check(signs.arrow_taken and signs.bones_taken, "o que já foi pego vai no save")


func _route() -> void:
	var marks := _tree.get_first_node_in_group(TreeMarks.GROUP) as TreeMarks
	var vegetation: Vegetation = _level._vegetation
	var marked := []
	for i in vegetation.trees.size():
		var tree: Vegetation.TreeInfo = vegetation.trees[i]
		if not tree.dead and not tree.fallen and Vector2(tree.base.x, tree.base.z).length() < 80.0 \
				and Vector2(tree.base.x, tree.base.z).distance_to(ForestLayout.CAVE_CENTER) > 25.0:
			marks.mark(i, tree.base, tree.radius, tree.base + Vector3(2.0, 0.0, 0.0))
			marked.append(tree.base)
			if marked.size() == 6:
				break
	var hits := 0
	for attempt in 6:
		var route := _band.make_route()
		for point: Vector3 in route:
			if marked.any(func(base: Vector3) -> bool: return Vector2(base.x, base.z).distance_to(Vector2(point.x, point.z)) < 2.0):
				hits += 1
	_check(hits > 0, "a rota da patrulha passa pelos troncos riscados (%d)" % hits)


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
