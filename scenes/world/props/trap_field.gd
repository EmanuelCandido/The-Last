class_name TrapField
extends Node3D
## As armadilhas do goblin (F13, docs/plano_combate.md §5.5; experimental): estacas fincadas, que
## ferem a perna de quem passa correndo por cima (orc ou lobo), e a corda de ossos, que bate quando
## algo passa (um alarme que se ouve de longe). Montadas pela lista de fabricar aos pés do goblin.
## Filho da floresta (grupo "persist"): guarda onde estão e quantos golpes as estacas aguentam.

const GROUP := &"trap_field"
const RATTLE := preload("res://assets/audio/sfx/stone_click_2.wav")
const STAKE_HIT := Arrow.HIT_FLESH

## [{"kind": &"stakes"|&"bones"|&"log", "at": [x, y, z], "yaw": f, "uses": n, "tree": id}]
var traps: Array[Dictionary] = []
var _nodes: Array[Node3D] = []
var _cooldown := {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)


## Monta a armadilha `kind` em `at`, de frente para `yaw`. Devolve false se já há demais. O tronco
## armado (&"log") leva a árvore seca `tree`: quem passa pela corda em `at` derruba ela.
func build_at(kind: StringName, at: Vector3, yaw: float, tree := -1) -> bool:
	var same := traps.filter(func(trap: Dictionary) -> bool: return trap.kind == kind).size()
	var limit := Tuning.STAKES_MAX if kind == &"stakes" else Tuning.BONE_ROPES_MAX
	if same >= limit:
		return false
	traps.append({"kind": kind, "at": [at.x, at.y, at.z], "yaw": yaw, "uses": Tuning.STAKES_USES if kind == &"stakes" else 1 if kind == &"log" else 999, "tree": tree})
	_rebuild()
	return true


func _physics_process(delta: float) -> void:
	for key: Variant in _cooldown.keys():
		_cooldown[key] = float(_cooldown[key]) - delta
		if float(_cooldown[key]) <= 0.0:
			_cooldown.erase(key)
	if traps.is_empty():
		return
	var spent := false
	for i in traps.size():
		var trap := traps[i]
		var at := _point(trap)
		var radius := Tuning.LOG_TRIGGER_RADIUS if trap.kind == &"log" else Tuning.TRAP_RADIUS
		for victim in _victims(at, radius):
			var key := "%d:%d" % [i, victim.get_instance_id()]
			if _cooldown.has(key):
				continue
			_cooldown[key] = 3.0
			if trap.kind == &"log":
				_drop_log(trap, at)
				trap.uses = 0
				spent = true
				break
			if trap.kind == &"stakes":
				if _speed(victim) > 2.0:
					_wound(victim, at)
					trap.uses = int(trap.uses) - 1
					if int(trap.uses) <= 0:
						spent = true
			else:
				OccludedAudio.play_at(get_parent(), RATTLE, at + Vector3.UP * 0.4, &"World", 2.0, 14.0, 0.7)
	if spent:
		traps = traps.filter(func(trap: Dictionary) -> bool: return int(trap.uses) > 0)
		_rebuild()


## Quem pode cair nela: orcs e lobos vivos (o goblin conhece as dele).
func _victims(at: Vector3, radius: float) -> Array[Node3D]:
	var list: Array[Node3D] = []
	for orc in get_tree().get_nodes_in_group(Orc.GROUP):
		if not (orc as Orc).is_dead() and (orc as Node3D).global_position.distance_to(at) < radius:
			list.append(orc)
	for node in get_tree().get_nodes_in_group(&"animals"):
		if node is Wolf and (node as Animal).state != Animal.State.DEAD and (node as Node3D).global_position.distance_to(at) < radius:
			list.append(node)
	return list


## A corda foi puxada: a árvore seca cai por cima da trilha e acerta quem está embaixo.
func _drop_log(trap: Dictionary, at: Vector3) -> void:
	var level := Game.current_level
	var tree := int(trap.get("tree", -1))
	if level == null or tree < 0 or not level.has_method("tree_standing") or not level.tree_standing(tree):
		return
	var vegetation: Vegetation = level._vegetation
	var info: Vegetation.TreeInfo = vegetation.trees[tree]
	# Cai para o lado da corda (o _fell_tree derruba para longe de `from`).
	var toward := Vector3(at.x - info.base.x, 0.0, at.z - info.base.z).normalized()
	vegetation._fell_tree(info, info.base - toward)
	var line_end := info.base + toward * 6.0
	get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
		for victim in _victims((info.base + line_end) * 0.5, 4.0):
			var p := Geometry3D.get_closest_point_to_segment(victim.global_position, info.base, line_end)
			if p.distance_to(victim.global_position) > Tuning.LOG_HIT_RADIUS:
				continue
			if victim is Orc:
				(victim as Orc).strike(Tuning.LOG_DAMAGE, &"blunt", victim.global_position + Vector3.UP * 1.2, toward, 2.0)
			elif victim is Animal:
				(victim as Animal).take_hit(1.0, victim.global_position + Vector3.UP * 0.5, toward, Tuning.LOG_DAMAGE))


func _speed(victim: Node3D) -> float:
	if victim is Orc:
		return Vector2((victim as Orc).velocity.x, (victim as Orc).velocity.z).length()
	if victim is Animal:
		return (victim as Animal).speed
	return 0.0


func _wound(victim: Node3D, at: Vector3) -> void:
	OccludedAudio.play_at(get_parent(), STAKE_HIT.pick_random(), at + Vector3.UP * 0.3, &"World", 0.0, 5.0, 0.8)
	if victim is Orc:
		(victim as Orc).strike(Tuning.STAKES_DAMAGE, &"pierce", victim.global_position + Vector3.UP * 0.3, Vector3.UP, 0.4)
	elif victim is Animal:
		(victim as Animal).take_hit(0.5, victim.global_position + Vector3.UP * 0.3, Vector3.UP, Tuning.STAKES_DAMAGE)


func _point(trap: Dictionary) -> Vector3:
	var at: Array = trap.at
	return Vector3(float(at[0]), float(at[1]), float(at[2]))


func _rebuild() -> void:
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	for trap in traps:
		var node := MeshInstance3D.new()
		node.mesh = _stakes_mesh() if trap.kind == &"stakes" else _log_mesh(trap) if trap.kind == &"log" else _bones_mesh()
		add_child(node)
		node.global_position = _point(trap)
		node.rotation.y = float(trap.yaw)
		_nodes.append(node)


## A corda de tendão do tronco armado: da trilha até a árvore seca, baixinha.
func _log_mesh(trap: Dictionary) -> ArrayMesh:
	var builder := TreeBuilder.Builder.new()
	var rope := builder.tool_for(PropLook.bark())
	var level := Game.current_level
	var at := _point(trap)
	var end := at + Vector3(1.0, 0.0, 0.0)
	if level != null and level.has_method("tree_base") and int(trap.get("tree", -1)) >= 0:
		end = level.tree_base(int(trap.tree))
	var local_end := Basis(Vector3.UP, -float(trap.yaw)) * (end - at)
	TreeBuilder.add_branch(rope, Vector3(-0.4, 0.2, 0.0), local_end + Vector3.UP * 0.5, 0.006, 0.006, 3)
	TreeBuilder.add_branch(rope, Vector3(-0.4, -0.05, 0.0), Vector3(-0.4, 0.25, 0.0), 0.02, 0.015, 4)
	return builder.commit()


static var _stakes: ArrayMesh
static var _bones: ArrayMesh


## Cinco paus afiados fincados em leque, inclinados para fora.
static func _stakes_mesh() -> ArrayMesh:
	if _stakes != null:
		return _stakes
	var builder := TreeBuilder.Builder.new()
	var bark := builder.tool_for(PropLook.bark())
	for i in 5:
		var x := -0.4 + i * 0.2
		var base := Vector3(x, -0.1, 0.0)
		var tip := Vector3(x * 1.2, 0.5 + 0.08 * sin(i * 2.1), 0.28)
		TreeBuilder.add_branch(bark, base, tip, 0.035, 0.004, 5)
	_stakes = builder.commit()
	return _stakes


## Dois paus baixos e uma corda de tendão com ossos pendurados.
static func _bones_mesh() -> ArrayMesh:
	if _bones != null:
		return _bones
	var builder := TreeBuilder.Builder.new()
	var bark := builder.tool_for(PropLook.bark())
	var bone := builder.tool_for(PropLook.bone())
	for x: float in [-0.7, 0.7]:
		TreeBuilder.add_branch(bark, Vector3(x, -0.05, 0.0), Vector3(x, 0.35, 0.0), 0.025, 0.02, 5)
	TreeBuilder.add_branch(bark, Vector3(-0.7, 0.3, 0.0), Vector3(0.7, 0.3, 0.0), 0.004, 0.004, 3)
	for i in 4:
		var x := -0.45 + i * 0.3
		TreeBuilder.add_branch(bone, Vector3(x, 0.3, 0.0), Vector3(x + 0.02, 0.18, 0.01), 0.012, 0.009, 4)
	_bones = builder.commit()
	return _bones


func save_data() -> Dictionary:
	return {"traps": traps.duplicate(true)}


func load_data(data: Dictionary) -> void:
	traps.clear()
	for trap: Dictionary in data.get("traps", []):
		traps.append(trap)
	_rebuild()
