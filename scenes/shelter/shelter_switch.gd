class_name ShelterSwitch
extends Node3D
## Uma coisa do Abrigo em que Ari mexe com E (fusível, alicate, cabo do clima, cartão). O texto,
## quando dá para fazer (`available`) e o que acontece (`action`) vêm de quem monta: assim cada
## objetivo é um punhado de linhas no Shelter, sem uma classe para cada.

## Texto quando dá para fazer ("Puxar o fusível do sensor").
var prompt := ""
## Texto quando ainda não dá (sem [E]); vazio = não aparece.
var locked_prompt := ""
## () -> bool: dá para fazer agora.
var available := func() -> bool: return true
## (body) -> void: o que acontece.
var action := func(_body: Node) -> void: pass
## Desligado: não aparece (já foi feito nesta visita, por exemplo).
var enabled := true


func _ready() -> void:
	add_to_group(&"interactable")


func interaction_prompt() -> String:
	if not Game.awake or not enabled or not is_visible_in_tree():
		return ""
	return prompt if available.call() else locked_prompt


func interaction_enabled() -> bool:
	return enabled and available.call()


func interact(body: Node) -> void:
	if interaction_enabled():
		action.call(body)
