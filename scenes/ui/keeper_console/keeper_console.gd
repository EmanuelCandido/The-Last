class_name KeeperConsole
extends CanvasLayer
## O console do Zelador (§7 e §8), no terminal da sala de controle. Os comandos do DevTools viram
## poderes da história: `neblina off` some com a neblina da floresta (flag "fog_off"), `teleport`
## escolhe onde o goblin acorda, `give` cria itens. E os comandos dos finais: `ficar`, `acordar` e
## o secreto, `trocar <senha>`, que só aceita a senha da carta (Story.password).
## O texto da ajuda fica em StoryBeats.CONSOLE_HELP. Esc (B no controle) ou `sair` fecha.
## Embaixo da linha de digitar ficam os comandos rápidos (F10), para quem joga com controle: a
## cruz escolhe e A envia. O `trocar <senha>` continua só digitando (a senha vem de fora do jogo).

## Fechou (Esc ou "sair").
signal closed
## Um comando dos finais: "ficar", "acordar" ou "trocar" (a senha já conferida).
signal chose(reason: StringName)

const KEY_SOUND := preload("res://assets/audio/sfx/stone_click_2.wav")
const COLOR := Color(0.45, 1.0, 0.6)
const DIM := Color(0.3, 0.62, 0.4)
## Os comandos rápidos, na ordem dos botões.
const QUICK := ["ajuda", "status", "neblina off", "neblina on", "ficar", "acordar", "sair"]
## Lugares do `teleport` (x, z no chão da floresta).
const PLACES := {
	"caverna": ForestLayout.SPAWN,
	"clareira": ForestLayout.MEADOW,
	"trilha": Vector2(4.0, 2.0),
	"ruina": Vector2(-15.0, -38.0),
	"norte": Vector2(-2.0, -86.0),
}
## O que o Zelador anota de cada objetivo real que Ari fez (o status mostra).
const ALERTS := {
	&"room_seen": "paciente fora da cápsula",
	&"blind_spot": "sensor do corredor desligado",
	&"climate_cut": "cabo do clima cortado",
	&"access_card": "cartão de acesso fora do peito",
}

var _log: RichTextLabel
var _field: LineEdit
var _keys: AudioStreamPlayer
var _quick_first: Button


func _ready() -> void:
	layer = 6
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "monospace"])
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.0, 0.02, 0.01, 0.97)
	add_child(back)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, 90)
	for side: String in ["top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 60)
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	frame.add_child(column)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.bbcode_enabled = true
	_log.add_theme_font_override(&"normal_font", font)
	_log.add_theme_font_size_override(&"normal_font_size", 17)
	_log.add_theme_color_override(&"default_color", COLOR)
	column.add_child(_log)
	var row := HBoxContainer.new()
	column.add_child(row)
	var caret := Label.new()
	caret.text = "> "
	caret.add_theme_font_override(&"font", font)
	caret.add_theme_font_size_override(&"font_size", 17)
	caret.add_theme_color_override(&"font_color", COLOR)
	row.add_child(caret)
	_field = LineEdit.new()
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.flat = true
	_field.caret_blink = true
	_field.add_theme_font_override(&"font", font)
	_field.add_theme_font_size_override(&"font_size", 17)
	_field.add_theme_color_override(&"font_color", COLOR)
	_field.add_theme_color_override(&"caret_color", COLOR)
	for style: StringName in [&"normal", &"focus", &"read_only"]:
		_field.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_field.text_submitted.connect(run)
	_field.text_changed.connect(func(_text: String) -> void: _click())
	row.add_child(_field)
	column.add_child(_quick_row(font))
	_keys = AudioStreamPlayer.new()
	_keys.stream = KEY_SOUND
	_keys.bus = &"Shelter"
	_keys.volume_db = -22.0
	add_child(_keys)
	_print("ZL-0 · UNIDADE DE CUIDADO · ABRIGO 9 · ALA C")
	_print("PACIENTE: ARI · LEITO 2714 · CICLO %d · ESTADO: ACORDADO" % Story.cycle)
	_print("[color=#%s]digite 'ajuda' para ver os comandos.[/color]\n" % DIM.to_html(false))
	if Settings.using_gamepad:
		_quick_first.grab_focus()
	else:
		_field.grab_focus()


func _input(event: InputEvent) -> void:
	var escape: bool = event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE
	if escape or (event is InputEventJoypadButton and event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		closed.emit()


## A linha de comandos rápidos: botões sem moldura, na cor do terminal.
func _quick_row(font: Font) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	for command: String in QUICK:
		var button := Button.new()
		button.text = "[%s]" % command
		button.flat = true
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_override(&"font", font)
		button.add_theme_font_size_override(&"font_size", 15)
		for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(state, DIM)
		button.add_theme_color_override(&"font_focus_color", COLOR)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(COLOR, 0.15)
		button.add_theme_stylebox_override(&"focus", focus)
		button.pressed.connect(func() -> void:
			_click()
			run(command))
		row.add_child(button)
		if _quick_first == null:
			_quick_first = button
	return row


## Roda um comando (o que se digitou e Enter).
func run(text: String) -> void:
	_field.clear()
	var line := text.strip_edges()
	if line == "":
		return
	_print("[color=#%s]> %s[/color]" % [DIM.to_html(false), line.replace("[", "[lb]")])
	var words := line.to_lower().split(" ", false)
	var command := words[0]
	var args := words.slice(1)
	match command:
		"ajuda", "help", "?":
			_print(StoryBeats.CONSOLE_HELP)
		"status":
			_status()
		"neblina":
			_fog(args)
		"ameaca", "ameaça":
			_threat(args)
		"teleport":
			_teleport(args)
		"give":
			_give(args)
		"ficar":
			_print("Vou desligar a contagem. Durma, Ari.")
			chose.emit(&"ficar")
		"acordar":
			_print("ABRINDO A SAÍDA BLINDADA...")
			chose.emit(&"acordar")
		"trocar":
			# A senha volta com as maiúsculas da carta: compara sem elas.
			var password := line.substr(command.length()).strip_edges()
			if password == "":
				_print("uso: trocar <senha>")
			elif Story.secret != "" and password.to_upper() == Story.secret:
				_print("SENHA ACEITA. INTERFACE DA CÁPSULA: TRANSFERIR ZL-0 → LEITO 2714")
				chose.emit(&"trocar")
			else:
				_print("SENHA RECUSADA.")
		"sair", "exit":
			closed.emit()
		_:
			_print("comando desconhecido: %s. 'ajuda' mostra os comandos." % command.replace("[", "[lb]"))


func _status() -> void:
	var done := PackedStringArray()
	for objective in Story.objectives:
		done.append(ALERTS.get(StringName(objective), objective))
	_print("PACIENTE: ARI, 41 · LEITO 2714 · NUTRIÇÃO %d%%" % roundi(Vitals.satiety))
	_print("SIMULAÇÃO 'A TOCA' · CICLO %d · DIA %d · %02d:%02d" % [Story.cycle, Clock.day, int(Clock.hour), int(fmod(Clock.hour, 1.0) * 60.0)])
	_print("VIGILÂNCIA %d%% · NEBLINA %s" % [roundi(Story.vigilance), "DESLIGADA" if Story.has_flag(&"fog_off") else "LIGADA"])
	# F12: a ameaça (os orcs). Na segunda leitura, o medo de quem vem de fora.
	var band := get_tree().get_first_node_in_group(OrcBand.GROUP) as OrcBand
	var threat := "DESLIGADA" if Story.has_flag(&"orcs_off") else "DIA %d DE %d" % [Clock.day, Tuning.ORC_FIRST_DAY] if Clock.day < Tuning.ORC_FIRST_DAY else "ATIVA"
	_print("AMEAÇA EXTERNA: %s · %d NA SIMULAÇÃO · ABATIDOS %d" % [threat, band.orcs().size() if band != null else 0, Story.count(&"orc_killed")])
	_print("ALERTAS DESTE CICLO: %s" % (", ".join(done) if not done.is_empty() else "nenhuma"))
	_print("ÚLTIMO CONTATO DE RÁDIO: 11/04/2038 · RESPOSTA: SEM SOBREVIVENTES")


func _fog(args: PackedStringArray) -> void:
	if args.is_empty() or args[0] not in ["off", "on"]:
		_print("uso: neblina off | on")
		return
	var off := args[0] == "off"
	Story.set_flag(&"fog_off", off)
	_print("neblina %s no setor da toca." % ("desligada" if off else "ligada"))


func _threat(args: PackedStringArray) -> void:
	if args.is_empty() or args[0] not in ["off", "on"]:
		_print("uso: ameaca off | on")
		return
	var off := args[0] == "off"
	Story.set_flag(&"orcs_off", off)
	_print("ameaça externa %s." % ("desligada" if off else "ligada"))


func _teleport(args: PackedStringArray) -> void:
	if args.is_empty() or not PLACES.has(args[0]):
		_print("uso: teleport <lugar> · lugares: %s" % ", ".join(PLACES.keys()))
		return
	Game.forest_teleport = PLACES[args[0]]
	_print("o goblin vai acordar em: %s." % args[0])


func _give(args: PackedStringArray) -> void:
	var names := {}
	for item: StringName in Inventory.NAMES:
		names[String(item)] = item
	if args.is_empty() or not names.has(args[0]):
		_print("uso: give <item> [n] · itens: %s" % ", ".join(names.keys()))
		return
	var amount := clampi(int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1, 1, 99)
	Inventory.add(names[args[0]], amount)
	_print("+%d %s." % [amount, Inventory.NAMES[names[args[0]]].to_lower()])


func _print(text: String) -> void:
	_log.append_text(text + "\n")


func _click() -> void:
	_keys.pitch_scale = randf_range(1.6, 2.1)
	_keys.play()
