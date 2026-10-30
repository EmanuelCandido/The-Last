extends RefCounted
## F13, a guerra pela toca (docs/plano_combate.md §7.5, §9.3 e §5.5, experimental): o chefe (maior,
## martelo, investida que o deixa tonto num tronco, preso depois do golpe de cima, trompa pela
## metade, morto acaba a Investida), a Investida (trompa, não dorme, orcs com tocha que entram na
## toca, acaba de manhã ou com metade caída) e as armadilhas. --case=<nome> roda um só.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := ["chief", "charge", "stuck", "raid", "traps"]
	for case: String in cases:
		if only == "" or only == case:
			print("[T] --- %s" % case)
			_reset()
			await _wait(0.2)
			await call("_" + case)
	_reset()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _chief() -> void:
	var camp := _tree.get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	var chief := camp.spawn_chief(_band)
	await _wait(0.3)
	_check(chief.kind == &"chief" and chief.weapon_item == &"orc_hammer", "o chefe com o martelo")
	_check(chief.health == Tuning.ORC_HEALTH[&"chief"], "vida do chefe")
	var head := chief._animator.bone_position("cabeca")
	_check(head.y - chief.global_position.y > 1.4, "maior que os outros (pescoço a %.2f m)" % (head.y - chief.global_position.y))
	Clock.hour = Tuning.ORC_LEAVE_HOUR + 0.5
	await _wait(0.3)
	_check(chief.state != Orc.State.LEAVE, "o chefe mora no acampamento: não vai embora de noite")
	Clock.hour = 10.0
	# Pela metade, a trompa chama os outros.
	var guard := _band.spawn(&"scout", chief.global_position + Vector3(4.0, 0.0, 0.0))
	await _wait(0.2)
	chief.strike(7.0, &"blunt", chief.global_position + Vector3.UP * 1.3, Vector3.FORWARD, 0.0)
	_check(chief._horned and guard.state == Orc.State.COMBAT, "pela metade da vida, a trompa chama os outros")
	chief.strike(99.0, &"blunt", chief.global_position + Vector3.UP * 1.3, Vector3.FORWARD, 0.0)
	_check(chief.is_dead() and Story.has_flag(&"chief_dead"), "o chefe morto: flag chief_dead")
	await _wait(1.0)
	chief.interact(Game.player)
	_check(Inventory.has(&"orc_hammer") and Inventory.has(&"orc_helmet") and Inventory.has(&"orc_chest"), "deixa o martelo, o elmo e o peitoral")
	Story.set_flag(&"chief_dead", false)


func _charge() -> void:
	# A investida bate no goblin parado: fere e derruba.
	_put(Vector3(30.0, 0.0, -2.0))
	var chief := _band.spawn(&"chief", Vector3(30.0, 0.0, -9.0))
	await _wait(0.3)
	chief.alert(Game.player.global_position)
	await _until(func() -> bool: return chief._charging > 0.0, 3.0)
	_check(chief._charging > 0.0, "de longe, o chefe investe")
	await _until(func() -> bool: return Vitals.health < 100.0 or chief._charging <= 0.0, 3.0)
	_check(Vitals.health <= 100.0 - Tuning.ORC_CHIEF_CHARGE_DAMAGE + 0.1, "a investida fere (%.0f)" % Vitals.health)
	chief.queue_free()
	await _wait(0.3)
	Vitals.health = 100.0
	Vitals.bleeding = 0.0
	# Contra uma parede (a paliçada do acampamento): fica tonto.
	var camp := _tree.get_first_node_in_group(OrcCamp.GROUP) as OrcCamp
	var out := Vector3(camp.global_position.x, 0.0, camp.global_position.z).normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	var inside := camp.global_position + side * (OrcCamp.RADIUS - 3.5)
	var wall_dir := side
	var bull := _band.spawn(&"chief", inside)
	await _wait(0.4)
	bull._start_charge(wall_dir)
	await _until(func() -> bool: return bull.state == Orc.State.KNEEL or bull._charging <= 0.0, 3.0)
	_check(bull.state == Orc.State.KNEEL, "batendo na paliçada, fica tonto (%d)" % bull.state)


func _stuck() -> void:
	_put(Vector3(30.0, 0.0, -2.0))
	var chief := _band.spawn(&"chief", Vector3(30.0, 0.0, -3.6))
	await _wait(0.3)
	chief._attack_wait = 99.0
	chief._charge_wait = 99.0
	chief.state = Orc.State.COMBAT
	chief._start_attack(true)
	await _until(func() -> bool: return chief.state == Orc.State.KNEEL, 4.0)
	_check(chief.state == Orc.State.KNEEL, "o golpe de cima finca o martelo: fica preso")
	var head := chief._animator.bone_position("cabeca")
	_check(head.y - chief.global_position.y < 1.6, "curvado, a cabeça desce (%.2f m)" % (head.y - chief.global_position.y))


func _raid() -> void:
	Clock.day = Tuning.RAID_DAY
	Clock.hour = Tuning.RAID_WARN_HOUR + 0.5
	_band.warn_raid()
	_check(Story.has_flag(&"raid_tonight"), "a trompa: esta noite eles vêm")
	var pelt := _level.find_child("Pelt", true, false)
	_check(pelt != null and not pelt.interaction_enabled(), "não dá para dormir")
	_put(Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y + 1.0))
	Clock.hour = Tuning.RAID_START_HOUR + 0.2
	_band.start_raid()
	await _wait(0.3)
	_check(_band.raid_active and _band.orcs().size() >= Tuning.RAID_SIZE.x, "chegaram %d orcs" % _band.orcs().size())
	_check(_band.orcs().all(func(orc: Orc) -> bool: return orc.raider), "todos da Investida")
	_check(not _band.orcs()[0]._forbidden(Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y)), "na Investida, a toca não é proibida")
	_check(_band.orcs()[0].get_children().any(func(node: Node) -> bool: return node is OmniLight3D), "vêm com tocha")
	# Metade cai: os outros fogem e a Investida acaba.
	var raiders := _band.orcs()
	var to_kill := int(ceil(raiders.size() / 2.0))
	for i in to_kill:
		raiders[i].strike(99.0, &"cut", raiders[i].global_position + Vector3.UP, Vector3.FORWARD, 0.0)
	await _wait(0.3)
	_check(not _band.raid_active and not Story.has_flag(&"raid_tonight"), "metade caiu: a Investida acaba")
	_check(Story.count(&"raids_won") >= 1, "conta a Investida ganha")
	_check(pelt.interaction_enabled(), "e dá para dormir de novo")
	Clock.day = 1


func _traps() -> void:
	var traps := _tree.get_first_node_in_group(TrapField.GROUP) as TrapField
	var at := Vector3(30.0, _level.ground_height(30.0, 0.0), 0.0)
	_check(traps.build_at(&"stakes", at, 0.0), "estacas fincadas")
	_put(at + Vector3(-12.0, 0.0, 6.0))
	var orc := _band.spawn(&"scout", at + Vector3(-6.0, 0.0, 0.0))
	await _wait(0.2)
	# Fugindo (correndo) reto por cima das estacas; longe do fim, para não sumir antes.
	orc.route = []
	orc.state = Orc.State.FLEE
	orc._timer = 99.0
	orc._goal = at + Vector3(30.0, 0.0, 0.0)
	var health := orc.health
	await _until(func() -> bool: return not is_instance_valid(orc) or orc.health < health, 4.0)
	_check(is_instance_valid(orc) and orc.health < health and orc._limp > 0.0, "o orc correndo pisa nas estacas e manca")
	for i in Tuning.STAKES_MAX:
		traps.build_at(&"stakes", at + Vector3(0.0, 0.0, 3.0 + i), 0.0)
	_check(traps.traps.filter(func(t: Dictionary) -> bool: return t.kind == &"stakes").size() <= Tuning.STAKES_MAX, "no máximo %d estacas" % Tuning.STAKES_MAX)
	var saved := traps.save_data()
	traps.load_data({})
	_check(traps.traps.is_empty(), "limpou")
	traps.load_data(saved)
	_check(not traps.traps.is_empty(), "as armadilhas voltam do save")
	_check(traps.build_at(&"bones", at + Vector3(10.0, 0.0, 0.0), 0.0), "corda de ossos esticada")


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	for orc in _band.get_children():
		orc.queue_free()
	_band.raid_active = false
	Story.set_flag(&"raid_tonight", false)
	Inventory.clear()
	Vitals.reset()
	Clock.hour = 10.0
	Weather.stop_rain()
	Weather.rain = 0.0


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _until(condition: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not condition.call():
		await _wait(0.05)
		left -= 0.05


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
