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
	var lines := PackedStringArray(["[b]FABRICAR[/b]"])
	for i in Recipes.LIST.size():
		var recipe := Recipes.LIST[i]
		var missing := Recipes.missing(recipe)
		var color := "#f2ead6" if missing == "" else "#8a857a"
		var marker := "›" if i == selected else " "
		var detail := Recipes.cost_text(recipe) if missing == "" else missing
		lines.append("[color=%s]%s %d  %s  [i]%s[/i][/color]" % [color, marker, i + 1, recipe.name, detail])
	lines.append("[color=#b8b2a4][E] fazer   roda/setas escolher   [R] fechar[/color]")
	_label.text = "\n".join(lines)


func _build_list() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 2
	_layer.visible = false
	add_child(_layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.045, 0.62)
	style.set_content_margin_all(10.0)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470.0
	panel.offset_right = -14.0
	panel.offset_top = -230.0
	panel.offset_bottom = -46.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.fit_content = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"normal_font_size", 15)
	_label.add_theme_font_size_override(&"bold_font_size", 15)
	_label.add_theme_font_size_override(&"italics_font_size", 14)
	_label.add_theme_constant_override(&"outline_size", 3)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	panel.add_child(_label)
