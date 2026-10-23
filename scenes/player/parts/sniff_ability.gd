class_name SniffAbility
extends Node
## Farejar (segurar "sniff", X), §4.8: o goblin agacha parado e fareja. O mundo abafa
## (o som fecha), o vento aparece como riscos finos no ar e cada bicho a até
## Tuning.SNIFF_RANGE cujo cheiro o vento traz (o bicho está contra o vento) solta uma
## trilha de cheiro que corre dele até o goblin. Farejando não faz barulho. Dura no máximo
## Tuning.SNIFF_MAX_SECONDS; para farejar de novo, solta e aperta outra vez.
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira a mecânica.

const SNIFF_SOUND := preload("res://assets/audio/sfx/sniff.wav")
## Cor da trilha de cada espécie (o resto usa DEFAULT_SCENT).
const SCENT_COLORS := {
	&"deer": Color(0.78, 0.36, 0.06),
	&"rabbit": Color(0.62, 0.55, 0.12),
	&"wolf": Color(0.7, 0.08, 0.04),
}
const DEFAULT_SCENT := Color(0.5, 0.5, 0.3)
## Segundos que uma partícula de cheiro leva do bicho até o goblin.
const TRAIL_TRAVEL := 2.4
## Altura da trilha (m): acima do capim alto, que a esconderia.
const TRAIL_HEIGHT := 1.0
## A trilha some a esta distância do goblin (m), sem entrar no rosto dele.
const TRAIL_STOP := 1.5

var _active := false
## Passou do máximo: só fareja de novo depois de soltar a tecla.
var _spent := false
var _time := 0.0
var _sound_timer := 0.0
var _wind: CPUParticles3D
## Trilhas de cheiro ligadas agora: Animal -> CPUParticles3D.
var _trails := {}

@onready var _player: Player = get_parent()


func _ready() -> void:
	_wind = _build_wind()
	add_child(_wind)


func _physics_process(delta: float) -> void:
	var held := Input.is_action_pressed("sniff")
	if not held:
		_spent = false
	var want := held and not _spent and _player.can_act() and _player.is_on_floor() and not _player.aiming
	if want != _active:
		_set_active(want)
	if not _active:
		return
	_time += delta
	if _time >= Tuning.SNIFF_MAX_SECONDS:
		_spent = true
		_set_active(false)
		return
	_sound_timer -= delta
	if _sound_timer <= 0.0:
		_sound_timer = randf_range(1.0, 1.5)
		OccludedAudio.play_at(_player, SNIFF_SOUND, _player.global_position + Vector3.UP * 0.6, &"World", -8.0, 1.5, randf_range(0.92, 1.08))
	_update_wind()
	_update_trails()


## Bichos cujo cheiro chega no goblin agora (o vento sopra deles para ele).
func scented_animals() -> Array[Animal]:
	var found: Array[Animal] = []
	var at := _player.global_position
	for node in get_tree().get_nodes_in_group(&"animals"):
		var animal := node as Animal
		var to_goblin := Vector2(at.x - animal.global_position.x, at.z - animal.global_position.z)
		var distance := to_goblin.length()
		if distance > Tuning.SNIFF_RANGE or distance < 0.5:
			continue
		if to_goblin.normalized().dot(Wind.direction) >= Tuning.SNIFF_DOWNWIND:
			found.append(animal)
	return found


func is_active() -> bool:
	return _active


func _set_active(on: bool) -> void:
	_active = on
	_player.sniffing = on
	_wind.emitting = on
	if on:
		_time = 0.0
		_sound_timer = 0.0
		_player.noise_factors[&"sniff"] = 0.0
		Game.close_ears(0.35, Tuning.SNIFF_MUFFLE_DB, Tuning.SNIFF_MUFFLE_HZ)
		return
	_player.noise_factors.erase(&"sniff")
	for animal: Variant in _trails:
		_stop_trail(_trails[animal])
	_trails.clear()
	# Dormindo ou morrendo, o Game já está fechando o som: não abre por cima.
	if not Game.resting:
		Game.open_ears(0.6, Tuning.SNIFF_MUFFLE_DB, Tuning.SNIFF_MUFFLE_HZ)


func _update_wind() -> void:
	var at := _player.global_position
	var strength := Wind.strength_at(at)
	_wind.global_position = at + Vector3.UP * 1.0
	_wind.direction = Vector3(Wind.direction.x, 0.0, Wind.direction.y)
	_wind.initial_velocity_min = 1.5 + strength * 4.0
	_wind.initial_velocity_max = 2.5 + strength * 6.0


func _update_trails() -> void:
	var scented := scented_animals()
	for animal: Variant in _trails.keys():
		if not is_instance_valid(animal) or not scented.has(animal):
			_stop_trail(_trails[animal])
			_trails.erase(animal)
	var goal := _player.global_position + Vector3.UP * TRAIL_HEIGHT
	for animal in scented:
		if not _trails.has(animal):
			_trails[animal] = _build_trail(SCENT_COLORS.get(animal.kind, DEFAULT_SCENT))
			add_child(_trails[animal])
		var trail: CPUParticles3D = _trails[animal]
		var from := animal.global_position + Vector3.UP * TRAIL_HEIGHT
		trail.global_position = from
		var to_goblin := goal - from
		trail.direction = to_goblin.normalized()
		var speed := maxf(to_goblin.length() - TRAIL_STOP, 0.5) / TRAIL_TRAVEL
		trail.initial_velocity_min = speed * 0.92
		trail.initial_velocity_max = speed * 1.05


## Desliga a trilha e a apaga quando as últimas partículas chegarem.
func _stop_trail(trail: Variant) -> void:
	if not is_instance_valid(trail):
		return
	var particles := trail as CPUParticles3D
	particles.emitting = false
	get_tree().create_timer(particles.lifetime + 0.2, false).timeout.connect(particles.queue_free)


func _build_trail(color: Color) -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.amount = 160
	trail.lifetime = TRAIL_TRAVEL
	trail.local_coords = false
	trail.spread = 3.0
	trail.gravity = Vector3.ZERO
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.15
	# O cheiro ondula no ar enquanto vem.
	trail.tangential_accel_min = -0.6
	trail.tangential_accel_max = 0.6
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	fade.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.75), Color(color, 0.6), Color(color, 0.0)])
	trail.color_ramp = fade
	trail.mesh = _mote_mesh(Vector2(0.09, 0.09), true)
	# É o faro do goblin: a trilha se vê por cima do capim e das árvores no caminho.
	(trail.mesh.surface_get_material(0) as StandardMaterial3D).no_depth_test = true
	return trail


## Riscos finos e claros que correm com o vento em volta do goblin.
func _build_wind() -> CPUParticles3D:
	var wind := CPUParticles3D.new()
	wind.name = "WindStreaks"
	wind.emitting = false
	wind.amount = 70
	wind.lifetime = 1.4
	wind.local_coords = false
	wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	wind.emission_ring_axis = Vector3.UP
	wind.emission_ring_height = 2.4
	wind.emission_ring_radius = 8.0
	wind.emission_ring_inner_radius = 2.5
	wind.spread = 6.0
	wind.gravity = Vector3.ZERO
	wind.particle_flag_align_y = true
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	var streak := Color(0.86, 0.9, 0.95)
	fade.colors = PackedColorArray([Color(streak, 0.0), Color(streak, 0.22), Color(streak, 0.22), Color(streak, 0.0)])
	wind.color_ramp = fade
	var box := BoxMesh.new()
	box.size = Vector3(0.006, 0.32, 0.006)
	box.material = _mote_material(false)
	wind.mesh = box
	return wind


static func _mote_mesh(size: Vector2, billboard: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _mote_material(billboard)
	return quad


## Sem luz e sem neblina: é um sentido do goblin, não algo do mundo; tem que se ver de longe.
static func _mote_material(billboard: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.disable_fog = true
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return material
