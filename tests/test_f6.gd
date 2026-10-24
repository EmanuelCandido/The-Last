extends RefCounted
## Fase 6 de ponta a ponta: R1 a R4 em sequência (cada um destrava o seguinte), ser sedado
## desfaz o que foi feito na visita, a lucidez acabando (desmaio), a ronda do Zelador, a
## bateria baixa depois do R3, os efeitos na floresta (ponto cego, o vazio ao norte, Ato IV),
## a Reciclagem desfazendo o último objetivo e a morte no Ato III virando visita curta.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	Story.set_flag(&"moss_fell")
	Story.set_flag(&"first_wake")
	Story.set_act(3)
	Story.vigilance = 20.0
	await _test_r1()
	await _test_capture_undoes()
	await _test_r2()
	await _test_r3()
	await _test_r4()
	await _test_faint()
	await _test_round()
	await _test_recycle()
	await _test_death_visit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	MetaFiles.remove_all()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- R1: ver o monitor e a janela e voltar -----------------------------------------------------
func _test_r1() -> void:
	var shelter := await _visit()
	var ari := shelter.ari
	_check(shelter.visit.active and is_equal_approx(shelter.visit.total, Tuning.LUCIDITY_SECONDS), "visita com %.0f s de lucidez" % shelter.visit.total)
	_check(shelter._fuse.interaction_prompt() == "", "antes do R1 o fusível não aparece")
	ari.global_position = shelter.to_global(Vector3(-4.0, 0.0, 3.5))
	await _look_at(shelter.monitor.global_transform * Vector3(0.0, VitalsMonitor.SCREEN_HEIGHT, 0.0))
	await _wait(0.3)
	await _look_at(shelter.blinds.global_position)
	await _wait(0.3)
	_check(shelter.visit.pending.has(&"room_seen"), "viu o monitor e a janela: R1 pendente")
	_check(not Story.has_flag(&"room_seen"), "R1 ainda não vale (só ao deitar)")
	await _back_to_capsule()
	_check(Story.has_flag(&"room_seen") and Story.objectives.has("room_seen"), "deitou na cápsula: R1 concluído")
	_check(Story.notes.has("Deixei uma coisa fora daqui. Fora do jogo."), "anotação do R1")


# --- Ser sedado perde o que foi feito na visita --------------------------------------------------
func _test_capture_undoes() -> void:
	var shelter := await _visit()
	var ari := shelter.ari
	await _use(shelter._fuse, "Puxar o fusível do sensor")
	_check(shelter.visit.pending.has(&"blind_spot") and not shelter.sensor_active(), "puxou o fusível: sensor apagado, R2 pendente")
	var vigilance := Story.vigilance
	# Na frente da recarga, de pé: ele vê, fica vermelho e vem.
	ari.global_position = shelter.to_global(Vector3(8.6, 0.0, 0.0))
	await _look_at(shelter.caretaker.head.global_position)
	var found := false
	for i in 100:
		await _wait(0.1)
		found = found or shelter.keeper.state == Keeper.State.FOUND
		if not Game.awake:
			break
	_check(found, "o Zelador viu Ari (luz vermelha)")
	await _until(func() -> bool: return not Game.awake, 12.0)
	_check(not Game.awake, "sedado: acordou na floresta")
	_check(not Story.has_flag(&"blind_spot"), "ser pego desfaz o R2 feito na visita")
	_check(is_equal_approx(Story.vigilance - vigilance, Tuning.VIGILANCE_CAPTURED), "Vigilância +%.0f (sedado)" % (Story.vigilance - vigilance))
	_check(Game.player.global_position.distance_to(Game.player._spawn_transform.origin) < 0.5, "o goblin acordou na pele da caverna")
	await _wait(6.5)
	_check(Game.player.can_act(), "o goblin levantou")


# --- R2: o fusível, guardado ----------------------------------------------------------------------
func _test_r2() -> void:
	var shelter := await _visit()
	_check(shelter.sensor_active(), "na visita seguinte o sensor voltou (o Zelador consertou)")
	await _use(shelter._fuse, "Puxar o fusível do sensor")
	await _back_to_capsule()
	_check(Story.has_flag(&"blind_spot"), "R2 concluído: ponto cego")
	await _wait(1.0)
	var watchers: Watchers = Game.current_level.find_child("Watchers", true, false)
	_check(watchers._sentinels.is_empty(), "sem corvo sentinela na caverna e na ruína")


# --- R3: o alicate e o cabo do clima ---------------------------------------------------------
func _test_r3() -> void:
	var shelter := await _visit()
	_check(not shelter.sensor_active(), "depois do R2 o sensor fica apagado")
	var ari := shelter.ari
	ari.global_position = shelter.to_global(Vector3(-13.2, 0.0, 0.6))
	await _look_at(shelter._cable.global_position)
	await _wait(0.2)
	_check(ari._prompt.contains("Um cabo grosso") or ari._prompt == "", "sem alicate o cabo não corta: '%s'" % ari._prompt)
	await _use(shelter._pliers, "Pegar o alicate")
	_check(shelter.visit.has_pliers, "pegou o alicate")
	await _use(shelter._cable, "Cortar o cabo do clima")
	_check(shelter.visit.pending.has(&"climate_cut"), "cortou o cabo: R3 pendente")
	await _back_to_capsule()
	_check(Story.has_flag(&"climate_cut"), "R3 concluído")
	var void_node: NorthVoid = Game.current_level.find_child("NorthVoid", true, false)
	_check(void_node.open and void_node.openness(Vector3(0.0, 0.0, -70.0)) > 0.9, "o norte abriu (o vazio)")
	_check(void_node.openness(Vector3(0.0, 0.0, 60.0)) == 0.0, "no sul a neblina continua")


# --- R4: o cartão do peito, com ele dormente --------------------------------------------------
func _test_r4() -> void:
	var shelter := await _visit()
	_check(shelter.keeper.state == Keeper.State.DORMANT, "bateria baixa: o Zelador fica dormente na recarga")
	var ari := shelter.ari
	ari.global_position = shelter.to_global(Vector3(10.95, 0.0, 0.0))
	await _wait(3.0)
	_check(shelter.keeper.state == Keeper.State.DORMANT, "Ari parado, quieto: ele não acorda")
	await _use(shelter._card, "Pegar o cartão do peito dele")
	_check(shelter.visit.pending.has(&"access_card") and not shelter.caretaker._card.visible, "pegou o cartão")
	await _back_to_capsule()
	_check(Story.has_flag(&"access_card") and Story.act == 4, "R4 concluído: começa o Ato IV")
	_check(Story.objectives == PackedStringArray(["room_seen", "blind_spot", "climate_cut", "access_card"]), "R1–R4 em ordem: %s" % [Story.objectives])


# --- A lucidez acaba ------------------------------------------------------------------------
func _test_faint() -> void:
	var shelter := await _visit()
	_check(shelter.keeper.state == Keeper.State.DOCKED, "com o cartão tirado, a bateria volta (encaixado, acordado)")
	var vigilance := Story.vigilance
	shelter.visit.seconds_left = Tuning.LUCIDITY_WARNING * 0.5
	await _wait(1.0)
	_check(Game.vision.tunnel > 0.3, "nos últimos segundos a visão fecha (%.2f)" % Game.vision.tunnel)
	await _until(func() -> bool: return not Game.awake, 25.0)
	_check(not Game.awake, "a lucidez acabou: desmaiou e acordou na floresta")
	_check(is_equal_approx(Story.vigilance - vigilance, Tuning.VIGILANCE_FAINT), "Vigilância +%.0f (desmaio)" % (Story.vigilance - vigilance))
	_check(Game.vision.tunnel == 0.0, "a visão voltou")
	await _wait(6.5)


# --- A ronda ---------------------------------------------------------------------------------
func _test_round() -> void:
	Story.vigilance = 20.0
	var shelter := await _visit()
	var ari := shelter.ari
	# Escondido atrás da estante do meio do almoxarifado, parado.
	ari.global_position = shelter.to_global(Vector3(-12.4, 0.0, -0.8))
	var states := {}
	var vigilance := Story.vigilance
	for i in 600:
		await _wait(0.1)
		states[shelter.keeper.state] = true
		if Story.vigilance > vigilance or not Game.awake:
			break
	_check(states.has(Keeper.State.ROUND), "a ronda começou (luz verde, saiu da recarga)")
	_check(is_equal_approx(Story.vigilance - vigilance, Tuning.VIGILANCE_CAPSULE_EMPTY), "achou a cápsula vazia: Vigilância +%.0f" % (Story.vigilance - vigilance))
	await _until(func() -> bool: return shelter.keeper.state == Keeper.State.CHECK, Tuning.KEEPER_CAPSULE_CHECK + 3.0)
	_check(shelter.keeper.state == Keeper.State.CHECK, "depois de conferir a cápsula, procura Ari (âmbar)")
	await _back_to_capsule()


# --- A Reciclagem desfaz o último objetivo ----------------------------------------------------
func _test_recycle() -> void:
	Game.recycle(&"test")
	await _until(func() -> bool: return Story.cycle > Story.START_CYCLE, 15.0)
	await _wait(1.0)
	_check(not Story.has_flag(&"access_card") and Story.has_flag(&"climate_cut"), "Reciclagem: o R4 foi desfeito, o R3 ficou")
	_check(Story.act == 4, "o ato fica")
	_check(Story.objectives.size() == 3, "objetivos: %s" % [Story.objectives])
	var shelter := await _visit()
	_check(shelter.keeper.state == Keeper.State.DORMANT and shelter.caretaker._card.visible, "o cartão voltou ao peito dele")
	await _back_to_capsule()


# --- Morrer no Ato III vira visita curta -----------------------------------------------------------
func _test_death_visit() -> void:
	await _wait(6.5)
	var vigilance := Story.vigilance
	Vitals.damage(1000.0, &"test")
	await _until(func() -> bool: return Game.awake and Game.shelter.ari != null, 15.0)
	var shelter := Game.shelter
	_check(Game.awake and is_equal_approx(shelter.visit.total, Tuning.LUCIDITY_AFTER_DEATH), "morreu: acordou no Abrigo com %.0f s" % shelter.visit.total)
	_check(Story.vigilance - vigilance >= 20.0, "Vigilância +%.0f (morte no Ato III)" % (Story.vigilance - vigilance))
	_check(not Game.in_flash(), "sem flash de morte no Ato III")
	await _until(func() -> bool: return shelter.ari != null and shelter.ari.controls, 15.0)
	await _back_to_capsule()
	_check(Game.player.global_position.distance_to(Game.player._spawn_transform.origin) < 0.5, "de volta, o goblin está na pele")


# --- Auxiliares ------------------------------------------------------------------------------
func _visit() -> Shelter:
	Game.wake_in_shelter(true)
	await _wait(0.3)
	var shelter := Game.shelter
	_check(Game.awake and shelter.ari != null and shelter.ari.controls, "acordou no Abrigo")
	return shelter


## Olha para `point` e espera a mira pegar.
func _look_at(point: Vector3) -> void:
	var ari := Game.shelter.ari
	ari.look(point - ari.camera.global_position)
	await _wait(0.15)


## Chega perto de `item`, olha e aperta E (o caminho de verdade do jogador).
func _use(item: Node3D, prompt: String) -> void:
	var ari := Game.shelter.ari
	var to_item := item.global_position - ari.global_position
	to_item.y = 0.0
	if to_item.length() > 1.2:
		ari.global_position = item.global_position - to_item.normalized() * 1.0
		ari.global_position.y = Game.shelter.global_position.y
	await _look_at(item.global_position)
	await _wait(0.2)
	_check(ari._prompt.contains(prompt), "olhando: '%s'" % ari._prompt)
	await _press("interact")
	await _wait(0.3)


func _back_to_capsule() -> void:
	var shelter := Game.shelter
	var ari := shelter.ari
	ari.global_position = shelter.capsule.out_point()
	await _look_at(shelter.capsule.interaction_point())
	await _wait(0.2)
	await _press("interact")
	await _until(func() -> bool: return not Game.awake, 10.0)
	await _wait(0.3)


func _until(condition: Callable, seconds: float) -> void:
	var frames := 0
	while not condition.call() and frames < seconds * 60.0:
		await _tree.process_frame
		frames += 1


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
