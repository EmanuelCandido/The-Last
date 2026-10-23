extends Control
## HUD discreto: ação disponível, avisos, itens, mira do arco e painel de desempenho (F3).
##
## Para não quebrar a imersão, as dicas de controle e os avisos somem sozinhos e a
## mira só aparece mirando.

## Segundos até as dicas de controle sumirem.
@export var hint_duration := 14.0
## Segundos que um aviso fica na tela antes de sumir.
@export var notice_duration := 3.5

var _notice_tween: Tween

@onready var _debug_label: Label = %DebugLabel
@onready var _controls_hint: Label = $ControlsHint
@onready var _prompt: Label = %Prompt
@onready var _notice: Label = %Notice
@onready var _items: Label = %Items
@onready var _crosshair: Control = %Crosshair
@onready var _vignette: ColorRect = %Vignette
@onready var _vignette_material: ShaderMaterial = _vignette.material


func _ready() -> void:
	_debug_label.visible = false
	_prompt.text = ""
	_notice.modulate.a = 0.0
	Events.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
	Events.notification_shown.connect(_show_notice)
	Inventory.changed.connect(func(_item: StringName, _amount: int) -> void: _refresh_items())
	_crosshair.draw.connect(_draw_crosshair)
	_refresh_items()
	var tween := create_tween()
	tween.tween_interval(hint_duration)
	tween.tween_property(_controls_hint, "modulate:a", 0.0, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_label.visible = not _debug_label.visible


func _process(_delta: float) -> void:
	var aiming := Game.player != null and Game.player.aiming
	_crosshair.visible = aiming
	if aiming:
		_crosshair.queue_redraw()
	_update_vignette()
	if not _debug_label.visible:
		return
	_debug_label.text = "FPS: %d\nDraw calls: %d\nTriângulos: %d\nMemória: %.1f MB" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]


## Ponto no centro e um anel que fecha conforme a corda é puxada.
func _draw_crosshair() -> void:
	var center := _crosshair.size * 0.5
	var draw_amount := Game.player.draw if Game.player != null else 0.0
	_crosshair.draw_circle(center, 1.6, Color(1.0, 1.0, 1.0, 0.8))
	_crosshair.draw_arc(center, lerpf(15.0, 4.0, draw_amount), 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.35 + 0.4 * draw_amount), 1.2)


func _show_notice(text: String) -> void:
	_notice.text = text
	if _notice_tween != null:
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(notice_duration)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 1.2)


## Vida baixa ou fome machucando: a borda da tela escurece e pulsa no ritmo do coração
## (mais rápido quanto pior).
func _update_vignette() -> void:
	var hurt := clampf((Tuning.LOW_HEALTH - Vitals.health) / Tuning.LOW_HEALTH, 0.0, 1.0)
	if Vitals.satiety <= 0.0:
		hurt = maxf(hurt, 0.3)
	_vignette.visible = hurt > 0.0 and Game.player != null
	if not _vignette.visible:
		return
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * lerpf(1.1, 2.0, hurt))
	_vignette_material.set_shader_parameter(&"amount", hurt * (0.8 + 0.2 * beat))
	_vignette_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))


func _refresh_items() -> void:
	var parts := PackedStringArray()
	for item: StringName in [&"arrow", &"wood", &"meat", &"cooked_meat", &"hide"]:
		var amount := Inventory.count(item)
		if amount > 0 or (item == &"arrow" and Inventory.has(&"bow")):
			parts.append("%s: %d" % [Inventory.NAMES[item], amount])
	_items.text = "    ".join(parts)
