class_name HeldBow
extends Node3D
## Arco na mão do goblin: dois braços que dobram, a corda que vai até a mão que puxa e a
## flecha encaixada nela. Mesmas coordenadas do BowMesh: empunhadura na origem, Y para
## cima, barriga para +Z (para o alvo) e corda atrás (-Z).

## Quanto as pontas dobram para trás com a corda toda puxada (rad).
const MAX_BEND := 0.2
## Até onde a corda vai atrás da posição solta (m).
const MAX_DRAW := 0.42
## A flecha passa pelo lado da empunhadura, não por dentro dela.
const ARROW_REST := Vector3(0.014, 0.01, 0.0)

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
	string_mesh.top_radius = 0.003
	string_mesh.bottom_radius = 0.003
	string_mesh.height = 1.0
	string_mesh.radial_segments = 4
	string_mesh.rings = 1
	string_mesh.material = BowMesh.string_material()
	_string_top = _part(string_mesh)
	_string_bottom = _part(string_mesh)
	_arrow = _part(BowMesh.arrow())
	pose_string(Vector3.INF, 0.0, false)


## Monta a corda. `hand` é a mão que puxa (global; INF = corda solta); `draw` (0..1) é
## quanto ela está puxada: os braços dobram com ele e a corda só acompanha a mão até
## essa distância, então ela volta reta na hora em que a flecha sai.
func pose_string(hand: Vector3, draw: float, arrow_on: bool) -> void:
	var bend := MAX_BEND * clampf(draw, 0.0, 1.0)
	_upper.basis = Basis(Vector3.RIGHT, -bend)
	_lower.basis = Basis(Vector3.RIGHT, bend)
	var top := _upper.basis * BowMesh.tip(1.0)
	var bottom := _lower.basis * BowMesh.tip(-1.0)
	var nock := (top + bottom) * 0.5
	if hand != Vector3.INF:
		# A corda fica no plano do arco; da mão só vale a profundidade.
		var local := to_local(hand)
		var pull := clampf(nock.z - local.z, 0.0, MAX_DRAW * draw + 0.02)
		nock += Vector3(clampf(local.x, -0.03, 0.03), clampf(local.y - nock.y, -0.05, 0.05), -pull)
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
