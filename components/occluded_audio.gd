class_name OccludedAudio
extends AudioStreamPlayer3D
## Som 3D que fica abafado quando há terreno ou rocha entre ele e quem escuta.
##
## A cada poucos décimos de segundo lança um raio da câmera (o ouvinte) até o som,
## só contra a camada "world" (terreno, caverna, pedras). Bloqueado, o som passa
## para o bus "...Muffled" (passa-baixa) e perde volume; livre, volta ao bus normal.

## Camada de física que bloqueia som (1 = world).
const OCCLUSION_MASK := 1

## Bus quando o caminho está livre ("World" ou "Ambience").
@export var clear_bus := &"World"
@export var check_interval := 0.3
## Quanto o volume cai (dB) quando abafado.
@export var occluded_drop_db := 6.0

var _timer := 0.0
var _base_volume_db := 0.0
var _occluded := false


## Toca um som solto num ponto e se apaga sozinho no fim.
static func play_at(parent: Node, stream: AudioStream, at: Vector3, bus_name := &"World", volume := 0.0, size := 6.0, pitch := 1.0) -> OccludedAudio:
	var sound := OccludedAudio.new()
	sound.stream = stream
	sound.clear_bus = bus_name
	sound.bus = bus_name
	sound.volume_db = volume
	sound.unit_size = size
	sound.max_distance = size * 25.0
	sound.pitch_scale = pitch
	sound.finished.connect(sound.queue_free)
	parent.add_child(sound)
	sound.global_position = at
	sound.play()
	return sound


func _ready() -> void:
	_base_volume_db = volume_db
	_timer = randf() * check_interval
	bus = clear_bus


func _physics_process(delta: float) -> void:
	if not playing:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = check_interval
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.global_position
	var to := global_position
	# Para meio metro antes da fonte: ela costuma estar encostada no chão ou numa árvore.
	var length := from.distance_to(to)
	if length < 1.0:
		_set_occluded(false)
		return
	to = from.lerp(to, (length - 0.5) / length)
	var query := PhysicsRayQueryParameters3D.create(from, to, OCCLUSION_MASK)
	_set_occluded(not get_world_3d().direct_space_state.intersect_ray(query).is_empty())


## Volume "de projeto" do som; use em vez de volume_db quando o volume muda em tempo real.
func set_base_volume(db: float) -> void:
	_base_volume_db = db
	volume_db = db - (occluded_drop_db if _occluded else 0.0)


func _set_occluded(value: bool) -> void:
	if value == _occluded:
		return
	_occluded = value
	bus = StringName(String(clear_bus) + "Muffled") if value else clear_bus
	volume_db = _base_volume_db - (occluded_drop_db if value else 0.0)
