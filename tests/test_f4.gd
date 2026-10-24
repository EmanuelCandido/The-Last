extends RefCounted
## Fase 4 de ponta a ponta: as 4 pistas do Ato I, o musgo, a Vigilância e os corvos, os
## flashes (anotações), a porta da ruína, o sarcófago e o ritual, o cervo branco e a
## Reciclagem.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	var level := Game.current_level
	Clock.hour = 10.0
	await _test_clues(Game.player, level)
	await _test_moss_and_vigilance(Game.player, level)
	await _test_flashes()
	await _test_door(Game.player, level)
	await _test_sarcophagus(Game.player, level)
	await _test_save()
	await _test_recycle(Game.player, level)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- Ato I: as quatro pistas ----------------------------------------------------------
func _test_clues(player: Player, level: Node) -> void:
	for marks in [1, 2, 3, 4]:
		Story.marks = marks
		Story.trigger(&"woke", &"sleep")
	for flag: StringName in [&"clue_deer_freeze", &"clue_crow_stare", &"clue_beep", &"clue_fan"]:
		_check(Story.has_flag(flag), "beat ligou %s" % flag)

	# Cervo que trava: andando, na tela, a menos de 30 m. (O corvo espera: o goblin na caverna.)
	var cave: Node3D = level.find_child("Cave", true, false)
	var deer: Animal = _tree.get_nodes_in_group(&"deer")[0]
	var at := Vector2(deer.global_position.x, deer.global_position.z) + Vector2(0.0, 14.0)
	_put(player, at)
	deer.sight_range = 1.0
	deer.hearing_range = 1.0
	deer.smell_range = 0.0
	deer._enter(Animal.State.WALK)
	var to := deer.global_position - player.global_position
	player.set_camera_angles(rad_to_deg(atan2(-to.x, -to.z)), -5.0)
	var frozen := false
	for i in 40:
		await _wait(0.1)
		if deer.is_frozen():
			frozen = true
			break
	_check(frozen and Story.has_flag(&"clue_deer_freeze_seen"), "o cervo travou no meio do passo")

	# Corvo que encara: fora da caverna, de dia, pousa perto e não crocita.
	await _wait(0.6)
	var watchers: Watchers = level.find_child("Watchers", true, false)
	var staring: Crow = null
	for child in watchers.get_children():
		if child is Crow:
			staring = child
	_check(Story.has_flag(&"clue_crow_stare_seen") and staring != null and staring.silent, "um corvo pousou para encarar, calado")
	if staring != null:
		var landed := Vector2(staring._perch.x, staring._perch.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
		_check(absf(landed - Tuning.CLUE_CROW_DISTANCE) < 1.5, "pousou a %.1f m" % landed)

	# Bipes: de noite, dentro da caverna.
	Clock.hour = 23.0
	var inside := cave.to_global(Vector3(0.5, 0.0, 1.0))
	_put(player, Vector2(inside.x, inside.z))
	await _wait(0.4)
	_check(Story.has_flag(&"clue_beep_seen"), "os bipes tocaram na caverna, de noite")
	Clock.hour = 10.0

	# Ventilador: na próxima rajada forte (procura um lugar ventando agora).
	var windy := Vector3.INF
	for i in 400:
		var p := Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
		var spot := Vector3(p.x, level.ground_height(p.x, p.y), p.y)
		if ForestLayout.cave_interior(p) < 0.1 and Wind.strength_at(spot) > Tuning.CLUE_FAN_GUST + 0.05:
			windy = spot
			break
	if windy == Vector3.INF:
		print("[T] (sem rajada forte agora: pista do ventilador não testada)")
	else:
		_put(player, Vector2(windy.x, windy.z))
		await _wait(0.4)
		_check(Story.has_flag(&"clue_fan_seen"), "o ventilador vazou na rajada (vento %.2f)" % Wind.strength_at(windy))


# --- Musgo, Ato II, Vigilância e corvos ----------------------------------------------
func _test_moss_and_vigilance(player: Player, level: Node) -> void:
	Story.add_vigilance(50.0)
	_check(Story.vigilance == 0.0, "no Ato I a Vigilância não conta")
	# F10: o musgo cai no 5º risco com um cervo coletado.
	Story.marks = 5
	Story.add_count(&"deer_harvested")
	Story.trigger(&"woke", &"sleep")
	_check(Story.act == 2 and Story.has_flag(&"moss_fell"), "o musgo caiu: Ato II")
	Events.crow_shot.emit()
	_check(is_equal_approx(Story.vigilance, Tuning.VIGILANCE_CROW_SHOT), "corvo abatido: +%.0f" % Tuning.VIGILANCE_CROW_SHOT)
	Events.ate.emit(&"cooked_meat")
	_check(is_equal_approx(Story.vigilance, Tuning.VIGILANCE_CROW_SHOT + Tuning.VIGILANCE_COOKED_MEAT), "carne assada: %.0f" % Tuning.VIGILANCE_COOKED_MEAT)
	# Sentinelas: na boca da caverna e no ninho da ruína.
	await _wait(0.5)
	var watchers: Watchers = level.find_child("Watchers", true, false)
	var ruin: Ruin = level.find_child("Ruin", true, false)
	var at_cave := 0
	var at_ruin := 0
	for child in watchers.get_children():
		if child is Crow and not (child as Crow).dead:
			if (child as Crow)._perch.distance_to(Vector3(ForestLayout.CAVE_CROW.x, (child as Crow)._perch.y, ForestLayout.CAVE_CROW.y)) < 0.5:
				at_cave += 1
			if (child as Crow)._perch.distance_to(ruin.nest_point()) < 0.5:
				at_ruin += 1
	_check(at_cave == 1 and at_ruin == 1, "sentinelas na caverna (%d) e na ruína (%d)" % [at_cave, at_ruin])
	await _wait(Crow.LANDING_TIME + 0.3)
	var mouth := Vector2(ForestLayout.CAVE_CROW.x - 3.0, ForestLayout.CAVE_CROW.y - 4.0)
	_put(player, mouth)
	await _wait(0.2)
	_check(Watchers.watching(player.global_position + Vector3.UP * 0.5), "a sentinela da caverna vê o goblin na boca")
	# Ponto cego (R2) tira as sentinelas.
	Story.set_flag(&"blind_spot")
	await _wait(0.3)
	_check(watchers._sentinels.is_empty(), "ponto cego: as sentinelas foram embora")
	Story.set_flag(&"blind_spot", false)


# --- Flashes: anotações e a ruína liberada ---------------------------------------------
func _test_flashes() -> void:
	var flashes: Array = []
	Events.flash_requested.connect(func(n: int) -> void: flashes.append(n))
	for i in 3:
		Events.slept.emit()
		Events.woke_up.emit(&"sleep")
	_check(flashes == [1, 2, 3], "flashes 1, 2 e 3 pedidos (%s)" % [flashes])
	_check(Story.notes.size() == 3 and "NÃO COMA A CARNE DO CERVO BRANCO." in Story.notes, "três anotações novas")
	_check(Story.has_flag(StoryBeats.DOOR_FLAG), "flash 3: Ari viu a ruína pela janela")


# --- A porta da ruína ------------------------------------------------------------------
func _test_door(player: Player, level: Node) -> void:
	var ruin: Ruin = level.find_child("Ruin", true, false)
	var door := ruin.door
	Story.set_flag(StoryBeats.DOOR_FLAG, false)
	var front := ruin.to_global(Vector3(-0.6, 0.0, 1.5))
	_put(player, Vector2(front.x, front.z))
	await _wait(0.3)
	_check(player._prompt.contains("Girar os discos"), "na porta: '%s'" % player._prompt)
	await _press("interact")
	await _wait(0.3)
	_check(door._active and not player.can_act(), "entrou nos discos (o goblin para)")
	door.set_code("2714")
	await _press("interact")
	_check(not door.is_open, "antes do flash 3 os discos não travam")
	Story.set_flag(StoryBeats.DOOR_FLAG)
	door.set_code("2700")
	await _press("interact")
	_check(not door.is_open, "código errado: nada")
	# Gira de verdade: disco 3 para 1, disco 4 para 4.
	door.set_code("2700")
	door.selected = 2
	await _press("move_forward")
	await _press("move_right")
	for i in 4:
		await _press("move_forward")
	_check(door.code() == "2714", "girou os discos até %s" % door.code())
	await _press("interact")
	_check(door.is_open and Story.has_flag(RuinDoor.OPEN_FLAG), "2714: a porta abre")
	await _wait(0.3)
	_check(player.can_act(), "saiu dos discos")
	await _wait(Tuning.RUIN_DOOR_OPEN_TIME + 0.3)
	_check(door._body.process_mode == Node.PROCESS_MODE_DISABLED, "a laje desceu e não bloqueia mais")
	# Entra andando na sala-espelho.
	Input.action_press("move_forward")
	player.set_camera_angles(0.0, -5.0)
	var inside := false
	for i in 60:
		await _wait(0.1)
		if ruin.in_mirror_room(player.global_position):
			inside = true
			break
	Input.action_release("move_forward")
	_check(inside, "entrou andando na sala-espelho")


# --- Sarcófago e ritual ----------------------------------------------------------------
func _test_sarcophagus(player: Player, level: Node) -> void:
	var ruin: Ruin = level.find_child("Ruin", true, false)
	var sarcophagus := ruin.sarcophagus
	var beside := sarcophagus.to_global(Vector3(0.9, 0.0, 0.0))
	player.global_position = beside + Vector3.UP * 0.05
	await _wait(0.4)
	_check(player._prompt.contains("Deitar no sarcófago"), "perto do sarcófago: '%s'" % player._prompt)
	await _press("interact")
	await _wait(1.8)
	_check(player.lying and player.ritual_place == &"sarcophagus", "deitou no sarcófago")
	var rituals: Array = []
	Events.ritual_completed.connect(func(place: StringName) -> void: rituals.append(place), CONNECT_ONE_SHOT)
	var before := Story.vigilance
	Input.action_press("hold_breath")
	await _wait(Tuning.BREATH_MAX_SECONDS + 1.0)
	_check(player.breath_held, "no sarcófago o ar não acaba (%.0f s)" % (Tuning.BREATH_MAX_SECONDS + 1.0))
	await _wait(Tuning.RITUAL_BREATH_SECONDS - Tuning.BREATH_MAX_SECONDS)
	Input.action_release("hold_breath")
	_check(rituals == [&"sarcophagus"], "ritual completo no sarcófago")
	_check(Story.vigilance >= before + Tuning.VIGILANCE_RITUAL - 0.01, "o ritual sobe a Vigilância (%.0f -> %.0f)" % [before, Story.vigilance])
	# F5: o ritual no sarcófago acorda Ari no Abrigo; volta na hora para seguir o roteiro da F4.
	await _wait_awake()
	_check(Game.awake, "o ritual acordou Ari no Abrigo (F5)")
	Game.return_to_forest(true)
	Story.set_act(2)
	await _press("jump")
	await _wait(3.5)
	_check(not player.lying and player.can_act(), "levantou e anda de novo")


# --- Save e load -----------------------------------------------------------------------
func _test_save() -> void:
	var vigilance := Story.vigilance
	Story.complete_objective(&"fuse_pulled")
	_check(SaveSystem.save_game(), "salvou")
	Story.vigilance = 0.0
	Story.set_flag(RuinDoor.OPEN_FLAG, false)
	_check(SaveSystem.load_game(), "carregou")
	await _tree.process_frame
	_check(is_equal_approx(Story.vigilance, vigilance) and Story.has_flag(RuinDoor.OPEN_FLAG) and "fuse_pulled" in Story.objectives,
		"load devolve Vigilância, porta aberta e objetivos")


# --- Cervo branco e Reciclagem ---------------------------------------------------------
func _test_recycle(player: Player, level: Node) -> void:
	# Vigilância em 100 pede a Reciclagem (aqui só se confere o pedido).
	Events.recycle_requested.disconnect(Game.recycle)
	var asked: Array = []
	var capture := func(reason: StringName) -> void: asked.append(reason)
	Events.recycle_requested.connect(capture)
	var before := Story.vigilance
	Story.add_vigilance(100.0)
	_check(asked == [&"vigilance"], "Vigilância em 100 pede a Reciclagem")
	Events.recycle_requested.disconnect(capture)
	Events.recycle_requested.connect(Game.recycle)
	Story.vigilance = Tuning.VIGILANCE_WHITE_DEER + 5.0
	# Cervo branco: aparece no dia novo com Vigilância alta.
	var watchers: Watchers = level.find_child("Watchers", true, false)
	_put(player, Vector2(14.0, 12.0))
	Clock.day_started.emit(Clock.day + 1)
	var white: WhiteDeer = watchers._white_deer
	_check(white != null and is_instance_valid(white), "Vigilância ≥ %.0f: o cervo branco apareceu" % Tuning.VIGILANCE_WHITE_DEER)
	white.take_hit(1.0, white.global_position + Vector3.UP * 1.3, Vector3.FORWARD, 10.0)
	_check(white.state == Animal.State.DEAD, "abatido")
	white.interact(player)
	_check(Inventory.count(&"white_meat") == 2, "deu 2 carnes brancas")
	# Comer é o sedativo: a floresta se desmancha e Ari acorda no dia 1.
	for food: StringName in [&"meat", &"cooked_meat"]:
		Inventory.remove(food, Inventory.count(food))
	var cycle := Story.cycle
	var marks := Story.marks
	var old_marks := Story.old_marks
	var notes := Story.notes.size()
	Clock.day = 9
	await _press("eat")
	await _wait(Tuning.EAT_TIME + Tuning.RECYCLE_SECONDS + 1.5)
	_check(Story.cycle == cycle + 1, "ciclo %d -> %d" % [cycle, Story.cycle])
	_check(Story.marks == 0 and Story.old_marks == old_marks + marks, "os riscos viraram antigos (%d)" % Story.old_marks)
	_check(Inventory.items().values().all(func(n: int) -> bool: return n == 0), "inventário zerado")
	_check(Clock.day == 1, "acordou no dia 1")
	_check(is_equal_approx(Story.vigilance, Tuning.VIGILANCE_AFTER_RECYCLE), "Vigilância voltou a %.0f" % Story.vigilance)
	_check(Story.act == 2 and Story.notes.size() == notes and Story.has_flag(&"moss_fell"), "ato, anotações e flags ficaram")
	_check(not ("fuse_pulled" in Story.objectives), "o último objetivo real foi desfeito")
	var bow := Game.current_level.find_child("BowPickup", true, false)
	_check(bow != null and not bow.is_queued_for_deletion(), "o arco voltou para o chão da caverna")


# --- Ajudantes -------------------------------------------------------------------------
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


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, false).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])


## Desde a F7 o primeiro ritual passa pelo falso travamento (~6 s) antes de Ari acordar: espera
## a cena acabar e Ari ficar de pé no Abrigo.
## `standing` = false espera só Ari aparecer (ainda deitado, na cena de acordar).
func _wait_awake(standing := true, limit := 25.0) -> void:
	var waited := 0.0
	while waited < limit:
		var ari: Ari = Game.shelter.ari if Game.shelter != null else null
		if Game.awake and ari != null and (ari.controls or not standing):
			return
		await _tree.process_frame
		waited += _tree.root.get_process_delta_time()
