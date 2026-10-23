class_name WolfPack
extends Node
## A matilha da noite. A partir do dia Tuning.WOLVES_FROM_DAY, Tuning.WOLF_WARNING_HOURS antes
## da chegada, Tuning.WOLF_COUNT lobos aparecem na borda do vale e um deles uiva (os outros às
## vezes respondem): o aviso sai de um lobo de verdade. Na hora da chegada eles entram no vale.
## Ao amanhecer vão embora; se o goblin dorme, a noite passa e eles somem junto.
##
## Matilhas distantes: algumas noites, lobos de verdade aparecem além da borda do vale (onde o
## goblin não chega), uivam de lá, às vezes com resposta, e somem. Às vezes uma delas responde
## ao aviso da matilha do vale.

var terrain: Terrain
var ambience: Ambience

## Lobos desta noite (sem tipo: os que somem viram objetos liberados até a próxima limpeza).
var _wolves := []
## Dia em que começou a última noite com aviso e com chegada (cada noite acontece uma vez).
var _warned_night := -1
var _arrived_night := -1
## De onde a matilha vem nesta noite.
var _origin := Vector2.ZERO
## Noite (dia em que começou) das rodadas distantes sorteadas e as horas delas (21..28).
var _distant_night := -999
var _distant_hours: Array[float] = []
## Uivos distantes marcados para daqui a pouco: [segundos, ângulo no mapa, tom].
var _distant_queue: Array = []


func _ready() -> void:
	# Dormir pula a noite: a matilha some e as rodadas que ficaram para trás não tocam.
	Clock.skipped.connect(func(_hours: float) -> void:
		_clear()
		_distant_hours.clear()
		_distant_queue.clear())


func _process(delta: float) -> void:
	if Game.player == null or Game.resting or terrain == null:
		return
	var hour := Clock.hour
	# A noite pertence ao dia em que começou (a madrugada é a noite de ontem).
	var night := Clock.day if hour >= 12.0 else Clock.day - 1
	_wolves = _wolves.filter(func(wolf: Variant) -> bool: return is_instance_valid(wolf))
	_tick_distant(delta, night, hour)
	if hour >= Tuning.WOLF_LEAVE_HOUR and hour < 12.0:
		for wolf: Wolf in _wolves:
			if not wolf.leaving:
				wolf.leave()
		return
	if night < Tuning.WOLVES_FROM_DAY:
		return
	var arrived := hour >= Tuning.WOLF_ARRIVE_HOUR or hour < Tuning.WOLF_LEAVE_HOUR
	if not arrived and hour >= Tuning.WOLF_ARRIVE_HOUR - Tuning.WOLF_WARNING_HOURS and _warned_night != night:
		_warned_night = night
		_origin = _pick_origin()
		_spawn(true)
		_warn()
	if arrived and _arrived_night != night:
		_arrived_night = night
		if _warned_night == night and not _wolves.is_empty():
			for wolf: Wolf in _wolves:
				wolf.waiting = false
		else:
			_origin = _pick_origin()
			_spawn(false)


## Ponto na borda do vale, longe do goblin.
func _pick_origin() -> Vector2:
	var player := Vector2(Game.player.global_position.x, Game.player.global_position.z)
	var best := Vector2.ZERO
	for attempt in 24:
		var angle := randf() * TAU
		var point := Vector2(cos(angle), sin(angle)) * (ForestLayout.VALLEY_RADIUS - 12.0)
		# Com o clima cortado (R3), o norte acaba antes da borda do vale.
		if Story.has_flag(&"climate_cut") and point.y < Tuning.VOID_EDGE_Z + 8.0:
			continue
		if point.distance_to(player) > best.distance_to(player):
			best = point
		if point.distance_to(player) >= Tuning.WOLF_SPAWN_MIN_DISTANCE:
			return point
	return best


## A matilha aparece junta em _origin; esperando (`waiting`), ronda a borda até a hora de chegar.
func _spawn(waiting: bool) -> void:
	for i in Tuning.WOLF_COUNT:
		var wolf := Wolf.new()
		wolf.waiting = waiting
		add_child(wolf)
		wolf.setup(terrain, _origin, randi())
		# O setup sorteia um ponto qualquer da área de caça: a matilha chega junta.
		var at := _origin + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		wolf.position = Vector3(at.x, terrain.get_height(at.x, at.y), at.y)
		_wolves.append(wolf)


## O aviso: um lobo uiva e os outros às vezes respondem; às vezes uma matilha distante também.
func _warn() -> void:
	if _wolves.is_empty():
		return
	_howl(_wolves[0], randf_range(0.95, 1.05), 60.0, -2.0)
	var delay := 0.0
	for wolf: Wolf in _wolves.slice(1):
		if randf() >= Tuning.HOWL_ANSWER:
			continue
		delay += randf_range(1.5, 5.0)
		get_tree().create_timer(delay, false).timeout.connect(_howl.bind(wolf, randf_range(0.9, 1.1), 60.0, -2.0))
	if randf() < Tuning.DISTANT_HOWL_REPLY:
		# Do outro lado do vale.
		_distant_queue.append([randf_range(6.0, 15.0), _origin.angle() + PI + randf_range(-0.8, 0.8), randf_range(0.9, 1.0)])


## O lobo para e uiva; o som sai da boca dele (pelos tocadores do Ambience: eco do vale,
## abafado atrás de rocha e, depois do R4, às vezes com a voz do Zelador).
func _howl(wolf: Variant, pitch: float, unit_size: float, volume_db: float) -> void:
	if ambience == null or not is_instance_valid(wolf) or (wolf as Wolf).state == Animal.State.DEAD:
		return
	var sound := ambience.howl_sound()
	(wolf as Wolf).howl(sound.get_length() / pitch)
	ambience.call_at(sound, (wolf as Wolf).mouth_position(), unit_size, volume_db, pitch)


## Matilhas distantes: cada noite sorteia de 0 a 3 rodadas (Tuning.DISTANT_HOWL_WEIGHTS) entre
## 21h e 4h. Uma rodada é um lobo de um lado do mapa; outros da mesma matilha respondem, às vezes.
func _tick_distant(delta: float, night: int, hour: float) -> void:
	var night_hour := hour if hour >= 12.0 else hour + 24.0
	if night != _distant_night:
		_distant_night = night
		_distant_hours.clear()
		var roll := randf()
		var bouts := 0
		for weight in Tuning.DISTANT_HOWL_WEIGHTS:
			roll -= weight
			if roll < 0.0:
				break
			bouts += 1
		for i in mini(bouts, Tuning.DISTANT_HOWL_WEIGHTS.size() - 1):
			_distant_hours.append(randf_range(Tuning.DISTANT_HOWL_HOURS.x, Tuning.DISTANT_HOWL_HOURS.y))
	for bout: float in _distant_hours.duplicate():
		# Só na hora da rodada (de dia, fora da faixa, nada toca).
		if night_hour >= bout and night_hour < bout + 0.5:
			_distant_hours.erase(bout)
			var angle := randf() * TAU
			_distant_queue.append([0.0, angle, randf_range(0.92, 1.05)])
			var delay := 0.0
			while randf() < Tuning.HOWL_ANSWER:
				delay += randf_range(2.0, 7.0)
				_distant_queue.append([delay, angle + randf_range(-0.25, 0.25), randf_range(0.88, 1.08)])
	for entry: Array in _distant_queue.duplicate():
		entry[0] -= delta
		if entry[0] <= 0.0:
			_distant_queue.erase(entry)
			_distant_howl(entry[1], entry[2])


## Um lobo distante aparece além da borda do vale, na direção `angle`, uiva e some depois.
func _distant_howl(angle: float, pitch: float) -> void:
	var at := _distant_point(angle)
	var wolf := Wolf.new()
	wolf.distant = true
	add_child(wolf)
	wolf.setup(terrain, at, randi())
	wolf.position = Vector3(at.x, terrain.get_height(at.x, at.y), at.y)
	# Olhando para o vale.
	wolf.rotation.y = atan2(-at.x, -at.y)
	_howl(wolf, pitch, 70.0, -4.0)
	get_tree().create_timer(Tuning.DISTANT_WOLF_SECONDS, false).timeout.connect(func() -> void:
		if is_instance_valid(wolf) and wolf.state != Animal.State.DEAD:
			wolf.queue_free())


## Ponto além da borda do vale (Tuning.DISTANT_HOWL_RING, do centro do mapa) perto de `angle`,
## longe do goblin; se ali estiver perto demais, gira para o outro lado.
func _distant_point(angle: float) -> Vector2:
	var player := Vector2(Game.player.global_position.x, Game.player.global_position.z)
	var best := Vector2.ZERO
	for attempt in 12:
		var a := angle + attempt * TAU / 12.0
		var point := Vector2(cos(a), sin(a)) * randf_range(Tuning.DISTANT_HOWL_RING.x, Tuning.DISTANT_HOWL_RING.y)
		if Story.has_flag(&"climate_cut") and point.y < Tuning.VOID_EDGE_Z + 8.0:
			continue
		if point.distance_to(player) > best.distance_to(player):
			best = point
		if point.distance_to(player) >= Tuning.DISTANT_HOWL_MIN_DISTANCE:
			return point
	return best


func _clear() -> void:
	for wolf: Variant in _wolves:
		if is_instance_valid(wolf) and (wolf as Wolf).state != Animal.State.DEAD:
			(wolf as Wolf).queue_free()
	_wolves.clear()


## Para testes: a matilha chega agora, perto de `origin`.
func spawn_now(origin: Vector2) -> Array:
	_origin = origin
	_arrived_night = Clock.day if Clock.hour >= 12.0 else Clock.day - 1
	_spawn(false)
	return _wolves.duplicate()
