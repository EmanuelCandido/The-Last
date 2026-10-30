class_name ThrownSpear
extends Arrow
## A lança arremessada (F11, plano_combate §5.1): voa e finca como a flecha (mesmo raio a cada
## quadro, mesmo jeito de prender no bicho), mas é maior, mais pesada e fere mais. Não quebra no
## chão. E pega de volta, com o desgaste que ela tinha.

## O desgaste da lança quando saiu da mão (0..1).
var worn := 1.0


func _ready() -> void:
	length = float(Weapons.spec(item).get("length", 1.15))
	var mesh := MeshInstance3D.new()
	mesh.mesh = WeaponMesh.build(item)
	# A malha é feita ao longo de +Y com a ponta em cima; a flecha voa com a ponta em -Z.
	mesh.basis = Basis(Vector3.RIGHT, -PI * 0.5)
	mesh.position = Vector3(0.0, 0.0, length * (0.5 - (1.0 - WeaponMesh.SPEAR_GRIP)))
	add_child(mesh)


func breakable() -> bool:
	return false


func worn_value() -> float:
	return worn


func interaction_prompt() -> String:
	return "" if _flying else "Pegar %s" % String(Weapons.spec(item).get("called", "a lança"))


func interact(_player: Node) -> void:
	Inventory.add(item, 1, worn)
	if Inventory.held() == &"":
		Inventory.hold(item)
	OccludedAudio.play_at(get_parent(), PICKUP.pick_random(), global_position, &"World", -6.0, 3.0)
	queue_free()
