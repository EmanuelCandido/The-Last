class_name Bird
extends Node3D
## Um pássaro do vale (BirdLife): pousado num galho de verdade, canta dali; espantado, voa para
## outra árvore e fica calado um tempo. De vez em quando troca de árvore sozinho.
## - canoro: na copa das árvores vivas, de dia (o coro do amanhecer é o mais cheio), cada um
##   com o seu canto e o seu tom;
## - pica-pau: agarrado ao tronco de uma árvore seca, tamborila de dia;
## - coruja: perto do tronco, na mata fechada, pia de noite.
## Só canta e se mexe perto do ouvido (Tuning.BIRD_ACTIVE_RANGE).

enum Species { SONGBIRD, WOODPECKER, OWL }
enum Mode { PERCHED, FLYING }

const SONGS: Array[AudioStream] = [
	preload("res://assets/audio/animals/bird_1.wav"),
	preload("res://assets/audio/animals/bird_2.wav"),
	preload("res://assets/audio/animals/bird_3.wav"),
	preload("res://assets/audio/animals/bird_4.wav"),
]
const WOODPECKER := preload("res://assets/audio/animals/woodpecker.wav")
const OWLS: Array[AudioStream] = [preload("res://assets/audio/animals/owl_1.wav"), preload("res://assets/audio/animals/owl_2.wav")]
const ALARM := preload("res://assets/audio/animals/bird_alarm.wav")
const FLAP := preload("res://assets/audio/animals/wing_flap.wav")
## Velocidade do voo (m/s) por espécie.
const FLIGHT_SPEED: Array[float] = [9.0, 8.0, 6.5]

var species := Species.SONGBIRD
var mode := Mode.PERCHED
var life: BirdLife
## Árvore onde está pousado (índice em Vegetation.trees; -1 = nenhuma).
var tree := -1

var _song: AudioStream
var _pitch := 1.0
var _call_timer := 0.0
var _shy := 0.0
var _wander := 0.0
var _look_timer := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _to_yaw := 0.0
var _to_tree := -1
var _flight := 0.0
var _flight_time := 1.0
var _wings: Array[Node3D] = []
var _head: Node3D


func setup(kind: Species, rng: RandomNumberGenerator) -> void:
	species = kind
	_song = SONGS[rng.randi() % SONGS.size()]
	_pitch = rng.randf_range(0.88, 1.15) if kind == Species.SONGBIRD else rng.randf_range(0.94, 1.06)
	_call_timer = rng.randf_range(0.5, 12.0)
	_wander = rng.randf_range(Tuning.BIRD_WANDER_SECONDS.x, Tuning.BIRD_WANDER_SECONDS.y)
	_build_body()


## Põe o pássaro pousado em `at`, olhando para `yaw`, na árvore `tree_id`.
func perch_at(at: Vector3, yaw: float, tree_id: int) -> void:
	mode = Mode.PERCHED
	position = at
	rotation = Vector3(0.0, yaw, 0.0)
	tree = tree_id
	# Pousado, as asas ficam fechadas no corpo (o corpo de caixa já as cobre).
	for wing in _wings:
		wing.visible = false


## Espanta: pio de alarme (canoro), bater de asas e voo para outra árvore longe de `from`.
func flush(from: Vector3) -> void:
	if mode != Mode.PERCHED:
		return
	life.call_at(FLAP, global_position, 4.0, -5.0, randf_range(0.9, 1.2))
	if species == Species.SONGBIRD:
		life.call_at(ALARM, global_position, 8.0, -4.0, _pitch)
	_shy = randf_range(Tuning.BIRD_SHY_SECONDS.x, Tuning.BIRD_SHY_SECONDS.y)
	_fly_away(from, 20.0, 45.0)


func _process(delta: float) -> void:
	if life == null or Game.player == null or Game.resting:
		return
	# O voo sempre termina (longe do ouvido ele não ficaria parado no ar).
	if mode == Mode.FLYING:
		_fly(delta)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.global_position.distance_to(global_position) > Tuning.BIRD_ACTIVE_RANGE:
		return
	_shy -= delta
	_wander -= delta
	_call_timer -= delta
	if tree != -1 and life.tree_gone(tree):
		flush(global_position)
		return
	var player := Game.player
	var reach := Tuning.BIRD_FLUSH_RADIUS
	var slow := Vector2(player.velocity.x, player.velocity.z).length() < 1.5
	if player.is_crouching() and slow:
		reach *= Tuning.BIRD_CROUCH_FACTOR
	var flat := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z)
	if flat.length() < reach:
		flush(player.global_position)
		return
	if _call_timer <= 0.0:
		_call_timer = _next_gap()
		if _shy <= 0.0 and _awake():
			_sing()
	if _wander <= 0.0:
		_wander = randf_range(Tuning.BIRD_WANDER_SECONDS.x, Tuning.BIRD_WANDER_SECONDS.y)
		if _awake():
			_fly_away(global_position, 8.0, 30.0)
			return
	# Pousado, vira a cabeça de vez em quando.
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(0.6, 3.0)
		_head.rotation.y = randf_range(-1.2, 1.2) if species != Species.WOODPECKER else randf_range(-0.4, 0.4)


## Acordado na hora dele: canoro e pica-pau de dia, coruja de noite. Chuva forte cala todos.
func _awake() -> bool:
	if Weather.rain > 0.7:
		return false
	var night := Clock.night()
	return night > 0.6 if species == Species.OWL else night < 0.4


func _next_gap() -> float:
	match species:
		Species.WOODPECKER:
			return randf_range(Tuning.WOODPECKER_DRUM_GAP.x, Tuning.WOODPECKER_DRUM_GAP.y)
		Species.OWL:
			return randf_range(Tuning.OWL_HOOT_GAP.x, Tuning.OWL_HOOT_GAP.y)
	var gap := randf_range(Tuning.SONGBIRD_SONG_GAP.x, Tuning.SONGBIRD_SONG_GAP.y)
	# O coro do amanhecer: das 4h30 às 8h cantam muito mais; vento e chuva fraca rareiam.
	if Clock.hour > 4.5 and Clock.hour < 8.0:
		gap /= Tuning.SONGBIRD_DAWN_BOOST
	return gap * (1.0 + 2.0 * Weather.rain) * (1.0 + Wind.intensity)


func _sing() -> void:
	match species:
		Species.SONGBIRD:
			life.call_at(_song, global_position, 10.0, -3.0, _pitch * randf_range(0.97, 1.03))
		Species.WOODPECKER:
			life.call_at(WOODPECKER, global_position, 14.0, -2.0, _pitch)
		Species.OWL:
			life.call_at(OWLS.pick_random(), global_position, 16.0, -4.0, _pitch)


func _fly_away(from: Vector3, min_distance: float, max_distance: float) -> void:
	var spot := life.perch_for(species, global_position, from, min_distance, max_distance)
	if spot.is_empty():
		return
	mode = Mode.FLYING
	_from = global_position
	_to = spot[0]
	_to_yaw = spot[1]
	_to_tree = spot[2]
	tree = -1
	for wing in _wings:
		wing.visible = true
	_flight = 0.0
	_flight_time = maxf(_from.distance_to(_to) / FLIGHT_SPEED[species], 0.8)
	rotation = Vector3(0.0, atan2(_to.x - _from.x, _to.z - _from.z), 0.0)


## Voo: sobe num arco; o canoro ondula (bate asas e plana); chega e pousa.
func _fly(delta: float) -> void:
	_flight += delta
	var t := clampf(_flight / _flight_time, 0.0, 1.0)
	var lift := 4.0 * t * (1.0 - t) * minf(_from.distance_to(_to) * 0.15, 5.0)
	var bounce := sin(_flight * 9.0) * 0.25 if species == Species.SONGBIRD else 0.0
	position = _from.lerp(_to, t) + Vector3.UP * (lift + bounce * (1.0 - t))
	var flapping := species != Species.OWL or t < 0.2 or t > 0.85
	_fold(sin(_flight * (26.0 if species == Species.SONGBIRD else 14.0)) * 0.9 if flapping else 0.25)
	if t >= 1.0:
		perch_at(_to, _to_yaw, _to_tree)


func _fold(angle: float) -> void:
	for i in _wings.size():
		_wings[i].rotation.z = angle * (1.0 if i == 0 else -1.0)


## Corpo de caixas, no estilo dos outros bichos. A frente é +Z.
func _build_body() -> void:
	var colors: Array
	var size: Vector3
	match species:
		Species.WOODPECKER:
			colors = [Color(0.08, 0.08, 0.08), Color(0.75, 0.73, 0.68), Color(0.55, 0.08, 0.07)]
			size = Vector3(0.06, 0.06, 0.13)
		Species.OWL:
			colors = [Color(0.36, 0.28, 0.2), Color(0.52, 0.44, 0.33), Color(0.2, 0.16, 0.12)]
			size = Vector3(0.14, 0.13, 0.17)
		_:
			colors = [Color(0.34, 0.29, 0.22), Color(0.52, 0.46, 0.36), Color(0.2, 0.18, 0.15)]
			size = Vector3(0.055, 0.05, 0.09)
	var body := Animal.flat_material(colors[0])
	var belly := Animal.flat_material(colors[1])
	var accent := Animal.flat_material(colors[2])
	var torso := Node3D.new()
	add_child(torso)
	# O pica-pau fica de pé no tronco; a coruja, empertigada; o canoro, meio deitado.
	torso.rotation.x = -1.2 if species == Species.WOODPECKER else (-1.0 if species == Species.OWL else -0.35)
	_box(torso, size, Vector3.ZERO, body)
	_box(torso, size * Vector3(0.8, 0.5, 0.7), Vector3(0.0, -size.y * 0.3, size.z * 0.05), belly)
	_box(torso, Vector3(size.x * 0.7, size.y * 0.2, size.z * 0.7), Vector3(0.0, 0.0, -size.z * 0.75), accent)
	_head = Node3D.new()
	_head.position = Vector3(0.0, size.y * 0.55, size.z * 0.45) if species != Species.OWL else Vector3(0.0, size.z * 0.55, size.y * 0.1)
	add_child(_head)
	var head_size := size.x * (1.0 if species == Species.OWL else 0.85)
	_box(_head, Vector3.ONE * head_size, Vector3.ZERO, body)
	_box(_head, Vector3(head_size * 0.25, head_size * 0.22, head_size * (0.8 if species == Species.WOODPECKER else 0.35)),
		Vector3(0.0, -head_size * 0.1, head_size * 0.6), accent)
	if species == Species.WOODPECKER:
		_box(_head, Vector3(head_size * 0.9, head_size * 0.3, head_size * 0.6), Vector3(0.0, head_size * 0.45, -head_size * 0.1), accent)
	elif species == Species.OWL:
		for side: float in [-1.0, 1.0]:
			_box(_head, Vector3.ONE * head_size * 0.22, Vector3(head_size * 0.25 * side, head_size * 0.1, head_size * 0.5), Animal.flat_material(Color(0.62, 0.52, 0.2)))
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(size.x * 0.45 * side, size.y * 0.2, 0.0)
		add_child(wing)
		_box(wing, Vector3(size.z * 1.6, 0.01, size.z * 0.6), Vector3(size.z * 0.8 * side, 0.0, 0.0), body)
		_wings.append(wing)


func _box(parent: Node3D, box_size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	parent.add_child(mesh)
