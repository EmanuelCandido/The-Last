class_name StonePile
extends Node3D
## Monte de pedras soltas (ForestLayout.STONE_PILES): E enche a mão até Tuning.STONE_MAX.
## Pedra solta não acaba.

const PICKUP_SOUND := preload("res://assets/audio/real/pickup_3.ogg")
const STONES := 9


## Monta as pedras assentadas no chão. `height_at(x, z)` dá a altura do terreno.
func build(height_at: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(position.x), roundi(position.z)))
	for i in STONES:
		var offset := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 0.4
		var radius := rng.randf_range(0.035, 0.07)
		var stone := MeshInstance3D.new()
		stone.mesh = ThrownStone.stone_mesh(rng.randi(), radius)
		add_child(stone)
		var ground: float = height_at.call(position.x + offset.x, position.z + offset.y)
		stone.position = Vector3(offset.x, ground - position.y + radius * 0.4, offset.y)
		stone.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	add_to_group(&"interactable")


func interaction_prompt() -> String:
	return "Pegar pedras" if interaction_enabled() else "Já leva pedras demais"


func interaction_enabled() -> bool:
	return Inventory.count(&"stone") < Tuning.STONE_MAX


func interact(_player: Node) -> void:
	var taken := Tuning.STONE_MAX - Inventory.count(&"stone")
	if taken <= 0:
		return
	Inventory.add(&"stone", taken)
	OccludedAudio.play_at(get_parent(), PICKUP_SOUND, global_position, &"World", -4.0, 3.0)
	Events.notification_shown.emit("+%d pedra%s (G para jogar)" % [taken, "s" if taken > 1 else ""])
