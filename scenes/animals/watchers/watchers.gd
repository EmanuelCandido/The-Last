class_name Watchers
extends Node3D
## Os olhos do Zelador na floresta (§5), ligados a partir do Ato II:
## - sentinelas: um corvo sempre pousado na boca da caverna e outro no ninho da ruína
##   (somem com o flag "blind_spot", o ponto cego do R2; abatido, volta no dia seguinte);
## - espiões: de tempos em tempos um corvo pousa perto do goblin e fica olhando
##   (com Vigilância alta, o dobro de vezes e mais perto);
## - o cervo branco: com Vigilância ≥ Tuning.VIGILANCE_WHITE_DEER, um por dia.
## Quem precisa saber se o Zelador está vendo pergunta Watchers.watching(ponto).
## A pista do corvo que encara (Clues) também pousa um corvo daqui.

const GROUP := &"watchers"
## Pousado "para sempre" (a sentinela só sai abatida ou com o ponto cego).
const FOREVER := 1.0e9

var terrain: Terrain

## Sentinela por lugar (&"cave", &"ruin") e o dia em que foi abatida.
var _sentinels := {}
var _sentinel_shot_day := {}
var _spy_timer := 40.0
var _white_deer: WhiteDeer
var _white_day := -1


func _ready() -> void:
	add_to_group(GROUP)
	Clock.day_started.connect(func(_day: int) -> void: _try_white_deer())


func _process(delta: float) -> void:
	if Game.player == null or Game.resting or terrain == null:
		return
	var active := Story.act >= Tuning.VIGILANCE_FROM_ACT
	_update_sentinels(active)
	if not active:
		return
	_spy_timer -= delta
	if _spy_timer <= 0.0:
		_spy_timer = Tuning.SPY_INTERVAL * (0.5 if Story.vigilance >= Tuning.VIGILANCE_MORE_CROWS else 1.0)
		_land_spy()


## Algum corvo pousado vê `point` agora.
static func watching(point: Vector3) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for node in tree.get_nodes_in_group(GROUP):
		for child in (node as Node).get_children():
			if child is Crow and (child as Crow).sees(point):
				return true
	return false


## Pousa um corvo em `at`, olhando `target` por `seconds`. `silent` = sem crocitar.
func perch_crow(at: Vector3, target: Node3D, seconds: float, silent := false) -> Crow:
	var crow := Crow.new()
	crow.terrain = terrain
	crow.silent = silent
	add_child(crow)
	crow.perch(at, target, seconds)
	return crow


## Ponto no chão a `distance` do goblin, de preferência na frente da câmera, fora da caverna,
## em chão firme e sem capim alto (no capim o corvo some). Vector3.INF se não achar.
func ground_spot_near_player(distance: float) -> Vector3:
	var player := Game.player
	var ahead := player.aim_direction()
	var base := atan2(ahead.x, ahead.z)
	var level := Game.current_level
	for attempt in 24:
		var angle := base + randf_range(-1.0, 1.0) * (0.6 + attempt * 0.12)
		var p := Vector2(player.global_position.x, player.global_position.z) + Vector2(sin(angle), cos(angle)) * distance
		if p.length() > ForestLayout.VALLEY_RADIUS - 5.0 or ForestLayout.cave_ellipse(p) < 1.3:
			continue
		if terrain.get_normal(p.x, p.y).y < 0.8:
			continue
		var ground := Vector3(p.x, terrain.get_height(p.x, p.y), p.y)
		if level != null and level.has_method("cover_at") and float(level.cover_at(ground)) > 0.2 and attempt < 20:
			continue
		return ground
	return Vector3.INF


## Para testes e para a Vigilância: o cervo branco aparece agora (um só por vez).
func spawn_white_deer() -> WhiteDeer:
	if _white_deer != null and is_instance_valid(_white_deer) and _white_deer.state != Animal.State.DEAD:
		return _white_deer
	var player := Vector2(Game.player.global_position.x, Game.player.global_position.z)
	var home := ForestLayout.MEADOW
	for attempt in 16:
		var p := player + Vector2.from_angle(randf() * TAU) * randf_range(35.0, 50.0)
		if p.length() < ForestLayout.VALLEY_RADIUS - 15.0 and ForestLayout.cave_ellipse(p) > 2.0 and terrain.get_normal(p.x, p.y).y > 0.85:
			home = p
			break
	_white_deer = WhiteDeer.new()
	get_parent().add_child(_white_deer)
	_white_deer.setup(terrain, home, randi())
	return _white_deer


func _try_white_deer() -> void:
	if Story.vigilance < Tuning.VIGILANCE_WHITE_DEER or _white_day == Clock.day or Game.player == null:
		return
	_white_day = Clock.day
	spawn_white_deer()


func _sentinel_points() -> Dictionary:
	var points := {&"cave": _ground(ForestLayout.CAVE_CROW)}
	var ruin := get_tree().get_first_node_in_group(Ruin.GROUP) as Ruin
	if ruin != null:
		points[&"ruin"] = ruin.nest_point()
	return points


func _update_sentinels(active: bool) -> void:
	var points := _sentinel_points()
	for spot: StringName in points:
		var crow: Crow = _sentinels.get(spot)
		var alive := crow != null and is_instance_valid(crow) and not crow.dead
		var want := active and not Story.has_flag(&"blind_spot")
		if want and not alive and _sentinel_shot_day.get(spot, -1) != Clock.day:
			crow = perch_crow(points[spot], Game.player, FOREVER)
			crow.shot.connect(func() -> void: _sentinel_shot_day[spot] = Clock.day)
			_sentinels[spot] = crow
		elif not want and alive:
			crow.leave()
			_sentinels.erase(spot)


func _land_spy() -> void:
	if Game.player == null or Clock.night() > 0.7:
		return
	var level := Game.current_level
	if level != null and level.has_method("indoor_at") and float(level.indoor_at(Game.player.global_position)) > 0.2:
		return
	var close := Story.vigilance >= Tuning.VIGILANCE_MORE_CROWS
	var spot := ground_spot_near_player(Tuning.SPY_LAND_DISTANCE_CLOSE if close else Tuning.SPY_LAND_DISTANCE)
	if spot != Vector3.INF:
		perch_crow(spot, Game.player, Tuning.SPY_WATCH_SECONDS)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.get_height(p.x, p.y), p.y)
