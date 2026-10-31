class_name OrcSigns
extends Node3D
## Os sinais dos orcs antes de eles chegarem (docs/plano_combate.md §9.2; experimental): uma flecha
## grande demais fincada num pinheiro perto da clareira, os ossos de um cervo esfolado a faca e uma
## fila de pegadas de bota que passa por perto (carimbadas de novo quando o goblin chega, para
## estarem sempre frescas). Do primeiro dia; ficam até o goblin pegar (a flecha e os ossos).
## Filho da floresta (grupo "persist"): guarda o que já foi pego.

const GROUP := &"orc_signs"
const PICK_SOUND := preload("res://assets/audio/real/pickup_3.ogg")
## Onde ficam: a flecha num pinheiro perto da clareira; os ossos e as pegadas no caminho do leste.
const ARROW_NEAR := Vector2(26.0, 14.0)
const CARCASS_AT := Vector2(44.0, -4.0)
const BOOT_LINE := [Vector2(36.0, -10.0), Vector2(52.0, -20.0)]

var arrow_taken := false
var bones_taken := false

var _arrow: SignSpot
var _bones: SignSpot
var _stamped := -999.0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)


func build(terrain: Terrain, vegetation: Vegetation) -> void:
	# A flecha: no pinheiro vivo mais perto de ARROW_NEAR, na altura do peito de um orc.
	var tree := -1
	var best := 40.0
	for i in vegetation.trees.size():
		var candidate: Vegetation.TreeInfo = vegetation.trees[i]
		var distance := Vector2(candidate.base.x, candidate.base.z).distance_to(ARROW_NEAR)
		if not candidate.dead and not candidate.fallen and distance < best:
			best = distance
			tree = i
	if tree != -1:
		var info: Vegetation.TreeInfo = vegetation.trees[tree]
		var side := (Vector3(ARROW_NEAR.x, info.base.y, ARROW_NEAR.y) - info.base)
		side.y = 0.0
		side = side.normalized() if side.length_squared() > 0.01 else Vector3.FORWARD
		_arrow = SignSpot.new()
		_arrow.prompt = "Arrancar a flecha do tronco"
		_arrow.taken.connect(_on_arrow)
		add_child(_arrow)
		_arrow.global_position = info.base + side * (info.radius + 0.02) + Vector3.UP * 1.4
		var mesh := MeshInstance3D.new()
		mesh.mesh = BowMesh.arrow(true)
		# Grande demais para o arco do goblin: uma vez e meia a flecha dele, cravada fundo.
		mesh.scale = Vector3.ONE * 1.6
		mesh.basis = Basis.looking_at(-side + Vector3.DOWN * 0.15, Vector3.UP).scaled(Vector3.ONE * 1.6)
		mesh.position = side * 0.2
		_arrow.add_child(mesh)
	# Os ossos: um cervo esfolado, as costelas para cima e uma mancha escura no chão.
	_bones = SignSpot.new()
	_bones.prompt = "Examinar os ossos do cervo"
	_bones.taken.connect(_on_bones)
	add_child(_bones)
	_bones.global_position = Vector3(CARCASS_AT.x, terrain.get_height(CARCASS_AT.x, CARCASS_AT.y), CARCASS_AT.y)
	_bones.add_child(_carcass())
	_refresh()


func _process(_delta: float) -> void:
	var player := Game.player
	if player == null or Clock.day > Tuning.ORC_FIRST_DAY + 2:
		return
	var near := Vector2(player.global_position.x, player.global_position.z)
	var line_a: Vector2 = BOOT_LINE[0]
	var line_b: Vector2 = BOOT_LINE[1]
	var closest := Geometry2D.get_closest_point_to_segment(near, line_a, line_b)
	var now := Time.get_ticks_msec() / 1000.0
	if near.distance_to(closest) < 25.0 and now - _stamped > Tuning.TRACK_SECONDS * 0.6:
		_stamped = now
		_stamp_line(line_a, line_b)


## Uma fila de pegadas de bota de `a` a `b`, passos de 0,9 m alternando os lados.
func _stamp_line(a: Vector2, b: Vector2) -> void:
	var level := Game.current_level
	if level == null:
		return
	var direction := (b - a).normalized()
	var side := Vector2(-direction.y, direction.x)
	var yaw := atan2(direction.x, direction.y)
	var steps := int(a.distance_to(b) / 0.9)
	for i in steps:
		var p := a + direction * (0.9 * i) + side * (0.16 if i % 2 == 0 else -0.16)
		var at := Vector3(p.x, float(level.ground_height(p.x, p.y)), p.y)
		Tracks.stamp(at, Vector3.UP, yaw, Tuning.ORC_BOOT_SIZE, &"orc")


func _on_arrow() -> void:
	arrow_taken = true
	Inventory.add(&"iron_scrap")
	OccludedAudio.play_at(self, PICK_SOUND, _arrow.global_position, &"World", -4.0, 3.0, 0.8)
	Events.notification_shown.emit("Uma flecha grande demais para o seu arco, com a ponta de ferro batido. +1 sucata")
	Story.add_note("Achei uma flecha num tronco, do tamanho de uma lança curta. Quem atira uma coisa dessas?")
	_refresh()


func _on_bones() -> void:
	bones_taken = true
	Inventory.add(&"bone", 2)
	OccludedAudio.play_at(self, PICK_SOUND, _bones.global_position, &"World", -4.0, 3.0)
	Events.notification_shown.emit("Os ossos de um cervo, ainda frescos. O couro foi tirado com faca, não com dente. +2 ossos")
	_refresh()


func _refresh() -> void:
	if _arrow != null:
		_arrow.visible = not arrow_taken
		_arrow.active = not arrow_taken
	if _bones != null:
		_bones.visible = not bones_taken
		_bones.active = not bones_taken


## As costelas para cima, a espinha e o crânio, em osso, sobre uma mancha escura.
static func _carcass() -> MeshInstance3D:
	var builder := TreeBuilder.Builder.new()
	var bone := builder.tool_for(PropLook.bone())
	TreeBuilder.add_branch(bone, Vector3(0.0, 0.08, -0.5), Vector3(0.0, 0.1, 0.55), 0.03, 0.025, 5)
	for i in 7:
		var z := -0.3 + i * 0.09
		for side: float in [-1.0, 1.0]:
			var mid := Vector3(side * 0.16, 0.22, z)
			TreeBuilder.add_branch(bone, Vector3(0.0, 0.1, z), mid, 0.012, 0.01, 4)
			TreeBuilder.add_branch(bone, mid, Vector3(side * 0.2, 0.04, z + 0.03), 0.01, 0.008, 4)
	TreeBuilder.add_branch(bone, Vector3(0.0, 0.1, 0.55), Vector3(0.05, 0.14, 0.8), 0.06, 0.035, 6)
	var blood := builder.tool_for(ArmorLook._mat(preload("res://assets/textures/ground_dirt.png"), Color(0.3, 0.12, 0.1)))
	var stain := CylinderMesh.new()
	stain.top_radius = 0.7
	stain.bottom_radius = 0.7
	stain.height = 0.01
	stain.radial_segments = 9
	blood.append_from(stain, 0, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.4)), Vector3(0.0, 0.01, 0.0)))
	var node := MeshInstance3D.new()
	node.mesh = builder.commit()
	return node


func save_data() -> Dictionary:
	return {"arrow_taken": arrow_taken, "bones_taken": bones_taken}


func load_data(data: Dictionary) -> void:
	arrow_taken = bool(data.get("arrow_taken", false))
	bones_taken = bool(data.get("bones_taken", false))
	_refresh()
