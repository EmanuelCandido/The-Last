class_name Torch
extends Node3D
## Tocha (§4.10): um pau com a ponta de resina acesa por Tuning.TORCH_SECONDS. É fogo de
## verdade para o resto do jogo (grupo Campfire.FIRE_GROUP): esquenta perto e os lobos não
## chegam. Quem a carrega é o TorchCarry; fincada no chão (ao mirar o arco) dá para pegar
## de volta com E. A origem é onde a mão segura.

signal burned_out

const FIRE_LOOP := preload("res://assets/audio/real/campfire_loop.wav")
## Pau apagado fica no chão este tanto antes de sumir (s).
const ASH_SECONDS := 40.0

## Fincada no chão (não está na mão de ninguém).
var planted := false

var _left := Tuning.TORCH_SECONDS
var _flame: GPUParticles3D
var _light: OmniLight3D
var _crackle: OccludedAudio
var _head: MeshInstance3D
var _flicker := randf() * 10.0


func _ready() -> void:
	add_to_group(Campfire.FIRE_GROUP)
	add_to_group(&"interactable")
	_build()
	Clock.skipped.connect(func(_hours: float) -> void: _burn_out())


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	_flicker += delta
	# Acabando, a chama encolhe.
	var strength := clampf(_left / 25.0, 0.25, 1.0)
	_light.light_energy = (1.05 + sin(_flicker * 17.0) * 0.08 + sin(_flicker * 7.3) * 0.12) * strength
	_light.omni_range = 6.5 * sqrt(strength)
	_flame.amount_ratio = strength
	if _left <= 0.0:
		_burn_out()


func is_lit() -> bool:
	return _left > 0.0


## Segundos que ainda queima.
func time_left() -> float:
	return maxf(_left, 0.0)


func interaction_prompt() -> String:
	return "Pegar a tocha" if planted and is_lit() else ""


func interact(player: Node) -> void:
	var carry := player.get_node_or_null(^"TorchCarry") as TorchCarry
	if carry != null:
		carry.take(self)


func _burn_out() -> void:
	if _left <= -1.0:
		return
	_left = -1.0
	remove_from_group(Campfire.FIRE_GROUP)
	_flame.emitting = false
	_light.visible = false
	_crackle.stop()
	(_head.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3
	burned_out.emit()
	get_tree().create_timer(ASH_SECONDS, false).timeout.connect(queue_free)


func _build() -> void:
	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.014
	stick_mesh.bottom_radius = 0.017
	stick_mesh.height = 0.5
	stick_mesh.radial_segments = 6
	stick_mesh.rings = 1
	stick.mesh = stick_mesh
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/textures/wood.png")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	wood.roughness = 0.9
	stick.material_override = wood
	stick.position = Vector3(0.0, 0.1, 0.0)
	add_child(stick)
	# Ponta enrolada em couro com resina: escura, com brasa por baixo da chama.
	_head = MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.03
	head_mesh.bottom_radius = 0.024
	head_mesh.height = 0.09
	head_mesh.radial_segments = 7
	head_mesh.rings = 1
	_head.mesh = head_mesh
	var resin := StandardMaterial3D.new()
	resin.albedo_color = Color(0.09, 0.06, 0.04)
	resin.emission_enabled = true
	resin.emission = Color(1.0, 0.35, 0.08)
	resin.emission_energy_multiplier = 1.4
	resin.roughness = 0.8
	_head.material_override = resin
	_head.position = Vector3(0.0, 0.36, 0.0)
	add_child(_head)

	_flame = GPUParticles3D.new()
	_flame.amount = 16
	_flame.lifetime = 0.45
	_flame.local_coords = false
	_flame.position = Vector3(0.0, 0.41, 0.0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.03
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.5
	process.gravity = Vector3(0.0, 0.9, 0.0)
	process.scale_min = 0.7
	process.scale_max = 1.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.5))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	var shrink_texture := CurveTexture.new()
	shrink_texture.curve = shrink
	process.scale_curve = shrink_texture
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	colors.colors = PackedColorArray([Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.45, 0.12, 0.8), Color(0.5, 0.1, 0.02, 0.0)])
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = colors
	process.color_ramp = color_texture
	_flame.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.14)
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fire.vertex_color_use_as_albedo = true
	var soft := Gradient.new()
	soft.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var soft_texture := GradientTexture2D.new()
	soft_texture.gradient = soft
	soft_texture.width = 32
	soft_texture.height = 32
	soft_texture.fill = GradientTexture2D.FILL_RADIAL
	soft_texture.fill_from = Vector2(0.5, 0.5)
	soft_texture.fill_to = Vector2(0.5, 0.0)
	fire.albedo_texture = soft_texture
	quad.material = fire
	_flame.draw_pass_1 = quad
	add_child(_flame)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.omni_range = 6.5
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = true
	_light.position = Vector3(0.0, 0.45, 0.0)
	add_child(_light)

	_crackle = OccludedAudio.new()
	_crackle.stream = FIRE_LOOP
	_crackle.clear_bus = &"World"
	_crackle.volume_db = -14.0
	_crackle.unit_size = 1.5
	_crackle.max_distance = 20.0
	_crackle.position = Vector3(0.0, 0.4, 0.0)
	_crackle.autoplay = true
	add_child(_crackle)
