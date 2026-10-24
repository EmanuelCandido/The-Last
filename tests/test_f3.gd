extends RefCounted
## Fase 3 de ponta a ponta: pegadas e cervo ferido, pedra tocando a manada, farejar,
## prender o ar, lama, fabricar (flechas, emplumadas, laço, roupa, tocha), laço, corvo.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	var player := Game.player
	var level := Game.current_level
	Clock.hour = 10.0
	Inventory.add(&"bow")
	Inventory.add(&"arrow", 6)

	await _test_tracks(player)
	await _test_stone(player)
	await _test_sniff(player)
	await _test_breath(player)
	await _test_mud(player, level)
	await _test_craft(player)
	await _test_snare(player, level)
	await _test_crow(player, level)
	_test_feathered()
	await _test_save()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- Pegadas: um cervo ferido foge e deixa pegadas e sangue até onde está ------------
func _test_tracks(player: Player) -> void:
	var deer := _nearest_animal(Deer, ForestLayout.MEADOW)
	_put(player, Vector2(deer.global_position.x, deer.global_position.z) + Vector2(25.0, 0.0))
	deer.take_hit(0.3, deer.global_position + Vector3.UP, Vector3.FORWARD)
	_check(deer.state == Animal.State.FLEE and deer.health < deer.max_health, "cervo ferido foge")
	var start := deer.global_position
	await _wait(6.0)
	var fled := start.distance_to(deer.global_position)
	var last := Tracks.nearest(&"deer", deer.global_position, 3.0)
	var first := Tracks.nearest(&"deer", start, 3.0)
	_check(fled > 10.0, "correu %.0f m" % fled)
	_check(last != Vector3.INF and first != Vector3.INF, "pegadas do começo ao fim da fuga")
	var trail := 0
	for i in 12:
		if Tracks.nearest(&"deer", start.lerp(deer.global_position, i / 11.0), 4.0) != Vector3.INF:
			trail += 1
	_check(trail >= 10, "rastro contínuo (%d de 12 pontos com pegada)" % trail)


# --- Pedra: cai do outro lado da manada e ela foge da pedra, não do goblin -----------
func _test_stone(player: Player) -> void:
	var herd := _herd_near(Vector2(-40.0, -22.0))
	# A manada junta, pastando, num raio de 6 m. Só a pedra pode assustar: os sentidos
	# dela para o goblin ficam curtos durante o teste (visão, faro e audição têm teste próprio).
	var level := Game.current_level
	var center := Vector3(-40.0, level.ground_height(-40.0, -22.0), -22.0)
	var senses := []
	for deer in herd:
		senses.append([deer.sight_range, deer.smell_range, deer.hearing_range])
		deer.sight_range = 1.0
		deer.smell_range = 0.0
		deer.hearing_range = 1.0
		var spot := Vector2(center.x, center.z) + Vector2.from_angle(randf() * TAU) * randf_range(1.0, 6.0)
		deer.home = spot
		deer.position = Vector3(spot.x, level.ground_height(spot.x, spot.y), spot.y)
		deer.awareness = 0.0
		deer.speed = 0.0
		deer._enter(Animal.State.GRAZE)
	# Caçada de verdade: agachado a 22 m, com o vento vindo da manada (ela não sente o
	# cheiro). A pedra vai cair 3 m além dela.
	var wind := Vector2(Wind.direction)
	var from := Vector2(center.x, center.z) + wind * 22.0
	_put(player, from)
	Input.action_press("crouch")
	Inventory.add(&"stone", 3)
	_check(Inventory.count(&"stone") == 3, "tem 3 pedras")
	# A pedra vai cair do outro lado da manada, 4 m além do meio dela.
	var toward := -wind
	var target := center + Vector3(toward.x, 0.0, toward.y) * 4.0
	player.set_camera_angles(rad_to_deg(atan2(-toward.x, -toward.y)), 0.0)
	player.set_camera_angles(rad_to_deg(atan2(-toward.x, -toward.y)), _pitch_to_hit(player, target))
	await _wait(0.2)
	_check(herd.all(func(deer: Animal) -> bool: return deer.state != Animal.State.FLEE), "a manada ainda não viu o goblin")
	var landed: Array = []
	Events.noise_made.connect(func(at: Vector3, radius: float) -> void:
		if is_equal_approx(radius, Tuning.STONE_NOISE):
			landed.append(at), CONNECT_ONE_SHOT)
	var origin := player.global_position
	await _press("throw")
	for i in 40:
		if not landed.is_empty():
			break
		await _wait(0.1)
	await _wait(0.6)
	_check(Inventory.count(&"stone") == 2, "jogou uma pedra")
	_check(not landed.is_empty(), "a pedra caiu e fez barulho")
	if landed.is_empty():
		return
	var hit: Vector3 = landed[0]
	print("[T] pedra caiu a %.1f m do goblin, %.1f m da manada" % [origin.distance_to(hit), hit.distance_to(center)])
	var scared := 0
	var from_stone := 0
	for deer in herd:
		print("[T]   cervo a %.1f m da pedra: estado %d, atenção %.2f, perigo a %.1f m da pedra e %.1f m do goblin" % [
			deer.global_position.distance_to(hit), deer.state, deer.awareness,
			deer._threat.distance_to(Vector2(hit.x, hit.z)), deer._threat.distance_to(Vector2(origin.x, origin.z))])
		if deer.awareness > Animal.SUSPICIOUS:
			scared += 1
		if deer._threat.distance_to(Vector2(hit.x, hit.z)) < 3.0:
			from_stone += 1
	_check(scared == herd.size(), "a manada toda se assustou (%d de %d)" % [scared, herd.size()])
	_check(from_stone >= herd.size() - 1, "o perigo que sentiram é a pedra, não o goblin (%d de %d)" % [from_stone, herd.size()])
	# Cada cervo corre para longe da pedra (com ela do outro lado, vêm para o lado do goblin).
	var stone_at := Vector2(hit.x, hit.z)
	var starts: Array[Vector2] = []
	for deer in herd:
		starts.append(Vector2(deer.global_position.x, deer.global_position.z))
	await _wait(2.0)
	var away := 0
	for i in herd.size():
		var now := Vector2(herd[i].global_position.x, herd[i].global_position.z)
		if now.distance_to(stone_at) > starts[i].distance_to(stone_at) + 3.0:
			away += 1
	_check(away >= herd.size() - 1, "a manada correu para longe da pedra (%d de %d)" % [away, herd.size()])
	Input.action_release("crouch")
	for i in herd.size():
		herd[i].sight_range = senses[i][0]
		herd[i].smell_range = senses[i][1]
		herd[i].hearing_range = senses[i][2]
	var stone: ThrownStone = null
	for node in _tree.get_nodes_in_group(&"interactable"):
		if node is ThrownStone:
			stone = node
	_check(stone != null, "a pedra ficou no chão para pegar")


# --- Farejar: trilha de cheiro de um bicho contra o vento; sem barulho; até 6 s -----
func _test_sniff(player: Player) -> void:
	_put(player, Vector2(14.0, 12.0))
	var sniff: SniffAbility = player.get_node("SniffAbility")
	var rabbit := _nearest_animal(Rabbit, Vector2(14.0, 12.0))
	# O coelho fica de onde o vento vem (o cheiro dele vem até o goblin).
	var upwind := Vector2(14.0, 12.0) - Wind.direction * 20.0
	rabbit.home = upwind
	rabbit.position = Vector3(upwind.x, Game.current_level.ground_height(upwind.x, upwind.y), upwind.y)
	rabbit.speed = 0.0
	rabbit._enter(Animal.State.IDLE)
	player.exert(1.0)
	await _wait(0.2)
	_check(player.noise_level() > 0.1, "ofegante parado, respira alto (%.2f)" % player.noise_level())
	Input.action_press("sniff")
	await _wait(1.0)
	_check(player.sniffing and player.is_crouching(), "farejando, agachado")
	_check(player.noise_level() == 0.0, "farejando não faz barulho")
	_check(sniff._trails.has(rabbit), "trilha de cheiro do coelho contra o vento")
	_check(AudioServer.get_bus_volume_db(0) < -6.0, "o som abafou (%.1f dB)" % AudioServer.get_bus_volume_db(0))
	await _wait(5.6)
	_check(not player.sniffing, "parou sozinho depois de %.0f s" % Tuning.SNIFF_MAX_SECONDS)
	await _wait(0.5)
	_check(not player.sniffing, "segurando, não volta a farejar")
	Input.action_release("sniff")
	await _wait(1.0)
	_check(AudioServer.get_bus_volume_db(0) > -2.0, "o som voltou (%.1f dB)" % AudioServer.get_bus_volume_db(0))


# --- Prender o ar: silêncio parado, arco firme, e solta alto depois de 12 s ---------
func _test_breath(player: Player) -> void:
	var breath: BreathControl = player.get_node("BreathControl")
	player.exert(1.0)
	Input.action_press("hold_breath")
	await _wait(0.5)
	_check(player.breath_held, "prendeu o ar")
	_check(player.noise_level() == 0.0, "prendendo o ar, ofegante parado fica em silêncio")
	var gasps: Array = []
	Events.noise_made.connect(func(_at: Vector3, radius: float) -> void:
		if is_equal_approx(radius, Tuning.BREATH_GASP_NOISE):
			gasps.append(radius), CONNECT_ONE_SHOT)
	await _wait(Tuning.BREATH_MAX_SECONDS)
	_check(not player.breath_held and not gasps.is_empty(), "não aguentou: soltou o ar alto")
	_check(player._animator.exertion() > 0.45, "ficou ofegante (%.2f)" % player._animator.exertion())
	await _wait(0.5)
	_check(not breath.is_holding(), "sem fôlego, não prende de novo logo")
	Input.action_release("hold_breath")
	await _wait(Tuning.BREATH_GASP_SECONDS)


# --- Lama: esfrega numa poça, fica menos visível e cheira menos ---------------------
func _test_mud(player: Player, level: Node) -> void:
	var spot: Vector2 = ForestLayout.MUD_SPOTS[0]
	_put(player, spot + Vector2(0.8, 0.0))
	await _wait(0.4)
	var seen := player.visibility()
	var smell := player.scent_level()
	_check(player._prompt.contains("Esfregar lama"), "na poça: '%s'" % player._prompt)
	await _press("interact")
	await _wait(Tuning.MUD_RUB_TIME + 0.3)
	_check(Vitals.mud > 0.99, "coberto de lama (%.2f)" % Vitals.mud)
	_check(player.visibility() < seen * (Tuning.MUD_VISIBILITY + 0.02), "menos visível (%.2f -> %.2f)" % [seen, player.visibility()])
	_check(player.scent_level() < smell * (Tuning.MUD_SCENT + 0.02), "cheira menos (%.2f -> %.2f)" % [smell, player.scent_level()])
	_check("Coberto de lama" in Vitals.status_words(), "o pause diz 'Coberto de lama'")


# --- Fabricar: lista com R, número ou E, custo sai no fim -------------------------
func _test_craft(player: Player) -> void:
	_put(player, Vector2(14.0, 12.0))
	var craft: CraftAbility = player.get_node("CraftAbility")
	Inventory.add(&"wood", 4)
	Inventory.add(&"hide", 4)
	Inventory.add(&"feather", 2)
	var arrows := Inventory.count(&"arrow")
	await _press("craft")
	_check(craft.is_open(), "R abre a lista")
	await _press_key(KEY_1)
	await _wait(Tuning.CRAFT_TIME + 0.2)
	_check(Inventory.count(&"arrow") == arrows + 3 and Inventory.count(&"wood") == 3, "1: flechas (+3, -1 madeira)")
	await _press_key(KEY_2)
	await _wait(Tuning.CRAFT_TIME + 0.2)
	_check(Inventory.count(&"feathered_arrow") == 3 and Inventory.count(&"feather") == 0, "2: flechas emplumadas")
	# Seta para baixo até a roupa e E.
	craft._select(0)
	for i in 3:
		await _press("ui_down")
	await _press("interact")
	await _wait(Tuning.CRAFT_TIME + 0.2)
	_check(Inventory.has(&"clothes") and Inventory.count(&"hide") == 1, "roupa de couro (3 couros)")
	_check(Recipes.missing(Recipes.LIST[3]) == "já tem", "roupa só uma vez")
	var cold: ColdExposure = player.get_node("ColdExposure")
	Clock.hour = 23.0
	await _wait(0.2)
	var dressed := cold.exposure()
	Inventory.remove(&"clothes")
	var naked := cold.exposure()
	Inventory.add(&"clothes")
	_check(absf(dressed - naked * Tuning.CLOTHES_COLD_FACTOR) < 0.05, "roupa: frio pela metade (%.2f / %.2f)" % [dressed, naked])
	Clock.hour = 10.0
	await _press_key(KEY_3)
	await _wait(Tuning.CRAFT_TIME + 0.2)
	_check(Inventory.count(&"snare") == 1, "3: laço (1 couro + 1 madeira)")
	await _press_key(KEY_5)
	await _wait(Tuning.CRAFT_TIME + 0.2)
	var carry: TorchCarry = player.get_node("TorchCarry")
	_check(carry.torch != null and player.torch_held, "5: tocha acesa na mão")
	_check(Campfire.distance_to_fire(player.global_position) < 1.5, "a tocha é fogo (esquenta, espanta lobo)")
	var seen := player.visibility()
	_check(player.visibility_factors.has(&"torch"), "com a tocha, os bichos veem mais (%.2f)" % seen)
	await _press_key(KEY_5)
	_check(Inventory.count(&"wood") == 0, "sem madeira: não faz outra")
	await _press("craft")
	_check(not craft.is_open(), "R fecha a lista")
	# Mirar finca a tocha.
	Input.action_press("aim")
	await _wait(0.3)
	Input.action_release("aim")
	var planted: Torch = null
	for node in _tree.get_nodes_in_group(Campfire.FIRE_GROUP):
		if node is Torch:
			planted = node
	_check(planted != null and planted.planted and carry.torch == null, "mirando, fincou a tocha no chão")
	await _wait(0.6)
	await _press("interact")
	await _wait(1.3)
	_check(carry.torch == planted, "E pega a tocha de volta")
	planted._left = 0.5
	await _wait(1.0)
	_check(carry.torch == null and not player.torch_held, "a tocha apagou")


# --- Laço: armar sobre pegadas de coelho, coelho cai, coletar, recolher -----------
func _test_snare(player: Player, level: Node) -> void:
	var field: SnareField = level.find_child("Snares", true, false)
	var at := Vector2(20.0, 30.0)
	_put(player, at)
	var ground := Vector3(at.x + 1.0, level.ground_height(at.x + 1.0, at.y), at.y)
	Tracks.stamp(ground, Vector3.UP, 0.0, Vector2(0.09, 0.17), &"rabbit")
	await _wait(0.3)
	_check(player._prompt.contains("Armar o laço"), "perto de pegada de coelho: '%s'" % player._prompt)
	await _press("interact")
	await _wait(2.6)
	_check(field.snares().size() == 1 and Inventory.count(&"snare") == 0, "laço armado")
	var snare := field.snares()[0]
	field.catch_now(snare)
	_check(snare.state == Snare.State.CAUGHT and snare.rabbit != null, "o laço pegou um coelho")
	var hides := Inventory.count(&"hide")
	_put(player, Vector2(snare.global_position.x + 0.6, snare.global_position.z))
	await _wait(0.3)
	_check(player._prompt.contains("Coletar"), "coelho no laço para coletar: '%s'" % player._prompt)
	await _press("interact")
	await _wait(2.6)
	_check(Inventory.count(&"hide") == hides + 1 and snare.state == Snare.State.SPRUNG, "coletou o coelho")
	await _wait(0.2)
	_check(player._prompt.contains("Recolher o laço"), "depois: '%s'" % player._prompt)
	await _press("interact")
	await _wait(1.3)
	_check(Inventory.count(&"snare") == 1 and field.snares().is_empty(), "recolheu o laço")
	# Dormindo, as horas contam: 60% em 24 h. Com 20 laços, uns pegam e outros não.
	for i in 20:
		field.place(Vector3(at.x + i, 0.0, at.y + 8.0))
	field._on_time_skipped(24.0)
	var caught := field.snares().filter(func(s: Snare) -> bool: return s.state == Snare.State.CAUGHT).size()
	_check(caught >= 6 and caught <= 19, "em 24 h, %d de 20 laços pegaram (esperado ~12)" % caught)
	Inventory.add(&"snare", 0)


# --- Corvo: flechada derruba, cai, dá penas e devolve a flecha --------------------
func _test_crow(player: Player, level: Node) -> void:
	var flock: CrowFlock = level.find_child("Crows", true, false)
	flock.set_process(false)
	var crow: Crow = flock.flying()[0]
	var below := crow.global_position + Vector3.DOWN * 4.0
	var arrow := Arrow.new()
	level.add_child(arrow)
	arrow.launch(below, Vector3.UP, 1.0, [])
	await _wait(0.4)
	_check(crow.dead, "flechada derrubou o corvo")
	_check(flock.flying().size() == flock.count - 1, "saiu do bando")
	flock.set_process(true)
	for i in 60:
		if crow.interaction_prompt() != "":
			break
		await _wait(0.1)
	_check(crow.interaction_prompt() == "Pegar as penas", "caiu no chão")
	var arrows := Inventory.count(&"arrow")
	var feathers := Inventory.count(&"feather")
	crow.interact(player)
	_check(Inventory.count(&"feather") == feathers + Tuning.CROW_FEATHERS and Inventory.count(&"arrow") == arrows + 1, "+2 penas e a flecha de volta")
	_check(Story.count(&"crow_harvested") == 1, "a história conta o corvo")


# --- Emplumada cai menos ---------------------------------------------------------
func _test_feathered() -> void:
	var drops := []
	for item: StringName in [&"arrow", &"feathered_arrow"]:
		var arrow := Arrow.new()
		arrow.item = item
		var v := Vector3(0.0, 0.0, -30.0)
		for i in 30:
			v += Vector3.DOWN * Arrow.GRAVITY * (Tuning.FEATHERED_GRAVITY if arrow.is_feathered() else 1.0) / 60.0
		drops.append(-v.y)
		arrow.free()
	_check(drops[1] < drops[0] * 0.7, "emplumada cai menos (%.1f vs %.1f m/s em 0,5 s)" % [drops[1], drops[0]])


# --- Save e load guardam lama e laços ---------------------------------------------
func _test_save() -> void:
	Vitals.mud = 0.7
	var field: SnareField = Game.current_level.find_child("Snares", true, false)
	var count := field.snares().size()
	_check(SaveSystem.save_game(), "salvou")
	Vitals.mud = 0.0
	_check(SaveSystem.load_game(), "carregou")
	await _tree.process_frame
	_check(absf(Vitals.mud - 0.7) < 0.01, "lama voltou (%.2f)" % Vitals.mud)
	_check(field.snares().size() == count, "laços voltaram (%d)" % field.snares().size())


# --- Ajudantes ---------------------------------------------------------------------
## Simula o voo da pedra sobre o relevo e acha a inclinação da câmera (graus) que cai mais
## perto de `target`.
func _pitch_to_hit(player: Player, target: Vector3) -> float:
	var level := Game.current_level
	var best := 0.0
	var best_error := INF
	var flat := player.aim_direction()
	flat = Vector3(flat.x, 0.0, flat.z).normalized()
	for pitch in range(-30, 35):
		var aim := flat * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
		aim.y += Tuning.STONE_LOFT
		var v := aim.normalized() * Tuning.STONE_SPEED
		var p := player.global_position + Vector3.UP * 0.75
		for i in 400:
			v += Vector3.DOWN * ThrownStone.GRAVITY / 60.0
			p += v / 60.0
			if p.y < float(level.ground_height(p.x, p.z)):
				break
		var error := Vector2(p.x - target.x, p.z - target.z).length()
		if error < best_error:
			best_error = error
			best = pitch
	return best



func _nearest_animal(type: Variant, near: Vector2) -> Animal:
	var best: Animal = null
	for node in _tree.get_nodes_in_group(&"animals"):
		var animal := node as Animal
		if is_instance_of(animal, type) and animal.state != Animal.State.DEAD:
			if best == null or Vector2(animal.global_position.x, animal.global_position.z).distance_to(near) < Vector2(best.global_position.x, best.global_position.z).distance_to(near):
				best = animal
	return best


func _herd_near(near: Vector2) -> Array[Animal]:
	var herd: Array[Animal] = []
	for node in _tree.get_nodes_in_group(&"deer"):
		var deer := node as Animal
		if deer.state != Animal.State.DEAD and Vector2(deer.global_position.x, deer.global_position.z).distance_to(near) < 45.0:
			herd.append(deer)
	return herd


func _put(player: Node3D, at: Vector2) -> void:
	player.global_position = Vector3(at.x, Game.current_level.ground_height(at.x, at.y) + 0.05, at.y)
	player.velocity = Vector3.ZERO


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tree.physics_frame


func _press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tree.physics_frame


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, false).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
