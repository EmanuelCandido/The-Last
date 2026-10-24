extends RefCounted
## Bichos do ambiente: insetos espalhados (cantam na hora deles, calam com o goblin e com barulho,
## gafanhoto pula), pássaros pousados (cantam do galho, espantam e trocam de árvore, coruja de
## noite) e uivos em rodadas raras.

var _tree := Engine.get_main_loop() as SceneTree
var _fails := 0
var _level: Node3D


func run() -> void:
	_level = Game.current_level
	Weather.stop_rain()
	Weather.rain = 0.0
	await _insects()
	await _birds()
	await _howls()
	print("[T] FIM: %s" % ("TUDO OK" if _fails == 0 else "%d FALHA(S)" % _fails))


func _insects() -> void:
	var ambience := _level.get_node("Ambience") as Ambience
	var field := ambience.insects
	var crickets := field.count(InsectField.Kind.CRICKET)
	var hoppers := field.count(InsectField.Kind.GRASSHOPPER)
	_check(crickets > 200 and hoppers > 120, "insetos espalhados (%d grilos, %d gafanhotos)" % [crickets, hoppers])
	# Um lugar com muitos grilos e gafanhotos perto.
	var spot := _crowded(field)
	Game.player.global_position = spot + Vector3.UP * 0.2
	Clock.hour = 23.0
	await _wait(1.5)
	var voiced := field.voiced()
	_check(not voiced.is_empty() and voiced.all(func(i: int) -> bool: return field.insect_kind(i) == InsectField.Kind.CRICKET),
		"de noite cantam grilos de verdade perto (%d)" % voiced.size())
	var far_ok := true
	for i in voiced:
		if field.insect_position(i).distance_to(Game.player.global_position) > Tuning.CRICKET_HEAR_RANGE + 3.0:
			far_ok = false
	_check(far_ok, "cada canto sai de um grilo dentro do alcance")
	Clock.hour = 11.0
	await _wait(1.5)
	voiced = field.voiced()
	_check(not voiced.is_empty() and voiced.all(func(i: int) -> bool: return field.insect_kind(i) == InsectField.Kind.GRASSHOPPER),
		"de dia cantam gafanhotos (%d)" % voiced.size())
	# Andando, os de perto se calam e o gafanhoto do pé pula.
	var near := _nearest(field, InsectField.Kind.GRASSHOPPER, Game.player.global_position)
	var before := field.insect_position(near)
	Game.player.global_position = before + Vector3(0.6, 0.2, 0.0)
	Input.action_press(&"move_forward")
	await _wait(0.6)
	Input.action_release(&"move_forward")
	_check(not field.singing(near), "com o goblin andando perto, o gafanhoto se cala")
	_check(field.insect_position(near).distance_to(before) > 0.8, "e pula para longe (%.1f m)" % field.insect_position(near).distance_to(before))
	# Um barulho cala os do raio.
	var target := _nearest(field, InsectField.Kind.GRASSHOPPER, spot + Vector3(12.0, 0.0, 0.0))
	var was := field.singing(target)
	Events.noise_made.emit(field.insect_position(target), 6.0)
	_check(was and not field.singing(target), "um barulho cala os insetos em volta")
	Weather.start_rain(2.0)
	Weather.rain = 1.0
	await _wait(1.5)
	_check(field.voiced().is_empty(), "na chuva os insetos se calam")
	Weather.stop_rain()
	Weather.rain = 0.0


func _birds() -> void:
	var life := _level.get_node("Animals/Birds") as BirdLife
	var counts := [0, 0, 0]
	for bird in life.birds:
		counts[bird.species] += 1
	_check(counts[0] >= 30 and counts[1] >= 2 and counts[2] >= 2, "pássaros pousados (%d canoros, %d pica-paus, %d corujas)" % counts)
	var vegetation := _level.get_node("Vegetation") as Vegetation
	var on_tree := true
	for bird in life.birds:
		var info := vegetation.trees[bird.tree]
		if Vector2(bird.global_position.x - info.base.x, bird.global_position.z - info.base.z).length() > 3.5 or bird.global_position.y < info.base.y + 2.0:
			on_tree = false
		if bird.species == Bird.Species.WOODPECKER and not info.dead:
			on_tree = false
	_check(on_tree, "cada um num galho de árvore de verdade (pica-pau em árvore seca)")
	# Canta do galho: o tocador do Ambience toca no ponto do pássaro.
	Clock.hour = 9.0
	var bird: Bird = null
	for b in life.birds:
		if b.species == Bird.Species.SONGBIRD:
			bird = b
			break
	Game.player.global_position = bird.global_position + Vector3(15.0, 0.0, 0.0)
	Game.player.global_position.y = _level.ground_height(Game.player.global_position.x, Game.player.global_position.z) + 0.2
	await _wait(0.3)
	bird._sing()
	await _wait(0.1)
	var from_bird := false
	for caller: OccludedAudio in (_level.get_node("Ambience") as Ambience)._callers:
		if caller.playing and caller.global_position.distance_to(bird.global_position) < 0.1:
			from_bird = true
	_check(from_bird, "o canto sai do galho do pássaro")
	# Espanta: voa para outra árvore e pousa.
	var tree_before := bird.tree
	var below := bird.global_position
	Game.player.global_position = Vector3(below.x + 1.0, _level.ground_height(below.x + 1.0, below.z) + 0.2, below.z)
	await _wait(0.4)
	_check(bird.mode == Bird.Mode.FLYING, "o goblin embaixo espanta o pássaro")
	await _wait(8.0)
	_check(bird.mode == Bird.Mode.PERCHED and bird.tree != tree_before and bird.tree != -1, "pousou em outra árvore")
	var owl: Bird = null
	for b in life.birds:
		if b.species == Bird.Species.OWL:
			owl = b
	Clock.hour = 12.0
	_check(not owl._awake(), "de dia a coruja dorme")
	Clock.hour = 23.5
	_check(owl._awake() and not bird._awake(), "de noite a coruja pia e o canoro dorme")


func _howls() -> void:
	# As rodadas distantes moram na matilha (WolfPack) desde que cada uivo virou um lobo de verdade.
	var pack := _level.find_child("WolfPack", true, false) as WolfPack
	var quiet := 0
	var max_bouts := 0
	var in_range := true
	for night in 300:
		pack._distant_queue.clear()
		pack._tick_distant(0.0, 1000 + night, 20.0)
		var bouts: int = pack._distant_hours.size()
		if bouts == 0:
			quiet += 1
		max_bouts = maxi(max_bouts, bouts)
		for hour: float in pack._distant_hours:
			if hour < 21.0 or hour > 28.0:
				in_range = false
	_check(quiet > 80 and quiet < 160, "muitas noites sem uivo nenhum (%d de 300)" % quiet)
	_check(max_bouts <= 3 and in_range, "no máximo 3 rodadas, entre 21h e 4h")
	pack._distant_hours.assign([22.0])
	pack._distant_queue.clear()
	pack._tick_distant(0.0, pack._distant_night, 13.0)
	_check(pack._distant_queue.is_empty(), "de dia nenhuma rodada toca")
	var before := _distant_wolves(pack)
	pack._tick_distant(0.0, pack._distant_night, 22.1)
	_check(pack._distant_hours.is_empty() and _distant_wolves(pack) > before, "na hora da rodada um lobo distante uiva")
	pack._clear()


func _distant_wolves(pack: WolfPack) -> int:
	return pack.get_children().filter(func(child: Node) -> bool:
		return child is Wolf and (child as Wolf).distant and not child.is_queued_for_deletion()).size()


func _crowded(field: InsectField) -> Vector3:
	var best := Vector3.ZERO
	var best_count := -1
	for attempt in 60:
		var center := field.insect_position(randi() % field.insect_count())
		var crickets := 0
		var hoppers := 0
		for i in field.insect_count():
			if field.insect_position(i).distance_to(center) < 15.0:
				if field.insect_kind(i) == InsectField.Kind.CRICKET:
					crickets += 1
				else:
					hoppers += 1
		if mini(crickets, hoppers) > best_count:
			best_count = mini(crickets, hoppers)
			best = center
	return best


func _nearest(field: InsectField, kind: int, at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in field.insect_count():
		if field.insect_kind(i) == kind and field.insect_position(i).distance_to(at) < best_d:
			best_d = field.insect_position(i).distance_to(at)
			best = i
	return best


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[T] ok   " + what)
	else:
		_fails += 1
		print("[T] FALHOU " + what)
