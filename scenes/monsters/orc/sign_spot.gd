class_name SignSpot
extends Node3D
## Um sinal que o goblin pega ou examina (F12+, OrcSigns): E faz a ação de pegar e avisa o dono.

signal taken

var prompt := ""
var active := true


func _ready() -> void:
	add_to_group(&"interactable")


func interaction_prompt() -> String:
	return prompt if active else ""


func interact(_player: Node) -> void:
	if active:
		active = false
		taken.emit()
