class_name NorthVoid
extends Node3D
## O clima cortado (R3, §3): no setor norte a neblina abre e mostra o mundo acabando. Depois de
## Tuning.VOID_EDGE_Z não há terreno nem árvore; na borda fica o corte do chão, preto e sem
## neblina, e uma parede que não deixa passar. Lá longe, atrás do corte, um fundo preto sobe do
## horizonte e se desfaz no céu: o nada. Embaixo do horizonte o céu também fica preto (a fase
## passa openness() para o DayNight). Liga e desliga com o flag "climate_cut", porque a
## Reciclagem pode desfazer o R3.

const FLAG := &"climate_cut"
## Até onde o corte desce (m, abaixo de zero) e a altura da parede invisível.
const DEPTH := 400.0
const WALL_HEIGHT := 600.0
## O fundo: a que distância da borda (m, dentro do plano distante da câmera), a largura, e as
## alturas em que é preto e em que já sumiu no céu.
const BACKDROP_DISTANCE := 700.0
const BACKDROP_WIDTH := 5000.0
const BACKDROP_SOLID := 30.0
const BACKDROP_TOP := 260.0

## O clima está cortado agora.
var open := false

var _terrain: Terrain
var _vegetation: Vegetation
var _cut: MeshInstance3D
var _backdrop: MeshInstance3D
var _wall: StaticBody3D


func build(terrain: Terrain, vegetation: Vegetation) -> void:
	_terrain = terrain
	_vegetation = vegetation
	_build_cut()
	_build_backdrop()
	_build_wall()
	Story.flag_changed.connect(func(flag: StringName, _value: bool) -> void:
		if flag == FLAG:
			_apply(Story.has_flag(FLAG)))
	_apply(Story.has_flag(FLAG))


## Quanto a neblina abre em `at`: 0 fora do setor norte (ou com o clima inteiro), 1 aberta.
func openness(at: Vector3) -> float:
	if not open:
		return 0.0
	return smoothstep(Tuning.NORTH_SECTOR_Z.x, Tuning.NORTH_SECTOR_Z.y, at.z)


func _apply(on: bool) -> void:
	open = on
	var edge := Tuning.VOID_EDGE_Z if on else -INF
	_terrain.set_north_cut(edge)
	_vegetation.set_north_cut(edge)
	_cut.visible = on
	_backdrop.visible = on
	_wall.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	print("[Vazio] Norte %s." % ("aberto" if on else "fechado"))


## O corte do chão na borda: uma faixa preta que desce do perfil do terreno até o fundo.
func _build_cut() -> void:
	var z := Tuning.VOID_EDGE_Z
	var half := ForestLayout.TERRAIN_SIZE * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := Terrain.RESOLUTION
	for i in steps:
		var x0 := -half + ForestLayout.TERRAIN_SIZE * i / steps
		var x1 := -half + ForestLayout.TERRAIN_SIZE * (i + 1) / steps
		# Um pouco abaixo do chão, para a emenda não cintilar.
		var top0 := Vector3(x0, _terrain.get_height(x0, z) - 0.03, z)
		var top1 := Vector3(x1, _terrain.get_height(x1, z) - 0.03, z)
		var bottom0 := Vector3(x0, -DEPTH, z)
		var bottom1 := Vector3(x1, -DEPTH, z)
		for vertex in [top0, top1, bottom0, top1, bottom1, bottom0]:
			tool.add_vertex(vertex)
	_cut = _void_mesh("Cut", tool.commit(), false)


## O nada atrás do corte: uma chapa preta e longe que se desfaz para cima (cor do vértice).
func _build_backdrop() -> void:
	var z := Tuning.VOID_EDGE_Z - BACKDROP_DISTANCE
	var half := BACKDROP_WIDTH * 0.5
	var rows := [[-DEPTH * 4.0, 1.0], [BACKDROP_SOLID, 1.0], [lerpf(BACKDROP_SOLID, BACKDROP_TOP, 0.4), 0.45], [BACKDROP_TOP, 0.0]]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows.size() - 1:
		var low: Array = rows[r]
		var high: Array = rows[r + 1]
		var quad := [
			[Vector3(-half, high[0], z), high[1]], [Vector3(half, high[0], z), high[1]], [Vector3(-half, low[0], z), low[1]],
			[Vector3(half, high[0], z), high[1]], [Vector3(half, low[0], z), low[1]], [Vector3(-half, low[0], z), low[1]],
		]
		for corner: Array in quad:
			tool.set_color(Color(0.0, 0.0, 0.0, corner[1]))
			tool.add_vertex(corner[0])
	_backdrop = _void_mesh("Backdrop", tool.commit(), true)


func _void_mesh(mesh_name: String, mesh: Mesh, fades: bool) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_fog = true
	if fades:
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _build_wall() -> void:
	_wall = StaticBody3D.new()
	_wall.name = "Wall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ForestLayout.TERRAIN_SIZE, WALL_HEIGHT, 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, WALL_HEIGHT * 0.5 - DEPTH * 0.25, Tuning.VOID_EDGE_Z - 1.0)
	_wall.add_child(shape)
	add_child(_wall)
