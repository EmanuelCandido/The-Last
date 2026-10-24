extends Control
## HUD discreto: ação disponível, avisos, itens, mira do arco, sinais vitais (VitalsHud, §7) e
## painel de desempenho (F3).
##
## Para não quebrar a imersão, as dicas de controle e os avisos somem sozinhos e a
## mira só aparece mirando. Os itens ficam no canto de baixo, direto sobre a cena: o ícone
## pixelado (UiStyle.item_icon) e a quantidade. Avisos, prompt e dicas ficam sobre uma mancha
## escura pontilhada (variação Smudge do Theme), que lê sobre a neblina clara; a tecla da ação
## aparece desenhada (Keycap). Com o jogo pausado, o HUD some (o menu de pausa fica sozinho).
## Configurações: tamanho dos avisos e do prompt (Settings.text_scale) e dicas de controle ligadas
## ou não (Settings.show_hints).

## Segundos até as dicas de controle sumirem.
@export var hint_duration := 14.0
## Segundos que um aviso fica na tela antes de sumir.
@export var notice_duration := 3.5

var _notice_tween: Tween
var _hint_tween: Tween
var _hint_alpha := 1.0
## Uma anotação entrou no escuro (sono, flash, Abrigo): o aviso espera o goblin acordar.
var _note_pending := false

@onready var _debug_label: Label = %DebugLabel
@onready var _hint_box: Control = %HintBox
@onready var _controls_hint: RichTextLabel = %ControlsHint
@onready var _prompt_box: Control = %PromptBox
@onready var _prompt_key: Control = %PromptKey
@onready var _key_label: Label = %KeyLabel
@onready var _prompt: Label = %Prompt
@onready var _notice_box: Control = %NoticeBox
@onready var _notice: Label = %Notice
@onready var _items_box: HBoxContainer = %ItemsBox
@onready var _crosshair: Control = %Crosshair
@onready var _vignette: ColorRect = %Vignette
@onready var _vignette_material: ShaderMaterial = _vignette.material


func _ready() -> void:
	_debug_label.visible = false
	_set_prompt("")
	_notice_box.modulate.a = 0.0
	Events.prompt_changed.connect(_set_prompt)
	Events.notification_shown.connect(_show_notice)
	Events.game_paused.connect(func(paused: bool) -> void: visible = not paused)
	Inventory.changed.connect(func(_item: StringName, _amount: int) -> void: _refresh_items())
	_crosshair.draw.connect(_draw_crosshair)
	_key_label.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	Settings.changed.connect(_on_settings_changed)
	_refresh_items()
	_refresh_hint()
	_apply_text_scale()
	var vitals := VitalsHud.new()
	vitals.name = "Vitals"
	add_child(vitals)
	_show_hint()
	# O menu principal fecha: as dicas de controle aparecem de novo para quem chega.
	Events.game_started.connect(_show_hint)
	Story.note_added.connect(func(_text: String) -> void: _on_note())
	Events.woke_up.connect(func(_reason: StringName) -> void: _flush_note())
	Events.shelter_left.connect(_flush_note)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug_label.visible = not _debug_label.visible


func _process(_delta: float) -> void:
	var aiming := Game.player != null and Game.player.aiming
	_crosshair.visible = aiming
	if aiming:
		_crosshair.queue_redraw()
	# No mundo real (acordado ou num flash), o inventário e as teclas do goblin não existem; nas
	# cenas do mistério (o travamento, a memória), no menu e com o goblin da IA, nada do HUD.
	var watching := Game.cutscene or Game.menu_open or Game.welcome
	var real := Game.awake or Game.in_flash() or watching
	_items_box.visible = not real and _items_box.get_child_count() > 0
	_hint_box.visible = not real and Settings.show_hints and _hint_alpha > 0.0
	_hint_box.modulate.a = _hint_alpha
	_prompt_box.get_parent().visible = not watching
	_update_vignette()
	if not _debug_label.visible:
		return
	_debug_label.text = "FPS: %d\nDraw calls: %d\nTriângulos: %d\nMemória: %.1f MB" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]


func _show_hint() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_alpha = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(hint_duration)
	_hint_tween.tween_property(self, ^"_hint_alpha", 0.0, 2.0)


## As dicas de controle com as teclas de agora: "[W A S D] mover · [Shift] correr...".
func _refresh_hint() -> void:
	var keys := Settings.key_labels()
	var walk: String = keys["move"] if Settings.using_gamepad else \
		"%s %s %s %s" % [keys["move_forward"], keys["move_left"], keys["move_back"], keys["move_right"]]
	var parts := PackedStringArray()
	for pair: Array in [[walk, "mover"], [keys["sprint"], "correr"], [keys["crouch"], "agachar"],
			[keys["interact"], "pegar"], [keys["eat"], "comer"], [keys["pause"], "pausar (veja as Dicas)"]]:
		parts.append("[color=%s]%s[/color] %s" % [UiStyle.hex(UiStyle.ACCENT), pair[0], pair[1]])
	_controls_hint.text = "  ·  ".join(parts)


## "[E] Pegar o arco": a tecla vai para a tecla desenhada, o resto para o texto.
func _set_prompt(text: String) -> void:
	var key := ""
	if text.begins_with("[") and text.find("]") > 0:
		key = text.substr(1, text.find("]") - 1)
		text = text.substr(text.find("]") + 1).strip_edges()
	_prompt.text = text
	_key_label.text = key
	_prompt_key.visible = key != ""
	_prompt_box.visible = text != "" or key != ""


## Mira: um ponto e quatro traços que fecham conforme a corda é puxada, tudo em pixels inteiros.
func _draw_crosshair() -> void:
	var center := (_crosshair.size * 0.5).floor()
	var draw_amount := Game.player.draw if Game.player != null else 0.0
	var gap := roundf(lerpf(12.0, 3.0, draw_amount))
	var ink := Color(UiStyle.INK, 0.55 + 0.4 * draw_amount)
	var shade := Color(0.0, 0.0, 0.0, 0.5)
	_crosshair.draw_rect(Rect2(center - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), shade)
	_crosshair.draw_rect(Rect2(center, Vector2(1.0, 1.0)), Color(UiStyle.INK, 0.9))
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var start := center + direction * gap
		var tick := Rect2(start, direction * 4.0 + Vector2(1.0, 1.0) * (Vector2.ONE - direction.abs())).abs()
		_crosshair.draw_rect(tick.grow(1.0), shade)
		_crosshair.draw_rect(tick, ink)


func _show_notice(text: String) -> void:
	_notice.text = text
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_box.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(notice_duration)
	_notice_tween.tween_property(_notice_box, "modulate:a", 0.0, 1.2)


## Uma anotação nova (Story.notes): avisa onde ler. No escuro (dormindo, num flash, acordado no
## Abrigo, numa cena), o aviso espera e sai quando o goblin já está de pé.
func _on_note() -> void:
	if Game.resting or Game.awake or Game.cutscene or Game.in_flash() or Game.menu_open:
		_note_pending = true
		return
	Events.notification_shown.emit("Anotação nova. [%s] Dicas" % Settings.key_label(&"pause", true))


func _flush_note() -> void:
	if not _note_pending:
		return
	_note_pending = false
	# Acordar leva uns 6 s (a cena de levantar): o aviso vem depois, com a tela clara.
	get_tree().create_timer(Tuning.NOTE_NOTICE_DELAY, false).timeout.connect(_on_note)


func _on_settings_changed(key: StringName) -> void:
	match key:
		&"text_scale_index":
			_apply_text_scale()
			_refresh_items()
		&"keys", &"input_device":
			_refresh_hint()
		&"show_hints":
			if Settings.show_hints:
				_show_hint()


## Avisos e prompt no tamanho escolhido (a fonte é pixelada: 16 é o tamanho de base).
func _apply_text_scale() -> void:
	var font_size := roundi(16.0 * Settings.text_scale())
	for label: Label in [_notice, _prompt, _key_label]:
		label.add_theme_font_size_override(&"font_size", font_size)


## Vida baixa ou fome machucando: a borda da tela escurece e pulsa no ritmo do coração
## (mais rápido quanto pior).
func _update_vignette() -> void:
	var hurt := clampf((Tuning.LOW_HEALTH - Vitals.health) / Tuning.LOW_HEALTH, 0.0, 1.0)
	if Vitals.satiety <= 0.0:
		hurt = maxf(hurt, 0.3)
	_vignette.visible = hurt > 0.0 and Game.player != null and not Game.awake and not Game.menu_open
	if not _vignette.visible:
		return
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * lerpf(1.1, 2.0, hurt))
	_vignette_material.set_shader_parameter(&"amount", hurt * (0.8 + 0.2 * beat))
	_vignette_material.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))


## A linha de itens: o ícone de cada um (a 2x) e a quantidade ao lado. Item sem ícone mostra o nome.
func _refresh_items() -> void:
	for child in _items_box.get_children():
		_items_box.remove_child(child)
		child.queue_free()
	var font_size := UiStyle.hud_font_size()
	for item: StringName in Inventory.HUD_ORDER:
		var amount := Inventory.count(item)
		if amount <= 0 and not (item == &"arrow" and Inventory.has(&"bow")):
			continue
		var group := HBoxContainer.new()
		group.add_theme_constant_override(&"separation", 8)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := UiStyle.item_icon(item)
		if icon != null:
			group.add_child(UiStyle.sprite(icon, 2))
		else:
			group.add_child(UiStyle.label(Inventory.NAMES.get(item, String(item)), &"Hint", font_size))
		group.add_child(UiStyle.label(str(amount), &"", font_size))
		_items_box.add_child(group)
