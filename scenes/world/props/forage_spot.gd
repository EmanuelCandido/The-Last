class_name ForageSpot
extends Node3D
## Um lugar de coleta (§8b-D): um tufo de cogumelos ao pé de uma árvore ou um arbusto de
## frutinhas na borda da mata. E colhe; colhido, volta a dar depois de Tuning.FORAGE_REGROW_DAYS
## dias (o arbusto fica, sem as frutinhas). Quem guarda o dia da colheita é o ForageField.

const PICK_SOUND := preload("res://assets/audio/real/pickup_2.ogg")

## &"mushroom" ou &"berries".
var kind := &"mushroom"
## Dia em que foi colhido (-1 = pronto para colher).
var picked_day := -1

var _fruit: Node3D


func build(spot_kind: StringName, rng: RandomNumberGenerator) -> void:
	kind = spot_kind
	add_to_group(&"interactable")
	_fruit = Node3D.new()
	add_child(_fruit)
	if kind == &"mushroom":
		var stem := Animal.flat_material(Color(0.82, 0.78, 0.68))
		var cap := Animal.flat_material(Color(0.55, 0.32, 0.2))
		for i in rng.randi_range(3, 5):
			var at := Vector3(rng.randf_range(-0.22, 0.22), 0.0, rng.randf_range(-0.22, 0.22))
			var height := rng.randf_range(0.05, 0.11)
			_box(_fruit, Vector3(0.025, height, 0.025), at + Vector3.UP * height * 0.5, stem)
			_box(_fruit, Vector3(0.09, 0.03, 0.09) * rng.randf_range(0.8, 1.3), at + Vector3.UP * height, cap)
	else:
		var leaf := Animal.flat_material(Color(0.18, 0.24, 0.13))
		var berry := Animal.flat_material(Color(0.42, 0.06, 0.1))
		# Mais alto que o capim, para se achar de longe.
		for i in 7:
			var at := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.3, 0.9), rng.randf_range(-0.4, 0.4))
			var blob := _box(self, Vector3(0.55, 0.45, 0.55) * rng.randf_range(0.7, 1.1), at, leaf)
			blob.rotation.y = rng.randf() * TAU
		for i in 22:
			var at := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.35, 1.15), rng.randf_range(-0.5, 0.5))
			_box(_fruit, Vector3.ONE * 0.05, at, berry)


func ready_to_pick() -> bool:
	return picked_day < 0 or Clock.day - picked_day >= Tuning.FORAGE_REGROW_DAYS


func refresh() -> void:
	if picked_day >= 0 and ready_to_pick():
		picked_day = -1
	_fruit.visible = ready_to_pick()


func interaction_prompt() -> String:
	if not ready_to_pick():
		return ""
	return "Colher cogumelos" if kind == &"mushroom" else "Colher frutinhas"


func interact(_player: Node) -> void:
	if not ready_to_pick():
		return
	var amount := 2 if kind == &"mushroom" else 3
	Inventory.add(kind, amount)
	picked_day = Clock.day
	refresh()
	Events.notification_shown.emit("+%d %s" % [amount, String(Inventory.NAMES[kind]).to_lower()])
	OccludedAudio.play_at(get_parent(), PICK_SOUND, global_position + Vector3.UP * 0.3, &"World", -6.0, 2.5)


func _box(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	parent.add_child(mesh)
	return mesh
