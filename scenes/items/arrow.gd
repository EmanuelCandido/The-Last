class_name Arrow
extends Node3D
## Flecha: voa com gravidade, finca no que acertar e pode ser recolhida com E.
##
## Em vez de corpo rígido, a cada frame de física lança um raio do ponto anterior até
## o novo: flechas rápidas não atravessam nada. Acertando um bicho (qualquer área de acerto
## cujo dono tenha take_hit, como Animal e Crow), a flecha fica presa nele e volta para o
## inventário quando o goblin coleta a caça. A emplumada (penas de corvo) cai menos e fere mais.

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
## Item que volta para o inventário ao recolher: &"arrow", &"feathered_arrow" ou &"bone_arrow".
var item := &"arrow"
## Multiplica a velocidade de saída (o arco de teixo atira mais rápido).
var speed_scale := 1.0
## Comprimento (m): quanto do projétil fica para fora ao fincar (a lança arremessada é maior).
var length := BowMesh.ARROW_LENGTH

var _flying := true
var _age := 0.0
var _exclude: Array[RID] = []


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BowMesh.arrow(is_feathered())
	add_child(mesh)


func is_feathered() -> bool:
	return item == &"feathered_arrow"


## Quanto a gravidade puxa cada tipo de flecha (a emplumada cai menos).
static func gravity_of(arrow_item: StringName) -> float:
	return GRAVITY * (Tuning.FEATHERED_GRAVITY if arrow_item == &"feathered_arrow" else 1.0)


## Quanto cada tipo de flecha fere (a de osso mais que todas).
static func damage_of(arrow_item: StringName) -> float:
	match arrow_item:
		&"feathered_arrow":
			return Tuning.FEATHERED_DAMAGE
		&"bone_arrow":
			return Tuning.BONE_ARROW_DAMAGE
		&"spear":
			return Tuning.SPEAR_THROW_DAMAGE
	return 1.0


## A velocidade com que a flecha sai, na direção `direction`, com a corda puxada `draw` (0..1).
static func start_velocity(direction: Vector3, draw: float, scale := 1.0) -> Vector3:
	return direction.normalized() * lerpf(SPEED_MIN, SPEED_MAX, draw) * scale


## Devolve ao inventário as flechas presas em `body` (a caça coletada). Retorna quantas.
static func collect_from(body: Node) -> int:
	var count := 0
	for child in body.find_children("*", "", true, false):
		if child is Arrow:
			Inventory.add((child as Arrow).item, 1, (child as Arrow).worn_value())
			count += 1
	return count


## Dispara de `from` na direção `direction` com a corda puxada `draw` (0..1).
func launch(from: Vector3, direction: Vector3, draw: float, exclude: Array[RID]) -> void:
	power = draw
	velocity = start_velocity(direction, draw, speed_scale)
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
	velocity += Vector3.DOWN * gravity_of(item) * delta
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
	Inventory.add(item)
	OccludedAudio.play_at(get_parent(), PICKUP.pick_random(), global_position, &"World", -6.0, 3.0)
	queue_free()


func _stick(hit: Dictionary) -> void:
	_flying = false
	var direction := velocity.normalized()
	# A ponta fica em -Z, meia flecha à frente do centro.
	global_position = hit.position - direction * (length * 0.5 - PENETRATION)
	var collider: Object = hit.collider
	var target: Node3D = null
	if collider is Area3D and (collider as Area3D).get_parent().has_method("take_hit"):
		target = (collider as Area3D).get_parent()
	if target != null:
		reparent(target.body_node())
		target.take_hit(power, hit.position, direction, damage_of(item))
		if target is Animal:
			Events.arrow_hit.emit((target as Animal).kind)
		OccludedAudio.play_at(target, HIT_FLESH.pick_random(), hit.position, &"World", 0.0, 5.0)
	else:
		var wood: bool = collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & TREES_LAYER
		var sounds: Array = HIT_WOOD if wood else HIT_GROUND
		OccludedAudio.play_at(get_parent(), sounds.pick_random(), hit.position, &"World", 0.0, 5.0, randf_range(0.92, 1.08))
		# F11: no chão duro a flecha às vezes quebra (a lança não).
		if not wood and breakable() and randf() < Tuning.ARROW_BREAK_CHANCE:
			Events.noise_made.emit(hit.position, 14.0)
			queue_free()
			return
		add_to_group(&"interactable")
	Events.noise_made.emit(hit.position, 14.0)


## O desgaste com que volta ao inventário (-1 = novo, como as flechas).
func worn_value() -> float:
	return -1.0


## Pode quebrar ao bater no chão (as flechas; a lança arremessada não).
func breakable() -> bool:
	return true


func _face(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT
	look_at(global_position + direction, up)
