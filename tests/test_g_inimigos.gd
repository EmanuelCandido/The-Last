extends RefCounted
## O que faltava do plano de combate, inimigos (experimental): o arqueiro orc (fica longe, puxa e
## atira; só o escudo segura a flecha), o lobo de guerra do chefe e o tronco armado.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _band: OrcBand
var _melee: MeleeAbility


func run() -> void:
	_level = Game.current_level
	_band = _tree.get_first_node_in_group(OrcBand.GROUP) as OrcBand
	_melee = Game.player.get_node("MeleeAbility") as MeleeAbility
	for case: String in ["archer", "arrows", "wolf", "log"]:
		print("[T] --- %s" % case)
		_reset()
		await _wait(0.2)
		await call("_" + case)
	_reset()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _archer() -> void:
	_put(Vector3(30.0, 0.0, -14.0))
	var archer := _band.spawn(&"archer", Vector3(30.0, 0.0, 0.0))
	await _wait(0.3)
	_check(archer._bow != null and archer.weapon_item == &"stone_knife", "o arqueiro tem o arco e uma faca")
	archer.alert(Game.player.global_position)
	await _until(func() -> bool: return archer._drawing > 0.0, 6.0)
	_check(archer._drawing > 0.0, "de longe, puxa a corda")
	var distance := Vector2(archer.global_position.x - Game.player.global_position.x, archer.global_position.z - Game.player.global_position.z).length()
	_check(distance > Tuning.ORC_ARCHER_RANGE.x - 1.0, "e fica longe (%.1f m)" % distance)
	await _until(func() -> bool: return Vitals.health < 100.0, 12.0)
	_check(Vitals.health < 100.0, "a flecha acerta o goblin parado (%.0f)" % Vitals.health)


func _arrows() -> void:
	# O escudo segura a flecha; a arma sozinha, não.
	_put(Vector3(30.0, 0.0, -3.0))
	await _wait(0.3)
	Inventory.add(&"club")
	Inventory.hold(&"club")
	Input.action_press("aim")
	await _wait(0.4)
	var dir := -Game.player.facing()
	Game.player.take_hit(0.8, Game.player.global_position + Vector3.UP * 0.5, dir, 1.0)
	var bare := 100.0 - Vitals.health
	_check(bare > 10.0, "defendendo com o porrete, a flecha passa (%.0f)" % bare)
	Vitals.health = 100.0
	Vitals.bleeding = 0.0
	Inventory.add(&"hide_shield")
	await _wait(0.2)
	Game.player.take_hit(0.8, Game.player.global_position + Vector3.UP * 0.5, dir, 1.0)
	var shielded := 100.0 - Vitals.health
	_check(shielded < bare * 0.3, "com o escudo, segura (%.1f)" % shielded)
	Input.action_release("aim")


func _wolf() -> void:
	Clock.day = Tuning.ORC_WAR_WOLF_DAY
	_put(Vector3(30.0, 0.0, -6.0))
	var chief := _band.spawn(&"chief", Vector3(30.0, 0.0, 0.0))
	await _wait(0.3)
	var wolves_before := _tree.get_nodes_in_group(&"animals").filter(func(n: Node) -> bool: return n is Wolf).size()
	chief.strike(7.0, &"blunt", chief.global_position + Vector3.UP * 1.3, Vector3.FORWARD, 0.0)
	await _wait(0.3)
	var wolves := _tree.get_nodes_in_group(&"animals").filter(func(n: Node) -> bool: return n is Wolf)
	_check(wolves.size() == wolves_before + 1, "pela metade, o chefe solta o lobo de guerra")
	if wolves.size() > wolves_before:
		var wolf: Wolf = wolves[wolves.size() - 1]
		_check(wolf.awareness > 1.0, "o lobo já vem caçando")
		wolf.queue_free()
	Clock.day = 1


func _log() -> void:
	var vegetation: Vegetation = _level._vegetation
	var dead := -1
	for i in vegetation.trees.size():
		var tree: Vegetation.TreeInfo = vegetation.trees[i]
		if tree.dead and not tree.fallen and Vector2(tree.base.x, tree.base.z).distance_to(ForestLayout.CAVE_CENTER) > 25.0:
			dead = i
			break
	_check(dead != -1, "há árvore seca")
	if dead == -1:
		return
	var base: Vector3 = vegetation.trees[dead].base
	_put(base + Vector3(1.0, 0.0, 0.6))
	await _wait(0.2)
	Inventory.add(&"sinew")
	var recipe: Dictionary = Recipes.LIST.filter(func(r: Dictionary) -> bool: return r.id == &"armed_log")[0]
	_check(Recipes.missing(recipe) == "", "perto de uma árvore seca dá para armar")
	(Game.player.get_node("CraftAbility") as CraftAbility)._finish(recipe)
	var traps := _tree.get_first_node_in_group(TrapField.GROUP) as TrapField
	var trap: Dictionary = traps.traps.filter(func(t: Dictionary) -> bool: return t.kind == &"log")[0]
	var at: Array = trap.at
	var trigger := Vector3(float(at[0]), float(at[1]), float(at[2]))
	_put(base + Vector3(20.0, 0.0, 20.0))
	# Um orc passa pela corda.
	var orc := _band.spawn(&"scout", trigger + Vector3(-5.0, 0.0, 0.0))
	await _wait(0.2)
	orc.route = []
	orc.state = Orc.State.INVESTIGATE
	orc._timer = 99.0
	orc._goal = trigger + Vector3(4.0, 0.0, 0.0)
	var health := orc.health
	await _until(func() -> bool: return vegetation.trees[dead].fallen, 8.0)
	_check(vegetation.trees[dead].fallen, "quem passa pela corda derruba a árvore")
	await _wait(1.6)
	_check(not is_instance_valid(orc) or orc.health < health, "e o tronco acerta o orc (%.1f → %.1f)" % [health, orc.health if is_instance_valid(orc) else 0.0])
	_check(traps.traps.filter(func(t: Dictionary) -> bool: return t.kind == &"log").is_empty(), "o tronco armado é de uma vez só")


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	Input.action_release("aim")
	for orc in _band.get_children():
		orc.queue_free()
	Inventory.clear()
	Vitals.reset()
	_melee.stamina = 1.0
	_melee.poise = 0.0
	Clock.hour = 10.0


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
