class_name OrcBand
extends Node3D
## Os orcs do vale (F12, docs/plano_combate.md §7 e §9.2; experimental): quem chega, quando, por onde
## anda e como se ajudam. Filho da floresta.
##
## Chegada pelo dia do ciclo: do Tuning.ORC_FIRST_DAY em diante um batedor por dia; do ORC_PATROL_DAY,
## também uma patrulha de dois (batedor e guerreiro). Entram às ORC_ARRIVE_HOUR pelo desfiladeiro
## (F14: vêm do vale da Pedra Rachada; aparecem no ponto do caminho mais perto da toca que fique
## longe do goblin e andam o resto, `Orc.approach`), e cada grupo anda uma rota em volta do vale;
## às ORC_LEAVE_HOUR voltam pelo desfiladeiro.
##
## O grito de um orc chama os que estão perto (alert). Na luta, só os ORC_ATTACKERS_AT_ONCE mais
## perto do goblin atacam (may_attack); os outros rodeiam. Um orc morto abala os que viram.
##
## Não há orcs no Bem-vindo de volta (o Zelador, jogando de goblin, não fere ninguém), depois de
## Ficar, com o flag `orcs_off` (o console do Zelador) e nos testes automáticos sem --orcs.
## Os orcs não vão no save: o dia de chegada sim (não chegam de novo no mesmo dia).

const GROUP := &"orc_band"

var _arrived_day := -1
var _rng := RandomNumberGenerator.new()
## A Investida (F13): em andamento, quem veio, quantos eram e o dia da última.
var raid_active := false
var _raiders: Array[Orc] = []
var _raid_size := 0
var _last_raid_day := -99
## Vigilância da luta (F14): quando foi a última que contou.
var _fight_clock := -999.0
## Segundos até a próxima conversa na língua dos orcs (F14).
var _talk_wait := 5.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)
	_rng.randomize()


func _process(delta: float) -> void:
	if not enabled():
		if get_child_count() > 0:
			for orc in get_children():
				orc.queue_free()
		return
	# O fim da Investida vale também nos testes (a que o roteiro começa).
	_raid_update()
	_chatter(delta)
	# Nos testes automáticos, só os orcs que o roteiro põe (sem --orcs eles não chegam sozinhos).
	if DevTools.automated and not DevTools.orcs:
		return
	_raid_schedule()
	if Clock.day < Tuning.ORC_FIRST_DAY or _arrived_day == Clock.day:
		return
	if Clock.hour < Tuning.ORC_ARRIVE_HOUR or Clock.hour >= Tuning.ORC_LEAVE_HOUR - 1.0:
		return
	_arrived_day = Clock.day
	arrive()


## A língua dos orcs (F14): de tempos em tempos, dois orcs calmos perto um do outro conversam (um
## fala, o outro responde quando ele termina).
func _chatter(delta: float) -> void:
	_talk_wait -= delta
	if _talk_wait > 0.0:
		return
	_talk_wait = _rng.randf_range(Tuning.ORC_TALK_INTERVAL.x, Tuning.ORC_TALK_INTERVAL.y)
	var calm: Array[Orc] = []
	for child in get_children():
		var orc := child as Orc
		if orc != null and orc.calm():
			calm.append(orc)
	calm.shuffle()
	for speaker in calm:
		for listener in calm:
			if speaker == listener or speaker.global_position.distance_to(listener.global_position) > Tuning.ORC_TALK_RANGE:
				continue
			var seconds := speaker.talk()
			get_tree().create_timer(seconds + _rng.randf_range(0.3, 0.8), false).timeout.connect(func() -> void:
				if is_instance_valid(listener) and listener.calm():
					listener.talk())
			return


## Os orcs podem existir agora.
func enabled() -> bool:
	return not (Game.welcome or Story.has_flag(&"ending_stay") or Story.has_flag(&"orcs_off"))


## Chegam os orcs do dia: um batedor e, mais tarde no ciclo, a patrulha.
func arrive() -> void:
	var entry := _entry()
	var path: Array[Vector3] = entry[1]
	var scout := spawn(&"scout", entry[0], make_route())
	scout.approach = path.duplicate()
	if Clock.day >= Tuning.ORC_PATROL_DAY:
		var patrol := make_route()
		# A patrulha vem atrás, uns passos de distância no mesmo caminho.
		var behind: Vector3 = entry[0] + Vector3(4.0, 0.0, 1.5)
		var first := spawn(&"scout", behind, patrol)
		first.approach = path.duplicate()
		# O segundo da patrulha: o guerreiro ou o arqueiro.
		var second := spawn(&"archer" if _rng.randf() < 0.5 else &"warrior", behind + Vector3(1.6, 0.0, 1.2), patrol)
		second.approach = path.duplicate()


## Cria um orc em `at` (no chão), andando `route`. `raider` = vem na Investida (tocha, entra na toca).
func spawn(kind: StringName, at: Vector3, route: Array[Vector3] = [], raider := false) -> Orc:
	var orc := Orc.new()
	orc.kind = kind
	orc.band = self
	orc.route = route
	orc.raider = raider
	add_child(orc)
	orc.global_position = Vector3(at.x, _ground(at.x, at.z) + 0.1, at.z)
	orc.died.connect(_on_died)
	return orc


func orcs() -> Array[Orc]:
	var list: Array[Orc] = []
	for node in get_children():
		if node is Orc and not (node as Orc).is_dead():
			list.append(node)
	return list


## Um orc gritou em `at`: os outros por perto vêm.
func alert(source: Orc, at: Vector3) -> void:
	for orc in orcs():
		if orc != source and orc.global_position.distance_to(source.global_position) < Tuning.ORC_SHOUT_RANGE:
			orc.alert(at)


## Só os mais perto do goblin atacam; os outros esperam rodeando.
func may_attack(orc: Orc) -> bool:
	var player := Game.player
	if player == null:
		return true
	var fighting: Array[Orc] = []
	for other in orcs():
		if other.state == Orc.State.COMBAT:
			fighting.append(other)
	fighting.sort_custom(func(a: Orc, b: Orc) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var index := fighting.find(orc)
	return index != -1 and index < Tuning.ORC_ATTACKERS_AT_ONCE


## Uma rota de patrulha: 5 a 6 pontos em volta do vale, em ordem de ângulo, fora da toca, da ruína
## e do vazio do norte.
func make_route() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var start := _rng.randf() * TAU
	var count := _rng.randi_range(5, 6)
	# Os troncos riscados pelo goblin chamam a patrulha (§9.4): a trilha dele é trilha para eles.
	var marked: Array[Vector3] = []
	var marks := get_tree().get_first_node_in_group(TreeMarks.GROUP) as TreeMarks
	var level := Game.current_level
	if marks != null and level != null and level.has_method("tree_base"):
		for tree: Variant in marks.marks:
			if _rng.randf() < Tuning.MARKED_TREE_ROUTE_CHANCE:
				var base: Vector3 = level.tree_base(int(tree))
				if _usable(Vector2(base.x, base.z)):
					marked.append(base + Vector3(1.2, 0.0, 0.0))
	for i in count:
		for attempt in 12:
			var angle := start + TAU * i / count + _rng.randf_range(-0.3, 0.3)
			var p := Vector2(cos(angle), sin(angle)) * _rng.randf_range(35.0, ForestLayout.VALLEY_RADIUS - 20.0)
			if _usable(p):
				points.append(Vector3(p.x, _ground(p.x, p.y), p.y))
				break
	points.append_array(marked)
	# Em ordem de ângulo em volta do vale: a rota dá a volta sem cruzar.
	points.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return wrapf(atan2(a.z, a.x) - start, 0.0, TAU) < wrapf(atan2(b.z, b.x) - start, 0.0, TAU))
	return points


func _usable(p: Vector2) -> bool:
	if p.distance_to(ForestLayout.CAVE_CENTER) < Tuning.ORC_CAVE_KEEP_OUT + 4.0:
		return false
	if p.distance_to(ForestLayout.RUINS) < Tuning.ORC_RUIN_KEEP_OUT + 4.0:
		return false
	if Story.has_flag(&"climate_cut") and p.y < Tuning.VOID_EDGE_Z + 10.0:
		return false
	return true


## Por onde os orcs entram (F14): [o ponto onde aparecem, o caminho que falta até o vale da toca].
## O caminho é o do desfiladeiro, vindo do vale deles; eles aparecem no ponto dele mais perto da
## toca que fique a pelo menos ORC_SPAWN_MIN_DISTANCE do goblin (no fim do desfiladeiro, se nenhum
## ficar).
func _entry() -> Array:
	var path := ForestLayout.gorge_path(true)
	var player := Game.player
	var start := 0
	for i in range(path.size() - 1, -1, -1):
		var distance := path[i].distance_to(Vector2(player.global_position.x, player.global_position.z)) if player != null else 999.0
		if distance >= Tuning.ORC_SPAWN_MIN_DISTANCE:
			start = i
			break
	var rest: Array[Vector3] = []
	for i in range(start + 1, path.size()):
		rest.append(Vector3(path[i].x, _ground(path[i].x, path[i].y), path[i].y))
	return [Vector3(path[start].x, 0.0, path[start].y), rest]


func _ground(x: float, z: float) -> float:
	var level := Game.current_level
	return float(level.ground_height(x, z)) if level != null and level.has_method("ground_height") else 0.0


# --- A Investida (F13, §9.3) ---------------------------------------------------------

func _raid_schedule() -> void:
	if raid_active or Story.has_flag(&"chief_dead") or Clock.day < Tuning.RAID_DAY:
		return
	if Clock.day - _last_raid_day < Tuning.RAID_INTERVAL:
		return
	if not Story.has_flag(&"raid_tonight"):
		if Clock.hour >= Tuning.RAID_WARN_HOUR and Clock.hour < Tuning.RAID_START_HOUR:
			warn_raid()
	elif Clock.hour >= Tuning.RAID_START_HOUR:
		start_raid()


## A trompa no acampamento: esta noite eles vêm. Daqui até o fim, não dá para dormir.
func warn_raid() -> void:
	Story.set_flag(&"raid_tonight", true)
	var camp := get_tree().get_first_node_in_group(OrcCamp.GROUP) as Node3D
	if camp != null:
		OccludedAudio.play_at(get_parent(), Orc.SHOUT, camp.global_position + Vector3.UP * 3.0, &"Ambience", 8.0, 60.0, 0.55)
	Events.notification_shown.emit("Uma trompa longe, a leste. Esta noite eles vêm até a toca.")


## Os orcs da Investida vêm pelo desfiladeiro, com tochas, e vão até a toca.
func start_raid() -> void:
	if raid_active:
		return
	Story.set_flag(&"raid_tonight", true)
	raid_active = true
	_last_raid_day = Clock.day
	_raid_size = _rng.randi_range(Tuning.RAID_SIZE.x, Tuning.RAID_SIZE.y)
	_raiders.clear()
	var mouth := Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y - ForestLayout.CAVE_DEPTH * 0.5 - 5.0)
	var inside := Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y)
	mouth.y = _ground(mouth.x, mouth.z)
	inside.y = _ground(inside.x, inside.z)
	var entry := _entry()
	var start: Vector3 = entry[0]
	var path: Array[Vector3] = entry[1]
	for i in _raid_size:
		var kind := &"warrior" if i % 2 == 1 else &"scout"
		var route: Array[Vector3] = [mouth, inside]
		var orc := spawn(kind, start + Vector3(float(i) * 1.5, 0.0, float(i % 2) * 1.5), route, true)
		orc.approach = path.duplicate()
		_raiders.append(orc)


func _raid_update() -> void:
	if not raid_active:
		return
	var alive: Array[Orc] = []
	for orc in _raiders:
		if is_instance_valid(orc) and not orc.is_dead() and orc.state != Orc.State.FLEE:
			alive.append(orc)
	var dawn := Clock.hour >= Tuning.RAID_END_HOUR and Clock.hour < 12.0 and Clock.day > _last_raid_day
	if alive.size() * 2 <= _raid_size or dawn:
		end_raid(alive)


func end_raid(survivors: Array[Orc]) -> void:
	for orc in survivors:
		orc._flee()
	raid_active = false
	_raiders.clear()
	Story.set_flag(&"raid_tonight", false)
	if Vitals.health > 0.0:
		Story.add_count(&"raids_won", 1)
		Story.add_vigilance(Tuning.VIGILANCE_RAID_WON)
		Events.notification_shown.emit("Os orcs recuaram. A toca aguentou.")


## Um orc entrou na luta com o goblin (F14): conta para a Vigilância e para as anotações.
func on_fight(orc: Orc) -> void:
	Story.trigger(&"orc", &"seen")
	var now := Time.get_ticks_msec() / 1000.0
	if now - _fight_clock < Tuning.FIGHT_VIGILANCE_COOLDOWN:
		return
	_fight_clock = now
	Story.add_vigilance(Tuning.VIGILANCE_FIGHT)
	if Game.player != null and Watchers.watching(Game.player.global_position):
		Story.add_vigilance(Tuning.VIGILANCE_FIGHT_SEEN)


func _on_died(dead: Orc) -> void:
	Story.add_count(&"orc_killed", 1)
	Story.trigger(&"orc", &"chief" if dead.kind == &"chief" else &"killed")
	if dead.kind == &"chief":
		Story.add_vigilance(Tuning.VIGILANCE_CHIEF)
	for orc in orcs():
		if orc.global_position.distance_to(dead.global_position) < 30.0:
			orc.lose_heart(0.35)


func save_data() -> Dictionary:
	return {"arrived_day": _arrived_day, "last_raid_day": _last_raid_day}


func load_data(data: Dictionary) -> void:
	_arrived_day = int(data.get("arrived_day", -1))
	_last_raid_day = int(data.get("last_raid_day", -99))
	# Uma Investida não volta do save: carregando no meio dela, a noite recomeça calma.
	Story.set_flag(&"raid_tonight", false)
