class_name Sarcophagus
extends Node3D
## O sarcófago da sala-espelho (§3), no lugar onde fica a cápsula de Ari no mundo real.
## A tampa está tombada ao lado. "Deitar no sarcófago" deita o goblin de costas dentro dele:
## é um lugar de ritual (prender o ar 20 s, §4.9). Espaço ou E levanta.
## A origem é o meio do fundo, no chão; o comprimento corre em Z (pés para +Z).

const LENGTH := 1.7
const WIDTH := 0.75
const HEIGHT := 0.55
const SIDE := 0.08

var _lying := false


func build(material: Material) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var half := Vector3(WIDTH, HEIGHT, LENGTH) * 0.5
	# Fundo e as quatro paredes (o miolo fica livre para deitar).
	_slab(body, material, Vector3(WIDTH, SIDE, LENGTH), Vector3(0.0, SIDE * 0.5, 0.0))
	for side in [-1.0, 1.0]:
		_slab(body, material, Vector3(SIDE, HEIGHT, LENGTH), Vector3((half.x - SIDE * 0.5) * side, half.y, 0.0))
		_slab(body, material, Vector3(WIDTH, HEIGHT, SIDE), Vector3(0.0, half.y, (half.z - SIDE * 0.5) * side))
	# A tampa, empurrada e tombada contra o lado esquerdo.
	_slab(body, material, Vector3(WIDTH + 0.08, 0.1, LENGTH + 0.08), Vector3(-WIDTH * 0.5 - 0.3, 0.32, 0.05), Vector3(0.0, 0.0, 1.15))
	add_to_group(&"interactable")


func interaction_prompt() -> String:
	return "" if _lying else "Deitar no sarcófago"


func interaction_action() -> Dictionary:
	return {"action": &"lie_down", "duration": 1.6, "at": 1.5}


func interact(player: Node) -> void:
	_lying = true
	# Pés para +Z: o goblin olha para cima com a cabeça no fundo do sarcófago.
	(player as Player).lie_at(global_position + Vector3.UP * SIDE, global_rotation.y, &"sarcophagus")
	Events.notification_shown.emit("[Espaço] levantar")


func is_occupied() -> bool:
	return _lying


func _unhandled_input(event: InputEvent) -> void:
	if not _lying or not (event.is_action_pressed("jump") or event.is_action_pressed("interact")):
		return
	get_viewport().set_input_as_handled()
	get_up()


func get_up() -> void:
	if not _lying or Game.player == null:
		return
	_lying = false
	# Levanta já do lado de fora, à direita.
	Game.player.get_up(global_transform * Vector3(WIDTH * 0.5 + 0.45, 0.0, 0.0))


func _slab(body: StaticBody3D, material: Material, size: Vector3, center: Vector3, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	mesh.rotation = tilt
	add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = size
	shape.shape = collision
	shape.position = center
	shape.rotation = mesh.rotation
	body.add_child(shape)
	return mesh
