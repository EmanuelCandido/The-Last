class_name Clues
extends Node
## As pistas do Ato I (§3) e os sons que vazam do mundo real (§7). Os beats só ligam um
## flag ("clue_deer_freeze"...); aqui cada pista espera a hora certa, acontece uma vez,
## rápido, e liga "<flag>_seen". Nenhuma interrompe o jogo: tem que parecer bug ou estilo.
##
## Do Ato II em diante, os vazamentos repetem: o bipe às vezes à noite na caverna e o
## ventilador nas rajadas fortes.

const BEEP := preload("res://assets/audio/sfx/monitor_beep.wav")
const FAN := preload("res://assets/audio/sfx/fan_hum.wav")

var watchers: Watchers

var _fan_cooldown := 0.0
## Noite (dia em que começou) em que já se sorteou o bipe vazando.
var _beep_night := -1
var _beep_at := -1.0


func _process(delta: float) -> void:
	var player := Game.player
	if player == null or Game.resting or not player.can_act():
		return
	_fan_cooldown = maxf(_fan_cooldown - delta, 0.0)
	if _pending(&"clue_deer_freeze"):
		_try_deer_freeze(player)
	if _pending(&"clue_crow_stare"):
		_try_crow_stare(player)
	if _pending(&"clue_beep") and Clock.night() > 0.6 and _indoor(player) > 0.8:
		_beeps()
		_done(&"clue_beep")
	if _pending(&"clue_fan") and _strong_gust(player):
		_fan()
		_done(&"clue_fan")
	if Story.act >= 2:
		_leaks(player)


## Pista ligada pelo beat e ainda não vista.
func _pending(flag: StringName) -> bool:
	return Story.has_flag(flag) and not Story.has_flag(StringName("%s_seen" % flag))


func _done(flag: StringName) -> void:
	Story.set_flag(StringName("%s_seen" % flag))


## O primeiro cervo na tela, a menos de Tuning.CLUE_DEER_DISTANCE, trava no meio do passo.
func _try_deer_freeze(player: Player) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for node in get_tree().get_nodes_in_group(&"deer"):
		var deer := node as Animal
		if deer.state == Animal.State.DEAD or deer.speed < 0.3:
			continue
		var at := deer.global_position + Vector3.UP * 1.0
		if at.distance_to(player.global_position) > Tuning.CLUE_DEER_DISTANCE or not camera.is_position_in_frustum(at):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, at, 1 | 2)
		if not get_viewport().get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		deer.freeze(Tuning.CLUE_DEER_FREEZE)
		_done(&"clue_deer_freeze")
		return


## Na primeira vez fora da caverna, de dia, um corvo pousa perto e encara sem crocitar.
func _try_crow_stare(player: Player) -> void:
	if watchers == null or _indoor(player) > 0.05 or Clock.night() > 0.5:
		return
	var spot := watchers.ground_spot_near_player(Tuning.CLUE_CROW_DISTANCE)
	if spot == Vector3.INF:
		return
	watchers.perch_crow(spot, player, Tuning.CLUE_CROW_SECONDS, true)
	_done(&"clue_crow_stare")


## Três bipes no ritmo de um coração (Tuning.CLUE_BEEP_BPM).
func _beeps() -> void:
	for i in Tuning.CLUE_BEEPS:
		get_tree().create_timer(i * 60.0 / Tuning.CLUE_BEEP_BPM, false).timeout.connect(func() -> void:
			_play(BEEP, -16.0))


func _fan() -> void:
	_play(FAN, -12.0)
	_fan_cooldown = Tuning.LEAK_FAN_COOLDOWN


## Vazamento é "dentro da cabeça": sem posição no mundo, baixinho.
func _play(stream: AudioStream, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"World"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## Ato II em diante: o ventilador nas rajadas fortes (com intervalo) e, numa parte das
## noites, os bipes num momento sorteado da noite na caverna.
func _leaks(player: Player) -> void:
	if _fan_cooldown <= 0.0 and _strong_gust(player):
		_fan()
	var night := Clock.day if Clock.hour >= 12.0 else Clock.day - 1
	if Clock.night() < 0.6:
		return
	if _beep_night != night:
		_beep_night = night
		_beep_at = randf_range(0.0, 1.0) if randf() < Tuning.LEAK_BEEP_CHANCE else -1.0
		return
	if _beep_at >= 0.0 and _indoor(player) > 0.8 and _night_progress() >= _beep_at:
		_beep_at = -1.0
		_beeps()


## Quanto da noite fechada já passou (0 às 20h30 .. 1 às 5h).
func _night_progress() -> float:
	var hours := Clock.hour - Tuning.DUSK.y if Clock.hour >= 12.0 else Clock.hour + 24.0 - Tuning.DUSK.y
	return clampf(hours / (24.0 - Tuning.DUSK.y + Tuning.DAWN.x), 0.0, 1.0)


func _strong_gust(player: Player) -> bool:
	return _indoor(player) < 0.2 and Wind.strength_at(player.global_position) > Tuning.CLUE_FAN_GUST


func _indoor(player: Player) -> float:
	var level := Game.current_level
	return float(level.indoor_at(player.global_position)) if level != null and level.has_method("indoor_at") else 0.0
