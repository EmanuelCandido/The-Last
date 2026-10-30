class_name Visit
extends Node
## Uma visita acordado (§6.2): a lucidez correndo, o coração e a visão que fecham nos últimos
## segundos, e os objetivos feitos nesta visita. Eles só valem quando Ari deita de volta na
## cápsula (finish(true)); desmaiar ou ser sedado perde tudo o que foi feito nela, porque o
## Zelador conserta enquanto Ari dorme.
##
## Também percebe o R1 sozinho: com o monitor e a janela vistos de perto, ele fica pendente.

## A lucidez acabou: Ari desmaia.
signal ran_out

const HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")
## R1: de quão perto (m) e com quão pouco desvio do centro da tela (graus) conta "ver".
const LOOK_DISTANCE := {&"monitor": 3.0, &"window": 5.0}
const LOOK_ANGLE := {&"monitor": 20.0, &"window": 25.0}

var shelter: Shelter
var active := false
## Segundos de lucidez que sobram e o total desta visita.
var seconds_left := 0.0
var total := 0.0
## Objetivos feitos nesta visita, ainda não guardados.
var pending: Array[StringName] = []
## Ari pegou o alicate do almoxarifado (só vale nesta visita).
var has_pliers := false

var _seen := {}
var _heart: AudioStreamPlayer
var _heart_timer := 0.0


func _ready() -> void:
	_heart = AudioStreamPlayer.new()
	_heart.stream = HEARTBEAT
	_heart.bus = &"Shelter"
	add_child(_heart)


## Quanto dura a lucidez agora (§6.2): menos com fome; menos ainda logo depois de morrer.
static func lucidity_seconds(last_wake: StringName) -> float:
	if last_wake == &"death":
		return Tuning.LUCIDITY_AFTER_DEATH
	var seconds := Tuning.LUCIDITY_SECONDS
	if Vitals.satiety < Tuning.LUCIDITY_HUNGRY_BELOW:
		seconds *= Tuning.LUCIDITY_HUNGRY_FACTOR
	# F14: uma luta pesada no dia cansa o corpo de Ari (a adrenalina).
	if Story.has_flag(&"hard_fight_today"):
		seconds -= Tuning.COMBAT_LUCIDITY_PENALTY
	return seconds


func begin(seconds: float) -> void:
	active = true
	total = seconds
	seconds_left = seconds
	pending.clear()
	has_pliers = false
	_seen.clear()


## Fim da visita. `keep` = Ari deitou na cápsula: devolve os objetivos para guardar.
func finish(keep: bool) -> Array[StringName]:
	active = false
	Game.vision.tunnel = 0.0
	var done: Array[StringName] = []
	if keep:
		done = pending.duplicate()
	pending.clear()
	has_pliers = false
	return done


## Feito: guardado ou pendente nesta visita.
func did(objective: StringName) -> bool:
	return pending.has(objective) or Story.has_flag(objective)


## Dá para fazer agora: ainda não foi, e o anterior da corrente já foi (nesta visita conta).
func can(objective: StringName) -> bool:
	if did(objective) or not StoryBeats.OBJECTIVES.has(objective):
		return false
	var needs: StringName = StoryBeats.OBJECTIVES[objective]
	return needs == &"" or did(needs)


func add(objective: StringName) -> void:
	if can(objective):
		pending.append(objective)
		print("[Visita] Objetivo pendente: %s" % objective)


func _process(delta: float) -> void:
	if not active or shelter.ari == null:
		return
	seconds_left -= delta
	# Nos últimos segundos: o coração dispara e a visão fecha pelas bordas.
	var warning := clampf(1.0 - seconds_left / Tuning.LUCIDITY_WARNING, 0.0, 1.0)
	Game.vision.tunnel = warning * 0.9
	if warning > 0.0:
		_heart_timer -= delta
		if _heart_timer <= 0.0:
			_heart_timer = lerpf(0.9, 0.38, warning)
			_heart.volume_db = lerpf(-16.0, -2.0, warning)
			_heart.play()
	if seconds_left <= 0.0:
		active = false
		ran_out.emit()
		return
	_watch_room()


## R1: olhou o monitor e a janela de perto.
func _watch_room() -> void:
	if did(&"room_seen") or not shelter.ari.controls:
		return
	var camera := shelter.ari.camera
	var targets := {
		&"monitor": shelter.monitor.global_transform * Vector3(0.0, VitalsMonitor.SCREEN_HEIGHT, 0.0),
		&"window": shelter.blinds.global_position,
	}
	for name: StringName in targets:
		var to_target: Vector3 = targets[name] - camera.global_position
		if to_target.length() < LOOK_DISTANCE[name] and rad_to_deg((-camera.global_basis.z).angle_to(to_target)) < LOOK_ANGLE[name]:
			_seen[name] = true
	if _seen.has(&"monitor") and _seen.has(&"window"):
		add(&"room_seen")
