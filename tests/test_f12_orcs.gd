extends RefCounted
## F12 de ponta a ponta (docs/plano_combate.md §7, experimental): os orcs nascem com o corpo e a
## arma certos, veem e ouvem o goblin, vão ver onde a pedra caiu, gritam e chamam os outros, atacam
## com a arma de verdade (a defesa segura e o aparo ajoelha), levam golpes por zona e armadura,
## perdem a moral e fogem, são revistados, espantam os bichos, não entram na toca e vão embora no
## fim da tarde. --case=<nome> roda um só (padrão: todos).

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := ["spawn", "senses", "stone", "fight", "zones", "armor", "group", "loot", "animals", "cave", "leave", "arrival"]
	for case: String in cases:
		if only == "" or only == case:
			print("[T] --- %s" % case)
			_reset()
			await _wait(0.2)
			await call("_" + case)
	_reset()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _spawn() -> void:
	var scout := _band.spawn(&"scout", _at(30.0, 0.0))
	var warrior := _band.spawn(&"warrior", _at(33.0, 0.0))
	await _wait(0.3)
	_check(scout.health == Tuning.ORC_HEALTH[&"scout"] and warrior.health == Tuning.ORC_HEALTH[&"warrior"], "vida do batedor e do guerreiro")
	_check(scout.weapon_item == &"orc_axe" and warrior.weapon_item == &"orc_sword", "machado no batedor, espada no guerreiro")
	var helmet_scout := scout._model.find_child("Elmo", true, false) as Node3D
	var helmet_warrior := warrior._model.find_child("Elmo", true, false) as Node3D
	_check(helmet_scout != null and not helmet_scout.visible and helmet_warrior.visible, "só o guerreiro usa elmo")
	_check(scout._animator != null, "o orc usa o animador do goblin")
	var head := scout._animator.bone_position("cabeca")
	_check(head.y - scout.global_position.y > 1.15, "o orc tem o dobro do goblin (pescoço a %.2f m)" % (head.y - scout.global_position.y))
	_check(scout.is_on_floor(), "o orc fica no chão")


func _senses() -> void:
	# De pé, andando, na frente do orc: ele vê e entra na luta.
	var orc := _band.spawn(&"scout", _at(30.0, 0.0))
	await _wait(0.2)
	orc.set_physics_process(false)
	_face(orc, Vector3(30.0, 0.0, -12.0))
	orc.set_physics_process(true)
	_put(Vector3(30.0, 0.0, -10.0))
	Input.action_press("move_left")
	await _until(func() -> bool: return orc.state == Orc.State.COMBAT, 6.0)
	Input.action_release("move_left")
	_check(orc.state == Orc.State.COMBAT, "vê o goblin de pé na frente dele e luta (%d)" % orc.state)
	orc.queue_free()
	await _wait(0.2)
	# Agachado, parado, atrás dele e longe: ele não percebe.
	var calm := _band.spawn(&"scout", _at(30.0, 0.0))
	await _wait(0.2)
	calm.route = []
	_face(calm, Vector3(30.0, 0.0, 20.0))
	_put(Vector3(30.0, 0.0, -14.0))
	Input.action_press("crouch")
	await _wait(4.0)
	Input.action_release("crouch")
	_check(calm.state == Orc.State.PATROL and calm.awareness < Tuning.ORC_SUSPICIOUS, "agachado atrás e longe, não percebe (%.2f)" % calm.awareness)
	_check(calm.unaware(), "desprevenido (o golpe furtivo vale)")


func _stone() -> void:
	var orc := _band.spawn(&"scout", _at(30.0, 0.0))
	orc.route = []
	_put(Vector3(30.0, 0.0, -40.0))
	await _wait(0.3)
	var spot := Vector3(38.0, _level.ground_height(38.0, 4.0), 4.0)
	Events.noise_made.emit(spot, Tuning.STONE_NOISE)
	await _wait(0.2)
	_check(orc.state == Orc.State.INVESTIGATE, "ouve a pedra e vai ver (%d)" % orc.state)
	await _until(func() -> bool: return Vector2(orc.global_position.x, orc.global_position.z).distance_to(Vector2(spot.x, spot.z)) < 2.5, 12.0)
	_check(Vector2(orc.global_position.x, orc.global_position.z).distance_to(Vector2(spot.x, spot.z)) < 2.5, "chegou onde a pedra caiu")


func _fight() -> void:
	Inventory.add(&"club")
	Inventory.hold(&"club")
	var melee := Game.player.get_node("MeleeAbility") as MeleeAbility
	_put(Vector3(30.0, 0.0, -3.0))
	var orc := _band.spawn(&"scout", _at(30.0, 0.0))
	await _wait(0.3)
	orc.alert(Game.player.global_position)
	_check(orc.state == Orc.State.COMBAT, "alerta: luta")
	# Sem defender: o golpe da arma chega e fere.
	await _until(func() -> bool: return Vitals.health < 100.0, 10.0)
	_check(Vitals.health < 100.0 and Vitals.health >= 100.0 - Tuning.ORC_HEAVY_DAMAGE - 0.1, "o golpe do orc fere o goblin (%.0f)" % Vitals.health)
	# Defendendo bem na hora: apara, e o orc ajoelha.
	Vitals.health = 100.0
	melee.stamina = 1.0
	melee.poise = 0.0
	# Ergue a defesa quando a arma começa a descer (a janela abre). Às vezes o golpe passa longe:
	# tenta até seis golpes.
	for attempt in 6:
		await _until(func() -> bool: return Game.player.can_act() and not orc.is_attacking(), 4.0)
		Input.action_release("aim")
		await _until(func() -> bool: return bool(orc._attack.get("active", false)), 8.0)
		Game.player.face(orc.global_position - Game.player.global_position)
		Input.action_press("aim")
		await _until(func() -> bool: return orc.state == Orc.State.KNEEL or Vitals.health < 100.0 or orc._attack.is_empty(), 2.0)
		if orc.state == Orc.State.KNEEL or Vitals.health < 100.0:
			break
	Input.action_release("aim")
	_check(orc.state == Orc.State.KNEEL, "aparado, o orc ajoelha (%d, vida %.0f)" % [orc.state, Vitals.health])
	if orc.state == Orc.State.KNEEL:
		var head := orc._animator.bone_position("cabeca")
		_check(head.y - orc.global_position.y < 1.45, "ajoelhado, a cabeça desce (%.2f m)" % (head.y - orc.global_position.y))
	await _wait(Tuning.ORC_KNEEL + 0.3)
	_check(orc.state == Orc.State.COMBAT, "e volta a lutar")


func _zones() -> void:
	var orc := _band.spawn(&"scout", _at(30.0, 0.0))
	await _wait(0.3)
	orc.set_physics_process(false)
	var head := orc._animator.bone_position("cabeca") + Vector3.UP * 0.18
	var health := orc.health
	orc.strike(0.5, &"cut", head, Vector3.FORWARD, 0.0)
	_check(is_equal_approx(health - orc.health, 0.5 * Tuning.ORC_HEAD_DAMAGE), "na cabeça vale o dobro (%.2f)" % (health - orc.health))
	health = orc.health
	orc.strike(0.5, &"cut", orc.global_position + Vector3.UP * 0.3, Vector3.FORWARD, 0.0)
	_check(is_equal_approx(health - orc.health, 0.5 * Tuning.ORC_LEG_DAMAGE) and orc._limp > 0.0, "na perna vale menos e ele manca")
	health = orc.health
	orc.take_hit(0.5, orc.global_position + Vector3.UP * 1.1, Vector3.FORWARD, 1.0)
	_check(is_equal_approx(health - orc.health, 1.0), "a flechada no peito do batedor entra inteira")
	orc.poise = 0.0
	orc.strike(0.1, &"blunt", orc.global_position + Vector3.UP * 1.1, Vector3.FORWARD, 0.7)
	_check(orc.state == Orc.State.KNEEL, "o porrete quebra a postura: ajoelha")


func _armor() -> void:
	var orc := _band.spawn(&"warrior", _at(30.0, 0.0))
	await _wait(0.3)
	orc.set_physics_process(false)
	var chest := orc.global_position + Vector3.UP * 1.1
	var health := orc.health
	orc.strike(1.0, &"cut", chest, Vector3.FORWARD, 0.0)
	_check(is_equal_approx(health - orc.health, Tuning.ORC_IRON[&"cut"]), "o peitoral segura o corte (%.2f)" % (health - orc.health))
	health = orc.health
	orc.strike(1.0, &"blunt", chest, Vector3.FORWARD, 0.0)
	_check(is_equal_approx(health - orc.health, Tuning.ORC_IRON[&"blunt"]), "o impacto passa quase inteiro (%.2f)" % (health - orc.health))
	health = orc.health
	var head := orc._animator.bone_position("cabeca") + Vector3.UP * 0.18
	orc.strike(1.0, &"cut", head, Vector3.FORWARD, 0.0)
	_check(is_equal_approx(health - orc.health, Tuning.ORC_HEAD_DAMAGE / Tuning.ORC_HELMET), "o elmo segura parte do golpe na cabeça (%.2f)" % (health - orc.health))


func _group() -> void:
	_put(Vector3(30.0, 0.0, -6.0))
	var first := _band.spawn(&"scout", _at(30.0, 0.0))
	var second := _band.spawn(&"scout", _at(36.0, 4.0))
	var third := _band.spawn(&"warrior", _at(24.0, 4.0))
	var far := _band.spawn(&"scout", _at(30.0, 80.0))
	await _wait(0.3)
	first.alert(Game.player.global_position)
	first._shouted = false
	first._enter(Orc.State.COMBAT)
	_check(second.state == Orc.State.COMBAT and third.state == Orc.State.COMBAT, "o grito chama os de perto")
	_check(far.state != Orc.State.COMBAT, "o de longe não ouve")
	var allowed := [first, second, third].filter(func(orc: Orc) -> bool: return _band.may_attack(orc)).size()
	_check(allowed == Tuning.ORC_ATTACKERS_AT_ONCE, "só %d atacam de cada vez (%d)" % [Tuning.ORC_ATTACKERS_AT_ONCE, allowed])
	# Um cai: os outros perdem a moral; com a moral baixa e ferido, foge.
	var morale := second.morale
	first.strike(99.0, &"cut", first.global_position + Vector3.UP, Vector3.FORWARD, 0.0)
	_check(first.is_dead(), "morreu")
	_check(second.morale < morale, "o companheiro morto abala os outros (%.2f)" % second.morale)
	second.strike(1.4, &"cut", second.global_position + Vector3.UP * 1.1, Vector3.FORWARD, 0.0)
	second.lose_heart(0.2)
	_check(second.state == Orc.State.FLEE, "com a moral baixa, foge (%d, moral %.2f)" % [second.state, second.morale])
	_check(Story.count(&"orc_killed") >= 1, "o Story conta os orcs mortos")


func _loot() -> void:
	var orc := _band.spawn(&"scout", _at(30.0, 0.0))
	await _wait(0.3)
	orc.strike(99.0, &"cut", orc.global_position + Vector3.UP, Vector3.FORWARD, 0.0)
	await _wait(1.2)
	_check(orc.interaction_prompt() == "Revistar o orc", "morto, dá para revistar")
	orc.interact(Game.player)
	_check(Inventory.has(&"orc_axe") and Inventory.wear(&"orc_axe") < 0.7, "fica com o machado, gasto (%.2f)" % Inventory.wear(&"orc_axe"))
	_check(Inventory.has(&"iron_scrap") and Inventory.has(&"orc_ration"), "sucata e carne seca")
	_check(orc.interaction_prompt() == "", "não revista duas vezes")
	Vitals.satiety = 40.0
	_check(not Vitals.eat(&"orc_ration") and Vitals.satiety > 60.0, "a carne seca enche e não faz mal")


func _animals() -> void:
	var deer: Deer = null
	for node in _tree.get_nodes_in_group(&"animals"):
		if node is Deer and not node is WhiteDeer and (node as Animal).state != Animal.State.DEAD:
			deer = node
			break
	_check(deer != null, "há cervo")
	if deer == null:
		return
	_put(deer.global_position + Vector3(60.0, 0.0, 0.0))
	deer.awareness = 0.0
	var at := deer.global_position + Vector3(6.0, 0.0, 0.0)
	var orc := _band.spawn(&"scout", at)
	orc.route = [deer.global_position + Vector3(-20.0, 0.0, 0.0)]
	await _until(func() -> bool: return deer.state == Animal.State.FLEE, 8.0)
	_check(deer.state == Animal.State.FLEE, "o cervo foge do orc (%d, atenção %.2f)" % [deer.state, deer.awareness])


func _cave() -> void:
	# O goblin corre para dentro da toca: o orc para na beira.
	var mouth := Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y)
	_put(mouth + Vector3(0.0, 0.0, 2.0))
	var orc := _band.spawn(&"scout", mouth + Vector3(0.0, 0.0, -Tuning.ORC_CAVE_KEEP_OUT - 6.0))
	await _wait(0.3)
	orc.alert(Game.player.global_position)
	await _wait(8.0)
	var distance := Vector2(orc.global_position.x, orc.global_position.z).distance_to(ForestLayout.CAVE_CENTER)
	_check(distance > Tuning.ORC_CAVE_KEEP_OUT - 1.0, "o orc não entra na toca (a %.1f m do centro)" % distance)
	_check(Vitals.health == 100.0, "e o goblin está a salvo")


func _leave() -> void:
	var orc := _band.spawn(&"scout", _at(30.0, 0.0))
	await _wait(0.3)
	Clock.hour = Tuning.ORC_LEAVE_HOUR + 0.1
	await _wait(0.3)
	_check(orc.state == Orc.State.LEAVE, "no fim da tarde vai embora")
	Clock.hour = 10.0


func _arrival() -> void:
	Clock.day = Tuning.ORC_PATROL_DAY
	_band.arrive()
	await _wait(0.3)
	_check(_band.orcs().size() == 3, "no dia %d chegam o batedor e a patrulha (%d)" % [Clock.day, _band.orcs().size()])
	var player_flat := Vector2(Game.player.global_position.x, Game.player.global_position.z)
	var close := _band.orcs().filter(func(orc: Orc) -> bool:
		return Vector2(orc.global_position.x, orc.global_position.z).distance_to(player_flat) < 40.0).size()
	_check(close == 0, "chegam longe do goblin")
	var route := _band.orcs()[0].route
	_check(route.size() >= 4, "andam uma rota em volta do vale (%d pontos)" % route.size())
	Story.set_flag(&"orcs_off", true)
	await _wait(0.3)
	_check(_band.get_child_count() == 0, "o console desliga os orcs (orcs_off)")
	Story.set_flag(&"orcs_off", false)
	Clock.day = 1


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	for action in ["attack", "aim", "crouch", "move_left"]:
		Input.action_release(action)
	for orc in _band.get_children():
		orc.queue_free()
	Inventory.clear()
	Vitals.reset()
	Clock.hour = 10.0
	Weather.stop_rain()
	Weather.rain = 0.0


func _at(x: float, z: float) -> Vector3:
	return Vector3(x, _level.ground_height(x, z), z)


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _face(orc: Orc, point: Vector3) -> void:
	var to := point - orc.global_position
	orc._target_yaw = atan2(to.x, to.z)
	orc._visual.rotation.y = orc._target_yaw


func _until(condition: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not condition.call():
		await _wait(0.05)
		left -= 0.05


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
