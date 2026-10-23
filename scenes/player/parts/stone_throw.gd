class_name StoneThrow
extends Node
## Jogar pedra ("throw", G), §4.11: arremesso por cima na direção da câmera, um pouco para
## o alto. Onde a pedra cai faz barulho (ThrownStone): os bichos olham para lá e fogem
## dali, não do goblin. Serve para tocar a manada para perto.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

const THROW_SOUND := preload("res://assets/audio/sfx/stone_throw.wav")

@onready var _player: Player = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("throw") or not _player.can_act() or _player.aiming:
		return
	get_viewport().set_input_as_handled()
	if not Inventory.has(&"stone"):
		Events.notification_shown.emit("Sem pedras. Pegue algumas num monte de pedras soltas.")
		return
	_player.face(_player.aim_direction())
	_player.perform(&"throw", Tuning.THROW_TIME, [[Tuning.THROW_RELEASE_AT, _release]])


func _release() -> void:
	if not Inventory.remove(&"stone"):
		return
	var direction := _player.aim_direction()
	direction.y += Tuning.STONE_LOFT
	var from := _player.hand_socket().global_position
	var stone := ThrownStone.new()
	Game.current_level.add_child(stone)
	stone.launch(from, direction.normalized() * Tuning.STONE_SPEED, [_player.get_rid()])
	OccludedAudio.play_at(_player, THROW_SOUND, from, &"World", -8.0, 2.0, randf_range(0.9, 1.1))
