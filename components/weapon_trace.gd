class_name WeaponTrace
extends RefCounted
## O caminho da arma num golpe (F11, plano_combate §3.3). Nos quadros ativos, testa por onde a
## lâmina passou entre o quadro de física anterior e este (esferas ao longo do caminho, em vários
## pontos da lâmina) contra as áreas de acerto, e entrega cada alvo uma vez por golpe. Bate onde a
## lâmina passou: um golpe rápido não atravessa nada, e quem está fora do arco não leva.
## Serve para o goblin agora e, na F12, para os orcs.

## Pontos da lâmina testados (fração da base até a ponta) e subpassos entre dois quadros.
const SAMPLES := [0.3, 0.65, 1.0]
const STEPS := 3

## Camadas: bichos (4) e corpos de luta (5).
var mask := 8 | 16
var radius := 0.07
var exclude: Array[RID] = []

var _prev: Array[Vector3] = []
var _hit := {}
var _shape := SphereShape3D.new()


## Começa um golpe novo: esquece quem já levou e de onde a lâmina vinha.
func begin() -> void:
	_prev.clear()
	_hit.clear()


## A lâmina agora vai de `base` a `tip`. Devolve os alvos novos: [{target, point, direction}].
## Alvo é o dono de uma área de acerto que sabe levar golpe (`take_hit`).
func sweep(world: World3D, base: Vector3, tip: Vector3) -> Array[Dictionary]:
	var now: Array[Vector3] = []
	for s: float in SAMPLES:
		now.append(base.lerp(tip, s))
	var found: Array[Dictionary] = []
	_shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.collision_mask = mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = exclude
	var space := world.direct_space_state
	for i in now.size():
		var from: Vector3 = _prev[i] if _prev.size() == now.size() else now[i]
		var motion := now[i] - from
		var direction := motion.normalized() if motion.length_squared() > 0.000001 else (tip - base).normalized()
		for k in STEPS:
			var point := from.lerp(now[i], float(k + 1) / STEPS)
			query.transform = Transform3D(Basis.IDENTITY, point)
			for result: Dictionary in space.intersect_shape(query, 8):
				var area := result.collider as Area3D
				if area == null:
					continue
				var target := area.get_parent()
				if target == null or not target.has_method("take_hit"):
					continue
				var id := target.get_instance_id()
				if _hit.has(id):
					continue
				_hit[id] = true
				found.append({"target": target, "point": point, "direction": direction})
	_prev = now
	return found


## Alguém levou neste golpe.
func hit_anything() -> bool:
	return not _hit.is_empty()
