extends RefCounted
## Fase 5 de ponta a ponta: os flashes 1 a 3 no escuro de cada sono do Ato II, o flash de
## morte, o ritual no sarcófago que acorda Ari no Abrigo (first_wake), andar mancando,
## rastejar, a perna que não corre, prender o ar, a persiana, não salvar acordado, voltar pela
## cápsula sem perder nada da floresta, a segunda visita e carregar um save acordado.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _snapshot := {}


func run() -> void:
	var player := Game.player
	var level := Game.current_level
	Story.set_flag(&"moss_fell")
	Story.set_act(2)
	for number in [1, 2, 3]:
		await _test_flash(player, number)
	_check(Story.has_flag(&"saw_ruin_window"), "o flash 3 liga saw_ruin_window (a porta aceita o código)")
	_check(Story.notes.size() >= 3, "as três anotações dos flashes entraram (%d)" % Story.notes.size())
	await _test_death_flash(player)
	await _test_first_wake(player, level)
	await _test_ari_body()
	await _test_blinds()
	await _test_return(player, level)
	await _test_second_visit_and_load()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- Flashes -----------------------------------------------------------------------------
func _test_flash(player: Player, number: int) -> void:
	var player_camera := _camera()
	var woke: Array = []
	Events.woke_up.connect(func(reason: StringName) -> void: woke.append(reason), CONNECT_ONE_SHOT)
	Clock.hour = 21.0
	Game.pass_out(&"sleep")
	var shelter := await _wait_flash()
	if shelter == null:
		_check(false, "flash %d: o Abrigo apareceu" % number)
		return
	_check(_camera() == shelter.eyes, "flash %d: a câmera está nos olhos de Ari, no Abrigo" % number)
	_check(Game.vision.amount > 0.5, "flash %d: visão borrada (%.2f)" % [number, Game.vision.amount])
	var arm: Node3D = shelter.capsule._occupied[2]
	_check(arm.visible, "flash %d: Ari deitado na cápsula (coberta e braço)" % number)
	var first_frame := Engine.get_process_frames()
	var moved := false
	var best_monitor := -1.0
	var nearest_lens := INF
	while shelter.visible and Engine.get_process_frames() - first_frame < 900:
		await _tree.process_frame
		moved = moved or shelter.caretaker.moving
		var eye := shelter.capsule.eye_point()
		var forward := -shelter.eyes.global_basis.z
		var screen := shelter.monitor.global_transform * Vector3(0.0, VitalsMonitor.SCREEN_HEIGHT, 0.0)
		best_monitor = maxf(best_monitor, forward.dot((screen - eye).normalized()))
		nearest_lens = minf(nearest_lens, shelter.caretaker.head.global_position.distance_to(eye))
	# Com --fixed-fps 60, um frame é 1/60 s de jogo (o tempo visível conta desde o 1º frame no Abrigo).
	var seconds := (Engine.get_process_frames() - first_frame) / 60.0 + 0.1
	var expected: float = Tuning.FLASH_SECONDS[number]
	_check(absf(seconds - expected) < 1.2, "flash %d durou %.1f s (esperado ~%.0f)" % [number, seconds, expected])
	match number:
		1:
			_check(moved, "flash 1: a silhueta do Zelador passou")
		2:
			_check(best_monitor > cos(deg_to_rad(30.0)), "flash 2: a cabeça caiu e olha o monitor (cos %.2f)" % best_monitor)
		3:
			_check(nearest_lens < 0.5, "flash 3: a lente chegou perto (%.2f m)" % nearest_lens)
	_check(Story.has_flag(StringName("flash_%d_seen" % number)), "flash %d marcado como visto" % number)
	_check(woke == [&"sleep"] and _camera() == player_camera, "flash %d: acordou na toca, câmera de volta no goblin" % number)
	await _wait(6.5)
	_check(player.can_act(), "flash %d: levantou e anda" % number)


func _test_death_flash(player: Player) -> void:
	var woke: Array = []
	Events.woke_up.connect(func(reason: StringName) -> void: woke.append(reason), CONNECT_ONE_SHOT)
	Vitals.damage(1000.0, &"test")
	var shelter := await _wait_flash()
	var first_frame := Engine.get_process_frames()
	while shelter != null and shelter.visible and Engine.get_process_frames() - first_frame < 900:
		await _tree.process_frame
	var seconds := (Engine.get_process_frames() - first_frame) / 60.0 + 0.1
	_check(shelter != null and absf(seconds - Tuning.DEATH_FLASH_SECONDS) < 1.2, "morte no Ato II: flash curto de %.1f s" % seconds)
	_check(woke == [&"death"], "acordou depois de morrer")
	await _wait(6.5)
	_check(player.can_act() and Vitals.health > 0.0, "vivo de novo")


# --- O ritual leva ao Abrigo -----------------------------------------------------------------
func _test_first_wake(player: Player, level: Node) -> void:
	var ruin: Ruin = level.find_child("Ruin", true, false)
	var sarcophagus := ruin.sarcophagus
	player.global_position = sarcophagus.to_global(Vector3(0.9, 0.0, 0.0)) + Vector3.UP * 0.05
	await _wait(0.4)
	await _press("interact")
	await _wait(1.8)
	_check(player.lying and player.ritual_place == &"sarcophagus", "deitou no sarcófago")
	Input.action_press("hold_breath")
	await _wait(Tuning.RITUAL_BREATH_SECONDS + 0.5)
	Input.action_release("hold_breath")
	_check(Story.act == 3 and Story.has_flag(&"first_wake"), "o ritual no sarcófago abre o Ato III (first_wake)")
	await _wait_awake(false)
	var shelter := Game.shelter
	_check(Game.awake and shelter.ari != null and _camera() == shelter.ari.camera, "Ari acordou no Abrigo, em primeira pessoa")
	_check(level.process_mode == Node.PROCESS_MODE_DISABLED, "a floresta parou")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"World")),
		"os sons da floresta calaram")
	var deer: Animal = _tree.get_nodes_in_group(&"deer")[0]
	_snapshot = {
		"items": Inventory.items().duplicate(), "day": Clock.day, "hour": Clock.hour, "marks": Story.marks,
		"satiety": Vitals.satiety, "player": player.global_position, "deer": deer.global_position, "deer_node": deer,
	}
	await _wait(2.0)
	_check(is_equal_approx(Clock.hour, _snapshot.hour) and is_equal_approx(Vitals.satiety, _snapshot.satiety),
		"acordado, o relógio e a fome param")
	_check(not shelter.ari.controls, "ainda na cena de acordar (sem controle)")
	await _wait(6.0)
	_check(shelter.ari.controls and Game.vision.lids < 0.05, "levantou da cápsula e tem controle")


func _test_ari_body() -> void:
	var ari := Game.shelter.ari
	ari.look(Vector3.RIGHT)
	await _wait(0.2)
	var start := ari.global_position
	var low := INF
	var high := -INF
	Input.action_press("move_forward")
	for i in 30:
		await _wait(0.1)
		low = minf(low, ari.head.position.y)
		high = maxf(high, ari.head.position.y)
	Input.action_release("move_forward")
	var walked := Vector2(ari.global_position.x - start.x, ari.global_position.z - start.z).length()
	_check(walked / 3.0 > 0.65 and walked / 3.0 < 1.05, "anda mancando a %.2f m/s (~0,9)" % (walked / 3.0))
	_check(high - low > 0.03, "a cabeça afunda no passo manco (%.3f m)" % (high - low))
	await _wait(0.5)
	ari.look(Vector3.LEFT)
	Input.action_press("crouch")
	await _wait(0.8)
	start = ari.global_position
	Input.action_press("move_forward")
	await _wait(2.0)
	Input.action_release("move_forward")
	var crawled := Vector2(ari.global_position.x - start.x, ari.global_position.z - start.z).length()
	_check(crawled / 2.0 > 0.25 and crawled / 2.0 < 0.5 and ari.head.position.y < 1.0, "rasteja a %.2f m/s, rente ao chão" % (crawled / 2.0))
	Input.action_release("crouch")
	await _wait(1.0)
	await _press("sprint")
	_check(Story.has_flag(&"leg_warned"), "Shift: \"A perna não deixa.\"")
	var start_y := ari.global_position.y
	await _press("jump")
	await _wait(0.3)
	_check(absf(ari.global_position.y - start_y) < 0.02, "sem pulo")
	Input.action_press("hold_breath")
	await _wait(5.0)
	_check(ari.breath_held and ari.noise_level() == 0.0, "prendendo o ar, parado, não faz barulho")
	await _wait(Tuning.ARI_BREATH_SECONDS - 4.0)
	_check(not ari.breath_held and ari.noise_level() == Tuning.ARI_NOISE_PANT, "passou de %.0f s: arfa alto" % Tuning.ARI_BREATH_SECONDS)
	Input.action_release("hold_breath")
	await _wait(Tuning.ARI_GASP_SECONDS + 0.5)
	_check(ari.noise_level() == 0.0, "o fôlego volta")


func _test_blinds() -> void:
	var shelter := Game.shelter
	var ari := shelter.ari
	ari.global_position = shelter.to_global(Vector3(-3.6, 0.0, 5.7))
	await _wait(0.2)
	ari.look(shelter.blinds.global_position - ari.camera.global_position)
	await _wait(0.3)
	_check(ari._prompt.contains("persiana"), "de frente para a janela: '%s'" % ari._prompt)
	var before := shelter.blinds.openness
	await _press("interact")
	await _wait(0.8)
	_check(absf(shelter.blinds.openness - before) > 0.4, "a persiana mexeu (%.2f -> %.2f)" % [before, shelter.blinds.openness])


func _test_return(player: Player, level: Node) -> void:
	var shelter := Game.shelter
	var ari := shelter.ari
	_check(not SaveSystem.save_game(), "acordado não dá para salvar")
	ari.global_position = shelter.capsule.out_point()
	await _wait(0.2)
	ari.look(shelter.capsule.interaction_point() - ari.camera.global_position)
	await _wait(0.3)
	_check(ari._prompt.contains("Deitar e fechar os olhos"), "olhando a cápsula: '%s'" % ari._prompt)
	await _press("interact")
	var frames := 0
	while Game.awake and frames < 600:
		await _tree.process_frame
		frames += 1
	# Compara no frame em que a floresta volta (depois disso os bichos já andam).
	var deer: Animal = _snapshot.deer_node
	var same := {
		"itens": Inventory.items() == _snapshot.items, "dia": Clock.day == _snapshot.day,
		"hora": absf(Clock.hour - _snapshot.hour) < 0.01, "riscos": Story.marks == _snapshot.marks,
		"goblin": player.global_position.distance_to(_snapshot.player) < 0.05,
		"cervo": deer.global_position.distance_to(_snapshot.deer) < 0.05,
	}
	_check(same.values().all(func(ok: bool) -> bool: return ok), "ida e volta sem perder estado %s (voltou em %.1f s)" % [same, frames / 60.0])
	await _wait(0.5)
	_check(not Game.awake and shelter.ari == null and not shelter.visible, "deitou e saiu do Abrigo")
	_check(level.process_mode == Node.PROCESS_MODE_INHERIT and _camera() == player.get_node(^"CameraPivot/CameraArm/Camera3D"),
		"a floresta voltou, com a câmera do goblin")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")), "os sons da floresta voltaram")
	_check(player.lying, "o goblin continua deitado no sarcófago")
	await _press("jump")
	await _wait(3.5)
	_check(player.can_act(), "levantou do sarcófago")


func _test_second_visit_and_load() -> void:
	_check(SaveSystem.save_game(), "na floresta, salva")
	Events.ritual_completed.emit(&"cave_dark")
	await _wait(3.0)
	_check(Game.awake, "no Ato III, outro ritual: outra visita")
	_check(SaveSystem.load_game(), "carregar acordado")
	await _tree.process_frame
	_check(not Game.awake and Game.current_level.process_mode == Node.PROCESS_MODE_INHERIT and Game.shelter.ari == null,
		"carregar acordado volta para a floresta")


# --- Auxiliares ------------------------------------------------------------------------------
func _wait_flash() -> Shelter:
	for i in 80:
		await _wait(0.1)
		if Game.shelter != null and Game.shelter.visible:
			return Game.shelter
	return null


func _camera() -> Camera3D:
	return _tree.root.get_viewport().get_camera_3d()


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
