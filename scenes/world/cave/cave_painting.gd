class_name CavePainting
extends Node3D
## Pintura no teto da caverna (§3, beat painting): 2 cervos, 7 corvos, 1 lobo e 4 coelhos,
## em grupos, em ocre. É o código da porta da ruína (2714). Sempre existiu; só se lê com a
## fogueira cheia, que é a única luz que alcança o teto.
##
## Cada figura é um quadrado colado na rocha por um raio para cima (no primeiro frame de
## física, como os riscos da parede), com o desenho de um atlas feito aqui em código.
## A origem é a do salão da caverna (filho da Cave).

## Figuras em ordem, com o lugar de cada uma no teto (x, z no espaço da caverna).
const FIGURES := [
	[&"deer", Vector2(-2.0, -0.2)], [&"deer", Vector2(-1.55, 0.25)],
	[&"crow", Vector2(-0.7, -0.55)], [&"crow", Vector2(-0.35, -0.1)], [&"crow", Vector2(-0.8, 0.25)],
	[&"crow", Vector2(-0.25, 0.4)], [&"crow", Vector2(0.05, -0.4)], [&"crow", Vector2(-0.5, 0.75)], [&"crow", Vector2(0.15, 0.85)],
	[&"wolf", Vector2(0.9, 0.1)],
	[&"rabbit", Vector2(1.6, -0.3)], [&"rabbit", Vector2(1.95, 0.05)], [&"rabbit", Vector2(1.6, 0.45)], [&"rabbit", Vector2(2.0, 0.8)],
]
## Coluna de cada figura no atlas (32 px cada).
const ATLAS := {&"deer": 0, &"crow": 1, &"wolf": 2, &"rabbit": 3}
const SIZES := {&"deer": 0.7, &"crow": 0.42, &"wolf": 0.7, &"rabbit": 0.45}
## Ocre pálido: sobre a rocha escura, só se lê com luz forte.
const PAINT := Color(0.7, 0.5, 0.31)
const CELL := 32


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build()


func _build() -> void:
	var space := get_world_3d().direct_space_state
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2714
	for figure: Array in FIGURES:
		var kind: StringName = figure[0]
		var at: Vector2 = figure[1]
		var from := to_global(Vector3(at.x, 1.5, at.y))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 6.0, 1))
		if hit.is_empty():
			continue
		var normal: Vector3 = (hit.normal as Vector3).normalized()
		# A casca tem colisão dos dois lados: a normal pode vir para fora da rocha. Vira para
		# baixo, para o lado de quem olha, senão a figura entra na pedra.
		if normal.y > 0.0:
			normal = -normal
		# Pintadas olhando para a boca da caverna, um pouco tortas, como à mão.
		var right := normal.cross(Vector3.FORWARD).normalized().rotated(normal, rng.randf_range(-0.25, 0.25))
		var up := right.cross(normal).normalized()
		var size: float = SIZES[kind] * rng.randf_range(0.9, 1.1)
		var center := to_local(hit.position + normal * 0.02)
		var r := (global_basis.inverse() * right) * size * 0.5
		var u := (global_basis.inverse() * up) * size * 0.5
		var column: int = ATLAS[kind]
		var uv0 := Vector2(column / 4.0, 0.0)
		var uv1 := Vector2((column + 1) / 4.0, 1.0)
		var corners := [center - r + u, center + r + u, center + r - u, center - r - u]
		var uvs := [uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]
		var local_normal := global_basis.inverse() * normal
		# A face da frente para baixo (horário visto de quem olha do chão): com a face do verso
		# para baixo, a normal sairia virada para a rocha e a luz do fogo não pegaria.
		for index: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(local_normal)
			st.set_uv(uvs[index])
			st.add_vertex(corners[index])
	var mesh := MeshInstance3D.new()
	mesh.name = "Figures"
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = _atlas()
	material.albedo_color = PAINT
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


## Atlas 128×32 com as quatro figuras em traço grosso, como pintura rupestre.
static func _atlas() -> ImageTexture:
	var image := Image.create(CELL * 4, CELL, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var strokes := {
		# Cervo: corpo, quatro pernas, pescoço, cabeça e galhada.
		0: [[8, 16, 22, 15], [9, 16, 8, 26], [12, 16, 13, 26], [20, 15, 19, 26], [22, 15, 24, 25], [22, 15, 25, 9], [25, 9, 29, 10],
			[25, 9, 23, 3], [24, 6, 20, 5], [25, 9, 28, 3], [8, 16, 6, 13]],
		# Corvo: asas em V, corpo e cauda.
		1: [[4, 11, 11, 16], [11, 16, 16, 18], [16, 18, 21, 16], [21, 16, 28, 11], [16, 18, 16, 24], [15, 24, 17, 24]],
		# Lobo: corpo, pernas, cabeça com orelhas em pé e rabo.
		2: [[7, 15, 22, 15], [8, 15, 7, 25], [11, 15, 12, 25], [20, 15, 19, 25], [22, 15, 23, 25], [22, 15, 27, 12], [27, 12, 30, 14],
			[25, 13, 25, 8], [27, 12, 28, 8], [7, 15, 3, 10]],
		# Coelho: corpo redondo, orelhas compridas e rabinho.
		3: [[10, 20, 14, 16], [14, 16, 20, 16], [20, 16, 22, 20], [22, 20, 18, 24], [18, 24, 11, 24], [11, 24, 10, 20],
			[19, 16, 18, 6], [21, 17, 23, 7], [10, 21, 7, 20], [13, 24, 12, 27], [19, 24, 20, 27]],
	}
	for column: int in strokes:
		for stroke: Array in strokes[column]:
			_line(image, Vector2i(column * CELL + int(stroke[0]), int(stroke[1])), Vector2i(column * CELL + int(stroke[2]), int(stroke[3])))
	return ImageTexture.create_from_image(image)


## Traço de 2 px (dedo com tinta) de `a` até `b`.
static func _line(image: Image, a: Vector2i, b: Vector2i) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / maxf(steps, 1))
		for dx in 2:
			for dy in 2:
				var x := clampi(int(p.x) + dx, 0, image.get_width() - 1)
				var y := clampi(int(p.y) + dy, 0, image.get_height() - 1)
				image.set_pixel(x, y, Color.WHITE)
