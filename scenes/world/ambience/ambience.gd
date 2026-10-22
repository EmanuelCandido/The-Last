class_name Ambience
extends Node
## Som ambiente com propagação no espaço:
## - vento: fontes em volta de quem escuta, cada uma no volume da força do vento no
##   seu ponto (a rajada "vem" de um lado e passa), mais uma camada colada no ouvido
##   quando a rajada pega o goblin em cheio;
## - folhas: o farfalhar sai das árvores mais próximas, cada uma com o próprio vento;
## - chamados de bichos saem de árvores reais, ecoam no vale e ficam abafados atrás
##   de terreno ou rocha (OccludedAudio);
## - dentro da caverna o som de fora fica abafado (passa-baixa no bus Ambience) e o
##   fogo, os passos e as gotas ganham eco (reverb no bus World).

const WIND_LOOP := preload("res://assets/audio/ambience/wind_loop.wav")
const LEAVES_LOOP := preload("res://assets/audio/ambience/leaves_loop.wav")
const BIRDS := [
	preload("res://assets/audio/animals/bird_1.wav"),
	preload("res://assets/audio/animals/bird_2.wav"),
	preload("res://assets/audio/animals/bird_3.wav"),
	preload("res://assets/audio/animals/bird_4.wav"),
]
const WOODPECKER := preload("res://assets/audio/animals/woodpecker.wav")
## Uivo sintético: usado só enquanto não houver gravações reais (wolf_howl_real_N.ogg/.wav/.mp3).
const WOLF := preload("res://assets/audio/animals/wolf_howl.wav")
const WOLF_REAL_PATTERN := "res://assets/audio/animals/wolf_howl_real_%d.%s"

## Fontes de vento em volta do ouvinte e a distância delas.
const WIND_RING := 4
const WIND_RING_RADIUS := 12.0
## Quantas árvores próximas farfalham ao mesmo tempo.
const RUSTLE_SOURCES := 6
const RUSTLE_RANGE := 35.0

## De onde os pássaros cantam e as folhas farfalham.
var vegetation: Vegetation
## Quanto o ouvinte está dentro da caverna (0..1), suavizado no tempo.
var indoor := 0.0

var _wind_ring: Array[AudioStreamPlayer3D] = []
var _ear_wind: AudioStreamPlayer
var _insects: AudioStreamPlayer
var _cave_tone: AudioStreamPlayer
var _rustles: Array[OccludedAudio] = []
## Para cada fonte de farfalhar, o índice da árvore em Vegetation.trees (-1 = livre).
var _rustle_tree: Array[int] = []
var _rustle_timer := 0.0
var _callers: Array[OccludedAudio] = []
var _bird_timer := 2.0
var _woodpecker_timer := 20.0
var _wolf_timer := 45.0
var _wolf_sounds: Array[AudioStream] = []
var _ambience_bus := AudioServer.get_bus_index(&"Ambience")
var _world_bus := AudioServer.get_bus_index(&"World")


func _ready() -> void:
	for i in range(1, 6):
		for extension in ["ogg", "wav", "mp3"]:
			var path := WOLF_REAL_PATTERN % [i, extension]
			if ResourceLoader.exists(path):
				_wolf_sounds.append(load(path))
	if _wolf_sounds.is_empty():
		_wolf_sounds.append(WOLF)
	for i in WIND_RING:
		var source := AudioStreamPlayer3D.new()
		source.stream = WIND_LOOP
		source.bus = &"Ambience"
		source.unit_size = 14.0
		source.max_distance = 80.0
		add_child(source)
		source.play(randf() * WIND_LOOP.get_length())
		_wind_ring.append(source)
	# Cada loop começa num ponto sorteado: nada soa como faixa dando play junto.
	_ear_wind = _loop(WIND_LOOP, &"Ambience")
	_insects = _loop(preload("res://assets/audio/ambience/grasshoppers_loop.wav"), &"Ambience")
	_cave_tone = _loop(preload("res://assets/audio/ambience/cave_loop.wav"), &"World")
	for i in RUSTLE_SOURCES:
		var rustle := OccludedAudio.new()
		rustle.stream = LEAVES_LOOP
		rustle.clear_bus = &"Ambience"
		rustle.unit_size = 7.0
		rustle.max_distance = 45.0
		rustle.volume_db = -80.0
		add_child(rustle)
		rustle.play(randf() * LEAVES_LOOP.get_length())
		_rustles.append(rustle)
		_rustle_tree.append(-1)
	for i in 4:
		var caller := OccludedAudio.new()
		caller.clear_bus = &"Ambience"
		add_child(caller)
		_callers.append(caller)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if Game.player == null or camera == null:
		return
	# O ouvido é a câmera; a caverna é medida pelo corpo do goblin.
	var ear := camera.global_position
	var body := Game.player.global_position
	indoor = move_toward(indoor, ForestLayout.cave_interior(Vector2(body.x, body.z)), delta * 0.7)

	_update_wind(ear)
	_rustle_timer -= delta
	if _rustle_timer <= 0.0:
		_rustle_timer = 0.5
		_assign_rustles(ear)
	_update_rustles()

	_insects.volume_db = linear_to_db(0.1 * (1.0 - indoor) * (1.0 - 0.5 * smoothstep(0.5, 0.9, Wind.intensity)) + 0.0001)
	_cave_tone.volume_db = linear_to_db(0.3 * indoor + 0.0001)
	var lowpass := AudioServer.get_bus_effect(_ambience_bus, 0) as AudioEffectLowPassFilter
	lowpass.cutoff_hz = 20000.0 * pow(700.0 / 20000.0, indoor)
	var reverb := AudioServer.get_bus_effect(_world_bus, 0) as AudioEffectReverb
	reverb.wet = lerpf(0.03, 0.4, indoor)

	_tick_calls(delta, ear)


func _update_wind(ear: Vector3) -> void:
	for i in WIND_RING:
		var angle := TAU * i / WIND_RING
		var at := ear + Vector3(cos(angle), 0.0, sin(angle)) * WIND_RING_RADIUS + Vector3.UP * 3.0
		_wind_ring[i].global_position = at
		_wind_ring[i].volume_db = linear_to_db(clampf(Wind.strength_at(at) * 0.8, 0.0001, 1.0))
	# Rajada forte bem em cima do goblin: chiado colado no ouvido.
	var here := Wind.strength_at(ear)
	_ear_wind.volume_db = linear_to_db(maxf(smoothstep(0.45, 1.0, here) * 0.55, 0.0001))


## Prende as fontes de farfalhar nas árvores mais próximas, mexendo só nas que mudaram.
func _assign_rustles(ear: Vector3) -> void:
	if vegetation == null:
		return
	var nearest := _nearest_trees(ear)
	for i in RUSTLE_SOURCES:
		if _rustle_tree[i] != -1 and not nearest.has(_rustle_tree[i]):
			_rustle_tree[i] = -1
	for id in nearest:
		if _rustle_tree.has(id):
			continue
		var slot := _rustle_tree.find(-1)
		if slot == -1:
			break
		_rustle_tree[slot] = id
		var tree := vegetation.trees[id]
		_rustles[slot].global_position = tree.base + Vector3.UP * (4.0 if tree.dead else 6.0)


func _update_rustles() -> void:
	for i in RUSTLE_SOURCES:
		var id := _rustle_tree[i]
		if id == -1 or vegetation.trees[id].fallen:
			_rustles[i].set_base_volume(-80.0)
			continue
		var tree := vegetation.trees[id]
		# Agulhas de pinheiro chiam; galho seco quase não faz barulho.
		var loudness := Wind.strength_at(tree.base) * (0.3 if tree.dead else 0.9)
		_rustles[i].set_base_volume(linear_to_db(clampf(loudness, 0.0001, 1.0)))


func _nearest_trees(ear: Vector3) -> Array[int]:
	var candidates := []
	var here := Vector2(ear.x, ear.z)
	for id in vegetation.trees.size():
		var tree := vegetation.trees[id]
		var distance := here.distance_to(Vector2(tree.base.x, tree.base.z))
		if distance < RUSTLE_RANGE and not tree.fallen:
			candidates.append([distance, id])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array[int] = []
	for entry in candidates.slice(0, RUSTLE_SOURCES):
		result.append(entry[1])
	return result


func _tick_calls(delta: float, ear: Vector3) -> void:
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(2.0, 7.0) * (1.0 + indoor * 2.0) * (1.0 + Wind.intensity)
		_call(BIRDS.pick_random(), _point_near(ear, 10.0, 38.0, 6.0), 10.0, -3.0, randf_range(0.9, 1.15))
	_woodpecker_timer -= delta
	if _woodpecker_timer <= 0.0:
		_woodpecker_timer = randf_range(25.0, 50.0)
		_call(WOODPECKER, _point_near(ear, 30.0, 60.0, 5.0), 14.0, -2.0, randf_range(0.95, 1.05))
	_wolf_timer -= delta
	if _wolf_timer <= 0.0:
		_wolf_timer = randf_range(70.0, 140.0)
		var angle := randf() * TAU
		var far := ear + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(130.0, 170.0) + Vector3.UP * 30.0
		_call(_wolf_sounds.pick_random(), far, 70.0, -4.0, randf_range(0.92, 1.05))


## Toca um som solto num ponto do mundo, usando um dos tocadores livres.
func _call(stream: AudioStream, at: Vector3, unit_size: float, volume_db: float, pitch: float) -> void:
	for caller in _callers:
		if caller.playing:
			continue
		caller.stream = stream
		caller.global_position = at
		caller.unit_size = unit_size
		caller.max_distance = unit_size * 20.0
		caller.set_base_volume(volume_db)
		caller.pitch_scale = pitch
		caller.play()
		return


## Um ponto numa árvore entre min e max metros do ouvinte (ou em volta, sem árvore).
func _point_near(ear: Vector3, min_distance: float, max_distance: float, height: float) -> Vector3:
	var here := Vector2(ear.x, ear.z)
	if vegetation != null and not vegetation.tree_positions.is_empty():
		for attempt in 16:
			var tree := vegetation.tree_positions[randi() % vegetation.tree_positions.size()]
			var distance := here.distance_to(tree)
			if distance > min_distance and distance < max_distance:
				return Vector3(tree.x, ear.y + height, tree.y)
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * randf_range(min_distance, max_distance)
	return Vector3(here.x + offset.x, ear.y + height, here.y + offset.y)


func _loop(stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	player.play(randf() * stream.get_length())
	return player
