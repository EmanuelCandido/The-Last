extends Node
## Estado global da partida: fase atual, jogador, pausa e captura do mouse.

const FIRST_LEVEL := "res://scenes/levels/forest/forest.tscn"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

## Nó onde as fases são instanciadas. Definido pela cena Main.
var level_root: Node3D
var current_level: Node3D
var player: Player


func _ready() -> void:
	# Precisa receber input mesmo pausado, para conseguir despausar.
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	Events.level_loaded.emit(current_level)


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
