extends Node
## O tempo (§8b, F9): por enquanto, a chuva. A cada hora de jogo há uma chance de começar a
## chover (Tuning.RAIN_CHANCE_PER_HOUR); a chuva dura de RAIN_HOURS_MIN a RAIN_HOURS_MAX horas e
## entra e sai devagar (`rain`, 0..1). Para com o relógio (dormindo ou acordado no Abrigo); o
## sono pula as horas de uma vez (Clock.skipped). Salvo junto com a partida.
##
## Quem reage: a floresta (riscos de chuva, céu, neblina e o som), os bichos (ouvem e cheiram
## menos, a manada se abriga), o frio do goblin (molhado, fora do abrigo).

signal changed(raining: bool)

## Quanto está chovendo agora (0..1, suave).
var rain := 0.0
## Horas de chuva que faltam (0 = tempo firme).
var rain_left := 0.0

var _last_hour := -1.0


func _ready() -> void:
	Clock.skipped.connect(_on_skipped)


func _process(delta: float) -> void:
	var target := 1.0 if rain_left > 0.0 else 0.0
	rain = move_toward(rain, target, delta / Tuning.RAIN_FADE_SECONDS)
	if Game.resting or Game.awake or Game.menu_open:
		_last_hour = Clock.hour
		return
	if _last_hour < 0.0:
		_last_hour = Clock.hour
		return
	var hours := Clock.hour - _last_hour
	if hours < 0.0:
		hours += 24.0
	_last_hour = Clock.hour
	if hours > 0.0 and hours < 1.0:
		_pass(hours)


func is_raining() -> bool:
	return rain_left > 0.0


## Começa a chover por `hours` horas (0 = sorteia a duração).
func start_rain(hours := 0.0) -> void:
	var was := is_raining()
	rain_left = hours if hours > 0.0 else randf_range(Tuning.RAIN_HOURS_MIN, Tuning.RAIN_HOURS_MAX)
	if not was:
		changed.emit(true)


func stop_rain() -> void:
	var was := is_raining()
	rain_left = 0.0
	if was:
		changed.emit(false)


## Passaram `hours` horas de jogo: gasta a chuva ou sorteia uma nova.
func _pass(hours: float) -> void:
	if is_raining():
		rain_left -= hours
		if rain_left <= 0.0:
			stop_rain()
	elif randf() < 1.0 - pow(1.0 - Tuning.RAIN_CHANCE_PER_HOUR, hours):
		start_rain()


func _on_skipped(hours: float) -> void:
	# A noite dormida: a chuva de agora acaba ou não, e a manhã pode amanhecer chovendo.
	_pass(minf(hours, rain_left + 0.01) if is_raining() else 0.0)
	if not is_raining() and randf() < Tuning.RAIN_CHANCE_PER_HOUR * 2.0:
		start_rain()
	rain = 1.0 if is_raining() else 0.0
	_last_hour = Clock.hour


func save_data() -> Dictionary:
	return {"rain_left": rain_left}


func load_data(data: Dictionary) -> void:
	rain_left = float(data.get("rain_left", 0.0))
	rain = 1.0 if rain_left > 0.0 else 0.0
	_last_hour = -1.0
	changed.emit(is_raining())


func debug_set(key: String, value: String) -> void:
	match key:
		"rain":
			if float(value) > 0.0:
				start_rain(float(value) if float(value) > 1.0 else 0.0)
				rain = 1.0
			else:
				stop_rain()
				rain = 0.0
		_:
			push_error("[Weather] chave desconhecida: %s" % key)
