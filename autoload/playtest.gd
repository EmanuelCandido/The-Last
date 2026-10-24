extends Node
## Diário de playtest (F10): grava o que acontece numa partida para ver depois onde quem jogou
## travou, morreu ou se perdeu. Só ouve sinais que já existem; nenhum sistema sabe dele.
##
## Liga sozinho em build de depuração (editor e export de depuração) e com --playtest em
## qualquer build. Fica desligado nos testes do DevTools (--frames, --screenshot, --run) e no
## export de lançamento, para não deixar arquivo na pasta que o jogador abre pelo menu.
##
## Cada sessão vira user://playtest/sessao_AAAA-MM-DD_HH-MM.log, uma linha por evento,
## separada por tab: tempo real (min:s), dia, hora do jogo, ato, ciclo, evento, detalhe. No
## fim, o resumo: tempo total e tempo em cada ato.

const FOLDER := "user://playtest"

var enabled := false

var _file: FileAccess
var _started_ms := 0
## Ato atual e desde quando (ms), para o tempo em cada ato.
var _act := 0
var _act_since_ms := 0
var _act_seconds := {}
var _position_timer := 0.0


func _ready() -> void:
	set_process(false)
	_connect()
	var forced := "--playtest" in OS.get_cmdline_user_args()
	if forced or (OS.is_debug_build() and not DevTools.automated):
		var stamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-").left(16)
		open(FOLDER.path_join("sessao_%s.log" % stamp))


## Começa a gravar em `path` (um arquivo novo; os testes abrem um próprio).
func open(path: String) -> bool:
	_finish()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_file = FileAccess.open(path, FileAccess.WRITE)
	enabled = _file != null
	set_process(enabled)
	if not enabled:
		return false
	_act_seconds.clear()
	_position_timer = 0.0
	_started_ms = Time.get_ticks_msec()
	_act = Story.act
	_act_since_ms = _started_ms
	_file.store_line("# A Toca, playtest de %s" % Time.get_datetime_string_from_system(false, true))
	_file.store_line("# tempo\tdia\thora\tato\tciclo\tevento\tdetalhe")
	log_event(&"sessao", "começou")
	return true


## Para de gravar e escreve o resumo.
func close() -> void:
	_finish()


func _process(delta: float) -> void:
	_position_timer += delta
	if _position_timer < Tuning.PLAYTEST_POSITION_SECONDS:
		return
	_position_timer = 0.0
	var player := Game.player
	if player == null or Game.awake or Game.menu_open:
		return
	var at := player.global_position
	var level := Game.current_level
	var inside := level != null and level.has_method("indoor_at") and float(level.indoor_at(at)) > 0.5
	log_event(&"posicao", "%.0f, %.0f%s" % [at.x, at.z, " (toca)" if inside else ""])


func _exit_tree() -> void:
	_finish()


## Grava uma linha. Outros sistemas também podem chamar (ex.: um evento sem sinal).
func log_event(event: StringName, detail := "") -> void:
	if _file == null:
		return
	var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
	_file.store_line("%d:%02d\t%d\t%05.2f\t%d\t%d\t%s\t%s" % [
		int(seconds) / 60, int(seconds) % 60, Clock.day, Clock.hour, Story.act, Story.cycle, event, detail])
	_file.flush()


func _connect() -> void:
	Events.level_loaded.connect(func(level: Node3D) -> void: log_event(&"fase", level.name))
	Events.game_started.connect(func() -> void: log_event(&"partida", "começou"))
	Events.game_paused.connect(func(paused: bool) -> void: log_event(&"pausa", "abriu" if paused else "fechou"))
	Events.player_died.connect(func(cause: StringName) -> void: log_event(&"morreu", cause))
	Events.slept.connect(func() -> void: log_event(&"dormiu", "riscos %d" % Story.marks))
	Events.woke_up.connect(func(reason: StringName) -> void: log_event(&"acordou", reason))
	Events.recycle_requested.connect(func(reason: StringName) -> void: log_event(&"reciclagem", reason))
	Events.shelter_entered.connect(func() -> void: log_event(&"abrigo", "entrou"))
	Events.shelter_left.connect(func() -> void: log_event(&"abrigo", "saiu"))
	Events.ending_requested.connect(func(ending: StringName) -> void: log_event(&"final", ending))
	Events.crafted.connect(func(recipe: StringName) -> void: log_event(&"fabricou", recipe))
	Events.animal_harvested.connect(func(kind: StringName) -> void: log_event(&"coletou", kind))
	Events.ate.connect(func(food: StringName) -> void: log_event(&"comeu", food))
	Events.ritual_completed.connect(func(place: StringName) -> void: log_event(&"ritual", place))
	Events.notification_shown.connect(func(text: String) -> void: log_event(&"aviso", text))
	Story.flag_changed.connect(func(flag: StringName, value: bool) -> void:
		log_event(&"flag", "%s %s" % [flag, "ligou" if value else "desligou"]))
	Story.note_added.connect(func(text: String) -> void: log_event(&"anotacao", text))
	Story.act_changed.connect(_on_act_changed)


func _on_act_changed(act: int) -> void:
	if act == _act:
		return
	_close_act()
	_act = act
	log_event(&"ato", str(act))


## Soma o tempo passado no ato atual.
func _close_act() -> void:
	var now := Time.get_ticks_msec()
	_act_seconds[_act] = float(_act_seconds.get(_act, 0.0)) + (now - _act_since_ms) / 1000.0
	_act_since_ms = now


func _finish() -> void:
	if _file == null:
		return
	_close_act()
	log_event(&"sessao", "terminou")
	var total := (Time.get_ticks_msec() - _started_ms) / 1000.0
	_file.store_line("# resumo: %d min no total" % roundi(total / 60.0))
	var acts: Array = _act_seconds.keys()
	acts.sort()
	for act: int in acts:
		_file.store_line("#   ato %d: %d min" % [act, roundi(float(_act_seconds[act]) / 60.0)])
	_file.close()
	_file = null
	enabled = false
	set_process(false)
