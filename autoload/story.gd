extends Node
## Estado da história: ato, ciclo, riscos na parede, flags, contadores e anotações.
##
## O que acontece e quando vem de StoryBeats (data/story_beats.gd): aqui só se guarda
## o estado e se avaliam os beats quando um gatilho acontece. Os sistemas reagem ao
## estado (flag_changed, act_changed) sem saber qual beat o mudou.

signal changed
signal flag_changed(flag: StringName, value: bool)
signal act_changed(act: int)
signal note_added(text: String)

const START_CYCLE := 347

var act := 1
var cycle := START_CYCLE
## Riscos deste ciclo (um por noite dormida na pele).
var marks := 0
## Riscos de ciclos passados, debaixo do musgo.
var old_marks := Tuning.OLD_MARKS
## Anotações que o próprio Ari deixou (Dicas que mudam). Sobrevivem à Reciclagem.
var notes: PackedStringArray = []

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


func add_note(text: String) -> void:
	if text in notes:
		return
	notes.append(text)
	note_added.emit(text)
	changed.emit()


## Avalia os beats do gatilho `on`. `reason` é o detalhe do gatilho (motivo de acordar,
## causa da morte, comida, bicho).
func trigger(on: StringName, reason: StringName = &"") -> void:
	for beat: Dictionary in StoryBeats.BEATS:
		var id: String = beat.id
		if beat.on != String(on) or _fired.has(id):
			continue
		if not _matches(beat.get("when", {}), reason):
			continue
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
	act_changed.emit(act)
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
				_:
					push_warning("Story: ação desconhecida '%s'." % key)
