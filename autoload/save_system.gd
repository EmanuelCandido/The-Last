extends Node
## Salva e carrega a partida em JSON (user://save.json).
##
## Dois tipos de estado:
## - Da fase: coloque o nó no grupo "persist" e implemente
##     save_data() -> Dictionary
##     load_data(data: Dictionary) -> void
##   Os dados ficam indexados pelo caminho do nó dentro da fase.
## - Global (autoloads da lista GLOBALS): mesmo contrato, indexados pelo nome. Um save
##   sem a chave de um deles carrega load_data({}), ou seja, os valores iniciais.
##
## snapshot() e restore() fazem o mesmo na memória, sem tocar no disco (a memória do ciclo 346
## mexe na noite, na fogueira e no goblin, e devolve tudo no fim). O ciclo_346.sav, que aparece
## em "Carregar", é falso: quem cuida dele é o MetaFiles.

const SAVE_PATH := "user://save.json"
const PERSIST_GROUP := &"persist"
## 1: só inventário fora da fase. 2: estado global genérico (história, relógio, corpo).
const FORMAT_VERSION := 2


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	# Acordado no Abrigo não dá para salvar (§6.2); o goblin da IA (Bem-vindo de volta) nunca salva.
	if Game.current_level == null or Game.awake or Game.welcome:
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar em %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(snapshot(), "\t"))
	return true


## Carrega o save. `fresh` = numa fase nova (Continuar, do menu): o estado global entra antes, para a
## floresta já nascer como o save deixou (o vazio do norte, a porta da ruína...).
func load_game(fresh := false) -> bool:
	if not has_save():
		return false
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if payload is not Dictionary:
		push_error("Save corrompido: %s" % SAVE_PATH)
		return false
	if fresh:
		var globals: Dictionary = (payload as Dictionary).get("globals", {})
		for key: String in _globals():
			_globals()[key].load_data(globals.get(key, {}))
		var level_path: String = (payload as Dictionary).get("level", "")
		if ResourceLoader.exists(level_path):
			Game.change_level(level_path, false)
	if not restore(payload):
		return false
	MetaFiles.ensure()
	return true


## Apaga o save (Novo jogo).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Volta o estado global ao começo do jogo (o que load_data({}) dá).
func reset_globals() -> void:
	for key: String in _globals():
		_globals()[key].load_data({})


## "Dia 4 · Ciclo 347", lido do save no disco ("" sem save).
func describe_save() -> String:
	if not has_save():
		return ""
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if payload is not Dictionary:
		return "corrompido"
	var globals: Dictionary = (payload as Dictionary).get("globals", {})
	var clock: Dictionary = globals.get("clock", {})
	var story: Dictionary = globals.get("story", {})
	return "Dia %d · Ciclo %d" % [int(clock.get("day", 1)), int(story.get("cycle", Story.START_CYCLE))]


## O estado da partida agora (a fase, os nós persistentes e os autoloads).
func snapshot() -> Dictionary:
	var level := Game.current_level
	var nodes := {}
	for node in get_tree().get_nodes_in_group(PERSIST_GROUP):
		if level != null and level.is_ancestor_of(node) and node.has_method("save_data"):
			nodes[str(level.get_path_to(node))] = node.save_data()
	var globals := {}
	for key: String in _globals():
		globals[key] = _globals()[key].save_data()
	return {
		"version": FORMAT_VERSION,
		"level": level.scene_file_path if level != null else "",
		"nodes": nodes,
		"globals": globals,
	}


## Põe o jogo no estado de `payload` (de snapshot ou do arquivo).
func restore(payload: Dictionary) -> bool:
	if Game.awake:
		Game.return_to_forest(true)
	var level_path: String = payload.get("level", "")
	if not ResourceLoader.exists(level_path):
		push_error("Fase do save não existe: %s" % level_path)
		return false
	if Game.current_level == null or Game.current_level.scene_file_path != level_path:
		Game.change_level(level_path)

	var globals: Dictionary = payload.get("globals", {})
	if payload.has("inventory"):
		# Save da versão 1: o inventário ficava fora de "globals".
		globals["inventory"] = payload["inventory"]
	for key: String in _globals():
		_globals()[key].load_data(globals.get(key, {}))
	var nodes: Dictionary = payload.get("nodes", {})
	for path: String in nodes:
		var node := Game.current_level.get_node_or_null(NodePath(path))
		if node != null and node.has_method("load_data"):
			node.load_data(nodes[path])
	return true


## Estado global salvo junto com a partida. Para salvar um autoload novo, ponha aqui.
func _globals() -> Dictionary:
	return {"inventory": Inventory, "story": Story, "clock": Clock, "vitals": Vitals, "weather": Weather}
