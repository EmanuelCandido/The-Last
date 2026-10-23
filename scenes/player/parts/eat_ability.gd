class_name EatAbility
extends Node
## Comer (ação "eat", tecla F): escolhe a comida pela ordem de Tuning.FOOD_PREFERENCE
## (assada antes de crua). A comida só sai do inventário quando chega à boca.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

const CHEW_SOUNDS := [preload("res://assets/audio/sfx/chew_1.wav"), preload("res://assets/audio/sfx/chew_2.wav")]
const MESSAGES := {
	&"cooked_meat": "Comeu carne assada.",
	&"meat": "Comeu carne crua.",
	&"smoked_meat": "Comeu carne defumada.",
	&"berries": "Comeu frutinhas.",
	&"mushroom": "Comeu cogumelos crus.",
	&"rotten_meat": "Comeu carne estragada.",
}
## O que se segura na mão comendo (frutinhas e cogumelos vão direto à boca).
const MEATS := [&"meat", &"cooked_meat", &"smoked_meat", &"rotten_meat", &"white_meat"]

@onready var _player: Player = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("eat") or not _player.can_act():
		return
	get_viewport().set_input_as_handled()
	var food := _pick_food()
	if food == &"":
		Events.notification_shown.emit("Nada para comer. Cace e asse a carne na fogueira.")
		return
	_player.perform(&"eat", Tuning.EAT_TIME, [[Tuning.EAT_BITE_AT, _bite.bind(food)]])
	if food in MEATS:
		_player.hold_in_hand(MeatMesh.instance(food in [&"cooked_meat", &"smoked_meat"]), Tuning.EAT_TIME - 0.25)


func _pick_food() -> StringName:
	for food: StringName in Tuning.FOOD_PREFERENCE:
		if Inventory.has(food):
			return food
	return &""


func _bite(food: StringName) -> void:
	if not Inventory.remove(food):
		return
	OccludedAudio.play_at(_player, CHEW_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.7, &"World", -6.0, 2.0, randf_range(0.92, 1.08))
	var sick := Vitals.eat(food)
	Events.notification_shown.emit(MESSAGES.get(food, "Comeu.") + (" Não caiu bem..." if sick else ""))
