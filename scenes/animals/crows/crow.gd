class_name Crow
extends Node3D
## Um corvo do bando (CrowFlock). Voando, é levado pelo bando; uma flechada o derruba: cai
## rodando até o chão e vira caça para pegar as penas (Tuning.CROW_FEATHERS), com as
## flechas presas nele.

signal shot

const HIT_LAYER := 8
const PICKUP_SOUND := preload("res://assets/audio/real/pickup_1.ogg")

var terrain: Terrain
var wings: Array[Node3D] = []
var dead := false

var _fall_speed := 0.0
var _spin := Vector3.ZERO
var _landed := false


func _ready() -> void:
	var feathers := Animal.flat_material(Color(0.05, 0.05, 0.06))
	var beak := Animal.flat_material(Color(0.18, 0.17, 0.16))
	_part(self, Vector3(0.12, 0.1, 0.38), Vector3.ZERO, feathers)
	_part(self, Vector3(0.09, 0.09, 0.1), Vector3(0.0, 0.03, 0.22), feathers)
	_part(self, Vector3(0.03, 0.03, 0.09), Vector3(0.0, 0.02, 0.3), beak)
	_part(self, Vector3(0.14, 0.02, 0.15), Vector3(0.0, 0.0, -0.25), feathers)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.05 * side, 0.03, 0.0)
		add_child(wing)
		_part(wing, Vector3(0.5, 0.015, 0.2), Vector3(0.25 * side, 0.0, 0.0), feathers)
		wings.append(wing)
	# Área de acerto um pouco maior que o corpo com as asas abertas: alvo alto e rápido.
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = HIT_LAYER
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.3, 0.55)
	shape.shape = box
	hitbox.add_child(shape)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	if not dead or _landed:
		return
	_fall_speed = minf(_fall_speed + 9.8 * delta, 18.0)
	position.y -= _fall_speed * delta
	rotation += _spin * delta
	var ground := terrain.get_height(position.x, position.z) if terrain != null else 0.0
	if position.y <= ground + 0.06:
		_landed = true
		position.y = ground + 0.06
		rotation = Vector3(0.0, rotation.y, PI * 0.5)
		add_to_group(&"interactable")


## Flechada (mesmo contrato do Animal): qualquer acerto derruba.
func take_hit(_power: float, _point: Vector3, _direction: Vector3, _damage := 1.0) -> void:
	if dead:
		return
	dead = true
	_spin = Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-8.0, 8.0))
	for wing in wings:
		wing.rotation.z = 0.9 * signf(wing.position.x)
	var hitbox := get_node_or_null(^"Hitbox")
	if hitbox != null:
		hitbox.queue_free()
	shot.emit()


func body_node() -> Node3D:
	return self


func interaction_prompt() -> String:
	return "Pegar as penas" if _landed else ""


func interact(_player: Node) -> void:
	Events.animal_harvested.emit(&"crow")
	Arrow.collect_from(self)
	Inventory.add(&"feather", Tuning.CROW_FEATHERS)
	Events.notification_shown.emit("+%d penas" % Tuning.CROW_FEATHERS)
	OccludedAudio.play_at(get_parent(), PICKUP_SOUND, global_position, &"World", -4.0, 3.0)
	queue_free()


func _part(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
