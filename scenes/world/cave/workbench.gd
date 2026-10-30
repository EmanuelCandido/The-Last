class_name Workbench
extends Node3D
## A bancada da toca (F11, plano_combate §6.2): uma laje de pedra sobre dois troncos, com uma pedra
## de amolar. Nasce desmontada e aparece quando o goblin a fabrica (receita especial &"bench", só
## dentro da caverna). Perto dela, a lista de fabricar mostra as receitas de bancada e os consertos.
## Filho da Cave (grupo "persist").

const GROUP := &"workbench"

var built := false

var _mesh: MeshInstance3D
var _body: StaticBody3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)
	_build()
	_refresh()


## A bancada mais perto de `point` a menos de `radius` (null se não há, ou se não foi montada).
static func near(tree: SceneTree, point: Vector3, radius: float) -> Workbench:
	for node in tree.get_nodes_in_group(GROUP):
		var bench := node as Workbench
		if bench.built and bench.global_position.distance_to(point) < radius:
			return bench
	return null


func build_now() -> void:
	built = true
	_refresh()


func save_data() -> Dictionary:
	return {"built": built}


func load_data(data: Dictionary) -> void:
	built = bool(data.get("built", false))
	_refresh()


func _refresh() -> void:
	if _mesh != null:
		_mesh.visible = built
		_body.process_mode = Node.PROCESS_MODE_INHERIT if built else Node.PROCESS_MODE_DISABLED
		(_body.get_child(0) as CollisionShape3D).disabled = not built


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2714
	var builder := TreeBuilder.Builder.new()
	var bark := builder.tool_for(PropLook.bark())
	# Dois troncos curtos deitados, um pouco tortos.
	for side: float in [-0.32, 0.3]:
		var a := Vector3(side, 0.11, -0.22 + rng.randf_range(-0.03, 0.03))
		var b := Vector3(side + rng.randf_range(-0.04, 0.04), 0.1, 0.24)
		TreeBuilder.add_branch(bark, a, b, 0.11, 0.1, 7)
	var rock := builder.tool_for(_rock_material())
	# A laje: um bloco achatado de 80 x 45 cm, grosso de 6 cm, com a borda irregular.
	var corners: Array[Vector3] = []
	for i in 8:
		var angle := TAU * i / 8.0 + 0.2
		corners.append(Vector3(cos(angle) * 0.44 * rng.randf_range(0.9, 1.05), 0.0, sin(angle) * 0.27 * rng.randf_range(0.9, 1.05)))
	var top := 0.27
	var bottom := 0.21
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		_quad(rock, a + Vector3.UP * bottom, b + Vector3.UP * bottom, b + Vector3.UP * top, a + Vector3.UP * top)
		_tri(rock, Vector3.UP * top, a + Vector3.UP * top, b + Vector3.UP * top)
	# A pedra de amolar num canto e um osso esquecido.
	TreeBuilder.add_branch(rock, Vector3(0.24, top, 0.06), Vector3(0.36, top + 0.02, 0.1), 0.045, 0.04, 6)
	TreeBuilder.add_branch(builder.tool_for(PropLook.bone()), Vector3(-0.3, top + 0.01, -0.1), Vector3(-0.1, top + 0.015, -0.05), 0.012, 0.01, 5)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = builder.commit()
	add_child(_mesh)
	_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.85, top, 0.55)
	shape.shape = box
	shape.position = Vector3(0.0, top * 0.5, 0.0)
	_body.add_child(shape)
	_body.set_meta(&"surface", &"stone")
	add_child(_body)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


## Triângulo com a face da frente para fora (sentido horário visto de fora, a convenção do Godot).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for p: Vector3 in [a, b, c]:
		st.set_normal(normal)
		st.set_uv(Vector2(p.x + p.z, p.y) * 3.0)
		st.add_vertex(p)


static func _rock_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/rock.png")
	material.albedo_color = Color(0.72, 0.7, 0.68)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.9
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 2.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
