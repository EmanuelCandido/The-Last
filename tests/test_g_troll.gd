extends RefCounted
## O troll da ponte caída (F14, experimental): dorme de dia, anda de noite, pega o goblin sem ferir e o
## larga na boca da toca (com a Vigilância mais alta), não entra na toca, dorme com a bateria do
## Zelador baixa e some com `ameaca off`.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _bridge: TrollBridge
var _troll: Troll


func run() -> void:
	_bridge = _tree.get_first_node_in_group(TrollBridge.GROUP) as TrollBridge
	_check(_bridge != null, "a ponte caída existe")
	if _bridge == null:
		print("[T] FIM: 1 FALHA(S)")
		return
	_check(not is_instance_valid(_bridge.troll), "nos testes sem --orcs, o troll não aparece sozinho")
	Story.act = 2
	Story.vigilance = 20.0
	_troll = _bridge.spawn_troll()
	for case: String in ["day_night", "grab", "cave", "battery", "off"]:
		print("[T] --- %s" % case)
		await call("_" + case)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _day_night() -> void:
	Clock.hour = 12.0
	await _wait(1.0)
	_check(_troll.state == Troll.State.SLEEP, "de dia dorme na ponte")
	_check(_troll.global_position.distance_to(_bridge.global_position) < 6.0, "perto dos troncos")
	_check(_troll._eye.light_energy < 0.5, "o olho quase apagado")
	Clock.hour = 23.0
	await _wait(1.5)
	_check(_troll.state == Troll.State.WANDER, "de noite sai para a ronda (estado %d)" % _troll.state)
	_check(_troll._eye.light_energy > 0.6, "o olho verde aceso (%.2f)" % _troll._eye.light_energy)


func _grab() -> void:
	var health := Vitals.health
	var vigilance := Story.vigilance
	var hour := Clock.hour
	_put(_troll.global_position + Vector3(3.0, 0.0, 0.0))
	_troll.awareness = 1.2
	await _until(func() -> bool: return _troll.state == Troll.State.CARRY, 6.0)
	_check(_troll.state == Troll.State.CARRY, "ouviu, veio e pegou o goblin")
	_check(not Game.player.controls_on(), "pego, o goblin não se mexe")
	await _wait(2.2)
	var mouth := Vector2(ForestLayout.CAVE_CENTER.x, ForestLayout.CAVE_CENTER.y - ForestLayout.CAVE_DEPTH * 0.5)
	var at := Vector2(Game.player.global_position.x, Game.player.global_position.z)
	_check(at.distance_to(mouth) < 4.0, "acordou na boca da toca (%.1f m)" % at.distance_to(mouth))
	_check(Vitals.health == health, "sem ferida nenhuma")
	_check(is_equal_approx(Story.vigilance, vigilance + Tuning.VIGILANCE_TROLL), "a Vigilância subiu (%.0f -> %.0f)" % [vigilance, Story.vigilance])
	_check(absf(fposmod(Clock.hour - hour, 24.0) - Tuning.TROLL_CARRY_HOURS) < 0.2, "passaram as horas desacordado")
	_check(Story.has_flag(&"bestiary_troll"), "a página do bestiário")
	_check("olho verde" in "\n".join(Story.notes), "a anotação de Ari")
	# Ainda é madrugada: de volta à ponte, ele segue a ronda.
	_check(_troll.global_position.distance_to(_troll.home) < 3.0 and _troll.awareness == 0.0, "ele volta para a ponte, calmo")
	var pause := _tree.root.find_child("PauseMenu", true, false)
	if pause != null:
		var text: String = pause._tips_with_notes()
		_check("O da ponte caída" in text, "o troll entra nas Dicas")
	await _until(func() -> bool: return Game.player.controls_on(), 8.0)


func _cave() -> void:
	# Correndo para a toca: ele para na boca e desiste.
	Clock.hour = 23.0
	_troll.global_position = Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y - ForestLayout.CAVE_DEPTH * 0.5 - 10.0)
	_troll.global_position.y = Game.current_level.ground_height(_troll.global_position.x, _troll.global_position.z) + 0.2
	_put(Vector3(ForestLayout.SPAWN.x, 0.0, ForestLayout.SPAWN.y))
	_troll.state = Troll.State.HUNT
	_troll.awareness = 1.2
	await _wait(0.5)
	_check(_troll.state == Troll.State.WANDER, "o goblin está na toca: ele desiste (estado %d)" % _troll.state)
	_check(Game.player.controls_on(), "e não pega")


func _battery() -> void:
	_troll.global_position = _troll.home + Vector3.UP * 0.2
	_troll.state = Troll.State.SLEEP
	_troll.awareness = 0.0
	_put(Vector3(ForestLayout.SPAWN.x, 0.0, ForestLayout.SPAWN.y))
	Story.set_flag(&"climate_cut")
	Clock.hour = 23.0
	await _wait(1.0)
	_check(_troll.low_battery() and _troll.state == Troll.State.SLEEP, "bateria baixa (R3 sem o R4): de noite ele continua dormindo")
	Story.set_flag(&"access_card")
	await _wait(1.0)
	_check(_troll.state == Troll.State.WANDER, "com o cartão fora, ele volta a andar")
	Story.set_flag(&"climate_cut", false)
	Story.set_flag(&"access_card", false)


func _off() -> void:
	Story.set_flag(&"orcs_off")
	await _wait(0.3)
	_check(not is_instance_valid(_bridge.troll), "`ameaca off` tira o troll")
	Story.set_flag(&"orcs_off", false)


func _put(at: Vector3) -> void:
	var level := Game.current_level
	Game.player.global_position = Vector3(at.x, level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < timeout:
		await _wait(0.1)
		waited += 0.1


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
