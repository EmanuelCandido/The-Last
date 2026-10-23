class_name GoblinAutopilot
extends Node
## O goblin sem ninguém nos controles (§8, Bem-vindo de volta): depois do Final 3, quem joga é a
## IA. Ela aperta as mesmas ações de quem joga (o Input), então o goblin anda, mira, atira, coleta,
## come e dorme pelo Player de verdade, e a câmera dele acompanha como se alguém jogasse. Os bichos
## o veem, ouvem e farejam como sempre.
##
## Tarefas: pegar o arco; caçar (o cervo mais perto, o coelho só se estiver perto; chega agachado,
## espera o bicho assustado se acalmar, levanta, mira com a queda da flecha e atira, se o caminho
## do arco até o alvo estiver livre); coletar o que caiu; comer com fome; e, de noite, voltar para
## a pele e dormir. Sem flechas, fabrica mais.
## Parte do goblin: filho do Player (quem põe é o WelcomeBack). Tirar o nó devolve os controles.

enum Task { WAIT, BOW, HUNT, AIM, HARVEST, HOME, SLEEP }

## As ações que ele segura (soltas quando sai).
const HELD := ["move_forward", "crouch", "aim", "attack", "sprint"]
## A boca da caverna, por onde ele entra e sai (x, z).
const MOUTH := Vector2(0.0, 63.0)
const ARRIVE := 1.1
## Mirando: segundos para a câmera assentar e para esperar a flecha seguinte.
const SETTLE := 0.6
const AFTER_SHOT := 1.0
## De onde a flecha sai (altura do arco, de pé) e até onde ele atira num bicho fugindo (m).
const BOW_HEIGHT := 1.0
const FLEEING_RANGE := 10.0

var task := Task.WAIT

var _player: Player
var _target: Node3D
var _yaw := 0.0
var _pitch := -12.0
var _cooldown := 0.0
var _aim_time := 0.0
var _blocked := 0.0
var _shots := 0
var _stuck_check := 0.0
var _last := Vector3.ZERO
var _detour := 0.0
var _detour_side := 1.0
var _wander := Vector2.INF


func _ready() -> void:
	_player = get_parent() as Player
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var forward := -camera.global_basis.z
		_yaw = atan2(-forward.x, -forward.z)


func _exit_tree() -> void:
	for action: String in HELD:
		Input.action_release(action)


func _physics_process(delta: float) -> void:
	if _player == null or Game.resting or Game.cutscene or not _player.can_act():
		_release_moves()
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		_release_moves()
		return
	match task:
		Task.WAIT:
			task = Task.HUNT if Inventory.has(&"bow") else Task.BOW
		Task.BOW:
			var bow := Game.current_level.get_node_or_null(^"Cave/BowPickup") as Node3D
			if bow == null or Inventory.has(&"bow"):
				task = Task.HUNT
			elif _walk_to(bow.global_position, false, delta):
				_press("interact")
				_cooldown = 1.6
		Task.HUNT:
			_hunt(delta)
		Task.AIM:
			_aim(delta)
		Task.HARVEST:
			if not is_instance_valid(_target):
				task = Task.HUNT
			elif _walk_to(_target.global_position, false, delta):
				_press("interact")
				_target = null
				task = Task.HUNT
				_cooldown = 3.0
		Task.HOME:
			var pelt := Game.current_level.get_node_or_null(^"Cave/Pelt") as Node3D
			if pelt != null and _walk_to(pelt.global_position, false, delta) and Clock.can_sleep():
				_press("interact")
				task = Task.SLEEP
		Task.SLEEP:
			_release_moves()


func _hunt(delta: float) -> void:
	if Clock.hour >= Tuning.AUTOPILOT_SLEEP_HOUR or Clock.hour < 5.0:
		task = Task.HOME
		return
	if not Inventory.has(&"arrow") and not Inventory.has(&"feathered_arrow"):
		# Sem flechas: faz mais (a IA não precisa de madeira, mas o corpo faz o trabalho).
		_release_moves()
		_player.perform(&"craft", Tuning.CRAFT_TIME, [[Tuning.CRAFT_TIME * 0.9, func() -> void: Inventory.add(&"arrow", 4)]])
		return
	if Vitals.satiety < Tuning.AUTOPILOT_EAT_BELOW and (Inventory.has(&"cooked_meat") or Inventory.has(&"meat")):
		_release_moves()
		_press("eat")
		_cooldown = Tuning.EAT_TIME + 0.3
		return
	_target = _pick_prey()
	if _target == null:
		# Nada à vista: anda pelo vale.
		if _wander == Vector2.INF or Vector2(_player.global_position.x, _player.global_position.z).distance_to(_wander) < 3.0:
			_wander = ForestLayout.MEADOW + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		_walk_to(Vector3(_wander.x, 0.0, _wander.y), false, delta)
		return
	var distance := _player.global_position.distance_to(_target.global_position)
	var fleeing := (_target as Animal).state == Animal.State.FLEE
	if distance < (FLEEING_RANGE if fleeing else Tuning.AUTOPILOT_SHOOT_RANGE) and _sees(_target):
		task = Task.AIM
		_aim_time = 0.0
		_blocked = 0.0
		_shots = 0
		_release_moves()
		return
	if fleeing or (_target as Animal).state == Animal.State.SUSPICIOUS:
		# Desconfiado, fica parado até ele voltar a pastar; assustado, não adianta correr atrás.
		_release_moves()
		_hold("crouch", true)
		return
	_walk_to(_target.global_position, distance < Tuning.AUTOPILOT_STALK_RANGE, delta)


func _aim(delta: float) -> void:
	Input.action_release("move_forward")
	if not is_instance_valid(_target) or (_target as Animal).state == Animal.State.DEAD:
		_stop_aiming()
		task = Task.HARVEST if is_instance_valid(_target) else Task.HUNT
		_cooldown = 0.8
		return
	var distance := _player.global_position.distance_to(_target.global_position)
	var fleeing := (_target as Animal).state == Animal.State.FLEE
	# Algo no caminho do arco (um morro, uma árvore): chega mais perto ou contorna.
	_blocked = _blocked + delta if not _sees(_target) else 0.0
	if _shots >= 4 or distance > Tuning.AUTOPILOT_SHOOT_RANGE * 1.4 or _blocked > 0.5 or (fleeing and distance > FLEEING_RANGE * 1.3):
		_stop_aiming()
		task = Task.HUNT
		return
	# De pé: agachado, o arco fica baixo e a flecha bate no capim e no chão.
	_hold("crouch", false)
	_hold("aim", true)
	_point_camera(_aim_point(_target), delta)
	_aim_time += delta
	var drawing := _aim_time > SETTLE and _aim_time < SETTLE + Tuning.AUTOPILOT_DRAW_SECONDS
	_hold("attack", drawing)
	if _aim_time >= SETTLE + Tuning.AUTOPILOT_DRAW_SECONDS + AFTER_SHOT:
		_shots += 1
		_aim_time = 0.0


func _stop_aiming() -> void:
	for action: String in ["aim", "attack", "crouch"]:
		Input.action_release(action)


## A caça mais perto que vale a pena (cervo primeiro; coelho só de perto). Fica com a de antes
## enquanto ela estiver viva e por perto.
func _pick_prey() -> Node3D:
	if is_instance_valid(_target) and _target is Animal and (_target as Animal).state != Animal.State.DEAD:
		if _player.global_position.distance_to(_target.global_position) < 90.0:
			return _target
	var best: Node3D = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(&"animals"):
		var animal := node as Animal
		if animal == null or animal.state == Animal.State.DEAD or animal is WhiteDeer or not (animal is Deer or animal is Rabbit):
			continue
		var distance := _player.global_position.distance_to(animal.global_position)
		var score := distance * (1.0 if animal is Deer else 2.2)
		if distance < 140.0 and score < best_score:
			best_score = score
			best = animal
	return best


## O peito do bicho, um pouco acima pela queda da flecha. Só metade da queda: a mira para no
## próprio corpo do bicho (a flecha vai até onde o meio da tela acerta), e o resto da queda ainda
## cai dentro do peito.
func _aim_point(target: Node3D) -> Vector3:
	var point := target.global_position + Vector3.UP * (1.0 if target is Deer else 0.15)
	var flight := _player.global_position.distance_to(point) / Arrow.SPEED_MAX
	return point + Vector3.UP * 0.25 * Arrow.GRAVITY * flight * flight


## O caminho da flecha está livre: do arco (de pé) até onde ela vai acertar.
func _sees(target: Node3D) -> bool:
	var from := _player.global_position + Vector3.UP * BOW_HEIGHT
	var to := _aim_point(target)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [_player.get_rid()])
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A câmera mira em `point` (a flecha vai para o meio da tela).
func _point_camera(point: Vector3, delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var to := point - camera.global_position
	_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
	_pitch = lerpf(_pitch, rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length())), 1.0 - exp(-10.0 * delta))
	_player.set_camera_angles(rad_to_deg(_yaw), _pitch)


## Anda até `point` (agachado com `sneak`). Entre a caverna e o vale, passa pela boca. Devolve
## true quando chegou.
func _walk_to(point: Vector3, sneak: bool, delta: float) -> bool:
	var here := _player.global_position
	var goal := Vector2(point.x, point.z)
	var flat := Vector2(here.x, here.z)
	var inside_here := ForestLayout.cave_interior(flat) > 0.05
	var inside_goal := ForestLayout.cave_interior(goal) > 0.05
	if inside_here != inside_goal and flat.distance_to(MOUTH) > 1.5:
		goal = MOUTH
	var to := Vector3(goal.x - here.x, 0.0, goal.y - here.z)
	if goal != MOUTH and to.length() < ARRIVE:
		_release_moves()
		return true
	var direction := _avoid(to.normalized(), delta)
	_yaw = lerp_angle(_yaw, atan2(-direction.x, -direction.z), 1.0 - exp(-6.0 * delta))
	_pitch = lerpf(_pitch, -12.0, 1.0 - exp(-3.0 * delta))
	_player.set_camera_angles(rad_to_deg(_yaw), _pitch)
	Input.action_press("move_forward")
	_hold("crouch", sneak)
	Input.action_release("aim")
	Input.action_release("attack")
	return false


## Desvia de árvore no caminho e, se ficou preso, tenta de lado um pouco.
func _avoid(direction: Vector3, delta: float) -> Vector3:
	var here := _player.global_position
	_stuck_check -= delta
	if _stuck_check <= 0.0:
		_stuck_check = 1.5
		if here.distance_to(_last) < 0.35 and _detour <= 0.0:
			_detour = 1.4
			_detour_side = -_detour_side
		_last = here
	if _detour > 0.0:
		_detour -= delta
		return direction.rotated(Vector3.UP, 1.3 * _detour_side)
	var level := Game.current_level
	if level != null and level.has_method("tree_near") and level.tree_near(here + direction * 1.4, 0.9) != -1:
		return direction.rotated(Vector3.UP, 0.9 * _detour_side)
	return direction


func _hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_moves() -> void:
	for action: String in HELD:
		Input.action_release(action)


## Aperta e solta uma ação, como uma tecla (o E, o F).
func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
