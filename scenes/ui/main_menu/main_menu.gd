class_name MainMenu
extends Control
## O menu principal (§8). Atrás, a floresta de verdade, vista de fora da caverna (Game.open_menu).
## O título muda com os finais (MetaFiles.title): "A Toca", "A Toca — Ninho" depois do Final 1, e
## "Bem-vindo de volta" depois do Final 3, quando o menu só tem "Assistir" e "Sair" (e "Novo ciclo"
## depois de assistir até o fim).

const TITLE_COLOR := Color(0.86, 0.84, 0.78)
const SUBTITLE_COLOR := Color(0.7, 0.72, 0.68)
const BUTTON_COLOR := Color(0.78, 0.79, 0.75)
const SHADE := """shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, 0.72 * (1.0 - smoothstep(0.0, 0.55, UV.x)));
}"""

var _buttons: VBoxContainer
var _confirm: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Uma sombra à esquerda, para o texto ler sobre a neblina.
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADE
	shade.material = material
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 90)
	margin.add_theme_constant_override(&"margin_top", 150)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = MetaFiles.title()
	title.add_theme_font_size_override(&"font_size", 54)
	title.add_theme_color_override(&"font_color", TITLE_COLOR)
	title.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title.add_theme_constant_override(&"shadow_offset_y", 3)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _subtitle()
	subtitle.add_theme_font_size_override(&"font_size", 17)
	subtitle.add_theme_color_override(&"font_color", SUBTITLE_COLOR)
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 36.0)
	column.add_child(gap)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 8)
	column.add_child(_buttons)
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override(&"separation", 8)
	_confirm.visible = false
	column.add_child(_confirm)
	if MetaFiles.title_mode() == &"welcome":
		_button(_buttons, "Assistir", Game.start_welcome)
		if MetaFiles.welcome_done():
			_button(_buttons, "Novo ciclo", Game.new_cycle)
	else:
		if SaveSystem.has_save():
			_button(_buttons, "Continuar  ·  %s" % SaveSystem.describe_save(), Game.continue_game)
		_button(_buttons, "Novo jogo", _on_new_game)
	_button(_buttons, "Sair", Game.quit)
	var warning := Label.new()
	warning.text = "Começar de novo apaga o jogo salvo\ne o que ele deixou fora do jogo."
	warning.add_theme_color_override(&"font_color", SUBTITLE_COLOR)
	_confirm.add_child(warning)
	_button(_confirm, "Começar de novo", Game.start_new_game)
	_button(_confirm, "Voltar", _show_confirm.bind(false))
	(_buttons.get_child(0) as Button).grab_focus()


func _subtitle() -> String:
	match MetaFiles.title_mode():
		&"ninho":
			return "Os riscos agora contam para a frente."
		&"welcome":
			return "Alguém está quente agora."
	return "Um goblin acorda numa caverna."


func _on_new_game() -> void:
	if SaveSystem.has_save():
		_show_confirm(true)
	else:
		Game.start_new_game()


func _show_confirm(confirm_visible: bool) -> void:
	_confirm.visible = confirm_visible
	_buttons.visible = not confirm_visible
	var first := (_confirm if confirm_visible else _buttons).get_child(1 if confirm_visible else 0) as Button
	first.grab_focus()


func _button(parent: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(320.0, 40.0)
	button.add_theme_font_size_override(&"font_size", 20)
	button.flat = true
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	button.add_theme_color_override(&"font_color", BUTTON_COLOR)
	for state: StringName in [&"font_hover_color", &"font_focus_color", &"font_pressed_color"]:
		button.add_theme_color_override(state, TITLE_COLOR.lightened(0.2))
	button.mouse_entered.connect(button.grab_focus)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
