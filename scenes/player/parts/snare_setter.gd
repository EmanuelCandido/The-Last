class_name SnareSetter
extends Node3D
## Armar o laço (§4.10): com um laço no inventário e pegadas frescas de coelho a até
## Tuning.SNARE_TRACK_DISTANCE, aparece "[E] Armar o laço" sobre a pegada mais perto. É um
## interagível como os outros: este nó vai para cima da pegada e o Player o acha sozinho.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

## Onde armar agora (Vector3.INF = em lugar nenhum).
var spot := Vector3.INF
## Onde o goblin começou a armar (o spot some enquanto ele está ocupado).
var _arming_at := Vector3.INF

@onready var _player: Player = get_parent()


func _ready() -> void:
	top_level = true
	add_to_group(&"interactable")


func _physics_process(_delta: float) -> void:
	spot = Vector3.INF
	if Inventory.has(&"snare") and _player.can_act():
		spot = Tracks.nearest(&"rabbit", _player.global_position, Tuning.SNARE_TRACK_DISTANCE)
	# Longe de tudo quando não há onde armar (o Player só olha interagíveis perto).
	global_position = spot if spot != Vector3.INF else Vector3(0.0, -1000.0, 0.0)


func interaction_prompt() -> String:
	return "" if spot == Vector3.INF else "Armar o laço (pegadas de coelho)"


func interaction_action() -> Dictionary:
	return {"action": &"harvest", "duration": 2.4, "at": 1.9}


func interaction_started(_player_node: Node) -> void:
	_arming_at = spot


func interact(_player_node: Node) -> void:
	var field := get_tree().get_first_node_in_group(SnareField.GROUP) as SnareField
	if field == null or _arming_at == Vector3.INF or not Inventory.remove(&"snare"):
		return
	var at := _arming_at
	_arming_at = Vector3.INF
	var across := (at - _player.global_position)
	field.place(at, atan2(across.x, across.z))
	Events.notification_shown.emit("Laço armado. Volte mais tarde (ou amanhã).")
