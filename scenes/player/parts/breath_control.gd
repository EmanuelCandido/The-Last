class_name BreathControl
extends Node
## Prender o ar (segurar "hold_breath", Q), §4.9. Enquanto segura: parado, o goblin não
## faz barulho nenhum (nem a respiração ofegante), o braço do arco firma e o coração bate
## baixinho, cada vez mais rápido. Passando de Tuning.BREATH_MAX_SECONDS, solta o ar alto
## (barulho de Tuning.BREATH_GASP_NOISE m) e fica ofegante: respira alto e a mira treme.
##
## O ritual de acordar do Ato III (F6) usa este mesmo segurar, agachado e parado num lugar
## de ritual, onde o ar não acaba (Tuning.RITUAL_BREATH_SECONDS).
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

const BREATH_IN := preload("res://assets/audio/sfx/breath_in.wav")
const GASP := preload("res://assets/audio/sfx/gasp.wav")
const HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")

## Segundos com o ar preso agora (0 = respirando).
var held_for := 0.0

var _holding := false
## Sem fôlego depois de soltar à força: não prende de novo até passar.
var _recover := 0.0
var _heart_timer := 0.0
var _heart: AudioStreamPlayer

@onready var _player: Player = get_parent()


func _ready() -> void:
	# O coração é ouvido por dentro: sem posição no mundo.
	_heart = AudioStreamPlayer.new()
	_heart.stream = HEARTBEAT
	_heart.bus = &"World"
	add_child(_heart)


func _physics_process(delta: float) -> void:
	_recover = maxf(_recover - delta, 0.0)
	var want := Input.is_action_pressed("hold_breath") and _player.can_act() and _recover <= 0.0
	if want and not _holding:
		_start()
	elif not want and _holding:
		_release(false)
	if not _holding:
		return
	held_for += delta
	var tension := clampf(held_for / max_seconds(), 0.0, 1.0)
	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = lerpf(1.05, 0.5, tension)
		_heart.volume_db = lerpf(-20.0, -6.0, tension)
		_heart.play()
	if held_for >= max_seconds():
		_release(true)


func is_holding() -> bool:
	return _holding


## Quanto aguenta agora. No lugar do ritual (F6) não acaba.
func max_seconds() -> float:
	return Tuning.BREATH_MAX_SECONDS


func _start() -> void:
	_holding = true
	held_for = 0.0
	_heart_timer = 0.6
	_player.breath_held = true
	OccludedAudio.play_at(_player, BREATH_IN, _player.global_position + Vector3.UP * 0.7, &"World", -12.0, 1.5, randf_range(0.95, 1.05))


## Solta o ar. `forced` = não aguentou: bufa alto, faz barulho e fica ofegante.
func _release(forced: bool) -> void:
	_holding = false
	_player.breath_held = false
	if not forced:
		return
	_recover = Tuning.BREATH_GASP_SECONDS
	# O cansaço cai 0,07/s e o goblin ofega acima de 0,45: ofegante por BREATH_GASP_SECONDS.
	_player.exert(0.45 + 0.07 * Tuning.BREATH_GASP_SECONDS)
	OccludedAudio.play_at(_player, GASP, _player.global_position + Vector3.UP * 0.7, &"World", -2.0, 4.0, randf_range(0.95, 1.05))
	Events.noise_made.emit(_player.global_position, Tuning.BREATH_GASP_NOISE)
