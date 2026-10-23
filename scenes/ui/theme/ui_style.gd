class_name UiStyle
extends RefCounted
## Peças da interface no estilo do jogo, por cima do Theme único (assets/ui/ui_theme.tres, o tema
## do projeto): a paleta para BBCode e desenho, o painel de rocha dos menus, o logo, os botões de
## menu com o marcador laranja, o rodapé com a tecla-lápide, os ícones dos itens e as linhas.
## A fonte "Toca" é pixelada com 16 px de base: os tamanhos bons são 16, 32, 48 e 64. As peças
## desenhadas (tools/generate_ui.py) também vão em escala inteira: as de rocha a 3x, o resto a 2x
## ou 3x.
##
## Variações do Theme: Title (64), MenuTitle (48, negrito e espaçado: "PAUSADO"), Heading (32,
## ocre), Hint (apagado), MenuItem (botão de menu, 32, com a faixa no foco), TabButton (aba),
## PanelDark, Smudge (mancha atrás do texto do HUD) e Keycap (tecla).

const FOG_SHADER := preload("res://assets/shaders/ui_fog.gdshader")
const NOISE := preload("res://assets/textures/macro_noise.png")
const LOGO := preload("res://assets/ui/logo.png")
const TALLY := preload("res://assets/ui/tally.png")
const CAVE_ICON := preload("res://assets/ui/cave_icon.png")
const KEY_ICON := preload("res://assets/ui/key_icon.png")
const MARKER := preload("res://assets/ui/marker.png")
const UP_DOWN := preload("res://assets/ui/up_down.png")
const ITEM_ICONS := preload("res://assets/ui/item_icons.png")
## Os painéis de rocha, todos a 3x: o do menu principal, o da pausa e o largo (Configurações, Dicas).
const ROCKS := {
	&"menu": preload("res://assets/ui/rock_menu.png"),
	&"pause": preload("res://assets/ui/rock_pause.png"),
	&"wide": preload("res://assets/ui/rock_wide.png"),
}
## A ordem dos ícones no atlas item_icons.png (a mesma de ICONS no tools/generate_ui.py).
const ICONS: Array[StringName] = [
	&"arrow", &"feathered_arrow", &"bone_arrow", &"stone", &"wood", &"meat", &"cooked_meat",
	&"smoked_meat", &"rotten_meat", &"berries", &"mushroom", &"white_meat", &"hide", &"bone",
	&"feather", &"snare",
]
## Lado de cada ícone no atlas, com a sombra.
const ICON_CELL := 13
## Onde começa a coluna dos menus (logo, título e itens) e a margem de baixo do rodapé.
const MENU_LEFT := 104.0
const FOOTER_BOTTOM := 44.0

## Osso (texto), apagado, sumido, ocre de vela (destaque), musgo (anotações), sangue seco e o
## laranja do marcador de foco.
const INK := Color(0.84, 0.82, 0.76)
const INK_DIM := Color(0.56, 0.56, 0.52)
const INK_FAINT := Color(0.38, 0.39, 0.37)
const ACCENT := Color(0.86, 0.76, 0.52)
const MOSS := Color(0.62, 0.68, 0.52)
const BLOOD := Color(0.66, 0.38, 0.32)
const MARK := Color(0.88, 0.58, 0.25)

static var _icon_cache := {}


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


## O painel de rocha colado à esquerda, da altura da tela, com a borda direita em silhueta. O mundo
## aparece à direita sem escurecer. `kind`: &"menu", &"pause" ou &"wide".
static func rock_panel(kind: StringName) -> TextureRect:
	var texture: Texture2D = ROCKS[kind]
	var rect := TextureRect.new()
	rect.name = "Rock"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.anchor_bottom = 1.0
	rect.offset_right = texture.get_width() * 3.0
	return rect


## Uma peça desenhada em escala inteira (o pixel da textura vira `scale` pixels da tela).
static func sprite(texture: Texture2D, scale: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = texture.get_size() * scale
	rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## O título dos menus ("PAUSADO"): negrito, espaçado e em maiúsculas.
static func menu_title(text: String) -> Label:
	return label(text.to_upper(), &"MenuTitle")


## A linha de baixo do título: os três riscos e, ao lado, um texto apagado ("Dia 4 · tarde").
static func tally_line(text := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sprite(TALLY, 2))
	var hint := label(text, &"Hint", 32)
	hint.name = "Text"
	hint.visible = text != ""
	row.add_child(hint)
	return row


## O rodapé dos menus: a tecla-lápide e "[Esc] Voltar ao jogo". Fica no canto de baixo de `parent`.
static func footer(parent: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Footer"
	row.add_theme_constant_override(&"separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = MENU_LEFT - 34.0
	row.offset_top = -FOOTER_BOTTOM - 42.0
	row.offset_bottom = -FOOTER_BOTTOM
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.add_child(sprite(KEY_ICON, 2))
	var hint := label(text, &"Hint", 32)
	hint.name = "Text"
	row.add_child(hint)
	parent.add_child(row)
	return row


## Botão de menu (texto grande; no foco, a faixa quente atrás e o marcador laranja à esquerda).
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
	add_marker(button, 3 if font_size >= 32 else 2)
	return button


## O marcador laranja ("[ )"), à esquerda de `control`, que só aparece com ele em foco.
static func add_marker(control: Control, scale := 3) -> TextureRect:
	var marker := sprite(MARKER, scale)
	marker.name = "Marker"
	var marker_size := MARKER.get_size() * scale
	marker.anchor_top = 0.5
	marker.anchor_bottom = 0.5
	marker.offset_left = -marker_size.x - 2.0 * scale
	marker.offset_right = -2.0 * scale
	marker.offset_top = -floorf(marker_size.y * 0.5)
	marker.offset_bottom = marker.offset_top + marker_size.y
	marker.visible = false
	control.add_child(marker)
	control.focus_entered.connect(func() -> void: marker.visible = true)
	control.focus_exited.connect(func() -> void: marker.visible = false)
	return marker


## Tamanho do texto do canto do HUD (itens e lista de fabricar): 32 no tamanho normal, 48 e 64 nos
## maiores das Configurações (sempre múltiplo de 16, a base da fonte).
static func hud_font_size() -> int:
	return roundi(32.0 * Settings.text_scale() / 16.0) * 16


## O ícone pixelado de um item do HUD (null se não tiver).
static func item_icon(item: StringName) -> Texture2D:
	if _icon_cache.has(item):
		return _icon_cache[item]
	var index := ICONS.find(item)
	var icon: AtlasTexture = null
	if index >= 0:
		icon = AtlasTexture.new()
		icon.atlas = ITEM_ICONS
		icon.region = Rect2(index * ICON_CELL, 0, ICON_CELL, ICON_CELL)
	_icon_cache[item] = icon
	return icon


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
