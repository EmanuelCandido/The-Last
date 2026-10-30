class_name Orc
extends CharacterBody3D
## O orc (F12, docs/plano_combate.md §7; experimental). O corpo é o goblin de outras proporções
## (assets/models/orc, no mesmo esqueleto) animado pelo mesmo GoblinAnimator, no dobro do tamanho.
##
## Sentidos: vê em cone e ouve bem, fareja mal (o capim, o escuro e a lama importam mais que o
## vento). A atenção sobe com o que ele percebe e leva a: desconfiado (vai olhar), alerta (grita,
## chama os outros pelo OrcBand e luta). Uma pedra jogada faz ele ir ver onde ela caiu.
##
## Na luta: chega, rodeia esperando a vez (no máximo Tuning.ORC_ATTACKERS_AT_ONCE atacam juntos) e
## golpeia com preparação visível e um grunhido antes (a janela de quem defende). O golpe é a arma
## de verdade passando (WeaponTrace) e chega ao goblin por Player.receive_attack. Aparado, ou com a
## postura quebrada, ajoelha: a cabeça fica ao alcance do goblin. Ferido na perna, manca. Com a moral
## baixa, foge. Morto, cai e vira interagível: "Revistar".
##
## Não entra na toca nem na ruína (Tuning.ORC_CAVE_KEEP_OUT, ORC_RUIN_KEEP_OUT) e vai embora no fim
## da tarde. Quem cria e reúne os orcs é o OrcBand.

signal died(orc: Orc)

const MODEL := preload("res://assets/models/orc/orc.glb")
const GROUP := &"orcs"
## Camadas: o corpo (6, "monsters") e a área de acerto (5, "combat").
const BODY_LAYER := 32
const HIT_LAYER := 16
## O que o corpo do orc bate: mundo, árvores e o goblin.
const BODY_MASK := 1 | 2 | 4
const SIGHT_MASK := 1 | 2
const GRUNTS := [
	preload("res://assets/audio/sfx/orc_grunt_1.wav"), preload("res://assets/audio/sfx/orc_grunt_2.wav"),
	preload("res://assets/audio/sfx/orc_grunt_3.wav"),
]
const SHOUT := preload("res://assets/audio/sfx/orc_shout.wav")
const HURT := [preload("res://assets/audio/sfx/orc_hurt_1.wav"), preload("res://assets/audio/sfx/orc_hurt_2.wav")]
const DEATH := preload("res://assets/audio/sfx/orc_death.wav")
const HIT_SOUNDS := Arrow.HIT_FLESH
const SEARCH_SOUND := preload("res://assets/audio/real/pickup_3.ogg")

enum State { PATROL, INVESTIGATE, COMBAT, SEARCH, FLEE, KNEEL, DEAD, LEAVE }

## &"scout" (batedor: machado, couro) ou &"warrior" (guerreiro: espada, elmo e peitoral de ferro).
var kind := &"scout"
var state := State.PATROL
var health := 3.0
var awareness := 0.0
var poise := 0.0
var morale := 1.0
## Rota da patrulha (pontos no chão, em volta).
var route: Array[Vector3] = []
## Quem reúne os orcs (alerta, vez de atacar). Pode faltar (orc de teste).
var band: Node
var weapon_item := &"orc_axe"

var _animator: GoblinAnimator
var _visual: Node3D
var _model: Node3D
var _weapon: MeshInstance3D
var _weapon_axis := Vector3.UP
var _trace := WeaponTrace.new()
var _hit_area: Area3D
var _voice: AudioStreamPlayer3D
var _route_index := 0
var _goal := Vector3.INF
var _timer := 0.0
var _sense_timer := 0.0
var _attack := {}
var _attack_wait := 0.0
var _last_seen := Vector3.INF
var _seen_time := 0.0
var _target_yaw := 0.0
var _limp := 0.0
var _circle := 1.0
var _shouted := false
var _looted := false
var _last_yaw := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	health = float(Tuning.ORC_HEALTH.get(kind, 3.0))
	weapon_item = &"orc_sword" if kind == &"warrior" else &"orc_axe"
	collision_layer = BODY_LAYER
	collision_mask = BODY_MASK
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3.UP * 0.875
	add_child(shape)
	_build_body()
	_build_hit_area()
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"World"
	_voice.unit_size = 6.0
	_voice.max_distance = 60.0
	_voice.position = Vector3.UP * 1.6
	add_child(_voice)
	_trace.exclude = [_hit_area.get_rid()]
	_trace.mask = HIT_LAYER | 8
	_trace.radius = 0.1
	Events.noise_made.connect(_on_noise)
	_target_yaw = _visual.rotation.y
	_last_yaw = _target_yaw


# --- Corpo -------------------------------------------------------------------------

func _build_body() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * Tuning.ORC_MODEL_SCALE
	add_child(_visual)
	_model = MODEL.instantiate()
	_visual.add_child(_model)
	# Pele cinza-esverdeada e a roupa clara e gasta (na segunda leitura, o macacão da evacuação);
	# a textura fica no tamanho do goblin, então o pixel do orc não sai maior.
	GoblinLook.apply(_model, {
		"pele": Color(0.78, 0.82, 0.72), "pele_escura": Color(0.52, 0.55, 0.5),
		"trapo": Color(1.35, 1.32, 1.22), "trapo_escuro": Color(0.95, 0.92, 0.85), "couro": Color(0.7, 0.66, 0.62),
	}, GoblinLook.TEXEL_SPAN / Tuning.ORC_MODEL_SCALE)
	var player := _model.find_child("AnimationPlayer") as AnimationPlayer
	if player != null:
		player.stop()
	# O batedor anda sem ferro; o guerreiro usa o elmo e o peitoral.
	for piece in ["Elmo", "Peitoral"]:
		var node := _model.find_child(piece, true, false) as Node3D
		if node != null:
			node.visible = kind == &"warrior"
	var skeleton := _model.find_child("Skeleton3D") as Skeleton3D
	_animator = GoblinAnimator.new()
	add_child(_animator)
	if skeleton == null or not _animator.setup(skeleton):
		_animator.queue_free()
		_animator = null
	else:
		_animator.body = self
		_animator.foot_planted.connect(_on_step)
		var grip := _model.find_child("braco_D*mao", true, false) as Node3D
		if grip != null:
			_animator.weapon_grip = grip.transform.origin
	_weapon = MeshInstance3D.new()
	_weapon.mesh = WeaponMesh.build(weapon_item)
	add_child(_weapon)


func _build_hit_area() -> void:
	_hit_area = Area3D.new()
	_hit_area.collision_layer = HIT_LAYER
	_hit_area.collision_mask = 0
	_hit_area.monitoring = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.85
	shape.shape = capsule
	shape.position = Vector3.UP * 0.92
	_hit_area.add_child(shape)
	add_child(_hit_area)


## Onde a flecha fica presa (Arrow.reparent).
func body_node() -> Node3D:
	return _visual


## Para onde o orc olha (no chão).
func facing() -> Vector3:
	return Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))


## O barulho que os bichos ouvem (0..1).
func noise_level() -> float:
	if state == State.DEAD:
		return 0.0
	var speed := Vector2(velocity.x, velocity.z).length()
	return Tuning.ORC_RUN_NOISE if speed > Tuning.ORC_WALK_SPEED * 1.4 else Tuning.ORC_WALK_NOISE if speed > 0.3 else 0.1


func is_dead() -> bool:
	return state == State.DEAD


## O orc vivo mais perto de `point` a menos de `radius` m (null se nenhum).
static func nearest(tree: SceneTree, point: Vector3, radius: float) -> Orc:
	var best: Orc = null
	var best_distance := radius
	for node in tree.get_nodes_in_group(GROUP):
		var orc := node as Orc
		if orc.state == State.DEAD:
			continue
		var distance := orc.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = orc
	return best


# --- Quadro a quadro -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if state != State.DEAD:
		_sense_timer -= delta
		if _sense_timer <= 0.0:
			_sense_timer = 0.15
			_sense(0.15)
		poise = maxf(poise - Tuning.ORC_POISE_DECAY * delta, 0.0)
		_limp = maxf(_limp - delta, 0.0)
		_attack_wait -= delta
		_think(delta)
		if _attack.get("active", false):
			_sweep()
		if state != State.FLEE and state != State.LEAVE:
			_hold_zones()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	move_and_slide()


func _process(delta: float) -> void:
	_visual.rotation.y = lerp_angle(_visual.rotation.y, _target_yaw, 1.0 - exp(-Tuning.ORC_TURN_SPEED * delta))
	if _animator == null:
		return
	_animator.velocity_local = _visual.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	_animator.on_floor = is_on_floor()
	_animator.vertical_speed = velocity.y
	_animator.weapon_style = &"club"
	_animator.guarding = false
	_animator.turn_rate = angle_difference(_last_yaw, _visual.rotation.y) / maxf(delta, 0.001)
	_last_yaw = _visual.rotation.y
	_animator.lying = state == State.DEAD and not _animator.is_busy()
	_animator.update(delta)
	_weapon_axis = WeaponMesh.hold(_weapon, weapon_item, _animator, _visual)


# --- Sentidos ------------------------------------------------------------------------

func _sense(dt: float) -> void:
	var player := Game.player
	if player == null or Game.awake:
		return
	var eye := global_position + Vector3.UP * Tuning.ORC_EYE_HEIGHT
	var target := player.global_position + Vector3.UP * 0.5
	var distance := eye.distance_to(target)
	var stimulus := 0.0
	var seen := false
	var reach := Tuning.ORC_SIGHT * lerpf(1.0, Tuning.NIGHT_VISIBILITY, Clock.night())
	if distance < reach and Senses.sees(get_world_3d().direct_space_state, eye, facing(), target, Tuning.ORC_FOV, reach, SIGHT_MASK, [get_rid()]):
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		var motion := clampf(speed / Tuning.SIGHT_MOTION_SPEED, 0.2, 1.0)
		if speed > 0.3 and not player.is_crouching():
			motion = maxf(motion, Tuning.UPRIGHT_MOTION)
		var sight := pow(1.0 - distance / reach, 1.3) * player.visibility() * motion * 3.5
		stimulus += sight
		seen = sight > 0.12
	if distance < Tuning.ORC_HEARING:
		stimulus += player.noise_level() * (1.0 - distance / Tuning.ORC_HEARING) * 2.0 * lerpf(1.0, Tuning.RAIN_HEARING, Weather.rain)
	if distance < Tuning.ORC_SMELL * player.scent_level():
		stimulus += 0.3
	# Colado na luta, ele não perde o goblin (ouve, sente, esbarra), mesmo caído no capim.
	if state == State.COMBAT and distance < Tuning.ORC_CLOSE_TRACK:
		seen = true
	if seen:
		_last_seen = player.global_position
		_seen_time = 0.0
	else:
		_seen_time += dt
	if stimulus > 0.02:
		awareness = minf(awareness + stimulus * dt, 1.5)
		if state != State.COMBAT and awareness >= Tuning.ORC_SUSPICIOUS:
			_last_seen = player.global_position if seen or _last_seen == Vector3.INF else _last_seen
	elif state != State.COMBAT:
		awareness = maxf(awareness - Tuning.ORC_AWARENESS_DECAY * dt, 0.0)


func _on_noise(at: Vector3, radius: float) -> void:
	# Só vai ver barulho quem anda calmo ou procura (no meio da luta, ajoelhado ou fugindo, não).
	if not state in [State.PATROL, State.SEARCH, State.INVESTIGATE] or radius < 2.0:
		return
	var distance := at.distance_to(global_position)
	if distance > radius * 1.3:
		return
	# Vai ver o que foi (uma pedra jogada o leva para longe do goblin).
	awareness = maxf(awareness, Tuning.ORC_SUSPICIOUS + 0.05)
	_investigate(at)


## Outro orc gritou: vem para a luta.
func alert(at: Vector3) -> void:
	if state in [State.DEAD, State.FLEE, State.LEAVE]:
		return
	awareness = maxf(awareness, Tuning.ORC_ALERT)
	_last_seen = at
	_shouted = true
	_enter(State.COMBAT)


# --- Decisão -------------------------------------------------------------------------

func _think(delta: float) -> void:
	_timer -= delta
	var player := Game.player
	if state != State.FLEE and state != State.LEAVE and Clock.hour >= Tuning.ORC_LEAVE_HOUR:
		_leave()
	match state:
		State.PATROL:
			if _check_alert():
				return
			if route.is_empty():
				_stand(delta)
				return
			var point := route[_route_index % route.size()]
			if _walk_to(point, Tuning.ORC_WALK_SPEED, delta) < 1.2:
				_route_index += 1
		State.INVESTIGATE:
			if _check_alert():
				return
			if _walk_to(_goal, Tuning.ORC_WALK_SPEED * 1.2, delta) < 1.5:
				_stand(delta)
				if _timer <= 0.0:
					# Olhou em volta e não achou nada.
					_enter(State.SEARCH if awareness > Tuning.ORC_SUSPICIOUS else State.PATROL)
			else:
				_timer = 4.0
		State.SEARCH:
			if _check_alert():
				return
			if _goal == Vector3.INF or _walk_to(_goal, Tuning.ORC_WALK_SPEED, delta) < 1.5:
				_goal = _search_point()
			if _timer <= 0.0:
				awareness = minf(awareness, Tuning.ORC_SUSPICIOUS * 0.5)
				_enter(State.PATROL)
		State.COMBAT:
			_fight(player, delta)
		State.FLEE, State.LEAVE:
			var away := _goal
			if _walk_to(away, Tuning.ORC_RUN_SPEED if state == State.FLEE else Tuning.ORC_WALK_SPEED, delta, true) < 3.0 \
					or (player != null and global_position.distance_to(player.global_position) > 70.0 and _timer <= 0.0):
				queue_free()
		State.KNEEL:
			_stand(delta)
			if _timer <= 0.0:
				_enter(State.COMBAT)


func _check_alert() -> bool:
	if awareness >= Tuning.ORC_ALERT:
		_enter(State.COMBAT)
		return true
	if awareness >= Tuning.ORC_SUSPICIOUS and state == State.PATROL and _last_seen != Vector3.INF:
		_investigate(_last_seen)
		return true
	return false


func _investigate(at: Vector3) -> void:
	_goal = _keep_out(at)
	_timer = 4.0
	if state != State.INVESTIGATE:
		_play(GRUNTS.pick_random(), -8.0, 0.8)
	state = State.INVESTIGATE


func _enter(new_state: State) -> void:
	state = new_state
	match new_state:
		State.COMBAT:
			if not _shouted:
				_shouted = true
				_play(SHOUT, 0.0)
				if band != null and band.has_method("alert"):
					band.alert(self, _last_seen if _last_seen != Vector3.INF else global_position)
		State.SEARCH:
			_timer = Tuning.ORC_SEARCH_SECONDS
			_goal = _last_seen if _last_seen != Vector3.INF else _search_point()
			_shouted = false
		State.PATROL:
			_shouted = false
			_goal = Vector3.INF


func _fight(player: Player, delta: float) -> void:
	if player == null or Game.awake:
		_enter(State.SEARCH)
		return
	if Vitals.health <= 0.0 or Game.resting:
		_enter(State.SEARCH)
		return
	if _seen_time > 6.0:
		_enter(State.SEARCH)
		return
	var to := player.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var toward := to / maxf(distance, 0.001)
	if not _attack.is_empty():
		# No meio do golpe: só vira devagar para o alvo (dá para sair de lado).
		_target_yaw = rotate_toward(_target_yaw, atan2(toward.x, toward.z), 1.5 * delta)
		_brake(delta)
		return
	# Dentro da toca ou da ruína o orc não entra: espera na beira, gritando.
	if _forbidden(player.global_position):
		_walk_to(_keep_out(player.global_position), Tuning.ORC_WALK_SPEED, delta)
		if _rng.randf() < delta * 0.2:
			_play(GRUNTS.pick_random(), -4.0, 0.9)
		return
	_target_yaw = atan2(toward.x, toward.z)
	# Colado demais, o arco da arma passa por fora do goblin: recua um passo antes de golpear.
	if distance < Tuning.ORC_ATTACK_MIN:
		_move(-toward, Tuning.ORC_WALK_SPEED, delta)
		return
	if distance > Tuning.ORC_ATTACK_RANGE:
		var may_attack: bool = band == null or not band.has_method("may_attack") or band.may_attack(self)
		if may_attack or distance > Tuning.ORC_CIRCLE_DISTANCE + 1.0:
			_walk_to(player.global_position, Tuning.ORC_RUN_SPEED if distance > 4.0 else Tuning.ORC_WALK_SPEED, delta)
		else:
			_strafe(toward, delta)
		return
	if _attack_wait <= 0.0 and (band == null or not band.has_method("may_attack") or band.may_attack(self)):
		_start_attack(_rng.randf() < Tuning.ORC_HEAVY_CHANCE)
	else:
		_strafe(toward, delta)


## Rodeia o goblin de lado, esperando a vez, na distância de rodear.
func _strafe(toward: Vector3, delta: float) -> void:
	var side := Vector3(toward.z, 0.0, -toward.x) * _circle
	var distance_error := (Game.player.global_position - global_position).length() - Tuning.ORC_CIRCLE_DISTANCE
	var direction := (side + toward * clampf(distance_error, -1.0, 1.0)).normalized()
	if _rng.randf() < delta * 0.3:
		_circle = -_circle
	_move(direction, Tuning.ORC_WALK_SPEED * 0.7, delta)


# --- Golpes do orc -------------------------------------------------------------------

func is_attacking() -> bool:
	return not _attack.is_empty()


func _start_attack(heavy: bool) -> void:
	if _animator == null:
		return
	var timing := Weapons.swing(weapon_item, heavy)
	var slow := Tuning.ORC_SWING_SLOW
	var duration: float = float(timing[0]) * slow
	var opens: float = float(timing[1]) * slow
	var closes: float = float(timing[2]) * slow
	_attack = {"heavy": heavy, "active": false}
	_animator.strike_window = Vector2(opens, closes)
	_animator.strike_bend = Tuning.ORC_STRIKE_BEND
	_animator.play_action(&"club_heavy" if heavy else (&"club_1" if _rng.randf() < 0.5 else &"club_2"), duration,
		[[opens, _open_attack], [closes, _close_attack], [duration - 0.02, _end_attack]])
	# O aviso: o grunhido sai com a preparação (o tempo de reagir).
	_play(GRUNTS.pick_random(), -3.0 if heavy else -6.0, 0.85 if heavy else 1.0)


func _open_attack() -> void:
	if _attack.is_empty():
		return
	_attack.active = true
	_trace.begin()
	velocity += facing() * (2.2 if _attack.heavy else 1.4)
	OccludedAudio.play_at(get_parent(), MeleeAbility.SWING_SOUNDS.pick_random(), global_position + Vector3.UP * 1.2, &"World", -2.0, 4.0, 0.7)


func _close_attack() -> void:
	if _attack.is_empty():
		return
	_sweep()
	_attack.active = false


func _end_attack() -> void:
	_attack = {}
	_attack_wait = _rng.randf_range(Tuning.ORC_ATTACK_PAUSE.x, Tuning.ORC_ATTACK_PAUSE.y)


func _sweep() -> void:
	var blade := WeaponMesh.blade(weapon_item, _weapon.global_position, _weapon_axis, Tuning.ORC_MODEL_SCALE)
	for hit: Dictionary in _trace.sweep(get_world_3d(), blade[0], blade[1]):
		var target: Node = hit.target
		if target is Orc:
			continue
		if target is Player:
			var heavy: bool = _attack.heavy
			var push := facing() * (3.0 if heavy else 1.8) + Vector3.UP * (1.2 if heavy else 0.5)
			(target as Player).receive_attack({
				"damage": Tuning.ORC_HEAVY_DAMAGE if heavy else Tuning.ORC_LIGHT_DAMAGE, "kind": &"cut",
				"from": global_position, "poise": Tuning.ORC_HEAVY_POISE if heavy else Tuning.ORC_LIGHT_POISE,
				"cause": &"orc", "attacker": self, "push": push,
			})
		elif target != self and target.has_method("take_hit"):
			target.take_hit(1.0, hit.point, hit.direction, 1.2)


## Aparado: perde o equilíbrio e ajoelha (MeleeAbility.defend).
func stagger(_seconds: float) -> void:
	_kneel()


func _kneel() -> void:
	if state == State.DEAD:
		return
	_attack = {}
	poise = 0.0
	state = State.KNEEL
	_timer = Tuning.ORC_KNEEL
	if _animator != null:
		_animator.play_action(&"kneel", Tuning.ORC_KNEEL)
	_play(HURT.pick_random(), -2.0, 0.9)


# --- Golpes no orc -------------------------------------------------------------------

## Uma flechada (Arrow) ou um golpe de algo que não diz o tipo: perfuração.
func take_hit(power: float, point: Vector3, direction: Vector3, damage := 1.0) -> void:
	strike(lerpf(0.6, 1.4, power) * damage, &"pierce", point, direction, 0.3)


## Um golpe do goblin: `damage` na unidade da flechada, `kind` o tipo, `force` a postura.
func strike(damage: float, kind_of_hit: StringName, point: Vector3, direction: Vector3, force: float) -> void:
	if state == State.DEAD:
		return
	# O osso `cabeca` começa no pescoço: o meio da cabeça fica uns 12 cm (no modelo) acima.
	var head := (_animator.bone_position("cabeca") if _animator != null else global_position + Vector3.UP * 1.3) \
		+ Vector3.UP * 0.12 * Tuning.ORC_MODEL_SCALE
	var hips := _animator.bone_position("quadril") if _animator != null else global_position + Vector3.UP * 0.8
	var zone := &"torso"
	if point.distance_to(head) < 0.17 * Tuning.ORC_MODEL_SCALE:
		zone = &"head"
	elif point.y < hips.y:
		zone = &"legs"
	var hurt := damage
	match zone:
		&"head":
			hurt *= Tuning.ORC_HEAD_DAMAGE / (Tuning.ORC_HELMET if kind == &"warrior" and kind_of_hit != &"blunt" else 1.0)
		&"legs":
			hurt *= Tuning.ORC_LEG_DAMAGE
			_limp = Tuning.ORC_LIMP_SECONDS
		_:
			if kind == &"warrior":
				hurt *= float(Tuning.ORC_IRON.get(kind_of_hit, 1.0))
	# Pego desprevenido (o goblin não foi visto): o golpe entra inteiro.
	health -= hurt
	morale -= hurt / maxf(float(Tuning.ORC_HEALTH.get(kind, 3.0)), 0.1) * 0.5
	_play(HURT.pick_random(), -1.0, _rng.randf_range(0.9, 1.05))
	if health <= 0.0:
		_die()
		return
	if Game.player != null:
		_last_seen = Game.player.global_position
	awareness = 1.5
	poise += force * (1.6 if kind_of_hit == &"blunt" else 1.0)
	if poise >= Tuning.ORC_POISE_MAX:
		_kneel()
	elif state != State.COMBAT and state != State.KNEEL:
		_enter(State.COMBAT)
	if morale < Tuning.ORC_FLEE_MORALE and state != State.KNEEL:
		_flee()


## Um companheiro caiu: a moral cai.
func lose_heart(amount: float) -> void:
	morale -= amount
	if morale < Tuning.ORC_FLEE_MORALE and state in [State.COMBAT, State.SEARCH, State.INVESTIGATE]:
		_flee()


## O golpe furtivo vale: o orc não estava alerta.
func unaware() -> bool:
	return state != State.COMBAT and awareness < Tuning.ORC_ALERT


func _flee() -> void:
	_attack = {}
	state = State.FLEE
	_timer = 8.0
	var player := Game.player
	var away := global_position - (player.global_position if player != null else global_position)
	away.y = 0.0
	_goal = _edge_point(away.normalized() if away.length_squared() > 0.01 else facing())
	_play(SHOUT, -4.0, 1.2)


func _leave() -> void:
	_attack = {}
	state = State.LEAVE
	_timer = 5.0
	_goal = _edge_point(Vector3(global_position.x, 0.0, global_position.z).normalized())


func _die() -> void:
	state = State.DEAD
	_attack = {}
	health = 0.0
	collision_layer = 0
	_hit_area.collision_layer = 0
	if _animator != null:
		_animator.play_action(&"die", 0.9)
	_play(DEATH, 0.0)
	add_to_group(&"interactable")
	Events.noise_made.emit(global_position, 12.0)
	died.emit(self)


# --- Revistar ------------------------------------------------------------------------

func interaction_prompt() -> String:
	return "" if state != State.DEAD or _looted else "Revistar o orc"


func interaction_action() -> Dictionary:
	return {"action": &"harvest", "duration": 2.4, "at": 1.9}


func interact(_player: Node) -> void:
	if _looted:
		return
	_looted = true
	remove_from_group(&"interactable")
	var found := PackedStringArray()
	# A arma, gasta da luta.
	Inventory.add(weapon_item, 1, _rng.randf_range(0.3, 0.6))
	found.append(String(Weapons.spec(weapon_item).get("called", weapon_item)))
	var scrap := _rng.randi_range(1, 2) + (1 if kind == &"warrior" else 0)
	Inventory.add(&"iron_scrap", scrap)
	found.append("%d sucata%s" % [scrap, "s" if scrap > 1 else ""])
	Inventory.add(&"orc_ration")
	found.append("carne seca")
	# O ferro do guerreiro (F13): grande demais, ajusta na bancada.
	if kind == &"warrior":
		if _rng.randf() < Tuning.ORC_HELMET_DROP:
			Inventory.add(&"orc_helmet")
			found.append("o elmo")
		if _rng.randf() < Tuning.ORC_CHEST_DROP:
			Inventory.add(&"orc_chest")
			found.append("o peitoral")
	var arrows := Arrow.collect_from(self)
	if arrows > 0:
		found.append("%d flecha%s" % [arrows, "s" if arrows > 1 else ""])
	_weapon.visible = false
	OccludedAudio.play_at(get_parent(), SEARCH_SOUND, global_position + Vector3.UP * 0.4, &"World", -4.0, 3.0)
	Events.notification_shown.emit("Revistou o orc: %s." % ", ".join(found))


# --- Movimento -----------------------------------------------------------------------

## Anda até `point` desviando do que está na frente. Devolve a distância que falta (no chão).
func _walk_to(point: Vector3, speed: float, delta: float, ignore_zones := false) -> float:
	if point == Vector3.INF:
		_stand(delta)
		return 0.0
	var goal := point if ignore_zones else _keep_out(point)
	var to := goal - global_position
	to.y = 0.0
	var distance := to.length()
	if distance < 0.4:
		_stand(delta)
		return distance
	_move(to / distance, speed, delta)
	return distance


func _move(direction: Vector3, speed: float, delta: float) -> void:
	var free := _steer(direction)
	if _limp > 0.0:
		speed *= Tuning.ORC_LIMP_SPEED
	var target := free * speed
	var weight := 1.0 - exp(-6.0 * delta)
	velocity.x = lerpf(velocity.x, target.x, weight)
	velocity.z = lerpf(velocity.z, target.z, weight)
	if state != State.COMBAT or _attack.is_empty():
		if state != State.COMBAT:
			_target_yaw = atan2(free.x, free.z)


func _stand(delta: float) -> void:
	_brake(delta)


func _brake(delta: float) -> void:
	var weight := 1.0 - exp(-8.0 * delta)
	velocity.x = lerpf(velocity.x, 0.0, weight)
	velocity.z = lerpf(velocity.z, 0.0, weight)


## A direção livre mais perto de `direction`: dois raios (canela e peito) à frente; se baterem, tenta
## abrir para os lados.
func _steer(direction: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	for angle: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var candidate := direction.rotated(Vector3.UP, angle)
		var clear := true
		for height: float in [0.5, 1.3]:
			var from := global_position + Vector3.UP * height
			var query := PhysicsRayQueryParameters3D.create(from, from + candidate * 1.4, 1 | 2, [get_rid()])
			if not space.intersect_ray(query).is_empty():
				clear = false
				break
		if clear:
			return candidate
	return direction


## Não deixa a velocidade levar o orc para dentro da toca ou da ruína (o freio sozinho passava da
## beira); quem estiver dentro é empurrado para fora.
func _hold_zones() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	for zone: Array in [[ForestLayout.CAVE_CENTER, Tuning.ORC_CAVE_KEEP_OUT], [ForestLayout.RUINS, Tuning.ORC_RUIN_KEEP_OUT]]:
		var center: Vector2 = zone[0]
		var radius: float = zone[1]
		var offset := flat - center
		if offset.length() > radius + 1.0:
			continue
		var out := offset.normalized() if offset.length_squared() > 0.01 else Vector2(0.0, -1.0)
		var moving := Vector2(velocity.x, velocity.z)
		var inward := minf(moving.dot(out), 0.0)
		moving -= out * inward
		if offset.length() < radius:
			moving += out * 1.5
		velocity.x = moving.x
		velocity.z = moving.y


## Dentro da toca ou perto da ruína: lugar onde o orc não entra.
func _forbidden(point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	return flat.distance_to(ForestLayout.CAVE_CENTER) < Tuning.ORC_CAVE_KEEP_OUT \
		or flat.distance_to(ForestLayout.RUINS) < Tuning.ORC_RUIN_KEEP_OUT


## O ponto mais perto de `point` fora da toca e da ruína.
func _keep_out(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z)
	for zone: Array in [[ForestLayout.CAVE_CENTER, Tuning.ORC_CAVE_KEEP_OUT], [ForestLayout.RUINS, Tuning.ORC_RUIN_KEEP_OUT]]:
		var center: Vector2 = zone[0]
		var radius: float = zone[1]
		var offset := flat - center
		if offset.length() < radius:
			flat = center + (offset.normalized() if offset.length_squared() > 0.01 else Vector2(0.0, -1.0)) * (radius + 0.5)
	return Vector3(flat.x, point.y, flat.y)


## Um lugar para procurar em volta de onde o goblin foi visto.
func _search_point() -> Vector3:
	var base := _last_seen if _last_seen != Vector3.INF else global_position
	var angle := _rng.randf() * TAU
	return base + Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(3.0, 9.0)


## Um ponto na borda do vale na direção `direction` (para onde o orc vai embora).
func _edge_point(direction: Vector3) -> Vector3:
	var flat := Vector2(direction.x, direction.z)
	if flat.length_squared() < 0.01:
		flat = Vector2(1.0, 0.0)
	var edge := flat.normalized() * (ForestLayout.VALLEY_RADIUS - 6.0)
	return Vector3(edge.x, global_position.y, edge.y)


# --- Som ---------------------------------------------------------------------------

func _play(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	_voice.stream = stream
	_voice.volume_db = volume_db
	_voice.pitch_scale = pitch * _rng.randf_range(0.95, 1.05)
	_voice.play()


func _on_step(_side: int) -> void:
	var level := Game.current_level
	if level == null:
		return
	var surface: StringName = level.surface_at(global_position) if level.has_method("surface_at") else &"dirt"
	var sounds: Array = Footsteps.SOUNDS.get(surface, Footsteps.SOUNDS.get(&"dirt", []))
	if sounds.is_empty():
		return
	# Botas pesadas: os passos do goblin, um tom abaixo e mais altos.
	OccludedAudio.play_at(level, sounds.pick_random(), global_position, &"World", -6.0, 3.0, _rng.randf_range(0.68, 0.76))
