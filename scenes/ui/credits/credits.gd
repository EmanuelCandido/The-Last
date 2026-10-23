class_name Credits
extends CanvasLayer
## Os créditos (§8): o texto de StoryBeats.CREDITS subindo pela tela. Sobre a floresta (Final 1)
## eles passam por cima do jogo, que continua (`over_world`); nos outros finais, sobre o preto.
## Depois de Tuning.CREDITS_SKIP_AFTER segundos, Esc, E ou Enter pulam.

signal finished

const TITLE_COLOR := Color(0.85, 0.76, 0.48)
const TEXT_COLOR := Color(0.82, 0.84, 0.8)

## Por cima do jogo (true) ou sobre o preto.
var over_world := false

var _column: VBoxContainer
var _back: ColorRect
var _time := 0.0
var _done := false


func _ready() -> void:
	layer = 8
	_back = ColorRect.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.color = Color(0.0, 0.0, 0.0, 0.35 if over_world else 1.0)
	add_child(_back)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	add_child(_column)
	for line in StoryBeats.CREDITS.split("\n"):
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override(&"shadow_offset_x", 2)
		label.add_theme_constant_override(&"shadow_offset_y", 2)
		if line.begins_with("#"):
			label.text = line.substr(1)
			label.add_theme_font_size_override(&"font_size", 34 if label.text == "A TOCA" else 22)
			label.add_theme_color_override(&"font_color", TITLE_COLOR)
		else:
			label.text = line
			label.add_theme_font_size_override(&"font_size", 18)
			label.add_theme_color_override(&"font_color", TEXT_COLOR)
		_column.add_child(label)
	var screen := get_viewport().get_visible_rect().size
	_column.size = Vector2(screen.x, 0.0)
	_column.position = Vector2(0.0, screen.y)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var screen := get_viewport().get_visible_rect().size
	_column.size.x = screen.x
	_column.position.y -= Tuning.CREDITS_SPEED * delta
	if _column.position.y + _column.size.y < -20.0:
		_finish()


func _input(event: InputEvent) -> void:
	if _done or _time < Tuning.CREDITS_SKIP_AFTER:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_finish()


## Passa os créditos e espera acabar.
func play() -> void:
	await finished


func _finish() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_column, ^"modulate:a", 0.0, 1.2)
	if over_world:
		tween.tween_property(_back, ^"color:a", 0.0, 1.2)
	await tween.finished
	finished.emit()
	queue_free()
