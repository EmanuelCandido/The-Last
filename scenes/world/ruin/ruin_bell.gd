class_name RuinBell
extends Node3D
## O sino rachado da espadana da ruína (F10). Balança com o vento no alto (Wind.aloft_at: a 5 m
## do chão ele fica acima do abrigo da mata, que no chão da ruína quase zera o vento) e, quando o balanço passa de Tuning.BELL_HIT_SWING, o badalo bate na
## boca do sino no fim de cada ida: uma batida surda e desafinada que se ouve longe na neblina.
## É um marco pelo som (a ruína fica "ali"), e uma pista de duas leituras: é o mesmo sino da
## cidade de verdade, que Ari ouve no Final 2.
##
## Este nó fica no eixo, embaixo da verga; o sino pendura em -Y. Montado pela Ruin.

const SOUNDS := [preload("res://assets/audio/sfx/bell_clank_1.wav"), preload("res://assets/audio/sfx/bell_clank_2.wav")]
const METAL := preload("res://assets/textures/metal.png")
## Perfil do sino (raio, altura abaixo do eixo), da coroa até a boca.
const PROFILE := [
	Vector2(0.03, 0.0), Vector2(0.08, 0.02), Vector2(0.1, 0.06), Vector2(0.105, 0.14),
	Vector2(0.115, 0.22), Vector2(0.14, 0.29), Vector2(0.165, 0.33), Vector2(0.16, 0.345),
]
const SIDES := 12

## Quantas vezes o badalo bateu (o diário de playtest e os testes leem).
var strikes := 0

var _bell: Node3D
var _clapper: Node3D
## Fase e tamanho do balanço (rad); o tamanho segue o vento devagar.
var _phase := 0.0
var _swing := 0.0
var _cooldown := 0.0
var _last_sign := 0.0


func _ready() -> void:
	_bell = Node3D.new()
	_bell.name = "Bell"
	add_child(_bell)
	var body := MeshInstance3D.new()
	body.mesh = _bell_mesh()
	_bell.add_child(body)
	_clapper = Node3D.new()
	_clapper.name = "Clapper"
	_bell.add_child(_clapper)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _metal_material()
	ball.mesh = sphere
	ball.position = Vector3.DOWN * 0.3
	_clapper.add_child(ball)
	_phase = randf() * TAU


func _process(delta: float) -> void:
	_cooldown -= delta
	var wind := Wind.aloft_at(global_position)
	var target := smoothstep(Tuning.BELL_WIND_THRESHOLD * 0.6, 1.0, wind) * Tuning.BELL_MAX_SWING
	_swing = lerpf(_swing, target, 1.0 - exp(-0.8 * delta))
	_phase += delta * TAU / Tuning.BELL_PERIOD
	var angle := sin(_phase) * _swing
	_bell.rotation.x = angle
	# O badalo atrasa um pouco atrás do sino e alcança a boca no fim da ida.
	_clapper.rotation.x = -sin(_phase - 0.5) * _swing * 0.6
	var side := signf(cos(_phase))
	if side != _last_sign:
		_last_sign = side
		if _swing > Tuning.BELL_HIT_SWING and wind > Tuning.BELL_WIND_THRESHOLD and _cooldown <= 0.0:
			_strike(_swing)


func _strike(swing: float) -> void:
	_cooldown = Tuning.BELL_COOLDOWN
	strikes += 1
	var strong := swing > Tuning.BELL_MAX_SWING * 0.7
	var sound: AudioStream = SOUNDS[0] if strong else SOUNDS[1]
	OccludedAudio.play_at(get_parent(), sound, global_position + Vector3.DOWN * 0.2, &"Ambience",
		Tuning.BELL_DB, Tuning.BELL_UNIT_SIZE, randf_range(0.97, 1.03))


## Perfil girado em volta de Y: casca de bronze sem tampa embaixo (a boca é aberta).
func _bell_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		for j in PROFILE.size() - 1:
			var p: Vector2 = PROFILE[j]
			var q: Vector2 = PROFILE[j + 1]
			var v00 := Vector3(sin(a0) * p.x, -p.y, cos(a0) * p.x)
			var v10 := Vector3(sin(a1) * p.x, -p.y, cos(a1) * p.x)
			var v01 := Vector3(sin(a0) * q.x, -q.y, cos(a0) * q.x)
			var v11 := Vector3(sin(a1) * q.x, -q.y, cos(a1) * q.x)
			for v: Vector3 in [v00, v11, v10, v00, v01, v11]:
				st.set_uv(Vector2(atan2(v.x, v.z) / TAU, -v.y * 3.0))
				st.add_vertex(v)
	st.generate_normals()
	st.set_material(_metal_material())
	return st.commit()


## Bronze velho: o metal das texturas, esverdeado e escuro, triplanar como o resto.
func _metal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = METAL
	material.albedo_color = Color(0.42, 0.4, 0.3)
	material.metallic = 0.6
	material.roughness = 0.7
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 8.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
