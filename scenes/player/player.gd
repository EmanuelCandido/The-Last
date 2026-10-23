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
## Camadas que a mira e as flechas enxergam: mundo, árvores e bichos.
const AIM_MASK := 1 | 2 | 8
## A câmera só bate no mundo (terreno, caverna, pedras): tronco fino na frente não a empurra.
const CAMERA_MASK := 1
## Raio da esfera que testa o caminho da câmera (folga entre a lente e a rocha).
const CAMERA_RADIUS := 0.22
## Segundos para tirar outra flecha da aljava e encaixar na corda depois de atirar.
const RELOAD_TIME := 0.75
## Arco carregado: deitado para a frente, a ponta de cima CARRY_RISE (rad) acima da
## horizontal; balança com o antebraço (CARRY_SWING da diferença), como um pau no punho.
const CARRY_RISE := 0.45
const CARRY_SWING := 0.4
## Mirando, o arco deita um pouco (topo para a direita), como o de um arqueiro destro.
const BOW_CANT := 0.15
## Raio em volta do corpo onde se procura o vazio na borda (m).
const EDGE_PROBE := 0.32
## Ação padrão para interagir com algo que não diz a sua (interaction_action): abaixar e pegar.
const DEFAULT_INTERACTION := {"action": &"pickup", "duration": 1.1, "at": 0.5}

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
## Distância da câmera atrás do ombro.
@export var camera_distance := 3.0
## Deslocamento para a direita (câmera sobre o ombro).
@export var shoulder_offset := 0.45

@export_group("Arco")
## Segundos para puxar a corda até o fim.
@export var draw_time := 0.9
@export var interact_distance := 1.8

## Mirando com o arco (botão direito).
var aiming := false
## Quanto a corda está puxada (0..1).
var draw := 0.0

## Estados que as partes (scenes/player/parts/) ligam e o corpo mostra.
## Farejando (SniffAbility): agachado, parado, sem barulho.
var sniffing := false
## Prendendo o ar (BreathControl): a respiração para e o arco não treme.
var breath_held := false
## Com a tocha acesa na mão (TorchCarry).
var torch_held := false
## Deitado (no sarcófago): parado, sem física, e o lugar conta para o ritual (§4.9).
var lying := false
## Lugar de ritual em que o goblin está deitado (&"" = nenhum).
var ritual_place := &""
## Multiplicadores que as partes põem nos sentidos dos bichos, por nome (ex.: &"mud": 0.65).
## Tirar a chave tira o efeito.
var visibility_factors := {}
var noise_factors := {}
var scent_factors := {}

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
## Para onde o corpo vira. O giro é feito em _process (a cada frame desenhado), não na
## física: a 60 Hz de física e 120 de tela o corpo girava em degraus e a inclinação da
## curva piscava entre dois valores, desenhando o goblin "duplo".
var _target_yaw := 0.0
var _interaction: Node3D
## A interação mais próxima pode ser feita agora (senão só mostra o texto, sem [E]).
var _interaction_ready := false
var _tree_target := -1
var _prompt := ""
var _pine_warning_cooldown := 0.0
var _bow: Node3D
## Tempo que falta para a próxima flecha estar na corda.
var _reload := 0.0
## Equilíbrio na borda (1 firme .. 0 cai) e quanto tempo ainda tomba para fora.
var _balance := 1.0
var _tipping := 0.0
var _edge_dir := Vector3.ZERO
var _floor_snap := 0.0
var _quiver: Node3D
var _draw_sound: AudioStreamPlayer3D
var _camera_rest := {}
var _camera_length := 0.0
var _camera_shoulder := 0.0
## Comprimento real do braço depois das colisões (encolhe na hora, volta devagar).
var _arm_length := 0.0
var _camera_probe := SphereShape3D.new()
var _model_fade := 0.0

@onready var _visual: Node3D = $Visual
@onready var _model: Node3D = $Visual/Goblin
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera_arm: Node3D = $CameraPivot/CameraArm
@onready var _camera: Camera3D = $CameraPivot/CameraArm/Camera3D
@onready var _footsteps: Footsteps = $Footsteps


func _ready() -> void:
	_spawn_transform = global_transform
	_floor_snap = floor_snap_length
	_camera_probe.radius = CAMERA_RADIUS
	_camera_length = camera_distance
	_camera_shoulder = shoulder_offset
	_arm_length = camera_distance
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
		_animator.body = self
		_animator.foot_planted.connect(func(_side: int) -> void: _footsteps.play_step())
		_footsteps.driven_by_animation = true
	_last_yaw = _visual.rotation.y
	_target_yaw = _visual.rotation.y
	_camera_rest = {"fov": _camera.fov, "pivot": _camera_pivot.position.y}
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
	if event.is_action_pressed("interact") and _interaction != null and _interaction_ready:
		_start_interaction(_interaction)
	elif event.is_action_pressed("attack") and not aiming:
		_punch()


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * gamepad_look_speed * delta, -look.y * gamepad_look_speed * delta)
	if lying:
		velocity = Vector3.ZERO
		_update_interaction()
		return

	var free := _can_act()
	_crouching = free and (Input.is_action_pressed("crouch") or sniffing)
	aiming = free and not sniffing and Inventory.has(&"bow") and Input.is_action_pressed("aim")

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
	if _tipping > 0.0:
		# Perdeu o equilíbrio: o corpo vai para o vazio e o controle não segura.
		_tipping -= delta
		target = _edge_dir * 1.8
		direction = Vector3.ZERO
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var weight := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)

	move_and_slide()
	_update_balance(delta, direction)

	if not aiming and direction.length_squared() > 0.01:
		_target_yaw = atan2(direction.x, direction.z)

	if is_on_floor() and not _was_on_floor:
		if _animator != null:
			_animator.notify_landing(_fall_speed)
		if _fall_speed > Tuning.FALL_DAMAGE_SPEED:
			Vitals.damage((_fall_speed - Tuning.FALL_DAMAGE_SPEED) * Tuning.FALL_DAMAGE_PER_MS, &"fall")
	if is_on_floor():
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()

	_update_bow(delta)
	_update_interaction()

	if global_position.y < fall_limit:
		respawn()


func _process(delta: float) -> void:
	_pine_warning_cooldown -= delta
	if aiming:
		# Mirando, o goblin olha para onde a câmera aponta.
		_target_yaw = _camera_pivot.rotation.y + PI
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _target_yaw, 1.0 - exp(-(14.0 if aiming else turn_speed) * delta))
	_update_camera(delta)
	if _animator != null:
		_animator.velocity_local = _visual.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
		_animator.on_floor = is_on_floor()
		_animator.crouching = _crouching
		_animator.aiming = aiming
		_animator.starving = Vitals.is_starving()
		_animator.shiver = smoothstep(Tuning.COLD_SHIVER, 90.0, Vitals.cold)
		_animator.sniffing = sniffing
		_animator.breath_held = breath_held
		_animator.holding_torch = torch_held
		_animator.lying = lying
		_animator.draw = draw
		_animator.reload = clampf(_reload / RELOAD_TIME, 0.0, 1.0)
		_animator.aim_pitch = _camera_arm.rotation.x
		_animator.aim_point = _aim_point() if aiming or _animator.aim_weight() > 0.001 else Vector3.INF
		_animator.nock_depth = HeldBow.nock_depth(draw)
		if _quiver != null:
			_animator.quiver_top = _skeleton.global_transform.affine_inverse() * (_quiver.global_transform * Vector3(0.0, 0.22, 0.0))
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


## Deita de costas em `at`, com os pés para `yaw`. `place` é o lugar de ritual (ou &"").
func lie_at(at: Vector3, yaw: float, place := &"") -> void:
	_controls_enabled = false
	lying = true
	ritual_place = place
	global_position = at
	velocity = Vector3.ZERO
	_visual.rotation.y = yaw
	_target_yaw = yaw


## Levanta (senta, apoia e fica de pé) já fora de onde estava deitado, em `at`.
func get_up(at: Vector3) -> void:
	lying = false
	ritual_place = &""
	global_position = at
	velocity = Vector3.ZERO
	if _animator == null:
		_controls_enabled = true
		return
	_animator.play_action(&"wake", 5.8, [[5.5, func() -> void: _controls_enabled = true]], 2.6)


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO


## Liga ou desliga o controle do jogador (dormindo, cenas). A câmera continua livre.
func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled


## Livre para fazer uma ação agora (usado pelas partes em scenes/player/parts/).
func can_act() -> bool:
	return _can_act()


## Faz uma ação cronometrada do corpo (ver GoblinAnimator.play_action). Sem animador,
## os eventos acontecem na hora.
func perform(action: StringName, duration: float, events: Array = []) -> void:
	velocity = Vector3(0.0, velocity.y, 0.0)
	if _animator == null:
		for event: Array in events:
			(event[1] as Callable).call()
		return
	_animator.play_action(action, duration, events)


## Põe algo na mão direita por `seconds` segundos (a carne ao comer e ao assar).
func hold_in_hand(item: Node3D, seconds: float) -> Node3D:
	_attach_node(item, "braco_D*mao")
	get_tree().create_timer(seconds, false).timeout.connect(item.queue_free)
	return item


## Põe `item` preso à mão (direita ou esquerda) até alguém tirar. Devolve o item.
func attach_to_hand(item: Node3D, right := true) -> Node3D:
	return _attach_node(item, "braco_D*mao" if right else "braco_E*mao")


## Nó que acompanha a mão direita (ou a esquerda), para quem segue a mão sem ser filho dela.
func hand_socket(right := true) -> Node3D:
	var socket := _model.find_child("braco_D*mao" if right else "braco_E*mao", true, false) as Node3D
	return socket if socket != null else _visual


func skeleton() -> Skeleton3D:
	return _skeleton


## Para onde o corpo está virado (direção no chão, no mundo).
func facing() -> Vector3:
	var forward := _visual.global_basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


## Para onde a câmera aponta (direção no mundo).
func aim_direction() -> Vector3:
	return -_camera.global_basis.z


## Vira o corpo para `direction` na hora (só o giro no chão conta).
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	_visual.rotation.y = atan2(direction.x, direction.z)
	_target_yaw = _visual.rotation.y


## Cansa o corpo (0..1): ofega parado, respira alto e a mira treme até passar.
func exert(amount: float) -> void:
	if _animator != null:
		_animator.add_exertion(amount)


func is_crouching() -> bool:
	return _crouching


## Barulho que o goblin faz agora (0 parado .. 1 correndo). Os bichos ouvem isso.
## Parado e ofegante, a respiração se ouve; prendendo o ar, não.
func noise_level() -> float:
	if not is_on_floor():
		return 0.0
	var speed := Vector2(velocity.x, velocity.z).length()
	var noise := 0.0
	if speed >= 0.3:
		noise = 0.1 if _crouching else clampf(speed / sprint_speed, 0.3, 1.0)
	elif not breath_held and _animator != null:
		noise = _animator.exertion() * Tuning.PANTING_NOISE
	return noise * _product(noise_factors)


## Quão fácil é ver o goblin (0..1): agachado e parado no capim quase some.
func visibility() -> float:
	var value := 0.45 if _crouching else 1.0
	var level := Game.current_level
	if level != null and level.has_method("cover_at"):
		value *= 1.0 - float(level.cover_at(global_position)) * (1.0 if _crouching else 0.4)
	if Vector2(velocity.x, velocity.z).length() < 0.3:
		value *= 0.6
	return value * lerpf(1.0, Tuning.NIGHT_VISIBILITY, Clock.night()) * _product(visibility_factors)


## Quanto o cheiro do goblin vai longe (1 = normal). Os bichos multiplicam o faro por isto.
func scent_level() -> float:
	return _product(scent_factors)


static func _product(factors: Dictionary) -> float:
	var value := 1.0
	for key: Variant in factors:
		value *= float(factors[key])
	return value


## Aponta a câmera (graus). Yaw 0 olha para -Z.
func set_camera_angles(yaw_deg: float, pitch_deg: float) -> void:
	_camera_pivot.rotation.y = deg_to_rad(yaw_deg)
	_camera_arm.rotation.x = clampf(deg_to_rad(pitch_deg), deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


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
	_target_yaw = _visual.rotation.y


## Equilíbrio na borda. Com o centro do corpo além da borda (sem chão logo embaixo),
## o goblin se desequilibra: o equilíbrio cai mais rápido se ele anda para o vazio ou
## está com um pé solto, e volta se ele andar para dentro ou se agachar. Se acabar,
## ele tomba para o lado do vazio.
func _update_balance(delta: float, direction: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var over_edge := false
	if is_on_floor() and _tipping <= 0.0:
		over_edge = _ground_below(space, global_position, 0.25) == false
	if not over_edge:
		_balance = move_toward(_balance, 1.0, delta * 0.8)
		if is_on_floor():
			_tipping = 0.0
			floor_snap_length = _floor_snap
		_set_teeter(move_toward(_animator.teeter if _animator != null else 0.0, 0.0, delta * (1.0 if not is_on_floor() else 3.0)))
		return
	# Para onde fica o vazio: soma das direções em volta sem chão.
	var void_dir := Vector3.ZERO
	for i in 8:
		var offset := Vector3(cos(TAU * i / 8.0), 0.0, sin(TAU * i / 8.0)) * EDGE_PROBE
		if not _ground_below(space, global_position + offset, 0.35):
			void_dir += offset
	if void_dir.length_squared() < 0.0001:
		void_dir = Vector3(get_floor_normal().x, 0.0, get_floor_normal().z)
	_edge_dir = void_dir.normalized() if void_dir.length_squared() > 0.0001 else -_visual.global_basis.z
	var instability := 0.55
	if _animator != null:
		var loose := int(not _animator.foot_supported[0]) + int(not _animator.foot_supported[1])
		# Os dois pés no vazio: não há em que se segurar.
		instability += 2.5 if loose == 2 else 0.2 * loose
	if Vector2(velocity.x, velocity.z).dot(Vector2(_edge_dir.x, _edge_dir.z)) > 0.2:
		instability += 0.5
	if direction.dot(-_edge_dir) > 0.3:
		instability -= 0.9
	if _crouching:
		instability -= 0.35
	_balance = clampf(_balance - instability * delta * 0.6, 0.0, 1.0)
	_set_teeter(0.55 + 0.45 * (1.0 - _balance))
	if _balance <= 0.0:
		_tipping = 0.6
		floor_snap_length = 0.0
		velocity += _edge_dir * 1.2 + Vector3.UP * 0.8


func _ground_below(space: PhysicsDirectSpaceState3D, at: Vector3, depth: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * depth, 1, [get_rid()])
	return not space.intersect_ray(query).is_empty()


func _set_teeter(amount: float) -> void:
	if _animator == null:
		return
	_animator.teeter = amount
	var local := _visual.global_basis.inverse() * _edge_dir
	_animator.teeter_dir = Vector2(local.x, local.z).normalized() if amount > 0.0 else Vector2.ZERO


## Livre para agir: controles ligados e nenhuma ação (pegar, coletar) em andamento.
## O golpe não trava o goblin.
func _can_act() -> bool:
	return _controls_enabled and (_animator == null or not _animator.is_busy() or _punching)


func _current_speed() -> float:
	if sniffing:
		return 0.0
	if aiming:
		return aim_speed
	if _crouching:
		return crouch_speed
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed


# --- Arco ------------------------------------------------------------------------

func _update_bow(delta: float) -> void:
	if _reload > 0.0:
		_reload -= delta
		if _reload <= 0.0 and aiming and _arrow_item() != &"":
			OccludedAudio.play_at(self, BOW_NOCK_SOUNDS.pick_random(), global_position + Vector3.UP * 0.7, &"World", -4.0, 2.5)
	if not aiming:
		_was_aiming = false
		if draw > 0.0:
			draw = 0.0
			_draw_sound.stop()
		return
	if not _was_aiming:
		_was_aiming = true
		# Ao erguer o arco, o goblin encaixa uma flecha na corda.
		if _arrow_item() != &"" and _reload <= 0.0:
			OccludedAudio.play_at(self, BOW_NOCK_SOUNDS.pick_random(), global_position + Vector3.UP * 0.7, &"World", -4.0, 2.5)
	if Input.is_action_pressed("attack") and _arrow_nocked():
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
	elif Input.is_action_just_pressed("attack") and _arrow_item() == &"":
		Events.notification_shown.emit("Sem flechas. Aperte R e faça flechas com madeira.")


func _arrow_nocked() -> bool:
	return _reload <= 0.0 and _arrow_item() != &""


## A flecha que vai na corda: a emplumada primeiro, depois a comum; vazio = nenhuma.
func _arrow_item() -> StringName:
	for item: StringName in [&"feathered_arrow", &"arrow"]:
		if Inventory.has(item):
			return item
	return &""


func _shoot() -> void:
	var item := _arrow_item()
	if item == &"" or not Inventory.remove(item):
		return
	_reload = RELOAD_TIME
	# A flecha sai de onde está na corda, no arco, e vai para o centro da tela.
	var origin := _bow.global_position
	var arrow := Arrow.new()
	arrow.item = item
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
		# O arco é posto na mão por código a cada frame (_orient_gear), sem socket: a mão da
		# corda é levada até ele no mesmo frame, então não pode haver atraso de um frame.
		_bow = HeldBow.new()
		_visual.add_child(_bow)
		_quiver = _attach(BowMesh.build_quiver(), "tronco*tras")
		# Na diagonal das costas (boca sobre o ombro direito); acompanha o giro do tronco.
		_quiver.basis = Basis(Vector3.BACK, 0.35) * Basis(Vector3.RIGHT, -0.2)
		if _animator != null:
			var grip := _model.find_child("braco_E*mao", true, false) as Node3D
			if grip != null:
				_animator.bow_grip = grip.transform.origin
	if _bow != null:
		_bow.visible = has_bow
		_quiver.visible = has_bow


## Arco na mão esquerda: carregado, passa pelo punho como um pau e balança com o braço;
## mirando, fica em pé (um pouco deitado) com a barriga para o alvo. A corda vai até onde o
## animador levou a mão direita.
func _orient_gear() -> void:
	if _bow == null or not _bow.visible:
		return
	if _bow is HeldBow and _animator != null:
		var side := _visual.global_basis.x
		var level := _visual.global_basis.z.rotated(side, -CARRY_RISE)
		var swung := (-_animator.forearm_direction(true)).rotated(side, PI * 0.5)
		var up := level.lerp(swung, CARRY_SWING).normalized()
		var belly := side.cross(up).normalized()
		up = belly.cross(side).normalized()
		var held := Basis(up.cross(belly), up, belly).get_rotation_quaternion()
		var grip := _animator.bow_grip_position()
		var weight := _animator.aim_weight()
		if weight > 0.001 and _animator.aim_point != Vector3.INF:
			var aimed := Basis.looking_at(_animator.aim_point - grip, Vector3.UP, true) * Basis(Vector3.BACK, BOW_CANT)
			held = held.slerp(aimed.get_rotation_quaternion(), weight)
		_bow.global_transform = Transform3D(Basis(held), grip)
		(_bow as HeldBow).pose_string(draw, aiming and _arrow_nocked())


func _attach(mesh: Mesh, socket_pattern: String) -> Node3D:
	var holder := MeshInstance3D.new()
	holder.mesh = mesh
	return _attach_node(holder, socket_pattern)


func _attach_node(node: Node3D, socket_pattern: String) -> Node3D:
	var socket := _model.find_child(socket_pattern, true, false) as Node3D
	(socket if socket != null else _visual).add_child(node)
	return node


# --- Interação: pegar coisas e quebrar árvore -------------------------------------

## Interagíveis (grupo "interactable") implementam:
##   interaction_prompt() -> String        texto da ação; vazio = nada a fazer agora
## e, se quiserem:
##   interaction_enabled() -> bool         false = só mostra o texto, sem [E] (ex.: falta algo)
##   interaction_action() -> Dictionary    {"action", "duration", "at"}: a animação e quando
##                                         interact() é chamado (padrão: DEFAULT_INTERACTION)
##   interaction_started(player)           chamado quando a animação começa
## Ganha o mais próximo que pode ser feito; se nenhum pode, o mais próximo com texto.
func _update_interaction() -> void:
	_interaction = null
	_interaction_ready = false
	_tree_target = -1
	var prompt := ""
	if _can_act():
		var best := interact_distance
		var best_ready := interact_distance
		var fallback: Node3D
		for node in get_tree().get_nodes_in_group(&"interactable"):
			var item := node as Node3D
			var distance := item.global_position.distance_to(global_position)
			if distance >= interact_distance or item.interaction_prompt() == "":
				continue
			var ready: bool = not item.has_method("interaction_enabled") or item.interaction_enabled()
			if ready and distance < best_ready:
				best_ready = distance
				_interaction = item
			elif not ready and distance < best:
				best = distance
				fallback = item
		_interaction_ready = _interaction != null
		if _interaction == null:
			_interaction = fallback
		if _interaction != null:
			prompt = ("[E] " if _interaction_ready else "") + _interaction.interaction_prompt()
		else:
			var level := Game.current_level
			if level != null and level.has_method("tree_near"):
				_tree_target = level.tree_near(global_position, 1.0)
				if _tree_target != -1:
					prompt = "[Clique] Golpear a árvore seca" if level.is_tree_dead(_tree_target) else "Pinheiro vivo: duro demais para quebrar"
	if prompt != _prompt:
		_prompt = prompt
		Events.prompt_changed.emit(prompt)


## Vira para o item e faz a ação dele: o item só reage quando a mão chega nele.
func _start_interaction(item: Node3D) -> void:
	var to_item := item.global_position - global_position
	_visual.rotation.y = atan2(to_item.x, to_item.z)
	_target_yaw = _visual.rotation.y
	var spec: Dictionary = item.interaction_action() if item.has_method("interaction_action") else DEFAULT_INTERACTION
	var grab := func() -> void:
		if is_instance_valid(item):
			item.interact(self)
	if item.has_method("interaction_started"):
		item.interaction_started(self)
	perform(spec.action, spec.duration, [[spec.at, grab]])


func _punch() -> void:
	if _animator == null:
		_land_punch()
		return
	if _animator.is_busy():
		return
	_punching = true
	_animator.play_action(&"punch", 0.5, [[0.24, _land_punch], [0.5, func() -> void: _punching = false]])


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
	_camera_length = lerpf(_camera_length, 1.5 if aiming else camera_distance, weight)
	_camera_shoulder = lerpf(_camera_shoulder, 0.6 if aiming else shoulder_offset, weight)
	_camera.fov = lerpf(_camera.fov, 50.0 - draw * 6.0 if aiming else _camera_rest.fov, weight)
	_camera_pivot.position.y = lerpf(_camera_pivot.position.y, _camera_rest.pivot - (0.25 if _crouching else 0.0), weight)
	_place_camera(delta)


## Câmera sobre o ombro que não atravessa rocha. Uma esfera vai do pivô (nuca) até o
## ombro e de lá para trás; onde ela bater, a câmera para. Ao bater, encolhe na hora
## (nunca mostra o outro lado da parede); quando o caminho abre, volta devagar.
func _place_camera(delta: float) -> void:
	var arm := _camera_arm.global_transform
	var side := arm.basis.x * _camera_shoulder
	var shoulder := arm.origin + side * _sweep(arm.origin, side)
	var back := arm.basis.z * _camera_length
	var free_length := _camera_length * _sweep(shoulder, back)
	if free_length < _arm_length:
		_arm_length = free_length
	else:
		_arm_length = lerpf(_arm_length, free_length, 1.0 - exp(-3.0 * delta))
	_camera.global_position = shoulder + arm.basis.z * _arm_length
	_fade_model()


## Fração livre (0..1) do movimento da esfera da câmera de `from` até `from + motion`.
func _sweep(from: Vector3, motion: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _camera_probe
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.collision_mask = CAMERA_MASK
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return result[0]


## Com a câmera espremida contra a parede, o goblin fica transparente em vez de a
## lente entrar na cabeça dele. Colado na lente, some de vez (o brilho dos olhos
## continuaria boiando na tela).
func _fade_model() -> void:
	var distance := _camera.global_position.distance_to(_visual.global_position + Vector3.UP * 0.7)
	var fade := 1.0 if distance < 0.6 else (1.0 - smoothstep(0.6, 1.3, distance)) * 0.8
	if absf(fade - _model_fade) < 0.02 and not (fade == 0.0 and _model_fade > 0.0):
		return
	_model_fade = fade
	for node in _visual.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		geometry.visible = fade < 1.0
		geometry.transparency = fade if fade < 1.0 else 0.0


func _rotate_camera(yaw: float, pitch: float) -> void:
	_camera_pivot.rotate_y(yaw)
	_camera_arm.rotation.x = clampf(
		_camera_arm.rotation.x + pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg)
	)
