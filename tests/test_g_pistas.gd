extends RefCounted
## O que faltava do plano de combate, som e pistas (experimental): o tambor do acampamento, batido
## por um orc de verdade no ritmo do coração de Ari, e a língua dos orcs (o rádio ao contrário).

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _band: OrcBand
var _camp: OrcCamp


func run() -> void:
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	_camp = _tree.get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	# O goblin longe do acampamento: os orcs ficam calmos.
	_put(Vector3(ForestLayout.SPAWN.x, 0.0, ForestLayout.SPAWN.y))
	for case: String in ["drum", "talk"]:
		print("[T] --- %s" % case)
		for orc in _band.get_children():
			orc.queue_free()
		await _wait(0.3)
		await call("_" + case)
	Story.set_flag(&"raid_tonight", false)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _drum() -> void:
	_check(_camp.drummer() == null, "sem orc, o tambor fica quieto")
	var stand := _camp.to_global(_camp._drum_stand)
	var orc := _band.spawn(&"scout", stand + Vector3(1.5, 0.0, 0.0))
	await _wait(1.5)
	_check(_camp.drummer() == orc, "o orc perto do tambor vira o tocador")
	await _until(func() -> bool: return orc._animator._action == &"drum", 8.0)
	_check(orc._animator._action == &"drum", "ele chega ao tambor e bate")
	_check(Vector2(orc.global_position.x - stand.x, orc.global_position.z - stand.z).length() < 0.8, "parado no lugar do tocador")
	_check(absf(orc._animator.drum_period - 60.0 / Tuning.SHELTER_BPM) < 0.01, "no ritmo do coração de Ari (%.2f s)" % orc._animator.drum_period)
	await _wait(GoblinActions.DRUM_LEAD + orc._animator.drum_period * 2.0 + 0.1)
	_check(orc._drum_hits >= 4, "dois baques por batida (%d baques)" % orc._drum_hits)
	# Noite da Investida: o tambor acelera e não para.
	Story.set_flag(&"raid_tonight", true)
	await _wait(1.2)
	_check(orc.drum_bpm == Tuning.ORC_DRUM_RAID_BPM and orc.drum_rest == 0.0, "na Investida, mais rápido e sem descanso")
	Story.set_flag(&"raid_tonight", false)
	# Um barulho de luta: larga o tambor.
	orc.alert(orc.global_position + Vector3(6.0, 0.0, 0.0))
	await _wait(0.2)
	_check(orc._animator._action != &"drum", "chamado para a luta, as mãos saem do tambor")
	orc.queue_free()
	await _wait(1.2)
	_check(_camp.drummer() == null, "o tocador sumiu: o tambor para")


func _talk() -> void:
	var at := Vector3(ForestLayout.SPAWN.x + 30.0, 0.0, ForestLayout.SPAWN.y + 20.0)
	var a := _band.spawn(&"scout", at)
	var b := _band.spawn(&"warrior", at + Vector3(3.0, 0.0, 1.0))
	await _wait(0.4)
	_band._talk_wait = 0.0
	await _wait(0.2)
	var speaker := a if a._voice.playing else b
	var listener := b if speaker == a else a
	_check(speaker._voice.playing and speaker._voice.stream in Orc.TALK, "um orc fala na língua deles")
	await _until(func() -> bool: return listener._voice.playing, 5.0)
	_check(listener._voice.playing and listener._voice.stream in Orc.TALK, "o outro responde quando ele termina")
	# Longe um do outro, ninguém puxa conversa.
	# (Sem placa de som, no modo headless, o som nunca termina: as vozes param à mão.)
	var far := at + Vector3(30.0, 0.0, 0.0)
	b.global_position = Vector3(far.x, Game.current_level.ground_height(far.x, far.z) + 0.1, far.z)
	a._voice.stop()
	b._voice.stop()
	_band._talk_wait = 0.0
	await _wait(0.2)
	_check(not _talking(a) and not _talking(b), "sozinho, o orc fica calado")


func _talking(orc: Orc) -> bool:
	return orc._voice.playing and orc._voice.stream in Orc.TALK


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
