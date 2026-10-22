extends Node3D
## Fogueira quase apagada: brasas, chamas baixas, fumaça, luz tremendo e estalos.

@export var base_energy := 1.0
@export var stone_material: Material

var _noise := FastNoiseLite.new()
var _time := 0.0

@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	_noise.frequency = 1.5
	_build_stone_ring()


func _process(delta: float) -> void:
	_time += delta
	var flicker := _noise.get_noise_1d(_time * 6.0) * 0.5 + 0.5
	_light.light_energy = base_energy * (0.6 + 0.5 * flicker)
	_light.position = Vector3(
		_noise.get_noise_1d(_time * 3.0 + 100.0) * 0.06,
		0.45 + flicker * 0.05,
		_noise.get_noise_1d(_time * 3.0 + 200.0) * 0.06
	)


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
