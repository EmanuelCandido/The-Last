class_name MainMenu
extends Control
## O menu principal (§8). Atrás, a floresta de verdade, vista de fora da caverna (Game.open_menu);
## à esquerda, o painel de rocha (UiStyle.rock_panel) com o logo, os riscos e os itens, e o mundo
## aparece à direita sem escurecer.
## O título muda com os finais (MetaFiles.title_mode): o logo "A TOCA", o logo com "Ninho" depois do
## Final 1, e "Bem-vindo de volta" escrito depois do Final 3, quando o menu só tem "Assistir" e "Sair"
## (e "Novo ciclo" depois de assistir até o fim). "Configurações" abre a SettingsMenu por cima.

var _column: Control
var _buttons: VBoxContainer
var _confirm: VBoxContainer
var _settings_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiStyle.rock_panel(&"menu"))
	_column = Control.new()
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	var header := VBoxContainer.new()
	header.add_theme_constant_override(&"separation", 12)
	header.position = Vector2(66.0, 156.0)
	_column.add_child(header)
	if MetaFiles.title_mode() == &"welcome":
		header.add_child(UiStyle.menu_title("Bem-vindo\nde volta"))
	else:
		header.add_child(UiStyle.sprite(UiStyle.LOGO, 3))
	header.add_child(UiStyle.tally_line(SaveSystem.describe_save() if SaveSystem.has_save() else ""))
	var subtitle := _subtitle()
	if subtitle != "":
		header.add_child(UiStyle.label(subtitle, &"Hint"))
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 12)
	_buttons.position = Vector2(UiStyle.MENU_LEFT, 382.0)
	_column.add_child(_buttons)
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override(&"separation", 12)
	_confirm.position = _buttons.position
	_confirm.visible = false
	_column.add_child(_confirm)
	if MetaFiles.title_mode() == &"welcome":
		_button(_buttons, "Assistir", Game.start_welcome)
		if MetaFiles.welcome_done():
			_button(_buttons, "Novo ciclo", Game.new_cycle)
	else:
		if SaveSystem.has_save():
			_button(_buttons, "Continuar", Game.continue_game)
		_button(_buttons, "Novo jogo", _on_new_game)
	_settings_button = _button(_buttons, "Configurações", _open_settings)
	_button(_buttons, "Sair", Game.quit)
	var warning := UiStyle.label("Começar de novo apaga o jogo salvo\ne o que ele deixou fora do jogo.")
	warning.add_theme_color_override(&"font_color", UiStyle.BLOOD.lightened(0.25))
	_confirm.add_child(warning)
	_button(_confirm, "Começar de novo", Game.start_new_game)
	_button(_confirm, "Voltar", _show_confirm.bind(false))
	UiStyle.footer(_column, "[Enter] Confirmar")
	(_buttons.get_child(0) as Button).grab_focus()


## A frase embaixo dos riscos, só depois dos finais.
func _subtitle() -> String:
	match MetaFiles.title_mode():
		&"ninho":
			return "Ninho. Os riscos agora contam para a frente."
		&"welcome":
			return "Alguém está quente agora."
	return ""


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
	button.custom_minimum_size.x = 300.0
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(button)
	return button
