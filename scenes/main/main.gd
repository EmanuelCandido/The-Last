extends Node
## Cena raiz: entrega o LevelRoot e a interface ao Game e abre o menu principal (nos testes do
## DevTools, vai direto para a primeira fase).

@onready var _level_root: Node3D = $LevelRoot
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	Game.level_root = _level_root
	Game.ui_root = _ui
	DisplayServer.window_set_title(MetaFiles.title())
	if DevTools.show_menu:
		Game.open_menu()
		return
	Game.change_level(Game.FIRST_LEVEL)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
