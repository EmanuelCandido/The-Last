class_name TreeMarker
extends Node3D
## Riscar o tronco (F10): perto de um pinheiro vivo, aparece "[E] Riscar o tronco" no tronco. O
## goblin raspa a casca com as garras (ação `scratch`) e a árvore fica marcada (TreeMarks), para
## achar o caminho de volta na neblina. Árvore seca não: ela continua com o "Golpear".
##
## Parte do goblin: um nó filho do Player, interagível como a SnareSetter (vai para o tronco e
## o Player o acha sozinho). Tirar o nó tira a mecânica.

const SCRATCH_SOUNDS := [preload("res://assets/audio/sfx/wall_scratch_1.wav"), preload("res://assets/audio/sfx/wall_scratch_2.wav")]

## A árvore ao alcance agora (-1 = nenhuma).
var tree := -1
var _marking := -1

@onready var _player: Player = get_parent()


func _ready() -> void:
	top_level = true
	add_to_group(&"interactable")


func _physics_process(_delta: float) -> void:
	tree = -1
	var level := Game.current_level
	if _player.can_act() and level != null and level.has_method("tree_near"):
		var near: int = level.tree_near(_player.global_position, Tuning.TREE_MARK_REACH)
		if near != -1 and not level.is_tree_dead(near):
			tree = near
	if tree == -1:
		# Longe de tudo quando não há tronco (o Player só olha interagíveis perto).
		global_position = Vector3(0.0, -1000.0, 0.0)
		return
	var base: Vector3 = level.tree_base(tree)
	var to_goblin := Vector3(_player.global_position.x - base.x, 0.0, _player.global_position.z - base.z).normalized()
	global_position = base + to_goblin * float(level.tree_radius(tree)) + Vector3.UP * TreeMarks.HEIGHT


func interaction_prompt() -> String:
	if tree == -1:
		return ""
	return "Tronco já riscado" if _marks() != null and _marks().has_mark(tree) else "Riscar o tronco"


func interaction_enabled() -> bool:
	return tree != -1 and _marks() != null and not _marks().has_mark(tree)


func interaction_action() -> Dictionary:
	return {"action": &"scratch", "duration": Tuning.TREE_MARK_TIME, "at": Tuning.TREE_MARK_TIME - 0.6}


func interaction_started(_player_node: Node) -> void:
	_marking = tree
	OccludedAudio.play_at(_player, SCRATCH_SOUNDS.pick_random(), global_position, &"World", -6.0, 3.0, 0.75)


func interact(_player_node: Node) -> void:
	var level := Game.current_level
	var marks := _marks()
	if marks == null or level == null or _marking == -1:
		return
	marks.mark(_marking, level.tree_base(_marking), level.tree_radius(_marking), _player.global_position)
	OccludedAudio.play_at(_player, SCRATCH_SOUNDS.pick_random(), global_position, &"World", -6.0, 3.0, 0.7)
	_marking = -1


func _marks() -> TreeMarks:
	return get_tree().get_first_node_in_group(TreeMarks.GROUP) as TreeMarks
