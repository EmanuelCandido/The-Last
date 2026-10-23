class_name CrowFlock
extends Node3D
## Bando de corvos voando em círculos sobre o vale, alternando batidas de asa e
## planeio, e grasnando de vez em quando. Um corvo abatido (Crow) sai do bando e cai;
## Tuning.CROW_RESPAWN_SECONDS depois, outro chega.

const CAWS := [
	preload("res://assets/audio/animals/crow_1.wav"),
	preload("res://assets/audio/animals/crow_2.wav"),
]

@export var count := 6
## Altura de voo acima do terreno.
@export var flight_height := 26.0

var terrain: Terrain

var _crows: Array[Dictionary] = []
var _time := 0.0
var _caw_timer := 6.0
var _voice: AudioStreamPlayer3D
## O corvo que está grasnando: a voz voa junto com ele.
var _cawing: Node3D


func _ready() -> void:
	for i in count:
		_add_crow()
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"Ambience"
	_voice.unit_size = 18.0
	_voice.max_distance = 180.0
	add_child(_voice)


func _process(delta: float) -> void:
	_time += delta
	var center := Vector2(sin(_time * 0.03) * 40.0, cos(_time * 0.023) * 30.0)
	for crow in _crows:
		crow.angle += crow.speed / crow.radius * delta
		var p: Vector2 = center + Vector2(cos(crow.angle), sin(crow.angle)) * crow.radius
		var ground := terrain.get_height(p.x, p.y) if terrain != null else 0.0
		var node: Crow = crow.node
		node.position = Vector3(p.x, ground + flight_height + crow.lift + sin(_time * 0.5 + crow.phase) * 2.0, p.y)
		var tangent := Vector2(-sin(crow.angle), cos(crow.angle))
		node.rotation = Vector3(0.0, atan2(tangent.x, tangent.y), -0.25)
		var gliding := sin(_time * 0.4 + crow.phase) > 0.3
		var flap := 0.12 if gliding else sin(_time * 9.0 + crow.phase) * 0.7
		node.wings[0].rotation.z = -flap
		node.wings[1].rotation.z = flap

	_caw_timer -= delta
	if _caw_timer <= 0.0 and not _crows.is_empty():
		_caw_timer = randf_range(7.0, 16.0)
		_cawing = _crows.pick_random().node as Node3D
		_voice.stream = CAWS.pick_random()
		_voice.pitch_scale = randf_range(0.9, 1.1)
		_voice.play()
	if _voice.playing and is_instance_valid(_cawing):
		_voice.global_position = _cawing.global_position


## Corvos voando agora (para testes e para a Vigilância).
func flying() -> Array[Crow]:
	var list: Array[Crow] = []
	for crow in _crows:
		list.append(crow.node)
	return list


func _add_crow() -> void:
	var crow := Crow.new()
	crow.terrain = terrain
	add_child(crow)
	var entry := {
		"node": crow,
		"radius": randf_range(14.0, 32.0), "angle": randf() * TAU,
		"speed": randf_range(7.0, 10.0), "phase": randf() * TAU, "lift": randf_range(-3.0, 4.0),
	}
	_crows.append(entry)
	crow.shot.connect(_on_shot.bind(entry))


func _on_shot(entry: Dictionary) -> void:
	_crows.erase(entry)
	# O bando grasna junto quando um cai.
	_caw_timer = 0.0
	get_tree().create_timer(Tuning.CROW_RESPAWN_SECONDS, false).timeout.connect(_add_crow)
