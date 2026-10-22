class_name Arrow
extends Node3D
## Flecha: voa com gravidade, finca no que acertar e pode ser recolhida com E.
##
## Em vez de corpo rígido, a cada frame de física lança um raio do ponto anterior até
## o novo: flechas rápidas não atravessam nada. Acertando um bicho, a flecha fica
## presa nele e volta para o inventário quando o goblin coleta a caça.

const SPEED_MIN := 16.0
const SPEED_MAX := 52.0
const GRAVITY := 9.8
## Mundo, árvores e bichos (as áreas de acerto dos bichos ficam na camada 4).
const HIT_MASK := 1 | 2 | 8
const TREES_LAYER := 2
## Quanto da flecha entra no alvo.
const PENETRATION := 0.12
const HIT_WOOD := [
	preload("res://assets/audio/real/arrow_hit_wood_1.ogg"), preload("res://assets/audio/real/arrow_hit_wood_2.ogg"),
	preload("res://assets/audio/real/arrow_hit_wood_3.ogg"),
]
const HIT_GROUND := [
	preload("res://assets/audio/real/arrow_hit_ground_1.ogg"), preload("res://assets/audio/real/arrow_hit_ground_2.ogg"),
	preload("res://assets/audio/real/arrow_hit_ground_3.ogg"),
]
const HIT_FLESH := [
	preload("res://assets/audio/real/arrow_hit_flesh_1.ogg"), preload("res://assets/audio/real/arrow_hit_flesh_2.ogg"),
	preload("res://assets/audio/real/arrow_hit_flesh_3.ogg"),
]
const PICKUP := [
	preload("res://assets/audio/real/pickup_1.ogg"), preload("res://assets/audio/real/pickup_2.ogg"),
	preload("res://assets/audio/real/pickup_3.ogg"), preload("res://assets/audio/real/pickup_4.ogg"),
]

var velocity := Vector3.ZERO
## Força do disparo (0..1): quanto a corda foi puxada.
var power := 1.0

var _flying := true
var _age := 0.0
var _exclude: Array[RID] = []


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BowMesh.arrow()
	add_child(mesh)


## Dispara de `from` na direção `direction` com a corda puxada `draw` (0..1).
func launch(from: Vector3, direction: Vector3, draw: float, exclude: Array[RID]) -> void:
	power = draw
	velocity = direction.normalized() * lerpf(SPEED_MIN, SPEED_MAX, draw)
	_exclude = exclude
	global_position = from
	_face(velocity)


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	_age += delta
	if _age > 10.0:
		queue_free()
		return
	velocity += Vector3.DOWN * GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, _exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_face(velocity)
	else:
		_stick(hit)


func interaction_prompt() -> String:
	return "" if _flying else "Pegar a flecha"


func interact(_player: Node) -> void:
	Inventory.add(&"arrow")
	OccludedAudio.play_at(get_parent(), PICKUP.pick_random(), global_position, &"World", -6.0, 3.0)
	queue_free()


func _stick(hit: Dictionary) -> void:
	_flying = false
	var direction := velocity.normalized()
	# A ponta fica em -Z, meia flecha à frente do centro.
	global_position = hit.position - direction * (BowMesh.ARROW_LENGTH * 0.5 - PENETRATION)
	var collider: Object = hit.collider
	var animal: Animal = null
	if collider is Area3D:
		animal = (collider as Area3D).get_parent() as Animal
	if animal != null:
		reparent(animal.body_node())
		animal.take_hit(power, hit.position, direction)
		OccludedAudio.play_at(animal, HIT_FLESH.pick_random(), hit.position, &"World", 0.0, 5.0)
	else:
		var wood: bool = collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & TREES_LAYER
		var sounds: Array = HIT_WOOD if wood else HIT_GROUND
		OccludedAudio.play_at(get_parent(), sounds.pick_random(), hit.position, &"World", 0.0, 5.0, randf_range(0.92, 1.08))
		add_to_group(&"interactable")
	Events.noise_made.emit(hit.position, 14.0)


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT
	look_at(global_position + direction, up)
