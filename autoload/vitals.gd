extends Node
## O corpo de Ari: saciedade, vida, frio e enjoo. É o mesmo corpo na floresta e no mundo real.
##
## Só números e regras (valores em Tuning). O que se vê e ouve (ronco da barriga, borda
## escura, mão na barriga, tremor) fica em quem lê daqui: BodyFeedback, ColdExposure, HUD,
## GoblinAnimator. Quanto o frio sobe ou desce depende do lugar: quem mede é o ColdExposure.
## Corre junto com o relógio: parado enquanto o goblin dorme ou desmaia.

signal changed

var satiety := Tuning.START_SATIETY
var health := 100.0
## Frio (0..100): no máximo, machuca.
var cold := 0.0
## Segundos de enjoo restantes (sem regenerar).
var nausea := 0.0
## Lama na pele (0..1): camufla. Quem passa e tira é o MudCamouflage.
var mud := 0.0

var _dead := false


func _process(delta: float) -> void:
	if Game.player == null or Game.resting or Game.awake or _dead:
		return
	satiety = maxf(satiety - Tuning.SATIETY_DECAY * delta, 0.0)
	nausea = maxf(nausea - delta, 0.0)
	if cold >= 100.0:
		damage(Tuning.COLD_DAMAGE * delta, &"cold")
	if satiety <= 0.0:
		damage(Tuning.STARVE_DAMAGE * delta, &"hunger")
	elif satiety > Tuning.REGEN_MIN_SATIETY and nausea <= 0.0:
		health = minf(health + Tuning.REGEN * delta, 100.0)


func is_hungry() -> bool:
	return satiety < Tuning.HUNGRY_BELOW


func is_starving() -> bool:
	return satiety < Tuning.STARVING_BELOW


func is_cold() -> bool:
	return cold >= Tuning.COLD_SHIVER


func add_cold(amount: float) -> void:
	cold = clampf(cold + amount, 0.0, 100.0)


func damage(amount: float, cause: StringName) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	changed.emit()
	if health <= 0.0:
		_dead = true
		Events.player_died.emit(cause)


## Come `food` (chave de Tuning.FOODS). Devolve true se a comida fez mal (enjoo).
func eat(food: StringName) -> bool:
	var spec: Dictionary = Tuning.FOODS.get(food, {})
	satiety = minf(satiety + float(spec.get("satiety", 0.0)), 100.0)
	var sick := randf() < float(spec.get("nausea_chance", 0.0))
	if sick:
		nausea = Tuning.NAUSEA_SECONDS
		damage(Tuning.NAUSEA_DAMAGE, &"nausea")
	changed.emit()
	Events.ate.emit(food)
	return sick


## Uma noite de sono: gasta saciedade e, bem alimentado, cura.
func rest() -> void:
	satiety = maxf(satiety - Tuning.SLEEP_SATIETY_COST, 0.0)
	if satiety > Tuning.SLEEP_HEAL_MIN_SATIETY:
		health = minf(health + Tuning.SLEEP_HEAL, 100.0)
	# Dormiu enrolado na pele, dentro da toca.
	cold = 0.0
	changed.emit()


## Corpo novo em folha (a Reciclagem: acorda no dia 1).
func reset() -> void:
	_dead = false
	satiety = Tuning.START_SATIETY
	health = 100.0
	nausea = 0.0
	cold = 0.0
	mud = 0.0
	changed.emit()


## Volta depois de morrer.
func revive() -> void:
	_dead = false
	health = Tuning.DEATH_HEALTH
	satiety = maxf(satiety, Tuning.DEATH_SATIETY)
	nausea = 0.0
	cold = 0.0
	changed.emit()


## Palavras do estado do corpo para o menu de pausa ("Com fome", "Ferido").
func status_words() -> PackedStringArray:
	var words := PackedStringArray()
	if satiety <= 0.0:
		words.append("Faminto")
	elif is_hungry():
		words.append("Com fome")
	if health < Tuning.LOW_HEALTH:
		words.append("Muito ferido")
	elif health < 75.0:
		words.append("Ferido")
	if cold >= 100.0:
		words.append("Congelando")
	elif is_cold():
		words.append("Com frio")
	if nausea > 0.0:
		words.append("Enjoado")
	if mud > 0.3:
		words.append("Coberto de lama")
	return words


func save_data() -> Dictionary:
	return {"satiety": satiety, "health": health, "nausea": nausea, "cold": cold, "mud": mud}


func load_data(data: Dictionary) -> void:
	satiety = float(data.get("satiety", Tuning.START_SATIETY))
	health = float(data.get("health", 100.0))
	nausea = float(data.get("nausea", 0.0))
	cold = float(data.get("cold", 0.0))
	mud = float(data.get("mud", 0.0))
	_dead = health <= 0.0
	changed.emit()


## Usado pelo DevTools (--set=vitals.satiety:10,vitals.health:30).
func debug_set(key: String, value: String) -> void:
	set(key, type_convert(value, typeof(get(key))))
	changed.emit()
