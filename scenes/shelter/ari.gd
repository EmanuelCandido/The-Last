class_name Ari
extends CharacterBody3D
## Ari acordado no Abrigo (§6.2), em primeira pessoa. É o mesmo corpo do goblin: manca no
## mesmo ritmo (a perna direita segura o passo e a cabeça afunda nela) e ofega igual.
## Anda a ~0,9 m/s, Ctrl rasteja, Q prende o ar (até Tuning.ARI_BREATH_SECONDS; depois arfa
## alto), E mexe no que está no meio da tela. Sem pulo e sem corrida: a primeira vez que
## apertar Shift, "A perna não deixa."
##
## Montado por código. Quem cria é o Shelter (spawn_ari); quem liga o controle são as cenas
## de acordar (wake_in) e de deitar de volta (lie_down_in).

const BREATH_IN := preload("res://assets/audio/sfx/breath_in.wav")
const GASP := preload("res://assets/audio/sfx/gasp.wav")
const HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")
const MOUSE_SENSITIVITY := 0.0025
const PITCH_LIMIT := deg_to_rad(80.0)
## Olhos sentado na beira da cápsula, de lado (no espaço da cápsula).
const SITTING_EYE := Vector3(-0.4, 1.3, -0.4)

## A cabeça (gira com o mouse) e o olho.
var head: Node3D
var camera: Camera3D
## Controle ligado: desligado nas cenas de acordar e deitar.
var controls := false
var crawling := false
var breath_held := false
## Segundos com o ar preso agora.
var held_for := 0.0

var _yaw := 0.0
var _pitch := 0.0
## Fase da passada (0..1): na primeira metade o peso está na perna ruim.
var _phase := 0.0
var _eye := Tuning.ARI_EYE_HEIGHT
var _pant := 0.0
var _heart_timer := 0.0
var _time := 0.0
var _footsteps: Footsteps
var _heart: AudioStreamPlayer
var _interaction: Node3D
var _prompt := ""
var _turn_tween: Tween


func _init() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = _eye
	add_child(head)
	camera = Camera3D.new()
	# Ari vê um pouco mais aberto que a câmera do goblin (primeira pessoa).
	camera.fov = Settings.fov + 7.0
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"fov":
			camera.fov = Settings.fov + 7.0)
	camera.near = 0.03
	head.add_child(camera)
	_footsteps = Footsteps.new()
	_footsteps.driven_by_animation = true
	_footsteps.bus = &"Shelter"
	_footsteps.base_volume_db = -9.0
	add_child(_footsteps)
	# O coração e o ar são ouvidos por dentro: sem posição no mundo.
	_heart = AudioStreamPlayer.new()
	_heart.stream = HEARTBEAT
	_heart.bus = &"Shelter"
	add_child(_heart)


func _unhandled_input(event: InputEvent) -> void:
	if not controls:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := MOUSE_SENSITIVITY * Settings.mouse_sensitivity
		var vertical := -1.0 if Settings.invert_y else 1.0
		_yaw -= motion.relative.x * sensitivity
		_pitch = clampf(_pitch - motion.relative.y * sensitivity * vertical, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("interact") and _interaction != null:
		_interaction.interact(self)
	elif event.is_action_pressed("sprint") and not Story.has_flag(&"leg_warned"):
		Story.set_flag(&"leg_warned")
		Events.notification_shown.emit("A perna não deixa.")


func _physics_process(delta: float) -> void:
	_pant = maxf(_pant - delta, 0.0)
	if not is_on_floor():
		velocity += get_gravity() * delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls else Vector2.ZERO
	crawling = controls and Input.is_action_pressed("crouch")
	var direction := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	var speed := Tuning.ARI_CRAWL_SPEED if crawling else Tuning.ARI_WALK_SPEED * _limp()
	var weight := 1.0 - exp(-10.0 * delta)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)
	move_and_slide()
	_advance_gait(Vector2(velocity.x, velocity.z).length() * delta)
	_update_breath(delta)
	_update_interaction()


func _process(delta: float) -> void:
	_time += delta
	if head.top_level:
		return
	_eye = lerpf(_eye, Tuning.ARI_CRAWL_EYE if crawling else Tuning.ARI_EYE_HEIGHT, 1.0 - exp(-4.0 * delta))
	# O corpo manca: no passo da perna ruim a cabeça afunda e pende para a direita; no passo
	# bom, sobe um pouco. Parado, só a respiração (ofegante depois de arfar).
	var moving := clampf(Vector2(velocity.x, velocity.z).length() / 0.35, 0.0, 1.0) * (0.5 if crawling else 1.0)
	var dip := 0.0
	var roll := 0.0
	if _phase < 0.5:
		var u := sin(_phase / 0.5 * PI)
		dip = -0.055 * u
		roll = -0.035 * u
	else:
		var u := sin((_phase - 0.5) / 0.5 * PI)
		dip = 0.012 * u - 0.008
		roll = 0.01 * u
	var sway := -0.025 * sin(_phase * TAU)
	var breathing := sin(_time * (3.4 if _pant > 0.0 else 1.6)) * (0.02 if _pant > 0.0 else 0.005)
	head.position = Vector3(sway * moving, _eye + dip * moving + breathing, 0.0)
	head.rotation = Vector3(_pitch, _yaw, roll * moving)


func is_crouching() -> bool:
	return crawling


## O barulho de Ari agora (raio em m, para o Zelador da F6): arfando, andando ou rastejando.
func noise_level() -> float:
	if _pant > 0.0:
		return Tuning.ARI_NOISE_PANT
	if Vector2(velocity.x, velocity.z).length() < 0.1:
		return 0.0
	return Tuning.ARI_NOISE_CRAWL if crawling else Tuning.ARI_NOISE_WALK


## Cena de acordar: abre os olhos deitado, senta na beira da cápsula e fica de pé olhando
## para `face` (um ponto no mundo). A visão borrada clareia aos poucos.
func wake_in(capsule: CareCapsule, face: Vector3) -> void:
	controls = false
	var standing_eye := global_position + Vector3.UP * Tuning.ARI_EYE_HEIGHT
	var to_face := face - standing_eye
	to_face.y = 0.0
	var standing := Transform3D(Basis.looking_at(to_face.normalized(), Vector3.UP), standing_eye)
	var sitting := _sitting(capsule)
	var lying := _lying(capsule)
	head.top_level = true
	head.global_transform = lying
	var vision := Game.vision
	vision.amount = 1.0
	vision.lids = 1.0
	var tween := create_tween()
	tween.tween_property(vision, ^"lids", 0.45, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(vision, ^"lids", 0.9, 0.25)
	tween.tween_property(vision, ^"lids", 0.2, 0.6)
	tween.tween_method(_place_head.bind(lying, sitting), 0.0, 1.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.5)
	tween.tween_method(_place_head.bind(sitting, standing), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(vision, ^"lids", 0.0, 1.0)
	var blur := create_tween()
	blur.tween_property(vision, ^"amount", 0.0, Tuning.ARI_WAKE_BLUR_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	_take_head(standing)
	controls = true


## O contrário: senta na cápsula, deita e fecha os olhos.
func lie_down_in(capsule: CareCapsule) -> void:
	controls = false
	_clear_prompt()
	var lying := _lying(capsule)
	var sitting := _sitting(capsule)
	var from := head.global_transform
	head.top_level = true
	head.global_transform = from
	var vision := Game.vision
	var tween := create_tween()
	tween.tween_method(_place_head.bind(from, sitting), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_place_head.bind(sitting, lying), 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(vision, ^"lids", 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


## Liga já de pé, sem cena (DevTools --shelter e testes).
func stand_ready(face: Vector3) -> void:
	var standing_eye := global_position + Vector3.UP * Tuning.ARI_EYE_HEIGHT
	var to_face := face - standing_eye
	to_face.y = 0.0
	_take_head(Transform3D(Basis.looking_at(to_face.normalized(), Vector3.UP), standing_eye))
	controls = true


## Olha para `direction` (yaw e pitch; para testes e roteiros).
func look(direction: Vector3) -> void:
	_yaw = atan2(-direction.x, -direction.z)
	_pitch = asin(clampf(direction.normalized().y, -1.0, 1.0))


## Vira a cabeça devagar até olhar para `point` (no mundo), em `seconds` segundos (as cenas).
func turn_to(point: Vector3, seconds := 1.0) -> void:
	var direction := point - camera.global_position
	var yaw := atan2(-direction.x, -direction.z)
	var pitch := clampf(asin(clampf(direction.normalized().y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)
	var from := Vector2(_yaw, _pitch)
	var to := Vector2(from.x + angle_difference(from.x, yaw), pitch)
	if _turn_tween != null:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_method(func(view: Vector2) -> void:
		_yaw = view.x
		_pitch = view.y, from, to, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _place_head(weight: float, from: Transform3D, to: Transform3D) -> void:
	head.global_transform = from.interpolate_with(to, weight)


## Devolve a cabeça ao corpo, olhando para onde a cena terminou.
func _take_head(view: Transform3D) -> void:
	head.top_level = false
	var euler := view.basis.get_euler()
	_yaw = euler.y
	_pitch = clampf(euler.x, -PITCH_LIMIT, PITCH_LIMIT)
	head.position = Vector3(0.0, _eye, 0.0)
	head.rotation = Vector3(_pitch, _yaw, 0.0)


func _lying(capsule: CareCapsule) -> Transform3D:
	return Transform3D(Basis.looking_at(Vector3.UP, capsule.crown_direction()), capsule.eye_point())


func _sitting(capsule: CareCapsule) -> Transform3D:
	var out := -capsule.global_basis.z
	var forward := (out + Vector3.DOWN * 0.25).normalized()
	return Transform3D(Basis.looking_at(forward, Vector3.UP), capsule.global_transform * SITTING_EYE)


## Quanto da velocidade sobra agora: a perna direita segura o corpo na primeira metade.
func _limp() -> float:
	if _phase >= 0.5:
		return 1.0
	return 1.0 - Tuning.ARI_LIMP * sin(_phase / 0.5 * PI)


func _advance_gait(moved: float) -> void:
	if moved < 0.0002 or not is_on_floor():
		return
	var before := _phase
	_phase = fmod(_phase + moved / (Tuning.ARI_STRIDE * (0.5 if crawling else 1.0)), 1.0)
	if _phase < before:
		# Pisou com a perna ruim: mais leve, arrastando.
		_footsteps.play_step(-5.0)
	elif before < 0.5 and _phase >= 0.5:
		_footsteps.play_step()


func _update_breath(delta: float) -> void:
	var want := controls and Input.is_action_pressed("hold_breath") and _pant <= 0.0
	if want and not breath_held:
		breath_held = true
		held_for = 0.0
		_heart_timer = 0.6
		_inner(BREATH_IN, -12.0)
	elif not want and breath_held:
		breath_held = false
	if not breath_held:
		return
	held_for += delta
	var tension := clampf(held_for / Tuning.ARI_BREATH_SECONDS, 0.0, 1.0)
	_heart_timer -= delta
	if _heart_timer <= 0.0:
		_heart_timer = lerpf(1.0, 0.45, tension)
		_heart.volume_db = lerpf(-18.0, -4.0, tension)
		_heart.play()
	if held_for >= Tuning.ARI_BREATH_SECONDS:
		# Não aguentou: arfa alto (o Zelador ouve, F6) e fica sem fôlego um tempo.
		breath_held = false
		_pant = Tuning.ARI_GASP_SECONDS
		_inner(GASP, 0.0)
		Events.noise_made.emit(global_position, Tuning.ARI_NOISE_PANT)


## O que está no meio da tela, perto: o mais alinhado com o olhar.
func _update_interaction() -> void:
	_interaction = null
	if not controls:
		_clear_prompt()
		return
	var shelter := get_parent()
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var best := deg_to_rad(Tuning.ARI_INTERACT_ANGLE)
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var item := node as Node3D
		if not shelter.is_ancestor_of(item) or item.interaction_prompt() == "":
			continue
		var point: Vector3 = item.interaction_point() if item.has_method("interaction_point") else item.global_position
		var to_item := point - from
		if to_item.length() > Tuning.ARI_INTERACT_DISTANCE:
			continue
		var angle := forward.angle_to(to_item)
		if angle < best:
			best = angle
			_interaction = item
	var prompt: String = "" if _interaction == null else "[%s] " % Settings.key_label(&"interact", true) + _interaction.interaction_prompt()
	if prompt != _prompt:
		_prompt = prompt
		Events.prompt_changed.emit(prompt)


func _clear_prompt() -> void:
	if _prompt != "":
		_prompt = ""
		Events.prompt_changed.emit("")


func _inner(stream: AudioStream, volume: float) -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = stream
	sound.bus = &"Shelter"
	sound.volume_db = volume
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
