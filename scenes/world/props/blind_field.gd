class_name BlindField
extends Node3D
## As tocaias de galhos (§8b-C), salvas com a partida (grupo "persist"). A receita "Tocaia de
## galhos" monta uma aos pés do goblin (CraftAbility, especial &"blind"); passando de
## Tuning.BLIND_MAX, a mais velha se desfaz. Agachado dentro de uma (Tuning.BLIND_RADIUS), o goblin
## quase não é visto: Player.visibility_factors[&"blind"] = Tuning.BLIND_VISIBILITY.
## Filho de Props.

const GROUP := &"blinds"
const BUILD_SOUND := preload("res://assets/audio/real/wood_creak_2.ogg")

var terrain: Terrain


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)


func _physics_process(_delta: float) -> void:
	var player := Game.player
	if player == null:
		return
	var inside := false
	if player.is_crouching():
		var at := Vector2(player.global_position.x, player.global_position.z)
		for blind in get_children():
			if at.distance_to(Vector2((blind as Node3D).global_position.x, (blind as Node3D).global_position.z)) < Tuning.BLIND_RADIUS:
				inside = true
				break
	if inside:
		player.visibility_factors[&"blind"] = Tuning.BLIND_VISIBILITY
	else:
		player.visibility_factors.erase(&"blind")


## Monta uma tocaia em `at` (no chão), com a abertura para `facing` (de onde o goblin olha).
func build_at(at: Vector3, facing: float, sound := true) -> void:
	while get_child_count() >= Tuning.BLIND_MAX:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var blind := Node3D.new()
	blind.name = "Blind"
	add_child(blind)
	blind.global_position = Vector3(at.x, terrain.get_height(at.x, at.z) if terrain != null else at.y, at.z)
	blind.rotation.y = facing
	_build_branches(blind)
	if sound:
		# O som fica no pai: aqui dentro só tocaias.
		OccludedAudio.play_at(get_parent(), BUILD_SOUND, blind.global_position + Vector3.UP * 0.5, &"World", -4.0, 3.0)


## Um anel de galhos tortos inclinados para dentro (casca das árvores), com ramos de pinheiro
## por cima (cartões do foliage.gdshader, que balançam com o vento); a frente (+Z) fica com uma
## fresta para olhar e atirar.
func _build_branches(blind: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(blind.global_position)
	var builder := TreeBuilder.Builder.new()
	var bark_st := builder.tool_for(PropLook.bark())
	var bough_st := builder.tool_for(PropLook.needles())
	var count := 16
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.08, 0.08)
		# A fresta: deixa um vão estreito na frente.
		if absf(wrapf(angle, -PI, PI)) < 0.3:
			continue
		var out := Vector3(sin(angle), 0.0, cos(angle))
		var base := out * rng.randf_range(1.05, 1.2) + Vector3.DOWN * 0.05
		# Deita o topo para dentro: o galho sobe e volta para o centro.
		var dir := (Vector3.UP - out * rng.randf_range(0.35, 0.6)).normalized()
		var stick := TreeBuilder.crooked_line(rng, base, dir, rng.randf_range(1.1, 1.45), 3, 0.08)
		for s in stick.size() - 1:
			TreeBuilder.add_branch(bark_st, stick[s], stick[s + 1], 0.03 - s * 0.006, 0.024 - s * 0.006, 5)
		# Ramos encostados por fora, deitados ao longo do anel: é o que esconde.
		for b in 2:
			var at: Vector3 = stick[b + 1].lerp(stick[b + 2], rng.randf()) + out * 0.08
			var along := (Vector3(-out.z, 0.0, out.x) * (1.0 if rng.randf() < 0.5 else -1.0) + Vector3.DOWN * rng.randf_range(0.3, 0.8)).normalized()
			_bough(bough_st, at - along * 0.35, along, rng.randf_range(0.75, 1.0), 0.6)
	blind.add_child(_instance(builder.commit()))


## Ramo de pinheiro: dois cartões cruzados ao longo de `dir`, como os galhos das árvores.
func _bough(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float) -> void:
	var tip := base + dir * length
	var flat := dir.cross(Vector3.UP).normalized() * width * 0.5
	var upright := dir.cross(flat).normalized() * width * 0.3
	for side: Vector3 in [flat, upright]:
		var corners := [base - side, base + side, tip + side, tip - side]
		var normals := [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
		TreeBuilder.add_card(st, corners, [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [0.0, 0.0, 0.5, 0.5], normals)


func _instance(mesh: ArrayMesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node


func save_data() -> Dictionary:
	var list := []
	for blind in get_children():
		var node := blind as Node3D
		list.append([node.global_position.x, node.global_position.z, node.rotation.y])
	return {"blinds": list}


func load_data(data: Dictionary) -> void:
	for blind in get_children():
		remove_child(blind)
		blind.queue_free()
	for entry: Array in data.get("blinds", []):
		if entry.size() >= 3:
			build_at(Vector3(float(entry[0]), 0.0, float(entry[1])), float(entry[2]), false)
