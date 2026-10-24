class_name EdgeBalance
extends RefCounted
## Equilíbrio na borda (tirado do Player na F10). Com o centro do corpo além da borda (sem chão
## logo embaixo), o goblin se desequilibra: o equilíbrio cai mais rápido se ele anda para o vazio
## ou está com um pé solto, e volta se ele andar para dentro ou se agachar. Se acabar, ele tomba
## para o lado do vazio (`tipping` > 0: o Player empurra o corpo para `edge_dir`, sem floor_snap).

## Raio em volta do corpo onde se procura o vazio na borda (m).
const PROBE := 0.32

## Equilíbrio (1 firme .. 0 cai), quanto tempo ainda tomba para fora e para onde fica o vazio.
var balance := 1.0
var tipping := 0.0
var edge_dir := Vector3.ZERO

var _body: CharacterBody3D
var _visual: Node3D
var _floor_snap := 0.0


func _init(body: CharacterBody3D, visual: Node3D) -> void:
	_body = body
	_visual = visual
	_floor_snap = body.floor_snap_length


func update(delta: float, direction: Vector3, crouching: bool, animator: GoblinAnimator) -> void:
	var space := _body.get_world_3d().direct_space_state
	var over_edge := false
	if _body.is_on_floor() and tipping <= 0.0:
		over_edge = _ground_below(space, _body.global_position, 0.25) == false
	if not over_edge:
		balance = move_toward(balance, 1.0, delta * 0.8)
		if _body.is_on_floor():
			tipping = 0.0
			_body.floor_snap_length = _floor_snap
		_set_teeter(animator, move_toward(animator.teeter if animator != null else 0.0, 0.0, delta * (1.0 if not _body.is_on_floor() else 3.0)))
		return
	# Para onde fica o vazio: soma das direções em volta sem chão.
	var void_dir := Vector3.ZERO
	for i in 8:
		var offset := Vector3(cos(TAU * i / 8.0), 0.0, sin(TAU * i / 8.0)) * PROBE
		if not _ground_below(space, _body.global_position + offset, 0.35):
			void_dir += offset
	if void_dir.length_squared() < 0.0001:
		void_dir = Vector3(_body.get_floor_normal().x, 0.0, _body.get_floor_normal().z)
	edge_dir = void_dir.normalized() if void_dir.length_squared() > 0.0001 else -_visual.global_basis.z
	var instability := 0.55
	if animator != null:
		var loose := int(not animator.foot_supported[0]) + int(not animator.foot_supported[1])
		# Os dois pés no vazio: não há em que se segurar.
		instability += 2.5 if loose == 2 else 0.2 * loose
	var velocity := _body.velocity
	if Vector2(velocity.x, velocity.z).dot(Vector2(edge_dir.x, edge_dir.z)) > 0.2:
		instability += 0.5
	if direction.dot(-edge_dir) > 0.3:
		instability -= 0.9
	if crouching:
		instability -= 0.35
	balance = clampf(balance - instability * delta * 0.6, 0.0, 1.0)
	_set_teeter(animator, 0.55 + 0.45 * (1.0 - balance))
	if balance <= 0.0:
		tipping = 0.6
		_body.floor_snap_length = 0.0
		_body.velocity += edge_dir * 1.2 + Vector3.UP * 0.8


func _ground_below(space: PhysicsDirectSpaceState3D, at: Vector3, depth: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * depth, 1, [_body.get_rid()])
	return not space.intersect_ray(query).is_empty()


func _set_teeter(animator: GoblinAnimator, amount: float) -> void:
	if animator == null:
		return
	animator.teeter = amount
	var local := _visual.global_basis.inverse() * edge_dir
	animator.teeter_dir = Vector2(local.x, local.z).normalized() if amount > 0.0 else Vector2.ZERO
