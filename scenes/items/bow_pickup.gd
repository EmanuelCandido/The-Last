extends Node3D
## Arco e aljava largados na caverna. Com E, o goblin pega o arco e as flechas.

const ARROWS := 6
const PICKUP := preload("res://assets/audio/real/pickup_5.ogg")


func _ready() -> void:
	if Inventory.has(&"bow"):
		queue_free()
		return
	add_to_group(&"interactable")
	# Arco deitado de lado no chão (a barriga para +Z, corda atrás).
	var bow := MeshInstance3D.new()
	bow.mesh = BowMesh.build_bow()
	bow.rotation = Vector3(0.0, 0.0, PI * 0.5)
	bow.position = Vector3(0.0, 0.025, 0.0)
	add_child(bow)
	# Aljava tombada ao lado, com as penas das flechas para fora.
	var quiver := MeshInstance3D.new()
	quiver.mesh = BowMesh.build_quiver()
	quiver.rotation = Vector3(PI * 0.5, 0.4, 0.0)
	quiver.position = Vector3(0.1, 0.06, 0.32)
	add_child(quiver)


func interaction_prompt() -> String:
	return "Pegar o arco e as flechas"


func interact(_player: Node) -> void:
	Inventory.add(&"bow")
	Inventory.add(&"arrow", ARROWS)
	OccludedAudio.play_at(get_parent(), PICKUP, global_position + Vector3.UP * 0.3, &"World", -2.0, 3.0)
	Events.notification_shown.emit("Pegou o arco e %d flechas. Segure o botão direito para mirar." % ARROWS)
	queue_free()
