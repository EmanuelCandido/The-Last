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
@onready var _outdoor_fog_density := _environment.fog_density


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_terrain.generate()
	_terrain.publish_height_texture()
	_cave.build(_terrain.cave_floor_height)
	_vegetation.populate(_terrain)
	var half := ForestLayout.TERRAIN_SIZE * 0.5
	Wind.set_exposure(_terrain.build_wind_exposure(), Rect2(-half, -half, half * 2.0, half * 2.0))
	_ambience.vegetation = _vegetation
	_spawn_animals()
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
	# Dentro da caverna a neblina cinza lavaria as paredes escuras: afina e escurece.
	_environment.fog_density = lerpf(_outdoor_fog_density, _outdoor_fog_density * 0.35, _ambience.indoor)
	_environment.fog_light_energy = lerpf(1.0, 0.55, _ambience.indoor)


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


## Árvore em pé perto de `world_position` (índice) ou -1. Usado pelo soco do goblin.
func tree_near(world_position: Vector3, max_distance: float) -> int:
	return _vegetation.tree_near(world_position, max_distance)


func is_tree_dead(id: int) -> bool:
	return _vegetation.trees[id].dead


func hit_tree(id: int, from: Vector3) -> bool:
	return _vegetation.hit_tree(id, from)


func _on_level_loaded(level: Node3D) -> void:
	if level != self or Game.player == null or DevTools.skip_intro:
		return
	Events.screen_fade_requested.emit(1.0, 0.0)
	Events.screen_fade_requested.emit(0.0, 5.0)
	# Dormindo, quase não se ouve nada; o som abre enquanto ele senta e levanta.
	Game.open_ears(7.5, -42.0, 160.0)
	Game.player.wake_up()


func _spawn_animals() -> void:
	# Duas manadas de cervos e coelhos espalhados pelo vale.
	for herd_home: Vector2 in [ForestLayout.MEADOW, Vector2(-40.0, -22.0)]:
		for i in 3:
			_spawn_animal(Deer.new(), herd_home)
	for home: Vector2 in [Vector2(4.0, 54.0), Vector2(-8.0, 30.0), Vector2(6.0, 18.0), Vector2(12.0, 40.0), Vector2(-6.0, -8.0), Vector2(30.0, -30.0)]:
		_spawn_animal(Rabbit.new(), home)
	var crows := CrowFlock.new()
	crows.terrain = _terrain
	_animals.add_child(crows)
	var wolves := WolfPack.new()
	wolves.name = "WolfPack"
	wolves.terrain = _terrain
	wolves.ambience = _ambience
	_animals.add_child(wolves)


func _spawn_animal(animal: Animal, home: Vector2) -> void:
	_animals.add_child(animal)
	animal.setup(_terrain, home, randi())
	# Caçado (coletado), outro bicho da mesma espécie aparece depois, longe do goblin.
	animal.tree_exited.connect(_respawn_later.bind(animal is Deer, home))


func _respawn_later(is_deer: bool, home: Vector2) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	# Conexão com um método desta fase: se a fase sair antes, o timer não chama nada.
	get_tree().create_timer(120.0).timeout.connect(_respawn.bind(is_deer, home))


func _respawn(is_deer: bool, home: Vector2) -> void:
	var player := Game.player
	if player != null and Vector2(player.global_position.x, player.global_position.z).distance_to(home) < 60.0:
		home = -home
	_spawn_animal(Deer.new() if is_deer else Rabbit.new(), home)
