class_name TorchCarry
extends Node
## Carregar a tocha acesa (§4.10): na mão direita, erguida à frente. Ilumina, esquenta e
## espanta lobo, mas os bichos veem o goblin de longe (Tuning.TORCH_VISIBILITY, e de noite
## sem o desconto do escuro). Ao mirar o arco, o goblin finca a tocha no chão à frente
## (fica acesa ali; E pega de volta). Acaba em Tuning.TORCH_SECONDS.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

## Inclinação da tocha para a frente (rad), longe do rosto.
const TILT := 0.3

## A tocha na mão, ou null.
var torch: Torch

@onready var _player: Player = get_parent()


func _process(_delta: float) -> void:
	if torch == null:
		return
	if not is_instance_valid(torch) or not torch.is_lit():
		_let_go()
		return
	if _player.aiming:
		_plant()
		return
	var socket := _player.hand_socket()
	var forward := _player.facing()
	var up := Vector3.UP.rotated(forward.cross(Vector3.UP).normalized(), -TILT) if forward.length_squared() > 0.0 else Vector3.UP
	torch.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), socket.global_position)
	_player.visibility_factors[&"torch"] = Tuning.TORCH_VISIBILITY / lerpf(1.0, Tuning.NIGHT_VISIBILITY, Clock.night())


## Acende uma tocha nova na mão (a velha, se houver, é trocada pela nova).
func light() -> void:
	if torch != null and is_instance_valid(torch):
		torch.queue_free()
	torch = Torch.new()
	Game.current_level.add_child(torch)
	torch.burned_out.connect(_on_burned_out.bind(torch))
	_player.torch_held = true


## Pega de volta uma tocha fincada.
func take(planted: Torch) -> void:
	if torch != null or not planted.is_lit():
		return
	planted.planted = false
	torch = planted
	_player.torch_held = true


func _plant() -> void:
	var forward := _player.facing()
	var at := _player.global_position + forward * 0.55
	var level := Game.current_level
	if level != null and level.has_method("ground_height"):
		at.y = float(level.ground_height(at.x, at.z))
	# O pau entra uns 12 cm na terra.
	torch.global_transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.03)
	torch.planted = true
	torch = null
	_let_go()


func _let_go() -> void:
	torch = null
	_player.torch_held = false
	_player.visibility_factors.erase(&"torch")


func _on_burned_out(burned: Torch) -> void:
	if burned != torch:
		return
	Events.notification_shown.emit("A tocha apagou.")
	# O pau apagado cai da mão.
	var level := Game.current_level
	if level != null and level.has_method("ground_height"):
		var at := burned.global_position
		burned.global_transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(at.x, float(level.ground_height(at.x, at.z)) + 0.03, at.z))
	_let_go()
