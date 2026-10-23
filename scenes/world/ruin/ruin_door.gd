class_name RuinDoor
extends Node3D
## A porta lisa sob a hera, no fundo da capela (§3, beat ruin_door). Ao lado, 4 discos de
## pedra marcados de 0 a 9. E entra no teclado (os controles do goblin travam): ←/→ ou A/D
## escolhem o disco, ↑/↓, W/S ou a roda giram, E empurra, Espaço sai.
##
## A porta só aceita o código (StoryBeats.DOOR_CODE) depois que Ari viu a ruína pela janela
## (StoryBeats.DOOR_FLAG). Aberta, a laje desce no chão e o flag "ruin_door_open" fica no
## Story (o save guarda). Um corvo vendo o goblin no teclado sobe a Vigilância.
## A origem é o meio da soleira, do lado de dentro da capela.

const OPEN_FLAG := &"ruin_door_open"
const DOOR_SOUND := preload("res://assets/audio/sfx/stone_door.wav")
const CLICK_SOUNDS := [preload("res://assets/audio/sfx/stone_click_1.wav"), preload("res://assets/audio/sfx/stone_click_2.wav")]
const HINT := "%s      ←/→ disco  ·  ↑/↓ girar  ·  [E] empurrar  ·  [Espaço] sair"
## Onde ficam os discos, em relação à soleira (à direita de quem olha a porta).
const DISCS_AT := Vector3(-0.82, 0.62, 0.02)
const DISC_SPACING := 0.14

var digits: Array[int] = [0, 0, 0, 0]
var selected := 0
var is_open := false

var _active := false
var _width := 1.0
var _height := 1.8
var _slab: MeshInstance3D
var _body: StaticBody3D
var _discs: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _disc_material: StandardMaterial3D
var _selected_material: StandardMaterial3D


## Monta a laje (`width` × `height`, `thickness`) e os discos na parede.
func build(width: float, height: float, thickness: float) -> void:
	_width = width
	_height = height
	_slab = MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(width, height, thickness)
	_slab.mesh = slab
	# Lisa demais para uma ruína: cinza claro, quase sem textura (a porta não é de pedra).
	var smooth := StandardMaterial3D.new()
	smooth.albedo_color = Color(0.5, 0.51, 0.5)
	smooth.roughness = 0.4
	smooth.metallic_specular = 0.6
	_slab.material_override = smooth
	_slab.position = Vector3(0.0, height * 0.5, -thickness * 0.5)
	add_child(_slab)
	_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = slab.size
	shape.shape = box
	_body.add_child(shape)
	_slab.add_child(_body)

	_disc_material = StandardMaterial3D.new()
	_disc_material.albedo_texture = preload("res://assets/textures/rock.png")
	_disc_material.albedo_color = Color(0.62, 0.6, 0.55)
	_disc_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_disc_material.uv1_triplanar = true
	_disc_material.uv1_scale = Vector3.ONE * 8.0
	_selected_material = _disc_material.duplicate()
	_selected_material.albedo_color = Color(0.85, 0.82, 0.72)
	for i in 4:
		var disc := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.06
		cylinder.bottom_radius = 0.065
		cylinder.height = 0.04
		cylinder.radial_segments = 10
		cylinder.rings = 1
		disc.mesh = cylinder
		disc.material_override = _disc_material
		disc.rotation.x = PI * 0.5
		# Da esquerda para a direita de quem olha a porta: lê-se como o código.
		disc.position = DISCS_AT + Vector3((i - 1.5) * DISC_SPACING, 0.0, 0.0)
		add_child(disc)
		_discs.append(disc)
		var label := Label3D.new()
		label.font_size = 40
		label.pixel_size = 0.0022
		label.modulate = Color(0.12, 0.1, 0.08)
		label.outline_size = 0
		label.shaded = true
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.position = Vector3(disc.position.x, disc.position.y, disc.position.z + 0.022)
		add_child(label)
		_labels.append(label)
	_refresh()
	add_to_group(&"interactable")
	Story.changed.connect(_sync_open)
	_sync_open()


func interaction_prompt() -> String:
	return "" if is_open or _active else "Girar os discos de pedra"


## Sem animação: o goblin só chega perto e põe a mão.
func interaction_action() -> Dictionary:
	return {"action": &"keypad", "duration": 0.05, "at": 0.0}


func interact(player: Node) -> void:
	_active = true
	(player as Player).set_controls_enabled(false)
	_refresh()
	if Watchers.watching(_discs[1].global_position):
		Story.crow_saw_keypad()
	# O Player limpa o texto da ação no frame seguinte; a dica entra depois dele.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_show_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not event.is_pressed() or event.is_echo():
		return
	var wheel := event as InputEventMouseButton
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_select(selected - 1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_select(selected + 1)
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up") or (wheel != null and wheel.button_index == MOUSE_BUTTON_WHEEL_UP):
		_turn(1)
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down") or (wheel != null and wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_turn(-1)
	elif event.is_action_pressed("interact"):
		_push()
	elif event.is_action_pressed("jump"):
		_leave()
	else:
		return
	get_viewport().set_input_as_handled()


func code() -> String:
	return "".join(digits.map(func(d: int) -> String: return str(d)))


## Para testes: põe os discos num código.
func set_code(text: String) -> void:
	for i in 4:
		digits[i] = int(text[i])
	_refresh()


func _select(index: int) -> void:
	selected = posmod(index, 4)
	_click()
	_refresh()


func _turn(step: int) -> void:
	digits[selected] = posmod(digits[selected] + step, 10)
	_click()
	_refresh()


## Empurra os discos: com o código certo (e Ari já sabendo da ruína), a laje desce.
func _push() -> void:
	_click()
	if not Story.has_flag(StoryBeats.DOOR_FLAG):
		Events.notification_shown.emit("Os discos giram, mas não travam em nada.")
	elif code() == StoryBeats.DOOR_CODE:
		open()
	else:
		Events.notification_shown.emit("Os discos voltam com um estalo.")


func _leave() -> void:
	_active = false
	_refresh()
	Events.prompt_changed.emit("")
	if Game.player != null:
		Game.player.set_controls_enabled(true)


## Abre a porta: a laje desce no chão em Tuning.RUIN_DOOR_OPEN_TIME.
func open() -> void:
	if is_open:
		return
	is_open = true
	if _active:
		_leave()
	Story.set_flag(OPEN_FLAG)
	OccludedAudio.play_at(get_parent(), DOOR_SOUND, global_position + Vector3.UP * 0.9, &"World", 0.0, 6.0)
	var tween := create_tween()
	tween.tween_property(_slab, "position:y", -_height * 0.5 + 0.02, Tuning.RUIN_DOOR_OPEN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _body.process_mode = Node.PROCESS_MODE_DISABLED)


## Carregou um save com a porta aberta (ou fechada): põe a laje no lugar, sem cena.
func _sync_open() -> void:
	if Story.has_flag(OPEN_FLAG) and not is_open:
		is_open = true
		_slab.position.y = -_height * 0.5 + 0.02
		_body.process_mode = Node.PROCESS_MODE_DISABLED
	elif not Story.has_flag(OPEN_FLAG) and is_open:
		is_open = false
		_slab.position.y = _height * 0.5
		_body.process_mode = Node.PROCESS_MODE_INHERIT


## Os discos são pequenos para ler de longe: a dica mostra os números, o escolhido entre [ ].
func _show_hint() -> void:
	if not _active:
		return
	var shown := PackedStringArray()
	for i in 4:
		shown.append("[%d]" % digits[i] if i == selected else " %d " % digits[i])
	Events.prompt_changed.emit(HINT % " ".join(shown))


func _refresh() -> void:
	for i in 4:
		_labels[i].text = str(digits[i])
		# O disco escolhido gira um pouco para a frente, como se estivesse na mão.
		_discs[i].material_override = _selected_material if _active and i == selected else _disc_material
		_discs[i].position.z = DISCS_AT.z + (0.012 if _active and i == selected else 0.0)
		_labels[i].position.z = _discs[i].position.z + 0.022
	_show_hint()


func _click() -> void:
	OccludedAudio.play_at(get_parent(), CLICK_SOUNDS.pick_random(), _discs[selected].global_position, &"World", -6.0, 2.0, randf_range(0.9, 1.1))
