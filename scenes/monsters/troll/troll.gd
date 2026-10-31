class_name Troll
extends CharacterBody3D
## O troll da ponte caída (docs/plano_combate.md §2 e §7.2; experimental). O corpo é o do orc, bem
## maior, com a pele cinza de pedra e um olho só, que brilha verde: a lente do Zelador.
##
## De dia dorme sentado perto da ponte. De noite anda devagar pelas bordas do vale, entre a ponte e
## dois pontos da borda. Ouve e fareja muito bem; vê pouco. Quando pega o goblin, não fere: a tela
## escurece, e o goblin acorda largado na boca da toca, com a Vigilância mais alta. É o "ser sedado"
## do Abrigo dentro da floresta: o Zelador não pode ferir o paciente. Na toca ele não entra; com a
## bateria do Zelador baixa (R3 sem o R4) ele só dorme, e só um barulho perto o acorda.
##
## Primeira leitura: um troll estranho, que não mata. Segunda leitura: é ele.

const MODEL := preload("res://assets/models/orc/orc.glb")
const GROUP := &"trolls"
const BODY_LAYER := 32
const BODY_MASK := 1 | 2
const BREATH := preload("res://assets/audio/sfx/orc_death.wav")
const HUM := preload("res://assets/audio/real/extractor_fan.ogg")

enum State { SLEEP, WANDER, HUNT, CARRY }

var state := State.SLEEP
var awareness := 0.0
## A ponte (onde dorme) e os pontos da borda por onde anda de noite.
var home := Vector3.ZERO
var route: Array[Vector3] = []

var _animator: GoblinAnimator
var _visual: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _head_bone := -1
var _eye_offset := Vector3.ZERO
var _eye: OmniLight3D
var _hum: AudioStreamPlayer3D
var _route_index := 0
var _target_yaw := 0.0
var _last_yaw := 0.0
var _sense_timer := 0.0
var _breath_timer := 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	collision_layer = BODY_LAYER
	collision_mask = BODY_MASK
	floor_snap_length = 0.5
	var size := Tuning.TROLL_SCALE / Tuning.ORC_MODEL_SCALE
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32 * size
	capsule.height = 1.75 * size
	shape.shape = capsule
	shape.position = Vector3.UP * 0.875 * size
	add_child(shape)
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * Tuning.TROLL_SCALE
	add_child(_visual)
	_model = MODEL.instantiate()
	_visual.add_child(_model)
	# Os dois olhos do modelo: onde ficam (o meio deles vira o lugar da lente) e quais superfícies são.
	var face := _model.find_child("Rosto", true, false) as MeshInstance3D
	var eye_surfaces: Array[int] = []
	var eye_center := Vector3.ZERO
	if face != null:
		var count := 0
		for surface in face.mesh.get_surface_count():
			var material := face.mesh.surface_get_material(surface)
			if material != null and material.resource_name in ["goblin.olho", "goblin.pupila"]:
				eye_surfaces.append(surface)
				for vertex: Vector3 in face.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					eye_center += vertex
					count += 1
		eye_center /= maxf(count, 1.0)
	GoblinLook.apply(_model, {
		"pele": Color(0.84, 0.86, 0.82), "pele_escura": Color(0.56, 0.58, 0.56),
		"trapo": Color(0.6, 0.6, 0.57), "trapo_escuro": Color(0.42, 0.42, 0.4), "couro": Color(0.5, 0.48, 0.45),
	}, GoblinLook.TEXEL_SPAN / Tuning.TROLL_SCALE)
	# Os olhos fechados, da cor da pele: o olho dele é a lente no meio da testa.
	var body_mesh := _model.find_child("Corpo_continuo", true, false) as MeshInstance3D
	if face != null and body_mesh != null:
		for surface in eye_surfaces:
			face.set_surface_override_material(surface, body_mesh.mesh.surface_get_material(0))
	for piece in ["Elmo", "Peitoral", "Mascara", "Filtros"]:
		var node := _model.find_child(piece, true, false) as Node3D
		if node != null:
			node.visible = false
	var player := _model.find_child("AnimationPlayer") as AnimationPlayer
	if player != null:
		player.stop()
	var skeleton := _model.find_child("Skeleton3D") as Skeleton3D
	if skeleton != null:
		_skeleton = skeleton
		_head_bone = skeleton.find_bone("cabeca")
		if _head_bone != -1:
			# Na testa, acima das sobrancelhas e à frente do meio dos olhos (no espaço do osso da cabeça,
			# tamanho do goblin; mais embaixo a ponte do nariz cobre a lente).
			var lens_rest := eye_center + Vector3(0.0, 0.07, 0.05)
			_eye_offset = skeleton.get_bone_global_rest(_head_bone).affine_inverse() * lens_rest
	_animator = GoblinAnimator.new()
	add_child(_animator)
	if skeleton == null or not _animator.setup(skeleton):
		_animator.queue_free()
		_animator = null
	else:
		_animator.body = self
		_animator.foot_planted.connect(_on_step)
	# O olho: uma luz verde pequena no rosto (a lente).
	_eye = OmniLight3D.new()
	_eye.light_color = Color(0.35, 1.0, 0.45)
	_eye.omni_range = 1.4
	_eye.light_energy = 0.0
	add_child(_eye)
	var lens := MeshInstance3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.055
	bead.height = 0.11
	lens.mesh = bead
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(0.35, 1.0, 0.45)
	glow.emission_energy_multiplier = 3.0
	glow.albedo_color = Color(0.1, 0.3, 0.12)
	lens.material_override = glow
	_eye.add_child(lens)
	# O zumbido baixo de motor, bem perto dele (a segunda leitura).
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = HUM
	_hum.bus = &"World"
	_hum.volume_db = -26.0
	_hum.unit_size = 2.0
	_hum.max_distance = 18.0
	_hum.pitch_scale = 0.55
	_hum.position = Vector3.UP * 2.0
	add_child(_hum)
	_hum.finished.connect(_hum.play)
	_hum.play()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var night := Clock.night() > 0.5 and not low_battery()
	var player := Game.player
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = 0.2
		_sense(0.2)
	match state:
		State.SLEEP:
			_brake(delta)
			if night or awareness > 1.0:
				state = State.WANDER
		State.WANDER:
			if not night and awareness < 0.3:
				if _walk_to(home, Tuning.TROLL_WALK_SPEED, delta) < 1.5:
					state = State.SLEEP
			elif awareness >= 1.0 and player != null:
				state = State.HUNT
			elif not route.is_empty():
				if _walk_to(route[_route_index % route.size()], Tuning.TROLL_WALK_SPEED, delta) < 2.0:
					_route_index += 1
		State.HUNT:
			if player == null or awareness < 0.3:
				state = State.WANDER
			elif _indoors(player.global_position):
				# O goblin chegou na toca: ele fica na boca, desiste e volta para a ronda.
				awareness = 0.2
				state = State.WANDER
			else:
				var distance := _walk_to(player.global_position, Tuning.TROLL_RUN_SPEED, delta)
				if distance < Tuning.TROLL_GRAB_RANGE and not Game.resting and player.controls_on():
					_grab(player)
		State.CARRY:
			_brake(delta)
	move_and_slide()
	_breath_timer -= delta
	if _breath_timer <= 0.0 and state != State.SLEEP:
		_breath_timer = _rng.randf_range(5.0, 9.0)
		OccludedAudio.play_at(get_parent(), BREATH, global_position + Vector3.UP * 3.0, &"World", -10.0, 8.0, 0.45)


func _process(delta: float) -> void:
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _target_yaw, 1.0 - exp(-3.0 * delta))
	var awake := state != State.SLEEP
	_eye.light_energy = lerpf(_eye.light_energy, 1.0 if awake else 0.15, 1.0 - exp(-2.0 * delta))
	if _animator == null:
		return
	_animator.velocity_local = _visual.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	_animator.on_floor = is_on_floor()
	_animator.vertical_speed = velocity.y
	_animator.crouching = state == State.SLEEP
	_animator.turn_rate = angle_difference(_last_yaw, _visual.rotation.y) / maxf(delta, 0.001)
	_last_yaw = _visual.rotation.y
	_animator.update(delta)
	# A lente segue a cabeça, no meio da testa.
	if _head_bone != -1:
		_eye.global_position = _skeleton.global_transform * (_skeleton.get_bone_global_pose(_head_bone) * _eye_offset)


## A bateria do Zelador está baixa (R3 sem o R4): o troll não sai de noite.
func low_battery() -> bool:
	return Story.has_flag(&"climate_cut") and not Story.has_flag(&"access_card")


func _indoors(point: Vector3) -> bool:
	var level := Game.current_level
	return level != null and level.has_method("indoor_at") and float(level.indoor_at(point)) > 0.3


## Ouve e fareja muito; enxerga pouco. Dormindo, só um barulho alto acorda.
func _sense(dt: float) -> void:
	var player := Game.player
	if player == null or Game.awake:
		return
	var distance := global_position.distance_to(player.global_position)
	var stimulus := 0.0
	var hearing := Tuning.TROLL_HEARING * (0.3 if state == State.SLEEP else 1.0)
	if distance < hearing:
		stimulus += player.noise_level() * (1.0 - distance / hearing) * 2.5
	if state != State.SLEEP:
		var smell := Tuning.TROLL_SMELL * player.scent_level() * lerpf(1.0, Tuning.RAIN_SCENT, Weather.rain)
		if distance < smell:
			stimulus += 0.6 * (1.0 - distance / smell)
		if distance < Tuning.TROLL_SIGHT:
			stimulus += player.visibility() * (1.0 - distance / Tuning.TROLL_SIGHT) * 1.2
	awareness = clampf(awareness + stimulus * dt - 0.08 * dt, 0.0, 1.5)


## Pegou o goblin: não fere. Escurece, e ele acorda largado na boca da toca.
func _grab(player: Player) -> void:
	state = State.CARRY
	player.set_controls_enabled(false)
	var to := player.global_position - global_position
	_target_yaw = atan2(to.x, to.z)
	if _animator != null:
		_animator.play_action(&"pickup", 1.4)
	OccludedAudio.play_at(get_parent(), BREATH, global_position + Vector3.UP * 2.5, &"World", 0.0, 10.0, 0.4)
	Events.screen_fade_requested.emit(1.0, 0.8)
	Game.close_ears(0.8)
	await get_tree().create_timer(1.6, false).timeout
	if not is_instance_valid(player):
		return
	var mouth := Vector3(ForestLayout.CAVE_CENTER.x, 0.0, ForestLayout.CAVE_CENTER.y - ForestLayout.CAVE_DEPTH * 0.5 + 1.0)
	var level := Game.current_level
	if level != null and level.has_method("ground_height"):
		mouth.y = float(level.ground_height(mouth.x, mouth.z)) + 0.2
	player.global_position = mouth
	player.velocity = Vector3.ZERO
	Clock.hour = fmod(Clock.hour + Tuning.TROLL_CARRY_HOURS, 24.0)
	Story.add_vigilance(Tuning.VIGILANCE_TROLL)
	Story.set_flag(&"bestiary_troll")
	Story.add_count(&"troll_carried")
	Story.trigger(&"orc", &"troll")
	Events.screen_fade_requested.emit(0.0, 3.0)
	Game.open_ears(4.0, -30.0, 400.0)
	player.wake_up()
	Events.notification_shown.emit("Algo enorme te pegou no escuro e te largou na boca da toca. Não te machucou.")
	awareness = 0.0
	global_position = home
	state = State.SLEEP


## O passo pesado: o som do mesmo chão do goblin (Footsteps.SOUNDS), uma oitava abaixo e mais alto.
func _on_step(_side: int) -> void:
	var level := Game.current_level
	var surface: StringName = level.surface_at(global_position) if level != null and level.has_method("surface_at") else &"grass"
	var options: Array = Footsteps.SOUNDS.get(surface, Footsteps.SOUNDS[&"grass"])
	OccludedAudio.play_at(get_parent(), options.pick_random(), global_position, &"World", 4.0, 6.0, _rng.randf_range(0.45, 0.55))


func _walk_to(point: Vector3, speed: float, delta: float) -> float:
	var to := point - global_position
	to.y = 0.0
	var distance := to.length()
	if distance < 0.5:
		_brake(delta)
		return distance
	var direction := to / distance
	var weight := 1.0 - exp(-4.0 * delta)
	velocity.x = lerpf(velocity.x, direction.x * speed, weight)
	velocity.z = lerpf(velocity.z, direction.z * speed, weight)
	_target_yaw = atan2(direction.x, direction.z)
	return distance


func _brake(delta: float) -> void:
	var weight := 1.0 - exp(-6.0 * delta)
	velocity.x = lerpf(velocity.x, 0.0, weight)
	velocity.z = lerpf(velocity.z, 0.0, weight)
