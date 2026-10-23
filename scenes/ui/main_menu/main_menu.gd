class_name MainMenu
extends Control
## O menu principal (§8). Atrás, a floresta de verdade, vista de fora da caverna (Game.open_menu),
## escurecida pela esquerda por uma neblina em pontilhado (UiStyle.fog_backdrop).
## O título muda com os finais (MetaFiles.title): "A Toca", "A Toca — Ninho" depois do Final 1, e
## "Bem-vindo de volta" depois do Final 3, quando o menu só tem "Assistir" e "Sair" (e "Novo ciclo"
## depois de assistir até o fim). "Configurações" abre a SettingsMenu por cima.

var _column: VBoxContainer
var _buttons: VBoxContainer
var _confirm: VBoxContainer
var _settings_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiStyle.fog_backdrop(0.86, 1.0, 0.16))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 96)
	margin.add_theme_constant_override(&"margin_top", 120)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 6)
	margin.add_child(_column)
	_column.add_child(UiStyle.label(MetaFiles.title(), &"Title"))
	var rule := UiStyle.separator()
	rule.custom_minimum_size.x = 420.0
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.add_child(rule)
	_column.add_child(UiStyle.label(_subtitle(), &"Hint"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 40.0)
	_column.add_child(gap)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 4)
	_column.add_child(_buttons)
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override(&"separation", 4)
	_confirm.visible = false
	_column.add_child(_confirm)
	if MetaFiles.title_mode() == &"welcome":
		_button(_buttons, "Assistir", Game.start_welcome)
		if MetaFiles.welcome_done():
			_button(_buttons, "Novo ciclo", Game.new_cycle)
	else:
		if SaveSystem.has_save():
			_button(_buttons, "Continuar  ·  %s" % SaveSystem.describe_save(), Game.continue_game)
		_button(_buttons, "Novo jogo", _on_new_game)
	_settings_button = _button(_buttons, "Configurações", _open_settings)
	_button(_buttons, "Sair", Game.quit)
	var warning := UiStyle.label("Começar de novo apaga o jogo salvo\ne o que ele deixou fora do jogo.")
	warning.add_theme_color_override(&"font_color", UiStyle.BLOOD.lightened(0.25))
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


func _open_settings() -> void:
	var settings := SettingsMenu.new()
	settings.name = "Settings"
	_column.visible = false
	settings.closed.connect(func() -> void:
		_column.visible = true
		_settings_button.grab_focus())
	add_child(settings)


func _button(parent: Container, text: String, action: Callable) -> Button:
	var button := UiStyle.menu_button(text, action)
	button.custom_minimum_size.x = 380.0
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)
	return button
