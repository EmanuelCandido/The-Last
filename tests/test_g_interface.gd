extends RefCounted
## O que faltava do plano de combate, interface (experimental): a prática de luta (aparo mais largo,
## golpe mais leve), a trava de alvo, a arma na mão no HUD e o bestiário nas Dicas.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand
var _melee: MeleeAbility


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	_melee = Game.player.get_node("MeleeAbility") as MeleeAbility
	for case: String in ["practice", "lock", "hud", "bestiary"]:
		print("[T] --- %s" % case)
		for orc in _band.get_children():
			orc.queue_free()
		Inventory.clear()
		Vitals.reset()
		await _wait(0.2)
		await call("_" + case)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _practice() -> void:
	var parry := Game.player.parry_bonus
	var swing := Game.player.swing_stamina
	for i in 30:
		Events.guard_held.emit(&"blocked")
		Events.melee_hit.emit(&"orc")
	_check(Game.player.parry_bonus > parry, "defender ensina: o aparo fica mais largo (%.2f)" % Game.player.parry_bonus)
	_check(Game.player.swing_stamina < swing, "golpear ensina: o golpe cansa menos (%.2f)" % Game.player.swing_stamina)
	_check(Game.player.parry_bonus <= Tuning.PRACTICE_PARRY_MAX, "até um limite")
	_check(Story.count(&"guards_held") >= 30 and Story.count(&"melee_hits") >= 30, "a prática fica no Story (vai no save)")


func _lock() -> void:
	_put(Vector3(30.0, 0.0, -3.0))
	var orc := _band.spawn(&"scout", Vector3(30.0, 0.0, -9.0))
	orc.route = []
	await _wait(0.3)
	orc.set_physics_process(false)
	Game.player.set_camera_angles(0.0, -10.0)
	await _wait(0.1)
	var event := InputEventAction.new()
	event.action = "lock_on"
	event.pressed = true
	Input.parse_input_event(event)
	await _wait(0.1)
	_check(_melee.locked == orc, "a trava pega o orc na frente da câmera")
	# Ele anda para o lado: a câmera vai atrás.
	orc.global_position = Vector3(36.0, _level.ground_height(36.0, -6.0), -6.0)
	await _wait(1.2)
	var to := orc.global_position - Game.player.global_position
	to.y = 0.0
	var aim := Game.player.aim_direction()
	aim.y = 0.0
	_check(rad_to_deg(aim.normalized().angle_to(to.normalized())) < 15.0, "a câmera segue o alvo travado")
	orc.strike(99.0, &"cut", orc.global_position + Vector3.UP, Vector3.FORWARD, 0.0)
	await _wait(0.2)
	_check(_melee.locked == null, "o alvo morreu: a trava solta")


func _hud() -> void:
	var hud := _tree.root.find_child("HUD", true, false)
	Inventory.add(&"club")
	Inventory.hold(&"club")
	await _wait(0.1)
	var texts := _labels(hud)
	_check(texts.any(func(t: String) -> bool: return t.begins_with("Porrete")), "o HUD mostra a arma na mão")
	Inventory.wear_down(&"club", 0.85)
	await _wait(0.1)
	texts = _labels(hud)
	_check(texts.any(func(t: String) -> bool: return "rachando" in t), "gasta, aparece rachando")


func _bestiary() -> void:
	var pause := _tree.root.find_child("PauseMenu", true, false)
	_check(pause != null, "o menu de pausa existe")
	if pause == null:
		return
	Story.set_flag(&"bestiary_orc_archer")
	var text: String = pause._tips_with_notes()
	_check("BESTIÁRIO" in text and "O arqueiro" in text, "o bestiário mostra o que o goblin encontrou")
	_check(not "O grande da Pedra Rachada" in text or Story.has_flag(&"bestiary_orc_chief"), "e só isso")


func _labels(root: Node) -> Array[String]:
	var found: Array[String] = []
	for node in root.find_children("*", "Label", true, false):
		found.append((node as Label).text)
	return found


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
