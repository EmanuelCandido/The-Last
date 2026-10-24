class_name ColdExposure
extends Node
## Frio do lugar: mede quanto o goblin esfria ou esquenta agora (noite, caverna, vento,
## fogo perto, roupa) e põe em Vitals.cold. Mostra o frio no corpo: vapor da respiração
## na noite fria, dentes batendo e o aviso. O tremor fica no GoblinAnimator (Player lê).
##
## Parte do goblin: um nó filho do Player. Tirar o nó tira o frio.

const CHATTER := preload("res://assets/audio/real/teeth_chatter.ogg")
## Onde sai o vapor da respiração, no espaço do Visual (o goblin olha para +Z).
const MOUTH := Vector3(0.0, 0.7, 0.16)
## Segundos de uma respiração (inspira e solta o vapor).
const BREATH_PERIOD := 2.4

var _breath: CPUParticles3D
var _breath_time := 0.0
var _chatter_timer := 3.0
var _warned := false

@onready var _player: Player = get_parent()


func _ready() -> void:
	_breath = _build_breath()
	_player.get_node("Visual").add_child.call_deferred(_breath)


func _process(delta: float) -> void:
	if Game.resting:
		_breath.emitting = false
		return
	Vitals.add_cold(exposure() * delta)
	_update_breath(delta)
	_update_warning(delta)


## Frio ganho por segundo agora (negativo = esquentando).
func exposure() -> float:
	var at := _player.global_position
	var night := Clock.night()
	var indoor := _indoor(at)
	var rate := lerpf(lerpf(Tuning.COLD_DAY, Tuning.COLD_NIGHT_OUTSIDE, night), lerpf(Tuning.COLD_DAY, Tuning.COLD_NIGHT_CAVE, night), indoor)
	# Molhado: a chuva esfria fora da toca e longe da copa das árvores.
	var level := Game.current_level
	var canopy: float = level.canopy_at(at) if level != null and level.has_method("canopy_at") else 0.0
	var wet := Weather.rain * (1.0 - indoor) * (1.0 - smoothstep(0.0, Tuning.CANOPY_SHELTER, canopy))
	# Molhado, o dia não esquenta: a chuva tira o calor e soma o frio dela.
	if wet > 0.01:
		rate = lerpf(rate, maxf(rate, 0.0), wet) + Tuning.RAIN_COLD * wet
	if rate > 0.0:
		rate *= 0.5 + Wind.strength_at(at)
		if Inventory.has(&"clothes"):
			rate *= Tuning.CLOTHES_COLD_FACTOR
	if Campfire.distance_to_fire(at) < Tuning.FIRE_WARM_RADIUS:
		rate = minf(rate, Tuning.FIRE_WARMTH)
	return rate


func _indoor(at: Vector3) -> float:
	var level := Game.current_level
	return float(level.indoor_at(at)) if level != null and level.has_method("indoor_at") else 0.0


## Na noite fria e fora da toca, cada expiração solta uma nuvenzinha.
func _update_breath(delta: float) -> void:
	var at := _player.global_position
	var chilly := maxf(Clock.night() * (1.0 - _indoor(at)), smoothstep(30.0, 60.0, Vitals.cold))
	_breath_time = fmod(_breath_time + delta * (1.6 if _player.noise_level() > 0.5 else 1.0), BREATH_PERIOD)
	_breath.emitting = chilly > 0.35 and _breath_time > BREATH_PERIOD * 0.6 and not _player.breath_held


func _update_warning(delta: float) -> void:
	if Vitals.cold < 30.0:
		_warned = false
	elif Vitals.is_cold() and not _warned:
		_warned = true
		Events.notification_shown.emit("Com frio. Procure fogo ou a toca.")
	if Vitals.cold < 70.0:
		return
	_chatter_timer -= delta
	if _chatter_timer <= 0.0:
		_chatter_timer = randf_range(4.0, 8.0)
		OccludedAudio.play_at(_player, CHATTER, _player.global_position + Vector3.UP * 0.7, &"World", -10.0, 1.5, randf_range(0.9, 1.1))


func _build_breath() -> CPUParticles3D:
	var breath := CPUParticles3D.new()
	breath.name = "Breath"
	breath.position = MOUTH
	breath.emitting = false
	breath.amount = 10
	breath.lifetime = 1.3
	breath.local_coords = false
	breath.direction = Vector3(0.0, 0.25, 1.0)
	breath.spread = 18.0
	breath.initial_velocity_min = 0.2
	breath.initial_velocity_max = 0.35
	breath.gravity = Vector3(0.0, 0.06, 0.0)
	breath.damping_min = 0.3
	breath.damping_max = 0.6
	breath.scale_amount_min = 0.6
	breath.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	breath.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.22))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	breath.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.85, 0.88, 0.92)
	material.roughness = 1.0
	quad.material = material
	breath.mesh = quad
	return breath
