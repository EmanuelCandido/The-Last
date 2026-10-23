class_name ThrownStone
extends Node3D
## Pedra jogada: voa com gravidade (raio a cada frame de física, como a Flecha), quica uma
## vez e para. Onde bate pela primeira vez faz barulho (Events.noise_made de
## Tuning.STONE_NOISE m): os bichos se assustam com o lugar, não com o goblin. Parada no
## chão, dá para pegar de volta com E.

const HIT_SOUNDS := [preload("res://assets/audio/sfx/stone_hit_1.wav"), preload("res://assets/audio/sfx/stone_hit_2.wav")]
const PICKUP_SOUND := preload("res://assets/audio/real/pickup_2.ogg")
## Mundo e árvores (bichos não param a pedra).
const HIT_MASK := 1 | 2
const GRAVITY := 9.8
## Some sozinha depois disto no chão, para o vale não encher de pedras (s).
const LIFETIME := 600.0

var velocity := Vector3.ZERO

var _flying := true
var _bounced := false
var _exclude: Array[RID] = []
var _spin := Vector3.ZERO


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = stone_mesh(randi())
	add_child(mesh)


func launch(from: Vector3, start_velocity: Vector3, exclude: Array[RID]) -> void:
	global_position = from
	velocity = start_velocity
	_exclude = exclude
	_spin = Vector3(randf_range(-12.0, 12.0), randf_range(-6.0, 6.0), randf_range(-12.0, 12.0))


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	velocity += Vector3.DOWN * GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, _exclude))
	if hit.is_empty():
		global_position = to
		rotation += _spin * delta
		if global_position.y < -100.0:
			queue_free()
		return
	var normal: Vector3 = hit.normal
	global_position = hit.position + normal * 0.03
	if not _bounced:
		_bounced = true
		OccludedAudio.play_at(get_parent(), HIT_SOUNDS.pick_random(), hit.position, &"World", 0.0, 5.0, randf_range(0.9, 1.1))
		Events.noise_made.emit(hit.position, Tuning.STONE_NOISE)
		# Quica baixo e perde quase toda a força.
		velocity = velocity.bounce(normal) * 0.3
		_spin *= 0.4
		if velocity.length() > 1.0:
			return
	_flying = false
	add_to_group(&"interactable")
	get_tree().create_timer(LIFETIME, false).timeout.connect(queue_free)


func interaction_prompt() -> String:
	return "" if _flying else "Pegar a pedra"


func interaction_enabled() -> bool:
	return Inventory.count(&"stone") < Tuning.STONE_MAX


func interact(_player: Node) -> void:
	if Inventory.count(&"stone") >= Tuning.STONE_MAX:
		return
	Inventory.add(&"stone")
	OccludedAudio.play_at(get_parent(), PICKUP_SOUND, global_position, &"World", -6.0, 3.0)
	queue_free()


static var _rock: StandardMaterial3D


## Pedrinha irregular (6–8 cm): uma esfera baixa de poucos lados, amassada pelo sorteio.
static func stone_mesh(rng_seed: int, radius := 0.04) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 7
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var squash := Vector3(rng.randf_range(0.9, 1.2), rng.randf_range(0.55, 0.8), rng.randf_range(0.8, 1.1))
	# Mesma posição, mesmo deslocamento: a emenda da esfera não abre.
	var bumps := {}
	for i in vertices.size():
		var key := vertices[i].snapped(Vector3.ONE * 0.001)
		if not bumps.has(key):
			bumps[key] = rng.randf_range(0.85, 1.12)
		vertices[i] = vertices[i] * squash * float(bumps[key])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _rock == null:
		_rock = StandardMaterial3D.new()
		_rock.albedo_texture = preload("res://assets/textures/rock.png")
		_rock.albedo_color = Color(0.62, 0.6, 0.57)
		_rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_rock.uv1_triplanar = true
		_rock.uv1_scale = Vector3.ONE * 6.0
		_rock.roughness = 0.95
	mesh.surface_set_material(0, _rock)
	return mesh
