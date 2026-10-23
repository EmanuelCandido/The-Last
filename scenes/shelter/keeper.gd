class_name Keeper
extends Node
## A cabeça do Zelador (§6.3): a ronda, os sentidos e o que ele faz com o que percebe. O corpo
## é o Caretaker do Shelter; este nó só decide para onde ele vai, para onde olha e a cor da
## lente. Liga só nas visitas (Shelter.begin_visit); nos flashes quem manda é o FlashDirector.
##
## Estados:
## - DOCKED: encaixado na recarga, esperando a próxima ronda (luz verde);
## - ROUND: de parada em parada (cápsula, sala de controle, recarga);
## - CHECK: luz âmbar, vai ver um ponto suspeito e olha em volta;
## - FOUND: luz vermelha, vem até Ari;
## - CAPTURE: a 1,2 m, ergue o braço com a seringa (Game.faint_in_shelter faz o resto);
## - DORMANT: bateria baixa depois do R3, encaixado e quase desligado: só ouve.
## Nunca machuca Ari. Anda pelo grafo de pontos do Abrigo (POINTS e LINKS); onde a linha está
## livre, vai reto.

signal captured

enum State { DOCKED, ROUND, CHECK, FOUND, CAPTURE, DORMANT }

## Pontos do caminho, no espaço do Abrigo (x, z).
const POINTS := {
	&"dock": Vector2(12.45, 0.0), &"dock_front": Vector2(9.5, 0.0), &"control_out": Vector2(4.0, 0.0),
	&"control_in": Vector2(5.0, 3.6), &"mid": Vector2(-0.5, 0.0), &"room_out": Vector2(-3.0, 0.0),
	&"room_in": Vector2(-3.0, 2.0), &"capsule": Vector2(-4.8, 2.75), &"store_out": Vector2(-9.0, 0.0),
	&"store_in": Vector2(-10.6, 0.0), &"store_corner": Vector2(-10.6, 1.55), &"store_back": Vector2(-12.6, 1.55),
}
const LINKS := [
	[&"dock", &"dock_front"], [&"dock_front", &"control_out"], [&"control_out", &"control_in"],
	[&"control_out", &"mid"], [&"mid", &"room_out"], [&"room_out", &"room_in"], [&"room_in", &"capsule"],
	[&"room_out", &"store_out"], [&"store_out", &"store_in"], [&"store_in", &"store_corner"],
	[&"store_corner", &"store_back"],
]
## Onde ele procura quando acha a cápsula vazia.
const SEARCH := [&"room_in", &"mid", &"store_in"]
const SIGHT_MASK := 1
const SENSE_INTERVAL := 0.1
const ARRIVE := 0.12

var shelter: Shelter
var state := State.DOCKED
var active := false
## 0..1: certeza de ter visto Ari. Em 1, FOUND.
var awareness := 0.0

var _path: Array[Vector3] = []
var _stops: Array[Dictionary] = []
var _search: Array[Vector3] = []
var _wait := 0.0
var _look_at := Vector3.INF
var _round_timer := 0.0
var _sense_timer := 0.0
var _replan := 0.0
var _last_seen := Vector3.ZERO
var _unseen := 0.0
var _alert := false
var _capsule_alarmed := false
var _sensor_alarmed := false
var _capture_timer := 0.0
var _yaw := 0.0
var _look_phase := 0.0


func _ready() -> void:
	Events.noise_made.connect(_on_noise)


## Começo de uma visita: encaixado na recarga; dormente se a bateria está baixa.
func begin() -> void:
	active = true
	awareness = 0.0
	_alert = false
	_capsule_alarmed = false
	_sensor_alarmed = false
	_path.clear()
	_stops.clear()
	_search.clear()
	_round_timer = Tuning.KEEPER_FIRST_ROUND
	var body := shelter.caretaker
	body.transform = shelter.dock
	_yaw = body.global_rotation.y
	body.head.position = Vector3(0.0, Caretaker.NECK_HEIGHT, 0.0)
	body.head.rotation = Vector3.ZERO
	body.pose_arm(0, 0.0, 0.35)
	body.pose_arm(1, 0.0, 0.35)
	_enter(State.DORMANT if low_battery() else State.DOCKED)


func end() -> void:
	active = false
	var body := shelter.caretaker
	body.moving = false
	body.transform = shelter.dock
	body.set_glow(1.0)
	body.set_light(&"green")
	shelter.set_control_door(false)


## Depois do R3 ele gastou a recarga consertando o clima: até Ari pegar o cartão, fica encaixado.
func low_battery() -> bool:
	return Story.has_flag(&"climate_cut") and not Story.has_flag(&"access_card")


## Vai ver `point` (âmbar). Na ronda, depois volta para onde ia.
func investigate(point: Vector3) -> void:
	if not active or state in [State.FOUND, State.CAPTURE, State.DORMANT]:
		return
	_search = [point]
	_enter(State.CHECK)
	_plan_to(point)


func _physics_process(delta: float) -> void:
	if not active or shelter.ari == null:
		return
	_round_timer -= delta
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = SENSE_INTERVAL
		_sense(SENSE_INTERVAL)
	match state:
		State.DOCKED:
			if _round_timer <= 0.0:
				_start_round()
		State.ROUND, State.CHECK:
			if _path.is_empty():
				_arrived(delta)
		State.FOUND:
			_replan -= delta
			if _replan <= 0.0:
				_replan = 0.4
				_plan_to(shelter.ari.global_position)
			if _flat_distance(shelter.caretaker.global_position, shelter.ari.global_position) < Tuning.KEEPER_CAPTURE_DISTANCE:
				_capture()
		State.CAPTURE:
			_capture_timer -= delta
			if _capture_timer <= 0.0 and active:
				active = false
				captured.emit()
			return
	_move(delta)
	# A porta da sala de controle abre sozinha para ele (o cartão no peito).
	var door := shelter.to_global(Vector3(4.0, 0.0, 1.0))
	shelter.set_control_door(_flat_distance(shelter.caretaker.global_position, door) < 1.6)


# --- Sentidos ---------------------------------------------------------------------------------

func _sense(dt: float) -> void:
	var ari := shelter.ari
	var body := shelter.caretaker
	var eye := body.head.global_position
	var target := ari.head.global_position
	var noise := ari.noise_level()
	if state == State.DORMANT:
		# Quase desligado: só o ouvido. Ouviu, acorda.
		if Senses.hears(eye, ari.global_position, noise):
			_enter(State.FOUND)
		return
	if state == State.CAPTURE:
		return
	var reach := Tuning.KEEPER_SIGHT_DARK if shelter.is_dark(target) else Tuning.KEEPER_SIGHT
	if ari.crawling:
		reach *= Tuning.KEEPER_SIGHT_CRAWLING
	var forward := body.head.global_basis.z
	var exclude: Array[RID] = [ari.get_rid()]
	var seen := Senses.sees(body.get_world_3d().direct_space_state, eye, forward, target, Tuning.KEEPER_FOV, reach, SIGHT_MASK, exclude)
	var distance := eye.distance_to(target)
	if seen:
		_last_seen = ari.global_position
		_unseen = 0.0
		var closeness := clampf(1.6 - distance / reach, 0.3, 1.6)
		awareness = minf(awareness + dt / Tuning.KEEPER_SIGHT_TIME * closeness * (1.5 if _alert else 1.0), 1.0)
		if awareness >= 1.0 and state != State.FOUND:
			_enter(State.FOUND)
	else:
		awareness = maxf(awareness - dt * 0.25, 0.0)
		if state == State.FOUND:
			_unseen += dt
			if _unseen >= Tuning.KEEPER_LOSE_SECONDS:
				awareness = 0.6
				_search = [_last_seen]
				_enter(State.CHECK)
				_plan_to(_last_seen)
			return
	if state == State.FOUND:
		return
	if Senses.hears(eye, ari.global_position, noise) or Senses.feels_heat(body.global_position + Vector3.UP, ari.global_position + Vector3.UP, Tuning.KEEPER_THERMAL):
		if state != State.CHECK or _search.is_empty() or _search[0].distance_to(ari.global_position) > 1.5:
			investigate(ari.global_position)
	# O sensor do corredor (antes do R2): passou embaixo, ele vem ver.
	var sensor := shelter.sensor.global_position
	if shelter.sensor_active() and Vector2(ari.global_position.x - sensor.x, ari.global_position.z - sensor.z).length() < Tuning.SENSOR_RADIUS:
		if not _sensor_alarmed:
			_sensor_alarmed = true
			Story.add_vigilance(Tuning.VIGILANCE_SENSOR)
			shelter.sensor_alarm()
			investigate(Vector3(sensor.x, ari.global_position.y, sensor.z))


func _on_noise(at: Vector3, radius: float) -> void:
	if not active or shelter.ari == null:
		return
	if state == State.DORMANT:
		if at.distance_to(shelter.caretaker.global_position) < radius:
			_enter(State.FOUND)
		return
	if at.distance_to(shelter.caretaker.global_position) < radius:
		investigate(at)


# --- Decisão ----------------------------------------------------------------------------------

func _enter(new_state: State) -> void:
	state = new_state
	_wait = -1.0
	var body := shelter.caretaker
	match new_state:
		State.DOCKED, State.ROUND:
			body.set_light(&"green")
			body.set_glow(1.0)
		State.CHECK:
			body.set_light(&"amber")
			body.set_glow(1.0)
		State.FOUND, State.CAPTURE:
			body.set_light(&"red")
			body.set_glow(1.3)
			_unseen = 0.0
			_replan = 0.0
			_last_seen = shelter.ari.global_position
		State.DORMANT:
			body.set_light(&"amber")
			body.set_glow(0.25)
	body.moving = false


func _start_round() -> void:
	var vigilant := Story.vigilance >= Tuning.KEEPER_ROUND_ALERT_VIGILANCE
	_round_timer = Tuning.KEEPER_ROUND_INTERVAL_ALERT if vigilant else Tuning.KEEPER_ROUND_INTERVAL
	_stops = [
		{"at": &"capsule", "wait": Tuning.KEEPER_CAPSULE_CHECK, "look": shelter.capsule.global_position, "capsule": true},
		{"at": &"control_in", "wait": Tuning.KEEPER_CONTROL_STAY, "look": shelter.to_global(Vector3(5.0, 1.0, 6.5))},
		{"at": &"dock", "wait": 0.0, "dock": true},
	]
	_enter(State.ROUND)
	_next_stop()


func _next_stop() -> void:
	if _stops.is_empty():
		_go_dock()
		return
	var stop: Dictionary = _stops[0]
	_wait = -1.0
	_plan_to(_point(stop.at))


func _go_dock() -> void:
	_stops = [{"at": &"dock", "wait": 0.0, "dock": true}]
	_enter(State.ROUND)
	_plan_to(_point(&"dock"))


## Chegou ao fim do caminho: espera na parada (olhando) e segue.
func _arrived(delta: float) -> void:
	var body := shelter.caretaker
	if state == State.CHECK:
		if _wait < 0.0:
			_wait = Tuning.KEEPER_LOOK_AROUND
			_look_phase = 0.0
		_wait -= delta
		_look_phase += delta
		# Olha em volta: a cabeça varre de um lado para o outro.
		body.head.rotation.y = sin(_look_phase * 1.8) * 1.2
		if _wait <= 0.0:
			body.head.rotation.y = 0.0
			_search.pop_front()
			if not _search.is_empty():
				_wait = -1.0
				_plan_to(_search[0])
			elif _stops.is_empty():
				_go_dock()
			else:
				_enter(State.ROUND)
				_next_stop()
		return
	if _stops.is_empty():
		_go_dock()
		return
	var stop: Dictionary = _stops[0]
	if _wait < 0.0:
		_wait = float(stop.wait)
		_look_at = stop.get("look", Vector3.INF)
		if stop.get("capsule", false) and not _capsule_alarmed:
			# A cápsula está vazia: o paciente saiu. Fica alerta e procura.
			_capsule_alarmed = true
			_alert = true
			Story.add_vigilance(Tuning.VIGILANCE_CAPSULE_EMPTY)
	if _look_at != Vector3.INF:
		_face(_look_at - body.global_position, delta)
	_wait -= delta
	if _wait > 0.0:
		return
	_stops.pop_front()
	if stop.get("dock", false):
		body.transform = shelter.dock
		_yaw = body.global_rotation.y
		_enter(State.DOCKED)
		return
	if stop.get("capsule", false) and _capsule_alarmed and _search.is_empty() and _alert:
		for point: StringName in SEARCH:
			_search.append(_point(point))
		_alert = true
		_enter(State.CHECK)
		_wait = -1.0
		_plan_to(_search[0])
		return
	_next_stop()


func _capture() -> void:
	_enter(State.CAPTURE)
	_path.clear()
	_capture_timer = 1.3
	var body := shelter.caretaker
	var ari := shelter.ari
	_face(ari.global_position - body.global_position, 1.0)
	body.global_rotation.y = _yaw
	body.pose_arm(1, 1.45, 0.25)
	body.servo()
	ari.controls = false
	ari.look(body.head.global_position - ari.camera.global_position)


# --- Andar ------------------------------------------------------------------------------------

func _move(delta: float) -> void:
	var body := shelter.caretaker
	if _path.is_empty():
		body.moving = false
		return
	var speed := Tuning.KEEPER_SPEED
	if state == State.FOUND:
		speed = Tuning.KEEPER_LOW_BATTERY_SPEED if low_battery() else Tuning.KEEPER_CHASE_SPEED
	var target := _path[0]
	var to_target := Vector3(target.x - body.global_position.x, 0.0, target.z - body.global_position.z)
	var step := speed * delta
	if to_target.length() <= maxf(step, ARRIVE):
		body.global_position = Vector3(target.x, body.global_position.y, target.z)
		_path.pop_front()
		if _path.is_empty():
			body.moving = false
		return
	body.moving = true
	body.global_position += to_target.normalized() * step
	_face(to_target, delta)
	body.head.rotation.y = lerpf(body.head.rotation.y, 0.0, 1.0 - exp(-4.0 * delta))


func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	_yaw = lerp_angle(_yaw, atan2(direction.x, direction.z), 1.0 - exp(-5.0 * delta))
	shelter.caretaker.global_rotation.y = _yaw


## Caminho até `target`: reto se a linha está livre; senão pelo grafo de pontos.
func _plan_to(target: Vector3) -> void:
	var from := shelter.caretaker.global_position
	_path.clear()
	if _clear(from, target):
		_path.append(target)
		return
	var start := _nearest_point(from)
	var goal := _nearest_point(target)
	for point: StringName in _route(start, goal):
		_path.append(_point(point))
	_path.append(target)


func _clear(from: Vector3, to: Vector3) -> bool:
	var space := shelter.caretaker.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if shelter.ari != null:
		exclude.append(shelter.ari.get_rid())
	for height in [0.4, 1.1]:
		var a: Vector3 = from + Vector3.UP * height
		var b: Vector3 = Vector3(to.x, from.y, to.z) + Vector3.UP * height
		if not Senses.line_of_sight(space, a, b, SIGHT_MASK, exclude):
			return false
	return true


## O ponto do grafo mais perto de `at` que ele enxerga (ou o mais perto, se nenhum).
func _nearest_point(at: Vector3) -> StringName:
	var best := &""
	var best_visible := &""
	var distance := INF
	var distance_visible := INF
	for point: StringName in POINTS:
		var d := _flat_distance(at, _point(point))
		if d < distance:
			distance = d
			best = point
		if d < distance_visible and _clear(at, _point(point)):
			distance_visible = d
			best_visible = point
	return best_visible if best_visible != &"" else best


## Busca em largura no grafo (são poucos pontos).
func _route(start: StringName, goal: StringName) -> Array[StringName]:
	var previous := {start: start}
	var queue: Array[StringName] = [start]
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		if current == goal:
			break
		for link: Array in LINKS:
			var next: StringName = &""
			if link[0] == current:
				next = link[1]
			elif link[1] == current:
				next = link[0]
			if next != &"" and not previous.has(next):
				previous[next] = current
				queue.append(next)
	var route: Array[StringName] = []
	if not previous.has(goal):
		return route
	var step := goal
	while step != start:
		route.push_front(step)
		step = previous[step]
	route.push_front(start)
	return route


func _point(point: StringName) -> Vector3:
	var at: Vector2 = POINTS[point]
	return shelter.to_global(Vector3(at.x, 0.0, at.y))


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
