class_name Ruin
extends Node3D
## A Ruína de São Brás (§1, §3), no fim da trilha (ForestLayout.RUINS): uma capela caída
## com a frente (e o arco da entrada) virada para +Z, de onde a trilha chega.
## - Nave: paredes quebradas em alturas diferentes, um rombo na parede direita, entulho e hera.
## - No fundo da nave, a porta lisa com os discos (RuinDoor).
## - Na fachada, uma espadana (parede do sino) com um sino rachado que bate com o vento (RuinBell).
## - Atrás dela, a sala-espelho: a planta da sala 2714 do Abrigo (5 × 6 m), com o sarcófago
##   no lugar da cápsula, uma janela de pedra com grades no lugar da janela, a frase de Ari
##   na parede e um ninho de corvo no alto da parede, onde o teto quebrou.
## Tudo montado por código; as paredes são uma malha só (com colisão exata) e cada bloco
## acompanha o chão embaixo dele, porque o terreno ali não é plano.

const GROUP := &"ruin"
const ROCK_SHADER := preload("res://assets/shaders/rock.gdshader")
const ROCK_TEXTURE := preload("res://assets/textures/rock.png")
const MOSS_TEXTURE := preload("res://assets/textures/ground_forest.png")
## Nave e sala-espelho (x, z no espaço da ruína; paredes centradas nas bordas).
const NAVE := Rect2(-3.0, 0.0, 6.0, 6.5)
const ROOM := Rect2(-2.5, -6.0, 5.0, 6.0)
const WALL := 0.6
const BLOCK := 0.75
## Porta (largura × altura) no meio da parede entre a nave e a sala.
const DOOR_SIZE := Vector2(1.0, 1.8)
## Abertura do arco da frente (largura × altura até o começo da curva).
const ARCH_SIZE := Vector2(1.6, 1.9)
## A frase que Ari deixou na sala (a única instrução do ritual, §3).
const WRITING := "PRENDA O AR NO ESCURO.\nCONTE ATÉ VINTE.\n— A."

var terrain: Terrain
## Altura (no espaço da ruína) do piso da sala-espelho: acima de todo o chão embaixo dela.
var floor_y := 0.0
var door: RuinDoor
var sarcophagus: Sarcophagus
var bell: RuinBell

var _rng := RandomNumberGenerator.new()
var _walls := SurfaceTool.new()
var _rock: ShaderMaterial
var _floor_stone: ShaderMaterial
var _nest := Vector3.ZERO
## Eixo do sino, embaixo da verga da espadana (espaço da ruína).
var _bell_axis := Vector3.ZERO


func build(world_terrain: Terrain) -> void:
	terrain = world_terrain
	add_to_group(GROUP)
	var at := ForestLayout.RUINS
	position = Vector3(at.x, terrain.get_height(at.x, at.y), at.y)
	_rng.seed = 2714
	_rock = _rock_material(Color(0.95, 0.92, 0.86), 0.45)
	_floor_stone = _rock_material(Color(0.8, 0.77, 0.72), 0.15)
	floor_y = _highest_ground(ROOM.grow(0.6)) + 0.05

	_walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_nave()
	_build_room()
	_build_bell_gable()
	var mesh := _walls.commit()
	var walls := MeshInstance3D.new()
	walls.name = "Walls"
	walls.mesh = mesh
	walls.material_override = _rock
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(walls)
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var trimesh := mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)
	add_child(body)

	_build_room_floor()
	_build_roof()
	_build_window_bars()
	_build_writing()
	_build_nest()
	_build_rubble()
	_build_ivy()
	bell = RuinBell.new()
	bell.name = "Bell"
	add_child(bell)
	bell.position = _bell_axis

	door = RuinDoor.new()
	door.name = "Door"
	add_child(door)
	door.position = Vector3(0.0, floor_y, WALL * 0.5)
	door.build(DOOR_SIZE.x, DOOR_SIZE.y, WALL * 0.5)
	sarcophagus = Sarcophagus.new()
	sarcophagus.name = "Sarcophagus"
	add_child(sarcophagus)
	# Onde a cápsula fica na sala 2714: encostada na parede da esquerda, pés para a porta.
	sarcophagus.position = Vector3(-1.2, floor_y, -3.4)
	sarcophagus.build(_rock_material(Color(1.0, 0.97, 0.92), 0.25))


## Ponto de pouso do corvo sentinela da ruína (o ninho), no mundo.
func nest_point() -> Vector3:
	return to_global(_nest)


## Dentro da sala-espelho (para a escuridão e para quem precisar saber onde o goblin está).
func in_mirror_room(world_position: Vector3) -> bool:
	var local := to_local(world_position)
	return ROOM.has_point(Vector2(local.x, local.z))


# --- Paredes -------------------------------------------------------------------------

func _build_nave() -> void:
	var left := NAVE.position.x
	var right := NAVE.end.x
	var front := NAVE.end.y
	# Laterais quebradas: a esquerda mais alta; a direita com um rombo no meio.
	_wall(Vector2(left, 0.0), Vector2(left, front), Vector2(0.7, 2.9), false)
	_wall(Vector2(right, 0.0), Vector2(right, front), Vector2(0.4, 2.3), false, [[0.38, 0.62, -9.0, 9.0]])
	# Fachada: dois pedaços altos (o que sobrou da empena) e o arco no meio.
	var half_arch := ARCH_SIZE.x * 0.5
	_wall(Vector2(left - WALL * 0.5, front), Vector2(right + WALL * 0.5, front), Vector2(2.6, 3.9), false,
		[[0.5 - half_arch / (NAVE.size.x + WALL), 0.5 + half_arch / (NAVE.size.x + WALL), -9.0, ARCH_SIZE.y + 0.8]])
	_arch(Vector3(0.0, _ground(0.0, front) + ARCH_SIZE.y, front), half_arch + 0.12)


func _build_room() -> void:
	var left := ROOM.position.x
	var right := ROOM.end.x
	var back := ROOM.position.y
	# Parede entre a nave e a sala, com a porta no meio (o vão vai do chão ao lintel).
	var span := ROOM.size.x + WALL
	var half_door := DOOR_SIZE.x * 0.5 / span
	_wall(Vector2(left - WALL * 0.5, 0.0), Vector2(right + WALL * 0.5, 0.0), Vector2(3.0, 3.3), true,
		[[0.5 - half_door, 0.5 + half_door, -9.0, DOOR_SIZE.y]])
	# Laterais e fundo: quase inteiras (é uma sala); a direita tem a janela de pedra.
	_wall(Vector2(left, 0.0), Vector2(left, back), Vector2(2.9, 3.2), true)
	_wall(Vector2(right, 0.0), Vector2(right, back), Vector2(2.8, 3.1), true, [[0.42, 0.58, 1.0, 1.75]])
	_wall(Vector2(left - WALL * 0.5, back), Vector2(right + WALL * 0.5, back), Vector2(2.7, 3.2), true)


## Uma parede de `a` até `b` em blocos de ~BLOCK m, cada um com a altura sorteada entre
## `heights` (vizinhos parecidos). `on_floor` = a altura conta do piso da sala, senão do chão
## embaixo do bloco. `openings`: [[t0, t1, y0, y1], ...] ao longo da parede (0..1), vãos
## entre as alturas y0 e y1 (acima da base).
func _wall(a: Vector2, b: Vector2, heights: Vector2, on_floor: bool, openings: Array = []) -> void:
	var length := a.distance_to(b)
	var count := maxi(1, roundi(length / BLOCK))
	var along := (b - a) / count
	var yaw := atan2(along.x, along.y)
	var height := _rng.randf_range(heights.x, heights.y)
	for i in count:
		var t0 := float(i) / count
		var t1 := float(i + 1) / count
		var mid := a + along * (i + 0.5)
		height = clampf(lerpf(height, _rng.randf_range(heights.x, heights.y), 0.55), heights.x, heights.y)
		var ground := _ground(mid.x, mid.y)
		var base := floor_y if on_floor else ground
		var bottom := minf(ground, base) - 1.2
		var top := base + height
		var spans := [[bottom, top]]
		for opening: Array in openings:
			if t1 > float(opening[0]) and t0 < float(opening[1]):
				var cut_low := base + float(opening[2])
				var cut_high := base + float(opening[3])
				var next := []
				for piece: Array in spans:
					if float(piece[0]) < cut_low:
						next.append([piece[0], minf(float(piece[1]), cut_low)])
					if float(piece[1]) > cut_high:
						next.append([maxf(float(piece[0]), cut_high), piece[1]])
				spans = next
		for piece: Array in spans:
			var low: float = piece[0]
			var high: float = piece[1]
			if high - low < 0.08:
				continue
			# Feita à mão: cada bloco sai um pouco do prumo.
			var center := Vector3(mid.x, (low + high) * 0.5, mid.y) + Vector3(_rng.randf_range(-0.03, 0.03), 0.0, _rng.randf_range(-0.03, 0.03))
			_block(center, Vector3(WALL + _rng.randf_range(-0.04, 0.04), high - low, along.length() + 0.04), yaw + _rng.randf_range(-0.03, 0.03))


## A espadana (F10): no pedaço alto da esquerda da fachada sobem dois pilares e uma verga, acima
## de onde a parede quebrou; o sino pendura no vão entre eles e aparece de longe na neblina.
func _build_bell_gable() -> void:
	var front := NAVE.end.y
	var x := NAVE.position.x + 1.0
	var ground := _ground(x, front)
	var top := ground + 4.75
	for side: float in [-1.0, 1.0]:
		var low := ground - 0.5
		_block(Vector3(x + side * 0.4, (low + top) * 0.5, front), Vector3(0.26, top - low, WALL * 0.8), _rng.randf_range(-0.02, 0.02))
	_block(Vector3(x, top + 0.13, front), Vector3(1.1, 0.26, WALL * 0.9), _rng.randf_range(-0.02, 0.02))
	_bell_axis = Vector3(x, top - 0.03, front)


## Arco de pedras em semicírculo sobre o vão da frente.
func _arch(center: Vector3, radius: float) -> void:
	var stones := 9
	for i in stones:
		var angle := PI * (i + 0.5) / stones
		var at := center + Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		var block := Transform3D(Basis(Vector3.BACK, angle - PI * 0.5), at)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.32, 0.36, WALL + 0.06)
		_walls.append_from(mesh, 0, block)


func _block(center: Vector3, size: Vector3, yaw: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_walls.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, yaw), center))


# --- Sala-espelho ----------------------------------------------------------------------

func _build_room_floor() -> void:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	# Vai até a face da parede do lado da nave: o vão da porta também tem chão.
	box.size = Vector3(ROOM.size.x + 0.1, 0.4, ROOM.size.y + WALL * 0.5 + 0.1)
	slab.mesh = box
	slab.material_override = _floor_stone
	slab.position = Vector3(ROOM.get_center().x, floor_y - 0.2, ROOM.position.y - 0.05 + box.size.z * 0.5)
	add_child(slab)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = box.size
	shape.shape = collision
	body.add_child(shape)
	slab.add_child(body)
	# Uma rampa de pedra da nave até o piso da sala (o goblin não sobe degrau).
	var run := 1.6
	var start := WALL * 0.5
	var rise := floor_y - _ground(0.0, start + run)
	if rise < 0.04:
		return
	var ramp := MeshInstance3D.new()
	var ramp_box := BoxMesh.new()
	var slope := Vector2(run, rise).length()
	ramp_box.size = Vector3(DOOR_SIZE.x + 0.5, 0.3, slope)
	ramp.mesh = ramp_box
	ramp.material_override = _floor_stone
	# A face de cima vai do piso (na parede) até o chão da nave, `run` m para fora.
	var angle := atan2(rise, run)
	ramp.rotation.x = angle
	ramp.position = Vector3(0.0, floor_y - rise * 0.5, start + run * 0.5) + Basis(Vector3.RIGHT, angle) * Vector3(0.0, -0.15, 0.0)
	add_child(ramp)
	var ramp_body := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	var ramp_collision := BoxShape3D.new()
	ramp_collision.size = ramp_box.size
	ramp_shape.shape = ramp_collision
	ramp_body.add_child(ramp_shape)
	ramp.add_child(ramp_body)


## Teto quebrado: a metade do fundo ainda coberta por uma laje torta; na da frente, só vigas
## (uma caída). É por ali que entra a pouca luz e que o corvo pousa.
func _build_roof() -> void:
	var top := floor_y + 3.05
	var slab := _prop(BoxMesh.new(), Vector3(ROOM.size.x + WALL * 2.0, 0.3, 3.1), _rock, Vector3(0.0, top + 0.1, ROOM.position.y + 1.4))
	slab.rotation.x = 0.04
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/textures/bark.png")
	wood.albedo_color = Color(0.4, 0.33, 0.28)
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	wood.uv1_triplanar = true
	wood.roughness = 1.0
	for z: float in [-1.0, -2.2]:
		_prop(BoxMesh.new(), Vector3(ROOM.size.x + WALL, 0.18, 0.2), wood, Vector3(0.0, top, z))
	var fallen := _prop(BoxMesh.new(), Vector3(3.0, 0.18, 0.2), wood, Vector3(1.2, floor_y + 1.4, -2.9))
	fallen.rotation = Vector3(0.3, 0.25, -0.75)


func _build_window_bars() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.13, 0.11)
	iron.metallic = 0.6
	iron.roughness = 0.7
	var z := lerpf(0.0, ROOM.position.y, 0.5)
	for offset: float in [-0.12, 0.12]:
		var bar := CylinderMesh.new()
		bar.top_radius = 0.015
		bar.bottom_radius = 0.015
		bar.height = 0.8
		bar.radial_segments = 5
		bar.rings = 1
		_prop(bar, Vector3.ONE, iron, Vector3(ROOM.end.x, floor_y + 1.37, z + offset))


func _build_writing() -> void:
	var label := Label3D.new()
	label.name = "Writing"
	label.text = WRITING
	label.font_size = 44
	label.pixel_size = 0.0032
	label.modulate = Color(0.08, 0.07, 0.06, 0.92)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Na parede da esquerda, por dentro, virada para a sala (+X), na altura dos olhos do goblin.
	label.position = Vector3(ROOM.position.x + WALL * 0.5 + 0.01, floor_y + 1.15, -1.9)
	label.rotation.y = PI * 0.5
	add_child(label)


func _build_nest() -> void:
	var corner := Vector2(ROOM.end.x - 0.05, -0.55)
	_nest = Vector3(corner.x, floor_y + 3.15, corner.y)
	var twigs := TorusMesh.new()
	twigs.inner_radius = 0.1
	twigs.outer_radius = 0.24
	twigs.rings = 10
	twigs.ring_segments = 5
	var straw := StandardMaterial3D.new()
	straw.albedo_texture = preload("res://assets/textures/bark.png")
	straw.albedo_color = Color(0.36, 0.3, 0.22)
	straw.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	straw.uv1_triplanar = true
	var nest := _prop(twigs, Vector3(1.0, 0.45, 1.0), straw, _nest + Vector3.DOWN * 0.03)
	nest.name = "Nest"


func _build_rubble() -> void:
	var spots := [Vector3(2.6, 0.0, 3.6), Vector3(3.3, 0.0, 4.2), Vector3(-2.2, 0.0, 5.4), Vector3(1.4, 0.0, 1.2), Vector3(-1.8, 0.0, 2.0), Vector3(2.9, 0.0, 2.9)]
	for spot: Vector3 in spots:
		for k in 5:
			var radius := _rng.randf_range(0.12, 0.32)
			var offset := Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5))
			var stone := MeshInstance3D.new()
			stone.mesh = ThrownStone.stone_mesh(_rng.randi(), radius)
			stone.material_override = _rock
			var p := spot + offset
			stone.position = Vector3(p.x, _ground(p.x, p.z) + radius * 0.35, p.z)
			stone.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4))
			add_child(stone)


## Hera: cartões de folhas escuras na fachada e pendurados em volta da porta (escondendo-a).
func _build_ivy() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var front := NAVE.end.y + WALL * 0.5 + 0.02
	for i in 26:
		var x := _rng.randf_range(NAVE.position.x, NAVE.end.x)
		if absf(x) < ARCH_SIZE.x * 0.5:
			continue
		_ivy_card(st, Vector3(x, _ground(x, front) + _rng.randf_range(0.6, 3.2), front), Vector3.BACK, _rng.randf_range(0.5, 0.9))
	var wall_face := WALL * 0.5 + 0.02
	for i in 18:
		var x := _rng.randf_range(-1.4, 1.4)
		var hang := floor_y + _rng.randf_range(DOOR_SIZE.y - 0.4, DOOR_SIZE.y + 1.2)
		_ivy_card(st, Vector3(x, hang, wall_face + _rng.randf_range(0.0, 0.05)), Vector3.BACK, _rng.randf_range(0.45, 0.8))
	var ivy := MeshInstance3D.new()
	ivy.name = "Ivy"
	ivy.mesh = st.commit()
	var leaves := StandardMaterial3D.new()
	leaves.albedo_texture = preload("res://assets/textures/leaves_card.png")
	leaves.albedo_color = Color(0.32, 0.4, 0.26)
	leaves.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	leaves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaves.alpha_scissor_threshold = 0.5
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.roughness = 1.0
	ivy.material_override = leaves
	ivy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ivy)


## Um cartão de hera de `size` m pendurado em `top`, de frente para `normal`.
func _ivy_card(st: SurfaceTool, top: Vector3, normal: Vector3, size: float) -> void:
	var side := normal.cross(Vector3.UP).normalized() * size * 0.5
	var down := Vector3.DOWN * size * 1.2
	var tilt := Vector3(_rng.randf_range(-0.1, 0.1), 0.0, 0.0)
	var corners := [top - side, top + side, top + side + down + tilt, top - side + down + tilt]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[index])
		st.add_vertex(corners[index])


# --- Ajudantes -----------------------------------------------------------------------

func _prop(mesh: PrimitiveMesh, scale_factor: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.scale = scale_factor
	add_child(node)
	return node


## Altura do terreno no ponto (x, z) da ruína, no espaço da ruína.
func _ground(x: float, z: float) -> float:
	return terrain.get_height(position.x + x, position.z + z) - position.y


func _highest_ground(area: Rect2) -> float:
	var highest := -INF
	for i in 9:
		for j in 9:
			var p := area.position + area.size * Vector2(i / 8.0, j / 8.0)
			highest = maxf(highest, _ground(p.x, p.y))
	return highest


func _rock_material(tint: Color, moss: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ROCK_SHADER
	material.set_shader_parameter(&"rock_texture", ROCK_TEXTURE)
	material.set_shader_parameter(&"moss_texture", MOSS_TEXTURE)
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"moss_tint", Color(0.42, 0.46, 0.34))
	material.set_shader_parameter(&"tile_size", 1.2)
	material.set_shader_parameter(&"moss_amount", moss)
	return material
