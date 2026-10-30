extends RefCounted
## F14, a segunda leitura (docs/plano_combate.md §2 e §11, experimental): a luta agita Ari (a
## Vigilância sobe com a luta, a luta vista por corvo, a luta pesada e o chefe; a Investida ganha
## acalma), a luta pesada encurta a próxima visita ao Abrigo, as anotações de Ari sobre os orcs, as
## falas novas da conversa e os modos sem orcs (Bem-vindo de volta, depois de Ficar).

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	for case: String in ["vigilance", "hurt", "notes", "modes"]:
		print("[T] --- %s" % case)
		_reset()
		await _wait(0.2)
		await call("_" + case)
	_reset()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _vigilance() -> void:
	Story.act = 1
	Story.vigilance = 0.0
	_put(Vector3(30.0, 0.0, -3.0))
	var calm := _band.spawn(&"scout", Vector3(30.0, 0.0, 0.0))
	await _wait(0.2)
	calm.alert(Game.player.global_position)
	_check(Story.vigilance == 0.0, "no Ato I a luta não conta (a Vigilância ainda não existe)")
	_reset()
	Story.set_act(2)
	Story.vigilance = 20.0
	_band._fight_clock = -999.0
	_put(Vector3(30.0, 0.0, -3.0))
	var orc := _band.spawn(&"scout", Vector3(30.0, 0.0, 0.0))
	await _wait(0.2)
	orc.alert(Game.player.global_position)
	_check(Story.vigilance >= 20.0 + Tuning.VIGILANCE_FIGHT - 0.01, "começar uma luta agita Ari (%.0f)" % Story.vigilance)
	var after := Story.vigilance
	var other := _band.spawn(&"scout", Vector3(33.0, 0.0, 0.0))
	await _wait(0.2)
	other.alert(Game.player.global_position)
	_check(Story.vigilance == after, "a segunda luta logo depois não soma de novo")
	var chief := _band.spawn(&"chief", Vector3(36.0, 0.0, 0.0))
	await _wait(0.2)
	var before := Story.vigilance
	chief.strike(99.0, &"blunt", chief.global_position + Vector3.UP * 1.3, Vector3.FORWARD, 0.0)
	_check(Story.vigilance >= before + Tuning.VIGILANCE_CHIEF - 0.01, "matar o chefe agita (%.0f → %.0f)" % [before, Story.vigilance])
	Story.set_flag(&"chief_dead", false)
	before = Story.vigilance
	_band.raid_active = true
	_band._raid_size = 2
	_band.end_raid([])
	_check(Story.vigilance <= before + Tuning.VIGILANCE_RAID_WON + 0.01, "ganhar a Investida acalma (%.0f → %.0f)" % [before, Story.vigilance])


func _hurt() -> void:
	Story.set_act(2)
	Story.vigilance = 20.0
	_put(Vector3(30.0, 0.0, -3.0))
	await _wait(0.2)
	var normal := Visit.lucidity_seconds(&"ritual")
	var from := Game.player.global_position + Game.player.facing()
	for i in 3:
		Game.player.receive_attack({"damage": 15.0, "kind": &"blunt", "from": from, "poise": 0.0, "cause": &"orc"})
	_check(Story.has_flag(&"hard_fight_today"), "mais de %d de vida numa luta: luta pesada" % int(Tuning.FIGHT_HURT_LIMIT))
	_check(Story.vigilance >= 20.0 + Tuning.VIGILANCE_FIGHT_HURT - 0.01, "a luta pesada agita Ari (%.0f)" % Story.vigilance)
	_check(Visit.lucidity_seconds(&"ritual") < normal, "a próxima visita tem menos lucidez (%.0f → %.0f)" % [normal, Visit.lucidity_seconds(&"ritual")])
	Story.trigger(&"slept")
	_check(not Story.has_flag(&"hard_fight_today"), "dormindo, passa")


func _notes() -> void:
	_put(Vector3(30.0, 0.0, -3.0))
	var orc := _band.spawn(&"scout", Vector3(30.0, 0.0, 0.0))
	await _wait(0.2)
	orc.alert(Game.player.global_position)
	# O beat dispara uma vez só (pode já ter saído no caso anterior): a anotação está na lista.
	_check(Array(Story.notes).any(func(note: String) -> bool: return "maior que eu" in note), "anotação: o primeiro orc")
	orc.strike(99.0, &"cut", orc.global_position + Vector3.UP, Vector3.FORWARD, 0.0)
	_check("borracha" in Story.notes[Story.notes.size() - 1], "anotação: o cheiro de borracha")
	Story.trigger(&"shelter", &"recordings")
	_check(Story.has_flag(&"confession_orcs"), "quem matou orcs ouve das máscaras na conversa")
	_check(StoryBeats.LINES.has(&"confession_orcs_1") and StoryBeats.LINES.has(&"confession_orcs_2"), "as falas existem")


func _modes() -> void:
	_band.spawn(&"scout", Vector3(30.0, 0.0, 0.0))
	await _wait(0.2)
	Game.welcome = true
	await _wait(0.2)
	_check(_band.get_child_count() == 0 and not _band.enabled(), "no Bem-vindo de volta não há orcs")
	Game.welcome = false
	_band.spawn(&"scout", Vector3(30.0, 0.0, 0.0))
	await _wait(0.2)
	Story.set_flag(&"ending_stay")
	await _wait(0.2)
	_check(_band.get_child_count() == 0, "depois de Ficar, os orcs somem")
	Story.set_flag(&"ending_stay", false)


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	for orc in _band.get_children():
		orc.queue_free()
	Game.welcome = false
	Inventory.clear()
	Vitals.reset()
	Clock.hour = 10.0


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
