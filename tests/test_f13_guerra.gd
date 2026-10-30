extends RefCounted
## F13 de ponta a ponta (docs/plano_combate.md §5 e §9, experimental): escudo, armaduras e seus
## custos, o machado no pinheiro vivo, a flecha de ferro, o couro curtido, o crânio do javali e o
## ferro do guerreiro. --case=<nome> roda um só (padrão: todos).

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _melee: MeleeAbility


func run() -> void:
	_level = Game.current_level
	_melee = Game.player.get_node("MeleeAbility") as MeleeAbility
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := ["shield", "armor", "axe", "iron", "tan", "loot"]
	for case: String in cases:
		if only == "" or only == case:
			print("[T] --- %s" % case)
			_reset()
			await _wait(0.2)
			await call("_" + case)
	_reset()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _shield() -> void:
	Inventory.add(&"club")
	Inventory.add(&"spear")
	Inventory.add(&"hide_shield")
	Inventory.hold(&"club")
	_check(Armor.shield_in_use() == &"hide_shield", "escudo em uso com arma de uma mão")
	Inventory.hold(&"spear")
	_check(Armor.shield_in_use() == &"", "com a lança (duas mãos), sem escudo")
	Inventory.hold(&"club")
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.3)
	Input.action_press("aim")
	await _wait(0.5)
	var front := Game.player.global_position + Game.player.facing() * 1.2
	var result := Game.player.receive_attack(_hit(front, 20.0))
	_check(result == &"blocked", "o escudo segura (%s)" % result)
	_check(Vitals.health > 100.0 - 20.0 * Tuning.BLOCK_LEAK + 0.5, "passa bem menos que sem escudo (%.1f)" % Vitals.health)
	_check(Inventory.wear(&"hide_shield") < 1.0 and Inventory.wear(&"club") == 1.0, "quem gasta é o escudo, não a arma")
	Input.action_release("aim")


func _armor() -> void:
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.3)
	var behind := Game.player.global_position - Game.player.facing() * 1.0
	Game.player.receive_attack(_hit(behind, 20.0))
	var bare := 100.0 - Vitals.health
	Vitals.health = 100.0
	Vitals.bleeding = 0.0
	Inventory.add(&"leather_vest")
	Inventory.add(&"skull_helm")
	await _wait(0.6)
	Game.player.receive_attack(_hit(behind, 20.0))
	var dressed := 100.0 - Vitals.health
	_check(dressed < bare * 0.8, "o couro segura parte do golpe (%.1f → %.1f)" % [bare, dressed])
	_check(Armor.worn(&"head") == &"skull_helm" and Armor.worn(&"body") == &"leather_vest", "veste a melhor peça de cada lugar")
	Inventory.add(&"fitted_chest")
	Inventory.add(&"fitted_helmet")
	await _wait(0.2)
	_check(Armor.worn(&"body") == &"fitted_chest" and Armor.worn(&"head") == &"fitted_helmet", "o ferro passa na frente do couro")
	_check(Game.player.noise_factors.get(&"armor", 1.0) > 1.2, "o ferro faz barulho (%.2f)" % Game.player.noise_factors.get(&"armor", 1.0))
	_check(Game.player.speed_factors.get(&"armor", 1.0) < 1.0, "e pesa")
	var cold := Game.player.get_node("ColdExposure") as ColdExposure
	Clock.hour = 23.0
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.3)
	var iron_cold := cold.exposure()
	Inventory.remove(&"fitted_chest")
	Inventory.remove(&"fitted_helmet")
	await _wait(0.3)
	_check(iron_cold > cold.exposure(), "de noite o ferro gela (%.2f contra %.2f)" % [iron_cold, cold.exposure()])
	Clock.hour = 10.0


func _axe() -> void:
	Inventory.add(&"orc_axe")
	Inventory.hold(&"orc_axe")
	var vegetation: Vegetation = _level._vegetation
	var pine := -1
	for i in vegetation.trees.size():
		var tree: Vegetation.TreeInfo = vegetation.trees[i]
		if not tree.dead and not tree.fallen and tree.base.distance_to(Vector3(20.0, tree.base.y, 10.0)) < 60.0:
			pine = i
			break
	_check(pine != -1, "há pinheiro vivo")
	if pine == -1:
		return
	var base: Vector3 = vegetation.trees[pine].base
	var radius: float = vegetation.trees[pine].radius
	_put(base + Vector3(radius + 0.45, 0.0, 0.0))
	await _wait(0.3)
	var wood := Inventory.count(&"wood")
	for i in Tuning.AXE_PINE_HITS:
		Game.player.strike_tree(1.2)
	_check(vegetation.trees[pine].fallen, "o machado derruba o pinheiro vivo em %d golpes" % Tuning.AXE_PINE_HITS)
	_check(Inventory.count(&"wood") >= wood + 4, "e dá madeira farta (%d)" % (Inventory.count(&"wood") - wood))
	Inventory.hold(&"")
	var other := -1
	for i in vegetation.trees.size():
		var tree: Vegetation.TreeInfo = vegetation.trees[i]
		if not tree.dead and not tree.fallen and i != pine:
			other = i
			break
	var other_base: Vector3 = vegetation.trees[other].base
	_put(other_base + Vector3(vegetation.trees[other].radius + 0.45, 0.0, 0.0))
	await _wait(0.3)
	for i in Tuning.AXE_PINE_HITS + 2:
		Game.player.strike_tree(1.2)
	_check(not vegetation.trees[other].fallen, "no soco, o pinheiro vivo não cai")


func _iron() -> void:
	var band := _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	var warrior := band.spawn(&"warrior", Vector3(30.0, 0.0, 0.0))
	await _wait(0.3)
	warrior.set_physics_process(false)
	var chest := warrior.global_position + Vector3.UP * 1.1
	var health := warrior.health
	var arrow := Arrow.new()
	arrow.item = &"iron_arrow"
	_level.add_child(arrow)
	arrow.launch(chest + Vector3(0.0, 0.0, 3.0), Vector3(0.0, 0.0, -1.0), 0.5, [])
	await _wait(0.4)
	var iron_hurt := health - warrior.health
	health = warrior.health
	var plain := Arrow.new()
	_level.add_child(plain)
	plain.launch(chest + Vector3(0.1, 0.0, 3.0), Vector3(0.0, 0.0, -1.0), 0.5, [])
	await _wait(0.4)
	var plain_hurt := health - warrior.health
	_check(iron_hurt > 0.0 and plain_hurt > 0.0, "as duas flechas acertam o guerreiro")
	_check(iron_hurt > plain_hurt * 1.5, "a de ferro fura o peitoral (%.2f contra %.2f)" % [iron_hurt, plain_hurt])
	warrior.queue_free()


func _tan() -> void:
	var rack := _level.find_child("SmokingRack", true, false) as SmokingRack
	var fire := rack.campfire
	fire.fuel = 3.0
	# O defumador lê a lenha a cada quadro: espera um para o "dormiu" contar a fogueira cheia.
	await _wait(0.1)
	Inventory.add(&"hide", 2)
	_check(rack.interaction_prompt() == "Pendurar couro para curtir", "o defumador aceita couro")
	rack.interact(Game.player)
	_check(rack.hides.size() == 2 and not Inventory.has(&"hide"), "os dois couros na fumaça")
	rack._on_skipped(Tuning.TAN_HOURS + 1.0)
	_check(rack.tanned_count() == 2, "dormindo com o fogo aceso, curtem")
	rack.interact(Game.player)
	_check(Inventory.count(&"tanned_hide") == 2, "couro curtido no inventário")
	var boar: Boar = null
	for node in _tree.get_nodes_in_group(&"animals"):
		if node is Boar and (node as Animal).state != Animal.State.DEAD:
			boar = node
			break
	if boar != null:
		boar.kill()
		boar.interact(Game.player)
		_check(Inventory.has(&"boar_skull"), "o javali deixa o crânio")


func _loot() -> void:
	var band := _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	for i in 6:
		var warrior := band.spawn(&"warrior", Vector3(30.0 + i * 2.0, 0.0, 0.0))
		await _wait(0.1)
		warrior.strike(99.0, &"cut", warrior.global_position + Vector3.UP, Vector3.FORWARD, 0.0)
		warrior.interact(Game.player)
		warrior.queue_free()
	_check(Inventory.has(&"orc_helmet") or Inventory.has(&"orc_chest"), "os guerreiros deixam o ferro (elmo %d, peitoral %d)" % [Inventory.count(&"orc_helmet"), Inventory.count(&"orc_chest")])
	var bench := _level.find_child("Workbench", true, false) as Workbench
	bench.build_now()
	_put(bench.global_position + bench.global_basis.z * 1.0)
	await _wait(0.2)
	Inventory.add(&"orc_helmet")
	Inventory.add(&"hide")
	var craft := Game.player.get_node("CraftAbility") as CraftAbility
	for recipe: Dictionary in Recipes.LIST:
		if recipe.id == &"fit_helmet":
			craft._finish(recipe)
	_check(Inventory.has(&"fitted_helmet") and Armor.worn(&"head") == &"fitted_helmet", "ajustado na bancada, o elmo orc vai na cabeça")


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	for action in ["attack", "aim", "crouch"]:
		Input.action_release(action)
	var band := _tree.get_first_node_in_group(OrcBand.GROUP)
	for orc in band.get_children():
		orc.queue_free()
	Inventory.clear()
	Vitals.reset()
	_melee.stamina = 1.0
	_melee.poise = 0.0
	Clock.hour = 10.0
	Weather.stop_rain()
	Weather.rain = 0.0


func _hit(from: Vector3, damage: float) -> Dictionary:
	return {"damage": damage, "kind": &"cut", "from": from, "poise": 0.2, "cause": &"orc", "push": Vector3.ZERO}


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
