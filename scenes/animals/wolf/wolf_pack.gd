class_name WolfPack
extends Node
## A matilha da noite. A partir do dia Tuning.WOLVES_FROM_DAY, um uivo avisa pela borda
## do vale e, Tuning.WOLF_WARNING_HOURS depois, Tuning.WOLF_COUNT lobos chegam de lá. Ao
## amanhecer vão embora; se o goblin dorme, a noite passa e eles somem junto.

var terrain: Terrain
var ambience: Ambience

## Lobos desta noite (sem tipo: os que somem viram objetos liberados até a próxima limpeza).
var _wolves := []
## Dia em que começou a última noite com aviso e com chegada (cada noite acontece uma vez).
var _warned_night := -1
var _arrived_night := -1
## De onde a matilha vem nesta noite.
var _origin := Vector2.ZERO


func _ready() -> void:
	Clock.skipped.connect(func(_hours: float) -> void: _clear())


func _process(_delta: float) -> void:
	if Game.player == null or Game.resting or terrain == null:
		return
	var hour := Clock.hour
	# A noite pertence ao dia em que começou (a madrugada é a noite de ontem).
	var night := Clock.day if hour >= 12.0 else Clock.day - 1
	_wolves = _wolves.filter(func(wolf: Variant) -> bool: return is_instance_valid(wolf))
	if hour >= Tuning.WOLF_LEAVE_HOUR and hour < 12.0:
		for wolf: Wolf in _wolves:
			if not wolf.leaving:
				wolf.leave()
		return
	if night < Tuning.WOLVES_FROM_DAY:
		return
	var arrived := hour >= Tuning.WOLF_ARRIVE_HOUR or hour < Tuning.WOLF_LEAVE_HOUR
	if hour >= Tuning.WOLF_ARRIVE_HOUR - Tuning.WOLF_WARNING_HOURS and _warned_night != night:
		_warned_night = night
		_origin = _pick_origin()
		if ambience != null:
			ambience.howl_from(Vector3(_origin.x, terrain.get_height(_origin.x, _origin.y) + 12.0, _origin.y))
	if arrived and _arrived_night != night:
		_arrived_night = night
		if _warned_night != night:
			_origin = _pick_origin()
		_spawn()


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


func _spawn() -> void:
	for i in Tuning.WOLF_COUNT:
		var wolf := Wolf.new()
		add_child(wolf)
		wolf.setup(terrain, _origin, randi())
		# O setup sorteia um ponto qualquer da área de caça: a matilha chega junta.
		var at := _origin + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		wolf.position = Vector3(at.x, terrain.get_height(at.x, at.y), at.y)
		_wolves.append(wolf)


func _clear() -> void:
	for wolf: Variant in _wolves:
		if is_instance_valid(wolf) and (wolf as Wolf).state != Animal.State.DEAD:
			(wolf as Wolf).queue_free()
	_wolves.clear()


## Para testes: a matilha chega agora, perto de `origin`.
func spawn_now(origin: Vector2) -> Array:
	_origin = origin
	_arrived_night = Clock.day if Clock.hour >= 12.0 else Clock.day - 1
	_spawn()
	return _wolves.duplicate()
