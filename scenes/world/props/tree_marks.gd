class_name TreeMarks
extends Node3D
## Os troncos riscados (F10), salvos com a partida (grupo "persist"): o goblin raspa a casca de
## um pinheiro vivo com as garras (TreeMarker) e deixa uma mancha clara de madeira com três
## riscos, dos dois lados do tronco, para ver indo e voltando. Serve de trilha na neblina.
## Os ids das árvores são estáveis (a vegetação usa semente fixa). Filho de Props.

const GROUP := &"tree_marks"
const TEXTURE := preload("res://assets/textures/tree_blaze.png")
## Tamanho da mancha (largura no arco do tronco × altura) e altura do meio dela.
const SIZE := Vector2(0.24, 0.4)
const HEIGHT := 0.75

## id da árvore -> ângulo (rad, no plano) do lado de onde o goblin riscou.
var marks := {}

var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveSystem.PERSIST_GROUP)


func has_mark(tree: int) -> bool:
	return marks.has(tree)


## Risca a árvore `tree` (base `base`, raio do tronco `radius`) do lado que olha para `from`.
func mark(tree: int, base: Vector3, radius: float, from: Vector3) -> void:
	if marks.has(tree):
		return
	var angle := atan2(from.x - base.x, from.z - base.z)
	marks[tree] = angle
	_build(tree, base, radius, angle)


func _build(tree: int, base: Vector3, radius: float, angle: float) -> void:
	var holder := MeshInstance3D.new()
	holder.name = "Mark%d" % tree
	holder.mesh = _blaze_mesh(radius, angle)
	holder.material_override = _blaze_material()
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holder)
	holder.global_position = base
	holder.set_meta(&"tree", tree)


## Duas manchas curvas seguindo o tronco (um pouco para fora da casca), uma de cada lado.
func _blaze_mesh(radius: float, angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := radius + 0.012
	var half_arc := SIZE.x * 0.5 / r
	var columns := 4
	for side in 2:
		var center := angle + PI * side
		for c in columns:
			var a0 := center - half_arc + 2.0 * half_arc * c / columns
			var a1 := center - half_arc + 2.0 * half_arc * (c + 1) / columns
			var u0 := float(c) / columns
			var u1 := float(c + 1) / columns
			var p00 := Vector3(sin(a0) * r, HEIGHT - SIZE.y * 0.5, cos(a0) * r)
			var p10 := Vector3(sin(a1) * r, HEIGHT - SIZE.y * 0.5, cos(a1) * r)
			var p01 := Vector3(sin(a0) * r, HEIGHT + SIZE.y * 0.5, cos(a0) * r)
			var p11 := Vector3(sin(a1) * r, HEIGHT + SIZE.y * 0.5, cos(a1) * r)
			var n0 := Vector3(sin(a0), 0.0, cos(a0))
			var n1 := Vector3(sin(a1), 0.0, cos(a1))
			# Visto de fora, sentido horário (a face da frente no Godot).
			for v: Array in [[p00, n0, Vector2(u0, 1)], [p01, n0, Vector2(u0, 0)], [p11, n1, Vector2(u1, 0)],
					[p00, n0, Vector2(u0, 1)], [p11, n1, Vector2(u1, 0)], [p10, n1, Vector2(u1, 1)]]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	return st.commit()


func _blaze_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = TEXTURE
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_material.alpha_scissor_threshold = 0.5
		_material.roughness = 1.0
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


func save_data() -> Dictionary:
	var list := []
	for tree: int in marks:
		list.append([tree, marks[tree]])
	return {"marks": list}


func load_data(data: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	marks.clear()
	var level := Game.current_level
	for entry: Array in data.get("marks", []):
		if entry.size() < 2 or level == null or not level.has_method("tree_base"):
			continue
		var tree := int(entry[0])
		var angle := float(entry[1])
		if not level.tree_standing(tree):
			continue
		marks[tree] = angle
		_build(tree, level.tree_base(tree), level.tree_radius(tree), angle)
