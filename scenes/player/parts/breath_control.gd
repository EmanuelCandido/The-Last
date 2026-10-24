class_name BreathControl
extends Node
## Prender o ar (segurar "hold_breath", Q), §4.9. Enquanto segura: parado, o goblin não
## faz barulho nenhum (nem a respiração ofegante), o braço do arco firma e o coração bate
## baixinho, cada vez mais rápido. Passando de Tuning.BREATH_MAX_SECONDS, solta o ar alto
## (barulho de Tuning.BREATH_GASP_NOISE m) e fica ofegante: respira alto e a mira treme.
##
## O ritual de acordar (§4.9) usa este mesmo segurar: deitado no sarcófago da ruína, ou
## agachado e parado no fundo escuro da caverna, o ar não acaba; com
## Tuning.RITUAL_BREATH_SECONDS, emite Events.ritual_completed e a Vigilância sobe (mais
## ainda se um corvo estiver vendo). O que acontece depois é do beat "ritual" (F5/F6).
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

const BREATH_IN := preload("res://assets/audio/real/breath_in.ogg")
const GASP := preload("res://assets/audio/real/gasp.ogg")
const HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")

## Segundos com o ar preso agora (0 = respirando).
var held_for := 0.0

var _holding := false
## Sem fôlego depois de soltar à força: não prende de novo até passar.
var _recover := 0.0
var _heart_timer := 0.0
var _heart: AudioStreamPlayer
## O ritual já terminou neste fôlego (um por vez).
var _ritual_done := false

@onready var _player: Player = get_parent()


func _ready() -> void:
	# O coração é ouvido por dentro: sem posição no mundo.
	_heart = AudioStreamPlayer.new()
	_heart.stream = HEARTBEAT
	_heart.bus = &"World"
	add_child(_heart)


func _physics_process(delta: float) -> void:
	_recover = maxf(_recover - delta, 0.0)
	# Deitado no sarcófago os controles estão travados, mas prender o ar é o ritual.
	var want := Input.is_action_pressed("hold_breath") and (_player.can_act() or _player.lying) and _recover <= 0.0
	if want and not _holding:
		_start()
	elif not want and _holding:
		_release(false)
	if not _holding:
		return
	held_for += delta
	var limit := max_seconds()
	var tension := clampf(held_for / (Tuning.RITUAL_BREATH_SECONDS if is_inf(limit) else limit), 0.0, 1.0)
	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = lerpf(1.05, 0.5, tension)
		_heart.volume_db = lerpf(-20.0, -6.0, tension)
		_heart.play()
	var place := ritual_place()
	if place != &"" and held_for >= Tuning.RITUAL_BREATH_SECONDS and not _ritual_done:
		_complete_ritual(place)
	if held_for >= max_seconds():
		_release(true)


func is_holding() -> bool:
	return _holding


## Quanto aguenta agora. No lugar do ritual não acaba.
func max_seconds() -> float:
	return INF if ritual_place() != &"" else Tuning.BREATH_MAX_SECONDS


## Lugar de ritual onde o goblin está agora (&"" = nenhum): deitado no sarcófago, ou
## agachado e parado no fundo da caverna (os últimos 3 m, longe da boca e do fogo).
func ritual_place() -> StringName:
	if _player.ritual_place != &"":
		return _player.ritual_place
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	var back := at.y - ForestLayout.CAVE_CENTER.y > ForestLayout.CAVE_DEPTH * 0.5 - 3.0
	var still := Vector2(_player.velocity.x, _player.velocity.z).length() < 0.2
	if back and ForestLayout.cave_interior(at) > 0.9 and _player.is_crouching() and still:
		return &"cave_dark"
	return &""


func _complete_ritual(place: StringName) -> void:
	_ritual_done = true
	Story.add_vigilance(Tuning.VIGILANCE_RITUAL)
	if Watchers.watching(_player.global_position + Vector3.UP * 0.4):
		Story.add_vigilance(Tuning.VIGILANCE_RITUAL_SEEN)
	Events.ritual_completed.emit(place)


func _start() -> void:
	_holding = true
	_ritual_done = false
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
