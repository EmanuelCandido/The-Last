extends Node
## Cena raiz: entrega o LevelRoot ao Game e carrega a primeira fase.

@onready var _level_root: Node3D = $LevelRoot


func _ready() -> void:
	Game.level_root = _level_root
	Game.change_level(Game.FIRST_LEVEL)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
