extends Node
## As Configurações do jogador (vídeo, áudio, controles e jogo), salvas em user://settings.cfg,
## fora do save da partida. Carregam no início e valem na hora: quem muda um valor chama
## set_value (ou set_volume, rebind), que aplica, salva e emite `changed`.
##
## Quem lê: o Player e Ari (sensibilidade, inverter Y, campo de visão), o HUD (dicas de controle e
## tamanho dos avisos), a BlurredVision (tamanho das legendas) e os textos que mostram teclas
## (key_label). Os padrões ficam em Tuning.SETTINGS_*.
##
## O aparelho em uso (F10): quem mexeu por último, o controle ou o teclado e mouse
## (`using_gamepad`). Os textos que mostram tecla (key_label, key_labels) seguem ele: "[E] Pegar"
## vira "[X] Pegar". Ao trocar, emite `changed(&"input_device")`. A troca de teclas da tela de
## Configurações continua sendo só do teclado e do mouse (keyboard_label).

signal changed(key: StringName)

const PATH := "user://settings.cfg"
const BRIGHTNESS_SHADER := preload("res://assets/shaders/brightness.gdshader")
const RETRO_SHADER := preload("res://assets/shaders/retro_filter.gdshader")

## Ações que dá para trocar de tecla, na ordem da tela, com o nome que aparece.
const REMAPPABLE: Array[Array] = [
	[&"move_forward", "Andar para a frente"],
	[&"move_back", "Andar para trás"],
	[&"move_left", "Andar para a esquerda"],
	[&"move_right", "Andar para a direita"],
	[&"sprint", "Correr"],
	[&"crouch", "Agachar"],
	[&"jump", "Pular"],
	[&"interact", "Pegar, usar"],
	[&"aim", "Mirar com o arco"],
	[&"attack", "Atirar, golpear"],
	[&"eat", "Comer"],
	[&"craft", "Fabricar"],
	[&"hold_breath", "Prender o ar"],
	[&"sniff", "Farejar"],
	[&"throw", "Jogar pedra"],
]
## Volumes: chave -> buses. "world" leva também o bus Shelter (os sons do Abrigo contam como
## efeitos; a tela não pode dizer que ele existe). "master" é um ganho no Master, porque o volume
## do Master é do ouvido (Game.open_ears).
const VOLUME_BUSES := {
	&"master": [&"Master"],
	&"ambience": [&"Ambience"],
	&"world": [&"World", &"Shelter"],
}
## Seção do arquivo de cada valor simples (os volumes e as teclas têm as suas).
const SECTIONS := {
	&"fullscreen": "video", &"vsync": "video", &"render_scale": "video", &"max_fps": "video",
	&"fov": "video", &"brightness": "video", &"retro": "video", &"muted": "audio", &"mouse_sensitivity": "controls",
	&"invert_y": "controls", &"text_scale_index": "game", &"show_hints": "game",
}
const KEY_NAMES := {
	KEY_SPACE: "Espaço", KEY_ESCAPE: "Esc", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt",
	KEY_ENTER: "Enter", KEY_TAB: "Tab", KEY_BACKSPACE: "Apagar", KEY_CAPSLOCK: "Caps",
	KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
}
const MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Botão esquerdo", MOUSE_BUTTON_RIGHT: "Botão direito",
	MOUSE_BUTTON_MIDDLE: "Botão do meio", MOUSE_BUTTON_WHEEL_UP: "Roda para cima",
	MOUSE_BUTTON_WHEEL_DOWN: "Roda para baixo", MOUSE_BUTTON_XBUTTON1: "Botão lateral 1",
	MOUSE_BUTTON_XBUTTON2: "Botão lateral 2",
}
const SHORT_MOUSE_NAMES := {
	MOUSE_BUTTON_LEFT: "Clique", MOUSE_BUTTON_RIGHT: "Botão dir.", MOUSE_BUTTON_MIDDLE: "Meio",
}
## Botões do controle com os nomes do controle do Xbox (o padrão do Godot); a cruz com setas.
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruz ↑", JOY_BUTTON_DPAD_DOWN: "Cruz ↓", JOY_BUTTON_DPAD_LEFT: "Cruz ←",
	JOY_BUTTON_DPAD_RIGHT: "Cruz →",
}
const PAD_AXIS_NAMES := {
	JOY_AXIS_LEFT_X: "LS", JOY_AXIS_LEFT_Y: "LS", JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}

# Vídeo
var fullscreen := Tuning.SETTINGS_FULLSCREEN
var vsync := Tuning.SETTINGS_VSYNC
var render_scale := Tuning.SETTINGS_RENDER_SCALE
var max_fps := Tuning.SETTINGS_MAX_FPS
var fov := Tuning.SETTINGS_FOV
var brightness := Tuning.SETTINGS_BRIGHTNESS
## O filtro retrô (pixel grande, poucas cores, vinheta e grão) sobre a imagem 3D.
var retro := Tuning.SETTINGS_RETRO
# Áudio
var volumes := {&"master": Tuning.SETTINGS_VOLUME, &"ambience": Tuning.SETTINGS_VOLUME, &"world": Tuning.SETTINGS_VOLUME}
var muted := false
# Controles
var mouse_sensitivity := Tuning.SETTINGS_MOUSE_SENSITIVITY
var invert_y := false
# Jogo
var text_scale_index := Tuning.SETTINGS_TEXT_SCALE
var show_hints := true

var _config := ConfigFile.new()
var _gain := AudioEffectAmplify.new()
var _gamma_layer: CanvasLayer
var _gamma: ShaderMaterial
var _retro_layer: CanvasLayer


## O último aparelho usado foi o controle (os textos de tecla mostram os botões dele).
var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.add_bus_effect(0, _gain)
	_build_gamma()
	_build_retro()
	_load()
	for key: StringName in SECTIONS:
		_apply(key)
	_apply_volumes()


## Muda um valor simples (os nomes de SECTIONS), aplica e salva.
func set_value(key: StringName, value: Variant) -> void:
	set(key, value)
	_apply(key)
	_config.set_value(SECTIONS[key], key, get(key))
	_save()
	changed.emit(key)


## Volume de 0 a 1 de "master", "ambience" ou "world".
func set_volume(key: StringName, value: float) -> void:
	volumes[key] = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_config.set_value("audio", key, volumes[key])
	_save()
	changed.emit(key)


## Escala dos avisos, do prompt e das legendas.
func text_scale() -> float:
	return Tuning.SETTINGS_TEXT_SCALES[clampi(text_scale_index, 0, Tuning.SETTINGS_TEXT_SCALES.size() - 1)]


## Volta os padrões de uma seção: "video", "audio", "controls" (as teclas também) ou "game".
func reset_section(section: String) -> void:
	for key: StringName in SECTIONS:
		if SECTIONS[key] == section:
			set(key, _default(key))
			_apply(key)
			changed.emit(key)
	if section == "audio":
		for key: StringName in volumes:
			volumes[key] = Tuning.SETTINGS_VOLUME
		_apply_volumes()
		changed.emit(&"volumes")
	if section == "controls":
		InputMap.load_from_project_settings()
		if _config.has_section("keys"):
			_config.erase_section("keys")
		changed.emit(&"keys")
	if _config.has_section(section):
		_config.erase_section(section)
	_save()


# --- Teclas -------------------------------------------------------------------------------------

## A tecla (ou botão do mouse) principal da ação: o primeiro evento de teclado ou mouse.
func binding(action: StringName) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


## Quem mexeu por último: o controle (botão ou analógico bem inclinado) ou o teclado e mouse.
func _input(event: InputEvent) -> void:
	var pad := using_gamepad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		pad = false
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 4.0:
		pad = false
	if pad != using_gamepad:
		using_gamepad = pad
		changed.emit(&"input_device")


## O nome da tecla principal da ação no aparelho em uso ("E", "Shift", "Botão direito"; no
## controle, "X", "RT", "Cruz ↓"); `short` encurta o mouse.
func key_label(action: StringName, short := false) -> String:
	if using_gamepad:
		var pad := pad_binding(action)
		if pad != null:
			return event_label(pad, short)
	return keyboard_label(action, short)


## O nome da tecla do teclado ou do mouse (a tela de troca de teclas usa este).
func keyboard_label(action: StringName, short := false) -> String:
	var event := binding(action)
	return "?" if event == null else event_label(event, short)


## O botão (ou eixo) do controle da ação, ou null.
func pad_binding(action: StringName) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return event
	return null


## Os nomes das teclas para String.format: {interact}, {eat}, {craft}...
func key_labels() -> Dictionary:
	var labels := {}
	for entry in REMAPPABLE:
		labels[String(entry[0])] = key_label(entry[0], true)
	labels["pause"] = key_label(&"pause", true)
	# As quatro direções juntas: "WASD" no teclado, o analógico no controle.
	labels["move"] = labels["move_forward"] if using_gamepad else \
		"%s%s%s%s" % [labels["move_forward"], labels["move_left"], labels["move_back"], labels["move_right"]]
	return labels


func event_label(event: InputEvent, short := false) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = key.physical_keycode
			# O nome da tecla no teclado de quem joga (sem janela, como nos testes, fica o físico).
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		return KEY_NAMES.get(code, OS.get_keycode_string(code)) as String
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if short and SHORT_MOUSE_NAMES.has(button):
			return SHORT_MOUSE_NAMES[button]
		return MOUSE_NAMES.get(button, "Mouse %d" % button) as String
	if event is InputEventJoypadButton:
		return PAD_NAMES.get((event as InputEventJoypadButton).button_index, "Botão %d" % (event as InputEventJoypadButton).button_index) as String
	if event is InputEventJoypadMotion:
		return PAD_AXIS_NAMES.get((event as InputEventJoypadMotion).axis, "Eixo") as String
	return "?"


## Troca a tecla principal de `action` por `event` (tecla ou botão do mouse). A mesma tecla sai de
## qualquer outra ação da lista, para não ficar com duas funções; a ação que ficou sem tecla
## nenhuma recebe a antiga de `action` (as duas trocam).
func rebind(action: StringName, event: InputEvent) -> void:
	var clean := _clean_event(event)
	if clean == null:
		return
	var old := binding(action)
	for entry in REMAPPABLE:
		if entry[0] == action:
			continue
		for other in InputMap.action_get_events(entry[0]):
			if _same_input(other, clean):
				InputMap.action_erase_event(entry[0], other)
				if binding(entry[0]) == null and old != null:
					InputMap.action_add_event(entry[0], _clean_event(old))
	for other in InputMap.action_get_events(action):
		if _same_input(other, clean) and other != old:
			InputMap.action_erase_event(action, other)
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var placed := false
	for current in events:
		if current == old and not placed:
			InputMap.action_add_event(action, clean)
			placed = true
		else:
			InputMap.action_add_event(action, current)
	if not placed:
		# Sem tecla antes: a nova entra na frente.
		events = InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, clean)
		for current in events:
			InputMap.action_add_event(action, current)
	_store_keys()
	_save()
	changed.emit(&"keys")


func _clean_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		var source := event as InputEventKey
		key.physical_keycode = source.physical_keycode if source.physical_keycode != KEY_NONE else source.keycode
		return key
	if event is InputEventMouseButton:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = (event as InputEventMouseButton).button_index
		return mouse
	return null


func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var code_a := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var code_b := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		return code_a == code_b
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## Guarda as teclas e botões de todas as ações da lista (o controle de videogame fica no projeto).
func _store_keys() -> void:
	for entry in REMAPPABLE:
		var stored: Array[Dictionary] = []
		for event in InputMap.action_get_events(entry[0]):
			if event is InputEventKey:
				stored.append({"key": (event as InputEventKey).physical_keycode})
			elif event is InputEventMouseButton:
				stored.append({"mouse": (event as InputEventMouseButton).button_index})
		_config.set_value("keys", entry[0], stored)


func _load_keys() -> void:
	if not _config.has_section("keys"):
		return
	for action: String in _config.get_section_keys("keys"):
		if not InputMap.has_action(action):
			continue
		var stored: Array = _config.get_value("keys", action, [])
		for event in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				InputMap.action_erase_event(action, event)
		var restored: Array[InputEvent] = []
		for entry: Dictionary in stored:
			if entry.has("key"):
				var key := InputEventKey.new()
				key.physical_keycode = int(entry["key"]) as Key
				restored.append(key)
			elif entry.has("mouse"):
				var mouse := InputEventMouseButton.new()
				mouse.button_index = int(entry["mouse"]) as MouseButton
				restored.append(mouse)
		# As teclas vêm antes do controle, como no projeto.
		var pads := InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		for event in restored + pads:
			InputMap.action_add_event(action, event)


# --- Aplicar, carregar e salvar ----------------------------------------------------------------

func _apply(key: StringName) -> void:
	var windowed := DisplayServer.get_name() != "headless"
	match key:
		&"fullscreen":
			if windowed:
				var mode := DisplayServer.window_get_mode()
				var is_full := mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
				if fullscreen != is_full:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		&"vsync":
			if windowed:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		&"render_scale":
			render_scale = clampf(render_scale, Tuning.SETTINGS_RENDER_SCALE_RANGE.x, Tuning.SETTINGS_RENDER_SCALE_RANGE.y)
			get_tree().root.scaling_3d_scale = render_scale
		&"max_fps":
			Engine.max_fps = max_fps
		&"brightness":
			_gamma.set_shader_parameter(&"gamma", brightness)
			_gamma_layer.visible = absf(brightness - 1.0) > 0.01
		&"retro":
			_retro_layer.visible = retro
		&"muted":
			AudioServer.set_bus_mute(0, muted)


func _apply_volumes() -> void:
	_gain.volume_db = linear_to_db(maxf(volumes[&"master"], 0.0001))
	for key: StringName in [&"ambience", &"world"]:
		for bus: StringName in VOLUME_BUSES[key]:
			var index := AudioServer.get_bus_index(bus)
			if index >= 0:
				AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[key], 0.0001)))


func _default(key: StringName) -> Variant:
	match key:
		&"fullscreen": return Tuning.SETTINGS_FULLSCREEN
		&"vsync": return Tuning.SETTINGS_VSYNC
		&"render_scale": return Tuning.SETTINGS_RENDER_SCALE
		&"max_fps": return Tuning.SETTINGS_MAX_FPS
		&"fov": return Tuning.SETTINGS_FOV
		&"brightness": return Tuning.SETTINGS_BRIGHTNESS
		&"retro": return Tuning.SETTINGS_RETRO
		&"mouse_sensitivity": return Tuning.SETTINGS_MOUSE_SENSITIVITY
		&"text_scale_index": return Tuning.SETTINGS_TEXT_SCALE
		&"show_hints": return true
	return false


func _load() -> void:
	if _config.load(PATH) != OK:
		_config = ConfigFile.new()
		return
	for key: StringName in SECTIONS:
		var value: Variant = _config.get_value(SECTIONS[key], key, get(key))
		match typeof(get(key)):
			TYPE_INT:
				if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
					set(key, int(value))
			TYPE_FLOAT:
				if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
					set(key, float(value))
			TYPE_BOOL:
				if typeof(value) == TYPE_BOOL:
					set(key, value)
	for key: StringName in volumes:
		volumes[key] = clampf(float(_config.get_value("audio", key, volumes[key])), 0.0, 1.0)
	_load_keys()


func _save() -> void:
	var error := _config.save(PATH)
	if error != OK:
		push_warning("[Settings] Não deu para salvar %s: %s" % [PATH, error_string(error)])


## A curva de gama do brilho, numa camada abaixo de toda a interface (só a imagem 3D muda).
func _build_gamma() -> void:
	_gamma_layer = CanvasLayer.new()
	_gamma_layer.name = "Brightness"
	_gamma_layer.layer = -1
	_gamma_layer.visible = false
	add_child(_gamma_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gamma = ShaderMaterial.new()
	_gamma.shader = BRIGHTNESS_SHADER
	rect.material = _gamma
	_gamma_layer.add_child(rect)


## O filtro retrô, abaixo do brilho (o brilho clareia a imagem já filtrada) e de toda a interface.
func _build_retro() -> void:
	_retro_layer = CanvasLayer.new()
	_retro_layer.name = "RetroFilter"
	_retro_layer.layer = -2
	add_child(_retro_layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = RETRO_SHADER
	material.set_shader_parameter(&"virtual_height", Tuning.RETRO_VIRTUAL_HEIGHT)
	material.set_shader_parameter(&"levels", Tuning.RETRO_LEVELS)
	material.set_shader_parameter(&"dither", Tuning.RETRO_DITHER)
	material.set_shader_parameter(&"bloom", Tuning.RETRO_BLOOM)
	material.set_shader_parameter(&"bloom_threshold", Tuning.RETRO_BLOOM_THRESHOLD)
	material.set_shader_parameter(&"bloom_tint", Tuning.RETRO_BLOOM_TINT)
	material.set_shader_parameter(&"saturation", Tuning.RETRO_SATURATION)
	material.set_shader_parameter(&"shadow_tint", Tuning.RETRO_SHADOW_TINT)
	material.set_shader_parameter(&"light_tint", Tuning.RETRO_LIGHT_TINT)
	material.set_shader_parameter(&"vignette", Tuning.RETRO_VIGNETTE)
	material.set_shader_parameter(&"vignette_range", Tuning.RETRO_VIGNETTE_RANGE)
	material.set_shader_parameter(&"grain", Tuning.RETRO_GRAIN)
	material.set_shader_parameter(&"grain_fps", Tuning.RETRO_GRAIN_FPS)
	rect.material = material
	_retro_layer.add_child(rect)
