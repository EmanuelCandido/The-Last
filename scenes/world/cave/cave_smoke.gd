class_name CaveSmoke
extends GPUParticles3D
## A fumaça da toca vista de longe (F10): com a fogueira acesa, uma coluna de fumaça sai pelo
## alto da boca da caverna, sobe 20 a 30 m e deita para o lado do vento. Acima das árvores ela
## aparece na neblina e mostra onde fica a toca, até onde a neblina deixa ver.
##
## Bolos de fumaça (smoke_puff.png, pixelado) em quads virados para a câmera, com transparência
## de verdade: em dither (ALPHA_HASH) a fumaça virava um chuvisco de pontos que piscava. Quanto
## mais lenha, mais fumaça. Filho da Cave.

const TEXTURE := preload("res://assets/textures/smoke_puff.png")

var fire: Campfire

var _process_material := ParticleProcessMaterial.new()
var _wind_timer := 0.0


func _ready() -> void:
	amount = Tuning.CAVE_SMOKE_AMOUNT
	lifetime = Tuning.CAVE_SMOKE_LIFETIME
	preprocess = Tuning.CAVE_SMOKE_LIFETIME
	fixed_fps = 15
	local_coords = false
	visibility_aabb = AABB(Vector3(-40.0, -4.0, -40.0), Vector3(80.0, 60.0, 80.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process_material = _process_material
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_process_material.emission_sphere_radius = 0.6
	_process_material.direction = Vector3.UP
	_process_material.spread = 9.0
	_process_material.initial_velocity_min = Tuning.CAVE_SMOKE_RISE * 0.8
	_process_material.initial_velocity_max = Tuning.CAVE_SMOKE_RISE * 1.2
	_process_material.damping_min = 0.05
	_process_material.damping_max = 0.1
	_process_material.angle_min = -180.0
	_process_material.angle_max = 180.0
	_process_material.angular_velocity_min = -6.0
	_process_material.angular_velocity_max = 6.0
	# Sem turbulência: com ela os bolos se espalhavam 12 m para os lados e a coluna se desmanchava.
	# Cresce ao subir: começa do tamanho da boca e abre.
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	_process_material.scale_curve = grow_texture
	_process_material.scale_min = 0.8
	_process_material.scale_max = 1.2
	# Entra rápido, fica e some devagar no alto.
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.55, 1.0])
	var tint: Color = Tuning.CAVE_SMOKE_COLOR
	fade.colors = PackedColorArray([Color(tint, 0.0), Color(tint, 0.75), Color(tint, 0.5), Color(tint, 0.0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	_process_material.color_ramp = fade_texture

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * Tuning.CAVE_SMOKE_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_texture = TEXTURE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.roughness = 1.0
	# A neblina de 0,016 apagava a coluna antes dos 60 m. Fora dela, a fumaça some aos poucos com
	# a distância (de CAVE_SMOKE_FADE.x a .y m): de longe, um traço escuro acima das árvores.
	material.disable_fog = true
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = Tuning.CAVE_SMOKE_FADE.y
	material.distance_fade_max_distance = Tuning.CAVE_SMOKE_FADE.x
	quad.material = material
	draw_pass_1 = quad
	_update_wind()
	_update_fuel()


func _process(delta: float) -> void:
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_wind_timer = 1.0
		_update_wind()
		_update_fuel()


## O vento deita a coluna: empurra para o lado dele e o resto é a fumaça quente subindo.
func _update_wind() -> void:
	var push := Wind.direction * Wind.intensity * Tuning.CAVE_SMOKE_WIND
	_process_material.gravity = Vector3(push.x, Tuning.CAVE_SMOKE_BUOYANCY, push.y)


## Só mexe quando muda: reaplicar `emitting` e `amount_ratio` reinicia as partículas, e a coluna
## não passava de um bolo junto da boca.
func _update_fuel() -> void:
	var lit := fire != null and fire.is_lit()
	if emitting != lit:
		emitting = lit
	var ratio := snappedf(clampf(0.35 + 0.65 * fire.fuel / Tuning.FIRE_MAX_FUEL, 0.0, 1.0), 0.25) if lit else amount_ratio
	if not is_equal_approx(ratio, amount_ratio):
		amount_ratio = ratio
