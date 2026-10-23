class_name BodyFeedback
extends Node
## O corpo avisa, sem barra no HUD: a barriga ronca com fome e um aviso aparece quando
## a fome começa e quando ela passa a machucar. Lê de Vitals; a borda escura da vida
## baixa fica no HUD e a mão na barriga no GoblinAnimator.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira os avisos.

const GROWL_SOUNDS := [preload("res://assets/audio/sfx/stomach_growl_1.wav"), preload("res://assets/audio/sfx/stomach_growl_2.wav")]

var _growl_timer := 0.0
var _warned_hungry := false
var _warned_starving := false

@onready var _player: Player = get_parent()


func _ready() -> void:
	_growl_timer = randf_range(Tuning.GROWL_INTERVAL.x, Tuning.GROWL_INTERVAL.y) * 0.3


func _process(delta: float) -> void:
	if Game.resting:
		return
	if not Vitals.is_hungry():
		# Comeu: os avisos podem voltar da próxima vez que a fome apertar.
		if Vitals.satiety > Tuning.HUNGRY_BELOW + 10.0:
			_warned_hungry = false
		_warned_starving = false
		return
	if not _warned_hungry:
		_warned_hungry = true
		Events.notification_shown.emit("Com fome.")
	if Vitals.satiety <= 0.0 and not _warned_starving:
		_warned_starving = true
		Events.notification_shown.emit("A fome está machucando. Coma alguma coisa.")
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		# Quanto mais fome, mais seguido ronca.
		var urgency := 1.0 - Vitals.satiety / Tuning.HUNGRY_BELOW
		_growl_timer = randf_range(Tuning.GROWL_INTERVAL.x, Tuning.GROWL_INTERVAL.y) * lerpf(1.0, 0.5, urgency)
		OccludedAudio.play_at(_player, GROWL_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.5, &"World", lerpf(-12.0, -5.0, urgency), 1.5, randf_range(0.9, 1.1))
