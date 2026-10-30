extends Node3D
## Floresta medieval: monta o mundo (terreno, caverna, vegetação, bichos) ao carregar
## e roda a cena do goblin acordando dentro da caverna.

@onready var _terrain: Terrain = $Terrain
@onready var _cave: Cave = $Cave
@onready var _vegetation: Vegetation = $Vegetation
@onready var _animals: Node3D = $Animals
@onready var _ambience: Ambience = $Ambience
@onready var _spawn: Marker3D = $PlayerSpawn
@onready var _debris: GPUParticles3D = $WindDebris
@onready var _environment: Environment = $WorldEnvironment.environment
@onready var _day_night: DayNight = $DayNight
@onready var _outdoor_fog_density := _environment.fog_density
@onready var _fog_sky_affect := _environment.fog_sky_affect

var _void: NorthVoid
## Os riscos da chuva, em volta da câmera (Weather.rain).
var _rain: GPUParticles3D


func _ready() -> void:
	var started := Time.get_ticks_msec()
	# O sol da floresta não ilumina o Abrigo (que fica no mesmo mundo, 2 km abaixo).
	($Sun as DirectionalLight3D).light_cull_mask &= ~Shelter.LAYER
	_terrain.generate()
	_terrain.publish_height_texture()
	_cave.build(_terrain.cave_floor_height)
	var painting := CavePainting.new()
	painting.name = "Painting"
	_cave.add_child(painting)
	# A toca (§8b): o defumador ao lado da fogueira e os troféus na parede.
	var rack := SmokingRack.new()
	rack.name = "SmokingRack"
	rack.campfire = _cave.get_node(^"Campfire") as Campfire
	_cave.add_child(rack)
	rack.position = Vector3(-2.35, 0.0, -1.0)
	rack.rotation.y = PI * 0.5
	var trophies := Trophies.new()
	trophies.name = "Trophies"
	_cave.add_child(trophies)
	# F12: os orcs (chegam pelo dia do ciclo).
	var band := OrcBand.new()
	band.name = "Orcs"
	add_child(band)
	# F13: a bolsa da morte e o esconderijo da toca (desmontado até o goblin fabricá-lo).
	var bags := BagField.new()
	bags.name = "Bags"
	add_child(bags)
	var traps := TrapField.new()
	traps.name = "Traps"
	add_child(traps)
	var stash := CaveStash.new()
	stash.name = "Stash"
	_cave.add_child(stash)
	stash.position = Vector3(2.5, 0.0, 1.7)
	stash.rotation.y = -PI * 0.5
	# F11: a bancada, desmontada até o goblin fabricá-la.
	var bench := Workbench.new()
	bench.name = "Workbench"
	_cave.add_child(bench)
	bench.position = Vector3(-2.3, 0.0, 1.5)
	bench.rotation.y = PI * 0.5 + 0.15
	var ruin := Ruin.new()
	ruin.name = "Ruin"
	add_child(ruin)
	ruin.build(_terrain)
	_vegetation.populate(_terrain)
	# F13: o acampamento dos orcs, no chão livre mais perto de ForestLayout.ORC_CAMP.
	var camp := OrcCamp.new()
	camp.name = "OrcCamp"
	add_child(camp)
	camp.build(_terrain, OrcCamp.pick_center(_terrain, _vegetation))
	_void = NorthVoid.new()
	_void.name = "NorthVoid"
	add_child(_void)
	_void.build(_terrain, _vegetation)
	var half := ForestLayout.TERRAIN_SIZE * 0.5
	Wind.set_exposure(_terrain.build_wind_exposure(), Rect2(-half, -half, half * 2.0, half * 2.0))
	_ambience.vegetation = _vegetation
	_ambience.build_life(_terrain)
	_spawn_animals()
	_place_props()
	_build_rain()
	var spawn := ForestLayout.SPAWN
	_spawn.position = Vector3(spawn.x, _terrain.get_height(spawn.x, spawn.y) + 0.1, spawn.y)
	print("[Floresta] Mundo gerado em %d ms." % (Time.get_ticks_msec() - started))
	Events.level_loaded.connect(_on_level_loaded, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	if Game.player == null:
		return
	# Folhas e poeira soltas no ar acompanham o goblin; somem dentro da caverna.
	var at := Game.player.global_position
	var strength := Wind.strength_at(at)
	_debris.global_position = at + Vector3(0.0, 3.0, 0.0)
	_debris.amount_ratio = (1.0 - ForestLayout.cave_interior(Vector2(at.x, at.z))) * clampf(strength * 1.3, 0.1, 1.0)
	var push := Wind.direction * (0.6 + strength * 2.4)
	(_debris.process_material as ParticleProcessMaterial).gravity = Vector3(push.x, -0.35, push.y)
	# A neblina é a mesma dentro e fora da caverna (de dentro, o vale lá fora tem de parecer o
	# mesmo). Com o clima cortado (R3), no setor norte ela quase some e o vazio aparece; vale
	# onde está a câmera, não o goblin.
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else at
	var north := _void.openness(eye)
	# Na chuva a neblina adensa.
	var fog := _outdoor_fog_density * (1.0 + Tuning.RAIN_FOG * Weather.rain)
	_environment.fog_density = lerpf(fog, Tuning.NORTH_FOG_DENSITY, north)
	# O console do Zelador (§7): "neblina off" mostra o mundo como ele é, cortado na distância.
	if Story.has_flag(&"fog_off"):
		_environment.fog_density = 0.0
	_environment.fog_sky_affect = lerpf(_fog_sky_affect, 0.1, north)
	_day_night.void_amount = north * Tuning.VOID_SKY_DARKNESS
	_update_rain(eye, push)


## A chuva cai num bloco em volta da câmera (as gotas ficam no mundo, não andam com ela) e some
## dentro da caverna.
func _update_rain(eye: Vector3, push: Vector2) -> void:
	_rain.global_position = eye + Vector3(0.0, 7.0, 0.0)
	var inside := ForestLayout.cave_interior(Vector2(eye.x, eye.z))
	_rain.amount_ratio = Weather.rain * (1.0 - inside)
	_rain.emitting = _rain.amount_ratio > 0.01
	(_rain.process_material as ParticleProcessMaterial).gravity = Vector3(push.x * 2.0, -30.0, push.y * 2.0)


func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 6000
	_rain.lifetime = 0.75
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-20.0, -16.0, -20.0), Vector3(40.0, 24.0, 40.0))
	_rain.emitting = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12.0, 2.0, 12.0)
	process.direction = Vector3.DOWN
	process.spread = 3.0
	process.initial_velocity_min = 10.0
	process.initial_velocity_max = 13.0
	process.gravity = Vector3(0.0, -30.0, 0.0)
	_rain.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.008, 0.55)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.68, 0.72, 0.76, 0.16)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = material
	_rain.draw_pass_1 = streak
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


## Tipo de chão para os passos (usado pelo componente Footsteps).
func surface_at(world_position: Vector3) -> StringName:
	return _terrain.surface_at(world_position)


func ground_height(x: float, z: float) -> float:
	return _terrain.get_height(x, z)


## Quanto `world_position` está abrigado dentro da caverna (0 fora .. 1 no salão).
func indoor_at(world_position: Vector3) -> float:
	return ForestLayout.cave_interior(Vector2(world_position.x, world_position.z))


## Quanto o capim e a mata escondem quem está em `world_position` (0..0.7).
func cover_at(world_position: Vector3) -> float:
	var splat := _terrain.get_splat(world_position.x, world_position.z)
	var grass := (1.0 - splat.r) * (1.0 - splat.g) * (1.0 - 0.65 * splat.b)
	return clampf(grass * 0.5 + _terrain.forest_density(world_position.x, world_position.z) * 0.35, 0.0, 0.7)


## Quanto a copa das árvores cobre `world_position` (0..1): abriga da chuva.
func canopy_at(world_position: Vector3) -> float:
	return _vegetation.canopy_at(world_position)


## O lugar mais coberto pelas copas a até `radius` m (a manada se abriga ali na chuva).
func shelter_near(world_position: Vector3, radius: float) -> Vector3:
	var spot := _vegetation.shelter_near(world_position, radius)
	spot.y = _terrain.get_height(spot.x, spot.z)
	return spot


## Árvore em pé perto de `world_position` (índice) ou -1. Usado pelo soco do goblin.
func tree_near(world_position: Vector3, max_distance: float) -> int:
	return _vegetation.tree_near(world_position, max_distance)


func is_tree_dead(id: int) -> bool:
	return _vegetation.trees[id].dead


## Base (no chão) e raio do tronco da árvore `id`; `tree_standing` = ainda não caiu.
func tree_base(id: int) -> Vector3:
	return _vegetation.trees[id].base


func tree_radius(id: int) -> float:
	return _vegetation.trees[id].radius


func tree_standing(id: int) -> bool:
	return id >= 0 and id < _vegetation.trees.size() and not _vegetation.trees[id].fallen


func hit_tree(id: int, from: Vector3, chop := false) -> bool:
	return _vegetation.hit_tree(id, from, chop)


func _on_level_loaded(level: Node3D) -> void:
	if level != self or Game.player == null or DevTools.skip_intro or not Game.play_intro:
		return
	Events.screen_fade_requested.emit(1.0, 0.0)
	Events.screen_fade_requested.emit(0.0, 5.0)
	# Dormindo, quase não se ouve nada; o som abre enquanto ele senta e levanta.
	Game.open_ears(7.5, -42.0, 160.0)
	Game.player.wake_up()


func _spawn_animals() -> void:
	# As manadas de cervos, cada uma com a sua casa (§8b-B), e os coelhos espalhados pelo vale.
	for i in ForestLayout.DEER_HOMES.size():
		var herd := Herd.new()
		herd.name = "Herd%d" % i
		_animals.add_child(herd)
		herd.setup(_terrain, self, ForestLayout.DEER_HOMES[i], randi_range(Tuning.HERD_SIZE_MIN, Tuning.HERD_SIZE_MAX), randi())
	for i in Tuning.RABBIT_COUNT:
		_spawn_animal(Rabbit.new(), ForestLayout.RABBIT_HOMES[i % ForestLayout.RABBIT_HOMES.size()])
	for i in Tuning.BOAR_COUNT:
		_spawn_animal(Boar.new(), ForestLayout.BOAR_HOMES[i % ForestLayout.BOAR_HOMES.size()])
	Clock.day_started.connect(_on_day_started)
	var crows := CrowFlock.new()
	crows.name = "Crows"
	crows.terrain = _terrain
	_animals.add_child(crows)
	var tracks := Tracks.new()
	tracks.name = "Tracks"
	_animals.add_child(tracks)
	var snares := SnareField.new()
	snares.name = "Snares"
	snares.terrain = _terrain
	_animals.add_child(snares)
	var watchers := Watchers.new()
	watchers.name = "Watchers"
	watchers.terrain = _terrain
	_animals.add_child(watchers)
	var clues := Clues.new()
	clues.name = "Clues"
	clues.watchers = watchers
	add_child(clues)
	var birds := BirdLife.new()
	birds.name = "Birds"
	birds.terrain = _terrain
	birds.vegetation = _vegetation
	birds.ambience = _ambience
	_animals.add_child(birds)
	birds.build()
	var wolves := WolfPack.new()
	wolves.name = "WolfPack"
	wolves.terrain = _terrain
	wolves.ambience = _ambience
	_animals.add_child(wolves)


## Poças de lama e montes de pedra soltas pelo vale (ForestLayout).
func _place_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	var height_at := _terrain.get_height
	for spot: Vector2 in ForestLayout.MUD_SPOTS:
		var puddle := MudPuddle.new()
		props.add_child(puddle)
		puddle.position = Vector3(spot.x, _terrain.get_height(spot.x, spot.y), spot.y)
		puddle.build(height_at)
	for spot: Vector2 in ForestLayout.STONE_PILES:
		var pile := StonePile.new()
		props.add_child(pile)
		pile.position = Vector3(spot.x, _terrain.get_height(spot.x, spot.y), spot.y)
		pile.build(height_at)
	# A coleta e as tocaias (§8b).
	var forage := ForageField.new()
	forage.name = "Forage"
	props.add_child(forage)
	forage.build(_terrain, _vegetation)
	var blinds := BlindField.new()
	blinds.name = "Blinds"
	blinds.terrain = _terrain
	props.add_child(blinds)
	# Os marcos que o goblin deixa para se achar na neblina (F10).
	var cairns := CairnField.new()
	cairns.name = "Cairns"
	cairns.terrain = _terrain
	props.add_child(cairns)
	var marks := TreeMarks.new()
	marks.name = "TreeMarks"
	props.add_child(marks)


func _spawn_animal(animal: Animal, home: Vector2) -> void:
	_animals.add_child(animal)
	animal.setup(_terrain, home, randi())


## A cada amanhecer os coelhos e os javalis voltam ao número do vale, nascendo longe do goblin
## (as manadas se repõem sozinhas, Herd), e às vezes o Velho aparece.
func _on_day_started(day: int) -> void:
	_restock(Rabbit, Tuning.RABBIT_COUNT, ForestLayout.RABBIT_HOMES)
	_restock(Boar, Tuning.BOAR_COUNT, ForestLayout.BOAR_HOMES)
	_maybe_old_deer(day)


func _restock(species: Script, wanted: int, homes_list: Array) -> void:
	var alive := 0
	for node in get_tree().get_nodes_in_group(&"animals"):
		if node.get_script() == species and (node as Animal).state != Animal.State.DEAD:
			alive += 1
	var homes := homes_list.duplicate()
	homes.shuffle()
	for home: Vector2 in homes:
		if alive >= wanted:
			break
		if _near_player(home, Tuning.RESTOCK_MIN_DISTANCE):
			continue
		_spawn_animal(species.new() as Animal, home)
		alive += 1


## O Velho (§8b-G): do dia OLD_DEER_FROM_DAY em diante, em alguns amanheceres, até ser caçado.
func _maybe_old_deer(day: int) -> void:
	if day < Tuning.OLD_DEER_FROM_DAY or Story.count(&"old_deer_harvested") > 0 or randf() >= Tuning.OLD_DEER_CHANCE:
		return
	if not get_tree().get_nodes_in_group(&"animals").filter(func(node: Node) -> bool: return node is OldDeer).is_empty():
		return
	spawn_old_deer()


## Põe o Velho num canto do vale longe do goblin (o DevTools e os roteiros também chamam).
func spawn_old_deer(at := Vector2.INF) -> OldDeer:
	var home := at
	for attempt in 30:
		if home != Vector2.INF:
			break
		var angle := randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * randf_range(40.0, ForestLayout.VALLEY_RADIUS - 20.0)
		if not _near_player(p, Tuning.RESTOCK_MIN_DISTANCE) and p.y > Tuning.VOID_EDGE_Z + 15.0 and _terrain.get_normal(p.x, p.y).y > 0.85:
			home = p
	if home == Vector2.INF:
		return null
	var old := OldDeer.new()
	_spawn_animal(old, home)
	return old


func _near_player(p: Vector2, distance: float) -> bool:
	var player := Game.player
	return player != null and Vector2(player.global_position.x, player.global_position.z).distance_to(p) < distance
