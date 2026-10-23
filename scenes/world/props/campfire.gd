class_name Campfire
extends Node3D
## Fogueira: brasas, chamas, fumaça, luz tremendo e estalos, do tamanho da lenha que tem.
##
## A lenha (0..Tuning.FIRE_MAX_FUEL) queima com o tempo, também enquanto o goblin dorme.
## Com 0 ficam só as brasas: luz fraca e sem cozinhar. O goblin põe lenha e assa carne
## com E (interagível); a fogueira cheia ilumina o teto da caverna.

const SIZZLE := preload("res://assets/audio/ambience/sizzle_loop.wav")
const FEED_SOUNDS := [preload("res://assets/audio/real/tree_hit_3.ogg"), preload("res://assets/audio/real/wood_creak_2.ogg")]

## Grupo dos fogos acesos ou não (fogueira, e depois tocha): esquentam e espantam lobos.
## Membros implementam is_lit().
const FIRE_GROUP := &"fire"

@export var base_energy := 1.0
@export var stone_material: Material

## Lenha que resta (fração queimando).
var fuel := Tuning.FIRE_START_FUEL

var _noise := FastNoiseLite.new()
var _time := 0.0
var _rest := {}
var _sizzle: OccludedAudio

@onready var _light: OmniLight3D = $Light
@onready var _flames: GPUParticles3D = $Flames
@onready var _smoke: GPUParticles3D = $Smoke
@onready var _sparks: GPUParticles3D = $Sparks
@onready var _crackle: OccludedAudio = $Crackle


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"persist")
	add_to_group(FIRE_GROUP)
	_noise.frequency = 1.5
	_build_stone_ring()
	_rest = {"energy": base_energy, "range": _light.omni_range, "crackle": _crackle.volume_db}
	Clock.skipped.connect(_on_time_skipped)
	_apply_fuel()


func _process(delta: float) -> void:
	_time += delta
	if not Game.resting:
		_burn(delta)
	var flicker := _noise.get_noise_1d(_time * 6.0) * 0.5 + 0.5
	_light.light_energy = base_energy * (0.6 + 0.5 * flicker)
	_light.position = Vector3(
		_noise.get_noise_1d(_time * 3.0 + 100.0) * 0.06,
		0.45 + flicker * 0.05,
		_noise.get_noise_1d(_time * 3.0 + 200.0) * 0.06
	)


func is_lit() -> bool:
	return fuel > 0.0


## Distância (no chão) de `at` até o fogo aceso mais próximo; INF se não há nenhum.
static func distance_to_fire(at: Vector3) -> float:
	var best := INF
	for node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(FIRE_GROUP):
		var fire := node as Node3D
		if fire.is_lit():
			best = minf(best, Vector2(fire.global_position.x - at.x, fire.global_position.z - at.z).length())
	return best


func add_fuel(amount := 1.0) -> void:
	fuel = minf(fuel + amount, Tuning.FIRE_MAX_FUEL)
	_apply_fuel()


# --- Interação -------------------------------------------------------------------

func interaction_prompt() -> String:
	match _next_use():
		&"feed":
			return "Pôr lenha na fogueira" if is_lit() else "Acender a fogueira com madeira"
		&"cook":
			return "Assar carne"
	if not is_lit():
		return "Fogueira apagada: precisa de madeira"
	return ""


func interaction_enabled() -> bool:
	return _next_use() != &""


func interaction_action() -> Dictionary:
	if _next_use() == &"cook":
		return {"action": &"cook", "duration": Tuning.COOK_TIME, "at": Tuning.COOK_DONE_AT}
	return {"action": &"pickup", "duration": Tuning.FEED_TIME, "at": Tuning.FEED_AT}


func interaction_started(player: Node) -> void:
	if _next_use() != &"cook":
		return
	var meat := (player as Player).hold_in_hand(MeatMesh.instance(false), Tuning.COOK_DONE_AT + 0.3) as MeshInstance3D
	MeatMesh.cook(meat, Tuning.COOK_DONE_AT * 0.8)
	_sizzle = OccludedAudio.play_at(self, SIZZLE, global_position + Vector3.UP * 0.3, &"World", -10.0, 2.0)
	_sizzle.finished.disconnect(_sizzle.queue_free)
	var fade_in := create_tween()
	fade_in.tween_method(_sizzle.set_base_volume, -24.0, -8.0, 1.2)
	# Se a ação for cortada (desmaio), o chiado para sozinho.
	get_tree().create_timer(Tuning.COOK_TIME + 0.5, false).timeout.connect(_stop_sizzle)


func interact(_player: Node) -> void:
	var use := _next_use()
	if use == &"cook" and Inventory.remove(&"meat"):
		Inventory.add(&"cooked_meat")
		Events.notification_shown.emit("+1 carne assada")
	elif use == &"feed" and Inventory.remove(&"wood"):
		add_fuel()
		OccludedAudio.play_at(self, FEED_SOUNDS.pick_random(), global_position + Vector3.UP * 0.2, &"World", -8.0, 2.5, randf_range(0.9, 1.1))
	_stop_sizzle()


## O que o E faria agora: acender quando apagada, assar se há chama e carne, senão
## completar a lenha. Vazio = nada a fazer.
func _next_use() -> StringName:
	var has_wood := Inventory.has(&"wood")
	if not is_lit():
		return &"feed" if has_wood else &""
	if Inventory.has(&"meat"):
		return &"cook"
	if has_wood and fuel <= Tuning.FIRE_MAX_FUEL - 1.0:
		return &"feed"
	return &""


func _stop_sizzle() -> void:
	if _sizzle == null:
		return
	var sizzle := _sizzle
	_sizzle = null
	var fade_out := create_tween()
	fade_out.tween_method(sizzle.set_base_volume, -8.0, -30.0, 0.8)
	fade_out.tween_callback(sizzle.queue_free)


func save_data() -> Dictionary:
	return {"fuel": fuel}


func load_data(data: Dictionary) -> void:
	fuel = float(data.get("fuel", Tuning.FIRE_START_FUEL))
	_apply_fuel()


# --- Tamanho do fogo ---------------------------------------------------------------

func _on_time_skipped(hours: float) -> void:
	_burn(hours * Tuning.SECONDS_PER_HOUR)


func _burn(seconds: float) -> void:
	if fuel <= 0.0:
		return
	var before := ceilf(fuel)
	fuel = maxf(fuel - seconds / Tuning.FIRE_SECONDS_PER_FUEL, 0.0)
	if ceilf(fuel) != before or fuel <= 0.0:
		_apply_fuel()


## Chama, fumaça, faíscas, luz e estalos pelo tamanho do fogo: 1 de lenha é a fogueira
## quase apagada do começo; cheia, ela clareia o salão todo.
func _apply_fuel() -> void:
	var size := _fire_size()
	_flames.emitting = is_lit()
	_sparks.emitting = is_lit()
	var grow := clampf(size - 1.0, 0.0, 1.0)
	# As partículas da cena têm o máximo da fogueira cheia; com 1 lenha, ~60%.
	_flames.amount_ratio = lerpf(0.6, 1.0, grow)
	_sparks.amount_ratio = lerpf(0.55, 1.0, grow)
	_smoke.amount_ratio = lerpf(0.7, 1.0, grow) if is_lit() else 0.35
	base_energy = _rest.energy * (lerpf(1.0, 1.9, grow) if is_lit() else 0.18)
	_light.omni_range = _rest.range * (lerpf(1.0, 1.45, grow) if is_lit() else 0.45)
	_crackle.set_base_volume(_rest.crackle + (linear_to_db(lerpf(1.0, 1.6, grow)) if is_lit() else -14.0))


## 0 apagada .. 1 com uma lenha .. 2 cheia.
func _fire_size() -> float:
	var logs := ceilf(fuel)
	return 0.0 if logs <= 0.0 else 1.0 + (logs - 1.0) / (Tuning.FIRE_MAX_FUEL - 1.0)


func _build_stone_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.16
	mesh.radial_segments = 7
	mesh.rings = 4
	for i in 9:
		var angle := TAU * i / 9 + rng.randf_range(-0.12, 0.12)
		var stone := MeshInstance3D.new()
		stone.mesh = mesh
		stone.material_override = stone_material
		stone.position = Vector3(cos(angle), 0.03, sin(angle)) * 0.42
		stone.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		stone.scale = Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.0), rng.randf_range(0.8, 1.3))
		add_child(stone)
