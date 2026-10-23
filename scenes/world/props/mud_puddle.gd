class_name MudPuddle
extends Node3D
## Poça de lama (ForestLayout.MUD_SPOTS), §4.11. "Esfregar lama" (3 s, animação rub_mud)
## cobre o goblin: Vitals.mud vai a 1 e o MudCamouflage faz o resto.

const RUB_SOUND := preload("res://assets/audio/sfx/mud_rub.wav")
## Raio médio da poça (m) e quantos pontos tem a borda.
const RADIUS := 1.1
const EDGE_POINTS := 20


## Monta a poça colada no chão. `height_at(x, z)` dá a altura do terreno.
func build(height_at: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(position.x), roundi(position.z)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := _ground_point(Vector2.ZERO, height_at)
	var edge: Array[Vector3] = []
	var wobble := [rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
	for i in EDGE_POINTS:
		var angle := TAU * i / EDGE_POINTS
		var radius := RADIUS * (1.0 + 0.22 * sin(angle * 2.0 + wobble[0]) + 0.12 * sin(angle * 5.0 + wobble[1]) + rng.randf_range(-0.05, 0.05))
		edge.append(_ground_point(Vector2.from_angle(angle) * radius, height_at))
	# Anel do meio: a lama tem volume, a borda afina até o chão.
	var inner: Array[Vector3] = []
	for point in edge:
		var mid := center.lerp(point, 0.6)
		inner.append(_ground_point(Vector2(mid.x, mid.z), height_at) + Vector3.UP * 0.012)
	for i in EDGE_POINTS:
		var j := (i + 1) % EDGE_POINTS
		# Horário visto de cima (face da frente no Godot).
		_triangle(st, center + Vector3.UP * 0.016, inner[i], inner[j])
		_triangle(st, inner[i], edge[j], inner[j])
		_triangle(st, inner[i], edge[i], edge[j])
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	add_to_group(&"interactable")


func interaction_prompt() -> String:
	return "Esfregar lama"


func interaction_action() -> Dictionary:
	return {"action": &"rub_mud", "duration": Tuning.MUD_RUB_TIME, "at": Tuning.MUD_RUB_TIME - 0.4}


func interaction_started(player: Node) -> void:
	OccludedAudio.play_at(get_parent(), RUB_SOUND, (player as Node3D).global_position + Vector3.UP * 0.4, &"World", -4.0, 2.5)


func interact(_player: Node) -> void:
	Vitals.mud = 1.0
	Events.notification_shown.emit("Coberto de lama: mais difícil de ver e de farejar.")


func _ground_point(local: Vector2, height_at: Callable) -> Vector3:
	var ground: float = height_at.call(position.x + local.x, position.z + local.y)
	return Vector3(local.x, ground - position.y + 0.02, local.y)


func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(point.x, point.z) * 0.8)
		st.add_vertex(point)


## Terra encharcada: escura, lisa e brilhando um pouco (água em cima).
static func _material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/ground_dirt.png")
	material.albedo_color = Color(0.66, 0.52, 0.38)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.5
	material.metallic_specular = 0.35
	return material
