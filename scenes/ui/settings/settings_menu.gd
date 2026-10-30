class_name SettingsMenu
extends Control
## A tela de Configurações: abas Vídeo, Áudio, Controles e Jogo, no painel largo de rocha
## (UiStyle.rock_panel), com o título e os riscos como nos outros menus. Abre por cima do menu
## principal e do menu de pausa (quem abre esconde o próprio painel e volta a mostrá-lo em
## `closed`). Cada mudança vale na hora e é salva pelo Settings. Esc fecha (ou cancela a troca de
## tecla).

signal closed

const TABS := [["video", "Vídeo"], ["audio", "Áudio"], ["controls", "Controles"], ["game", "Jogo"]]
const TEXT_SCALE_NAMES := ["Normal", "Grande", "Enorme"]
const LABEL_WIDTH := 330.0

var _tab := "video"
var _tab_buttons := {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
## A ação esperando a tecla nova, e o botão dela.
var _waiting := &""
var _waiting_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiStyle.rock_panel(&"wide"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	column.position = Vector2(79.0, 52.0)
	column.custom_minimum_size.x = 800.0
	add_child(column)
	column.add_child(UiStyle.menu_title("Configurações"))
	column.add_child(UiStyle.tally_line())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for entry: Array in TABS:
		var button := Button.new()
		button.text = entry[1]
		button.theme_type_variation = &"TabButton"
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_show_tab.bind(String(entry[0])))
		tabs.add_child(button)
		_tab_buttons[entry[0]] = button
	column.add_child(UiStyle.separator())
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 330.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 10)
	_scroll.add_child(_content)
	column.add_child(UiStyle.separator())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 10)
	column.add_child(bottom)
	_status = UiStyle.label("", &"Hint")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_status)
	var reset := Button.new()
	reset.text = "Restaurar padrão"
	reset.pressed.connect(_on_reset)
	bottom.add_child(reset)
	var back := Button.new()
	back.text = "Voltar"
	back.pressed.connect(close)
	bottom.add_child(back)
	UiStyle.footer(self, "[Esc] Voltar")
	(_tab_buttons["video"] as Button).button_pressed = true
	_show_tab("video")
	(_tab_buttons["video"] as Button).grab_focus()


func _input(event: InputEvent) -> void:
	if _waiting != &"":
		var bind: bool = (event is InputEventKey and event.pressed and not event.is_echo()) \
			or (event is InputEventMouseButton and event.pressed)
		if not bind:
			return
		get_viewport().set_input_as_handled()
		if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
			_stop_waiting("")
			return
		var action := _waiting
		_stop_waiting("")
		Settings.rebind(action, event)
		_show_tab("controls")
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


func _show_tab(tab: String) -> void:
	_tab = tab
	_status.text = ""
	for child in _content.get_children():
		child.queue_free()
	match tab:
		"video":
			_check("Tela cheia", &"fullscreen")
			_check("Sincronia vertical (vsync)", &"vsync")
			_slider("Escala da resolução 3D", &"render_scale", Tuning.SETTINGS_RENDER_SCALE_RANGE, 0.05,
				func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
			var fps_names := PackedStringArray()
			for fps in Tuning.SETTINGS_FPS_OPTIONS:
				fps_names.append("Sem limite" if fps == 0 else str(fps))
			_options("Limite de FPS", fps_names, maxi(Tuning.SETTINGS_FPS_OPTIONS.find(Settings.max_fps), 0),
				func(index: int) -> void: Settings.set_value(&"max_fps", Tuning.SETTINGS_FPS_OPTIONS[index]))
			_slider("Campo de visão", &"fov", Tuning.SETTINGS_FOV_RANGE, 1.0,
				func(v: float) -> String: return "%d°" % roundi(v))
			_slider("Brilho", &"brightness", Tuning.SETTINGS_BRIGHTNESS_RANGE, 0.05,
				func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
			_check("Filtro retrô", &"retro")
		"audio":
			_volume("Volume geral", &"master")
			_volume("Ambiente (vento, chuva, bichos)", &"ambience")
			_volume("Efeitos (passos, fogo, arco)", &"world")
			_check("Sem som", &"muted")
		"controls":
			_slider("Sensibilidade do mouse", &"mouse_sensitivity", Tuning.SETTINGS_MOUSE_SENSITIVITY_RANGE, 0.05,
				func(v: float) -> String: return "%.2f×" % v)
			_check("Inverter o eixo Y", &"invert_y")
			var keys := UiStyle.label("Teclas  ·  clique e aperte a nova (Esc cancela)", &"Hint")
			_content.add_child(keys)
			for entry: Array in Settings.REMAPPABLE:
				_key_row(entry[1], entry[0])
		"game":
			var names := PackedStringArray()
			for i in Tuning.SETTINGS_TEXT_SCALES.size():
				names.append(TEXT_SCALE_NAMES[mini(i, TEXT_SCALE_NAMES.size() - 1)])
			_options("Tamanho dos avisos e legendas", names, Settings.text_scale_index,
				func(index: int) -> void: Settings.set_value(&"text_scale_index", index))
			_check("Mostrar as dicas de controle", &"show_hints")
	_scroll.scroll_vertical = 0


func _on_reset() -> void:
	Settings.reset_section(_tab)
	_show_tab(_tab)
	_status.text = "Padrões de volta."


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	var name_label := UiStyle.label(text)
	name_label.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(name_label)
	_content.add_child(row)
	return row


func _check(text: String, key: StringName) -> void:
	var row := _row(text)
	var box := CheckBox.new()
	box.custom_minimum_size.x = 120.0
	box.text = "Sim" if bool(Settings.get(key)) else "Não"
	box.button_pressed = bool(Settings.get(key))
	box.toggled.connect(func(on: bool) -> void:
		box.text = "Sim" if on else "Não"
		Settings.set_value(key, on))
	row.add_child(box)


func _slider(text: String, key: StringName, range_: Vector2, step: float, format: Callable) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.min_value = range_.x
	slider.max_value = range_.y
	slider.step = step
	slider.value = float(Settings.get(key))
	slider.custom_minimum_size.x = 280.0
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UiStyle.label(format.call(slider.value))
	value.custom_minimum_size.x = 80.0
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = format.call(v)
		Settings.set_value(key, v))


func _volume(text: String, key: StringName) -> void:
	var row := _row(text)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.volumes[key])
	slider.custom_minimum_size.x = 280.0
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UiStyle.label("%d%%" % roundi(slider.value * 100.0))
	value.custom_minimum_size.x = 80.0
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % roundi(v * 100.0)
		Settings.set_volume(key, v))


func _options(text: String, names: PackedStringArray, selected: int, on_select: Callable) -> void:
	var row := _row(text)
	var options := OptionButton.new()
	options.custom_minimum_size.x = 220.0
	for item in names:
		options.add_item(item)
	options.select(selected)
	options.item_selected.connect(func(index: int) -> void: on_select.call(index))
	row.add_child(options)


func _key_row(text: String, action: StringName) -> void:
	var row := _row(text)
	var button := Button.new()
	button.text = Settings.keyboard_label(action)
	button.custom_minimum_size.x = 220.0
	button.pressed.connect(func() -> void:
		if _waiting_button != null:
			_stop_waiting("")
		_waiting = action
		_waiting_button = button
		button.text = "aperte a tecla…"
		_status.text = "Esc cancela.")
	row.add_child(button)


func _stop_waiting(message: String) -> void:
	if _waiting_button != null and is_instance_valid(_waiting_button):
		_waiting_button.text = Settings.keyboard_label(_waiting)
	_waiting = &""
	_waiting_button = null
	_status.text = message
