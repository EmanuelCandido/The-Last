class_name Tracks
extends MultiMeshInstance3D
## Pegadas dos bichos no chão (§4.8): um MultiMesh com Tuning.TRACK_POOL pegadas que se
## reaproveitam (a mais velha dá lugar à nova). Cada uma some aos poucos em
## Tuning.TRACK_SECONDS; o desenho (casco, pata de coelho, pata de lobo) é do shader.
##
## Quem anda chama Tracks.stamp(); quem procura pegadas chama Tracks.nearest().

## Desenho de cada espécie no shader (INSTANCE_CUSTOM.r).
const SHAPES := {&"deer": 0.0, &"rabbit": 1.0, &"wolf": 2.0}
const SHADER := preload("res://assets/shaders/track_print.gdshader")
## Altura acima do chão (m), para não piscar com o terreno.
const LIFT := 0.012

static var _current: Tracks

## Relógio próprio (s): pausa com o jogo e pula junto quando o goblin dorme.
var _time := 0.0
var _next := 0
var _stamped_at := PackedFloat32Array()
var _positions := PackedVector3Array()
var _kinds: Array[StringName] = []


func _ready() -> void:
	_current = self
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = Tuning.TRACK_POOL
	_stamped_at.resize(Tuning.TRACK_POOL)
	_positions.resize(Tuning.TRACK_POOL)
	_kinds.resize(Tuning.TRACK_POOL)
	for i in Tuning.TRACK_POOL:
		_stamped_at[i] = -INF
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"lifetime", Tuning.TRACK_SECONDS)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# As pegadas ficam pelo vale inteiro: a caixa de visibilidade não pode ser a do quad.
	custom_aabb = AABB(Vector3(-200.0, -50.0, -200.0), Vector3(400.0, 150.0, 400.0))
	Clock.skipped.connect(func(hours: float) -> void: _time += hours * Tuning.SECONDS_PER_HOUR)


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _process(delta: float) -> void:
	_time += delta
	(material_override as ShaderMaterial).set_shader_parameter(&"now", _time)


## Deixa uma pegada em `at`, deitada no chão de normal `normal`, apontando para `yaw`.
## `size` é a largura e o comprimento (m).
static func stamp(at: Vector3, normal: Vector3, yaw: float, size: Vector2, kind: StringName) -> void:
	if _current != null:
		_current._stamp(at, normal, yaw, size, kind)


## A pegada de `kind` mais perto de `at` (até `max_distance`), ou Vector3.INF.
static func nearest(kind: StringName, at: Vector3, max_distance: float) -> Vector3:
	if _current == null:
		return Vector3.INF
	return _current._nearest(kind, at, max_distance)


func _stamp(at: Vector3, normal: Vector3, yaw: float, size: Vector2, kind: StringName) -> void:
	var i := _next
	_next = (_next + 1) % Tuning.TRACK_POOL
	var up := normal.normalized()
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	forward = (forward - up * forward.dot(up)).normalized()
	var side := up.cross(forward)
	var basis := Basis(side * size.x, up, forward * size.y)
	multimesh.set_instance_transform(i, Transform3D(basis, at + up * LIFT))
	multimesh.set_instance_custom_data(i, Color(SHAPES.get(kind, 0.0), _time, randf(), 0.0))
	_stamped_at[i] = _time
	_positions[i] = at
	_kinds[i] = kind


func _nearest(kind: StringName, at: Vector3, max_distance: float) -> Vector3:
	var best := Vector3.INF
	var best_distance := max_distance
	for i in Tuning.TRACK_POOL:
		if _kinds[i] != kind or _time - _stamped_at[i] > Tuning.TRACK_SECONDS:
			continue
		var distance := _positions[i].distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = _positions[i]
	return best
