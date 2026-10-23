extends MeshInstance3D
## Pele onde o goblin dorme. Com sono (Clock.can_sleep), E deita e passa a noite
## (Game.pass_out): o tempo pula para a manhã, o corpo descansa e um risco vai para a parede.


func _ready() -> void:
	add_to_group(&"interactable")


func interaction_prompt() -> String:
	return "Dormir até amanhecer" if Clock.can_sleep() and not Game.resting else ""


func interaction_action() -> Dictionary:
	return {"action": &"lie_down", "duration": 2.0, "at": 0.15}


func interact(_player: Node) -> void:
	Game.pass_out(&"sleep")
