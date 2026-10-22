extends Node
## Estado global da partida: fase atual, jogador, pausa, captura do mouse e o ouvido.

const FIRST_LEVEL := "res://scenes/levels/forest/forest.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Nó onde as fases são instanciadas. Definido pela cena Main.
var level_root: Node3D
var current_level: Node3D
var player: Player

## O ouvido: um passa-baixa no Master que abre junto com o volume (ver open_ears).
var _ear_filter := AudioEffectLowPassFilter.new()
var _ear_tween: Tween


func _ready() -> void:
	# Precisa receber input mesmo pausado, para conseguir despausar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ear_filter.cutoff_hz = 20500.0
	AudioServer.add_bus_effect(0, _ear_filter)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not get_tree().paused:
		# Recaptura o mouse se o jogador clicar na janela depois de soltar o cursor.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Troca a fase atual e cria o jogador no Marker3D "PlayerSpawn" da nova fase.
func change_level(path: String) -> void:
	assert(level_root != null, "Game.level_root precisa ser definido antes de trocar de fase.")
	if current_level != null:
		level_root.remove_child(current_level)
		current_level.queue_free()
	current_level = (load(path) as PackedScene).instantiate() as Node3D
	level_root.add_child(current_level)
	_spawn_player()
	# Chegando num lugar: o som vem aos poucos, não começa no "play". A fase pode pedir
	# uma abertura mais lenta (o despertar) ao receber level_loaded.
	open_ears(2.5)
	Events.level_loaded.emit(current_level)


## O som chega ao ouvido aos poucos: começa baixo e abafado (`from_db`, `from_hz`) e
## abre em `duration` segundos. O volume sobe primeiro; os agudos chegam por último,
## como ouvidos que despertam.
func open_ears(duration: float, from_db := -30.0, from_hz := 300.0) -> void:
	if _ear_tween != null:
		_ear_tween.kill()
	AudioServer.set_bus_volume_db(0, from_db)
	_ear_filter.cutoff_hz = from_hz
	_ear_tween = create_tween().set_parallel()
	_ear_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(0, db), from_db, 0.0, duration) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ear_tween.tween_property(_ear_filter, ^"cutoff_hz", 20500.0, duration * 1.2) 		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	Events.game_paused.emit(paused)


func quit() -> void:
	get_tree().quit()


func _spawn_player() -> void:
	player = null
	var spawn := current_level.get_node_or_null(^"PlayerSpawn") as Node3D
	if spawn == null:
		return
	player = PLAYER_SCENE.instantiate() as Player
	player.transform = spawn.transform
	current_level.add_child(player)
