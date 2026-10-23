class_name FakeFreeze
extends CanvasLayer
## O falso travamento (§7), ao deitar no sarcófago no fim do Ato II: a imagem congela com o som
## preso num zumbido, a janela clareia e avisa que "A Toca não está respondendo", e a tela fica
## preta. Quem chamou continua no escuro: a "volta" já é o Abrigo (Game.wake_in_shelter).
## O título da janela de verdade também diz que o programa parou.

const BUZZ := preload("res://assets/audio/sfx/stuck_buzz.wav")
const APP_NAME := "A Toca"

var _frozen: TextureRect
var _buzz: AudioStreamPlayer
var _muted := {}
var _answered := false


func _init() -> void:
	layer = 40


## Passa o travamento inteiro (termina com a tela preta).
func play() -> void:
	# A última imagem desenhada, parada por cima de tudo (sem tela, como nos testes, não há imagem).
	_frozen = TextureRect.new()
	_frozen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frozen.stretch_mode = TextureRect.STRETCH_SCALE
	_frozen.mouse_filter = Control.MOUSE_FILTER_STOP
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image != null and not image.is_empty():
			_frozen.texture = ImageTexture.create_from_image(image)
	add_child(_frozen)
	_stick_audio()
	print("[FakeFreeze] A Toca não está respondendo.")
	await _wait(Tuning.FREEZE_SECONDS)

	# Clareia como janela travada, e o sistema pergunta o que fazer.
	DisplayServer.window_set_title("%s (Não está respondendo)" % APP_NAME)
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(1.0, 1.0, 1.0, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	create_tween().tween_property(veil, ^"color:a", 0.35, 0.6)
	add_child(_dialog())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var left := Tuning.FREEZE_DIALOG_SECONDS
	while left > 0.0 and not _answered:
		await get_tree().process_frame
		left -= get_process_delta_time()

	# Preto e silêncio.
	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	add_child(black)
	_buzz.stop()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(Tuning.FREEZE_BLACK_SECONDS)
	DisplayServer.window_set_title(String(ProjectSettings.get_setting("application/config/name", APP_NAME)))
	for bus: int in _muted:
		AudioServer.set_bus_mute(bus, _muted[bus])


## Todo o som cala de uma vez e só sobra um pedacinho repetindo (o buffer preso).
func _stick_audio() -> void:
	for bus in range(1, AudioServer.bus_count):
		_muted[bus] = AudioServer.is_bus_mute(bus)
		AudioServer.set_bus_mute(bus, true)
	_buzz = AudioStreamPlayer.new()
	_buzz.stream = BUZZ
	_buzz.volume_db = -8.0
	add_child(_buzz)
	_buzz.play()


## A caixa de "não está respondendo", no centro da tela.
func _dialog() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.97, 0.97)
	style.border_color = Color(0.72, 0.72, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 18
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	box.add_child(_label(APP_NAME, 13, Color(0.35, 0.35, 0.35)))
	box.add_child(_label("%s não está respondendo" % APP_NAME, 21, Color(0.1, 0.1, 0.1)))
	box.add_child(_label("Se você fechar o programa, poderá perder informações.", 14, Color(0.25, 0.25, 0.25)))
	for text: String in ["Fechar o programa", "Aguardar o programa responder"]:
		box.add_child(_option(text))
	return center


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## Uma opção da caixa: as duas fazem a mesma coisa (nada responde).
func _option(text: String) -> Button:
	var button := Button.new()
	button.text = "→  " + text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 15)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		button.add_theme_color_override(state, Color(0.1, 0.25, 0.55))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.88, 0.91, 0.96)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	button.add_theme_stylebox_override(&"hover", hover)
	button.pressed.connect(func() -> void: _answered = true)
	return button


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
