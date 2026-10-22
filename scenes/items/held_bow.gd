class_name HeldBow
extends Node3D
## Arco na mão do goblin: dois braços que dobram, a corda puxada até onde está a mão e a
## flecha encaixada nela. Mesmas coordenadas do BowMesh: empunhadura na origem, Y para
## cima, barriga para +Z (para o alvo) e corda atrás (-Z).
##
## Quem segura posiciona o arco e leva a mão da corda até `nock_depth(draw)` atrás da
## empunhadura (o GoblinAnimator faz isso com IK); aqui a corda só vai até lá.

## Quanto as pontas dobram para trás com a corda toda puxada (rad).
const MAX_BEND := 0.15
## Até onde a corda vai atrás da posição solta (m). Com a dobra dos braços, a corda toda
## puxada fica a ~27 cm da empunhadura: o que o braço de 32 cm do goblin alcança.
const MAX_DRAW := 0.15
## A flecha passa pelo lado da empunhadura, não por dentro dela.
const ARROW_REST := Vector3(0.012, 0.008, 0.0)

var _upper: MeshInstance3D
var _lower: MeshInstance3D
var _string_top: MeshInstance3D
var _string_bottom: MeshInstance3D
var _arrow: MeshInstance3D


func _init() -> void:
	_upper = _part(BowMesh.build_limb(1.0))
	_lower = _part(BowMesh.build_limb(-1.0))
	_part(BowMesh.build_grip())
	var string_mesh := CylinderMesh.new()
	string_mesh.top_radius = 0.0025
	string_mesh.bottom_radius = 0.0025
	string_mesh.height = 1.0
	string_mesh.radial_segments = 4
	string_mesh.rings = 1
	string_mesh.material = BowMesh.string_material()
	_string_top = _part(string_mesh)
	_string_bottom = _part(string_mesh)
	_arrow = _part(BowMesh.arrow())
	pose_string(0.0, false)


## Distância da empunhadura até o ponto de encaixe da corda, com a corda `draw` (0..1) puxada.
static func nock_depth(draw: float) -> float:
	var amount := clampf(draw, 0.0, 1.0)
	return -(Basis(Vector3.RIGHT, -MAX_BEND * amount) * BowMesh.tip(1.0)).z + MAX_DRAW * amount


## Monta a corda puxada `draw` (0..1): os braços dobram e o meio da corda vai para trás.
## Ao soltar (draw volta a 0), a corda fica reta na hora.
func pose_string(draw: float, arrow_on: bool) -> void:
	var bend := MAX_BEND * clampf(draw, 0.0, 1.0)
	_upper.basis = Basis(Vector3.RIGHT, -bend)
	_lower.basis = Basis(Vector3.RIGHT, bend)
	var top := _upper.basis * BowMesh.tip(1.0)
	var bottom := _lower.basis * BowMesh.tip(-1.0)
	var nock := Vector3(0.0, 0.0, -nock_depth(draw))
	_segment(_string_top, top, nock)
	_segment(_string_bottom, nock, bottom)
	_arrow.visible = arrow_on
	if arrow_on:
		var direction := (ARROW_REST - nock).normalized()
		_arrow.transform = Transform3D(Basis.looking_at(direction), nock + direction * BowMesh.ARROW_LENGTH * 0.5)


func _part(mesh: Mesh) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	return instance


## Estica o cilindro unitário de `a` até `b`.
func _segment(instance: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var axis := b - a
	var length := maxf(axis.length(), 0.001)
	var y := axis / length
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	instance.transform = Transform3D(Basis(x, y * length, x.cross(y)), (a + b) * 0.5)
