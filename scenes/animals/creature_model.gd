class_name CreatureModel
extends RefCounted
## O corpo de um bicho: o modelo com esqueleto (assets/models/animals/*.glb) preso a pivôs.
##
## Cada osso vira um Node3D (pivô) com o nome dele, na mesma hierarquia e na posição de repouso
## da junta, sem giro. O código do bicho anima os pivôs como antes (rotation, position), e
## `sync()` leva a pele junto: cada osso faz o mesmo movimento que o pivô dele fez desde o
## repouso. Assim flechas presas a um pivô, tweens da morte e os passos continuam iguais.

## Além disto (m) da câmera, a pele não é atualizada (a neblina já escondeu o bicho).
const SYNC_RANGE := 110.0

var skeleton: Skeleton3D
var joints: Array[Node3D] = []
var _by_name := {}
var _parents: PackedInt32Array = []
var _skel_from_model := Transform3D.IDENTITY
## Por osso: o inverso do pivô em repouso (no espaço do esqueleto) e a pose global de repouso.
var _rest_joint_inv: Array[Transform3D] = []
var _rest_bone: Array[Transform3D] = []
var _owner: Node3D
var _order: Array = []


## Põe o modelo `scene` em `owner`, vestido com `palette` (AnimalLook), e cria os pivôs.
static func attach(owner: Node3D, scene: PackedScene, palette: Dictionary, look_key: String) -> CreatureModel:
	var model := CreatureModel.new()
	model._owner = owner
	var instance := scene.instantiate() as Node3D
	owner.add_child(instance)
	model.skeleton = instance.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		part.mesh = AnimalLook.dressed(look_key, part.mesh as ArrayMesh, palette)
		part.visibility_range_end = SYNC_RANGE + 20.0
		part.visibility_range_end_margin = 10.0
		part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	model._build_joints(instance)
	return model


func joint(bone_name: String) -> Node3D:
	return _by_name.get(bone_name)


func _build_joints(instance: Node3D) -> void:
	# Do esqueleto até o dono do bicho (transformações paradas: a cena do modelo não mexe).
	var model_from_skel := Transform3D.IDENTITY
	var node: Node = skeleton
	while node != _owner and node != null:
		model_from_skel = (node as Node3D).transform * model_from_skel
		node = node.get_parent()
	_skel_from_model = model_from_skel.affine_inverse()
	var count := skeleton.get_bone_count()
	_parents.resize(count)
	joints.resize(count)
	_rest_joint_inv.resize(count)
	_rest_bone.resize(count)
	# Pais antes dos filhos (o glTF não garante a ordem).
	var depth := {}
	for i in count:
		var d := 0
		var p := skeleton.get_bone_parent(i)
		while p != -1:
			d += 1
			p = skeleton.get_bone_parent(p)
		depth[i] = d
	_order = range(count)
	_order.sort_custom(func(x: int, y: int) -> bool: return depth[x] < depth[y])
	for i: int in _order:
		var parent := skeleton.get_bone_parent(i)
		_parents[i] = parent
		var rest := skeleton.get_bone_global_rest(i)
		var origin_model := model_from_skel * rest.origin
		var pivot := Node3D.new()
		pivot.name = skeleton.get_bone_name(i)
		var parent_node: Node3D = _owner if parent == -1 else joints[parent]
		var parent_origin := Vector3.ZERO if parent == -1 else model_from_skel * skeleton.get_bone_global_rest(parent).origin
		pivot.position = origin_model - parent_origin
		parent_node.add_child(pivot)
		joints[i] = pivot
		_by_name[String(pivot.name)] = pivot
		_rest_joint_inv[i] = (_skel_from_model * Transform3D(Basis.IDENTITY, origin_model)).affine_inverse()
		_rest_bone[i] = rest


## Leva cada osso para onde o pivô dele está agora.
func sync() -> void:
	if skeleton == null:
		return
	var camera := _owner.get_viewport().get_camera_3d() if _owner.is_inside_tree() else null
	if camera != null and camera.global_position.distance_squared_to(_owner.global_position) > SYNC_RANGE * SYNC_RANGE:
		return
	var count := joints.size()
	var model_now: Array[Transform3D] = []
	var bone_now: Array[Transform3D] = []
	model_now.resize(count)
	bone_now.resize(count)
	for i: int in _order:
		var parent := _parents[i]
		model_now[i] = joints[i].transform if parent == -1 else model_now[parent] * joints[i].transform
		var delta := _skel_from_model * model_now[i] * _rest_joint_inv[i]
		bone_now[i] = delta * _rest_bone[i]
		var local := bone_now[i] if parent == -1 else bone_now[parent].affine_inverse() * bone_now[i]
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(i, local.basis.get_scale())
