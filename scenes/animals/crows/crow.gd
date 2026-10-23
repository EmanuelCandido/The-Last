class_name Crow
extends Node3D
## Um corvo. No bando (CrowFlock), voa em círculos levado por ele; sozinho, é um espião do
## Zelador (Watchers): desce planando, pousa, segue o goblin com a cabeça e vai embora.
## Uma flechada o derruba: cai rodando até o chão e vira caça para pegar as penas
## (Tuning.CROW_FEATHERS), com as flechas presas nele.

signal shot

enum Mode { FLOCK, LANDING, PERCHED, LEAVING, FALLING, DOWN }

const HIT_LAYER := 8
const PICKUP_SOUND := preload("res://assets/audio/real/pickup_1.ogg")
const FLAP_SOUND := preload("res://assets/audio/animals/wing_flap.wav")
const CAWS := [preload("res://assets/audio/animals/crow_1.wav"), preload("res://assets/audio/animals/crow_2.wav")]
## A voz do Zelador saindo do bico (Ato III).
const KEEPER_VOICE := preload("res://assets/audio/sfx/keeper_voice_1.wav")
## Segundos descendo até o pouso e de onde vem (m acima e para o lado).
const LANDING_TIME := 2.2
const LANDING_FROM := Vector3(6.0, 12.0, 0.0)
## Visão do corvo pousado (olhos na altura da cabeça).
const EYE_HEIGHT := 0.25
## Pousado, em pé: o corpo inclina de rabo para baixo (rad) e fica nesta altura do chão (m).
const PERCH_PITCH := -0.6
const PERCH_HEIGHT := 0.13

var terrain: Terrain
var wings: Array[Node3D] = []
var dead := false
var mode := Mode.FLOCK
## Pousado, a cabeça segue isto (o goblin).
var watch: Node3D
## Pousado sem crocitar (a pista do Ato I).
var silent := false
## O primeiro crocito pousado vira esta fala do Zelador, com legenda (vazio = só corvo).
var speech := ""

var _head: Node3D
var _legs: Node3D
var _fall_speed := 0.0
var _spin := Vector3.ZERO
var _timer := 0.0
var _perch := Vector3.ZERO
var _watch_seconds := 0.0
var _from := Vector3.ZERO
var _caw_timer := 0.0
var _voice: AudioStreamPlayer3D


func _ready() -> void:
	var feathers := Animal.flat_material(Color(0.05, 0.05, 0.06))
	var beak := Animal.flat_material(Color(0.18, 0.17, 0.16))
	_part(self, Vector3(0.12, 0.1, 0.38), Vector3.ZERO, feathers)
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.03, 0.2)
	add_child(_head)
	_part(_head, Vector3(0.09, 0.09, 0.1), Vector3(0.0, 0.0, 0.02), feathers)
	_part(_head, Vector3(0.03, 0.03, 0.09), Vector3(0.0, -0.01, 0.1), beak)
	_part(self, Vector3(0.14, 0.02, 0.15), Vector3(0.0, 0.0, -0.25), feathers)
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.05 * side, 0.03, 0.0)
		add_child(wing)
		_part(wing, Vector3(0.5, 0.015, 0.2), Vector3(0.25 * side, 0.0, 0.0), feathers)
		wings.append(wing)
	# As pernas só aparecem pousado (em voo ficam recolhidas).
	_legs = Node3D.new()
	_legs.visible = false
	# O corpo pousado inclina: as pernas desfazem a inclinação e ficam em pé.
	_legs.rotation.x = -PERCH_PITCH
	add_child(_legs)
	for side in [-1.0, 1.0]:
		_part(_legs, Vector3(0.012, 0.11, 0.012), Vector3(0.03 * side, -0.09, 0.06), beak)
	# Área de acerto um pouco maior que o corpo com as asas abertas: alvo alto e rápido.
	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = HIT_LAYER
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.3, 0.55)
	shape.shape = box
	hitbox.add_child(shape)
	add_child(hitbox)
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"Ambience"
	_voice.unit_size = 6.0
	_voice.max_distance = 80.0
	add_child(_voice)


func _physics_process(delta: float) -> void:
	match mode:
		Mode.LANDING:
			_timer += delta
			var t := clampf(_timer / LANDING_TIME, 0.0, 1.0)
			var eased := 1.0 - (1.0 - t) * (1.0 - t)
			position = _from.lerp(_perch, eased)
			var travel := _perch - _from
			rotation = Vector3(0.0, atan2(travel.x, travel.z), 0.0)
			_flap(0.15 if t < 0.7 else sin(_timer * 16.0) * 0.8)
			if t >= 1.0:
				mode = Mode.PERCHED
				_timer = _watch_seconds
		Mode.PERCHED:
			_timer -= delta
			_fold_wings()
			# Em pé: o peito sobe e as pernas descem (o corpo de caixa deitado parecia um tijolo).
			rotation.x = lerp_angle(rotation.x, PERCH_PITCH, 1.0 - exp(-8.0 * delta))
			position.y = lerpf(position.y, _perch.y - 0.07 + PERCH_HEIGHT, 1.0 - exp(-8.0 * delta))
			_legs.visible = true
			_look_at_watch(delta)
			_caw_timer -= delta
			if speech != "" and _caw_timer <= 0.0:
				_caw_timer = randf_range(5.0, 9.0)
				_voice.stream = KEEPER_VOICE
				_voice.pitch_scale = 1.12
				_voice.play()
				Game.vision.say(speech, 3.2)
				speech = ""
			elif not silent and _caw_timer <= 0.0:
				_caw_timer = randf_range(4.0, 9.0)
				_voice.stream = CAWS.pick_random()
				_voice.pitch_scale = randf_range(0.9, 1.1)
				_voice.play()
			if _timer <= 0.0:
				leave()
		Mode.LEAVING:
			_timer += delta
			rotation.x = lerp_angle(rotation.x, 0.0, 1.0 - exp(-6.0 * delta))
			_legs.visible = false
			var away := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
			position += (away * 7.0 + Vector3.UP * 4.0) * delta
			_flap(sin(_timer * 14.0) * 0.8)
			if _timer > 5.0:
				queue_free()
		Mode.FALLING:
			_fall_speed = minf(_fall_speed + 9.8 * delta, 18.0)
			position.y -= _fall_speed * delta
			rotation += _spin * delta
			var ground := terrain.get_height(position.x, position.z) if terrain != null else 0.0
			if position.y <= ground + 0.06:
				mode = Mode.DOWN
				position.y = ground + 0.06
				rotation = Vector3(0.0, rotation.y, PI * 0.5)
				add_to_group(&"interactable")


## Desce planando até `at` e fica pousado `seconds` segundos olhando `target`.
func perch(at: Vector3, target: Node3D, seconds: float) -> void:
	# A origem é o meio do corpo: pousado, fica um pouco acima do chão.
	_perch = at + Vector3.UP * 0.07
	watch = target
	_timer = 0.0
	var side := LANDING_FROM.rotated(Vector3.UP, randf() * TAU)
	_from = at + side
	position = _from
	mode = Mode.LANDING
	_watch_seconds = seconds
	_caw_timer = randf_range(1.5, 4.0)


## Levanta voo e some.
func leave() -> void:
	if mode != Mode.PERCHED and mode != Mode.LANDING:
		return
	mode = Mode.LEAVING
	_timer = 0.0
	OccludedAudio.play_at(get_parent(), FLAP_SOUND, global_position, &"Ambience", -6.0, 4.0, randf_range(0.9, 1.1))


func is_perched() -> bool:
	return mode == Mode.PERCHED


## Pousado, vê `point` (dentro de Tuning.SPY_SIGHT e sem rocha ou árvore no meio).
func sees(point: Vector3) -> bool:
	if mode != Mode.PERCHED:
		return false
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	if eye.distance_to(point) > Tuning.SPY_SIGHT:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point, 1 | 2)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Flechada (mesmo contrato do Animal): qualquer acerto derruba.
func take_hit(_power: float, _point: Vector3, _direction: Vector3, _damage := 1.0) -> void:
	if dead:
		return
	dead = true
	mode = Mode.FALLING
	_spin = Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-8.0, 8.0))
	_flap(0.9)
	var hitbox := get_node_or_null(^"Hitbox")
	if hitbox != null:
		hitbox.queue_free()
	shot.emit()
	Events.crow_shot.emit()


func body_node() -> Node3D:
	return self


func interaction_prompt() -> String:
	return "Pegar as penas" if mode == Mode.DOWN else ""


func interact(_player: Node) -> void:
	Events.animal_harvested.emit(&"crow")
	Arrow.collect_from(self)
	Inventory.add(&"feather", Tuning.CROW_FEATHERS)
	Events.notification_shown.emit("+%d penas" % Tuning.CROW_FEATHERS)
	OccludedAudio.play_at(get_parent(), PICKUP_SOUND, global_position, &"World", -4.0, 3.0)
	queue_free()


## Asas abertas num ângulo (o bando também usa).
func flap(angle: float) -> void:
	_flap(angle)


func _flap(angle: float) -> void:
	wings[0].rotation.z = -angle
	wings[1].rotation.z = angle


## Pousado: asas fechadas junto do corpo, as pontas passando um pouco do rabo.
func _fold_wings() -> void:
	wings[0].rotation = Vector3(0.0, -1.45, -0.35)
	wings[1].rotation = Vector3(0.0, 1.45, 0.35)


## A cabeça segue o alvo (até 100° para cada lado; além disso o corpo vira aos poucos).
func _look_at_watch(delta: float) -> void:
	if watch == null or not is_instance_valid(watch):
		return
	var to := watch.global_position + Vector3.UP * 0.6 - _head.global_position
	var local := global_basis.inverse() * to
	var yaw := atan2(local.x, local.z)
	if absf(yaw) > deg_to_rad(100.0):
		rotation.y += signf(yaw) * delta * 1.5
	yaw = clampf(yaw, -deg_to_rad(100.0), deg_to_rad(100.0))
	var pitch := -atan2(local.y, Vector2(local.x, local.z).length())
	_head.rotation = Vector3(clampf(pitch, -0.8, 0.8), yaw, 0.0)


func _part(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = center
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
