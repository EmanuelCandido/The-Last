class_name Trophies
extends Node3D
## A caverna vira lar (§8b-F): cada cervo coletado deixa uma galhada pendurada na parede da
## esquerda (de quem entra), até Tuning.TROPHY_MAX; cada javali, um par de presas; o Velho, um
## crânio grande com a galhada enorme, no lugar de honra, no fundo. Montados a partir dos
## contadores do Story ("deer_harvested", "boar_harvested", "old_deer_harvested"), que ficam na
## Reciclagem.
##
## A parede é irregular: cada troféu acha o seu ponto com um raio, depois da primeira volta da
## física (a casca da caverna é montada depois do _ready). Filho da Cave, no espaço dela.

## Onde vão as galhadas (z ao longo da caverna) e as presas, na parede -X.
const ANTLER_Z := [-2.6, -1.8, -1.0, -0.2, 0.6, 1.4, 2.2, 3.0]
const ANTLER_HEIGHT := 1.75
const TUSK_Z := [-2.2, -1.4, -0.6, 0.2]
const TUSK_HEIGHT := 1.2
## O Velho: no fundo da caverna, alto.
const OLD_SPOT := Vector3(0.0, 2.3, 6.0)

var _bone: StandardMaterial3D
var _built := ""


func _ready() -> void:
	_bone = Animal.flat_material(Color(0.78, 0.72, 0.6))
	Story.changed.connect(_refresh)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var deer := mini(Story.count(&"deer_harvested"), Tuning.TROPHY_MAX)
	var boars := mini(Story.count(&"boar_harvested"), TUSK_Z.size())
	var old := Story.count(&"old_deer_harvested") > 0
	var key := "%d/%d/%s" % [deer, boars, old]
	if key == _built:
		return
	_built = key
	for child in get_children():
		child.queue_free()
	var space := get_world_3d().direct_space_state
	for i in deer:
		var spot := _wall(space, Vector3(0.0, ANTLER_HEIGHT + (0.12 if i % 2 else 0.0), ANTLER_Z[i]), Vector3.LEFT)
		if not spot.is_empty():
			_antlers(spot[0], spot[1], 1.0, i)
	for i in boars:
		var spot := _wall(space, Vector3(0.0, TUSK_HEIGHT, TUSK_Z[i]), Vector3.LEFT)
		if not spot.is_empty():
			_tusks(spot[0], spot[1])
	if old:
		var spot := _wall(space, Vector3(0.0, OLD_SPOT.y, 2.0), Vector3.BACK)
		if not spot.is_empty():
			_antlers(spot[0], spot[1], 1.8, 99)


## Ponto da parede a partir de `from` (no espaço da caverna) indo para `direction`: [ponto, normal].
func _wall(space: PhysicsDirectSpaceState3D, from: Vector3, direction: Vector3) -> Array:
	var start := to_global(from)
	var query := PhysicsRayQueryParameters3D.create(start, start + global_basis * direction * 8.0, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return []
	return [to_local(hit.position), (global_basis.inverse() * (hit.normal as Vector3)).normalized()]


## Um crânio de cervo e a galhada, preso na parede com a cara para fora.
func _antlers(at: Vector3, normal: Vector3, size: float, variant: int) -> void:
	var mount := _mount(at, normal)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 31 + 7
	_box(mount, Vector3(0.11, 0.1, 0.2) * size, Vector3(0.0, 0.0, 0.08 * size), Vector3.ZERO)
	_box(mount, Vector3(0.06, 0.05, 0.08) * size, Vector3(0.0, -0.04 * size, 0.2 * size), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var beam_tilt := Vector3(0.0, 0.0, -0.55 * side)
		var beam := Vector3(0.09 * side, 0.15, 0.02) * size
		_box(mount, Vector3(0.025, 0.3, 0.025) * size, beam, beam_tilt + Vector3(rng.randf_range(-0.1, 0.1), 0.0, 0.0))
		var tines := 3 if size < 1.5 else 5
		for t in tines:
			var along := (0.06 + t * 0.07) * size
			var at_tine := Vector3((0.05 + along * 0.5) * side, 0.06 * size + along, 0.03 * size)
			_box(mount, Vector3(0.018, 0.12, 0.018) * size, at_tine + Vector3(0.0, 0.05, 0.03) * size, Vector3(0.6, 0.0, -0.2 * side))


## Um par de presas de javali cruzadas sobre uma tábua de casca.
func _tusks(at: Vector3, normal: Vector3) -> void:
	var mount := _mount(at, normal)
	for side: float in [-1.0, 1.0]:
		_box(mount, Vector3(0.025, 0.16, 0.03), Vector3(0.04 * side, 0.0, 0.03), Vector3(0.0, 0.0, 0.5 * side))
		_box(mount, Vector3(0.022, 0.06, 0.025), Vector3(0.09 * side, 0.08, 0.03), Vector3(0.0, 0.0, -0.3 * side))


func _mount(at: Vector3, normal: Vector3) -> Node3D:
	var mount := Node3D.new()
	add_child(mount)
	mount.position = at + normal * 0.03
	# +Z do troféu sai da parede.
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	mount.basis = Basis.looking_at(-normal, up)
	return mount


func _box(parent: Node3D, size: Vector3, center: Vector3, tilt: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _bone
	mesh.position = center
	mesh.rotation = tilt
	parent.add_child(mesh)
