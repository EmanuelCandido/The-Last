class_name BlurredVision
extends CanvasLayer
## A visão de Ari dopado (§7): borrada, com cores separadas, imagem dupla e pálpebras que
## pesam (blurred_vision.gdshader), e a legenda do que se ouve (a voz do Zelador não tem
## dublagem). Usada nos flashes e ao acordar na cápsula. Fica embaixo da tela preta do
## ScreenFade (a UI da Main fica na camada 2).

const SHADER := preload("res://assets/shaders/blurred_vision.gdshader")

## 0 = visão limpa, 1 = toda borrada.
var amount := 0.0:
	set(value):
		amount = value
		_refresh()
## 0 = olhos abertos, 1 = fechados.
var lids := 0.0:
	set(value):
		lids = value
		_refresh()
## A visão fechando pelas bordas (0 = aberta): a lucidez acabando.
var tunnel := 0.0:
	set(value):
		tunnel = value
		_refresh()

var _material: ShaderMaterial
var _overlay: ColorRect
var _subtitle: Label
var _subtitle_tween: Tween


func _ready() -> void:
	layer = 1
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_overlay.material = _material
	add_child(_overlay)
	_subtitle = Label.new()
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# Falas compridas (a conversa do Ato IV) quebram em linhas, longe do HUD vital no canto.
	_subtitle.anchor_left = 0.18
	_subtitle.anchor_right = 0.82
	_subtitle.offset_left = 0.0
	_subtitle.offset_right = 0.0
	_subtitle.offset_top = -170.0
	_subtitle.offset_bottom = -70.0
	_subtitle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_color_override(&"font_color", Color(0.78, 0.95, 0.84))
	_subtitle.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_subtitle.add_theme_constant_override(&"shadow_offset_x", 2)
	_subtitle.add_theme_constant_override(&"shadow_offset_y", 2)
	_apply_text_scale()
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"text_scale_index":
			_apply_text_scale())
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)
	_refresh()


func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))


## A fonte é pixelada: 32 (o dobro da base) vezes o tamanho das Configurações.
func _apply_text_scale() -> void:
	_subtitle.add_theme_font_size_override(&"font_size", roundi(32.0 * Settings.text_scale()))


## Legenda de `seconds` segundos (entra e sai devagar).
func say(text: String, seconds: float) -> void:
	_subtitle.text = text
	if _subtitle_tween != null:
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(_subtitle, ^"modulate:a", 1.0, 0.3)
	_subtitle_tween.tween_interval(maxf(seconds - 0.8, 0.1))
	_subtitle_tween.tween_property(_subtitle, ^"modulate:a", 0.0, 0.5)


## Visão limpa, sem legenda.
func clear() -> void:
	if _subtitle_tween != null:
		_subtitle_tween.kill()
	_subtitle.modulate.a = 0.0
	amount = 0.0
	lids = 0.0
	tunnel = 0.0


func _refresh() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"amount", amount)
	_material.set_shader_parameter(&"lids", lids)
	_material.set_shader_parameter(&"tunnel", tunnel)
	_overlay.visible = amount > 0.001 or lids > 0.001 or tunnel > 0.001
