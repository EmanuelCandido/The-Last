class_name Player
extends CharacterBody3D
## Goblin em terceira pessoa: anda, corre, agacha, pula, pega coisas, atira com o
## arco e golpeia árvores secas. Acorda deitado na primeira cena.
##
## Só o nó Visual gira para a direção do movimento; o corpo de física fica parado
## em Y para a câmera não girar junto. O modelo olha para +Z (MODEL_FRONT do Godot).
## Toda a animação do corpo é procedural (GoblinAnimator): este script só informa o
## estado (velocidade, chão, agachado, mira) e dispara as ações (golpe, pegar, acordar).

# Gravações reais: arco longo e recurvo (OpenGameArt, CC0); faca na madeira (Kenney, CC0).
const BOW_NOCK_SOUNDS := [preload("res://assets/audio/real/bow_nock_1.wav"), preload("res://assets/audio/real/bow_nock_2.wav")]
const BOW_DRAW_SOUNDS := [
	preload("res://assets/audio/real/bow_draw_1.wav"), preload("res://assets/audio/real/bow_draw_2.wav"),
	preload("res://assets/audio/real/bow_draw_3.wav"),
]
const BOW_RELEASE_SOUNDS := [
	preload("res://assets/audio/real/bow_release_1.wav"), preload("res://assets/audio/real/bow_release_2.wav"),
	preload("res://assets/audio/real/bow_release_3.wav"), preload("res://assets/audio/real/bow_release_4.wav"),
	preload("res://assets/audio/real/bow_release_5.wav"),
]
const CRAFT_SOUNDS := [
	preload("res://assets/audio/real/craft_1.ogg"), preload("res://assets/audio/real/craft_2.ogg"),
	preload("res://assets/audio/real/craft_3.ogg"),
]
## Camadas que a mira e as flechas enxergam: mundo, árvores e bichos.
const AIM_MASK := 1 | 2 | 8
## Flechas feitas com 1 madeira.
const ARROWS_PER_WOOD := 3

@export_group("Movimento")
@export var walk_speed := 2.6
@export var sprint_speed := 5.0
@export var crouch_speed := 1.2
@export var aim_speed := 1.4
## Quão rápido a velocidade chega no alvo (maior = mais responsivo).
@export var acceleration := 9.0
## Fração da aceleração disponível no ar.
@export_range(0.0, 1.0) var air_control := 0.3
@export var jump_velocity := 4.6
@export var turn_speed := 10.0
## Abaixo desta altura o jogador volta para o ponto de nascimento.
@export var fall_limit := -60.0

@export_group("Câmera")
@export var mouse_sensitivity := 0.0025
@export var gamepad_look_speed := 3.0
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 35.0

@export_group("Arco")
## Segundos para puxar a corda até o fim.
@export var draw_time := 0.9
@export var interact_distance := 1.8

## Mirando com o arco (botão direito).
var aiming := false
## Quanto a corda está puxada (0..1).
var draw := 0.0

var _spawn_transform: Transform3D
var _controls_enabled := true
var _crouching := false
var _skeleton: Skeleton3D
var _animator: GoblinAnimator
var _punching := false
var _was_aiming := false
var _was_on_floor := true
var _fall_speed := 0.0
var _last_yaw := 0.0
var _interaction: Node3D
var _tree_target := -1
var _prompt := ""
var _pine_warning_cooldown := 0.0
var _bow: Node3D
var _quiver: Node3D
var _draw_sound: AudioStreamPlayer3D
var _camera_rest := {}

@onready var _visual: Node3D = $Visual
@onready var _model: Node3D = $Visual/Goblin
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var _camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var _footsteps: Footsteps = $Footsteps


func _ready() -> void:
	_spawn_transform = global_transform
	_spring_arm.add_excluded_object(get_rid())
	GoblinLook.apply(_model)
	# As animações do kit ficam paradas: o corpo é animado por código.
	var player := _model.find_child("AnimationPlayer") as AnimationPlayer
	if player != null:
		player.stop()
	_skeleton = _model.find_child("Skeleton3D") as Skeleton3D
	_animator = GoblinAnimator.new()
	add_child(_animator)
	if _skeleton == null or not _animator.setup(_skeleton):
		_animator.queue_free()
		_animator = null
	else:
		_animator.foot_planted.connect(func(_side: int) -> void: _footsteps.play_step())
		_footsteps.driven_by_animation = true
	_last_yaw = _visual.rotation.y
	_camera_rest = {"length": _spring_arm.spring_length, "offset": _camera.h_offset, "fov": _camera.fov, "pivot": _camera_pivot.position.y}
	_draw_sound = AudioStreamPlayer3D.new()
	_draw_sound.bus = &"World"
	_draw_sound.unit_size = 3.0
	_draw_sound.position = Vector3.UP * 0.7
	add_child(_draw_sound)
	Inventory.changed.connect(_on_inventory_changed)
	_update_gear()
	# Limpa a dica de ação deixada por um jogador anterior (troca de fase).
	Events.prompt_changed.emit("")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := mouse_sensitivity * (0.6 if aiming else 1.0)
		_rotate_camera(-motion.relative.x * sensitivity, -motion.relative.y * sensitivity)
	if not _can_act():
		return
	if event.is_action_pressed("interact") and _interaction != null:
		_start_interaction(_interaction)
	elif event.is_action_pressed("craft"):
		_craft_arrows()
	elif event.is_action_pressed("attack") and not aiming:
		_punch()


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * gamepad_look_speed * delta, -look.y * gamepad_look_speed * delta)

	var free := _can_act()
	_crouching = free and Input.is_action_pressed("crouch")
	aiming = free and Inventory.has(&"bow") and Input.is_action_pressed("aim")

	if is_on_floor():
		if free and Input.is_action_just_pressed("jump") and not _crouching:
			velocity.y = jump_velocity
	else:
		velocity += get_gravity() * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if free else Vector2.ZERO
	# O pivô só gira em Y, então a direção já sai no plano horizontal.
	var direction := _camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)
	var target := direction * _current_speed()
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var weight := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	move_and_slide()

	if aiming:
		# Mirando, o goblin olha para onde a câmera aponta.
		_visual.rotation.y = lerp_angle(_visual.rotation.y, _camera_pivot.rotation.y + PI, 1.0 - exp(-14.0 * delta))
	elif direction.length_squared() > 0.01:
		var target_yaw := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	if is_on_floor() and not _was_on_floor and _animator != null:
		_animator.notify_landing(_fall_speed)
	if is_on_floor():
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()

	_update_bow(delta)
	_update_interaction()

	if global_position.y < fall_limit:
		respawn()


func _process(delta: float) -> void:
	_pine_warning_cooldown -= delta
	_update_camera(delta)
	if _animator != null:
		_animator.velocity_local = _visual.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
		_animator.on_floor = is_on_floor()
		_animator.crouching = _crouching
		_animator.aiming = aiming
		_animator.draw = draw
		_animator.aim_pitch = _spring_arm.rotation.x
		_animator.turn_rate = angle_difference(_last_yaw, _visual.rotation.y) / maxf(delta, 0.001)
		_last_yaw = _visual.rotation.y
		_animator.update(delta)
	_orient_gear()


## Cena de despertar: começa deitado, senta, esfrega os olhos e levanta.
func wake_up() -> void:
	_controls_enabled = false
	if _animator == null:
		_controls_enabled = true
		return
	_animator.play_action(&"wake", 5.8, [[5.5, func() -> void: _controls_enabled = true]])


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO


func is_crouching() -> bool:
	return _crouching


## Barulho que o goblin faz agora (0 parado .. 1 correndo). Os bichos ouvem isso.
func noise_level() -> float:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.3 or not is_on_floor():
		return 0.0
	if _crouching:
		return 0.1
	return clampf(speed / sprint_speed, 0.3, 1.0)


## Quão fácil é ver o goblin (0..1): agachado e parado no capim quase some.
func visibility() -> float:
	var value := 0.45 if _crouching else 1.0
	var level := Game.current_level
	if level != null and level.has_method("cover_at"):
		value *= 1.0 - float(level.cover_at(global_position)) * (1.0 if _crouching else 0.4)
	if Vector2(velocity.x, velocity.z).length() < 0.3:
		value *= 0.6
	return value


## Aponta a câmera (graus). Yaw 0 olha para -Z.
func set_camera_angles(yaw_deg: float, pitch_deg: float) -> void:
	_camera_pivot.rotation.y = deg_to_rad(yaw_deg)
	_spring_arm.rotation.x = clampf(deg_to_rad(pitch_deg), deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": _visual.rotation.y,
	}


func load_data(data: Dictionary) -> void:
	var position_data: Array = data.get("position", [])
	if position_data.size() == 3:
		global_position = Vector3(position_data[0], position_data[1], position_data[2])
		velocity = Vector3.ZERO
	_visual.rotation.y = data.get("yaw", _visual.rotation.y)


## Livre para agir: controles ligados e nenhuma ação (pegar, coletar) em andamento.
## O golpe não trava o goblin.
func _can_act() -> bool:
	return _controls_enabled and (_animator == null or not _animator.is_busy() or _punching)


func _current_speed() -> float:
	if aiming:
		return aim_speed
	if _crouching:
		return crouch_speed
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed


# --- Arco ------------------------------------------------------------------------

func _update_bow(delta: float) -> void:
	if not aiming:
		_was_aiming = false
		if draw > 0.0:
			draw = 0.0
			_draw_sound.stop()
		return
	if not _was_aiming:
		_was_aiming = true
		# Ao erguer o arco, o goblin encaixa uma flecha na corda.
		if Inventory.has(&"arrow"):
			OccludedAudio.play_at(self, BOW_NOCK_SOUNDS.pick_random(), global_position + Vector3.UP * 0.7, &"World", -4.0, 2.5)
	if Input.is_action_pressed("attack") and Inventory.has(&"arrow"):
		if draw == 0.0:
			_draw_sound.stream = BOW_DRAW_SOUNDS.pick_random()
			_draw_sound.pitch_scale = 1.0 / draw_time
			_draw_sound.play()
		draw = minf(draw + delta / draw_time, 1.0)
	elif draw > 0.0:
		if draw > 0.15:
			_shoot()
		draw = 0.0
		_draw_sound.stop()
	elif Input.is_action_just_pressed("attack"):
		Events.notification_shown.emit("Sem flechas. Aperte R para fazer flechas com madeira.")


func _shoot() -> void:
	if not Inventory.remove(&"arrow"):
		return
	var origin := _visual.global_position + Vector3.UP * 0.75 + _camera.global_basis.x * 0.15
	var arrow := Arrow.new()
	Game.current_level.add_child(arrow)
	arrow.launch(origin, _aim_point() - origin, draw, [get_rid()])
	OccludedAudio.play_at(self, BOW_RELEASE_SOUNDS.pick_random(), origin, &"World", lerpf(-8.0, -1.0, draw), 4.0, randf_range(0.96, 1.04))
	Events.noise_made.emit(global_position, 10.0)


## Ponto do mundo no centro da tela (onde a mira aponta).
func _aim_point() -> Vector3:
	var from := _camera.global_position
	var to := from - _camera.global_basis.z * 300.0
	var query := PhysicsRayQueryParameters3D.create(from, to, AIM_MASK, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else to


func _on_inventory_changed(item: StringName, _amount: int) -> void:
	if item == &"bow" or item == &"arrow":
		_update_gear()


## Mostra o arco na mão e a aljava nas costas quando o goblin tem o arco.
func _update_gear() -> void:
	var has_bow := Inventory.has(&"bow")
	if has_bow and _bow == null:
		_bow = _attach(BowMesh.build_bow(), "braco_E*mao")
		_quiver = _attach(BowMesh.build_quiver(), "tronco*tras")
	if _bow != null:
		_bow.visible = has_bow
		_quiver.visible = has_bow


## Arco em pé na mão (mirando, a barriga aponta para o alvo); aljava na diagonal das costas.
func _orient_gear() -> void:
	if _bow == null or not _bow.visible:
		return
	if aiming:
		_bow.global_basis = _camera.global_basis * Basis(Vector3.UP, PI)
	else:
		_bow.global_basis = _visual.global_basis * Basis(Vector3.RIGHT, -0.25)
	_quiver.global_basis = _visual.global_basis * Basis(Vector3.BACK, 0.35) * Basis(Vector3.RIGHT, -0.2)


func _attach(mesh: Mesh, socket_pattern: String) -> Node3D:
	var holder := MeshInstance3D.new()
	holder.mesh = mesh
	var socket := _model.find_child(socket_pattern, true, false) as Node3D
	(socket if socket != null else _visual).add_child(holder)
	return holder


# --- Interação: pegar coisas, quebrar árvore, fazer flecha -----------------------

func _update_interaction() -> void:
	_interaction = null
	_tree_target = -1
	var prompt := ""
	if _can_act():
		var best := interact_distance
		for node in get_tree().get_nodes_in_group(&"interactable"):
			var item := node as Node3D
			var distance := item.global_position.distance_to(global_position)
			if distance < best and item.interaction_prompt() != "":
				best = distance
				_interaction = item
		if _interaction != null:
			prompt = "[E] " + _interaction.interaction_prompt()
		else:
			var level := Game.current_level
			if level != null and level.has_method("tree_near"):
				_tree_target = level.tree_near(global_position, 1.0)
				if _tree_target != -1:
					prompt = "[Clique] Golpear a árvore seca" if level.is_tree_dead(_tree_target) else "Pinheiro vivo: duro demais para quebrar"
	if prompt != _prompt:
		_prompt = prompt
		Events.prompt_changed.emit(prompt)


## Vira para o item, abaixa e pega: o item só é pego quando a mão chega nele.
func _start_interaction(item: Node3D) -> void:
	var to_item := item.global_position - global_position
	_visual.rotation.y = atan2(to_item.x, to_item.z)
	velocity = Vector3(0.0, velocity.y, 0.0)
	if _animator == null:
		item.interact(self)
		return
	var grab := func() -> void:
		if is_instance_valid(item):
			item.interact(self)
	if item is Animal:
		_animator.play_action(&"harvest", 2.4, [[1.9, grab]])
	else:
		_animator.play_action(&"pickup", 1.1, [[0.5, grab]])


func _punch() -> void:
	if _animator == null:
		_land_punch()
		return
	if _animator.is_busy():
		return
	_punching = true
	_animator.play_action(&"punch", 0.5, [[0.24, _land_punch], [0.5, func() -> void: _punching = false]])


func _craft_arrows() -> void:
	if not Inventory.remove(&"wood"):
		Events.notification_shown.emit("Precisa de madeira. Quebre árvores secas para conseguir.")
		return
	Inventory.add(&"arrow", ARROWS_PER_WOOD)
	OccludedAudio.play_at(self, CRAFT_SOUNDS.pick_random(), global_position + Vector3.UP * 0.6, &"World", -4.0, 3.0)
	Events.notification_shown.emit("+%d flechas" % ARROWS_PER_WOOD)


func _land_punch() -> void:
	var level := Game.current_level
	if level == null or not level.has_method("tree_near"):
		return
	var tree: int = level.tree_near(global_position, 1.0)
	if tree == -1:
		return
	if not level.is_tree_dead(tree):
		level.hit_tree(tree, global_position)
		if _pine_warning_cooldown <= 0.0:
			_pine_warning_cooldown = 4.0
			Events.notification_shown.emit("Pinheiro vivo é duro demais. Procure árvores secas, sem folhas.")
		return
	if level.hit_tree(tree, global_position):
		var wood := randi_range(2, 4)
		Inventory.add(&"wood", wood)
		Events.notification_shown.emit("A árvore caiu! +%d madeira" % wood)


# --- Câmera ----------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	var weight := 1.0 - exp(-10.0 * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, 1.5 if aiming else _camera_rest.length, weight)
	_camera.h_offset = lerpf(_camera.h_offset, 0.6 if aiming else _camera_rest.offset, weight)
	_camera.fov = lerpf(_camera.fov, 50.0 - draw * 6.0 if aiming else _camera_rest.fov, weight)
	_camera_pivot.position.y = lerpf(_camera_pivot.position.y, _camera_rest.pivot - (0.25 if _crouching else 0.0), weight)


func _rotate_camera(yaw: float, pitch: float) -> void:
	_camera_pivot.rotate_y(yaw)
	_spring_arm.rotation.x = clampf(
		_spring_arm.rotation.x + pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg)
	)
