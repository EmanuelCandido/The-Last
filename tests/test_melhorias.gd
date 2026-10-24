extends RefCounted
## F10 de ponta a ponta (polimento e orientação): o Ato I mais curto, os degraus, o marco de
## pedras, o tronco riscado, a fumaça da toca, o sino da ruína, as dicas progressivas e o aviso
## de anotação, a pergunta antes de sair sem salvar, o diário de playtest, os textos de tecla do
## controle, Ari olhando com o analógico, a câmera da mira, o osso da caverna e o pool de pegadas.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _player: Player
var _notices: Array[String] = []


func run() -> void:
	_level = Game.current_level
	_player = Game.player
	Weather.stop_rain()
	Weather.rain = 0.0
	Clock.hour = 10.0
	Events.notification_shown.connect(func(text: String) -> void: _notices.append(text))
	await _pad_labels()
	await _pad_menus()
	await _steps()
	await _aim_camera()
	await _cairn()
	await _tree_mark()
	await _smoke_and_bones()
	await _bell()
	await _quit_confirm()
	_playtest()
	await _act_one()
	await _hints()
	await _ari_look()
	_check(Tracks._current.multimesh.instance_count == Tuning.TRACK_POOL and Tuning.TRACK_POOL >= 1200,
		"pegadas: pool de %d (dura os 2 min com as manadas)" % Tuning.TRACK_POOL)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	MetaFiles.remove_all()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


# --- Controle: os textos de tecla seguem o aparelho ---------------------------------------------
func _pad_labels() -> void:
	_put(ForestLayout.MEADOW + Vector2(0.0, 12.0))
	await _wait(0.3)
	_check(not Settings.using_gamepad and Settings.key_label(&"interact") == "E", "teclado: [E] (%s)" % Settings.key_label(&"interact"))
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_Y
	button.pressed = true
	Input.parse_input_event(button)
	await _tree.process_frame
	button = button.duplicate()
	button.pressed = false
	Input.parse_input_event(button)
	await _tree.process_frame
	_check(Settings.using_gamepad and Settings.key_label(&"interact") == "X" and Settings.key_label(&"aim") == "LT",
		"controle: [X] pegar, LT mirar (%s, %s)" % [Settings.key_label(&"interact"), Settings.key_label(&"aim")])
	_check(Settings.key_labels()["move"] == "LS" and Settings.keyboard_label(&"interact") == "E",
		"controle: andar no LS; a tela de teclas continua no teclado")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await _tree.process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _tree.process_frame
	_check(not Settings.using_gamepad and Settings.key_label(&"interact") == "E", "de volta ao teclado: [E]")


# --- Controle nos menus e na lista de fabricar ---------------------------------------------------
func _pad_menus() -> void:
	var pause: Variant = Game.ui_root.get_node("PauseMenu")
	await _pad(JOY_BUTTON_START)
	_check(_tree.paused and pause.visible, "Menu (Start) pausa")
	var first: Control = _tree.root.get_viewport().gui_get_focus_owner()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var second: Control = _tree.root.get_viewport().gui_get_focus_owner()
	_check(first != null and second != null and first != second, "a cruz anda pelos itens da pausa (%s -> %s)" % [first, second])
	await _pad(JOY_BUTTON_START)
	_check(not _tree.paused, "Menu (Start) volta ao jogo")
	# Lista de fabricar: Y abre, a cruz ↓ escolhe e não come junto (a cruz ↓ também é "comer").
	Inventory.add(&"cooked_meat")
	var craft := _player.get_node("CraftAbility") as CraftAbility
	await _pad(JOY_BUTTON_Y)
	_check(craft._open, "Y abre a lista de fabricar")
	var selected := craft.selected
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _wait(0.4)
	# A saciedade cai sozinha com o tempo: quem diz se comeu é a carne.
	_check(craft.selected != selected and Inventory.count(&"cooked_meat") == 1,
		"na lista, a cruz ↓ escolhe a receita e não come (%d -> %d)" % [selected, craft.selected])
	await _pad(JOY_BUTTON_Y)
	_check(not craft._open, "Y fecha a lista")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _wait(Tuning.EAT_TIME + 0.3)
	_check(Inventory.count(&"cooked_meat") == 0, "fora da lista, a cruz ↓ come")


func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tree.process_frame
		await _tree.process_frame


# --- Degraus ------------------------------------------------------------------------------------
func _steps() -> void:
	for case: Array in [[0.24, true], [0.5, false]]:
		var height: float = case[0]
		var climbs: bool = case[1]
		var at := ForestLayout.MEADOW + Vector2(-6.0, 0.0)
		_put(at)
		_player.set_camera_angles(0.0, -10.0)
		await _wait(0.4)
		# Um bloco largo à frente (a câmera olha para -Z), afundado no chão. A altura conta do chão
		# na face de quem chega (o prado tem encosta: medido no meio do bloco, o degrau mudava).
		var ground: float = _level.ground_height(at.x, at.y - 1.15)
		var block := _box(Vector3(2.4, height + 1.0, 1.0), Vector3(at.x, ground + (height - 1.0) * 0.5, at.y - 1.7))
		await _wait(0.2)
		Input.action_press(&"move_forward")
		await _wait(2.5)
		Input.action_release(&"move_forward")
		await _wait(0.3)
		var top := ground + height
		var on_top := _player.global_position.y > top - 0.08 and absf(_player.global_position.z - (at.y - 1.7)) < 0.6
		var past := _player.global_position.z < at.y - 2.3
		if climbs:
			_check(on_top or past, "sobe um degrau de %.0f cm (y %.2f, topo %.2f)" % [height * 100.0, _player.global_position.y, top])
		else:
			_check(not on_top and not past, "não sobe %.0f cm (y %.2f, z %.2f)" % [height * 100.0, _player.global_position.y, _player.global_position.z])
		block.queue_free()
		await _wait(0.2)


func _box(size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	body.add_child(mesh)
	_level.add_child(body)
	body.global_position = center
	return body


# --- Câmera da mira -----------------------------------------------------------------------------
func _aim_camera() -> void:
	_put(ForestLayout.MEADOW)
	Inventory.add(&"bow")
	Inventory.add(&"arrow", 6)
	_player.set_camera_angles(0.0, -5.0)
	await _wait(0.3)
	Input.action_press(&"aim")
	await _wait(1.2)
	var cam := _player._cam
	var distance := cam.camera.global_position.distance_to(cam.arm.global_position)
	Input.action_release(&"aim")
	var expected := Vector2(Tuning.AIM_CAMERA_DISTANCE, Tuning.AIM_SHOULDER).length()
	_check(absf(distance - expected) < 0.25, "mirando, a câmera fica a %.2f m (esperado %.2f)" % [distance, expected])
	await _wait(0.8)


# --- Marco de pedras ----------------------------------------------------------------------------
func _cairn() -> void:
	_put(ForestLayout.MEADOW + Vector2(4.0, 4.0))
	await _wait(0.3)
	Inventory.add(&"stone", 3)
	var cairns := _tree.get_first_node_in_group(CairnField.GROUP) as CairnField
	var before := cairns.get_child_count()
	var recipe: Dictionary = Recipes.LIST.filter(func(r: Dictionary) -> bool: return r.id == &"cairn")[0]
	(_player.get_node("CraftAbility") as CraftAbility).craft(recipe)
	await _wait(Tuning.CRAFT_TIME + 0.6)
	_check(cairns.get_child_count() == before + 1 and Inventory.count(&"stone") == 0, "o marco de pedras foi montado e gastou 3 pedras")
	var cairn := cairns.get_child(cairns.get_child_count() - 1) as Node3D
	var flat := Vector2(cairn.global_position.x - _player.global_position.x, cairn.global_position.z - _player.global_position.z)
	_check(flat.length() > 0.4 and flat.length() < 1.2, "na frente do goblin (%.2f m)" % flat.length())
	_check(SaveSystem.save_game(), "salvou com o marco")
	cairns.load_data({})
	_check(cairns.get_child_count() == 0, "(limpou para conferir o load)")
	SaveSystem.load_game()
	await _wait(0.3)
	cairns = _tree.get_first_node_in_group(CairnField.GROUP) as CairnField
	_check(cairns.get_child_count() == before + 1, "o marco volta ao carregar")


# --- Tronco riscado -----------------------------------------------------------------------------
func _tree_mark() -> void:
	var vegetation: Vegetation = _level.get_node("Vegetation")
	var interactables := _tree.get_nodes_in_group(&"interactable")
	var chosen := -1
	for id in vegetation.trees.size():
		var info := vegetation.trees[id]
		if info.dead or info.fallen or Vector2(info.base.x, info.base.z).distance_to(ForestLayout.MEADOW) > 60.0:
			continue
		var clear := true
		for node in interactables:
			if node is Node3D and node != _player.get_node("TreeMarker") and (node as Node3D).global_position.distance_to(info.base) < 3.0:
				clear = false
		if clear:
			chosen = id
			break
	_check(chosen != -1, "há um pinheiro vivo sozinho por perto")
	if chosen == -1:
		return
	var info := vegetation.trees[chosen]
	var spot := info.base + Vector3(info.radius + 0.5, 0.0, 0.0)
	_put(Vector2(spot.x, spot.z))
	await _wait(0.4)
	var marker := _player.get_node("TreeMarker") as TreeMarker
	_check(marker.tree == chosen and marker.interaction_prompt() == "Riscar o tronco", "perto do pinheiro: '%s'" % marker.interaction_prompt())
	await DevTools._press("interact")
	await _wait(Tuning.TREE_MARK_TIME + 0.5)
	var marks := _tree.get_first_node_in_group(TreeMarks.GROUP) as TreeMarks
	_check(marks.has_mark(chosen) and marker.interaction_prompt() == "Tronco já riscado", "riscou o tronco")
	SaveSystem.save_game()
	marks.load_data({"marks": []})
	SaveSystem.load_game()
	await _wait(0.3)
	marks = _tree.get_first_node_in_group(TreeMarks.GROUP) as TreeMarks
	_check(marks.has_mark(chosen) and marks.get_child_count() >= 1, "o risco volta ao carregar")


# --- Fumaça e ossos -----------------------------------------------------------------------------
func _smoke_and_bones() -> void:
	var cave := _level.find_child("Cave", true, false) as Cave
	var fire := cave.get_node("Campfire") as Campfire
	var smoke := cave.get_node("Smoke") as CaveSmoke
	fire.fuel = 2.0
	fire._apply_fuel()
	await _wait(1.2)
	_check(smoke.emitting, "fogo aceso: a fumaça sobe da toca")
	fire.fuel = 0.0
	fire._apply_fuel()
	await _wait(1.2)
	_check(not smoke.emitting, "fogo apagado: sem fumaça")
	fire.fuel = 1.0
	fire._apply_fuel()
	var bone := cave.get_node("BoneA") as MeshInstance3D
	_check(bone.mesh is ArrayMesh and bone.mesh.surface_get_material(0) == PropLook.bone(), "o osso da caverna tem textura de osso")
	Clock.hour = 23.0
	await _wait(0.3)
	var fill := cave.get_node("NightFill") as SpotLight3D
	_check(fill.visible and fill.light_energy > 0.2, "de noite, a luz do olho acostumado acende na toca (%.2f)" % fill.light_energy)
	Clock.hour = 10.0
	await _wait(0.3)
	_check(not fill.visible, "de dia ela apaga")


# --- O sino da ruína ----------------------------------------------------------------------------
func _bell() -> void:
	var ruin := _level.find_child("Ruin", true, false) as Ruin
	var bell := ruin.bell
	var below: float = _level.ground_height(bell.global_position.x, bell.global_position.z)
	_check(bell != null and bell.global_position.y - below > 4.0, "o sino pende da espadana (%.1f m do chão)" % (bell.global_position.y - below))
	# O Wind refaz o clima todo frame: parado, o roteiro manda (ventania e rajadas passando).
	Wind.set_process(false)
	Wind.intensity = 1.0
	var strikes := bell.strikes
	var peak := 0.0
	for i in 600:
		Wind._offset += Wind.direction * 9.0 / 60.0
		peak = maxf(peak, Wind.aloft_at(bell.global_position))
		await _tree.process_frame
	_check(bell.strikes > strikes, "na ventania o sino bate (%d batidas, rajada até %.2f)" % [bell.strikes - strikes, peak])
	Wind.intensity = 0.1
	await _wait(3.0)
	strikes = bell.strikes
	await _wait(6.0)
	_check(bell.strikes == strikes, "na calmaria ele fica quieto")
	Wind.set_process(true)


# --- Sair sem salvar ----------------------------------------------------------------------------
func _quit_confirm() -> void:
	# O menu de pausa não tem class_name: acesso dinâmico.
	var pause: Variant = Game.ui_root.get_node("PauseMenu")
	var calls: Array = []
	SaveSystem.save_game()
	Game.set_paused(true)
	pause.ask_leave(func() -> void: calls.append(1))
	_check(calls.size() == 1 and not pause._leave.visible, "acabou de salvar: sai sem perguntar")
	SaveSystem._unsaved = 120.0
	pause.ask_leave(func() -> void: calls.append(2))
	_check(calls.size() == 1 and pause._leave.visible and pause._leave_text.text.contains("há 2 min"),
		"sem salvar há 2 min: pergunta antes ('%s')" % pause._leave_text.text.replace("\n", " "))
	pause._leave_back.pressed.emit()
	_check(not pause._leave.visible and pause._items.visible and calls.size() == 1, "Voltar desiste de sair")
	pause.ask_leave(func() -> void: calls.append(3))
	pause._leave_save.pressed.emit()
	_check(calls.has(3) and SaveSystem.unsaved_seconds() < 1.0, "Salvar e sair salva e sai")
	Game.set_paused(false)
	await _wait(0.2)


# --- Diário de playtest -------------------------------------------------------------------------
func _playtest() -> void:
	_check(not Playtest.enabled, "nos testes o diário fica desligado")
	var path := "user://playtest/teste_roteiro.log"
	_check(Playtest.open(path), "abriu um diário de teste")
	Story.set_flag(&"teste_playtest")
	Events.crafted.emit(&"arrows")
	Playtest.close()
	var text := FileAccess.get_file_as_string(path)
	_check(text.contains("flag\tteste_playtest ligou") and text.contains("fabricou\tarrows") and text.contains("# resumo"),
		"o diário grava os eventos e o resumo")
	Story.set_flag(&"teste_playtest", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest"))


# --- Ato I mais curto ---------------------------------------------------------------------------
func _act_one() -> void:
	Story.set_act(1)
	Story.marks = 4
	Story.add_count(&"deer_harvested")
	await _sleep()
	_check(Story.marks == 5 and Story.has_flag(&"moss_fell") and Story.act == 2, "o musgo cai no 5º risco com um cervo (riscos %d)" % Story.marks)


# --- Dicas progressivas e o aviso de anotação ----------------------------------------------------
func _hints() -> void:
	Story.set_flag(&"saw_ruin_window")
	_check(Story.count(&"stuck_sleeps") == 0, "avançar zera o contador de dias parado")
	await _sleep()
	_check(Story.count(&"stuck_sleeps") == 1 and not _has_note("pede quatro números"), "um dia parado: ainda sem dica")
	_notices.clear()
	await _sleep()
	_check(_has_note("pede quatro números"), "dois dias parado na porta: a primeira dica entra")
	await _wait(Tuning.NOTE_NOTICE_DELAY + 0.5)
	_check(_notices.any(func(text: String) -> bool: return text.begins_with("Anotação nova")), "o aviso da anotação sai depois de acordar")
	Story.set_flag(RuinDoor.OPEN_FLAG)
	_check(Story.count(&"stuck_sleeps") == 0, "abrir a porta zera o contador")
	_notices.clear()
	Story.add_note("Teste: uma anotação de dia.")
	_check(_notices.any(func(text: String) -> bool: return text.begins_with("Anotação nova")), "anotação de dia: o aviso sai na hora")


# --- Ari e o analógico --------------------------------------------------------------------------
func _ari_look() -> void:
	Story.set_act(3)
	await Game.wake_in_shelter(true)
	var waited := 0.0
	while waited < 20.0 and not (Game.awake and Game.shelter.ari != null and Game.shelter.ari.controls):
		await _tree.process_frame
		waited += _tree.root.get_process_delta_time()
	var ari := Game.shelter.ari
	_check(ari != null and ari.controls, "Ari acordou e tem controle")
	if ari == null:
		return
	var yaw: float = ari._yaw
	Input.action_press(&"camera_right")
	await _wait(0.5)
	Input.action_release(&"camera_right")
	_check(absf(ari._yaw - yaw) > 0.3, "o analógico direito vira a cabeça de Ari (%.2f rad)" % absf(ari._yaw - yaw))
	Game.return_to_forest(true)
	await _wait(0.5)


func _sleep() -> void:
	Clock.hour = 21.0
	Game.pass_out(&"sleep")
	while Game.resting:
		await _tree.process_frame
	await _wait(0.2)


func _has_note(fragment: String) -> bool:
	for note in Story.notes:
		if note.contains(fragment):
			return true
	return false


func _put(at: Vector2) -> void:
	_player.global_position = Vector3(at.x, _level.ground_height(at.x, at.y) + 0.05, at.y)
	_player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, false).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
