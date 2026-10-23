class_name BirdLife
extends Node3D
## Os pássaros do vale: Tuning.SONGBIRD_COUNT canoros na copa das árvores vivas,
## WOODPECKER_COUNT pica-paus no tronco das secas e OWL_COUNT corujas na mata fechada. Cada um é
## um Bird pousado num galho de verdade, que canta de lá (o som passa pelo Ambience, que abafa
## atrás de rocha e, depois do R4, às vezes traz a voz do Zelador junto).
## Filho de Animals.

const SEED := 7310

var terrain: Terrain
var vegetation: Vegetation
var ambience: Ambience

var birds: Array[Bird] = []


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for entry: Array in [[Bird.Species.SONGBIRD, Tuning.SONGBIRD_COUNT], [Bird.Species.WOODPECKER, Tuning.WOODPECKER_COUNT],
			[Bird.Species.OWL, Tuning.OWL_COUNT]]:
		var species: Bird.Species = entry[0]
		for i in int(entry[1]):
			# Árvore seca é rara: se não houver galho perto do ponto sorteado, tenta outro ponto.
			var spot := []
			for attempt in 8:
				var angle := rng.randf() * TAU
				var near := Vector3(cos(angle), 0.0, sin(angle)) * sqrt(rng.randf()) * (ForestLayout.VALLEY_RADIUS - 10.0)
				spot = perch_for(species, near, near, 0.0, 30.0 + attempt * 15.0)
				if not spot.is_empty():
					break
			if spot.is_empty():
				continue
			var bird := Bird.new()
			bird.name = "Bird%d" % birds.size()
			bird.life = self
			add_child(bird)
			bird.setup(species, rng)
			bird.perch_at(spot[0], spot[1], spot[2])
			birds.append(bird)
	Events.noise_made.connect(_on_noise)


## Um galho para pousar entre min e max metros de `near`, de preferência longe de `away_from`:
## [ponto, giro, árvore], ou vazio se não achar.
func perch_for(species: Bird.Species, near: Vector3, away_from: Vector3, min_distance: float, max_distance: float) -> Array:
	if vegetation == null or vegetation.trees.is_empty():
		return []
	var best := []
	var best_score := -INF
	for attempt in 40:
		var id := randi() % vegetation.trees.size()
		var info := vegetation.trees[id]
		if info.fallen or info.dead != (species == Bird.Species.WOODPECKER):
			continue
		var flat := Vector2(info.base.x - near.x, info.base.z - near.z).length()
		if flat < min_distance or flat > max_distance:
			continue
		if Story.has_flag(&"climate_cut") and info.base.z < Tuning.VOID_EDGE_Z + 4.0:
			continue
		if species == Bird.Species.OWL and terrain != null and terrain.forest_density(info.base.x, info.base.z) < 0.4:
			continue
		var score := Vector2(info.base.x - away_from.x, info.base.z - away_from.z).length() + randf() * 10.0
		if score > best_score:
			best_score = score
			best = _spot_on(species, id)
		if best_score > max_distance:
			break
	return best


## A árvore caiu (o pássaro em cima dela tem de sair).
func tree_gone(id: int) -> bool:
	return id < 0 or id >= vegetation.trees.size() or vegetation.trees[id].fallen


## Toca um chamado num ponto (os tocadores do Ambience).
func call_at(stream: AudioStream, at: Vector3, unit_size: float, volume_db: float, pitch: float) -> void:
	if ambience != null:
		ambience.call_at(stream, at, unit_size, volume_db, pitch)


## O ponto do galho na árvore `id`: na copa (canoro), perto do tronco no meio da copa (coruja) ou
## agarrado ao tronco olhando para ele (pica-pau).
func _spot_on(species: Bird.Species, id: int) -> Array:
	var info := vegetation.trees[id]
	var height := info.mesh.get_aabb().end.y * info.transform.basis.get_scale().y
	var side := randf() * TAU
	var out := Vector3(sin(side), 0.0, cos(side))
	match species:
		Bird.Species.WOODPECKER:
			var up := randf_range(2.5, minf(6.0, height * 0.6))
			# O tronco seco é torto: o pássaro se agarra no eixo de verdade, onde ele já afinou.
			var axis := info.base + Vector3.UP * up
			var radius := info.radius
			if info.mesh.has_meta("trunk"):
				var trunk: PackedVector3Array = info.mesh.get_meta("trunk")
				var t := clampf(up / (trunk[trunk.size() - 1].y * info.transform.basis.get_scale().y), 0.0, 1.0)
				axis = info.transform * TreeBuilder._point_on_line(Array(trunk), t)
				radius *= 1.0 - t * 0.8 * (trunk.size() - 1) / trunk.size()
			# De frente para o tronco (o +Z do pássaro aponta para dentro), barriga na casca: o
			# tronco é um prisma de 6 lados, a face fica a 0,87 do raio.
			return [axis + out * (radius * 0.9 + 0.03), atan2(-out.x, -out.z), id]
		Bird.Species.OWL:
			return [info.base + Vector3.UP * height * randf_range(0.4, 0.55) + out * randf_range(0.4, 0.8), randf() * TAU, id]
	var frac := randf_range(0.45, 0.82)
	# A copa do pinheiro afina para cima: o galho é mais curto lá no alto.
	var reach := lerpf(2.2, 0.5, (frac - 0.45) / 0.37) * height / 14.0
	return [info.base + Vector3.UP * height * frac + out * reach * randf_range(0.5, 1.0), randf() * TAU, id]


func _on_noise(at: Vector3, radius: float) -> void:
	for bird in birds:
		if bird.global_position.distance_to(at) < radius * 0.8:
			bird.flush(at)
