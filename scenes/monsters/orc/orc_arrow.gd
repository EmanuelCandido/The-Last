class_name OrcArrow
extends Arrow
## A flecha do arqueiro orc (docs/plano_combate.md §7.2; experimental): uma vez e meia a do goblin,
## com ponta de ferro batido. Voa e acerta como a flecha (o mesmo raio a cada quadro). No goblin, vira
## um golpe de perfuração por Player.take_hit (o escudo segura; a arma não). No chão ou num tronco,
## fica um tempo e some: é grande demais para o arco do goblin.

const SIZE := 1.5
## Segundos que a flecha fincada fica antes de sumir.
const STAY := 30.0


func _ready() -> void:
	length = BowMesh.ARROW_LENGTH * SIZE
	var mesh := MeshInstance3D.new()
	mesh.mesh = BowMesh.arrow(true)
	mesh.scale = Vector3.ONE * SIZE
	add_child(mesh)


func _stick(hit: Dictionary) -> void:
	var collider: Object = hit.collider
	if collider is Area3D and (collider as Area3D).get_parent() is Player:
		var player := (collider as Area3D).get_parent() as Player
		player.take_hit(power, hit.position, velocity.normalized(), 1.0)
		queue_free()
		return
	super._stick(hit)
	remove_from_group(&"interactable")
	get_tree().create_timer(STAY, false).timeout.connect(queue_free)


func interaction_prompt() -> String:
	return ""
