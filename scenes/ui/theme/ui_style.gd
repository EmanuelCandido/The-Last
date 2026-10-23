class_name UiStyle
extends RefCounted
## Peças da interface no estilo do jogo, por cima do Theme único (assets/ui/ui_theme.tres, o tema
## do projeto): a paleta para BBCode e desenho, o fundo de neblina dos menus, os botões de menu e as
## linhas. A fonte "Toca" é pixelada com 16 px de base: os tamanhos bons são 16, 32, 48 e 64.
##
## Variações do Theme: Title (64), Heading (32, ocre), Hint (apagado), MenuItem (botão de menu, 32),
## TabButton (aba), PanelDark, Smudge (mancha atrás do texto do HUD) e Keycap (tecla).

const FOG_SHADER := preload("res://assets/shaders/ui_fog.gdshader")
const NOISE := preload("res://assets/textures/macro_noise.png")

## Osso (texto), apagado, sumido, ocre de vela (destaque), musgo (anotações) e sangue seco.
const INK := Color(0.84, 0.82, 0.76)
const INK_DIM := Color(0.56, 0.56, 0.52)
const INK_FAINT := Color(0.38, 0.39, 0.37)
const ACCENT := Color(0.86, 0.76, 0.52)
const MOSS := Color(0.62, 0.68, 0.52)
const BLOOD := Color(0.66, 0.38, 0.32)


## Fundo de neblina em pontilhado: `darkness` no lado escuro, `side` 1 = escuro vindo da esquerda,
## 0 = por igual; `fog` é quanto de neblina passa.
static func fog_backdrop(darkness: float, side: float, fog := 0.2) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Fog"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter(&"noise", NOISE)
	material.set_shader_parameter(&"darkness", darkness)
	material.set_shader_parameter(&"side", side)
	material.set_shader_parameter(&"fog", fog)
	rect.material = material
	return rect


## Botão de menu (texto grande, a plaquinha ocre aparece com o mouse ou o foco).
static func menu_button(text: String, action: Callable, font_size := 32) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"MenuItem"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if font_size != 32:
		button.add_theme_font_size_override(&"font_size", font_size)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.grab_focus())
	button.pressed.connect(action)
	return button


static func label(text: String, variation := &"", font_size := 0) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	if font_size > 0:
		node.add_theme_font_size_override(&"font_size", font_size)
	return node


static func separator() -> HSeparator:
	var line := HSeparator.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## "#d9c27a" de uma cor, para BBCode.
static func hex(color: Color) -> String:
	return "#" + color.to_html(false)
