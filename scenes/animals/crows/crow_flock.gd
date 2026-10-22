class_name CrowFlock
extends Node3D
## Bando de corvos voando em círculos sobre o vale, alternando batidas de asa e
## planeio, e grasnando de vez em quando.

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


func _ready() -> void:
	var feathers := Animal.flat_material(Color(0.05, 0.05, 0.06))
	var beak := Animal.flat_material(Color(0.18, 0.17, 0.16))
	for i in count:
		var crow := Node3D.new()
		add_child(crow)
		_part(crow, Vector3(0.12, 0.1, 0.38), Vector3.ZERO, feathers)
		_part(crow, Vector3(0.09, 0.09, 0.1), Vector3(0.0, 0.03, 0.22), feathers)
		_part(crow, Vector3(0.03, 0.03, 0.09), Vector3(0.0, 0.02, 0.3), beak)
		_part(crow, Vector3(0.14, 0.02, 0.15), Vector3(0.0, 0.0, -0.25), feathers)
		var wings: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var wing := Node3D.new()
			wing.position = Vector3(0.05 * side, 0.03, 0.0)
			crow.add_child(wing)
			_part(wing, Vector3(0.5, 0.015, 0.2), Vector3(0.25 * side, 0.0, 0.0), feathers)
			wings.append(wing)
		_crows.append({
			"node": crow, "wings": wings,
			"radius": randf_range(14.0, 32.0), "angle": randf() * TAU,
			"speed": randf_range(7.0, 10.0), "phase": randf() * TAU, "lift": randf_range(-3.0, 4.0),
		})
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
		var node: Node3D = crow.node
		node.position = Vector3(p.x, ground + flight_height + crow.lift + sin(_time * 0.5 + crow.phase) * 2.0, p.y)
		var tangent := Vector2(-sin(crow.angle), cos(crow.angle))
		node.rotation = Vector3(0.0, atan2(tangent.x, tangent.y), -0.25)
		var gliding := sin(_time * 0.4 + crow.phase) > 0.3
		var flap := 0.12 if gliding else sin(_time * 9.0 + crow.phase) * 0.7
		var wings: Array[Node3D] = crow.wings
		wings[0].rotation.z = -flap
		wings[1].rotation.z = flap

	_caw_timer -= delta
	if _caw_timer <= 0.0:
		_caw_timer = randf_range(7.0, 16.0)
		_voice.global_position = (_crows.pick_random().node as Node3D).global_position
		_voice.stream = CAWS.pick_random()
		_voice.pitch_scale = randf_range(0.9, 1.1)
		_voice.play()


func _part(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
