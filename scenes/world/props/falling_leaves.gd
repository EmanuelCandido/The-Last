extends GPUParticles3D
## Folhas caindo da árvore velha: caem mais e voam mais longe quando a rajada pega
## a copa. Também controla o farfalhar da copa.

## Fração de folhas caindo com vento fraco.
@export var calm_ratio := 0.08

@onready var _rustle: OccludedAudio = $Rustle
@onready var _process_material := process_material as ParticleProcessMaterial


func _process(_delta: float) -> void:
	var strength := Wind.strength_at(global_position)
	var gust := smoothstep(0.25, 0.85, strength)
	amount_ratio = lerpf(calm_ratio, 1.0, gust)
	var push := Wind.direction * strength * 2.2
	_process_material.gravity = Vector3(push.x, -0.9, push.y)
	_rustle.set_base_volume(linear_to_db(lerpf(0.15, 1.0, gust)))
