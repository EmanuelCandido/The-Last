extends Node
## Relógio do jogo: dia e hora (Tuning.SECONDS_PER_HOUR segundos reais por hora).
##
## Corre enquanto há um jogador e ele não está dormindo ou desmaiado (Game.resting).
## Dormir pula o tempo de uma vez (sleep_until_morning) e avisa quanto pulou, para quem
## gasta com o tempo (a fogueira queima a lenha) acompanhar.

signal hour_changed(hour: float)
signal day_started(day: int)
## O tempo pulou `hours` horas de uma vez (dormindo).
signal skipped(hours: float)

var day := 1
var hour := Tuning.START_HOUR
## Horas desde que acordou: muito tempo acordado dá sono mesmo de dia.
var hours_awake := 0.0


func _process(delta: float) -> void:
	if Game.player == null or Game.resting:
		return
	advance(delta / Tuning.SECONDS_PER_HOUR)


func advance(hours: float) -> void:
	var before := int(hour)
	hour += hours
	hours_awake += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		day_started.emit(day)
	if int(hour) != before:
		hour_changed.emit(hour)


func can_sleep() -> bool:
	return hour >= Tuning.SLEEP_FROM_HOUR or hour < Tuning.SLEEP_UNTIL_HOUR or hours_awake >= Tuning.SLEEPY_AFTER_HOURS


## Pula para a manhã seguinte (ou para a manhã de hoje, se já passou da meia-noite).
func sleep_until_morning() -> void:
	var hours := Tuning.WAKE_HOUR - hour
	if hours <= 0.0:
		hours += 24.0
	advance(hours)
	hours_awake = 0.0
	skipped.emit(hours)


## Nome da parte do dia, para o menu de pausa.
func period_name() -> String:
	if hour < 5.0:
		return "madrugada"
	if hour < 7.0:
		return "amanhecer"
	if hour < 12.0:
		return "manhã"
	if hour < 17.0:
		return "tarde"
	if hour < 20.0:
		return "fim da tarde"
	return "noite"


func save_data() -> Dictionary:
	return {"day": day, "hour": hour, "hours_awake": hours_awake}


func load_data(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	hour = float(data.get("hour", Tuning.START_HOUR))
	hours_awake = float(data.get("hours_awake", 0.0))
	hour_changed.emit(hour)


## Usado pelo DevTools (--set=clock.hour:19).
func debug_set(key: String, value: String) -> void:
	set(key, type_convert(value, typeof(get(key))))
	hour_changed.emit(hour)
