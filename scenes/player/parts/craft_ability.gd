class_name CraftAbility
extends Node
## Fabricar ("craft", R), §4.10: abre uma lista pequena no canto da tela, com as receitas
## de Recipes.LIST, uma por vez (a escolhida, com o custo ou o que falta embaixo). O tempo não
## para. Escolhe com a roda do mouse, as setas ou o D-pad;
## E (ou o número da receita) fabrica, com a animação "craft"; R fecha. A lista some
## sozinha depois de Tuning.CRAFT_LIST_SECONDS sem mexer nela.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica (e a lista).

const CRAFT_SOUNDS := [
	preload("res://assets/audio/real/craft_1.ogg"), preload("res://assets/audio/real/craft_2.ogg"),
	preload("res://assets/audio/real/craft_3.ogg"),
]

var selected := 0

var _open := false
var _idle := 0.0
var _layer: CanvasLayer
var _name: Label
var _cost: Label
var _make_key: Label
var _close_key: Label

@onready var _player: Player = get_parent()


func _ready() -> void:
	_build_list()
	Inventory.changed.connect(func(_item: StringName, _amount: int) -> void: _refresh())
	Events.game_paused.connect(func(paused: bool) -> void:
		if paused:
			set_open(false))


func _process(delta: float) -> void:
	if not _open:
		return
	_idle += delta
	if _idle >= Tuning.CRAFT_LIST_SECONDS or Game.resting:
		set_open(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("craft"):
		get_viewport().set_input_as_handled()
		set_open(not _open and _player.can_act())
		return
	if not _open or not event.is_pressed() or event.is_echo():
		return
	var choice := -1
	if event is InputEventKey:
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key < KEY_1 + Recipes.LIST.size():
			choice = key - KEY_1
	if event.is_action_pressed("ui_down") or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_select(selected + 1)
	elif event.is_action_pressed("ui_up") or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP):
		_select(selected - 1)
	elif event.is_action_pressed("interact"):
		choice = selected
	else:
		if choice == -1:
			return
	get_viewport().set_input_as_handled()
	if choice >= 0:
		selected = choice
		craft(Recipes.LIST[choice])


func is_open() -> bool:
	return _open


func set_open(open: bool) -> void:
	_open = open
	_idle = 0.0
	_layer.visible = open
	if open:
		# Começa na primeira receita que dá para fazer.
		for i in Recipes.LIST.size():
			if Recipes.missing(Recipes.LIST[i]) == "":
				selected = i
				break
	_refresh()


## Fabrica `recipe` se der: o custo só sai quando a coisa fica pronta, no fim da animação.
func craft(recipe: Dictionary) -> void:
	_idle = 0.0
	if not _player.can_act():
		return
	var missing := Recipes.missing(recipe)
	if missing != "":
		Events.notification_shown.emit("%s: %s." % [recipe.name, missing])
		return
	_player.perform(&"craft", Tuning.CRAFT_TIME, [[Tuning.CRAFT_DONE_AT, _finish.bind(recipe)]])
	OccludedAudio.play_at(_player, CRAFT_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.6, &"World", -4.0, 3.0)


func _finish(recipe: Dictionary) -> void:
	if Recipes.missing(recipe) != "":
		return
	var cost := Recipes.cost_of(recipe)
	for item: StringName in cost:
		Inventory.remove(item, int(cost[item]))
	for item: StringName in recipe.gives:
		Inventory.add(item, int(recipe.gives[item]))
	match recipe.get("special", &""):
		&"torch":
			var torch := _player.get_node_or_null(^"TorchCarry") as TorchCarry
			if torch != null:
				torch.light()
		&"blind":
			var field := get_tree().get_first_node_in_group(BlindField.GROUP) as BlindField
			if field != null:
				# A abertura fica para onde o goblin olha.
				var facing := _player.facing()
				field.build_at(_player.global_position, atan2(facing.x, facing.z))
		&"cairn":
			var cairns := get_tree().get_first_node_in_group(CairnField.GROUP) as CairnField
			if cairns != null:
				# Um passo à frente: o marco não nasce dentro do goblin.
				cairns.build_at(_player.global_position + _player.facing() * 0.7)
		&"bench":
			for node in get_tree().get_nodes_in_group(Workbench.GROUP):
				if not (node as Workbench).built:
					(node as Workbench).build_now()
					break
		&"repair":
			Inventory.repair(Inventory.held())
		&"log":
			var field := get_tree().get_first_node_in_group(TrapField.GROUP) as TrapField
			var tree := Recipes._dead_tree_near()
			if field != null and tree != -1:
				var facing := _player.facing()
				field.build_at(&"log", _player.global_position + facing * 0.6, atan2(facing.x, facing.z), tree)
		&"stakes", &"bones":
			var traps := get_tree().get_first_node_in_group(TrapField.GROUP) as TrapField
			if traps != null:
				var facing := _player.facing()
				var kind: StringName = &"stakes" if recipe.special == &"stakes" else &"bones"
				if not traps.build_at(kind, _player.global_position + facing * 0.8, atan2(facing.x, facing.z)):
					Events.notification_shown.emit("Já tem armadilhas demais desse tipo.")
		&"stash":
			for node in get_tree().get_nodes_in_group(CaveStash.GROUP):
				if not (node as CaveStash).built:
					(node as CaveStash).build_now()
					break
	OccludedAudio.play_at(_player, CRAFT_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.6, &"World", -4.0, 3.0)
	Events.notification_shown.emit(String(recipe.get("message", recipe.name)).format(Settings.key_labels()))
	Events.crafted.emit(recipe.id)
	_idle = 0.0


func _select(index: int) -> void:
	selected = posmod(index, Recipes.LIST.size())
	_idle = 0.0
	_refresh()


func _refresh() -> void:
	if _name == null or not _open:
		return
	var recipe := Recipes.LIST[selected]
	var missing := Recipes.missing(recipe)
	var ready := missing == ""
	_name.text = recipe.name
	_name.add_theme_color_override(&"font_color", UiStyle.INK if ready else UiStyle.INK_FAINT)
	_cost.text = Recipes.cost_text(recipe) if ready else missing
	_cost.add_theme_color_override(&"font_color", UiStyle.INK_DIM if ready else UiStyle.BLOOD.lightened(0.2))
	_make_key.text = "[%s] Fazer" % Settings.key_label(&"interact", true)
	_close_key.text = "[%s] Fechar" % Settings.key_label(&"craft", true)
	var font_size := UiStyle.hud_font_size()
	for label: Label in [_name, _cost, _make_key, _close_key]:
		label.add_theme_font_size_override(&"font_size", font_size)


## A lista, direto sobre a cena no canto de baixo, em cima da linha de itens do HUD: o marcador
## laranja, a receita escolhida e o custo embaixo, as setas de escolher e as teclas à direita.
func _build_list() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2
	_layer.visible = false
	add_child(_layer)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", -6)
	grid.anchor_left = 1.0
	grid.anchor_right = 1.0
	grid.anchor_top = 1.0
	grid.anchor_bottom = 1.0
	grid.offset_right = -32.0
	grid.offset_bottom = -72.0
	grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(grid)
	grid.add_child(UiStyle.sprite(UiStyle.MARKER, 2))
	_name = UiStyle.label("")
	_name.custom_minimum_size.x = 200.0
	grid.add_child(_name)
	grid.add_child(UiStyle.sprite(UiStyle.UP_DOWN, 2))
	_make_key = UiStyle.label("")
	grid.add_child(_make_key)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(gap)
	_cost = UiStyle.label("")
	grid.add_child(_cost)
	var gap_2 := Control.new()
	gap_2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(gap_2)
	_close_key = UiStyle.label("")
	grid.add_child(_close_key)
