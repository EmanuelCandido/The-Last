class_name Herd
extends Node
## Uma manada de cervos com um dia de verdade (§8b-B). Cada manada tem a sua casa (onde dorme) e
## um centro que anda pelo vale; cada cervo pasta em volta do centro (Animal.home = centro,
## home_radius = Tuning.HERD_SPREAD) e anda até ele quando fica longe.
##
## A agenda, pelo Clock:
## - ROAM (de HERD_DAY_START a HERD_HOME_HOUR): o centro vai de um ponto de pasto a outro pelo
##   vale, a HERD_ROAM_SPEED, trocando de ponto a cada HERD_WAYPOINT_HOURS;
## - HOMEWARD (de HERD_HOME_HOUR a HERD_SLEEP_HOUR, ou se a noite pegou a manada longe): volta para
##   a casa;
## - SLEEP (de noite, em casa): os cervos deitam e dormem (Animal.sleep), juntinhos;
## - SHELTER (chovendo, de dia ou indo para casa): vai para a copa mais fechada por perto
##   (forest.shelter_near) e fica parada até passar.
## Depois de uma fuga, o centro passa a ser onde os cervos pararam (não volta para onde estava o
## perigo). A cada amanhecer a manada volta ao tamanho dela, nascendo na casa, se o goblin está longe.
## Filho de Animals; os cervos são filhos de Animals também (a manada só os comanda).

enum Mode { ROAM, HOMEWARD, SLEEP, SHELTER }

var terrain: Terrain
var level: Node3D
## A casa (onde dorme) e quantos cervos a manada tem quando está completa.
var home := Vector2.ZERO
var size := 3
var mode := Mode.ROAM
var center := Vector2.ZERO
var members: Array[Deer] = []

var _waypoint := Vector2.ZERO
var _waypoint_left := 0.0
var _shelter := Vector2.INF
var _scattered := false
var _last_hour := -1.0
var _rng := RandomNumberGenerator.new()
var _check := 0.0


func setup(world_terrain: Terrain, world_level: Node3D, home_position: Vector2, herd_size: int, rng_seed: int) -> void:
	terrain = world_terrain
	level = world_level
	home = home_position
	size = herd_size
	_rng.seed = rng_seed
	center = _start_center()
	_waypoint = center
	for i in size:
		_spawn_member(center)
	Clock.skipped.connect(_on_skipped)
	Clock.day_started.connect(_on_day_started)


func _physics_process(delta: float) -> void:
	_prune()
	if members.is_empty():
		return
	var hours := _hours_passed()
	_update_mode()
	_move_center(delta, hours)
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_command_members()


## Onde a manada deveria estar agora (sem passar o tempo): a casa de noite, um pasto de dia.
func _start_center() -> Vector2:
	if _is_night() or Clock.hour >= Tuning.HERD_HOME_HOUR:
		return home
	return _pick_waypoint(home)


func _is_night() -> bool:
	return Clock.hour >= Tuning.HERD_SLEEP_HOUR or Clock.hour < Tuning.HERD_DAY_START


func _hours_passed() -> float:
	if _last_hour < 0.0:
		_last_hour = Clock.hour
		return 0.0
	var hours := Clock.hour - _last_hour
	if hours < 0.0:
		hours += 24.0
	_last_hour = Clock.hour
	return hours if hours < 1.0 else 0.0


func _update_mode() -> void:
	var at_home := center.distance_to(home) < 3.0
	var raining := Weather.rain > 0.3
	var previous := mode
	if _is_night():
		mode = Mode.SLEEP if at_home else Mode.HOMEWARD
	elif raining:
		mode = Mode.SHELTER
	elif Clock.hour >= Tuning.HERD_HOME_HOUR:
		mode = Mode.HOMEWARD
	else:
		mode = Mode.ROAM
	if mode == Mode.SHELTER and previous != Mode.SHELTER:
		var spot: Vector3 = level.shelter_near(Vector3(center.x, 0.0, center.y), 30.0) if level.has_method("shelter_near") else Vector3(center.x, 0.0, center.y)
		_shelter = Vector2(spot.x, spot.z)
	if previous == Mode.SLEEP and mode != Mode.SLEEP:
		for deer in members:
			deer.wake()


func _move_center(delta: float, hours: float) -> void:
	var target := center
	var speed := Tuning.HERD_ROAM_SPEED
	match mode:
		Mode.ROAM:
			_waypoint_left -= hours
			if _waypoint_left <= 0.0 or center.distance_to(_waypoint) < 2.0:
				_waypoint = _pick_waypoint(center)
				_waypoint_left = _rng.randf_range(Tuning.HERD_WAYPOINT_HOURS.x, Tuning.HERD_WAYPOINT_HOURS.y)
			target = _waypoint
		Mode.HOMEWARD, Mode.SLEEP:
			target = home
			speed *= 1.8
		Mode.SHELTER:
			target = _shelter
			speed *= 2.5
	# Enquanto algum foge, o centro espera; quando todos param, ele vai para onde eles estão.
	var fleeing := members.any(func(deer: Deer) -> bool: return deer.state == Animal.State.FLEE)
	if fleeing:
		_scattered = true
		return
	if _scattered:
		_scattered = false
		center = _members_middle()
		_waypoint = _pick_waypoint(center)
		return
	center = center.move_toward(target, speed * delta)


## Diz a cada cervo onde a manada está e o que fazer.
func _command_members() -> void:
	var spread := Tuning.HERD_SPREAD
	if mode == Mode.SLEEP:
		spread = 2.5
	elif mode == Mode.SHELTER:
		spread = 3.0
	for deer in members:
		deer.home = center
		deer.home_radius = spread
		if deer.state in [Animal.State.FLEE, Animal.State.SUSPICIOUS, Animal.State.DEAD]:
			continue
		var here := Vector2(deer.position.x, deer.position.z)
		var far := here.distance_to(center)
		if mode == Mode.SLEEP:
			if far < spread + 1.5 and deer.state != Animal.State.SLEEP:
				deer.sleep()
			elif far >= spread + 1.5:
				deer.regroup()
		elif far > _rejoin_distance(spread):
			deer.regroup()
		elif mode == Mode.SHELTER and far < spread + 1.0 and deer.state == Animal.State.GRAZE:
			# Debaixo da árvore, parado esperando a chuva passar.
			deer.stand()


## A partir de que distância do centro o cervo volta para a manada. Na chuva é curta: todos
## debaixo da copa (com a de sempre, até 9 m, metade pastava fora dela, molhando).
func _rejoin_distance(spread: float) -> float:
	if mode == Mode.SHELTER:
		return spread + Tuning.HERD_SHELTER_REJOIN
	return maxf(spread * 1.5, minf(Tuning.HERD_REJOIN_DISTANCE, spread * 3.0))


## Tira da manada quem foi coletado (o nó sumiu) ou morreu.
func _prune() -> void:
	var alive: Array[Deer] = []
	for i in members.size():
		var item: Variant = members[i]
		if is_instance_valid(item) and (item as Deer).state != Animal.State.DEAD:
			alive.append(item as Deer)
	members = alive


func _members_middle() -> Vector2:
	var sum := Vector2.ZERO
	for deer in members:
		sum += Vector2(deer.position.x, deer.position.z)
	return sum / members.size()


## Um ponto de pasto no vale: andável, longe da caverna e um pouco longe de onde está.
func _pick_waypoint(from: Vector2) -> Vector2:
	for attempt in 20:
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf()) * (ForestLayout.VALLEY_RADIUS - 20.0)
		var p := Vector2(cos(angle), sin(angle)) * radius
		if p.distance_to(from) < 20.0 or p.distance_to(ForestLayout.CAVE_CENTER) < 25.0:
			continue
		if p.y < Tuning.VOID_EDGE_Z + 12.0:
			continue
		if terrain.get_normal(p.x, p.y).y > 0.85:
			return p
	return home


func _spawn_member(around: Vector2) -> Deer:
	var deer := Deer.new()
	deer.herd_node = self
	get_parent().add_child(deer)
	deer.home_radius = Tuning.HERD_SPREAD
	deer.setup(terrain, around, _rng.randi())
	members.append(deer)
	if _is_night() and around.distance_to(home) < 3.0:
		deer.sleep()
	return deer


## O goblin dormiu: a manada passou a noite em casa e acorda lá.
func _on_skipped(_hours: float) -> void:
	_last_hour = Clock.hour
	center = home
	mode = Mode.SLEEP if _is_night() else Mode.ROAM
	_prune()
	for deer in members:
		deer.place_near(home, 2.5)
		if mode == Mode.SLEEP:
			deer.sleep()
		else:
			deer.wake()
	_waypoint = _pick_waypoint(home)
	_waypoint_left = 0.0


## Amanheceu: a manada volta ao tamanho dela, se o goblin está longe da casa.
func _on_day_started(_day: int) -> void:
	var player := Game.player
	if player != null and Vector2(player.global_position.x, player.global_position.z).distance_to(home) < Tuning.RESTOCK_MIN_DISTANCE:
		return
	_prune()
	while members.size() < size:
		_spawn_member(home)
