extends MeshInstance3D
## Pele onde o goblin dorme. Com sono (Clock.can_sleep), E deita e passa a noite
## (Game.pass_out): o tempo pula para a manhã, o corpo descansa e um risco vai para a parede.
## Com a cama de peles (F9, item "fur_bed"), mais duas peles por cima e um rolo de travesseiro:
## dormir cura mais e gasta menos fome (Vitals.rest).

var _bed: Node3D


func _ready() -> void:
	add_to_group(&"interactable")
	Inventory.changed.connect(func(item: StringName, _amount: int) -> void:
		if item == &"fur_bed":
			_update_bed())
	_update_bed()


func _update_bed() -> void:
	var has_bed := Inventory.has(&"fur_bed")
	if has_bed and _bed == null:
		_bed = Node3D.new()
		add_child(_bed)
		var furs := [Color(0.42, 0.3, 0.2), Color(0.55, 0.45, 0.33)]
		for i in 2:
			var layer := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.05 - i * 0.12, 0.05, 1.7 - i * 0.2)
			layer.mesh = box
			layer.material_override = Animal.fur_material(furs[i])
			layer.position = Vector3(0.04 * i, 0.04 + i * 0.045, -0.05 * i)
			layer.rotation.y = 0.08 - i * 0.14
			_bed.add_child(layer)
		var pillow := MeshInstance3D.new()
		var roll := CapsuleMesh.new()
		roll.radius = 0.11
		roll.height = 0.7
		pillow.mesh = roll
		pillow.material_override = Animal.fur_material(Color(0.5, 0.38, 0.27))
		pillow.position = Vector3(0.0, 0.16, 0.75)
		pillow.rotation.z = PI * 0.5
		_bed.add_child(pillow)
	if _bed != null:
		_bed.visible = has_bed


func interaction_prompt() -> String:
	# A noite da Investida (F13): eles estão vindo.
	if Story.has_flag(&"raid_tonight"):
		return "Não dá para dormir com eles lá fora"
	return "Dormir até amanhecer" if Clock.can_sleep() and not Game.resting else ""


func interaction_enabled() -> bool:
	return not Story.has_flag(&"raid_tonight")


func interaction_action() -> Dictionary:
	return {"action": &"lie_down", "duration": 2.0, "at": 0.15}


func interact(_player: Node) -> void:
	Game.pass_out(&"sleep")
