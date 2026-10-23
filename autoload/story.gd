extends Node
## Estado da história: ato, ciclo, riscos na parede, flags, contadores, anotações e a
## Vigilância (o Zelador observando, §5).
##
## O que acontece e quando vem de StoryBeats (data/story_beats.gd): aqui só se guarda
## o estado e se avaliam os beats quando um gatilho acontece. Os sistemas reagem ao
## estado (flag_changed, act_changed) sem saber qual beat o mudou.

signal changed
signal flag_changed(flag: StringName, value: bool)
signal act_changed(act: int)
signal note_added(text: String)
signal vigilance_changed(value: float)

const START_CYCLE := 347

var act := 1
var cycle := START_CYCLE
## Riscos deste ciclo (um por noite dormida na pele).
var marks := 0
## Riscos de ciclos passados, debaixo do musgo.
var old_marks := Tuning.OLD_MARKS
## Anotações que o próprio Ari deixou (Dicas que mudam). Sobrevivem à Reciclagem.
var notes: PackedStringArray = []
## Vigilância (0..100): só conta a partir de Tuning.VIGILANCE_FROM_ACT. Em 100, Reciclagem.
var vigilance := 0.0
## Objetivos reais concluídos, em ordem (F6). A Reciclagem desfaz o último.
var objectives: PackedStringArray = []
## Senha do Final 3 (§7), sorteada uma vez por save e escrita no leia_me ("" = ainda não).
var secret := ""

## Algo fez a Vigilância subir hoje (dormir num dia calmo a baixa).
var _alarmed_today := false
## Dia em que um corvo já viu o goblin no teclado da ruína (conta uma vez por dia).
var _keypad_seen_day := -1

var _flags := {}
var _counters := {}
var _fired := {}


func _ready() -> void:
	Events.level_loaded.connect(func(_level: Node3D) -> void: trigger(&"start"))
	Events.slept.connect(_on_slept)
	Events.woke_up.connect(func(reason: StringName) -> void: trigger(&"woke", reason))
	Events.player_died.connect(func(cause: StringName) -> void: trigger(&"died", cause))
	Events.ate.connect(func(food: StringName) -> void: trigger(&"ate", food))
	Events.animal_harvested.connect(_on_harvested)
	Events.crafted.connect(func(recipe: StringName) -> void: add_count(StringName("%s_crafted" % recipe)))
	Events.crow_shot.connect(func() -> void: add_vigilance(Tuning.VIGILANCE_CROW_SHOT))
	Events.ate.connect(func(food: StringName) -> void:
		if food == &"cooked_meat":
			add_vigilance(Tuning.VIGILANCE_COOKED_MEAT))
	Events.woke_up.connect(func(_reason: StringName) -> void: _alarmed_today = false)
	Events.ritual_completed.connect(func(place: StringName) -> void: trigger(&"ritual", place))


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func set_flag(flag: StringName, value := true) -> void:
	if has_flag(flag) == value:
		return
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)
	flag_changed.emit(flag, value)
	changed.emit()


func set_act(value: int) -> void:
	if act == value:
		return
	act = value
	act_changed.emit(act)
	changed.emit()


func count(counter: StringName) -> int:
	return _counters.get(counter, 0)


func add_count(counter: StringName, amount := 1) -> void:
	_counters[counter] = count(counter) + amount
	changed.emit()


## Soma (ou tira) Vigilância. Antes do Ato II não conta; em 100, pede a Reciclagem.
func add_vigilance(amount: float) -> void:
	if act < Tuning.VIGILANCE_FROM_ACT or amount == 0.0:
		return
	if amount > 0.0:
		_alarmed_today = true
	var before := vigilance
	vigilance = clampf(vigilance + amount, 0.0, 100.0)
	if vigilance == before:
		return
	vigilance_changed.emit(vigilance)
	changed.emit()
	if vigilance >= 100.0 and before < 100.0:
		Events.recycle_requested.emit(&"vigilance")


## Um corvo viu o goblin mexendo no teclado da ruína: sobe uma vez por dia.
func crow_saw_keypad() -> void:
	if _keypad_seen_day == Clock.day:
		return
	_keypad_seen_day = Clock.day
	add_vigilance(Tuning.VIGILANCE_KEYPAD_SEEN)


## Um objetivo real foi concluído: liga o flag de mesmo nome e avalia os beats "objective".
func complete_objective(objective: StringName) -> void:
	if String(objective) in objectives:
		return
	objectives.append(String(objective))
	set_flag(objective)
	trigger(&"objective", objective)


## O objetivo pode ser feito agora: ainda não foi, e o anterior da corrente já foi.
func objective_ready(objective: StringName) -> bool:
	if has_flag(objective) or not StoryBeats.OBJECTIVES.has(objective):
		return false
	var needs: StringName = StoryBeats.OBJECTIVES[objective]
	return needs == &"" or has_flag(needs)


## A Reciclagem (§3): o ciclo avança, os riscos viram antigos, a Vigilância volta a
## Tuning.VIGILANCE_AFTER_RECYCLE e o último objetivo real é desfeito. Ato, flags e
## anotações ficam.
func recycle() -> void:
	cycle += 1
	old_marks += marks
	marks = 0
	vigilance = Tuning.VIGILANCE_AFTER_RECYCLE if act >= Tuning.VIGILANCE_FROM_ACT else 0.0
	if not objectives.is_empty():
		var undone := objectives[objectives.size() - 1]
		objectives.remove_at(objectives.size() - 1)
		set_flag(StringName(undone), false)
	_alarmed_today = false
	vigilance_changed.emit(vigilance)
	changed.emit()


## A senha do Final 3: MUSGO- e quatro dígitos, sorteada na primeira vez que é pedida.
func password() -> String:
	if secret == "":
		secret = "MUSGO-%04d" % randi_range(0, 9999)
		changed.emit()
	return secret


func add_note(text: String) -> void:
	if text in notes:
		return
	notes.append(text)
	note_added.emit(text)
	changed.emit()


## Avalia os beats do gatilho `on`. `reason` é o detalhe do gatilho (motivo de acordar,
## causa da morte, comida, bicho). Beat com "repeat" dispara toda vez que valer.
func trigger(on: StringName, reason: StringName = &"") -> void:
	for beat: Dictionary in StoryBeats.BEATS:
		var id: String = beat.id
		if beat.on != String(on) or _fired.has(id):
			continue
		if not _matches(beat.get("when", {}), reason):
			continue
		if not beat.get("repeat", false):
			_fired[id] = true
		_run(beat.get("do", []))


func save_data() -> Dictionary:
	return {
		"act": act,
		"cycle": cycle,
		"marks": marks,
		"old_marks": old_marks,
		"notes": Array(notes),
		"flags": _flags.keys().map(func(flag: StringName) -> String: return String(flag)),
		"counters": _counters.duplicate(),
		"fired": _fired.keys(),
		"vigilance": vigilance,
		"objectives": Array(objectives),
		"alarmed_today": _alarmed_today,
		"keypad_seen_day": _keypad_seen_day,
		"secret": secret,
	}


func load_data(data: Dictionary) -> void:
	act = int(data.get("act", 1))
	cycle = int(data.get("cycle", START_CYCLE))
	marks = int(data.get("marks", 0))
	old_marks = int(data.get("old_marks", Tuning.OLD_MARKS))
	notes = PackedStringArray(data.get("notes", []))
	_flags.clear()
	for flag: String in data.get("flags", []):
		_flags[StringName(flag)] = true
	_counters.clear()
	var counters: Dictionary = data.get("counters", {})
	for counter: String in counters:
		_counters[StringName(counter)] = int(counters[counter])
	_fired.clear()
	for id: String in data.get("fired", []):
		_fired[id] = true
	vigilance = float(data.get("vigilance", 0.0))
	objectives = PackedStringArray(data.get("objectives", []))
	_alarmed_today = bool(data.get("alarmed_today", false))
	_keypad_seen_day = int(data.get("keypad_seen_day", -1))
	secret = String(data.get("secret", ""))
	act_changed.emit(act)
	vigilance_changed.emit(vigilance)
	changed.emit()


## Usado pelo DevTools (--set=story.act:2, story.flag:moss_fell, story.marks:6).
func debug_set(key: String, value: String) -> void:
	match key:
		"flag":
			set_flag(StringName(value))
		"act":
			set_act(int(value))
		_:
			set(key, type_convert(value, typeof(get(key))))
			changed.emit()


func _on_slept() -> void:
	marks += 1
	add_count(StringName("sleeps_act_%d" % act))
	# Um dia inteiro sem alarme: o Zelador relaxa.
	if not _alarmed_today:
		add_vigilance(Tuning.VIGILANCE_CALM_SLEEP)
	changed.emit()
	trigger(&"slept")


func _on_harvested(kind: StringName) -> void:
	add_count(StringName("%s_harvested" % kind))
	trigger(&"harvested", kind)


func _matches(conditions: Dictionary, reason: StringName) -> bool:
	for key: String in conditions:
		var value: Variant = conditions[key]
		var ok := true
		match key:
			"act":
				ok = act == int(value)
			"act_at_least":
				ok = act >= int(value)
			"marks_at_least":
				ok = marks >= int(value)
			"flag":
				ok = has_flag(StringName(value))
			"not_flag":
				ok = not has_flag(StringName(value))
			"reason":
				ok = String(reason) == String(value)
			"counter_at_least":
				var needed: Dictionary = value
				for counter: String in needed:
					ok = ok and count(StringName(counter)) >= int(needed[counter])
			"any":
				var options: Array = value
				ok = options.any(func(option: Dictionary) -> bool: return _matches(option, reason))
			_:
				push_warning("Story: condição desconhecida '%s'." % key)
		if not ok:
			return false
	return true


func _run(actions: Array) -> void:
	for action: Dictionary in actions:
		for key: String in action:
			var value: Variant = action[key]
			match key:
				"set_flag":
					set_flag(StringName(value))
				"clear_flag":
					set_flag(StringName(value), false)
				"set_act":
					set_act(int(value))
				"add_note":
					add_note(String(value))
				"notify":
					Events.notification_shown.emit(String(value))
				"flash":
					Events.flash_requested.emit(int(value))
				"wake_real":
					Events.real_wake_requested.emit()
				"freeze":
					Events.fake_freeze_requested.emit()
				"recycle":
					Events.recycle_requested.emit(StringName(String(value)))
				"vigilance":
					add_vigilance(float(value))
				_:
					push_warning("Story: ação desconhecida '%s'." % key)
