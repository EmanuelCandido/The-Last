class_name Animal
extends Node3D
## Bicho com sentidos de presa, para caçar e para fugir de forma crível.
##
## Sentidos (a cada SENSE_INTERVAL):
## - visão: cone de visão largo + linha de visada (árvores e terreno bloqueiam). Bichos
##   de presa percebem movimento muito melhor que forma parada, e pastando (cabeça
##   baixa) quase não enxergam;
## - audição: o barulho dos passos do goblin (agachado quase não faz) e barulhos
##   altos do mundo (Events.noise_made: árvore caindo, flecha batendo);
## - olfato: se o vento sopra do goblin para o bicho, ele sente o cheiro de longe.
## Os estímulos somam `awareness`: acima de SUSPICIOUS o bicho para e encara; acima de
## FLEE ele foge (e avisa a manada). Ferido, foge sangrando e mais devagar; morto,
## vira caça para coletar com E.
##
## Não usa física para andar: segue a altura do Terrain. O modelo olha para +Z.

enum State { IDLE, GRAZE, WALK, SUSPICIOUS, FLEE, DEAD }

const SENSE_INTERVAL := 0.15
const SIGHT_MASK := 1 | 2
const SUSPICIOUS := 0.35
const FLEE := 0.8
## Quanto dura o susto de um barulho e quanto o goblin precisa ser visto para passar por cima dele.
const STARTLE_SECONDS := 3.0
const STARTLE_OVERRIDE := 1.0
const HIT_LAYER := 8
const PICKUP_SOUND := preload("res://assets/audio/real/pickup_5.ogg")
## Passo em terra, mais agudo: batida de casco correndo.
const HOOF_SOUND := preload("res://assets/audio/real/hoof_dirt.ogg")

@export_group("Movimento")
@export var walk_speed := 1.2
@export var run_speed := 7.0
@export var turn_speed := 4.0
@export var home_radius := 22.0
## Distância (m) entre batidas de casco correndo; 0 = sem som.
@export var gallop_stride := 0.0
## Tamanho da pegada (largura, comprimento em m); zero = não deixa pegadas.
@export var track_size := Vector2.ZERO
## Quanto cada pegada sai para o lado do caminho (m), alternando: a fila de cascos.
@export var track_side := 0.0

@export_group("Sentidos")
@export var sight_range := 45.0
@export var sight_fov_deg := 300.0
@export var hearing_range := 30.0
@export var smell_range := 60.0
@export var eye_height := 1.4
## Distância do perigo em que volta a se acalmar.
@export var calm_distance := 60.0

@export_group("Caça")
@export var max_health := 2.0
@export var meat := 3
## Que carne o bicho dá (o cervo branco dá a carne branca).
@export var meat_item := &"meat"
@export var hide := 1
## Altura do corpo deitado, quando morre.
@export var dead_height := 0.22
## Grupo da manada ("" = vive sozinho).
@export var herd := ""
## Espécie, para a história contar o que foi caçado ("deer", "rabbit").
@export var kind := &""

var terrain: Terrain
var home := Vector2.ZERO
var state := State.IDLE
var speed := 0.0
## Atenção (0 calmo .. 1+ fugindo).
var awareness := 0.0
var health := 2.0

var _target := Vector2.ZERO
var _timer := 0.0
var _yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _sense_timer := 0.0
var _threat := Vector2.ZERO
## Susto de um barulho (s): enquanto dura, o perigo é o lugar do barulho, a não ser que o
## goblin apareça com clareza. É o que deixa a pedra tocar a manada para longe dela.
var _startle := 0.0
var _stamina := 1.0
var _zigzag := 0.0
var _zigzag_timer := 0.0
var _bleed_timer := 0.0
var _stride := 0.0
## Travado (s): nem anda, nem anima, nem soa (a pista do cervo que congela).
var _frozen := 0.0
var _track_distance := 0.0
var _track_left := false
var _hitbox: Area3D
var _voice: OccludedAudio
var _hooves: OccludedAudio


func setup(world_terrain: Terrain, home_position: Vector2, rng_seed: int) -> void:
	terrain = world_terrain
	home = home_position
	_rng.seed = rng_seed
	_yaw = _rng.randf() * TAU
	var start := _pick_target()
	position = Vector3(start.x, terrain.get_height(start.x, start.y), start.y)
	rotation.y = _yaw
	_enter(State.GRAZE)


func _ready() -> void:
	health = max_health
	add_to_group(&"animals")
	if herd != "":
		add_to_group(herd)
	_build_body()
	_hitbox = Area3D.new()
	_hitbox.collision_layer = HIT_LAYER
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	add_child(_hitbox)
	_build_hitbox(_hitbox)
	_voice = _make_sound()
	_hooves = _make_sound()
	_hooves.stream = HOOF_SOUND
	Events.noise_made.connect(_on_noise)


func _physics_process(delta: float) -> void:
	if terrain == null or state == State.DEAD:
		return
	if _frozen > 0.0:
		_frozen -= delta
		return
	_startle = maxf(_startle - delta, 0.0)
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = SENSE_INTERVAL
		_sense(SENSE_INTERVAL)
	var here := Vector2(position.x, position.z)
	_think(delta, here)
	_move(delta, here)
	_bleed(delta)
	_animate(delta)


## Monta as partes do corpo como filhos deste nó.
func _build_body() -> void:
	pass


## Coloca as formas de acerto (CollisionShape3D) na área de acerto.
func _build_hitbox(_area: Area3D) -> void:
	pass


func _animate(_delta: float) -> void:
	pass


## Nó que se move com o corpo (as flechas que acertam ficam presas nele).
func body_node() -> Node3D:
	return self


## Som do bicho desconfiado ou fugindo (bufo). Nulo = mudo.
func _alarm_sound() -> AudioStream:
	return null


## Som do bicho ao ser ferido ou morto. Nulo = usa o de alarme.
func _hurt_sound() -> AudioStream:
	return _alarm_sound()


## Quanto o acerto em `local_point` (coordenadas do bicho) vale: pescoço e peito matam mais.
func _vital_multiplier(_local_point: Vector3) -> float:
	return 1.0


## Uma flechada: `power` é a força do disparo (0..1); `damage` multiplica o dano (flecha emplumada).
func take_hit(power: float, point: Vector3, _direction: Vector3, damage := 1.0) -> void:
	if state == State.DEAD:
		return
	health -= lerpf(0.6, 1.4, power) * damage * _vital_multiplier(to_local(point))
	if Game.player != null:
		_threat = Vector2(Game.player.global_position.x, Game.player.global_position.z)
	_play_voice(_hurt_sound())
	if health <= 0.0:
		_die()
		return
	awareness = 1.5
	_enter(State.FLEE)


## Um bicho da manada viu perigo e saiu correndo.
func alarm(threat: Vector2) -> void:
	if state == State.DEAD or state == State.FLEE:
		return
	_threat = threat
	# Foge para longe de onde a manada se assustou, junto com ela.
	_startle = STARTLE_SECONDS
	awareness = maxf(awareness, 1.0)
	# Leva um instante para reagir ao susto do vizinho.
	get_tree().create_timer(_rng.randf_range(0.1, 0.5)).timeout.connect(func() -> void:
		if state != State.DEAD and state != State.FLEE:
			_enter(State.FLEE))


## Trava no meio do passo por `seconds`, mudo, como uma imagem parada.
func freeze(seconds: float) -> void:
	_frozen = seconds
	_voice.stop()
	_hooves.stop()


func is_frozen() -> bool:
	return _frozen > 0.0


## Morre na hora, sem susto nem barulho (o coelho pego no laço).
func kill() -> void:
	if state == State.DEAD:
		return
	health = 0.0
	state = State.DEAD
	speed = 0.0
	_hitbox.queue_free()
	add_to_group(&"interactable")
	var body := body_node()
	body.rotation.z = PI * 0.5
	body.position.y = dead_height


func interaction_prompt() -> String:
	return "Coletar carne e couro" if state == State.DEAD else ""


## O goblin ajoelha e corta a caça; a carne só sai no fim.
func interaction_action() -> Dictionary:
	return {"action": &"harvest", "duration": 2.4, "at": 1.9}


func interact(_player: Node) -> void:
	Events.animal_harvested.emit(kind)
	var arrows := Arrow.collect_from(body_node())
	if meat > 0:
		Inventory.add(meat_item, meat)
	if hide > 0:
		Inventory.add(&"hide", hide)
	var message := "+%d %s, +%d couro" % [meat, String(Inventory.NAMES.get(meat_item, "carne")).to_lower(), hide]
	if arrows > 0:
		message += ", +%d flecha%s" % [arrows, "s" if arrows > 1 else ""]
	Events.notification_shown.emit(message)
	OccludedAudio.play_at(get_parent(), PICKUP_SOUND, global_position + Vector3.UP * 0.4, &"World", -4.0, 3.0)
	queue_free()


# --- Sentidos --------------------------------------------------------------------

func _sense(dt: float) -> void:
	var player := Game.player
	if player == null:
		return
	var eye := global_position + Vector3.UP * eye_height
	var target := player.global_position + Vector3.UP * 0.6
	var to_player := target - eye
	var distance := to_player.length()
	var stimulus := 0.0
	var seen := 0.0

	if distance < sight_range:
		var forward := Vector3(sin(_yaw), 0.0, cos(_yaw))
		var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()
		var angle := rad_to_deg(forward.angle_to(flat))
		if angle < sight_fov_deg * 0.5 and _line_of_sight(eye, target):
			var motion := clampf(Vector2(player.velocity.x, player.velocity.z).length() / 3.0, 0.15, 1.0)
			var sight := pow(1.0 - distance / sight_range, 1.5) * player.visibility() * motion
			sight *= 1.0 if angle < 60.0 else 0.5
			if state == State.GRAZE:
				sight *= 0.35
			seen = sight * 3.0
			stimulus += seen

	if distance < hearing_range:
		stimulus += player.noise_level() * (1.0 - distance / hearing_range) * 2.0

	var from_player := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z)
	# Coberto de lama, o goblin cheira menos (Player.scent_level).
	var scent_range := (smell_range * Wind.intensity + 10.0) * player.scent_level()
	if from_player.length() < scent_range:
		var downwind := from_player.normalized().dot(Wind.direction)
		if downwind > 0.6:
			stimulus += (downwind - 0.6) / 0.4 * (1.0 - from_player.length() / scent_range) * 1.5

	if stimulus > 0.05:
		# Assustado com um barulho, só olha para o goblin se o vir com clareza (cheiro e
		# passos não dizem de onde vem o perigo).
		if _startle <= 0.0 or seen > STARTLE_OVERRIDE:
			_threat = Vector2(player.global_position.x, player.global_position.z)
		awareness = minf(awareness + stimulus * dt, 1.5)
	else:
		awareness = maxf(awareness - dt * (0.08 if state == State.FLEE else 0.12), 0.0)


func _line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, SIGHT_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_noise(at: Vector3, radius: float) -> void:
	if state == State.DEAD:
		return
	var distance := at.distance_to(global_position)
	if distance > radius:
		return
	awareness = minf(awareness + (1.0 - distance / radius) * 1.2, 1.5)
	_threat = Vector2(at.x, at.z)
	_startle = STARTLE_SECONDS


# --- Decisão ---------------------------------------------------------------------

func _think(delta: float, here: Vector2) -> void:
	_timer -= delta
	if state != State.FLEE and awareness >= FLEE:
		_enter(State.FLEE)
		return
	match state:
		State.IDLE, State.GRAZE, State.WALK:
			if awareness >= SUSPICIOUS:
				_enter(State.SUSPICIOUS)
			elif state == State.WALK and (here.distance_to(_target) < 0.6 or _timer <= 0.0):
				_enter(State.GRAZE if _rng.randf() < 0.7 else State.IDLE)
			elif state != State.WALK and _timer <= 0.0:
				_enter(State.WALK if _rng.randf() < 0.6 else State.GRAZE)
		State.SUSPICIOUS:
			if awareness < SUSPICIOUS * 0.6 and _timer <= 0.0:
				_enter(State.GRAZE)
		State.FLEE:
			_stamina = maxf(_stamina - delta / 18.0, 0.0)
			var wounded := health < max_health
			if here.distance_to(_threat) > calm_distance and awareness < 0.3 and not wounded:
				# Acalma onde parou e passa a viver por ali.
				home = here
				_enter(State.WALK)
	if state != State.FLEE:
		_stamina = minf(_stamina + delta / 30.0, 1.0)


func _enter(new_state: State) -> void:
	var previous := state
	state = new_state
	match new_state:
		State.GRAZE:
			_timer = _rng.randf_range(4.0, 10.0)
		State.IDLE:
			_timer = _rng.randf_range(2.0, 5.0)
		State.WALK:
			_target = _pick_target()
			_timer = 15.0
		State.SUSPICIOUS:
			_timer = _rng.randf_range(3.0, 6.0)
			if previous != State.SUSPICIOUS:
				_play_voice(_alarm_sound())
		State.FLEE:
			if previous != State.FLEE:
				_play_voice(_alarm_sound())
				_alarm_herd()


func _alarm_herd() -> void:
	if herd == "":
		return
	for node in get_tree().get_nodes_in_group(herd):
		var other := node as Animal
		if other != self and other.global_position.distance_to(global_position) < 35.0:
			other.alarm(_threat)


# --- Movimento -------------------------------------------------------------------

func _move(delta: float, here: Vector2) -> void:
	var desired_speed := 0.0
	var desired_yaw := _yaw
	var acceleration := 3.0
	match state:
		State.WALK:
			desired_speed = walk_speed
			desired_yaw = _yaw_towards(_target - here)
		State.SUSPICIOUS:
			desired_yaw = _yaw_towards(_threat - here)
		State.FLEE:
			acceleration = 14.0
			var health_factor := lerpf(0.55, 1.0, clampf(health / max_health, 0.0, 1.0))
			desired_speed = run_speed * health_factor * lerpf(0.55, 1.0, _stamina)
			var away := (here - _threat).normalized()
			if away.is_zero_approx():
				away = Vector2(sin(_yaw), cos(_yaw))
			# Perto da borda do vale, foge de volta para o meio.
			var edge := smoothstep(ForestLayout.VALLEY_RADIUS - 25.0, ForestLayout.VALLEY_RADIUS, here.length())
			away = away.lerp(-here.normalized(), edge).normalized()
			_zigzag_timer -= delta
			if _zigzag_timer <= 0.0:
				_zigzag_timer = _rng.randf_range(0.35, 0.9)
				_zigzag = _rng.randf_range(-0.5, 0.5)
			desired_yaw = _yaw_towards(away.rotated(_zigzag))

	speed = move_toward(speed, desired_speed, acceleration * delta)
	_yaw = lerp_angle(_yaw, desired_yaw, 1.0 - exp(-turn_speed * delta))
	var next := here + Vector2(sin(_yaw), cos(_yaw)) * speed * delta
	if speed > 0.0 and not _is_walkable(next):
		# Encosta íngreme ou caverna à frente: desvia.
		_yaw += PI * 0.5 * (1.0 if _rng.randf() < 0.5 else -1.0)
		if state == State.WALK:
			_target = _pick_target()
		next = here
	position = Vector3(next.x, terrain.get_height(next.x, next.y), next.y)
	rotation.y = _yaw
	_leave_tracks(speed * delta)

	if gallop_stride > 0.0 and speed > walk_speed * 2.0:
		_stride += speed * delta
		if _stride >= gallop_stride:
			_stride = 0.0
			_hooves.pitch_scale = _rng.randf_range(1.2, 1.5)
			_hooves.play()


## A cada Tuning.TRACK_SPACING andados, uma pegada (alternando os lados da fila).
func _leave_tracks(moved: float) -> void:
	if track_size == Vector2.ZERO:
		return
	_track_distance += moved
	if _track_distance < Tuning.TRACK_SPACING:
		return
	_track_distance = 0.0
	_track_left = not _track_left
	var side := Vector3(cos(_yaw), 0.0, -sin(_yaw)) * track_side * (1.0 if _track_left else -1.0)
	var at := position + side
	at.y = terrain.get_height(at.x, at.z)
	Tracks.stamp(at, terrain.get_normal(at.x, at.z), _yaw + _rng.randf_range(-0.15, 0.15), track_size, kind)


func _bleed(delta: float) -> void:
	if health >= max_health:
		return
	_bleed_timer -= delta
	if _bleed_timer > 0.0:
		return
	_bleed_timer = 0.45 if speed > 1.0 else 1.5
	var drop := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * _rng.randf_range(0.08, 0.18)
	quad.orientation = PlaneMesh.FACE_Y
	drop.mesh = quad
	drop.material_override = _blood_material()
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(_rng.randf_range(-0.2, 0.2), 0.03, _rng.randf_range(-0.2, 0.2))
	drop.rotation.y = _rng.randf() * TAU
	get_tree().create_timer(120.0).timeout.connect(drop.queue_free)


func _die() -> void:
	state = State.DEAD
	speed = 0.0
	_hitbox.queue_free()
	add_to_group(&"interactable")
	var body := body_node()
	var tween := create_tween().set_parallel()
	tween.tween_property(body, "rotation:z", PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(body, "position:y", dead_height, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_alarm_herd()


func _pick_target() -> Vector2:
	for attempt in 10:
		var p := home + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * home_radius
		if _is_walkable(p):
			return p
	return home


func _is_walkable(p: Vector2) -> bool:
	return p.length() < ForestLayout.VALLEY_RADIUS and ForestLayout.cave_ellipse(p) > 1.8 \
		and terrain.get_normal(p.x, p.y).y > 0.8


func _yaw_towards(direction: Vector2) -> float:
	return atan2(direction.x, direction.y)


func _play_voice(sound: AudioStream) -> void:
	if sound == null:
		return
	_voice.stream = sound
	_voice.pitch_scale = _rng.randf_range(0.9, 1.1)
	_voice.play()


func _make_sound() -> OccludedAudio:
	var sound := OccludedAudio.new()
	sound.clear_bus = &"World"
	sound.unit_size = 6.0
	sound.max_distance = 90.0
	sound.position = Vector3.UP * 0.8
	add_child(sound)
	return sound


static var _blood: StandardMaterial3D


static func _blood_material() -> StandardMaterial3D:
	if _blood == null:
		_blood = StandardMaterial3D.new()
		_blood.albedo_color = Color(0.28, 0.03, 0.02)
		_blood.roughness = 0.4
	return _blood


## Caixa colorida presa a `parent`, com centro em `center` (coordenadas locais).
func _box(parent: Node3D, size: Vector3, center: Vector3, material: Material, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = center
	part.rotation = tilt
	parent.add_child(part)
	return part


## Pivô (articulação) vazio, para girar um grupo de partes.
func _joint(parent: Node3D, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	return joint


## Forma de acerto (caixa) dentro da área de acerto.
func _hit_shape(area: Area3D, size: Vector3, center: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	area.add_child(collision)


static func fur_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = preload("res://assets/textures/fur.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	material.roughness = 1.0
	return material


static func flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
