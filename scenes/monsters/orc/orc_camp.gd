class_name OrcCamp
extends Node3D
## O acampamento da Pedra Rachada (F13, docs/plano_combate.md §9.1; experimental): uma paliçada de
## troncos pontudos em volta de uma fogueira, duas tendas de couro, o tambor e o baú onde os orcs
## guardam o que levam (a bolsa do goblin morto perto deles). A entrada larga dá para o vale; atrás,
## falta um tronco: uma fresta onde só o goblin passa. De dia, dois orcs ficam de guarda.
##
## Filho da floresta (grupo "persist"): guarda o baú (itens e desgaste).

const GROUP := &"orc_camp"
const CAMPFIRE := preload("res://scenes/world/props/campfire.tscn")
const CHEST_SOUND := preload("res://assets/audio/real/craft_2.ogg")
## Raio da paliçada (m), largura da entrada e da fresta (m).
const RADIUS := 7.5
const GATE := 2.6
const GAP := 0.62

## O que está no baú: {"items": {...}, "wear": {...}}.
var chest := {}
var _chest_node: Node3D
var _guarded_day := -1
## O tambor (F14): o centro do couro e onde o tocador fica (no espaço do acampamento), quem bate agora.
var _drum_face := Vector3.ZERO
var _drum_stand := Vector3.ZERO
var _drummer: Orc
var _drum_check := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)


## O chão para o acampamento: o ponto mais perto de ForestLayout.ORC_CAMP sem árvore dentro da
## paliçada, pouco inclinado e longe da trilha (sempre o mesmo: a busca não sorteia nada).
static func pick_center(terrain: Terrain, vegetation: Vegetation) -> Vector2:
	var best := ForestLayout.ORC_CAMP
	var best_score := INF
	for x in range(-20, 21, 2):
		for z in range(-20, 21, 2):
			var p := ForestLayout.ORC_CAMP + Vector2(x, z)
			if p.length() > ForestLayout.VALLEY_RADIUS - RADIUS - 6.0 or p.y < Tuning.VOID_EDGE_Z + RADIUS + 8.0:
				continue
			if ForestLayout.distance_to_trail(p) < RADIUS + 2.0:
				continue
			if terrain.get_normal(p.x, p.y).y < 0.93:
				continue
			if vegetation.tree_near(Vector3(p.x, 0.0, p.y), RADIUS + 1.0) != -1:
				continue
			var score := p.distance_to(ForestLayout.ORC_CAMP)
			if score < best_score:
				best_score = score
				best = p
	return best


## Monta o acampamento em `center` (no chão do `terrain`).
func build(terrain: Terrain, center: Vector2) -> void:
	position = Vector3(center.x, terrain.get_height(center.x, center.y), center.y)
	var toward_valley := (-center).normalized()
	var gate_angle := atan2(toward_valley.y, toward_valley.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3460
	var builder := TreeBuilder.Builder.new()
	var bark := builder.tool_for(PropLook.bark())
	var body := StaticBody3D.new()
	body.set_meta(&"surface", &"wood")
	add_child(body)
	# A paliçada: um tronco a cada passo, inclinado para fora, com a ponta afiada.
	var circumference := TAU * RADIUS
	var count := int(circumference / 0.42)
	for i in count:
		var angle := TAU * i / count
		var from_gate := absf(angle_difference(angle, gate_angle))
		var from_back := absf(angle_difference(angle, gate_angle + PI))
		if from_gate * RADIUS < GATE * 0.5 or from_back * RADIUS < GAP * 0.5 + 0.2:
			continue
		var dir := Vector2(cos(angle), sin(angle))
		var at := dir * RADIUS
		var ground := terrain.get_height(center.x + at.x, center.y + at.y) - position.y
		var height := rng.randf_range(2.1, 2.7)
		var r := rng.randf_range(0.11, 0.15)
		var base := Vector3(at.x, ground - 0.2, at.y)
		var top := base + Vector3(dir.x * 0.18, height, dir.y * 0.18)
		TreeBuilder.add_branch(bark, base, top, r, r * 0.9, 6)
		TreeBuilder.add_branch(bark, top, top + Vector3(dir.x * 0.03, 0.25, dir.y * 0.03), r * 0.9, 0.01, 6)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r * 2.0, height, r * 2.0)
		shape.shape = box
		shape.position = base.lerp(top, 0.5)
		body.add_child(shape)
	# As tendas: cones de couro sobre uma vara.
	var leather := builder.tool_for(ArmorLook._mat(GoblinLook.LEATHER, Color(0.62, 0.55, 0.48)))
	for spot: Vector2 in [Vector2(3.6, 2.2), Vector2(-2.8, 3.4)]:
		var rotated := spot.rotated(gate_angle - PI * 0.5)
		var ground := terrain.get_height(center.x + rotated.x, center.y + rotated.y) - position.y
		var cone := CylinderMesh.new()
		cone.top_radius = 0.04
		cone.bottom_radius = 1.4
		cone.height = 2.2
		cone.radial_segments = 7
		cone.rings = 1
		leather.append_from(cone, 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rotated.x, ground + 1.05, rotated.y)))
		TreeBuilder.add_branch(bark, Vector3(rotated.x, ground, rotated.y), Vector3(rotated.x, ground + 2.5, rotated.y), 0.04, 0.03, 5)
		var tent := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 1.1
		cylinder.height = 1.6
		tent.shape = cylinder
		tent.position = Vector3(rotated.x, ground + 0.8, rotated.y)
		body.add_child(tent)
	# O tambor: um tronco oco com couro esticado em cima.
	var drum_spot := Vector2(-3.4, -1.6).rotated(gate_angle - PI * 0.5)
	var drum_ground := terrain.get_height(center.x + drum_spot.x, center.y + drum_spot.y) - position.y
	TreeBuilder.add_branch(bark, Vector3(drum_spot.x, drum_ground, drum_spot.y), Vector3(drum_spot.x, drum_ground + 0.7, drum_spot.y), 0.42, 0.4, 9)
	var skin := CylinderMesh.new()
	skin.top_radius = 0.43
	skin.bottom_radius = 0.43
	skin.height = 0.03
	skin.radial_segments = 9
	leather.append_from(skin, 0, Transform3D(Basis.IDENTITY, Vector3(drum_spot.x, drum_ground + 0.71, drum_spot.y)))
	_drum_face = Vector3(drum_spot.x, drum_ground + 0.72, drum_spot.y)
	var toward_fire := -drum_spot.normalized()
	_drum_stand = Vector3(drum_spot.x + toward_fire.x * 0.85, drum_ground, drum_spot.y + toward_fire.y * 0.85)
	var mesh := MeshInstance3D.new()
	mesh.name = "Camp"
	mesh.mesh = builder.commit()
	add_child(mesh)
	# A fogueira no meio (a mesma cena da toca; os orcs mantêm a lenha).
	var fire := CAMPFIRE.instantiate()
	fire.name = "Fire"
	add_child(fire)
	fire.position = Vector3(0.0, terrain.get_height(center.x, center.y) - position.y, 0.0)
	# O baú, perto da tenda maior.
	var chest_spot := Vector2(2.2, -0.6).rotated(gate_angle - PI * 0.5)
	_chest_node = OrcChest.new()
	_chest_node.name = "Chest"
	(_chest_node as OrcChest).camp = self
	add_child(_chest_node)
	_chest_node.position = Vector3(chest_spot.x, terrain.get_height(center.x + chest_spot.x, center.y + chest_spot.y) - position.y, chest_spot.y)
	_chest_node.rotation.y = -gate_angle


func _process(delta: float) -> void:
	var fire := get_node_or_null(^"Fire") as Campfire
	if fire != null and fire.fuel < 2.0:
		fire.fuel = 2.0
	_guard()
	_drum_check -= delta
	if _drum_check <= 0.0:
		_drum_check = 1.0
		_drum_keeper()


## O tambor (F14): o orc calmo mais perto dele vira o tocador (o chefe só na noite da Investida,
## quando o tambor bate mais rápido e não para). Sem orc, sem tambor.
func _drum_keeper() -> void:
	var raid := Story.has_flag(&"raid_tonight")
	if _drummer != null and is_instance_valid(_drummer) and _drummer.state == Orc.State.PATROL and _drummer.drum_at != Vector3.INF:
		_drummer.drum_bpm = Tuning.ORC_DRUM_RAID_BPM if raid else Tuning.SHELTER_BPM
		_drummer.drum_rest = 0.0 if raid else Tuning.ORC_DRUM_REST
		return
	if _drummer != null and is_instance_valid(_drummer):
		_drummer.drum_at = Vector3.INF
	_drummer = null
	var stand := to_global(_drum_stand)
	var best_distance := Tuning.ORC_DRUM_REACH
	for node in get_tree().get_nodes_in_group(Orc.GROUP):
		var orc := node as Orc
		if orc == null or orc.state != Orc.State.PATROL or orc.raider or (orc.kind == &"chief" and not raid):
			continue
		var distance := orc.global_position.distance_to(stand)
		if distance < best_distance:
			best_distance = distance
			_drummer = orc
	if _drummer != null:
		_drummer.drum_at = stand
		_drummer.drum_face = to_global(_drum_face)
		_drummer.drum_bpm = Tuning.ORC_DRUM_RAID_BPM if raid else Tuning.SHELTER_BPM
		_drummer.drum_rest = 0.0 if raid else Tuning.ORC_DRUM_REST


## Quem está batendo o tambor agora (null = ninguém).
func drummer() -> Orc:
	if _drummer != null and is_instance_valid(_drummer) and _drummer.drum_at != Vector3.INF:
		return _drummer
	return null


## De dia, do dia da chegada dos orcs em diante, dois ficam de guarda no acampamento.
func _guard() -> void:
	var band := get_tree().get_first_node_in_group(OrcBand.GROUP) as OrcBand
	if band == null or not band.enabled() or (DevTools.automated and not DevTools.orcs):
		return
	if Clock.day < Tuning.ORC_FIRST_DAY or _guarded_day == Clock.day:
		return
	if Clock.hour < Tuning.ORC_ARRIVE_HOUR or Clock.hour >= Tuning.ORC_LEAVE_HOUR - 1.0:
		return
	_guarded_day = Clock.day
	spawn_guards(band)


func spawn_guards(band: OrcBand) -> void:
	var loop: Array[Vector3] = []
	for i in 4:
		var angle := TAU * i / 4.0 + 0.4
		loop.append(global_position + Vector3(cos(angle), 0.0, sin(angle)) * RADIUS * 0.55)
	band.spawn(&"scout", loop[0], loop)
	band.spawn(&"warrior", loop[2], loop)
	# O chefe mora aqui, perto do fogo (F13), do dia da patrulha em diante e enquanto vive.
	if Clock.day >= Tuning.ORC_PATROL_DAY and not Story.has_flag(&"chief_dead"):
		spawn_chief(band)


func spawn_chief(band: OrcBand) -> Orc:
	return band.spawn(&"chief", global_position + Vector3(1.8, 0.0, 1.2))


## Os orcs trouxeram uma bolsa: junta ao que já está no baú.
func store(content: Dictionary) -> void:
	var items: Dictionary = chest.get("items", {})
	var wear: Dictionary = chest.get("wear", {})
	var new_items: Dictionary = content.get("items", {})
	var new_wear: Dictionary = content.get("wear", {})
	for item: String in new_items:
		items[item] = int(items.get(item, 0)) + int(new_items[item])
	for item: String in new_wear:
		var units: Array = wear.get(item, [])
		units.append_array(new_wear[item])
		wear[item] = units
	chest = {"items": items, "wear": wear}


func chest_count() -> int:
	var total := 0
	var items: Dictionary = chest.get("items", {})
	for item: String in items:
		total += int(items[item])
	return total


## O goblin abriu o baú: pega tudo.
func open_chest() -> void:
	if chest_count() == 0:
		return
	BagField.give_back(chest)
	chest = {}
	OccludedAudio.play_at(self, CHEST_SOUND, _chest_node.global_position + Vector3.UP * 0.4, &"World", -2.0, 4.0, 0.8)
	Events.noise_made.emit(_chest_node.global_position, 10.0)
	Events.notification_shown.emit("Pegou o que estava no baú dos orcs.")


func save_data() -> Dictionary:
	return {"chest": chest.duplicate(true), "guarded_day": _guarded_day}


func load_data(data: Dictionary) -> void:
	chest = (data.get("chest", {}) as Dictionary).duplicate(true)
	_guarded_day = int(data.get("guarded_day", -1))
