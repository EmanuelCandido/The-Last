extends Node
## Estado global da partida: fase atual, jogador, pausa, captura do mouse, o ouvido e a
## passagem da noite (dormir e morrer).

const FIRST_LEVEL := "res://scenes/levels/forest/forest.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const RECYCLE_SHADER := preload("res://assets/shaders/recycle.gdshader")
const BEEP := preload("res://assets/audio/sfx/monitor_beep.wav")

## Nó onde as fases são instanciadas. Definido pela cena Main.
var level_root: Node3D
var current_level: Node3D
var player: Player
## Dormindo ou desmaiado: relógio e corpo param, e não dá para dormir de novo.
var resting := false

## O ouvido: um passa-baixa no Master que abre junto com o volume (ver open_ears).
var _ear_filter := AudioEffectLowPassFilter.new()
var _ear_tween: Tween


func _ready() -> void:
	# Precisa receber input mesmo pausado, para conseguir despausar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ear_filter.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(0, _ear_filter)
	Events.player_died.connect(func(_cause: StringName) -> void: pass_out(&"death"))
	Events.recycle_requested.connect(recycle)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		# Recaptura o mouse se o jogador clicar na janela depois de soltar o cursor.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Troca a fase atual e cria o jogador no Marker3D "PlayerSpawn" da nova fase.
func change_level(path: String) -> void:
	assert(level_root != null, "Game.level_root precisa ser definido antes de trocar de fase.")
	if current_level != null:
		level_root.remove_child(current_level)
		current_level.queue_free()
	resting = false
	current_level = (load(path) as PackedScene).instantiate() as Node3D
	level_root.add_child(current_level)
	_spawn_player()
	# Chegando num lugar: o som vem aos poucos, não começa no "play". A fase pode pedir
	# uma abertura mais lenta (o despertar) ao receber level_loaded.
	open_ears(2.5)
	Events.level_loaded.emit(current_level)


## O som chega ao ouvido aos poucos: começa baixo e abafado (`from_db`, `from_hz`) e
## abre em `duration` segundos. O volume sobe primeiro; os agudos chegam por último,
## como ouvidos que despertam.
func open_ears(duration: float, from_db := -30.0, from_hz := 300.0) -> void:
	if _ear_tween != null:
		_ear_tween.kill()
	AudioServer.set_bus_volume_db(0, from_db)
	_ear_filter.cutoff_hz = from_hz
	_ear_tween = create_tween().set_parallel()
	_ear_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(0, db), from_db, 0.0, duration) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ear_tween.tween_property(_ear_filter, ^"cutoff_hz", 20500.0, duration * 1.2) 		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


## O contrário de open_ears: o som some e abafa, como quem pega no sono.
func close_ears(duration: float, to_db := -42.0, to_hz := 160.0) -> void:
	if _ear_tween != null:
		_ear_tween.kill()
	_ear_tween = create_tween().set_parallel()
	_ear_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(0, db), AudioServer.get_bus_volume_db(0), to_db, duration) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ear_tween.tween_property(_ear_filter, ^"cutoff_hz", to_hz, duration * 0.8) 		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Dormir e morrer passam pela mesma sequência: a tela escurece, o som fecha, o tempo
## pula para a manhã e o goblin acorda na pele da caverna. `reason`: "sleep" ou "death".
## Quem precisa reagir escuta Events.slept, Events.woke_up e Clock.skipped.
func pass_out(reason: StringName) -> void:
	if resting or player == null:
		return
	resting = true
	player.set_controls_enabled(false)
	var fade := Tuning.DEATH_FADE if reason == &"death" else Tuning.SLEEP_FADE
	Events.screen_fade_requested.emit(1.0, fade)
	close_ears(fade)
	await get_tree().create_timer(fade + Tuning.DARK_HOLD, false).timeout
	if player == null or not resting:
		return

	Clock.sleep_until_morning()
	if reason == &"death":
		Vitals.revive()
		var lost := 0
		for food: StringName in Tuning.FOOD_PREFERENCE:
			lost += Inventory.count(food)
			Inventory.remove(food, Inventory.count(food))
		Events.notification_shown.emit("Acordou na toca." + (" A carne se perdeu." if lost > 0 else ""))
	else:
		Vitals.rest()
		Events.slept.emit()
	player.respawn()
	resting = false
	Events.screen_fade_requested.emit(0.0, 5.0)
	open_ears(7.5, -42.0, 160.0)
	player.wake_up()
	Events.woke_up.emit(reason)
	if reason == &"sleep":
		SaveSystem.save_game()


## A Reciclagem (§3): a floresta se desmancha em pixels da borda para o centro, o som
## afina até sobrar o bipe, e Ari acorda no dia 1: o Story avança o ciclo, o inventário
## zera, o corpo volta novo e a fase é recarregada (o arco volta para o chão da caverna).
func recycle(reason: StringName) -> void:
	if resting or player == null:
		return
	resting = true
	player.set_controls_enabled(false)
	var layer := CanvasLayer.new()
	layer.layer = 20
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = RECYCLE_SHADER
	overlay.material = material
	layer.add_child(overlay)
	add_child(layer)
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter(&"progress", value), 0.0, 1.0, Tuning.RECYCLE_SECONDS) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	close_ears(Tuning.RECYCLE_SECONDS, -30.0, 1200.0)
	var beeps := Timer.new()
	beeps.wait_time = 60.0 / Tuning.CLUE_BEEP_BPM
	beeps.timeout.connect(_beep)
	add_child(beeps)
	beeps.start()
	_beep()
	await get_tree().create_timer(Tuning.RECYCLE_SECONDS + 0.6, false).timeout
	beeps.queue_free()
	print("[Game] Reciclagem (%s): ciclo %d -> %d." % [reason, Story.cycle, Story.cycle + 1])
	Story.recycle()
	Inventory.clear()
	Vitals.reset()
	Clock.day = 1
	Clock.hour = Tuning.START_HOUR
	Clock.hours_awake = 0.0
	Events.screen_fade_requested.emit(1.0, 0.0)
	layer.queue_free()
	change_level(FIRST_LEVEL)
	if DevTools.skip_intro:
		Events.screen_fade_requested.emit(0.0, 1.0)
	await get_tree().process_frame
	SaveSystem.save_game()


func _beep() -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = BEEP
	sound.bus = &"World"
	sound.volume_db = -6.0
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	Events.game_paused.emit(paused)


func quit() -> void:
	get_tree().quit()


func _spawn_player() -> void:
	player = null
	var spawn := current_level.get_node_or_null(^"PlayerSpawn") as Node3D
	if spawn == null:
		return
	player = PLAYER_SCENE.instantiate() as Player
	player.transform = spawn.transform
	current_level.add_child(player)
