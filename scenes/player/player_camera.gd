class_name PlayerCamera
extends RefCounted
## A câmera sobre o ombro do goblin (tirada do Player na F10). Uma esfera vai do pivô (nuca)
## até o ombro e de lá para trás; onde ela bater, a câmera para. Ao bater, encolhe na hora
## (nunca mostra o outro lado da parede); quando o caminho abre, volta devagar. Mirando, chega
## mais perto (Tuning.AIM_CAMERA_DISTANCE) e mais para o lado (Tuning.AIM_SHOULDER).
##
## Colada no goblin, o que está perto da lente some em dither, pixel a pixel
## (Tuning.CAMERA_FADE_NEAR..FAR), em vez de a lente entrar na cabeça. Nada fica translúcido:
## transparência de verdade mostraria o interior da boca e dos olhos. Colado na lente, some de
## vez (CAMERA_HIDE_DISTANCE).

## A câmera só bate no mundo (terreno, caverna, pedras): tronco fino na frente não a empurra.
const MASK := 1
## Raio da esfera que testa o caminho da câmera (folga entre a lente e a rocha).
const RADIUS := 0.22

var pivot: Node3D
var arm: Node3D
var camera: Camera3D

var _body: CharacterBody3D
var _visual: Node3D
var _rest_height := 0.0
## Altura do pivô sem o degrau (agachado, mirando), que segue devagar.
var _height := 0.0
var _distance := 3.0
var _shoulder_rest := 0.45
var _length := 0.0
var _shoulder := 0.0
## Comprimento real do braço depois das colisões (encolhe na hora, volta devagar).
var _arm_length := 0.0
var _probe := SphereShape3D.new()
var _model_hidden := false


func _init(body: CharacterBody3D, visual: Node3D, camera_pivot: Node3D, distance: float, shoulder: float) -> void:
	_body = body
	_visual = visual
	pivot = camera_pivot
	arm = pivot.get_node("CameraArm")
	camera = arm.get_node("Camera3D")
	_rest_height = pivot.position.y
	_height = _rest_height
	_distance = distance
	_shoulder_rest = shoulder
	_length = distance
	_shoulder = shoulder
	_arm_length = distance
	_probe.radius = RADIUS
	camera.fov = Settings.fov


## Um frame: aproxima mirando, abaixa agachado, acompanha o degrau (`lift`, ≤ 0, o corpo
## visível embaixo do físico) e põe a lente onde cabe.
func update(delta: float, aiming: bool, crouching: bool, draw: float, lift: float) -> void:
	var weight := 1.0 - exp(-10.0 * delta)
	_length = lerpf(_length, Tuning.AIM_CAMERA_DISTANCE if aiming else _distance, weight)
	_shoulder = lerpf(_shoulder, Tuning.AIM_SHOULDER if aiming else _shoulder_rest, weight)
	# O campo de visão vem das Configurações; mirando, fecha e aproxima mais com a corda puxada.
	var aim_fov := Settings.fov - Tuning.SETTINGS_AIM_FOV_DROP - draw * 6.0
	camera.fov = lerpf(camera.fov, aim_fov if aiming else Settings.fov, weight)
	var height := _rest_height - (0.25 if crouching else 0.0) + (Tuning.AIM_PIVOT_RISE if aiming else 0.0)
	_height = lerpf(_height, height, weight)
	pivot.position.y = _height + lift
	_place(delta)


## Gira a câmera (rad), com o olhar para cima e para baixo preso em `min_pitch`..`max_pitch`.
func rotate_by(yaw: float, pitch: float, min_pitch: float, max_pitch: float) -> void:
	pivot.rotate_y(yaw)
	arm.rotation.x = clampf(arm.rotation.x + pitch, min_pitch, max_pitch)


func _place(delta: float) -> void:
	var xf := arm.global_transform
	var side := xf.basis.x * _shoulder
	var shoulder := xf.origin + side * _sweep(xf.origin, side)
	var back := xf.basis.z * _length
	var free_length := _length * _sweep(shoulder, back)
	if free_length < _arm_length:
		_arm_length = free_length
	else:
		_arm_length = lerpf(_arm_length, free_length, 1.0 - exp(-3.0 * delta))
	camera.global_position = shoulder + xf.basis.z * _arm_length
	_fade_model()


## Fração livre (0..1) do movimento da esfera da câmera de `from` até `from + motion`.
func _sweep(from: Vector3, motion: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.collision_mask = MASK
	query.exclude = [_body.get_rid()]
	var result := _body.get_world_3d().direct_space_state.cast_motion(query)
	return result[0]


func _fade_model() -> void:
	var distance := camera.global_position.distance_to(_visual.global_position + Vector3.UP * 0.7)
	# O dither é do material: só precisa ligar nos que ainda não têm (itens que chegam na mão).
	if distance < Tuning.CAMERA_FADE_FAR + 1.0:
		_dither_near_camera()
	var hidden := distance < Tuning.CAMERA_HIDE_DISTANCE
	if hidden == _model_hidden:
		return
	_model_hidden = hidden
	for node in _visual.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).visible = not hidden


func _dither_near_camera() -> void:
	for node in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material == null or material.has_meta(&"camera_dither"):
				continue
			material.set_meta(&"camera_dither", true)
			if material is StandardMaterial3D:
				var standard := material as StandardMaterial3D
				standard.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				standard.distance_fade_min_distance = Tuning.CAMERA_FADE_NEAR
				standard.distance_fade_max_distance = Tuning.CAMERA_FADE_FAR
			elif material is ShaderMaterial and (material as ShaderMaterial).shader == GoblinLook.SHADER:
				(material as ShaderMaterial).set_shader_parameter(&"camera_fade_near", Tuning.CAMERA_FADE_NEAR)
				(material as ShaderMaterial).set_shader_parameter(&"camera_fade_far", Tuning.CAMERA_FADE_FAR)
