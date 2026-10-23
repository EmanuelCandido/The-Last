class_name CraftAbility
extends Node
## Fabricar ("craft", R), §4.10: abre uma lista pequena no canto da tela, com as receitas
## de Recipes.LIST. O tempo não para. Escolhe com a roda do mouse, as setas ou o D-pad;
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
var _label: RichTextLabel
var _footer: RichTextLabel

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
	for item: StringName in recipe.cost:
		Inventory.remove(item, int(recipe.cost[item]))
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
	OccludedAudio.play_at(_player, CRAFT_SOUNDS.pick_random(), _player.global_position + Vector3.UP * 0.6, &"World", -4.0, 3.0)
	Events.notification_shown.emit(String(recipe.get("message", recipe.name)))
	Events.crafted.emit(recipe.id)
	_idle = 0.0


func _select(index: int) -> void:
	selected = posmod(index, Recipes.LIST.size())
	_idle = 0.0
	_refresh()


func _refresh() -> void:
	if _label == null or not _open:
		return
	var ink := UiStyle.hex(UiStyle.INK)
	var dim := UiStyle.hex(UiStyle.INK_DIM)
	var faint := UiStyle.hex(UiStyle.INK_FAINT)
	var accent := UiStyle.hex(UiStyle.ACCENT)
	var lines := PackedStringArray()
	for i in Recipes.LIST.size():
		var recipe := Recipes.LIST[i]
		var missing := Recipes.missing(recipe)
		var ready := missing == ""
		var name_color := (accent if i == selected else ink) if ready else faint
		var marker := "›" if i == selected else " "
		var detail := Recipes.cost_text(recipe) if ready else missing
		lines.append("[color=%s]%s %d  %s[/color]  [color=%s][i]%s[/i][/color]" % [
			name_color, marker, i + 1, recipe.name, dim if ready else faint, detail])
	_label.text = "\n".join(lines)
	_footer.text = "[color=%s][lb]%s[rb][/color] fazer   [color=%s]roda/setas[/color] escolher   [color=%s][lb]%s[rb][/color] fechar" % [
		accent, Settings.key_label(&"interact", true), accent, accent, Settings.key_label(&"craft", true)]


## A lista: um painel escuro no canto, título em ocre, as receitas e as teclas embaixo.
func _build_list() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2
	_layer.visible = false
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelDark"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -500.0
	panel.offset_right = -14.0
	panel.offset_top = -60.0
	panel.offset_bottom = -52.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)
	var title := UiStyle.label("Fabricar", &"Heading", 16)
	column.add_child(title)
	column.add_child(UiStyle.separator())
	_label = _rich_label()
	column.add_child(_label)
	column.add_child(UiStyle.separator())
	_footer = _rich_label()
	column.add_child(_footer)


func _rich_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
