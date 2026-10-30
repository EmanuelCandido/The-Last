class_name PlayerGear
extends RefCounted
## O arco na mão e a aljava nas costas (tirados do Player na F10), e o que se prende às mãos.
##
## O arco (HeldBow) é posto na mão por código a cada frame (`orient`), sem socket: a mão da
## corda é levada até ele no mesmo frame, então não pode haver atraso de um frame. Carregado,
## passa pelo punho como um pau e balança com o braço; mirando, fica em pé (um pouco deitado)
## com a barriga para o alvo. A corda vai até onde o animador levou a mão direita.

## Arco carregado: deitado para a frente, a ponta de cima CARRY_RISE (rad) acima da
## horizontal; balança com o antebraço (CARRY_SWING da diferença), como um pau no punho.
const CARRY_RISE := 0.45
const CARRY_SWING := 0.4
## Mirando, o arco deita um pouco (topo para a direita), como o de um arqueiro destro.
const BOW_CANT := 0.15
## Arma de uma mão: o cabo sai do punho este ângulo (rad) acima do antebraço, como com o pulso
## dobrado de quem segura a faca para a frente (a 90°, punho reto, a faca apontava para o rosto).
const ONE_HAND_TILT := 0.65

var bow: Node3D
var quiver: Node3D
## A arma de mão (F11) e qual é ela (&"" = nenhuma); o arco vai para as costas enquanto ela está na mão.
var weapon: MeshInstance3D
var weapon_item := &""

var _back_bow: MeshInstance3D
var _weapon_axis := Vector3.UP

var _visual: Node3D
var _model: Node3D


func _init(visual: Node3D, model: Node3D) -> void:
	_visual = visual
	_model = model


## Mostra o arco na mão e a aljava nas costas quando o goblin tem o arco.
func update(animator: GoblinAnimator) -> void:
	var has_bow := Inventory.has(&"bow")
	if has_bow and bow == null:
		bow = HeldBow.new()
		_visual.add_child(bow)
		quiver = attach(BowMesh.build_quiver(), "tronco*tras")
		# Na diagonal das costas (boca sobre o ombro direito); acompanha o giro do tronco.
		quiver.basis = Basis(Vector3.BACK, 0.35) * Basis(Vector3.RIGHT, -0.2)
		if animator != null:
			var grip := _model.find_child("braco_E*mao", true, false) as Node3D
			if grip != null:
				animator.bow_grip = grip.transform.origin
	if bow != null:
		bow.visible = has_bow and weapon_item == &""
		quiver.visible = has_bow
	if has_bow and _back_bow == null:
		_back_bow = attach(BowMesh.build_bow(), "tronco*tras") as MeshInstance3D
		# Atravessado nas costas, cruzando a aljava.
		_back_bow.basis = Basis(Vector3.BACK, -0.7) * Basis(Vector3.UP, PI * 0.5)
		_back_bow.position += Vector3(0.0, 0.0, -0.03)
	if _back_bow != null:
		_back_bow.visible = has_bow and weapon_item != &""


## Põe `item` na mão direita (&"" tira a arma e devolve o arco à mão).
func set_weapon(item: StringName, animator: GoblinAnimator) -> void:
	if item == weapon_item:
		return
	weapon_item = item
	if weapon != null:
		weapon.queue_free()
		weapon = null
	if item != &"":
		weapon = MeshInstance3D.new()
		weapon.mesh = WeaponMesh.build(item)
		_visual.add_child(weapon)
		if animator != null:
			var grip := _model.find_child("braco_D*mao", true, false) as Node3D
			if grip != null:
				animator.weapon_grip = grip.transform.origin
	update(animator)


## A arma segue a mão no mesmo frame da pose (como o arco). Com uma mão, o cabo sai do punho
## ONE_HAND_TILT acima do antebraço; com duas (a lança), vai da mão de trás para a da frente.
func orient_weapon(animator: GoblinAnimator) -> void:
	if weapon == null or animator == null:
		return
	var grip := animator.weapon_grip_position()
	var side := _visual.global_basis.x
	var axis: Vector3
	if Weapons.two_handed(weapon_item):
		axis = animator.hand_position(true) - grip
		if axis.length() < 0.06:
			axis = _visual.global_basis.z
	else:
		axis = animator.forearm_direction(false).rotated(side, -ONE_HAND_TILT)
	axis = axis.normalized()
	var x := side - axis * side.dot(axis)
	if x.length_squared() < 0.0001:
		x = _visual.global_basis.z.cross(axis)
	x = x.normalized()
	_weapon_axis = axis
	weapon.global_transform = Transform3D(Basis(x, axis, x.cross(axis).normalized()), grip)


## Por onde a lâmina passa agora: [começo, ponta] no mundo (vazio sem arma).
func weapon_segment() -> Array[Vector3]:
	if weapon == null:
		return []
	var length: float = Weapons.spec(weapon_item).get("length", 0.3)
	var grip := weapon.global_position
	if Weapons.two_handed(weapon_item):
		var ahead := length * (1.0 - WeaponMesh.SPEAR_GRIP)
		return [grip + _weapon_axis * ahead * 0.35, grip + _weapon_axis * ahead]
	return [grip + _weapon_axis * 0.04, grip + _weapon_axis * length]


func orient(animator: GoblinAnimator, draw: float, nocked: bool) -> void:
	if bow == null or not bow.visible:
		return
	if bow is HeldBow and animator != null:
		var side := _visual.global_basis.x
		var level := _visual.global_basis.z.rotated(side, -CARRY_RISE)
		var swung := (-animator.forearm_direction(true)).rotated(side, PI * 0.5)
		var up := level.lerp(swung, CARRY_SWING).normalized()
		var belly := side.cross(up).normalized()
		up = belly.cross(side).normalized()
		var held := Basis(up.cross(belly), up, belly).get_rotation_quaternion()
		var grip := animator.bow_grip_position()
		var weight := animator.aim_weight()
		if weight > 0.001 and animator.aim_point != Vector3.INF:
			var aimed := Basis.looking_at(animator.aim_point - grip, Vector3.UP, true) * Basis(Vector3.BACK, BOW_CANT)
			held = held.slerp(aimed.get_rotation_quaternion(), weight)
		bow.global_transform = Transform3D(Basis(held), grip)
		(bow as HeldBow).pose_string(draw, nocked)


func attach(mesh: Mesh, socket_pattern: String) -> Node3D:
	var holder := MeshInstance3D.new()
	holder.mesh = mesh
	return attach_node(holder, socket_pattern)


func attach_node(node: Node3D, socket_pattern: String) -> Node3D:
	var socket := _model.find_child(socket_pattern, true, false) as Node3D
	(socket if socket != null else _visual).add_child(node)
	return node
