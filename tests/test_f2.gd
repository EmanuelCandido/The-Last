extends RefCounted
## Fase 2 de ponta a ponta: noite, frio, fogo, roupa, matilha, mordida, fogo protege, flechas, amanhecer.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0


func run() -> void:
	var player := Game.player
	var level := Game.current_level
	var fire: Campfire = level.find_child("Campfire", true, false)
	var pack: WolfPack = level.find_child("WolfPack", true, false)
	var cold: ColdExposure = player.get_node("ColdExposure")

	# Noite.
	_check(Clock.night_at(12.0) == 0.0 and Clock.night_at(23.0) == 1.0 and Clock.night_at(2.0) == 1.0, "meio-dia é dia, 23h e 2h são noite")
	var dusk := Clock.night_at(19.5)
	_check(dusk > 0.2 and dusk < 0.8, "19h30 está no meio do anoitecer (%.2f)" % dusk)

	# Frio: de noite lá fora esfria; perto do fogo esquenta; roupa corta o ganho.
	Clock.hour = 23.0
	_put(player, Vector2(14.0, 12.0))
	await _wait(5.0)
	var outside := cold.exposure()
	print("[T] fora, noite: exposição %.2f/s, frio %.1f" % [outside, Vitals.cold])
	_check(outside > 0.0 and Vitals.cold > 1.0, "de noite, lá fora, esfria")
	Inventory.add(&"clothes")
	var dressed := cold.exposure()
	_check(absf(dressed - outside * Tuning.CLOTHES_COLD_FACTOR) < 0.05, "roupa corta o ganho pela metade (%.2f -> %.2f)" % [outside, dressed])
	Inventory.remove(&"clothes")
	fire.fuel = 3.0
	fire._apply_fuel()
	_put(player, Vector2(fire.global_position.x + 1.0, fire.global_position.z))
	await _wait(0.3)
	_check(cold.exposure() <= Tuning.FIRE_WARMTH, "perto do fogo esquenta (%.2f)" % cold.exposure())
	Vitals.cold = 100.0
	_put(player, Vector2(14.0, 12.0))
	var health := Vitals.health
	await _wait(3.0)
	_check(Vitals.health < health - 1.0, "frio no máximo machuca (%.1f -> %.1f)" % [health, Vitals.health])
	_check(player._animator.shiver > 0.9, "o goblin treme (shiver %.2f)" % player._animator.shiver)
	Vitals.cold = 0.0
	Vitals.health = 100.0

	# Matilha: antes do dia 3 não vem; no dia 3 avisa às 20h30 e chega às 21h.
	Clock.day = 2
	Clock.hour = 21.2
	await _wait(1.0)
	_check(_alive(pack) == 0, "dia 2: sem lobos")
	Clock.day = 3
	Clock.hour = 20.6
	await _wait(0.5)
	# Desde a F9 a matilha aparece no aviso, esperando na borda do vale (Wolf.waiting), e só chega às 21h.
	var waiting := pack._wolves.all(func(wolf: Variant) -> bool: return is_instance_valid(wolf) and (wolf as Wolf).waiting)
	_check(pack._warned_night == 3 and _alive(pack) == Tuning.WOLF_COUNT and waiting, "dia 3, 20h36: uivo de aviso, a matilha espera na borda")
	Clock.hour = 21.05
	await _wait(0.5)
	_check(_alive(pack) == Tuning.WOLF_COUNT, "21h: chegaram %d lobos" % _alive(pack))
	var origin := pack._origin
	_check(origin.distance_to(Vector2(player.global_position.x, player.global_position.z)) >= Tuning.WOLF_SPAWN_MIN_DISTANCE, "vieram longe do goblin")
	pack._clear()
	await _wait(0.2)

	# Mordida: um lobo que já percebeu o goblin corre e morde.
	_put(player, Vector2(14.0, 12.0))
	var wolves := pack.spawn_now(Vector2(14.0, 26.0))
	for wolf in wolves:
		wolf.awareness = 1.4
	var waited := 0.0
	while Vitals.health >= 100.0 and waited < 10.0:
		await _tree.process_frame
		waited += 1.0 / 60.0
	print("[T] primeira mordida depois de %.1f s: vida %.1f" % [waited, Vitals.health])
	_check(Vitals.health <= 100.0 - Tuning.WOLF_BITE + 0.1, "os lobos chegaram e morderam (vida %.1f)" % Vitals.health)
	pack._clear()
	await _wait(0.2)
	Vitals.health = 100.0
	# A mordida pode ter aberto uma ferida (F11): sem estancar, a vida cairia junto do fogo também.
	Vitals.bleeding = 0.0

	# Junto do fogo: o lobo ronda mas não morde.
	var near_fire := Vector2(fire.global_position.x + 0.8, fire.global_position.z + 0.5)
	_put(player, near_fire)
	wolves = pack.spawn_now(Vector2(0.0, 58.0))
	for wolf in wolves:
		wolf.awareness = 1.4
	await _wait(12.0)
	var closest := INF
	for wolf in wolves:
		if is_instance_valid(wolf):
			closest = minf(closest, Campfire.distance_to_fire(wolf.global_position))
	print("[T] junto do fogo: vida %.1f, lobo mais perto do fogo %.1f m" % [Vitals.health, closest])
	_check(Vitals.health >= 99.0 and closest > Tuning.WOLF_FIRE_FEAR - 1.0, "o fogo protege")

	# Flechadas: uma faz fugir e ir embora; duas matam e rendem couro.
	var target: Wolf = wolves[0]
	target.take_hit(1.0, target.global_position + Vector3.UP * 0.56, Vector3.FORWARD)
	_check(target.state == Animal.State.FLEE and target.leaving, "uma flechada: foge e vai embora")
	target.take_hit(1.0, target.global_position + Vector3.UP * 0.56, Vector3.FORWARD)
	_check(target.state == Animal.State.DEAD and target.interaction_prompt() != "", "duas flechadas: morto, dá para coletar")
	var hides := Inventory.count(&"hide")
	target.interact(player)
	_check(Inventory.count(&"hide") == hides + 2 and Story.count(&"wolf_harvested") == 1, "coletou 2 couros do lobo")

	# Amanhecer: os que sobraram vão embora.
	Clock.hour = 5.6
	await _wait(0.5)
	var leaving := true
	for wolf in wolves:
		if is_instance_valid(wolf) and wolf.state != Animal.State.DEAD:
			leaving = leaving and wolf.leaving
	_check(leaving, "amanhecer: os lobos vão embora")

	# Dormir faz a noite passar e some com a matilha.
	Clock.hour = 21.5
	Clock.day = 4
	await _wait(0.5)
	_check(_alive(pack) > 0, "dia 4, 21h30: a matilha voltou")
	Game.pass_out(&"sleep")
	while Game.resting:
		await _tree.process_frame
	_check(_alive(pack) == 0, "dormiu: a matilha sumiu com a noite")

	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _alive(pack: WolfPack) -> int:
	var count := 0
	for child in pack.get_children():
		if child is Wolf and not child.is_queued_for_deletion() and child.state != Animal.State.DEAD:
			count += 1
	return count


func _put(player: Node3D, at: Vector2) -> void:
	player.global_position = Vector3(at.x, Game.current_level.ground_height(at.x, at.y) + 0.05, at.y)
	player.velocity = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds, false).timeout


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("[T] %s %s" % ["ok  " if ok else "FALHOU", what])
