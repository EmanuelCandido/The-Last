class_name Snare
extends Node3D
## Laço armado no chão (§4.10): duas estacas e a laçada de couro. Armado, pode pegar um
## coelho (quem sorteia é o SnareField); com o coelho, a laçada fecha e o coelho fica ali,
## morto, para coletar. Depois, E recolhe o laço de volta (armado também dá para recolher).

signal changed

enum State { ARMED, CAUGHT, SPRUNG }

const SNAP_SOUND := preload("res://assets/audio/sfx/snare_snap.wav")
const PICKUP_SOUND := preload("res://assets/audio/real/pickup_4.ogg")

var state := State.ARMED
## O coelho pego (enquanto não for coletado).
var rabbit: Animal

var _loop: MeshInstance3D


func _ready() -> void:
	add_to_group(&"interactable")
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/textures/wood.png")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	wood.roughness = 0.9
	for side in [-1.0, 1.0]:
		var stake := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.006
		mesh.bottom_radius = 0.01
		mesh.height = 0.22
		mesh.radial_segments = 5
		mesh.rings = 1
		stake.mesh = mesh
		stake.material_override = wood
		stake.position = Vector3(0.11 * side, 0.08, 0.0)
		stake.rotation.z = -0.12 * side
		add_child(stake)
	_loop = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.075
	torus.outer_radius = 0.085
	torus.rings = 14
	torus.ring_segments = 4
	_loop.mesh = torus
	var leather := StandardMaterial3D.new()
	leather.albedo_texture = preload("res://assets/textures/leather.png")
	leather.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	leather.albedo_color = Color(0.7, 0.6, 0.5)
	_loop.material_override = leather
	# A laçada fica em pé entre as estacas, na altura do coelho.
	_loop.position = Vector3(0.0, 0.1, 0.0)
	_loop.rotation.x = PI * 0.5
	add_child(_loop)
	_show_state()


## O coelho caiu no laço: `caught` é o coelho morto, já posto no lugar.
func catch(caught: Animal, quiet := false) -> void:
	state = State.CAUGHT
	rabbit = caught
	caught.tree_exited.connect(func() -> void:
		if state == State.CAUGHT:
			state = State.SPRUNG
			rabbit = null
			changed.emit())
	if not quiet:
		OccludedAudio.play_at(get_parent(), SNAP_SOUND, global_position + Vector3.UP * 0.1, &"World", -2.0, 4.0)
	_show_state()
	changed.emit()


func interaction_prompt() -> String:
	# Com o coelho ainda preso, a interação é a do coelho (coletar).
	return "" if state == State.CAUGHT else "Recolher o laço"


func interact(_player: Node) -> void:
	Inventory.add(&"snare")
	OccludedAudio.play_at(get_parent(), PICKUP_SOUND, global_position, &"World", -6.0, 3.0)
	queue_free()


func _show_state() -> void:
	if _loop == null:
		return
	# Fechada, a laçada encolhe e deita.
	var closed := state != State.ARMED
	_loop.scale = Vector3.ONE * (0.45 if closed else 1.0)
	_loop.position.y = 0.04 if closed else 0.1
