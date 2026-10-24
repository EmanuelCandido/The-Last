extends RefCounted
## F9 de ponta a ponta: chuva, manadas (dia, noite, chuva), caça (sangrar, corpo), coleta, carne
## que estraga, defumador, receitas, prática, tocaia, troféus, o Velho, o javali e a mira com
## fôlego. --case=<nome> roda um só (padrão: todos).

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D


func run() -> void:
	_level = Game.current_level
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := ["rain", "herds", "hunt", "food", "gear", "beasts", "aim", "save"]
	for case: String in cases:
		if only == "" or only == case:
			print("[T] --- %s" % case)
			await call("_" + case)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _rain() -> void:
	Weather.stop_rain()
	Weather.rain = 0.0
	await _wait(0.3)
	var dry_fog := (_level.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_density
	Weather.start_rain(3.0)
	_check(Weather.is_raining(), "começou a chover")
	await _until(func() -> bool: return Weather.rain > 0.99, 40.0)
	_check(Weather.rain > 0.99, "a chuva entrou devagar até cheia (%.2f)" % Weather.rain)
	await _wait(0.2)
	var wet_fog := (_level.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_density
	_check(wet_fog > dry_fog * 1.3, "a neblina adensa na chuva (%.4f → %.4f)" % [dry_fog, wet_fog])
	var rain := _level.get_node("Rain") as GPUParticles3D
	Game.player.global_position = Vector3(20.0, _level.ground_height(20.0, 10.0) + 0.2, 10.0)
	await _wait(0.3)
	_check(rain.emitting and rain.amount_ratio > 0.9, "riscos de chuva fora da caverna")
	var cold := Game.player.get_node("ColdExposure") as ColdExposure
	Clock.hour = 13.0
	var open_canopy: float = _level.canopy_at(Game.player.global_position)
	if open_canopy < 0.3:
		_check(cold.exposure() > 0.0, "de dia, na chuva e no aberto, esfria (%.2f/s)" % cold.exposure())
	# Dentro da caverna: sem riscos e sem o frio da chuva.
	Game.player.global_position = Vector3(1.0, _level.ground_height(1.0, 72.0) + 0.2, 72.0)
	await _wait(0.4)
	_check(not rain.emitting or rain.amount_ratio < 0.05, "dentro da caverna não chove")
	_check(cold.exposure() <= 0.0, "dentro da caverna, de dia, a chuva não esfria (%.2f)" % cold.exposure())
	# Os bichos ouvem menos na chuva: o mesmo barulho dá menos atenção.
	var data := Weather.save_data()
	_check(float(data.rain_left) > 0.0, "a chuva vai no save")
	Weather.rain_left = 0.2
	Weather._pass(0.3)
	_check(not Weather.is_raining(), "a chuva acaba quando as horas passam")


func _herds() -> void:
	Weather.stop_rain()
	Weather.rain = 0.0
	var herds := _herd_list()
	_check(herds.size() == ForestLayout.DEER_HOMES.size(), "%d manadas" % herds.size())
	var deer := 0
	for herd in herds:
		deer += herd.members.size()
	_check(deer >= herds.size() * Tuning.HERD_SIZE_MIN, "%d cervos no vale" % deer)
	# De dia: anda pelo vale; os cervos ficam em volta do centro.
	Clock.hour = 9.0
	var herd: Herd = herds[0]
	herd._update_mode()
	_check(herd.mode == Herd.Mode.ROAM, "de dia a manada anda pelo vale (modo %d)" % herd.mode)
	var start := herd.center
	await _wait(25.0)
	_check(herd.center.distance_to(start) > 3.0, "o centro andou (%.1f m)" % herd.center.distance_to(start))
	var spread := 0.0
	for member in herd.members:
		spread = maxf(spread, Vector2(member.position.x, member.position.z).distance_to(herd.center))
	_check(spread < 30.0, "os cervos seguem a manada (o mais longe a %.1f m)" % spread)
	# Fim da tarde: volta para a casa (sem uma chuva sorteada no meio).
	Weather.stop_rain()
	Weather.rain = 0.0
	Clock.hour = 18.5
	await _wait(0.6)
	_check(herd.mode == Herd.Mode.HOMEWARD, "no fim da tarde volta para casa (modo %d)" % herd.mode)
	# Noite (o goblin dormiu): em casa, deitados.
	Clock.hour = 22.0
	herd._on_skipped(0.0)
	await _wait(1.5)
	var sleeping := herd.members.filter(func(member: Deer) -> bool: return member.state == Animal.State.SLEEP).size()
	_check(herd.mode == Herd.Mode.SLEEP and sleeping == herd.members.size(), "de noite dormem em casa (%d de %d)" % [sleeping, herd.members.size()])
	var near_home := herd.members.all(func(member: Deer) -> bool: return Vector2(member.position.x, member.position.z).distance_to(herd.home) < 6.0)
	_check(near_home, "dormem juntos na casa")
	# Dormindo, quase não enxergam: o goblin de pé a 15 m não acorda ninguém por um tempo.
	var sleeper: Deer = herd.members[0]
	var p := sleeper.global_position + Vector3(15.0, 0.0, 0.0)
	Game.player.global_position = Vector3(p.x, _level.ground_height(p.x, p.z) + 0.2, p.z)
	await _wait(3.0)
	_check(sleeper.state == Animal.State.SLEEP, "dormindo, não vê o goblin parado a 15 m")
	Game.player.global_position = Vector3(1.0, _level.ground_height(1.0, 72.0) + 0.2, 72.0)
	# Amanheceu: acordam.
	Clock.hour = 7.0
	await _wait(1.0)
	var awake := herd.members.filter(func(member: Deer) -> bool: return member.state != Animal.State.SLEEP).size()
	_check(awake == herd.members.size(), "de manhã acordam (%d)" % awake)
	# Chuva: vai para debaixo das árvores.
	Weather.start_rain(3.0)
	Weather.rain = 1.0
	await _wait(0.6)
	_check(herd.mode == Herd.Mode.SHELTER, "na chuva se abriga (modo %d)" % herd.mode)
	var spot := Vector3(herd._shelter.x, 0.0, herd._shelter.y)
	var cover: float = _level.canopy_at(spot)
	var cover_before: float = _level.canopy_at(Vector3(herd.center.x, 0.0, herd.center.y))
	_check(cover >= cover_before, "o abrigo tem mais copa (%.2f, antes %.2f)" % [cover, cover_before])
	await _until(func() -> bool: return herd.center.distance_to(herd._shelter) < 1.0, 120.0)
	await _wait(8.0)
	var under := herd.members.filter(func(member: Deer) -> bool: return Vector2(member.position.x, member.position.z).distance_to(herd._shelter) < 6.0).size()
	_check(under >= herd.members.size() - 1, "a manada está debaixo das árvores (%d de %d)" % [under, herd.members.size()])
	Weather.stop_rain()
	Weather.rain = 0.0
	# Reposição: um cervo some e volta no amanhecer (goblin longe).
	var lost: Deer = herd.members[0]
	lost.queue_free()
	await _wait(0.2)
	herd._prune()
	var before := herd.members.size()
	herd._on_day_started(Clock.day + 1)
	_check(herd.members.size() == herd.size and herd.members.size() > before, "a manada se repõe ao amanhecer (%d → %d)" % [before, herd.members.size()])


func _hunt() -> void:
	var deer := _calm_deer()
	# Escada do corpo: atento, encara, bate a pata.
	deer.awareness = 0.0
	deer._enter(Animal.State.GRAZE)
	deer.awareness = 0.2
	deer._think(0.016, Vector2(deer.position.x, deer.position.z))
	_check(deer.state == Animal.State.IDLE, "atento: para de pastar e ergue a cabeça")
	deer.awareness = 0.5
	deer._think(0.016, Vector2(deer.position.x, deer.position.z))
	_check(deer.state == Animal.State.SUSPICIOUS, "desconfiado: encara")
	deer.awareness = 0.7
	deer._think(0.016, Vector2(deer.position.x, deer.position.z))
	_check(deer._stomped, "quase fugindo: bate a pata e bufa")
	# Ferido no corpo: sangra até cair.
	deer.awareness = 0.0
	deer._enter(Animal.State.GRAZE)
	deer.take_hit(1.0, deer.to_global(Vector3(0.0, 1.0, -0.3)), Vector3.FORWARD)
	_check(deer.state == Animal.State.FLEE and deer.health > 0.0, "ferido no corpo, foge (vida %.2f)" % deer.health)
	var hit_at := Time.get_ticks_msec()
	await _until(func() -> bool: return deer.state == Animal.State.DEAD, 120.0)
	_check(deer.state == Animal.State.DEAD, "sangrou até cair")
	print("[T] info: caiu em %.0f s de jogo" % ((Time.get_ticks_msec() - hit_at) / 1000.0 * float(Engine.physics_ticks_per_second) / 60.0))
	var bones := Inventory.count(&"bone")
	deer.interact(Game.player)
	_check(Inventory.count(&"bone") == bones + 2, "coletar o cervo dá ossos")


func _food() -> void:
	# Coleta.
	var field := _level.find_child("Forage", true, false) as ForageField
	var spots := field.spots()
	var mushrooms := spots.filter(func(spot: ForageSpot) -> bool: return spot.kind == &"mushroom").size()
	_check(mushrooms >= 15 and spots.size() - mushrooms >= 6, "lugares de coleta: %d cogumelos, %d frutinhas" % [mushrooms, spots.size() - mushrooms])
	var bush: ForageSpot = spots.filter(func(spot: ForageSpot) -> bool: return spot.kind == &"berries")[0]
	var berries := Inventory.count(&"berries")
	bush.interact(Game.player)
	_check(Inventory.count(&"berries") == berries + 3 and not bush.ready_to_pick(), "colheu frutinhas e o arbusto esvaziou")
	_check(bush.interaction_prompt() == "", "colhido, não oferece colher de novo")
	Clock.day += Tuning.FORAGE_REGROW_DAYS
	bush.refresh()
	_check(bush.ready_to_pick(), "dias depois, voltou a dar")
	var picked := field.save_data()
	_check((picked.picked as Array).size() == spots.size(), "a coleta vai no save")
	# Carne que estraga, a mais velha primeiro.
	Inventory.remove(&"meat", Inventory.count(&"meat"))
	Inventory.remove(&"rotten_meat", Inventory.count(&"rotten_meat"))
	Inventory.add(&"meat", 1)
	Inventory.age(30.0)
	Inventory.add(&"meat", 1)
	Inventory.age(8.0)
	_check(Inventory.count(&"meat") == 1 and Inventory.count(&"rotten_meat") == 1, "a carne velha estragou e a nova não (crua %d, estragada %d)" % [Inventory.count(&"meat"), Inventory.count(&"rotten_meat")])
	Inventory.add(&"cooked_meat", 1)
	Inventory.age(40.0)
	_check(Inventory.count(&"cooked_meat") >= 1, "a assada aguenta mais")
	var saved := Inventory.save_data()
	Inventory.load_data(saved)
	_check(Inventory.oldest_age(&"cooked_meat") >= 39.0, "a idade da carne vai no save (%.0f h)" % Inventory.oldest_age(&"cooked_meat"))
	# Comer: frutinhas antes da carne crua.
	var eat := Game.player.get_node("EatAbility") as EatAbility
	Inventory.remove(&"cooked_meat", Inventory.count(&"cooked_meat"))
	Inventory.remove(&"smoked_meat", Inventory.count(&"smoked_meat"))
	_check(eat._pick_food() == &"berries", "come frutinhas antes da carne crua (%s)" % eat._pick_food())
	# Defumador.
	var rack := _level.find_child("SmokingRack", true, false) as SmokingRack
	rack.campfire.fuel = 3.0
	Inventory.add(&"meat", 3)
	var raw := Inventory.count(&"meat")
	rack.interact(Game.player)
	_check(rack.pieces.size() == 3 and Inventory.count(&"meat") == raw - 3, "pendurou 3 pedaços")
	_check(rack.interaction_prompt().begins_with("Defumando"), "mostra quanto falta: %s" % rack.interaction_prompt())
	rack._last_fuel = 3.0
	rack._on_skipped(Tuning.SMOKE_HOURS + 0.5)
	_check(rack.ready_count() == 3, "com o fogo aceso, defumou dormindo")
	var smoked := Inventory.count(&"smoked_meat")
	rack.interact(Game.player)
	_check(Inventory.count(&"smoked_meat") == smoked + 3 and rack.pieces.is_empty(), "pegou 3 carnes defumadas")
	Inventory.age(500.0)
	_check(Inventory.count(&"smoked_meat") == smoked + 3, "a defumada não estraga")
	# Sem fogo, não defuma.
	Inventory.add(&"meat", 1)
	rack.interact(Game.player)
	rack._last_fuel = 0.0
	rack._on_skipped(10.0)
	_check(rack.ready_count() == 0, "sem fogo, não defuma")
	rack.pieces.clear()


func _gear() -> void:
	var craft := Game.player.get_node("CraftAbility") as CraftAbility
	Inventory.add(&"wood", 20)
	Inventory.add(&"bone", 6)
	Inventory.add(&"hide", 6)
	var recipes := {}
	for recipe in Recipes.LIST:
		recipes[recipe.id] = recipe
	craft._finish(recipes[&"bone_arrows"])
	_check(Inventory.count(&"bone_arrow") >= 3, "fez flechas de osso")
	_check(Game.player._arrow_item() == &"bone_arrow", "a de osso vai primeiro na corda")
	_check(Arrow.damage_of(&"bone_arrow") > Arrow.damage_of(&"arrow"), "a de osso fere mais")
	craft._finish(recipes[&"yew_bow"])
	_check(Inventory.has(&"yew_bow") and Game.player.bow_speed() > 1.0, "arco de teixo: flecha mais rápida")
	_check(Game.player.tremor_factors.get(&"yew", 1.0) < 1.0, "arco de teixo: treme menos")
	_check(Recipes.missing(recipes[&"yew_bow"]) == "já tem", "o arco de teixo é um só")
	craft._finish(recipes[&"fur_bed"])
	var pelt := _level.find_child("Pelt", true, false)
	await _wait(0.1)
	_check(Inventory.has(&"fur_bed") and pelt._bed != null and pelt._bed.visible, "a cama de peles aparece na toca")
	Vitals.health = 50.0
	Vitals.satiety = 80.0
	Vitals.rest()
	_check(Vitals.health > 50.0 + Tuning.SLEEP_HEAL, "na cama de peles o sono cura mais (%.0f)" % Vitals.health)
	# Tocaia aos pés do goblin.
	var field := _tree.get_first_node_in_group(BlindField.GROUP) as BlindField
	Game.player.global_position = Vector3(20.0, _level.ground_height(20.0, 10.0) + 0.2, 10.0)
	await _wait(0.3)
	craft._finish(recipes[&"blind"])
	_check(field.get_child_count() == 1, "montou a tocaia")
	Input.action_press("crouch")
	await _wait(0.5)
	_check(Game.player.visibility_factors.get(&"blind", 1.0) == Tuning.BLIND_VISIBILITY, "agachado na tocaia, quase não é visto")
	Input.action_release("crouch")
	await _wait(0.3)
	_check(not Game.player.visibility_factors.has(&"blind"), "de pé, a tocaia não esconde")
	craft._finish(recipes[&"blind"])
	craft._finish(recipes[&"blind"])
	_check(field.get_child_count() == Tuning.BLIND_MAX, "no máximo %d tocaias" % Tuning.BLIND_MAX)
	# Prática.
	var steady_before: float = Game.player.tremor_factors.get(&"practice", 1.0)
	for i in 12:
		Events.arrow_hit.emit(&"deer")
	_check(Game.player.tremor_factors.get(&"practice", 1.0) < steady_before, "acertar flechas firma o braço (%.2f)" % Game.player.tremor_factors.get(&"practice", 1.0))
	Story.add_count(&"stealth_seconds", 600)
	(Game.player.get_node("Practice") as Practice)._apply()
	_check(Game.player.noise_factors.get(&"practice", 1.0) < 0.9, "andar agachado ensina a pisar leve (%.2f)" % Game.player.noise_factors.get(&"practice", 1.0))
	# Troféus.
	Story.add_count(&"deer_harvested", 3)
	Story.add_count(&"boar_harvested", 1)
	Story.add_count(&"old_deer_harvested", 1)
	await _wait(0.3)
	var trophies := _level.find_child("Trophies", true, false) as Trophies
	_check(trophies.get_child_count() >= 4, "troféus na parede (%d)" % trophies.get_child_count())


func _beasts() -> void:
	# O Velho.
	var old: OldDeer = _level.spawn_old_deer(Vector2(40.0, -60.0))
	_check(old != null and old.max_health == 4.0 and old.scale.x > 1.2, "o Velho apareceu, maior e mais forte")
	Clock.hour = 19.5
	Game.player.global_position = Vector3(1.0, _level.ground_height(1.0, 72.0) + 0.2, 72.0)
	await _wait(0.3)
	_check(not is_instance_valid(old), "no fim da tarde, longe do goblin, ele vai embora")
	Clock.hour = 10.0
	# O javali investe de perto.
	var boar: Boar = null
	for node in _tree.get_nodes_in_group(&"animals"):
		if node is Boar and (node as Animal).state != Animal.State.DEAD:
			boar = node
			break
	_check(boar != null, "há javalis no vale")
	var p := boar.global_position + Vector3(Tuning.BOAR_CHARGE_RANGE * 0.6, 0.0, 0.0)
	Game.player.global_position = Vector3(p.x, _level.ground_height(p.x, p.z) + 0.2, p.z)
	await _wait(0.3)
	Vitals.health = 100.0
	boar.awareness = 1.0
	await _until(func() -> bool: return boar.charge != Boar.Charge.NONE, 2.0)
	_check(boar.charge == Boar.Charge.RUN, "de perto, o javali investe")
	await _until(func() -> bool: return Vitals.health < 100.0, 5.0)
	_check(Vitals.health <= 100.0 - Tuning.BOAR_DAMAGE + 0.1, "a investida fere (%.0f)" % Vitals.health)
	await _until(func() -> bool: return boar.state == Animal.State.FLEE, 20.0)
	_check(boar.state == Animal.State.FLEE and boar.charges_left == 0, "depois das investidas, foge")
	# De longe, só foge.
	var far: Boar = null
	for node in _tree.get_nodes_in_group(&"animals"):
		if node is Boar and node != boar and (node as Animal).state != Animal.State.DEAD:
			far = node
			break
	if far != null:
		var q := far.global_position + Vector3(25.0, 0.0, 0.0)
		Game.player.global_position = Vector3(q.x, _level.ground_height(q.x, q.z) + 0.2, q.z)
		await _wait(0.2)
		far.awareness = 1.0
		await _wait(0.5)
		_check(far.charge == Boar.Charge.NONE and far.state == Animal.State.FLEE, "de longe, o javali foge")
	Vitals.health = 100.0


func _aim() -> void:
	Game.player.global_position = Vector3(20.0, _level.ground_height(20.0, 10.0) + 0.2, 10.0)
	Inventory.add(&"bow", 1)
	Inventory.add(&"arrow", 5)
	await _wait(0.3)
	var guide := Game.player.get_node("AimGuide") as AimGuide
	Input.action_press("aim")
	Input.action_press("attack")
	await _wait(1.2)
	_check(guide._mesh.get_surface_count() == 0, "puxando sem prender o ar, nada aparece")
	Input.action_press("hold_breath")
	await _wait(0.6)
	_check(guide._mesh.get_surface_count() > 0, "com o ar preso, o arco da flecha aparece")
	Input.action_release("hold_breath")
	Input.action_release("attack")
	Input.action_release("aim")
	await _wait(1.0)


func _save() -> void:
	Weather.start_rain(2.0)
	var rack := _level.find_child("SmokingRack", true, false) as SmokingRack
	rack.pieces = [1.5, 2.0]
	(_tree.get_first_node_in_group(BlindField.GROUP) as BlindField).build_at(Vector3(20.0, 0.0, 10.0), 0.0, false)
	var payload := SaveSystem.snapshot()
	Weather.stop_rain()
	rack.pieces.clear()
	SaveSystem.restore(payload)
	await _wait(0.2)
	_check(Weather.is_raining(), "a chuva volta com o save")
	rack = _level.find_child("SmokingRack", true, false) as SmokingRack
	_check(rack.pieces.size() == 2, "a carne no defumador volta com o save")
	var blinds := _tree.get_first_node_in_group(BlindField.GROUP) as BlindField
	_check(blinds.get_child_count() >= 1, "as tocaias voltam com o save")
	Weather.stop_rain()


# --- Ajudas -------------------------------------------------------------------------------------

func _herd_list() -> Array[Herd]:
	var list: Array[Herd] = []
	for node in _level.get_node("Animals").get_children():
		if node is Herd:
			list.append(node)
	return list


func _calm_deer() -> Deer:
	for herd in _herd_list():
		for member in herd.members:
			if is_instance_valid(member) and member.state != Animal.State.DEAD:
				return member
	return null


func _until(condition: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not condition.call():
		await _wait(0.1)
		left -= 0.1


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
