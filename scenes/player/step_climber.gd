class_name StepClimber
extends RefCounted
## Subir degraus (F10): o CharacterBody3D sozinho para em qualquer quina acima da curva da
## cápsula (~9 cm), e o goblin ficava preso em pedra baixa, entulho e bloco caído. Depois do
## move_and_slide, se ele andou contra uma parede, três testes de movimento perguntam se cabe
## um degrau: subir Tuning.STEP_HEIGHT, andar Tuning.STEP_PROBE e descer até um chão que não
## seja íngreme demais. Se o degrau ganho for pequeno o bastante, o corpo sobe na hora.
##
## O tranco não aparece: `offset` guarda o degrau (negativo, o corpo visível fica embaixo do
## físico) e volta a 0 em Tuning.STEP_SMOOTH s. O Player desce o Visual e a câmera por ele, e
## o animador põe cada pé no chão de verdade (_ground_feet).

## Quanto o corpo visível está abaixo do físico (≤ 0), voltando a 0.
var offset := 0.0

var _body: CharacterBody3D


func _init(body: CharacterBody3D) -> void:
	_body = body


func step(delta: float, direction: Vector3) -> void:
	offset *= exp(-delta / Tuning.STEP_SMOOTH)
	if absf(offset) < 0.001:
		offset = 0.0
	if not _body.is_on_floor() or not _body.is_on_wall():
		return
	var ahead := Vector3(direction.x, 0.0, direction.z)
	if ahead.length_squared() < 0.01:
		return
	ahead = ahead.normalized()
	# Só sobe o que está na frente (a parede contra o passo), não o que raspa de lado.
	var wall := _body.get_wall_normal()
	if Vector2(wall.x, wall.z).normalized().dot(Vector2(ahead.x, ahead.z)) > -0.4:
		return
	var from := _body.global_transform
	var up := _travel(from, Vector3.UP * Tuning.STEP_HEIGHT)
	if up.y < Tuning.STEP_MIN:
		return
	var raised := from.translated(up)
	var forward := _travel(raised, ahead * Tuning.STEP_PROBE)
	if forward.length() < Tuning.STEP_PROBE * 0.5:
		return
	var moved := raised.translated(forward)
	var result := PhysicsTestMotionResult3D.new()
	if not _test(moved, Vector3.DOWN * (up.y + 0.05), result):
		return
	if result.get_collision_normal().angle_to(Vector3.UP) > _body.floor_max_angle:
		return
	var gain := up.y + result.get_travel().y
	if gain < Tuning.STEP_MIN or gain > Tuning.STEP_HEIGHT:
		return
	# Sobe o degrau e entra só um pouco nele: o resto do passo vem do próprio movimento, e o
	# floor_snap assenta o corpo no chão de cima.
	_body.global_position += Vector3.UP * (gain + 0.01) + ahead * minf(forward.length(), 0.05)
	offset -= gain


## Quanto o corpo anda de `from` na direção `motion` antes de bater.
func _travel(from: Transform3D, motion: Vector3) -> Vector3:
	var result := PhysicsTestMotionResult3D.new()
	return result.get_travel() if _test(from, motion, result) else motion


func _test(from: Transform3D, motion: Vector3, result: PhysicsTestMotionResult3D) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	params.margin = _body.safe_margin
	return PhysicsServer3D.body_test_motion(_body.get_rid(), params, result)
