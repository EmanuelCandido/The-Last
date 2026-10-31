extends RefCounted
## F13, a consequência (docs/plano_combate.md §10, experimental): a bolsa da morte no chão e levada
## pelo orc para o baú do acampamento, o acampamento (paliçada com a fresta, fogueira, baú, guardas)
## e o esconderijo da toca. --case=<nome> roda um só (padrão: todos).

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D


func run() -> void:
	_level = Game.current_level
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := ["bag", "camp", "taken", "stash"]
	for case: String in cases:
		if only == "" or only == case:
			print("[T] --- %s" % case)
			_reset()
			await _wait(0.2)
			await call("_" + case)
	_reset()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _bag() -> void:
	var field := _tree.get_first_node_in_group(BagField.GROUP) as BagField
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.2)
	Inventory.add(&"bow")
	Inventory.add(&"clothes")
	Inventory.add(&"leather_vest")
	Inventory.add(&"wood", 5)
	Inventory.add(&"cooked_meat", 2)
	Inventory.add(&"club")
	Inventory.hold(&"club")
	Inventory.wear_down(&"club", 0.25)
	var spot := Game.player.global_position
	field._on_died(&"wolf")
	_check(Inventory.has(&"bow") and Inventory.has(&"clothes") and Inventory.has(&"leather_vest"), "arco, roupa e armadura ficam com o goblin")
	_check(not Inventory.has(&"wood") and not Inventory.has(&"club") and Inventory.held() == &"", "o resto (a arma da mão também) cai na bolsa")
	var bag: DroppedBag = null
	for child in field.get_children():
		if child is DroppedBag:
			bag = child
	_check(bag != null and bag.global_position.distance_to(spot) < 0.5, "a bolsa fica onde ele caiu")
	# O save guarda a bolsa.
	var saved := field.save_data()
	field.load_data({})
	_check(field.bag.is_empty(), "limpou")
	field.load_data(saved)
	_check(not field.bag.is_empty(), "a bolsa volta do save")
	field.pick_up()
	_check(Inventory.count(&"wood") == 5 and Inventory.count(&"cooked_meat") == 2, "pegou tudo de volta")
	_check(Inventory.has(&"club") and absf(Inventory.wear(&"club") - 0.75) < 0.01, "a arma volta gasta como estava")
	# Esquecida, ela some no começo do segundo dia.
	Inventory.add(&"wood", 3)
	field._on_died(&"wolf")
	field._on_day(Clock.day + 2)
	_check(field.bag.is_empty(), "esquecida, a bolsa se perde")


func _camp() -> void:
	var camp := _tree.get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	_check(camp != null, "o acampamento existe")
	if camp == null:
		return
	var flat := Vector2(camp.global_position.x, camp.global_position.z)
	_check(ForestLayout.in_second_valley(flat, OrcCamp.RADIUS) and flat.y > Tuning.VOID_EDGE_Z, "no vale da Pedra Rachada e fora do vazio do norte")
	_check(flat.distance_to(ForestLayout.CAVE_CENTER) > 80.0, "longe da toca (%.0f m)" % flat.distance_to(ForestLayout.CAVE_CENTER))
	var fire := camp.get_node(^"Fire") as Campfire
	fire.fuel = 0.0
	await _wait(0.2)
	_check(fire.is_lit(), "os orcs mantêm a fogueira acesa")
	# A paliçada: de fora para dentro pela frente o goblin entra; a fresta dos fundos existe.
	var gate := (-flat).normalized()
	var space := _level.get_world_3d().direct_space_state
	var blocked := 0
	var open := 0
	for i in 72:
		var angle := TAU * i / 72.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		# Na altura do chão daquele lado (o vale da Pedra Rachada não é plano).
		var from := camp.global_position + dir * (OrcCamp.RADIUS + 1.0)
		var to := camp.global_position + dir * (OrcCamp.RADIUS - 1.0)
		var ground := maxf(_level.ground_height(from.x, from.z), _level.ground_height(to.x, to.z))
		from.y = ground + 0.6
		to.y = ground + 0.6
		# Uma esfera do tamanho do goblin (os vãos entre os troncos são finos demais para ele).
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.24
		query.shape = sphere
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, from)
		query.motion = to - from
		var fractions := space.cast_motion(query)
		if fractions.is_empty() or fractions[0] >= 1.0:
			open += 1
		else:
			blocked += 1
	_check(blocked > 55, "a paliçada fecha o acampamento (%d de 72 fechados)" % blocked)
	_check(open >= 2, "e tem a entrada e a fresta (%d abertos)" % open)
	# Os guardas de dia.
	var band := _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	camp.spawn_guards(band)
	await _wait(0.3)
	var guards := band.orcs().filter(func(orc: Orc) -> bool: return orc.global_position.distance_to(camp.global_position) < OrcCamp.RADIUS + 2.0).size()
	_check(guards == 2, "dois guardas no acampamento (%d)" % guards)


func _taken() -> void:
	var field := _tree.get_first_node_in_group(BagField.GROUP) as BagField
	var camp := _tree.get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	var band := _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	_put(Vector3(20.0, 0.0, 10.0))
	band.spawn(&"scout", Vector3(26.0, 0.0, 10.0))
	await _wait(0.2)
	Inventory.add(&"iron_scrap", 2)
	Inventory.add(&"spear")
	Inventory.wear_down(&"spear", 0.5)
	field._on_died(&"orc")
	_check(field.bag.is_empty() and camp.chest_count() == 3, "com o orc perto, a bolsa vai para o baú (%d)" % camp.chest_count())
	var chest := camp.get_node(^"Chest") as OrcChest
	_check(chest.interaction_enabled(), "o baú tem o que abrir")
	chest.interact(Game.player)
	_check(Inventory.count(&"iron_scrap") == 2 and Inventory.has(&"spear") and absf(Inventory.wear(&"spear") - 0.5) < 0.01, "abriu o baú: tudo de volta")
	_check(camp.chest_count() == 0 and not chest.interaction_enabled(), "o baú ficou vazio")
	var saved := camp.save_data()
	_check(saved.has("chest"), "o baú vai no save")


func _stash() -> void:
	var stash := _tree.get_first_node_in_group(CaveStash.GROUP) as CaveStash
	_check(stash != null and not stash.built, "o esconderijo nasce por fazer")
	var craft := Game.player.get_node("CraftAbility") as CraftAbility
	var recipe: Dictionary = Recipes.LIST.filter(func(r: Dictionary) -> bool: return r.id == &"stash")[0]
	_put(stash.global_position + Vector3(0.0, 0.0, -1.0))
	await _wait(0.2)
	Inventory.add(&"stone", 2)
	Inventory.add(&"wood", 2)
	_check(Recipes.missing(recipe) == "", "dentro da toca dá para fazer")
	craft._finish(recipe)
	_check(stash.built, "esconderijo feito")
	Inventory.add(&"bow")
	Inventory.add(&"meat", 3)
	Inventory.add(&"fitted_chest")
	Inventory.add(&"club")
	Inventory.wear_down(&"club", 0.4)
	stash.interact(Game.player)
	_check(Inventory.has(&"bow") and not Inventory.has(&"meat") and not Inventory.has(&"fitted_chest"), "guardou tudo menos o arco (a armadura sai do corpo)")
	_check(Armor.worn(&"body") == &"", "sem o peitoral")
	var field := _tree.get_first_node_in_group(BagField.GROUP) as BagField
	field._on_died(&"wolf")
	_check(stash.count() == 5, "morrer não leva o que está guardado (%d)" % stash.count())
	Input.action_press("crouch")
	await _wait(0.3)
	stash.interact(Game.player)
	Input.action_release("crouch")
	_check(Inventory.count(&"meat") == 3 and Inventory.has(&"fitted_chest") and absf(Inventory.wear(&"club") - 0.6) < 0.01, "agachado, pegou tudo de volta")


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	Input.action_release("crouch")
	var band := _tree.get_first_node_in_group(OrcBand.GROUP)
	for orc in band.get_children():
		orc.queue_free()
	var field := _tree.get_first_node_in_group(BagField.GROUP) as BagField
	field._clear()
	Inventory.clear()
	Vitals.reset()
	Clock.hour = 10.0


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
