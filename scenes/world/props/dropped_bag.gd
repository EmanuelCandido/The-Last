class_name DroppedBag
extends Node3D
## A bolsa do goblin no chão, onde ele morreu (F13, ver BagField): um saco de couro amarrado, com a
## ponta de uma flecha para fora. E pega tudo de volta.

const PICK_SOUND := preload("res://assets/audio/real/pickup_4.ogg")

var field: BagField


func _ready() -> void:
	add_to_group(&"interactable")
	var builder := TreeBuilder.Builder.new()
	var leather := builder.tool_for(ArmorLook._mat(GoblinLook.LEATHER, Color(0.7, 0.55, 0.42)))
	var sack := SphereMesh.new()
	sack.radius = 0.16
	sack.height = 0.24
	sack.radial_segments = 8
	sack.rings = 5
	leather.append_from(sack, 0, Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.15)), Vector3(0.0, 0.1, 0.0)))
	TreeBuilder.add_branch(leather, Vector3(0.0, 0.18, 0.0), Vector3(0.02, 0.27, -0.03), 0.05, 0.02, 6)
	var shaft := builder.tool_for(ArmorLook._mat(preload("res://assets/textures/wood.png"), Color.WHITE))
	TreeBuilder.add_branch(shaft, Vector3(0.05, 0.15, 0.05), Vector3(0.14, 0.42, 0.12), 0.006, 0.006, 4)
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.commit()
	add_child(mesh)


func interaction_prompt() -> String:
	return "Pegar a sua bolsa"


func interact(_player: Node) -> void:
	OccludedAudio.play_at(get_parent(), PICK_SOUND, global_position + Vector3.UP * 0.2, &"World", -4.0, 3.0)
	if field != null:
		field.pick_up()
