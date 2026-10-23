class_name Senses
extends RefCounted
## Os sentidos de quem vigia (§6.3), como contas soltas: visão em cone com linha de visada,
## audição pelo raio do barulho e o térmico (só a distância: atravessa paredes). Os bichos
## usam a linha de visada; o Zelador usa tudo.


## Nada da camada `mask` entre `from` e `to`.
static func line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(query).is_empty()


## `target` está dentro do cone de `fov_deg` graus (no plano do chão) e a menos de `reach` m.
static func in_cone(eye: Vector3, forward: Vector3, target: Vector3, fov_deg: float, reach: float) -> bool:
	var to_target := target - eye
	if to_target.length() > reach:
		return false
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var ahead := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0001 or ahead.length_squared() < 0.0001:
		return true
	return rad_to_deg(ahead.angle_to(flat)) < fov_deg * 0.5


## Vê `target`: no cone e sem nada no caminho.
static func sees(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3, target: Vector3, fov_deg: float, reach: float, mask: int, exclude: Array[RID] = []) -> bool:
	return in_cone(eye, forward, target, fov_deg, reach) and line_of_sight(space, eye, target, mask, exclude)


## Ouve um barulho que alcança `noise_radius` m a partir de `source`.
static func hears(listener: Vector3, source: Vector3, noise_radius: float) -> bool:
	return noise_radius > 0.0 and listener.distance_to(source) < noise_radius


## Sente o calor de `source` a menos de `reach` m, com parede ou sem.
static func feels_heat(listener: Vector3, source: Vector3, reach: float) -> bool:
	return listener.distance_to(source) < reach
