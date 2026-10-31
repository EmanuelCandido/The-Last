class_name TrollBridge
extends Node3D
## A ponte caída do desfiladeiro (docs/plano_combate.md §9.1; experimental, F14): dois pinheiros
## caídos lado a lado por cima da ravina, e um terceiro que quebrou e despencou lá dentro. É a casa
## do troll (Troll): ele dorme no fundo da ravina, embaixo da ponte, de dia, e anda pelas bordas do
## vale de noite. Quem atravessa pelos troncos passa bem em cima dele; o outro caminho é a passagem
## junto do paredão norte. Filho da floresta.
##
## Não há troll no Bem-vindo de volta (o Zelador está jogando de goblin) nem nos testes automáticos
## sem --orcs (o roteiro põe com spawn_troll).

const GROUP := &"troll_bridge"
## De que lado do eixo os troncos da ponte passam (m; negativo = sul, onde a ravina é funda), a
## meia distância entre os dois, o raio e quanto passam da boca da ravina para cada lado.
const SIDE := -3.4
const GAP := 0.38
const LOG_RADIUS := 0.36
const OVERHANG := 2.6

var troll: Troll
## Onde o troll dorme: no fundo da ravina, embaixo da ponte.
var den := Vector3.ZERO

var _terrain: Terrain


func _ready() -> void:
	add_to_group(GROUP)


func build(terrain: Terrain) -> void:
	_terrain = terrain
	var center := ForestLayout.ravine_center()
	position = Vector3(center.x, terrain.get_height(center.x, center.y), center.y)
	var axis := (ForestLayout.GORGE_TO - ForestLayout.GORGE_FROM).normalized()
	var reach := ForestLayout.RAVINE_HALF + 0.7 + OVERHANG
	var builder := TreeBuilder.Builder.new()
	var bark := builder.tool_for(PropLook.bark())
	var body := StaticBody3D.new()
	body.set_meta(&"surface", &"wood")
	add_child(body)
	# Os dois troncos da ponte, com as pontas apoiadas no chão do desfiladeiro.
	for offset: float in [-GAP, GAP]:
		var middle := ForestLayout.gorge_point(ForestLayout.RAVINE_AT, SIDE + offset)
		var a := middle - axis * reach
		var b := middle + axis * reach
		_add_log(bark, body, _on_ground(a, LOG_RADIUS - 0.08), _on_ground(b, LOG_RADIUS - 0.12), LOG_RADIUS, LOG_RADIUS * 0.82)
	# O terceiro: quebrou e caiu, uma ponta na beira e a outra no fundo, junto do paredão sul (fora
	# do caminho entre a toca do troll e a rampa).
	var top := ForestLayout.gorge_point(ForestLayout.RAVINE_AT, -8.6) + axis * reach
	var bottom := ForestLayout.gorge_point(ForestLayout.RAVINE_AT, -8.0) - axis * 0.6
	_add_log(bark, body, _on_ground(top, 0.2), _on_ground(bottom, 0.3), 0.34, 0.12)
	var mesh := MeshInstance3D.new()
	mesh.name = "Logs"
	mesh.mesh = builder.commit()
	add_child(mesh)
	var spot := ForestLayout.gorge_point(ForestLayout.RAVINE_AT, SIDE - 0.6)
	den = Vector3(spot.x, terrain.get_height(spot.x, spot.y), spot.y)


## Um ponto do chão (`flat`, no plano) em coordenadas da ponte, `lift` acima do terreno.
func _on_ground(flat: Vector2, lift: float) -> Vector3:
	return to_local(Vector3(flat.x, _terrain.get_height(flat.x, flat.y) + lift, flat.y))


func _add_log(bark: SurfaceTool, body: StaticBody3D, a: Vector3, b: Vector3, radius: float, tip: float) -> void:
	TreeBuilder.add_branch(bark, a, b, radius, tip, 9)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = (radius + tip) * 0.5
	capsule.height = a.distance_to(b) + capsule.radius * 2.0
	shape.shape = capsule
	shape.transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5)
	body.add_child(shape)


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


## Põe o troll na toca dele, embaixo da ponte, com a ronda da noite: sobe a rampa da ravina, sai
## pela boca do desfiladeiro, anda a borda leste do vale da toca e volta.
func spawn_troll() -> Troll:
	if is_instance_valid(troll):
		return troll
	troll = Troll.new()
	troll.home = den
	var path: Array[Vector2] = [
		ForestLayout.gorge_point(ForestLayout.RAVINE_AT, ForestLayout.GORGE_LEDGE),
		ForestLayout.GORGE_FROM,
		ForestLayout.GORGE_FROM + Vector2(-16.0, 22.0),
		ForestLayout.GORGE_FROM + Vector2(-20.0, -18.0),
		ForestLayout.GORGE_FROM,
		ForestLayout.gorge_point(ForestLayout.RAVINE_AT, ForestLayout.GORGE_LEDGE),
	]
	for p in path:
		troll.route.append(Vector3(p.x, _terrain.get_height(p.x, p.y), p.y))
	troll.route.append(den)
	get_parent().add_child(troll)
	troll.global_position = den + Vector3.UP * 0.2
	return troll
