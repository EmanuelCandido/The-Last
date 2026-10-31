extends RefCounted
## Fase 8 de ponta a ponta, um final por vez (--case=stay | wake | swap | welcome | menu):
## a sala de controle (cartão, câmeras, a conversa), o console do Zelador e cada final.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	MetaFiles.remove_all()
	MetaFiles.forget_endings()
	var case := "stay"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case = arg.trim_prefix("--case=")
	print("[T] caso: %s" % case)
	match case:
		"stay":
			await _truth()
			await _console_powers()
			await _stay()
		"wake":
			await _truth()
			await _wake()
		"swap":
			await _truth()
			await _swap()
		"welcome":
			await _welcome()
		"menu":
			await _menu_flow()
	MetaFiles.remove_all()
	MetaFiles.forget_endings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- A sala de controle e a conversa -----------------------------------------------------------
func _truth() -> void:
	for objective: StringName in [&"room_seen", &"blind_spot", &"climate_cut", &"access_card"]:
		Story.complete_objective(objective)
	_check(Story.act == 4, "Ato IV com o cartão (ato %d)" % Story.act)
	Story.password()
	await Game.wake_in_shelter(true)
	var shelter := Game.shelter
	var control := shelter.control
	var ari := shelter.ari
	_check(control._door.position.x < 4.1, "a porta da sala de controle começa fechada")
	# O leitor do lado do corredor.
	ari.global_position = shelter.to_global(Vector3(4.75, 0.0, -0.2))
	ari.look(shelter.to_global(Vector3(4.75, 1.3, 0.85)) - ari.camera.global_position)
	await _wait(0.3)
	_check(ari._interaction == control._reader, "Ari olha para o leitor (%s)" % ari._interaction)
	_press("interact")
	await _wait(1.4)
	_check(control.unlocked and control._door.position.x > 4.9, "o cartão abriu a porta")
	# Entra: a anotação da sala.
	ari.global_position = shelter.to_global(Vector3(5.0, 0.0, 4.5))
	await _wait(0.3)
	_check(Story.has_flag(&"control_room"), "entrou na sala de controle (flag)")
	_check(Story.notes.has("As câmeras da sala de controle olham para fora."), "anotação da sala")
	_check(control._feeds[0].get_shader_parameter(&"signal_amount") == 0.0, "as telas começam sem sinal")
	# O terminal: abrir as gravações.
	ari.global_position = shelter.to_global(Vector3(5.0, 0.0, 5.4))
	ari.look(shelter.to_global(Vector3(5.0, 1.0, 6.3)) - ari.camera.global_position)
	await _wait(0.3)
	var prompt: String = ari._interaction.interaction_prompt() if ari._interaction != null else ""
	_check(prompt == "Abrir as gravações", "o terminal oferece as gravações (%s)" % prompt)
	_press("interact")
	await _wait(2.0)
	_check(Story.has_flag(&"confession") and control.talking, "abriu as gravações: começou a conversa")
	_check(float(control._feeds[0].get_shader_parameter(&"signal_amount")) > 0.9, "as câmeras ligaram")
	_check(control._stamps[0].text.contains(ControlRoom.RECORDING_DATE), "a data da gravação na tela (%s)" % control._stamps[0].text)
	_check(not shelter.visit.active, "a lucidez parou")
	await _wait(6.0)
	_check(shelter.keeper.state == Keeper.State.TALK, "o Zelador veio conversar (estado %d)" % shelter.keeper.state)
	await _until(func() -> bool: return not control.talking, 60.0)
	_check(not control.talking and ari.controls, "a conversa acabou e Ari voltou a mexer")
	var keeper_distance := shelter.caretaker.global_position.distance_to(control.talk_point())
	_check(keeper_distance < 0.5, "o Zelador está na sala (%.2f m do ponto)" % keeper_distance)
	_check(Story.notes.has("Lá fora tem gente. Ele disse que não havia ninguém aqui."), "anotação da conversa")
	ari.look(shelter.to_global(Vector3(5.0, 1.0, 6.3)) - ari.camera.global_position)
	await _wait(0.3)
	prompt = ari._interaction.interaction_prompt() if ari._interaction != null else ""
	_check(prompt == "Usar o terminal", "o terminal abre o console (%s)" % prompt)
	_press("interact")
	await _wait(0.3)
	_check(control._console != null and Game.cutscene, "o console do Zelador abriu")
	var console := control._console
	console.run("ajuda")
	_check(console._log.get_parsed_text().contains("neblina off"), "a ajuda mostra os comandos")
	_check(not console._log.get_parsed_text().contains("trocar <senha>  "), "a ajuda não conta do trocar")
	console.run("trocar MUSGO-0000" if Story.secret != "MUSGO-0000" else "trocar MUSGO-0001")
	_check(console._log.get_parsed_text().contains("SENHA RECUSADA"), "senha errada é recusada")
	_check(Game.ending == &"", "senha errada não começa final")
	console.run("ficar_nao")
	_check(console._log.get_parsed_text().contains("comando desconhecido"), "comando desconhecido")


func _console_powers() -> void:
	var console := Game.shelter.control._console
	console.run("status")
	_check(console._log.get_parsed_text().contains("CICLO 347"), "status mostra o ciclo")
	console.run("neblina off")
	_check(Story.has_flag(&"fog_off"), "neblina off liga o flag")
	console.run("give arrow 3")
	_check(Inventory.count(&"arrow") >= 3, "give cria flechas (%d)" % Inventory.count(&"arrow"))
	console.run("give pedra")
	_check(console._log.get_parsed_text().contains("uso: give"), "give com item errado mostra o uso")
	console.run("teleport ruina")
	_check(Game.forest_teleport == KeeperConsole.PLACES["ruina"], "teleport guarda o lugar")


# --- Final 1: ficar -----------------------------------------------------------------------------
func _stay() -> void:
	var console := Game.shelter.control._console
	console.run("ficar")
	await _wait(0.5)
	_check(Game.ending == &"stay" and Story.has_flag(&"ending_stay"), "ficar começou o Final 1")
	await _until(func() -> bool: return not Game.awake, 20.0)
	_check(not Game.awake, "Ari voltou para a floresta")
	await _wait(1.0)
	var ruin: Vector2 = KeeperConsole.PLACES["ruina"]
	var at := Game.player.global_position
	_check(Vector2(at.x, at.z).distance_to(ruin) < 1.0, "o goblin acordou na ruína (%s)" % at)
	_check(MetaFiles.title_mode() == &"ninho" and MetaFiles.title() == "A Toca — Ninho", "o título virou Ninho")
	_check(SaveSystem.has_save(), "salvou depois de ficar")
	_check(Game.get_node_or_null(^"Credits") != null, "os créditos sobre a floresta")
	_check(Game.player.can_act(), "dá para jogar durante os créditos")
	var vigilance := Story.vigilance
	Story.add_vigilance(50.0)
	_check(Story.vigilance == vigilance, "a Vigilância não sobe mais")
	var cycle := Story.cycle
	Game.recycle(&"vigilance")
	await _wait(0.5)
	_check(Story.cycle == cycle and not Game.resting, "a Reciclagem não acontece mais")
	var marks := Story.marks
	Events.slept.emit()
	_check(Story.forward_marks == 1 and Story.marks == marks, "a noite vira a contagem para a frente")
	var wall := Game.current_level.find_child("WallMarks", true, false) as WallMarks
	await _wait(0.2)
	_check(wall._forward_mesh.mesh != null, "o risco novo está na parede")
	Story.trigger(&"ritual", &"cave")
	await _wait(0.5)
	_check(not Game.awake, "o ritual não acorda mais Ari")
	await _until(func() -> bool: return Game.get_node_or_null(^"Credits") == null, 90.0)
	_check(Game.get_node_or_null(^"Credits") == null, "os créditos acabaram")


# --- Final 2: acordar ---------------------------------------------------------------------------
func _wake() -> void:
	var shelter := Game.shelter
	var console := shelter.control._console
	console.run("acordar")
	await _wait(0.5)
	_check(Game.ending == &"wake", "acordar começou o Final 2")
	_check(shelter.outside != null, "lá fora foi montado")
	await _until(func() -> bool: return shelter.ari.controls, 15.0)
	_check(shelter.keeper.state == Keeper.State.ESCORT, "o Zelador segue Ari (estado %d)" % shelter.keeper.state)
	_check(shelter._exit_door.position.y > 3.0, "a porta blindada subiu (%.2f)" % shelter._exit_door.position.y)
	var ari := shelter.ari
	var outside := shelter.outside
	# Ari vai até a porta: o Zelador vem atrás, mas não passa da soleira.
	ari.global_position = shelter.to_global(Vector3(0.0, 0.0, -3.0))
	await _wait(9.0)
	var keeper_z := shelter.to_local(shelter.caretaker.global_position).z
	_check(keeper_z > Keeper.EXIT_LIMIT_Z - 0.2, "o Zelador fica antes da soleira (z %.2f)" % keeper_z)
	var gap := shelter.caretaker.global_position.distance_to(ari.global_position)
	_check(gap > 1.2 and gap < 4.0, "segue de perto, sem tocar em Ari (%.2f m)" % gap)
	# Sobe a escada andando de verdade.
	ari.look(shelter.to_global(Vector3(0.0, 1.6, -10.0)) - ari.camera.global_position)
	Input.action_press("move_forward")
	await _wait(8.0)
	Input.action_release("move_forward")
	var climbed := shelter.to_local(ari.global_position)
	_check(climbed.y > 1.0 and climbed.z < -6.0, "Ari subiu a escada andando (%s)" % climbed)
	_check(outside.environment.fog_density > 0.0, "a neblina entra (%.4f)" % outside.environment.fog_density)
	# Na rua, longe da vitrine: sem reflexo.
	ari.global_position = outside.to_global(Vector3(0.0, Outside.STREET_Y + 0.05, -25.0))
	await _wait(2.0)
	_check(outside.reflection < 0.05, "longe do vidro, nada de reflexo")
	_check(not outside._crowd.playing, "no começo da rua, ainda sem vozes")
	_check(outside._walker.visible and outside._walker.position.x > Outside.WALKER_FROM.x + 1.0,
		"o vulto de respirador atravessa a rua lá na frente (x %.1f)" % outside._walker.position.x)
	ari.global_position = outside.to_global(Vector3(0.0, Outside.STREET_Y + 0.05, -36.0))
	await _wait(1.0)
	_check(outside._crowd.playing, "mais adiante, as vozes ao longe")
	# Diante da vitrine, olhando para ela.
	ari.global_position = outside.to_global(Vector3(0.2, Outside.STREET_Y + 0.05, Outside.GLASS_Z + 1.6))
	ari.look(outside.to_global(Vector3(0.0, Outside.STREET_Y + 1.55, Outside.GLASS_Z)) - ari.camera.global_position)
	await _wait(3.0)
	_check(outside.reflection > 0.5, "o rosto aparece no vidro (%.2f)" % outside.reflection)
	var mirror := outside.to_local(outside._face.global_position)
	_check(mirror.z < Outside.GLASS_Z - 1.0, "o reflexo fica do outro lado do vidro (z %.2f)" % mirror.z)
	await _until(func() -> bool: return outside.reflection_seen, 15.0)
	_check(outside.reflection_seen, "o rosto ficou visto")
	await _wait(6.0)
	_check(Game.get_node_or_null(^"Credits") != null, "os créditos no preto")
	await _until(func() -> bool: return Game.menu_open, 120.0)
	_check(Game.menu_open and not Game.awake, "voltou para o menu principal")
	_check(_tree.root.find_child("MainMenu", true, false) != null, "o menu está na tela")


# --- Final 3: trocar ----------------------------------------------------------------------------
func _swap() -> void:
	var shelter := Game.shelter
	var console := shelter.control._console
	console.run("trocar %s" % Story.secret.to_lower())
	await _wait(0.5)
	_check(Game.ending == &"swap" and Story.has_flag(&"ending_swap"), "a senha da carta começou o Final 3")
	await _wait(9.0)
	_check(shelter.control._terminal_text.text.contains("ZL-0"), "o terminal mostra a transferência (%s)" % shelter.control._terminal_text.text.replace("\n", " | "))
	await _until(func() -> bool: return MetaFiles.title_mode() == &"welcome", 30.0)
	_check(MetaFiles.title() == "Bem-vindo de volta", "da próxima vez o jogo abre como Bem-vindo de volta")
	await _wait(4.0)


# --- Bem-vindo de volta ---------------------------------------------------------------------------
func _welcome() -> void:
	MetaFiles.set_title_mode(&"welcome")
	Game.start_welcome()
	await _wait(1.0)
	var watcher := Game.current_level.find_child("WelcomeBack", true, false) as WelcomeBack
	_check(Game.welcome and watcher != null, "Bem-vindo de volta começou")
	var pilot := Game.player.find_child("Autopilot", true, false) as GoblinAutopilot
	_check(pilot != null, "a IA está no goblin")
	_check(not SaveSystem.save_game(), "o goblin da IA não salva")
	var start := Game.player.global_position
	await _until(func() -> bool: return Inventory.has(&"bow"), 40.0)
	_check(Inventory.has(&"bow"), "a IA pegou o arco")
	await _wait(40.0)
	var moved := Game.player.global_position.distance_to(start)
	var hunting := pilot.task in [GoblinAutopilot.Task.AIM, GoblinAutopilot.Task.HARVEST]
	_check(moved > 10.0 or hunting, "a IA saiu andando ou já caça perto (%.1f m, tarefa %d)" % [moved, pilot.task])
	_check(ForestLayout.cave_interior(Vector2(Game.player.global_position.x, Game.player.global_position.z)) < 0.5, "a IA saiu da caverna")
	await _until(func() -> bool: return pilot.task == GoblinAutopilot.Task.AIM or Story.count(&"deer_harvested") + Story.count(&"rabbit_harvested") > 0, 150.0)
	_check(pilot.task == GoblinAutopilot.Task.AIM or Story.count(&"deer_harvested") + Story.count(&"rabbit_harvested") > 0, "a IA chegou a mirar num bicho (tarefa %d)" % pilot.task)
	await _until(func() -> bool: return Story.count(&"deer_harvested") + Story.count(&"rabbit_harvested") > 0, 120.0)
	print("[T] info: caça coletada: cervos %d, coelhos %d; flechas %d" % [Story.count(&"deer_harvested"), Story.count(&"rabbit_harvested"), Inventory.count(&"arrow")])
	# O fim: sem esperar o dia inteiro.
	watcher._hours = Tuning.WELCOME_MAX_HOURS
	await _wait(6.0)
	var marks := Game.current_level.find_child("WallMarks", true, false) as WallMarks
	_check(marks._word_mesh.mesh != null, "os riscos formam a palavra")
	await _until(func() -> bool: return Game.menu_open, 40.0)
	_check(Game.menu_open and MetaFiles.welcome_done(), "acabou e voltou para o menu, com Novo ciclo")
	var menu := _tree.root.find_child("MainMenu", true, false) as MainMenu
	var texts := PackedStringArray()
	for button: Button in menu._buttons.get_children():
		texts.append(button.text)
	_check("Novo ciclo" in texts and "Assistir" in texts and texts.size() == 4, "o menu: %s" % ", ".join(texts))


# --- O menu principal ---------------------------------------------------------------------------
func _menu_flow() -> void:
	Game.back_to_menu()
	await _wait(1.0)
	var menu := _tree.root.find_child("MainMenu", true, false) as MainMenu
	_check(Game.menu_open and menu != null, "o menu abriu")
	var texts := PackedStringArray()
	for button: Button in menu._buttons.get_children():
		texts.append(button.text)
	_check(texts == PackedStringArray(["Novo jogo", "Configurações", "Sair"]), "sem save: %s" % ", ".join(texts))
	_check(Game.get_viewport().get_camera_3d().name == &"MenuCamera", "a câmera do menu está ligada")
	_check(not Game.player.can_act(), "o goblin não se mexe no menu")
	Game.start_new_game()
	await _wait(1.0)
	_check(not Game.menu_open and _tree.root.find_child("MainMenu", true, false) == null, "Novo jogo fechou o menu")
	_check(Story.act == 1 and Story.cycle == Story.START_CYCLE, "Novo jogo zerou a história")
	await _wait(7.0)
	_check(Game.player.can_act(), "o goblin acordou e anda")
	# Um save, e o menu de novo: aparece Continuar.
	Clock.day = 3
	Story.set_flag(&"moss_fell")
	_check(SaveSystem.save_game(), "salvou")
	Game.back_to_menu()
	await _wait(1.0)
	menu = _tree.root.find_child("MainMenu", true, false) as MainMenu
	texts = PackedStringArray()
	for button: Button in menu._buttons.get_children():
		texts.append(button.text)
	_check(texts.size() == 4 and texts[0] == "Continuar" and SaveSystem.describe_save().contains("Dia 3"), "com save: %s (%s)" % [", ".join(texts), SaveSystem.describe_save()])
	_check(Clock.day == 1 and not Story.has_flag(&"moss_fell"), "o menu zerou o estado de fundo")
	Game.continue_game()
	await _wait(1.0)
	_check(Clock.day == 3 and Story.has_flag(&"moss_fell"), "Continuar carregou o save")
	_check(Game.player.can_act(), "continuar não passa a cena de acordar")
	MetaFiles.set_title_mode(&"ninho")
	Game.back_to_menu()
	await _wait(0.5)
	menu = _tree.root.find_child("MainMenu", true, false) as MainMenu
	_check(menu.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text.begins_with("Ninho.")), "subtítulo do Ninho no menu")


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tree.physics_frame


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
