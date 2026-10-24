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
const FLAP := preload("res://assets/audio/real/wing_flap.ogg")
const SONGBIRD_MODEL := preload("res://assets/models/animals/songbird.glb")
const WOODPECKER_MODEL := preload("res://assets/models/animals/woodpecker.glb")
const OWL_MODEL := preload("res://assets/models/animals/owl.glb")
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
var _model: CreatureModel


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
	# Pousado, as asas ficam fechadas no corpo.
	_show_wings(false)


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
	if _model != null:
		_model.sync()
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
	var slow := Vector2(player.velocity.x, player.velocity.z).length() < 1.7
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
	_show_wings(true)
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


## Corpo com esqueleto (assets/models/animals/<espécie>.glb), na pose de pouso: o canoro meio
## deitado, o pica-pau de pé no tronco e a coruja empertigada. A frente é +Z.
func _build_body() -> void:
	var models: Array[PackedScene] = [SONGBIRD_MODEL, WOODPECKER_MODEL, OWL_MODEL]
	var palettes := [
		{"pena": [AnimalLook.PLUMAGE, Color(0.78, 0.64, 0.48)], "pena_clara": [AnimalLook.PLUMAGE, Color(1.15, 1.05, 0.88)],
			"bico": Color(0.25, 0.2, 0.15), "olho": Color(0.02, 0.02, 0.02)},
		{"pena": [AnimalLook.PLUMAGE, Color(0.22, 0.22, 0.22)], "pena_clara": [AnimalLook.PLUMAGE, Color(1.25, 1.22, 1.15)],
			"detalhe": Color(0.7, 0.09, 0.07), "bico": Color(0.16, 0.15, 0.14), "olho": Color(0.02, 0.02, 0.02)},
		{"pena": [AnimalLook.PLUMAGE, Color(0.92, 0.74, 0.54)], "pena_clara": [AnimalLook.PLUMAGE, Color(1.2, 1.08, 0.9)],
			"bico": Color(0.3, 0.28, 0.24), "olho": Color(0.02, 0.02, 0.02),
			"olho_brilho": AnimalLook.glowing_eye(Color(0.95, 0.72, 0.2), 0.6)},
	]
	_model = CreatureModel.attach(self, models[species], palettes[species], ["songbird", "woodpecker", "owl"][species])
	_head = _model.joint("cabeca")
	_wings = [_model.joint("asa_E"), _model.joint("asa_D")]
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Asas abertas só em voo; pousado, o pivô delas encolhe a quase nada.
func _show_wings(shown: bool) -> void:
	for wing in _wings:
		wing.scale = Vector3.ONE if shown else Vector3.ONE * 0.001
