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


## Um anel de galhos inclinados para dentro, com ramos de folha por cima; a frente (+Z) fica com
## uma fresta para olhar e atirar.
func _build_branches(blind: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(blind.global_position)
	var bark := Animal.flat_material(Color(0.24, 0.18, 0.12))
	var leaves := Animal.flat_material(Color(0.2, 0.26, 0.15))
	var count := 16
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.08, 0.08)
		# A fresta: deixa um vão estreito na frente.
		if absf(wrapf(angle, -PI, PI)) < 0.3:
			continue
		var base := Vector3(sin(angle), 0.0, cos(angle)) * 1.15
		var stick := MeshInstance3D.new()
		var box := BoxMesh.new()
		var length := rng.randf_range(1.1, 1.45)
		box.size = Vector3(0.05, length, 0.05)
		stick.mesh = box
		stick.material_override = bark
		blind.add_child(stick)
		stick.position = base * 0.82 + Vector3.UP * length * 0.45
		# Com o giro em Y, o +Z local aponta para fora: girar em X para trás deita o topo para dentro.
		stick.rotation = Vector3(0.0, angle, 0.0)
		stick.rotate_object_local(Vector3.RIGHT, -rng.randf_range(0.35, 0.55))
		if i % 2 == 0:
			var bough := MeshInstance3D.new()
			var plate := BoxMesh.new()
			plate.size = Vector3(0.55, 0.06, 0.5)
			bough.mesh = plate
			bough.material_override = leaves
			blind.add_child(bough)
			bough.position = base * 0.75 + Vector3.UP * rng.randf_range(0.55, 0.9)
			bough.rotation = Vector3(rng.randf_range(-0.6, -0.3), angle, rng.randf_range(-0.2, 0.2))


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
