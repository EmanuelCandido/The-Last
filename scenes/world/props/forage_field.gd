class_name ForageField
extends Node3D
## Os lugares de coleta do vale (§8b-D): Tuning.FORAGE_MUSHROOMS tufos de cogumelo ao pé de
## árvores vivas e FORAGE_BERRIES arbustos de frutinhas na borda da mata. Os lugares saem sempre
## iguais (semente fixa); o save guarda só o dia em que cada um foi colhido (grupo "persist").
## Filho de Props.

const SEED := 4417

var _spots: Array[ForageSpot] = []


func build(terrain: Terrain, vegetation: Vegetation) -> void:
	add_to_group(SaveSystem.PERSIST_GROUP)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Cogumelos: ao pé de árvores vivas do vale.
	var tries := 0
	var placed := 0
	while placed < Tuning.FORAGE_MUSHROOMS and tries < 2000 and not vegetation.trees.is_empty():
		tries += 1
		var tree: Vegetation.TreeInfo = vegetation.trees[rng.randi() % vegetation.trees.size()]
		if tree.dead:
			continue
		var angle := rng.randf() * TAU
		var p := Vector2(tree.base.x, tree.base.z) + Vector2(cos(angle), sin(angle)) * (tree.radius + 0.5)
		if not _usable(terrain, p):
			continue
		_add(&"mushroom", terrain, p, rng)
		placed += 1
	# Frutinhas: onde a mata começa (nem campo aberto, nem mata fechada).
	tries = 0
	placed = 0
	while placed < Tuning.FORAGE_BERRIES and tries < 4000:
		tries += 1
		var angle := rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * (ForestLayout.VALLEY_RADIUS - 15.0)
		var density := terrain.forest_density(p.x, p.y)
		if density < 0.2 or density > 0.55 or not _usable(terrain, p):
			continue
		if vegetation.tree_near(Vector3(p.x, 0.0, p.y), 1.2) != -1:
			continue
		_add(&"berries", terrain, p, rng)
		placed += 1
	Clock.day_started.connect(func(_day: int) -> void: _refresh())


func spots() -> Array[ForageSpot]:
	return _spots


func _usable(terrain: Terrain, p: Vector2) -> bool:
	return p.length() < ForestLayout.VALLEY_RADIUS - 8.0 and ForestLayout.cave_ellipse(p) > 1.6 \
		and ForestLayout.distance_to_trail(p) > 2.0 and terrain.get_normal(p.x, p.y).y > 0.8 \
		and p.y > Tuning.VOID_EDGE_Z + 6.0


func _add(kind: StringName, terrain: Terrain, p: Vector2, rng: RandomNumberGenerator) -> void:
	var spot := ForageSpot.new()
	spot.name = "Spot%d" % _spots.size()
	add_child(spot)
	spot.position = Vector3(p.x, terrain.get_height(p.x, p.y), p.y)
	spot.rotation.y = rng.randf() * TAU
	spot.build(kind, rng)
	_spots.append(spot)


func _refresh() -> void:
	for spot in _spots:
		spot.refresh()


func save_data() -> Dictionary:
	var picked := []
	for spot in _spots:
		picked.append(spot.picked_day)
	return {"picked": picked}


func load_data(data: Dictionary) -> void:
	var picked: Array = data.get("picked", [])
	for i in _spots.size():
		_spots[i].picked_day = int(picked[i]) if i < picked.size() else -1
	_refresh()
