extends RefCounted
## Fase 7 de ponta a ponta: o ciclo_346.sav aparece depois do flash 2 e carregá-lo passa a
## memória e devolve tudo; o leia_me aparece depois do R1 com a senha; o falso travamento no
## sarcófago leva ao Abrigo; o HUD vital no Abrigo e na floresta (R3, vida baixa); a voz do
## Zelador pelo alto-falante; o bipe de fundo do Ato III.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	MetaFiles.remove_all()
	Story.set_flag(&"moss_fell")
	Story.set_act(2)
	await _test_old_save()
	await _test_memory()
	await _test_freeze()
	await _test_vitals_shelter()
	await _test_letter()
	await _test_keeper_voice()
	await _test_vitals_forest()
	await _test_steady_beep()
	MetaFiles.remove_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- ciclo_346.sav ------------------------------------------------------------------------------
func _test_old_save() -> void:
	_check(not MetaFiles.has_old_save(), "antes do flash 2 não há ciclo_346.sav")
	Story.add_count(&"sleeps_act_2", 2)
	Story.trigger(&"slept")
	Game._pending_flash = -1
	_check(Story.has_flag(&"old_save") and MetaFiles.has_old_save(), "flash 2: o ciclo_346.sav apareceu")
	var text := FileAccess.get_file_as_string(MetaFiles.OLD_SAVE_PATH)
	_check(text.contains("\"cycle\": 346") and text.contains("ACORDA"), "o arquivo parece um save do ciclo 346")
	var menu := _menu()
	Game.set_paused(true)
	_check(not menu._load_button.disabled, "Carregar habilitado")
	menu._on_load_pressed()
	_check(menu._slots.visible and menu._slot_old.visible, "Carregar mostra a lista com o ciclo_346.sav")
	menu.show_slots(false)
	Game.set_paused(false)


# --- A memória do ciclo 346 ---------------------------------------------------------------------
func _test_memory() -> void:
	Clock.hour = 10.0
	var player := Game.player
	var before := player.global_position
	var campfire := Game.current_level.find_child("Campfire", true, false)
	var fuel: float = campfire.fuel
	Inventory.add(&"arrow", 3)
	var arrows := Inventory.count(&"arrow")
	var menu := _menu()
	Game.set_paused(true)
	menu._on_load_pressed()
	menu._on_load_old()
	await _wait(4.0)
	var marks := Game.current_level.find_child("WallMarks", true, false) as WallMarks
	_check(Game.cutscene and Game.resting, "memória passando (sem pausa, relógio parado)")
	_check(is_equal_approx(Clock.hour, Tuning.MEMORY_HOUR), "memória à noite (%.1f h)" % Clock.hour)
	_check(marks._word_mesh.mesh != null and not marks._new_mesh.visible, "a palavra aparecendo e os riscos de agora escondidos")
	_check(player.global_position.distance_to(before) > 1.0, "o goblin foi até a parede")
	await _until(func() -> bool: return not Game.cutscene, 30.0)
	_check(_tree.paused and menu.visible, "a memória acabou e voltou para o menu")
	_check(Story.notes.has("Ele vê pelos corvos."), "anotação da memória")
	_check(is_equal_approx(Clock.hour, 10.0), "a hora voltou (%.1f h)" % Clock.hour)
	_check(player.global_position.distance_to(before) < 0.2, "o goblin voltou para onde estava")
	_check(is_equal_approx(campfire.fuel, fuel), "a fogueira voltou (%.2f)" % campfire.fuel)
	_check(Inventory.count(&"arrow") == arrows, "o inventário ficou igual")
	_check(marks._word_mesh.mesh == null and marks._new_mesh.visible, "a palavra sumiu e os riscos voltaram")
	_check(Game.current_level.find_child("Memory346", true, false) == null, "a cena da memória foi embora")
	Game.set_paused(false)
	await _wait(0.5)


# --- O falso travamento ---------------------------------------------------------------------------
func _test_freeze() -> void:
	Events.ritual_completed.emit(&"sarcophagus")
	await _wait(1.0)
	var freeze := Game.get_node_or_null(^"FakeFreeze") as FakeFreeze
	_check(freeze != null and Game.cutscene and Story.act == 3, "ritual no sarcófago: o jogo \"trava\" (Ato III)")
	_check(freeze != null and freeze._frozen != null and freeze._buzz.playing, "imagem parada e o zumbido preso")
	_check(Game.shelter == null or Game.shelter.ari == null, "ainda não acordou durante o travamento")
	await _wait(Tuning.FREEZE_SECONDS + 0.5)
	var dialog := false
	if freeze != null:
		for child in freeze.get_children():
			dialog = dialog or child is CenterContainer
	_check(dialog, "a janela de \"não está respondendo\" apareceu")
	await _until(func() -> bool: return not Game.cutscene and Game.shelter != null and Game.shelter.ari != null, 20.0)
	_check(Game.awake and not Game.cutscene and Game.shelter != null and Game.shelter.ari != null, "a volta foi o Abrigo")
	await _until(func() -> bool: return Game.shelter.ari.controls, 20.0)


# --- HUD vital no Abrigo ----------------------------------------------------------------------
func _test_vitals_shelter() -> void:
	var hud := _vitals()
	await _wait(1.0)
	_check(hud.modulate.a > 0.5, "no Abrigo o ECG está no canto (%.2f)" % hud.modulate.a)
	var spo2 := hud._spo2
	Input.action_press("hold_breath")
	await _wait(2.5)
	Input.action_release("hold_breath")
	_check(hud._spo2 < spo2 - 0.8, "prendendo o ar o oxigênio cai (%.1f -> %.1f)" % [spo2, hud._spo2])


# --- leia_me_se_lembrar.txt ----------------------------------------------------------------------
func _test_letter() -> void:
	_check(not MetaFiles.has_letter(), "antes do R1 não há carta")
	await _back_to_capsule_with(&"room_seen")
	_check(Story.has_flag(&"letter_left") and MetaFiles.has_letter(), "R1: a carta apareceu em %s" % MetaFiles.letter_path())
	var text := FileAccess.get_file_as_string(MetaFiles.letter_path())
	var password := Story.password()
	var format := RegEx.create_from_string("^MUSGO-\\d{4}$")
	_check(format.search(password) != null, "senha no formato MUSGO-xxxx (%s)" % password)
	_check(text.contains("trocar " + password) and text.contains("ciclo 347"), "a carta termina com a senha")
	var menu := _menu()
	Game.set_paused(true)
	_check(menu._folder_button.visible, "o menu ganhou \"Abrir pasta do jogo\"")
	Game.set_paused(false)
	SaveSystem.save_game()
	Story.secret = ""
	DirAccess.remove_absolute(MetaFiles.letter_path())
	SaveSystem.load_game()
	_check(Story.secret == password, "a senha vai no save")
	_check(MetaFiles.has_letter(), "carta apagada volta ao carregar")


# --- A voz do Zelador no Abrigo -------------------------------------------------------------------
func _test_keeper_voice() -> void:
	Game.wake_in_shelter(true)
	await _wait(0.3)
	var shelter := Game.shelter
	var ari := shelter.ari
	ari.global_position = shelter.to_global(Vector3(8.6, 0.0, 0.0))
	ari.look(shelter.caretaker.head.global_position - ari.camera.global_position)
	await _until(func() -> bool: return shelter.keeper.state == Keeper.State.FOUND, 10.0)
	await _wait(0.2)
	var subtitle: String = Game.vision._subtitle.text
	_check(subtitle == StoryBeats.LINES[&"found"], "viu Ari: fala pelo alto-falante (\"%s\")" % subtitle)
	await _until(func() -> bool: return not Game.awake, 15.0)
	await _wait(1.0)


# --- HUD vital na floresta (R3) ------------------------------------------------------------------
func _test_vitals_forest() -> void:
	var hud := _vitals()
	await _until(func() -> bool: return Game.player.can_act(), 15.0)
	Vitals.health = 15.0
	await _wait(1.5)
	_check(hud.modulate.a < 0.01, "antes do R3 a vida baixa não mostra o ECG")
	Story.set_flag(&"climate_cut")
	await _wait(2.0)
	_check(hud.modulate.a > 0.05 and hud.modulate.a <= Tuning.VITALS_HUD_FOREST_ALPHA, "depois do R3, vida baixa: o ECG aparece de leve (%.2f)" % hud.modulate.a)
	Vitals.health = 100.0
	await _wait(2.0)
	_check(hud.modulate.a < 0.01, "vida boa: some")
	Story.set_flag(&"climate_cut", false)


# --- O bipe de fundo do Ato III -----------------------------------------------------------------
func _test_steady_beep() -> void:
	var clues := Game.current_level.find_child("Clues", true, false)
	Game.player.global_position = Game.current_level.find_child("Cave", true, false).to_global(Vector3(0.0, 0.2, 2.0))
	var heard := 0
	for i in 30:
		await _wait(0.1)
		for child in clues.get_children():
			if child is AudioStreamPlayer and (child as AudioStreamPlayer).stream == Clues.BEEP:
				heard += 1
	_check(heard > 0, "Ato III na caverna: o bipe no fundo")


# --- Auxiliares ----------------------------------------------------------------------------------
## Uma visita em que `objective` fica pendente e Ari deita na cápsula (o caminho de verdade).
func _back_to_capsule_with(objective: StringName) -> void:
	if not Game.awake:
		Game.wake_in_shelter(true)
		await _wait(0.3)
	var shelter := Game.shelter
	shelter.visit.add(objective)
	var ari := shelter.ari
	ari.global_position = shelter.capsule.out_point()
	ari.look(shelter.capsule.interaction_point() - ari.camera.global_position)
	await _wait(0.3)
	await _press("interact")
	await _until(func() -> bool: return not Game.awake, 10.0)
	await _wait(0.5)


func _menu() -> Control:
	return _tree.root.find_child("PauseMenu", true, false) as Control


func _vitals() -> VitalsHud:
	return _tree.root.find_child("HUD", true, false).get_node(^"Vitals") as VitalsHud


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _tree.physics_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
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
