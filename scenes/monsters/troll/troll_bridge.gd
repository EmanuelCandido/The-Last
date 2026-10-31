class_name TrollBridge
extends Node3D
## A ponte caída na borda oeste do vale (docs/plano_combate.md §9.1; experimental): três troncos
## grandes caídos uns sobre os outros, com pedras em volta. É a casa do troll (Troll), que dorme ali
## de dia e anda pelas bordas de noite. Filho da floresta.
##
## Não há troll no Bem-vindo de volta (o Zelador está jogando de goblin) nem nos testes automáticos
## sem --orcs (o roteiro põe com spawn_troll).

const GROUP := &"troll_bridge"

var troll: Troll


func _ready() -> void:
	add_to_group(GROUP)


func build(terrain: Terrain) -> void:
	var at := ForestLayout.TROLL_BRIDGE
	position = Vector3(at.x, terrain.get_height(at.x, at.y), at.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3471
	var builder := TreeBuilder.Builder.new()
	var bark := builder.tool_for(PropLook.bark())
	var body := StaticBody3D.new()
	body.set_meta(&"surface", &"wood")
	add_child(body)
	for i in 3:
		var angle := rng.randf_range(-0.4, 0.4) + (0.0 if i < 2 else PI * 0.5)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var mid := Vector3(rng.randf_range(-1.0, 1.0), 0.35 + i * 0.45, rng.randf_range(-1.0, 1.0))
		var half := rng.randf_range(4.0, 5.5)
		var a := mid - dir * half
		var b := mid + dir * half
		a.y = terrain.get_height(position.x + a.x, position.z + a.z) - position.y + 0.3 + i * 0.4
		b.y = terrain.get_height(position.x + b.x, position.z + b.z) - position.y + 0.25 + i * 0.4
		TreeBuilder.add_branch(bark, a, b, rng.randf_range(0.32, 0.4), rng.randf_range(0.26, 0.32), 8)
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.33
		capsule.height = a.distance_to(b)
		shape.shape = capsule
		shape.transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5)
		body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.commit()
	add_child(mesh)


func _process(_delta: float) -> void:
	# As mesmas regras dos orcs: nada no Bem-vindo de volta, depois de Ficar ou com `ameaca off`.
	var band := get_tree().get_first_node_in_group(OrcBand.GROUP) as OrcBand
	var enabled := band == null or band.enabled()
	var scripted := DevTools.automated and not DevTools.orcs
	if enabled and not scripted and not is_instance_valid(troll):
		spawn_troll()
	elif not enabled and is_instance_valid(troll):
		troll.queue_free()
		troll = null


## Põe o troll na ponte, com a ronda da noite pelas bordas.
func spawn_troll() -> Troll:
	if is_instance_valid(troll):
		return troll
	troll = Troll.new()
	troll.home = global_position + Vector3(2.5, 0.0, 1.5)
	var center := Vector2(global_position.x, global_position.z)
	var outward := center.normalized()
	var along := Vector2(-outward.y, outward.x)
	var level := Game.current_level
	for offset: float in [-22.0, 22.0]:
		var p := center - outward * 6.0 + along * offset
		var y := float(level.ground_height(p.x, p.y)) if level != null and level.has_method("ground_height") else global_position.y
		troll.route.append(Vector3(p.x, y, p.y))
	troll.route.append(troll.home)
	get_parent().add_child(troll)
	troll.global_position = troll.home + Vector3.UP * 0.2
	return troll
