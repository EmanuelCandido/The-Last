class_name Credits
extends CanvasLayer
## Os créditos (§8): o texto de StoryBeats.CREDITS subindo pela tela. Sobre a floresta (Final 1)
## eles passam por cima do jogo, que continua (`over_world`); nos outros finais, sobre o preto.
## Depois de Tuning.CREDITS_SKIP_AFTER segundos, Esc, E ou Enter pulam.

signal finished

## Por cima do jogo (true) ou sobre o preto.
var over_world := false

var _column: VBoxContainer
var _back: Control
var _time := 0.0
var _done := false


func _ready() -> void:
	layer = 8
	# Por cima do jogo, uma neblina escura em pontilhado; nos outros finais, o preto.
	if over_world:
		_back = UiStyle.fog_backdrop(0.5, 0.0, 0.1)
	else:
		var black := ColorRect.new()
		black.set_anchors_preset(Control.PRESET_FULL_RECT)
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		black.color = Color.BLACK
		_back = black
	add_child(_back)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	add_child(_column)
	for line in StoryBeats.CREDITS.split("\n"):
		var label: Label
		if line.begins_with("#"):
			var title := line.substr(1)
			label = UiStyle.label(title, &"Title" if title == "A TOCA" else &"Heading")
		else:
			label = UiStyle.label(line)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		tween.tween_property(_back, ^"modulate:a", 0.0, 1.2)
	await tween.finished
	finished.emit()
	queue_free()
