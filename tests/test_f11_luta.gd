extends RefCounted
## F11 de ponta a ponta (docs/plano_combate.md, experimental): receitas e bancada, trocar de arma,
## golpe leve, forte e a sequência num boneco de treino, defesa, aparo, esquiva, postura e queda,
## a lança firmada contra o javali, o furtivo, sangramento e bandagem, desgaste e conserto, o
## arremesso da lança e o save. --case=<nome> roda um só (padrão: todos).

const DUMMY_SOURCE := """extends Node3D
var hits: Array = []
func take_hit(_power: float, _point: Vector3, _direction: Vector3, damage := 1.0) -> void:
	hits.append(damage)
"""

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D
var _melee: MeleeAbility


func run() -> void:
	_level = Game.current_level
	_melee = Game.player.get_node("MeleeAbility") as MeleeAbility
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := ["craft", "equip", "swing", "guard", "dodge", "poise", "brace", "stealth", "bleed", "wear", "throw", "save"]
	for case: String in cases:
		if only == "" or only == case:
			print("[T] --- %s" % case)
			_reset()
			await call("_" + case)
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _craft() -> void:
	var craft := Game.player.get_node("CraftAbility") as CraftAbility
	var recipes := {}
	for recipe: Dictionary in Recipes.LIST:
		recipes[recipe.id] = recipe
	Inventory.add(&"wood", 12)
	Inventory.add(&"stone", 6)
	Inventory.add(&"sinew", 3)
	Inventory.add(&"bone", 3)
	Inventory.add(&"moss", 2)
	craft._finish(recipes[&"stone_knife"])
	craft._finish(recipes[&"club"])
	craft._finish(recipes[&"spear"])
	craft._finish(recipes[&"bandage"])
	_check(Inventory.has(&"stone_knife") and Inventory.has(&"club") and Inventory.has(&"spear"), "faca, porrete e lança saem da lista")
	_check(Inventory.has(&"bandage") and not Inventory.has(&"moss"), "2 musgos viram uma bandagem")
	_check(Inventory.count(&"sinew") == 2, "a lança gasta um tendão")
	# Fora da toca: nem bancada, nem receita de bancada.
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.2)
	_check(Recipes.missing(recipes[&"bench"]) == "só dentro da toca", "a bancada só se monta dentro da toca")
	_check(Recipes.missing(recipes[&"bone_knife"]) == "precisa da bancada", "a faca de osso precisa da bancada")
	# Na toca, perto de onde a bancada fica.
	var bench := _level.find_child("Workbench", true, false) as Workbench
	_check(bench != null and not bench.built, "a bancada nasce desmontada")
	_put(bench.global_position + bench.global_basis.z * 1.0)
	await _wait(0.2)
	_check(Recipes.missing(recipes[&"bench"]) == "", "dentro da toca dá para montar a bancada")
	craft._finish(recipes[&"bench"])
	_check(bench.built, "a bancada foi montada")
	_check(Recipes.missing(recipes[&"bench"]) == "já tem", "só uma bancada")
	_check(Recipes.missing(recipes[&"bone_knife"]) == "", "perto da bancada, a faca de osso dá")
	craft._finish(recipes[&"bone_knife"])
	_check(Inventory.has(&"bone_knife"), "faca de osso pronta")
	# Coletar caça dá tendão.
	var before := Inventory.count(&"sinew")
	var deer: Deer = null
	for node in _tree.get_nodes_in_group(&"animals"):
		if node is Deer and not node is OldDeer and not node is WhiteDeer:
			deer = node
			break
	if deer != null:
		deer.kill()
		deer.interact(Game.player)
		_check(Inventory.count(&"sinew") == before + deer.sinew and deer.sinew == 2, "o cervo dá %d tendões" % deer.sinew)


func _equip() -> void:
	Inventory.add(&"bow")
	Inventory.add(&"arrow", 5)
	Inventory.add(&"spear")
	Inventory.add(&"stone_knife")
	await _wait(0.3)
	_check(Inventory.held() == &"", "começa com o arco")
	_tap("weapon_swap")
	await _wait(0.8)
	_check(Inventory.held() == &"stone_knife", "Tab põe a faca na mão (%s)" % Inventory.held())
	var gear: PlayerGear = Game.player._gear
	_check(gear.weapon != null and gear.weapon.visible, "a faca aparece na mão")
	_check(not gear.bow.visible and gear._back_bow.visible, "o arco vai para as costas")
	Input.action_press("aim")
	await _wait(0.3)
	_check(not Game.player.aiming and _melee.guarding, "com a faca, o botão de mirar defende")
	Input.action_release("aim")
	_tap("weapon_swap")
	await _wait(0.8)
	_check(Inventory.held() == &"spear", "Tab de novo: a lança")
	var segment := Game.player.weapon_segment()
	_check(segment.size() == 2 and segment[0].distance_to(segment[1]) > 0.4, "a lâmina da lança tem um caminho (%.2f m)" % (segment[0].distance_to(segment[1]) if segment.size() == 2 else 0.0))
	_tap("weapon_swap")
	await _wait(0.8)
	_check(Inventory.held() == &"" and gear.bow.visible, "e volta ao arco")


func _swing() -> void:
	Inventory.add(&"stone_knife")
	Inventory.hold(&"stone_knife")
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.4)
	var dummy := _dummy()
	await _wait(0.2)
	var stamina := _melee.stamina
	_tap("attack")
	await _wait(0.9)
	var hits: Array = dummy.get("hits")
	_check(hits.size() == 1, "o golpe leve acerta o boneco (%d)" % hits.size())
	_check(_melee.stamina < stamina, "o golpe gasta fôlego (%.2f → %.2f)" % [stamina, _melee.stamina])
	var light: float = hits[0] if hits.size() > 0 else 0.0
	# Forte: segurando (cada golpe avança o goblin um pouco: o boneco volta para a frente dele).
	_melee.stamina = 1.0
	_place(dummy)
	_hold("attack", true)
	await _wait(Tuning.HEAVY_HOLD + 0.1)
	_hold("attack", false)
	await _wait(1.2)
	hits = dummy.get("hits")
	_check(hits.size() == 2 and float(hits[1]) > light, "o forte fere mais (%s)" % str(hits))
	# Sequência: três toques seguidos, três golpes.
	_melee.stamina = 1.0
	_place(dummy)
	await _wait(0.1)
	var count := hits.size()
	for i in 3:
		_tap("attack")
		await _wait(0.3)
	await _wait(1.2)
	hits = dummy.get("hits")
	_check(hits.size() - count >= 2, "os toques encadeiam golpes (%d)" % (hits.size() - count))
	# Cansado: o golpe sai fraco.
	_melee.stamina = 0.05
	_place(dummy)
	await _wait(0.1)
	count = hits.size()
	_tap("attack")
	await _wait(1.0)
	hits = dummy.get("hits")
	_check(hits.size() > count and float(hits[hits.size() - 1]) < light, "sem fôlego, o golpe sai fraco")
	dummy.queue_free()


func _guard() -> void:
	Inventory.add(&"club")
	Inventory.hold(&"club")
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.4)
	var front := Game.player.global_position + Game.player.facing() * 1.2
	Input.action_press("aim")
	await _wait(0.05)
	var result := Game.player.receive_attack(_bite(front))
	_check(result == &"parried", "defesa erguida bem na hora apara (%s)" % result)
	_check(Vitals.health == 100.0, "o aparo não fere")
	await _wait(0.5)
	result = Game.player.receive_attack(_bite(front))
	_check(result == &"blocked", "segurando, a defesa segura (%s)" % result)
	_check(Vitals.health < 100.0 and Vitals.health > 100.0 - Tuning.WOLF_BITE * 0.6, "passa só um pouco (%.1f)" % Vitals.health)
	Vitals.health = 100.0
	var back := Game.player.global_position - Game.player.facing() * 1.2
	result = Game.player.receive_attack(_bite(back))
	_check(result == &"hit", "por trás, a defesa não segura (%s)" % result)
	# Sem fôlego, a defesa cede e derruba.
	await _wait(1.0)
	Vitals.health = 100.0
	_melee.stamina = 0.0
	_melee.poise = 0.0
	await _wait(0.6)
	_melee.stamina = 0.0
	result = Game.player.receive_attack(_bite(front))
	_check(result == &"hit" and Game.player.animator()._action == &"knockdown", "sem fôlego, a defesa cede e ele cai")
	Input.action_release("aim")
	await _wait(Tuning.KNOCKDOWN_TIME + 0.3)
	_check(Game.player.can_act(), "e levanta")


func _dodge() -> void:
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.4)
	var start := Game.player.global_position
	_tap("dodge")
	await _wait(0.05)
	var result := Game.player.receive_attack(_bite(start + Game.player.facing()))
	_check(result == &"dodged", "no começo da esquiva, nada pega (%s)" % result)
	await _wait(0.6)
	var moved := Vector2(Game.player.global_position.x - start.x, Game.player.global_position.z - start.z).length()
	_check(moved > 0.8, "a esquiva leva o goblin longe (%.2f m)" % moved)
	_check(_melee.stamina < 1.0, "e gasta fôlego")
	await _wait(0.3)
	result = Game.player.receive_attack(_bite(Game.player.global_position + Game.player.facing()))
	_check(result == &"hit", "acabada a esquiva, pega")


func _poise() -> void:
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.4)
	var front := Game.player.global_position + Game.player.facing()
	Game.player.receive_attack(_bite(front))
	Game.player.receive_attack(_bite(front))
	_check(Game.player.animator()._action == &"stagger", "duas mordidas seguidas: cambaleia (%s)" % Game.player.animator()._action)
	await _wait(0.6)
	var big := _bite(front)
	big.poise = 1.2
	Game.player.receive_attack(big)
	_check(Game.player.animator()._action == &"knockdown", "um golpe pesado derruba")
	await _wait(Tuning.KNOCKDOWN_TIME + 0.3)
	_check(Game.player.can_act(), "e levanta sozinho")


func _brace() -> void:
	Inventory.add(&"spear")
	Inventory.hold(&"spear")
	var boar := _boar()
	_check(boar != null, "há javali no vale")
	if boar == null:
		return
	var p := boar.global_position + Vector3(Tuning.BOAR_CHARGE_RANGE * 0.6, 0.0, 0.0)
	_put(p)
	Game.player.face(boar.global_position - Game.player.global_position)
	await _wait(0.3)
	Input.action_press("aim")
	await _wait(0.4)
	_check(_melee.guarding, "a lança firmada")
	var health := boar.health
	# Virado para o goblin: a investida vem reta (de lado ela pode passar longe).
	var to := Game.player.global_position - boar.global_position
	boar._yaw = atan2(to.x, to.z)
	boar.rotation.y = boar._yaw
	boar.awareness = 1.0
	await _until(func() -> bool: return boar.charge != Boar.Charge.NONE, 2.0)
	boar._charge_yaw = boar._yaw
	_check(boar.charge == Boar.Charge.RUN, "o javali investe")
	# Como um jogador faria: vira o corpo para o javali enquanto ele vem (ele faz curva).
	var left := 9.0
	while left > 0.0 and boar.health >= health and Vitals.health >= 100.0:
		Game.player.face(boar.global_position - Game.player.global_position)
		await _wait(0.03)
		left -= 0.03

	_check(boar.health < health, "a investida bate na ponta: o javali se fere (%.2f → %.2f)" % [health, boar.health])
	_check(Vitals.health == 100.0, "e o goblin não (%.0f)" % Vitals.health)
	await _wait(0.5)
	_check(boar.charge == Boar.Charge.NONE, "a investida acaba")
	Input.action_release("aim")


func _stealth() -> void:
	Inventory.add(&"stone_knife")
	Inventory.hold(&"stone_knife")
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.4)
	var dummy := _dummy()
	await _wait(0.2)
	Input.action_press("crouch")
	await _wait(0.4)
	_tap("attack")
	await _wait(0.9)
	Input.action_release("crouch")
	var hits: Array = dummy.get("hits")
	# O boneco não é bicho: o golpe furtivo só vale contra quem tem atenção (Animal).
	_check(hits.size() == 1 and absf(float(hits[0]) - float(Weapons.spec(&"stone_knife").light)) < 0.01, "agachado num boneco, golpe normal")
	dummy.queue_free()
	var boar := _boar()
	if boar == null:
		return
	boar.awareness = 0.0
	var health := boar.health
	boar.take_hit(0.5, boar.global_position, Vector3.FORWARD, 0.0)
	_check(boar.health == health, "golpe de dano zero não fere (controle)")


func _bleed() -> void:
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.3)
	Vitals.bleed(10.0)
	await _wait(2.0)
	_check(Vitals.health < 100.0, "sangrando, a vida cai (%.1f)" % Vitals.health)
	_check("Sangrando" in Vitals.status_words(), "o pause diz Sangrando")
	Inventory.add(&"bandage")
	_tap("eat")
	await _wait(Tuning.BANDAGE_TIME + 0.3)
	_check(Vitals.bleeding == 0.0 and not Inventory.has(&"bandage"), "F põe a bandagem e o sangue para")
	Vitals.health = 50.0
	Inventory.add(&"herb")
	_tap("eat")
	await _wait(Tuning.EAT_TIME + 2.0)
	_check(Vitals.health > 51.0 and not Inventory.has(&"herb"), "ferido, F come a erva e cura devagar (%.1f)" % Vitals.health)


func _wear() -> void:
	Inventory.add(&"club")
	Inventory.hold(&"club")
	_melee._wear(&"club", 70.0)
	_check(Inventory.wear(&"club") < Tuning.WEAR_WARN and Inventory.has(&"club"), "rachando, mas inteira (%.2f)" % Inventory.wear(&"club"))
	var bench := _level.find_child("Workbench", true, false) as Workbench
	bench.build_now()
	_put(bench.global_position + bench.global_basis.z * 1.0)
	await _wait(0.2)
	Inventory.add(&"wood", 2)
	var repair: Dictionary = Recipes.LIST.filter(func(r: Dictionary) -> bool: return r.id == &"repair")[0]
	_check(Recipes.missing(repair) == "", "perto da bancada dá para consertar")
	(Game.player.get_node("CraftAbility") as CraftAbility)._finish(repair)
	_check(Inventory.wear(&"club") == 1.0 and Inventory.count(&"wood") == 1, "consertado com uma madeira")
	_melee._wear(&"club", 200.0)
	_check(not Inventory.has(&"club") and Inventory.held() == &"", "gasta demais, quebra e a mão fica vazia")


func _throw() -> void:
	Inventory.add(&"spear")
	Inventory.hold(&"spear")
	_put(Vector3(20.0, 0.0, 10.0))
	await _wait(0.3)
	Inventory.wear_down(&"spear", 0.3)
	_tap("throw")
	await _wait(Tuning.THROW_TIME + 2.0)
	_check(not Inventory.has(&"spear"), "G arremessa a lança")
	var spear: ThrownSpear = null
	for node in _level.get_children():
		if node is ThrownSpear:
			spear = node
	_check(spear != null and not spear._flying, "a lança fincou")
	if spear != null:
		spear.interact(Game.player)
		_check(Inventory.has(&"spear") and absf(Inventory.wear(&"spear") - 0.7) < 0.01, "pega de volta, gasta como saiu (%.2f)" % Inventory.wear(&"spear"))


func _save() -> void:
	Inventory.add(&"spear", 2)
	Inventory.hold(&"spear")
	Inventory.wear_down(&"spear", 0.4)
	Vitals.bleed(20.0)
	var inventory := Inventory.save_data()
	var vitals := Vitals.save_data()
	Inventory.clear()
	Vitals.reset()
	_check(Inventory.held() == &"" and Vitals.bleeding == 0.0, "limpou")
	Inventory.load_data(inventory)
	Vitals.load_data(vitals)
	_check(Inventory.held() == &"spear" and Inventory.count(&"spear") == 2, "a arma na mão volta do save")
	_check(absf(Inventory.wear(&"spear") - 0.6) < 0.01, "o desgaste volta do save (%.2f)" % Inventory.wear(&"spear"))
	_check(Vitals.bleeding > 0.0, "o sangramento volta do save")
	Vitals.bleeding = 0.0


# --- Ajudantes -------------------------------------------------------------------------

func _reset() -> void:
	for action in ["attack", "aim", "crouch", "dodge"]:
		Input.action_release(action)
	Inventory.clear()
	Vitals.reset()
	_melee.stamina = 1.0
	_melee.poise = 0.0
	_melee._cancel_swing()
	Clock.hour = 10.0
	Weather.stop_rain()
	Weather.rain = 0.0


## Um boneco de treino (área de acerto na camada dos bichos) à frente do goblin, na altura da mão.
func _dummy() -> Node3D:
	var script := GDScript.new()
	script.source_code = DUMMY_SOURCE
	script.reload()
	var dummy := Node3D.new()
	dummy.set_script(script)
	var area := Area3D.new()
	area.collision_layer = Animal.HIT_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	area.add_child(shape)
	dummy.add_child(area)
	_level.add_child(dummy)
	_place(dummy)
	return dummy


func _place(dummy: Node3D) -> void:
	var forward := Game.player.aim_direction()
	forward.y = 0.0
	forward = forward.normalized()
	dummy.global_position = Game.player.global_position + forward * 0.55 + Vector3.UP * 0.5


func _bite(from: Vector3) -> Dictionary:
	return {"damage": Tuning.WOLF_BITE, "kind": &"bite", "from": from, "poise": 0.35, "cause": &"wolf", "push": Vector3.ZERO}


func _boar() -> Boar:
	for node in _tree.get_nodes_in_group(&"animals"):
		if node is Boar and (node as Animal).state != Animal.State.DEAD:
			return node
	return null


func _put(at: Vector3) -> void:
	Game.player.global_position = Vector3(at.x, _level.ground_height(at.x, at.z) + 0.1, at.z)
	Game.player.velocity = Vector3.ZERO


func _tap(action: String) -> void:
	_hold(action, true)
	_hold(action, false)


func _hold(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _until(condition: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not condition.call():
		await _wait(0.1)
		left -= 0.1


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, true).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
