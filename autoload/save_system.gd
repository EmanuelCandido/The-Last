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

const SAVE_PATH := "user://save.json"
const PERSIST_GROUP := &"persist"
## 1: só inventário fora da fase. 2: estado global genérico (história, relógio, corpo).
const FORMAT_VERSION := 2


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var level := Game.current_level
	# Acordado no Abrigo não dá para salvar (§6.2).
	if level == null or Game.awake:
		return false

	var nodes := {}
	for node in get_tree().get_nodes_in_group(PERSIST_GROUP):
		if level.is_ancestor_of(node) and node.has_method("save_data"):
			nodes[str(level.get_path_to(node))] = node.save_data()

	var globals := {}
	for key: String in _globals():
		globals[key] = _globals()[key].save_data()

	var payload := {
		"version": FORMAT_VERSION,
		"level": level.scene_file_path,
		"nodes": nodes,
		"globals": globals,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar em %s: %s" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true


func load_game() -> bool:
	if not has_save():
		return false

	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if payload is not Dictionary:
		push_error("Save corrompido: %s" % SAVE_PATH)
		return false

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
	return {"inventory": Inventory, "story": Story, "clock": Clock, "vitals": Vitals}
