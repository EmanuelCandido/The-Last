class_name ForageField
extends Node3D
## Os lugares de coleta do vale (§8b-D): Tuning.FORAGE_MUSHROOMS tufos de cogumelo ao pé de
## árvores vivas e FORAGE_BERRIES arbustos de frutinhas na borda da mata; F11: FORAGE_MOSS tufos de
## musgo ao pé das secas e nos montes de pedra e FORAGE_HERBS de erva-de-sangue na mata fechada (no
## fim da lista, para os saves de antes continuarem casando pelo índice). Os lugares saem sempre
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
	# Musgo: no tronco das árvores secas, do lado da sombra (o norte, -Z), acima do capim.
	tries = 0
	placed = 0
	var mossy := {}
	while placed < Tuning.FORAGE_MOSS and tries < 3000 and not vegetation.trees.is_empty():
		tries += 1
		var id := rng.randi() % vegetation.trees.size()
		var tree: Vegetation.TreeInfo = vegetation.trees[id]
		if not tree.dead or mossy.has(id):
			continue
		var angle := -PI * 0.5 + rng.randf_range(-0.8, 0.8)
		var out := Vector2(cos(angle), sin(angle))
		var p := Vector2(tree.base.x, tree.base.z) + out * (tree.radius + 0.01)
		if not _usable(terrain, p):
			continue
		var spot := _add(&"moss", terrain, p, rng)
		# A frente do tufo (+Z da malha) fica para fora do tronco; cai junto com a árvore.
		spot.rotation.y = atan2(out.x, out.y)
		spot.tree_id = id
		mossy[id] = true
		placed += 1
	# Erva-de-sangue: rara, onde a mata é mais fechada.
	tries = 0
	placed = 0
	while placed < Tuning.FORAGE_HERBS and tries < 4000:
		tries += 1
		var angle := rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * (ForestLayout.VALLEY_RADIUS - 15.0)
		if terrain.forest_density(p.x, p.y) < 0.6 or not _usable(terrain, p):
			continue
		if vegetation.tree_near(Vector3(p.x, 0.0, p.y), 1.0) != -1:
			continue
		_add(&"herb", terrain, p, rng)
		placed += 1
	Clock.day_started.connect(func(_day: int) -> void: _refresh())


func spots() -> Array[ForageSpot]:
	return _spots


func _usable(terrain: Terrain, p: Vector2) -> bool:
	return p.length() < ForestLayout.VALLEY_RADIUS - 8.0 and ForestLayout.cave_ellipse(p) > 1.6 \
		and ForestLayout.distance_to_trail(p) > 2.0 and terrain.get_normal(p.x, p.y).y > 0.8 \
		and p.y > Tuning.VOID_EDGE_Z + 6.0


func _add(kind: StringName, terrain: Terrain, p: Vector2, rng: RandomNumberGenerator) -> ForageSpot:
	var spot := ForageSpot.new()
	spot.name = "Spot%d" % _spots.size()
	add_child(spot)
	spot.position = Vector3(p.x, terrain.get_height(p.x, p.y), p.y)
	spot.rotation.y = rng.randf() * TAU
	spot.build(kind, rng)
	_spots.append(spot)
	return spot


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
