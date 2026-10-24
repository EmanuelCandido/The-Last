class_name CairnField
extends Node3D
## Os marcos de pedra (F10), salvos com a partida (grupo "persist"). A receita "Marco de pedras"
## empilha um aos pés do goblin (CraftAbility, especial &"cairn"): uma torre de pedras da maior
## para a menor, alta o bastante para aparecer na neblina e marcar um caminho de volta. Passando
## de Tuning.CAIRN_MAX, o mais velho se desfaz. Filho de Props.

const GROUP := &"cairns"
const BUILD_SOUND := preload("res://assets/audio/sfx/stone_click_2.wav")

var terrain: Terrain


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)


## Empilha um marco em `at` (no chão).
func build_at(at: Vector3, sound := true) -> void:
	while get_child_count() >= Tuning.CAIRN_MAX:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var cairn := Node3D.new()
	cairn.name = "Cairn"
	add_child(cairn)
	var ground := terrain.get_height(at.x, at.z) if terrain != null else at.y
	cairn.global_position = Vector3(at.x, ground, at.z)
	var height := _stack(cairn)
	_collider(cairn, height)
	if sound:
		# O som fica no pai: aqui dentro só marcos.
		for i in 3:
			OccludedAudio.play_at(get_parent(), BUILD_SOUND, cairn.global_position + Vector3.UP * (0.2 + 0.2 * i), &"World", -6.0 + i, 3.0, 0.8 + 0.1 * i)


## As pedras, uma sobre a outra, cada uma um pouco torta e fora do eixo. Devolve a altura.
func _stack(cairn: Node3D) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(cairn.global_position.x * 10.0), roundi(cairn.global_position.z * 10.0)))
	var top := 0.0
	var radius := Tuning.CAIRN_BASE_RADIUS
	for i in Tuning.CAIRN_STONES:
		var stone := MeshInstance3D.new()
		stone.mesh = ThrownStone.stone_mesh(rng.randi(), radius)
		cairn.add_child(stone)
		# A malha achata a esfera para 55–80% em Y: a meia altura fica perto de 0,65 do raio.
		var half := radius * 0.65
		var drift := Vector2.from_angle(rng.randf() * TAU) * radius * 0.15
		stone.position = Vector3(drift.x, top + half * 0.85, drift.y)
		stone.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		top += half * 1.7
		radius *= rng.randf_range(0.78, 0.86)
	return top


## Um cilindro na camada do mundo: ninguém atravessa o marco.
func _collider(cairn: Node3D, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = Tuning.CAIRN_BASE_RADIUS * 0.9
	cylinder.height = height
	shape.shape = cylinder
	shape.position = Vector3.UP * height * 0.5
	# Os passos em cima (se alguém subir) soam como pedra (Footsteps lê o meta).
	shape.set_meta(&"surface", &"stone")
	body.add_child(shape)
	cairn.add_child(body)


## Marco mais perto de `p` (no plano), ou Vector3.INF se não houver nenhum.
func nearest(p: Vector3) -> Vector3:
	var best := Vector3.INF
	for cairn in get_children():
		var at := (cairn as Node3D).global_position
		if best == Vector3.INF or Vector2(at.x - p.x, at.z - p.z).length() < Vector2(best.x - p.x, best.z - p.z).length():
			best = at
	return best


func save_data() -> Dictionary:
	var list := []
	for cairn in get_children():
		var node := cairn as Node3D
		list.append([node.global_position.x, node.global_position.z])
	return {"cairns": list}


func load_data(data: Dictionary) -> void:
	for cairn in get_children():
		remove_child(cairn)
		cairn.queue_free()
	for entry: Array in data.get("cairns", []):
		if entry.size() >= 2:
			build_at(Vector3(float(entry[0]), 0.0, float(entry[1])), false)
