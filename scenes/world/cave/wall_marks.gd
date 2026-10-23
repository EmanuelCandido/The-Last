class_name WallMarks
extends Node3D
## Riscos na parede da caverna, ao lado da pele: um por noite dormida (Story.marks), em
## grupos de cinco (quatro em pé, o quinto atravessado). À esquerda ficam os riscos de
## ciclos passados (Story.old_marks), escondidos sob um musgo que cai quando o flag
## "moss_fell" liga. Quem liga o flag é a história (StoryBeats), não este nó.
##
## A parede é irregular: cada grupo acha o seu ponto com um raio. Os raios esperam a
## primeira volta da física, porque a casca da caverna é montada depois do _ready.
## Coordenadas da parede: u = z local da caverna (cresce para a direita de quem olha a
## parede), v = altura acima do chão.

const MOSS_FALL_SOUND := preload("res://assets/audio/sfx/moss_fall.wav")
const MOSS_SHADER := preload("res://assets/shaders/moss_patch.gdshader")
const MOSS_TEXTURE := preload("res://assets/textures/ground_forest.png")
const MOSS_EDGE_NOISE := preload("res://assets/textures/macro_noise.png")
const MOSS_FLAG := &"moss_fell"
## Os raios saem deste x (local da caverna) para +X, até a parede.
const RAY_FROM_X := 1.4
const RAY_LENGTH := 4.0
## Áreas (u, v, largura, altura) dos riscos antigos e dos deste ciclo.
const OLD_AREA := Rect2(-3.85, 0.22, 2.3, 0.72)
const NEW_AREA := Rect2(-1.45, 0.3, 0.55, 0.68)
## Tamanho de um grupo de cinco e o espaço entre grupos.
const GROUP_SIZE := Vector2(0.09, 0.085)
const NEW_GAP := Vector2(0.05, 0.035)
const OLD_GAP := Vector2(0.035, 0.012)
const STROKE_WIDTH := 0.008
## Folga entre os riscos e a rocha, e entre o musgo e a rocha.
const MARK_LIFT := 0.005
const MOSS_LIFT := 0.022
## Segundos depois de acordar até o musgo cair (o goblin está sentando, já ouvindo).
const MOSS_DELAY := 3.0
## Palavras riscadas (carve): onde começam (u, v da base), a altura da letra e o traço.
const WORD_START := Vector2(-3.45, 0.5)
const LETTER_HEIGHT := 0.16
const LETTER_STROKE := 0.012
## Letras para riscar na pedra: cada uma é uma lista de linhas, e cada linha são pontos num
## quadro de 0,65 de largura por 1 de altura (x para a direita, y para cima).
const LETTERS := {
	"A": [[Vector2(0.0, 0.0), Vector2(0.32, 1.0), Vector2(0.65, 0.0)], [Vector2(0.14, 0.42), Vector2(0.51, 0.42)]],
	"B": [[Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(0.4, 1.0), Vector2(0.56, 0.88), Vector2(0.56, 0.64), Vector2(0.4, 0.53), Vector2(0.0, 0.53)],
		[Vector2(0.4, 0.53), Vector2(0.62, 0.4), Vector2(0.62, 0.13), Vector2(0.45, 0.0), Vector2(0.0, 0.0)]],
	"C": [[Vector2(0.63, 0.86), Vector2(0.42, 1.0), Vector2(0.18, 0.95), Vector2(0.03, 0.72), Vector2(0.0, 0.45), Vector2(0.06, 0.18), Vector2(0.25, 0.0), Vector2(0.5, 0.02), Vector2(0.65, 0.16)]],
	"D": [[Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(0.3, 1.0), Vector2(0.55, 0.84), Vector2(0.65, 0.5), Vector2(0.55, 0.16), Vector2(0.3, 0.0), Vector2(0.0, 0.0)]],
	"G": [[Vector2(0.63, 0.86), Vector2(0.42, 1.0), Vector2(0.18, 0.95), Vector2(0.03, 0.72), Vector2(0.0, 0.45), Vector2(0.06, 0.18), Vector2(0.25, 0.0), Vector2(0.5, 0.02), Vector2(0.65, 0.18), Vector2(0.65, 0.45), Vector2(0.38, 0.45)]],
	"I": [[Vector2(0.32, 0.0), Vector2(0.32, 1.0)]],
	"O": [[Vector2(0.32, 1.0), Vector2(0.08, 0.88), Vector2(0.0, 0.5), Vector2(0.08, 0.12), Vector2(0.32, 0.0), Vector2(0.57, 0.12), Vector2(0.65, 0.5), Vector2(0.57, 0.88), Vector2(0.32, 1.0)]],
	"R": [[Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(0.42, 1.0), Vector2(0.6, 0.88), Vector2(0.6, 0.64), Vector2(0.42, 0.52), Vector2(0.0, 0.52)], [Vector2(0.3, 0.52), Vector2(0.65, 0.0)]],
}

## Risco recém-feito (pedra clara exposta) e o tom da rocha para onde os antigos desbotam.
const FRESH_COLOR := Color(0.66, 0.61, 0.54)
const ROCK_COLOR := Color(0.3, 0.29, 0.27)

var _ready_to_build := false
## Ponto e normal de cada grupo, por área: [[ponto, normal], ...] em espaço local.
var _old_slots: Array = []
var _new_slots: Array = []
var _old_mesh: MeshInstance3D
var _new_mesh: MeshInstance3D
var _moss: MeshInstance3D
var _moss_falling := false
var _material := StandardMaterial3D.new()
## Riscos e musgo escondidos (a memória de outro ciclo mostra a parede como era).
var _hidden := false
var _word_mesh: MeshInstance3D


func _ready() -> void:
	_material.vertex_color_use_as_albedo = true
	_material.roughness = 1.0
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_old_mesh = _add_mesh_node("OldMarks")
	_new_mesh = _add_mesh_node("Marks")
	_word_mesh = _add_mesh_node("Word")
	Story.changed.connect(_refresh)
	Story.flag_changed.connect(_on_flag_changed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	_old_slots = _cast_slots(space, OLD_AREA, OLD_GAP)
	_new_slots = _cast_slots(space, NEW_AREA, NEW_GAP)
	_ready_to_build = true
	_refresh()


func _refresh() -> void:
	if not _ready_to_build:
		return
	_old_mesh.mesh = _build_marks(_old_slots, Story.old_marks, true)
	_new_mesh.mesh = _build_marks(_new_slots, Story.marks, false)
	_new_mesh.visible = not _hidden
	if _moss != null:
		_moss.visible = not _hidden
	if _moss_falling:
		return
	var revealed := Story.has_flag(MOSS_FLAG)
	_old_mesh.visible = revealed and not _hidden
	if revealed and _moss != null:
		_moss.queue_free()
		_moss = null
	elif not revealed and _moss == null:
		_moss = _build_moss(get_world_3d().direct_space_state)


func _on_flag_changed(flag: StringName, value: bool) -> void:
	if flag != MOSS_FLAG or not value or _moss == null or _moss_falling:
		return
	_moss_falling = true
	await get_tree().create_timer(MOSS_DELAY, false).timeout
	_drop_moss()


## Esconde (ou volta a mostrar) os riscos e o musgo.
func hide_marks(hidden: bool) -> void:
	_hidden = hidden
	_refresh()


## Risca `text` na parede, na altura dos riscos antigos, até a fração `amount` dos traços (o
## último aparece pela metade). Devolve quantos traços a palavra tem; texto vazio apaga.
func carve(text: String, amount := 1.0) -> int:
	_word_mesh.mesh = null
	if text == "" or not _ready_to_build:
		return 0
	var segments := []
	for i in text.length():
		var lines: Array = LETTERS.get(text[i], [])
		for line: Array in lines:
			for k in line.size() - 1:
				segments.append([i, line[k], line[k + 1]])
	var shown := amount * segments.size()
	if shown <= 0.0:
		return segments.size()
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 346
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frames := {}
	for s in segments.size():
		var segment: Array = segments[s]
		var letter: int = segment[0]
		# Feito com uma pedra, no escuro: cada ponta escorrega um pouco.
		var a: Vector2 = segment[1] + Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		var b: Vector2 = segment[2] + Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		if float(s) >= shown:
			break
		if not frames.has(letter):
			var center := WORD_START + Vector2((letter + 0.32) * LETTER_HEIGHT, LETTER_HEIGHT * 0.5)
			frames[letter] = _wall_at(space, center.x, center.y)
		var hit: Array = frames[letter]
		if hit.is_empty():
			continue
		var part := clampf(shown - s, 0.0, 1.0)
		b = a.lerp(b, part)
		var normal: Vector3 = hit[1]
		var right := (Vector3.BACK - normal * normal.dot(Vector3.BACK)).normalized()
		var up := normal.cross(right)
		var origin: Vector3 = hit[0] + normal * MARK_LIFT * 1.5
		var offset := Vector2(0.32, 0.5)
		_add_stroke(st, origin, right, up, (a - offset) * LETTER_HEIGHT, (b - offset) * LETTER_HEIGHT, FRESH_COLOR.lightened(0.08), LETTER_STROKE)
	st.generate_normals()
	_word_mesh.mesh = st.commit()
	return segments.size()


# --- Riscos ------------------------------------------------------------------------

## Grade de grupos dentro de `area`, de cima para baixo e da esquerda para a direita.
func _cast_slots(space: PhysicsDirectSpaceState3D, area: Rect2, gap: Vector2) -> Array:
	var slots := []
	var step := GROUP_SIZE + gap
	var columns := int((area.size.x + gap.x) / step.x)
	var rows := int((area.size.y + gap.y) / step.y)
	for row in rows:
		for column in columns:
			var u := area.position.x + column * step.x + GROUP_SIZE.x * 0.5
			var v := area.end.y - row * step.y - GROUP_SIZE.y * 0.5
			# Feitos à mão, noite após noite: as fileiras ondulam e nenhum grupo fica no lugar exato.
			u += sin(row * 2.3 + column * 0.7) * gap.x * 0.35
			v += sin(column * 0.9 + row) * gap.y * 0.6 + sin(column * 0.31) * 0.01
			var hit := _wall_at(space, u, v)
			if not hit.is_empty():
				slots.append(hit)
	return slots


## Ponto e normal da parede na altura v, na posição u. Vazio se o raio não achar rocha.
func _wall_at(space: PhysicsDirectSpaceState3D, u: float, v: float) -> Array:
	var from := global_transform * Vector3(RAY_FROM_X, v, u)
	var to := from + global_basis.x * RAY_LENGTH
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if hit.is_empty():
		return []
	var normal: Vector3 = global_basis.inverse() * hit.normal
	return [to_local(hit.position), normal.normalized()]


## Uma malha com `count` riscos, cinco por grupo, um grupo por slot. Os antigos ficam
## mais apagados e cada ciclo antigo (uns 12 riscos) tem um desgaste próprio.
func _build_marks(slots: Array, count: int, old: bool) -> ArrayMesh:
	var groups := mini(ceili(count / 5.0), slots.size())
	if groups == 0:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2714 if old else 347
	for g in groups:
		var slot: Array = slots[g]
		var strokes := mini(count - g * 5, 5)
		var weathering := 0.0
		if old:
			var cycle_rng := RandomNumberGenerator.new()
			cycle_rng.seed = int(g * 5 / 12.0)
			weathering = cycle_rng.randf_range(0.35, 0.8)
		var color := FRESH_COLOR.lerp(ROCK_COLOR, weathering)
		_add_group(st, slot[0], slot[1], strokes, color, rng)
	st.generate_normals()
	return st.commit()


## Um grupo: até quatro riscos em pé, levemente tortos e de tamanhos diferentes, e o
## quinto cortando os quatro na diagonal.
func _add_group(st: SurfaceTool, center: Vector3, normal: Vector3, strokes: int, color: Color, rng: RandomNumberGenerator) -> void:
	var right := (Vector3.BACK - normal * normal.dot(Vector3.BACK)).normalized()
	var up := normal.cross(right)
	var origin := center + normal * MARK_LIFT - right * GROUP_SIZE.x * 0.4
	for i in mini(strokes, 4):
		var x := i * 0.022 + rng.randf_range(-0.004, 0.004)
		var half := rng.randf_range(0.034, 0.043)
		var lean := rng.randf_range(-0.1, 0.1)
		var a := Vector2(x - lean * half, -half + rng.randf_range(-0.005, 0.005))
		var b := Vector2(x + lean * half, half)
		_add_stroke(st, origin, right, up, a, b, color.darkened(rng.randf_range(0.0, 0.15)))
	if strokes == 5:
		_add_stroke(st, origin, right, up, Vector2(-0.012, -0.03), Vector2(0.078, 0.032), color)


func _add_stroke(st: SurfaceTool, origin: Vector3, right: Vector3, up: Vector3, a: Vector2, b: Vector2, color: Color, width := STROKE_WIDTH) -> void:
	if a.distance_squared_to(b) < 1e-8:
		return
	var direction := (b - a).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	var corners: Array[Vector3] = []
	for p: Vector2 in [a - side, a + side, b - side, b + side]:
		corners.append(origin + right * p.x + up * p.y)
	st.set_color(color)
	for index in [0, 1, 2, 1, 3, 2]:
		st.add_vertex(corners[index])


# --- Musgo ---------------------------------------------------------------------------

## Mancha de musgo colada na parede sobre os riscos antigos, com a borda irregular. Os
## vértices ficam em volta de um pivô na borda de cima, por onde ela despenca.
func _build_moss(space: PhysicsDirectSpaceState3D) -> MeshInstance3D:
	const COLUMNS := 10
	const ROWS := 6
	# Maior que os riscos: o shader rói a borda e ela não pode deixar nenhum à mostra.
	var area := OLD_AREA.grow(0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var grid := []
	for row in ROWS + 1:
		var line := []
		for column in COLUMNS + 1:
			var uv := Vector2(float(column) / COLUMNS, float(row) / ROWS)
			var u := area.position.x + uv.x * area.size.x
			var v := area.position.y + uv.y * area.size.y
			var hit := _wall_at(space, u, v)
			if hit.is_empty():
				return null
			var point: Vector3 = hit[0]
			var normal: Vector3 = hit[1]
			# Mais grosso no meio (tufo), colado na rocha na beirada.
			var middle := 1.0 - maxf(absf(uv.x * 2.0 - 1.0), absf(uv.y * 2.0 - 1.0))
			var thickness := rng.randf_range(0.0, 0.02) * middle
			line.append([point + normal * (MOSS_LIFT + thickness), Vector2(u, v) * 1.6, uv])
		grid.append(line)

	var top_row: Array = grid[ROWS]
	var top_left: Array = top_row[0]
	var top_right: Array = top_row[COLUMNS]
	var pivot: Vector3 = (top_left[0] + top_right[0]) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in ROWS:
		for column in COLUMNS:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var line: Array = grid[row + corner.y]
				var vertex: Array = line[column + corner.x]
				st.set_uv(vertex[1])
				st.set_uv2(vertex[2])
				st.add_vertex(vertex[0] - pivot)
	st.generate_normals()

	var material := ShaderMaterial.new()
	material.shader = MOSS_SHADER
	material.set_shader_parameter(&"moss_texture", MOSS_TEXTURE)
	material.set_shader_parameter(&"edge_noise", MOSS_EDGE_NOISE)
	var moss := MeshInstance3D.new()
	moss.name = "Moss"
	moss.mesh = st.commit()
	moss.material_override = material
	moss.position = pivot
	add_child(moss)
	return moss


## O musgo descola de cima, tomba para fora da parede e cai no chão, soltando poeira.
func _drop_moss() -> void:
	var moss := _moss
	_moss = null
	_old_mesh.visible = true
	if moss == null:
		_moss_falling = false
		return
	var pivot := moss.position
	var center := pivot + Vector3.DOWN * OLD_AREA.size.y * 0.5
	OccludedAudio.play_at(self, MOSS_FALL_SOUND, global_transform * center, &"World", -3.0, 3.0)
	_spawn_dust(center)
	var away := Vector3.LEFT
	var tilt_axis := Vector3.BACK
	var fall := func(k: float) -> void:
		moss.transform = Transform3D(Basis(tilt_axis, -k * 1.3), pivot + away * 0.35 * k + Vector3.DOWN * pivot.y * 0.85 * k * k)
	var tween := create_tween()
	tween.tween_method(fall, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(2.5)
	tween.tween_property(moss, "transparency", 1.0, 2.0)
	tween.tween_callback(func() -> void:
		moss.queue_free()
		_moss_falling = false)


func _spawn_dust(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.position = at
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 2.2
	dust.explosiveness = 0.85
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.05, OLD_AREA.size.y * 0.5, OLD_AREA.size.x * 0.5)
	dust.direction = Vector3.LEFT
	dust.spread = 50.0
	dust.initial_velocity_min = 0.1
	dust.initial_velocity_max = 0.4
	dust.gravity = Vector3(0.0, -0.6, 0.0)
	dust.damping_min = 0.6
	dust.damping_max = 1.2
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.4, 0.33, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.roughness = 1.0
	quad.material = material
	dust.mesh = quad
	add_child(dust)
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


func _add_mesh_node(node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.material_override = _material
	add_child(node)
	return node
