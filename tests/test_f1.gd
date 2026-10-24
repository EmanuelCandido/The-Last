extends RefCounted
## Fase 1 de ponta a ponta: fogueira, assar, comer, dormir, riscos, musgo, morte e save.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	var player := Game.player
	var level := Game.current_level
	var fire: Node3D = level.find_child("Campfire", true, false)
	var pelt: Node3D = level.find_child("Pelt", true, false)
	_state("início")
	_check(Story.act == 1 and Story.marks == 0 and Clock.day == 1, "começa no Ato I, dia 1, sem riscos")

	# Comer sem comida: só o aviso.
	DevTools._press("eat")
	await _wait(0.5)

	# Fogueira: lenha e assar.
	Inventory.add(&"meat", 2)
	Inventory.add(&"wood", 2)
	_put_near(player, fire, 0.9)
	await _wait(0.3)
	print("[T] fogueira lenha=%.2f prompt='%s'" % [fire.fuel, fire.interaction_prompt()])
	_check(fire.interaction_prompt() == "Assar carne", "com carne e chama, o E assa")
	DevTools._press("interact")
	await _wait(Tuning.COOK_TIME + 0.5)
	_check(Inventory.count(&"cooked_meat") == 1 and Inventory.count(&"meat") == 1, "assou uma carne")
	Inventory.remove(&"meat")
	print("[T] prompt sem carne='%s'" % fire.interaction_prompt())
	var fuel_before: float = fire.fuel
	DevTools._press("interact")
	await _wait(Tuning.FEED_TIME + 0.3)
	_check(fire.fuel > fuel_before + 0.9 and Inventory.count(&"wood") == 1, "pôs lenha (%.2f -> %.2f)" % [fuel_before, fire.fuel])

	# Comer: assada primeiro.
	Vitals.satiety = 20.0
	DevTools._press("eat")
	await _wait(Tuning.EAT_TIME + 0.3)
	_check(Inventory.count(&"cooked_meat") == 0 and Vitals.satiety > 45.0, "comeu a assada (saciedade %.1f)" % Vitals.satiety)

	# Sono: de dia não dá; à noite deita, pula para a manhã, risco e save.
	_put_near(player, pelt, 0.3)
	await _wait(0.3)
	_check(pelt.interaction_prompt() == "", "de manhã, sem sono")
	Clock.hour = 19.0
	await _wait(0.2)
	_check(pelt.interaction_prompt() != "", "à noite a pele oferece dormir")
	var fuel_night: float = fire.fuel
	DevTools._press("interact")
	await _wait(0.5)
	_check(Game.resting, "dormindo")
	await _until_awake(0.0)
	_state("ao acordar")
	_check(Story.marks == 1 and Clock.day == 2 and absf(Clock.hour - Tuning.WAKE_HOUR) < 0.01, "1 risco, dia 2, 6h30")
	await _wait(6.2)
	_check(fire.fuel < fuel_night, "a lenha queimou de noite (%.2f -> %.2f)" % [fuel_night, fire.fuel])
	_check(SaveSystem.has_save(), "salvou ao dormir")

	# Mais 4 noites com um cervo coletado: o musgo cai no 5º risco (F10; antes era o 7º).
	Events.animal_harvested.emit(&"deer")
	for i in 4:
		Clock.hour = 20.0
		Game.pass_out(&"sleep")
		await _until_awake(6.2 if i < 3 else 0.0)
	_state("5 noites")
	_check(Story.marks == 5 and Story.has_flag(&"moss_fell") and Story.act == 2, "5º risco: musgo caiu, Ato II")
	var marks_node: Node = Game.current_level.find_child("WallMarks", true, false)
	_check(marks_node.get_node_or_null("Moss") != null, "o musgo ainda está na parede logo ao acordar")
	await _wait(WallMarks.MOSS_DELAY + 1.5)
	var marks: Node = level.find_child("WallMarks", true, false)
	_check(marks.get_node_or_null("Moss") != null, "o musgo está caindo (ainda na cena)")
	await _wait(5.0)
	_check(marks.get_node_or_null("Moss") == null, "o musgo sumiu")

	# Morte: acorda na toca sem a carne.
	Inventory.add(&"meat", 3)
	Vitals.damage(500.0, &"fall")
	await _wait(0.2)
	_check(Game.resting, "morreu: desmaiando")
	await _until_awake()
	_state("depois de morrer")
	_check(is_equal_approx(Vitals.health, Tuning.DEATH_HEALTH) and Inventory.count(&"meat") == 0, "voltou com 60 de vida e sem a carne")
	_check(Story.marks == 5, "morrer não faz risco")

	# Save e load preservam história, relógio e corpo.
	SaveSystem.save_game()
	var saved := [Story.marks, Story.act, Clock.day, Vitals.health, fire.fuel]
	Story.marks = 0
	Story.set_act(1)
	Clock.day = 99
	Vitals.health = 5.0
	fire.fuel = 0.0
	SaveSystem.load_game()
	var loaded := [Story.marks, Story.act, Clock.day, Vitals.health, fire.fuel]
	_check(str(saved) == str(loaded), "load devolve o estado %s == %s" % [saved, loaded])
	_check(Story.has_flag(&"moss_fell"), "load mantém o flag do musgo")

	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _until_awake(settle := 6.2) -> void:
	while Game.resting:
		await _tree.process_frame
	# Acordar leva ~5,8 s.
	if settle > 0.0:
		await _wait(settle)


func _put_near(player: Node3D, target: Node3D, distance: float) -> void:
	var at := target.global_position + Vector3(distance, 0.0, 0.0)
	player.global_position = Vector3(at.x, Game.current_level.ground_height(at.x, at.z) + 0.05, at.z)
	player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, false).timeout


func _state(label: String) -> void:
	print("[T] %s: ato=%d riscos=%d dia=%d hora=%.2f saciedade=%.1f vida=%.1f inv=%s" % [
		label, Story.act, Story.marks, Clock.day, Clock.hour, Vitals.satiety, Vitals.health, Inventory.items()])


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
