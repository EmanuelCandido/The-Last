class_name CareCapsule
extends Node3D
## A cápsula de coma da sala 2714 (§6.1), no mesmo lugar do sarcófago da sala-espelho.
## O comprimento corre em X, com a cabeceira em -X; o lado direito de Ari deitado é +Z (onde
## ficam o monitor, o soro e a janela). A tampa de vidro fica recolhida sobre os pés.
##
## Ocupada (nos flashes), aparecem a coberta sobre o corpo e o braço direito com a sonda; com
## Ari de pé, a coberta fica embolada nos pés. Acordado, "Deitar e fechar os olhos" volta para
## a floresta sem custo (§6.2).

const LENGTH := 2.2
const WIDTH := 0.95
## Altura do colchão.
const BED := 0.79

## Onde o soro pendura (no espaço da cápsula): a sonda vai do braço até aqui.
var drip_point := Vector3(0.1, 1.82, 0.7)

var _occupied: Array[Node3D] = []
var _empty: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"interactable")
	var body := StaticBody3D.new()
	add_child(body)
	_solid(body, Vector3(2.0, 0.45, 0.7), Vector3(0.0, 0.225, 0.0), &"dark_metal")
	_solid(body, Vector3(LENGTH, 0.26, WIDTH), Vector3(0.0, 0.58, 0.0), &"plastic")
	ShelterLook.box(self, Vector3(2.02, 0.09, 0.8), Vector3(0.0, BED - 0.045, 0.0), &"cloth")
	# Bordas da concha, um pouco acima do colchão.
	for side in [-1.0, 1.0]:
		ShelterLook.box(self, Vector3(LENGTH, 0.08, 0.06), Vector3(0.0, BED + 0.0, side * (WIDTH * 0.5 - 0.03)), &"plastic")
	ShelterLook.box(self, Vector3(0.36, 0.08, 0.55), Vector3(-0.84, BED + 0.04, 0.0), &"paper")
	# Tampa de vidro aberta: a metade de cima correu nos trilhos e ficou por cima da de baixo,
	# sobre as pernas. A cabeceira fica livre (é por ali que se olha o teto e se levanta).
	var lid_height := BED + 0.36
	ShelterLook.box(self, Vector3(1.05, 0.02, 0.86), Vector3(0.55, lid_height, 0.0), &"glass")
	ShelterLook.box(self, Vector3(1.0, 0.02, 0.84), Vector3(0.57, lid_height + 0.04, 0.0), &"glass")
	for side in [-1.0, 1.0]:
		ShelterLook.box(self, Vector3(LENGTH - 0.1, 0.03, 0.03), Vector3(0.0, BED + 0.02, side * 0.45), &"dark_metal")
		ShelterLook.box(self, Vector3(1.05, 0.05, 0.04), Vector3(0.55, lid_height, side * 0.44), &"plastic")
		ShelterLook.box(self, Vector3(0.04, 0.36, 0.04), Vector3(0.06, BED + 0.18, side * 0.44), &"plastic")
		ShelterLook.box(self, Vector3(0.04, 0.36, 0.04), Vector3(1.05, BED + 0.18, side * 0.44), &"plastic")
	# Painel do pé da cápsula, com luzinhas.
	ShelterLook.box(self, Vector3(0.05, 0.3, 0.6), Vector3(LENGTH * 0.5 + 0.02, 0.62, 0.0), &"dark_metal")
	ShelterLook.box(self, Vector3(0.01, 0.025, 0.04), Vector3(LENGTH * 0.5 + 0.05, 0.68, -0.18), &"green")
	ShelterLook.box(self, Vector3(0.01, 0.025, 0.04), Vector3(LENGTH * 0.5 + 0.05, 0.68, -0.1), &"amber")
	_build_body()
	set_occupied(false)


## Mostra o corpo de Ari deitado (flashes) ou a cápsula vazia (Ari de pé).
func set_occupied(occupied: bool) -> void:
	for node in _occupied:
		node.visible = occupied
	for node in _empty:
		node.visible = not occupied


## Olhos de Ari deitado, no espaço do mundo.
func eye_point() -> Vector3:
	return global_transform * Vector3(-0.82, BED + 0.17, 0.0)


## Para onde fica a cabeça (do queixo para o topo): o "para cima" da visão de quem está deitado.
func crown_direction() -> Vector3:
	return -global_basis.x


## Onde Ari fica de pé ao sair (lado esquerdo, -Z), no chão.
func out_point() -> Vector3:
	return global_transform * Vector3(-0.35, 0.0, -0.95)


## Onde o olhar precisa estar para deitar: o meio do colchão.
func interaction_point() -> Vector3:
	return global_transform * Vector3(0.0, BED, 0.0)


func interaction_prompt() -> String:
	return "Deitar e fechar os olhos" if Game.awake else ""


func interact(_body: Node) -> void:
	Game.return_to_forest()


func _build_body() -> void:
	# A coberta sobre o corpo (do peito aos pés) e o volume das pernas por baixo.
	_occupied.append(ShelterLook.box(self, Vector3(1.45, 0.14, 0.72), Vector3(0.3, BED + 0.07, 0.0), &"blanket"))
	_occupied.append(ShelterLook.box(self, Vector3(0.4, 0.1, 0.42), Vector3(-0.58, BED + 0.06, 0.0), &"cloth"))
	# Braço direito por cima da coberta, a mão aberta, e a sonda presa com fita.
	var arm := Node3D.new()
	add_child(arm)
	_occupied.append(arm)
	var shoulder := Vector3(-0.62, BED + 0.11, 0.24)
	var elbow := Vector3(-0.34, BED + 0.18, 0.31)
	var wrist := Vector3(-0.06, BED + 0.18, 0.33)
	ShelterLook.rod(arm, shoulder, elbow, 0.042, &"skin")
	ShelterLook.sphere(arm, 0.04, elbow, &"skin")
	ShelterLook.rod(arm, elbow, wrist, 0.033, &"skin")
	ShelterLook.box(arm, Vector3(0.1, 0.03, 0.075), wrist + Vector3(0.06, -0.005, 0.0), &"skin", Vector3(0.0, 0.1, 0.0))
	for finger in 4:
		var start := wrist + Vector3(0.11, -0.006, -0.027 + finger * 0.018)
		ShelterLook.rod(arm, start, start + Vector3(0.055 - absf(finger - 1.5) * 0.008, -0.012, 0.004 * finger), 0.0075, &"skin", 6)
	var probe := (elbow + wrist) * 0.5 + Vector3(0.0, 0.03, 0.0)
	ShelterLook.box(arm, Vector3(0.06, 0.012, 0.07), probe, &"paper")
	ShelterLook.rod(arm, probe + Vector3(0.0, 0.01, 0.0), probe + Vector3(0.12, 0.35, 0.18), 0.005, &"glass", 5)
	ShelterLook.rod(arm, probe + Vector3(0.12, 0.35, 0.18), drip_point, 0.005, &"glass", 5)
	# Vazia: a coberta embolada nos pés.
	_empty.append(ShelterLook.box(self, Vector3(0.55, 0.16, 0.78), Vector3(0.78, BED + 0.08, 0.02), &"blanket", Vector3(0.0, 0.15, 0.08)))


func _solid(body: StaticBody3D, size: Vector3, center: Vector3, material_name: StringName) -> void:
	ShelterLook.box(self, size, center, material_name)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
