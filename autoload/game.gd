extends Node
## Estado global da partida: fase atual, jogador, pausa, captura do mouse, o ouvido, a
## passagem da noite (dormir e morrer), os flashes, a ida e volta ao mundo real (o Abrigo) e as
## cenas do mistério meta (o falso travamento e a memória do ciclo 346).

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
## Ari acordado no Abrigo (§6): a floresta, o relógio e o corpo ficam parados.
var awake := false
## Passando uma cena do mistério (o travamento, a memória): sem pausa e sem HUD do goblin.
var cutscene := false
## O Abrigo 9, montado na primeira vez que é preciso (get_shelter).
var shelter: Shelter
## A visão borrada de Ari (flashes e o despertar na cápsula).
var vision: BlurredVision

## O ouvido: um passa-baixa no Master que abre junto com o volume (ver open_ears).
var _ear_filter := AudioEffectLowPassFilter.new()
var _ear_tween: Tween
## Flash pedido por um beat, mostrado no escuro do sono ou da morte (-1 = nenhum).
var _pending_flash := -1
var _flash_director: FlashDirector
## A câmera da floresta, para voltar a ela depois da visita.
var _forest_camera: Camera3D
## De onde veio esta visita: "ritual" ou "death" (depois de morrer, a lucidez é curta).
var _visit_from := &"ritual"
## A visita está acabando (deitando na cápsula, desmaiando ou sedado): nada mais a encerra.
var _leaving := false
## Reciclagem pedida no meio do sono ou da visita: acontece logo que o goblin acorda.
var _pending_recycle := &""
## Um beat pediu o falso travamento: o próximo despertar no Abrigo começa por ele.
var _pending_freeze := false


func _ready() -> void:
	# Precisa receber input mesmo pausado, para conseguir despausar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ear_filter.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(0, _ear_filter)
	Events.player_died.connect(func(_cause: StringName) -> void: pass_out(&"death"))
	Events.recycle_requested.connect(recycle)
	vision = BlurredVision.new()
	vision.name = "BlurredVision"
	add_child(vision)
	Events.flash_requested.connect(func(number: int) -> void: _pending_flash = number)
	Events.real_wake_requested.connect(wake_in_shelter)
	Events.fake_freeze_requested.connect(func() -> void: _pending_freeze = true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not cutscene:
			set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		# Recaptura o mouse se o jogador clicar na janela depois de soltar o cursor.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Troca a fase atual e cria o jogador no Marker3D "PlayerSpawn" da nova fase.
func change_level(path: String) -> void:
	assert(level_root != null, "Game.level_root precisa ser definido antes de trocar de fase.")
	if awake:
		return_to_forest(true)
	_pending_flash = -1
	_pending_recycle = &""
	_pending_freeze = false
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
	if resting or awake or player == null:
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
		# Do Ato III em diante a morte acorda Ari de verdade: uma visita curta (§4), e o
		# goblin volta na pele da caverna.
		if Story.act >= Tuning.DEATH_VISIT_ACT:
			_pending_flash = -1
			player.respawn()
			resting = false
			_visit_from = &"death"
			wake_in_shelter()
			return
		Events.notification_shown.emit("Acordou na toca." + (" A carne se perdeu." if lost > 0 else ""))
	else:
		Vitals.rest()
		Events.slept.emit()
	# Um beat pediu um flash (ao dormir no Ato II, ou ao morrer): passa no escuro.
	if _pending_flash >= 0:
		var number := _pending_flash
		_pending_flash = -1
		await play_flash(number, reason == &"death")
		if player == null or not resting:
			return
	player.respawn()
	resting = false
	Events.screen_fade_requested.emit(0.0, 5.0)
	open_ears(7.5, -42.0, 160.0)
	player.wake_up()
	Events.woke_up.emit(reason)
	if reason == &"sleep":
		SaveSystem.save_game()
	_recycle_if_pending()


## A Reciclagem (§3): a floresta se desmancha em pixels da borda para o centro, o som
## afina até sobrar o bipe, e Ari acorda no dia 1: o Story avança o ciclo, o inventário
## zera, o corpo volta novo e a fase é recarregada (o arco volta para o chão da caverna).
func recycle(reason: StringName) -> void:
	if player == null:
		return
	if resting or awake:
		_pending_recycle = reason
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


## O Abrigo, montado na primeira vez (no mesmo mundo, 2 km abaixo da floresta).
func get_shelter() -> Shelter:
	if shelter == null:
		shelter = Shelter.new()
		shelter.name = "Shelter"
		add_child(shelter)
		shelter.fainted.connect(faint_in_shelter)
	return shelter


## Mostra um flash do mundo real (§7) com a tela já escura (e a deixa escura no fim).
## `number` 0 = sorteado entre os já vistos; `short` = a versão curta (morte).
func play_flash(number: int, short := false) -> void:
	if number == 0:
		var seen: Array[int] = []
		for flash: int in Tuning.FLASH_SECONDS:
			if Story.has_flag(StringName("flash_%d_seen" % flash)):
				seen.append(flash)
		if seen.is_empty():
			return
		number = seen.pick_random()
	var seconds: float = Tuning.DEATH_FLASH_SECONDS if short else Tuning.FLASH_SECONDS.get(number, 6.0)
	if _flash_director == null:
		_flash_director = FlashDirector.new()
		_flash_director.name = "Flashes"
		_flash_director.shelter = get_shelter()
		_flash_director.vision = vision
		add_child(_flash_director)
	print("[Game] Flash %d (%.1f s)." % [number, seconds])
	await _flash_director.play(number, seconds)
	Story.set_flag(StringName("flash_%d_seen" % number))


## Um flash do mundo real está passando agora.
func in_flash() -> bool:
	return _flash_director != null and _flash_director.is_playing()


## Ari acorda no mundo real (§6): a tela escurece, a floresta para (processamento e sons) e
## Ari abre os olhos na cápsula. `instant` = sem cenas, já de pé (DevTools e testes).
func wake_in_shelter(instant := false) -> void:
	if awake or resting or player == null:
		return
	awake = true
	_leaving = false
	player.set_controls_enabled(false)
	if not instant and _pending_freeze:
		# A primeira vez (fim do Ato II): o jogo "trava" e a volta já é o Abrigo.
		_pending_freeze = false
		await _fake_freeze()
	elif not instant:
		Events.screen_fade_requested.emit(1.0, 2.0)
		close_ears(2.0)
		await get_tree().create_timer(2.6, false).timeout
	var place := get_shelter()
	_forest_camera = get_viewport().get_camera_3d()
	_set_forest_active(false)
	place.set_active(true)
	var ari := place.spawn_ari()
	ari.camera.make_current()
	var seconds := Visit.lucidity_seconds(_visit_from)
	_visit_from = &"ritual"
	place.begin_visit(seconds)
	Events.prompt_changed.emit("")
	Events.shelter_entered.emit()
	print("[Game] Ari acordou no Abrigo (%.0f s de lucidez)." % seconds)
	if instant:
		Events.screen_fade_requested.emit(0.0, 0.0)
		open_ears(0.5)
		ari.stand_ready(place.room_door())
		return
	Events.screen_fade_requested.emit(0.0, 1.5)
	open_ears(5.0, -30.0, 400.0)
	await ari.wake_in(place.capsule, place.room_door())


## O falso travamento (§7): termina com a tela preta, como se o jogo tivesse fechado.
func _fake_freeze() -> void:
	cutscene = true
	var freeze := FakeFreeze.new()
	freeze.name = "FakeFreeze"
	add_child(freeze)
	await freeze.play()
	Events.screen_fade_requested.emit(1.0, 0.0)
	freeze.queue_free()
	cutscene = false


## A memória do ciclo 346 (§7): "carregar" o ciclo_346.sav. Passa na floresta de verdade, com o
## estado guardado antes e devolvido no fim (SaveSystem.snapshot); depois o jogo volta para o
## menu de pausa.
func play_memory() -> void:
	if cutscene or resting or player == null:
		return
	if awake:
		return_to_forest(true)
	var saved := SaveSystem.snapshot()
	cutscene = true
	resting = true
	player.set_controls_enabled(false)
	Events.prompt_changed.emit("")
	Events.screen_fade_requested.emit(1.0, 0.8)
	close_ears(0.8)
	await get_tree().create_timer(1.0, false).timeout
	print("[Game] Memória do ciclo 346.")
	var memory := Memory346.new()
	memory.name = "Memory346"
	current_level.add_child(memory)
	open_ears(2.0, -24.0, 900.0)
	await memory.play()
	memory.queue_free()
	SaveSystem.restore(saved)
	resting = false
	cutscene = false
	Story.trigger(&"memory", &"346")
	player.set_controls_enabled(true)
	open_ears(1.0)
	Events.screen_fade_requested.emit(0.0, 1.0)
	set_paused(true)


## Ari deita de volta na cápsula (§6.2: voltar antes de a lucidez acabar não custa nada) e o
## goblin acorda onde estava. Os objetivos feitos nesta visita só valem agora.
## `instant` = sem cenas e sem guardar nada (carregar um save acordado).
func return_to_forest(instant := false) -> void:
	if not awake or shelter == null or shelter.ari == null or (_leaving and not instant):
		return
	_leaving = true
	var ari := shelter.ari
	shelter.hold_visit()
	if not instant:
		await ari.lie_down_in(shelter.capsule)
		Events.screen_fade_requested.emit(1.0, 1.2)
		close_ears(1.2)
		await get_tree().create_timer(1.6, false).timeout
	var done := shelter.end_visit(not instant)
	_leave_shelter()
	print("[Game] Ari deitou na cápsula e voltou para a floresta.")
	for objective in done:
		print("[Game] Objetivo concluído: %s." % objective)
		Story.complete_objective(objective)
	# Deitado no sarcófago, continua deitado (Espaço levanta); senão, o controle volta.
	if player != null and not player.lying:
		player.set_controls_enabled(true)
	if instant:
		Events.screen_fade_requested.emit(0.0, 0.0)
		return
	Events.screen_fade_requested.emit(0.0, 3.0)
	open_ears(4.0, -36.0, 220.0)
	_recycle_if_pending()


## Ari apagou no Abrigo: a lucidez acabou (`reason` "fainted") ou o Zelador o sedou
## ("captured"). O que foi feito nesta visita se perde (o Zelador conserta enquanto Ari dorme),
## a Vigilância sobe e o goblin acorda na pele da caverna.
func faint_in_shelter(reason: StringName) -> void:
	if not awake or _leaving or shelter == null or shelter.ari == null:
		return
	_leaving = true
	shelter.hold_visit()
	shelter.ari.controls = false
	var captured := reason == &"captured"
	var fade := 0.5 if captured else 2.5
	if not captured:
		create_tween().tween_property(vision, ^"lids", 1.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	Events.screen_fade_requested.emit(1.0, fade)
	close_ears(fade)
	await get_tree().create_timer(fade + Tuning.DARK_HOLD, false).timeout
	shelter.end_visit(false)
	_leave_shelter()
	Story.add_vigilance(Tuning.VIGILANCE_CAPTURED if captured else Tuning.VIGILANCE_FAINT)
	print("[Game] Ari apagou no Abrigo (%s)." % reason)
	if player != null:
		if player.lying:
			player.lying = false
			player.ritual_place = &""
		player.respawn()
		player.wake_up()
	Events.screen_fade_requested.emit(0.0, 5.0)
	open_ears(7.5, -42.0, 160.0)
	_recycle_if_pending()


## Uma Reciclagem pedida enquanto o goblin dormia ou Ari estava acordado acontece agora.
func _recycle_if_pending() -> void:
	if _pending_recycle == &"":
		return
	var reason := _pending_recycle
	_pending_recycle = &""
	recycle(reason)


## Desmonta a visita e devolve a floresta (a câmera, os sons e o processamento).
func _leave_shelter() -> void:
	shelter.remove_ari()
	shelter.set_active(false)
	vision.clear()
	_set_forest_active(true)
	if is_instance_valid(_forest_camera):
		_forest_camera.make_current()
	awake = false
	_leaving = false
	Events.prompt_changed.emit("")
	Events.shelter_left.emit()


## Liga ou para a floresta inteira (o processamento e os sons de fora e do mundo).
func _set_forest_active(active: bool) -> void:
	if current_level != null:
		current_level.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for bus: StringName in [&"Ambience", &"World"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), not active)


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
