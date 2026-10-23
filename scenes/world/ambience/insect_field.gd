class_name InsectField
extends Node3D
## Os grilos e gafanhotos do vale: cada um é um ponto de verdade no capim, sempre no mesmo
## lugar (semente fixa), e o som sai dele.
## - Grilos cantam de noite (cada um começa num ponto do anoitecer), na grama e na borda da mata;
##   gafanhotos de dia, em campo aberto. Chuva e vento forte calam os dois.
## - Todo canto sai de onde os insetos estão. Os Tuning.INSECT_VOICES mais perto do ouvido que
##   estão cantando ganham um tocador 3D com o canto de um bicho só (tom e ponto de começo
##   próprios). Os mais longe, até Tuning.INSECT_CHORUS_RANGE, são agrupados em células de
##   CLUSTER_CELL metros: as CLUSTERS células que mais soam ganham um tocador 3D com o coro, no meio
##   dos que cantam ali e no volume de quantos são (abafado atrás de terreno ou rocha).
## - Com o goblin andando perto, o inseto se cala e só volta depois que ele se afasta; um
##   barulho (Events.noise_made) cala os do raio. O gafanhoto do pé pula para longe.
## Filho do Ambience (que dá o quanto o ouvinte está dentro da caverna).

enum Kind { CRICKET, GRASSHOPPER }

const SONGS: Array[AudioStream] = [
	preload("res://assets/audio/animals/cricket_song.wav"),
	preload("res://assets/audio/animals/grasshopper_song.wav"),
]
const CHORUS: Array[AudioStream] = [
	preload("res://assets/audio/ambience/crickets_loop.wav"),
	preload("res://assets/audio/ambience/grasshoppers_loop.wav"),
]
const SEED := 5101
## Volume de um bicho só (dB, a 2 m).
const VOICE_DB: Array[float] = [-7.0, -11.0]
## O coro: lado da célula que vira um grupo (m), quantos grupos tocam ao mesmo tempo e o volume
## do coro (dB, a 2 m) para um inseto só; cada grupo soma 10·log10(quantos cantam).
const CLUSTER_CELL := 16.0
const CLUSTERS := 8
const CLUSTER_DB: Array[float] = [-13.0, -17.0]
## Pulo do gafanhoto: duração (s) e altura (m).
const HOP_TIME := 0.45
const HOP_HEIGHT := 0.5

var _pos := PackedVector3Array()
var _kind := PackedByteArray()
var _pitch := PackedFloat32Array()
## Grilo: começa a cantar com Clock.night() acima disto; gafanhoto: com o dia (1 - night) acima.
var _wake := PackedFloat32Array()
## Calado até este instante (_time).
var _quiet := PackedFloat32Array()
var _time := 0.0
var _tick := 0.0
var _voices: Array[AudioStreamPlayer3D] = []
## Inseto de cada tocador (-1 = livre) e o volume que ele está buscando (dB).
var _voice_insect: Array[int] = []
var _voice_target: Array[float] = []
## Tocadores do coro: a célula de cada um ([tipo, x, z]; null = livre), o volume buscado e o atual (dB).
var _clusters: Array[OccludedAudio] = []
var _cluster_key: Array = []
var _cluster_target: Array[float] = []
var _cluster_db: Array[float] = []
## Pulos em andamento: [malha, de, para, tempo].
var _hops: Array = []
var _hop_pool: Array[MeshInstance3D] = []
var _terrain: Terrain


func build(terrain: Terrain) -> void:
	_terrain = terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_scatter(Kind.CRICKET, Tuning.CRICKET_COUNT, 0.75, rng)
	_scatter(Kind.GRASSHOPPER, Tuning.GRASSHOPPER_COUNT, 0.3, rng)
	_quiet.resize(_pos.size())
	for i in Tuning.INSECT_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"Ambience"
		voice.unit_size = 2.0
		voice.volume_db = -80.0
		add_child(voice)
		_voices.append(voice)
		_voice_insect.append(-1)
		_voice_target.append(-80.0)
	for i in CLUSTERS:
		var cluster := OccludedAudio.new()
		cluster.clear_bus = &"Ambience"
		cluster.unit_size = 2.0
		cluster.max_distance = Tuning.INSECT_CHORUS_RANGE + 30.0
		cluster.volume_db = -80.0
		add_child(cluster)
		_clusters.append(cluster)
		_cluster_key.append(null)
		_cluster_target.append(-80.0)
		_cluster_db.append(-80.0)
	var body := Animal.flat_material(Color(0.32, 0.34, 0.18))
	for i in 4:
		var hopper := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.02, 0.055)
		hopper.mesh = box
		hopper.material_override = body
		hopper.visible = false
		add_child(hopper)
		_hop_pool.append(hopper)
	Events.noise_made.connect(_on_noise)


## Quantos insetos de cada tipo há (para os testes).
func count(kind: Kind) -> int:
	var total := 0
	for k in _kind:
		if k == kind:
			total += 1
	return total


## Se o inseto `i` está cantando agora.
func singing(i: int) -> bool:
	if _time < _quiet[i] or _terrain == null:
		return false
	if Story.has_flag(&"climate_cut") and _pos[i].z < Tuning.VOID_EDGE_Z:
		return false
	var mood := (1.0 - Weather.rain) * (1.0 - 0.7 * smoothstep(0.6, 1.0, Wind.intensity))
	if mood < 0.3:
		return false
	var night := Clock.night()
	if _kind[i] == Kind.CRICKET:
		return night >= _wake[i]
	return 1.0 - night >= _wake[i]


## Onde está o inseto `i` e de que tipo é (para os testes).
func insect_position(i: int) -> Vector3:
	return _pos[i]


func insect_kind(i: int) -> int:
	return _kind[i]


func insect_count() -> int:
	return _pos.size()


## O inseto que um tocador está tocando agora (-1 = nenhum), para os testes.
func voiced() -> Array[int]:
	var list: Array[int] = []
	for i in _voices.size():
		if _voice_insect[i] != -1 and _voice_target[i] > -60.0:
			list.append(_voice_insect[i])
	return list


## Os grupos do coro tocando agora: [tipo, ponto, volume buscado], para os testes.
func choruses() -> Array:
	var list := []
	for c in _clusters.size():
		if _cluster_key[c] != null and _cluster_target[c] > -60.0:
			list.append([(_cluster_key[c] as Vector3i).x, _clusters[c].global_position, _cluster_target[c]])
	return list


func _process(delta: float) -> void:
	if _terrain == null or Game.player == null or Game.resting:
		return
	_time += delta
	_tick -= delta
	var camera := get_viewport().get_camera_3d()
	if _tick <= 0.0 and camera != null:
		_tick = 0.2
		_react_to_player()
		_assign(camera.global_position)
	for i in _voices.size():
		var voice := _voices[i]
		# Calar é rápido (o grilo para de uma vez); voltar é mais devagar.
		var speed := 220.0 if _voice_target[i] < voice.volume_db else 60.0
		voice.volume_db = move_toward(voice.volume_db, _voice_target[i], speed * delta)
		if voice.volume_db <= -79.0 and voice.playing:
			voice.stop()
	for i in _clusters.size():
		_cluster_db[i] = move_toward(_cluster_db[i], _cluster_target[i], 20.0 * delta)
		_clusters[i].set_base_volume(_cluster_db[i])
		if _cluster_db[i] <= -79.0 and _clusters[i].playing:
			_clusters[i].stop()
			_cluster_key[i] = null
	_update_hops(delta)


## Insetos onde há capim: grilo até a borda da mata, gafanhoto só no aberto.
func _scatter(kind: Kind, total: int, max_density: float, rng: RandomNumberGenerator) -> void:
	var placed := 0
	var tries := 0
	while placed < total and tries < total * 30:
		tries += 1
		var angle := rng.randf() * TAU
		var p := Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * (ForestLayout.VALLEY_RADIUS - 6.0)
		if ForestLayout.cave_ellipse(p) < 1.8 or ForestLayout.distance_to_trail(p) < 1.0:
			continue
		if _terrain.forest_density(p.x, p.y) > max_density:
			continue
		var at := Vector3(p.x, _terrain.get_height(p.x, p.y) + 0.05, p.y)
		if _terrain.surface_at(at) != &"grass":
			continue
		_pos.append(at)
		_kind.append(kind)
		_pitch.append(rng.randf_range(0.86, 1.18) if kind == Kind.CRICKET else rng.randf_range(0.85, 1.15))
		_wake.append(rng.randf_range(0.2, 0.7) if kind == Kind.CRICKET else rng.randf_range(0.45, 0.85))
		placed += 1


## Goblin andando perto: os insetos se calam; o gafanhoto do pé pula.
func _react_to_player() -> void:
	var player := Game.player
	var at := player.global_position
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.6
	if not moving:
		return
	var soft := Tuning.BIRD_CROUCH_FACTOR if player.is_crouching() else 1.0
	for i in _pos.size():
		var d := Vector2(_pos[i].x - at.x, _pos[i].z - at.z).length()
		var radius := Tuning.CRICKET_QUIET_RADIUS if _kind[i] == Kind.CRICKET else Tuning.GRASSHOPPER_QUIET_RADIUS
		if d > radius * soft:
			continue
		_silence(i)
		if _kind[i] == Kind.GRASSHOPPER and d < Tuning.GRASSHOPPER_FLUSH_RADIUS:
			_jump(i, at)


func _on_noise(at: Vector3, radius: float) -> void:
	for i in _pos.size():
		if _pos[i].distance_to(at) < radius * 0.7:
			_silence(i)


func _silence(i: int) -> void:
	_quiet[i] = maxf(_quiet[i], _time + randf_range(Tuning.INSECT_QUIET_SECONDS.x, Tuning.INSECT_QUIET_SECONDS.y))


## O gafanhoto salta para longe do goblin e fica lá (o ponto dele muda de vez).
func _jump(i: int, from: Vector3) -> void:
	var away := Vector2(_pos[i].x - from.x, _pos[i].z - from.z)
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
	away = away.rotated(randf_range(-0.6, 0.6)) * randf_range(Tuning.GRASSHOPPER_JUMP.x, Tuning.GRASSHOPPER_JUMP.y)
	var land := Vector2(_pos[i].x, _pos[i].z) + away
	var to := Vector3(land.x, _terrain.get_height(land.x, land.y) + 0.05, land.y)
	for hopper in _hop_pool:
		if not hopper.visible:
			hopper.visible = true
			hopper.global_position = _pos[i]
			hopper.rotation.y = atan2(away.x, away.y)
			_hops.append([hopper, _pos[i], to, 0.0])
			break
	_pos[i] = to


func _update_hops(delta: float) -> void:
	for hop: Array in _hops.duplicate():
		var hopper: MeshInstance3D = hop[0]
		var t: float = hop[3] + delta / HOP_TIME
		hop[3] = t
		var from: Vector3 = hop[1]
		var to: Vector3 = hop[2]
		hopper.global_position = from.lerp(to, minf(t, 1.0)) + Vector3.UP * HOP_HEIGHT * 4.0 * t * (1.0 - t)
		if t >= 1.0:
			hopper.visible = false
			_hops.erase(hop)


## Dá os tocadores aos mais perto que cantam; os de longe somam no coro.
func _assign(ear: Vector3) -> void:
	var indoor: float = get_parent().get("indoor") if get_parent() != null else 0.0
	var near := []
	# Célula -> [peso de quem canta, soma das posições pesadas].
	var cells := {}
	for i in _pos.size():
		var d := ear.distance_to(_pos[i])
		if d > Tuning.INSECT_CHORUS_RANGE or not singing(i):
			continue
		var kind := int(_kind[i])
		var hear := Tuning.CRICKET_HEAR_RANGE if kind == Kind.CRICKET else Tuning.GRASSHOPPER_HEAR_RANGE
		if d < hear:
			near.append([d, i])
		# O coro entra onde o canto sozinho some (a voz apaga de 0,65 até 1 do alcance) e
		# apaga antes do fim do alcance do coro, sem degrau nas duas pontas.
		var weight := smoothstep(hear * 0.65, hear, d) * (1.0 - smoothstep(Tuning.INSECT_CHORUS_RANGE * 0.8, Tuning.INSECT_CHORUS_RANGE, d))
		if weight <= 0.01:
			continue
		var key := Vector3i(kind, floori(_pos[i].x / CLUSTER_CELL), floori(_pos[i].z / CLUSTER_CELL))
		if not cells.has(key):
			cells[key] = [0.0, Vector3.ZERO]
		var cell: Array = cells[key]
		cell[0] += weight
		cell[1] += _pos[i] * weight
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var chosen := {}
	for entry: Array in near.slice(0, _voices.size()):
		chosen[entry[1]] = entry[0]
	# Quem já toca um escolhido continua (o canto não recomeça); o resto vai calando.
	for v in _voices.size():
		var insect := _voice_insect[v]
		if insect != -1 and chosen.has(insect):
			_voice_target[v] = _voice_db(insect, chosen[insect], indoor)
			chosen.erase(insect)
		else:
			_voice_target[v] = -80.0
	for insect: int in chosen:
		for v in _voices.size():
			if _voice_target[v] <= -80.0 and _voices[v].volume_db <= -60.0:
				_start_voice(v, insect)
				_voice_target[v] = _voice_db(insect, chosen[insect], indoor)
				break
	_assign_clusters(ear, cells, indoor)


## Dá os tocadores do coro às células que mais soam daqui (quantos cantam / distância²).
func _assign_clusters(ear: Vector3, cells: Dictionary, indoor: float) -> void:
	var ranked := []
	for key: Vector3i in cells:
		var cell: Array = cells[key]
		var weight: float = cell[0]
		var center: Vector3 = cell[1] / weight
		ranked.append([weight / maxf(ear.distance_squared_to(center), 1.0), key, center, weight])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var chosen := {}
	for entry: Array in ranked.slice(0, _clusters.size()):
		chosen[entry[1]] = entry
	# Quem já toca uma célula escolhida continua (e acompanha o meio dela); o resto vai calando.
	for c in _clusters.size():
		var key: Variant = _cluster_key[c]
		if key != null and chosen.has(key):
			var entry: Array = chosen[key]
			_clusters[c].global_position = entry[2]
			_cluster_target[c] = _cluster_volume(int(entry[1].x), entry[3], indoor)
			chosen.erase(key)
		else:
			_cluster_target[c] = -80.0
	for key: Vector3i in chosen:
		for c in _clusters.size():
			if _cluster_target[c] <= -80.0 and _cluster_db[c] <= -60.0:
				var entry: Array = chosen[key]
				var cluster := _clusters[c]
				_cluster_key[c] = key
				cluster.stream = CHORUS[key.x]
				cluster.pitch_scale = randf_range(0.94, 1.06)
				cluster.global_position = entry[2]
				_cluster_db[c] = -60.0
				cluster.set_base_volume(-60.0)
				cluster.play(randf() * cluster.stream.get_length())
				_cluster_target[c] = _cluster_volume(key.x, entry[3], indoor)
				break


## Volume do coro de uma célula com `count` insetos cantando (o 3D atenua pela distância).
func _cluster_volume(kind: int, count: float, indoor: float) -> float:
	return CLUSTER_DB[kind] + 10.0 * log(maxf(count, 0.01)) / log(10.0) + linear_to_db(maxf(1.0 - indoor, 0.0001))


func _voice_db(insect: int, distance: float, indoor: float) -> float:
	var kind := int(_kind[insect])
	var hear := Tuning.CRICKET_HEAR_RANGE if kind == Kind.CRICKET else Tuning.GRASSHOPPER_HEAR_RANGE
	# Some aos poucos na borda do alcance, para emendar no coro sem degrau.
	var edge := 1.0 - smoothstep(hear * 0.65, hear, distance)
	return linear_to_db(maxf(edge * (1.0 - indoor), 0.0001)) + VOICE_DB[kind]


func _start_voice(v: int, insect: int) -> void:
	var voice := _voices[v]
	_voice_insect[v] = insect
	voice.stream = SONGS[_kind[insect]]
	voice.pitch_scale = _pitch[insect]
	voice.max_distance = (Tuning.CRICKET_HEAR_RANGE if _kind[insect] == Kind.CRICKET else Tuning.GRASSHOPPER_HEAR_RANGE) + 2.0
	voice.global_position = _pos[insect]
	voice.volume_db = -60.0
	voice.play(fmod(insect * 0.737, 1.0) * voice.stream.get_length())
