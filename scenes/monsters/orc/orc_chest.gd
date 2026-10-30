class_name OrcChest
extends Node3D
## O baú do acampamento (F13, ver OrcCamp): tábuas e tiras de ferro. Abrir demora e faz barulho.

var camp: OrcCamp


func _ready() -> void:
	add_to_group(&"interactable")
	var builder := TreeBuilder.Builder.new()
	var wood := builder.tool_for(ArmorLook._mat(preload("res://assets/textures/wood.png"), Color(0.7, 0.6, 0.5)))
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.55, 0.6)
	wood.append_from(box, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.28, 0.0)))
	var iron := builder.tool_for(ArmorLook._mat(GoblinLook.METAL, Color(0.55, 0.53, 0.5)))
	for x: float in [-0.3, 0.3]:
		var strap := BoxMesh.new()
		strap.size = Vector3(0.06, 0.57, 0.62)
		iron.append_from(strap, 0, Transform3D(Basis.IDENTITY, Vector3(x, 0.28, 0.0)))
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.commit()
	add_child(mesh)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = Vector3(0.95, 0.55, 0.6)
	shape.shape = collision
	shape.position = Vector3(0.0, 0.28, 0.0)
	body.add_child(shape)
	body.set_meta(&"surface", &"wood")
	add_child(body)


func interaction_prompt() -> String:
	if camp == null:
		return ""
	return "Abrir o baú dos orcs" if camp.chest_count() > 0 else "Baú dos orcs: vazio"


func interaction_enabled() -> bool:
	return camp != null and camp.chest_count() > 0


func interaction_action() -> Dictionary:
	return {"action": &"harvest", "duration": 2.2, "at": 1.8}


func interact(_player: Node) -> void:
	if camp != null:
		camp.open_chest()
