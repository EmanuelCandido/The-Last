class_name AimGuide
extends MeshInstance3D
## A mira com fôlego (§8b-C): com o arco puxado e o ar preso (Q), aparece um arco fraco, em
## tracinhos, mostrando por onde a flecha vai cair (a mesma conta da Arrow: velocidade de saída,
## gravidade do tipo de flecha). Para onde bate num tronco ou no chão. Sem o ar preso, nada.
##
## Parte do goblin: filho do Player (top_level, no mundo). Tirar o nó tira a mecânica.

const STEP := 0.025
const MASK := 1 | 2

var _player: Player
var _mesh := ImmediateMesh.new()
var _fade := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material_override = material


func _process(delta: float) -> void:
	_mesh.clear_surfaces()
	global_transform = Transform3D.IDENTITY
	var item := _player.arrow_item()
	var on := _player.aiming and _player.breath_held and _player.draw > 0.2 and item != &""
	_fade = move_toward(_fade, 1.0 if on else 0.0, delta * 3.0)
	if _fade <= 0.01 or item == &"":
		return
	var position := _player.arrow_origin()
	var velocity := Arrow.start_velocity(_player.aim_point() - position, _player.draw, _player.bow_speed())
	var gravity := Arrow.gravity_of(item)
	var space := _player.get_world_3d().direct_space_state
	var travelled := 0.0
	var step := 0
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var drawn := false
	while travelled < Tuning.AIM_GUIDE_MAX and step < 400:
		var next := position + velocity * STEP
		velocity += Vector3.DOWN * gravity * STEP
		var query := PhysicsRayQueryParameters3D.create(position, next, MASK, [_player.get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			next = hit.position
		# Tracinhos: um sim, um não; somem para longe e logo perto do arco.
		if step % 2 == 0 and travelled > 1.0:
			var alpha := 0.35 * _fade * (1.0 - travelled / Tuning.AIM_GUIDE_MAX)
			_mesh.surface_set_color(Color(0.9, 0.88, 0.8, alpha))
			_mesh.surface_add_vertex(position)
			_mesh.surface_set_color(Color(0.9, 0.88, 0.8, alpha))
			_mesh.surface_add_vertex(next)
			drawn = true
		travelled += position.distance_to(next)
		position = next
		step += 1
		if not hit.is_empty():
			break
	if not drawn:
		# Uma superfície vazia não pode ser fechada: um traço invisível no lugar.
		_mesh.surface_set_color(Color(0.0, 0.0, 0.0, 0.0))
		_mesh.surface_add_vertex(position)
		_mesh.surface_add_vertex(position)
	_mesh.surface_end()
