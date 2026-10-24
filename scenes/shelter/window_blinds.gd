class_name WindowBlinds
extends Node3D
## A janela da sala 2714 com a persiana (§6.1). Lá fora, pintados no infinito (como um céu), o
## pinheiral e a Ruína de São Brás na Cinza (window_view.gdshader). Uma luz fria entra pela
## janela e as lâminas fazem listras de sombra no chão e na cápsula. E abre e fecha.
## A origem é o meio da abertura, na face de dentro da parede; lá fora é +Z.

const VIEW_SHADER := preload("res://assets/shaders/window_view.gdshader")
const RATTLE := preload("res://assets/audio/real/blind_rattle.ogg")
const SLATS := 17
const SLAT_GAP := 0.07

## Tamanho da abertura (largura, altura).
var size := Vector2(1.8, 1.2)
## 0 = fechada (lâminas em pé), 1 = aberta (deitadas).
var openness := 0.35:
	set(value):
		openness = clampf(value, 0.0, 1.0)
		_tilt_slats()
## Quanto da persiana está recolhida no alto (0 = toda descida). As lâminas de baixo sobem e
## se empilham sob o trilho, e a janela fica livre embaixo.
var raised := 0.0:
	set(value):
		raised = clampf(value, 0.0, 1.0)
		_tilt_slats()

var _slats: Array[Node3D] = []
var _tween: Tween
var _rattle: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"interactable")
	var top := size.y * 0.5
	ShelterLook.box(self, Vector3(size.x + 0.1, 0.05, 0.08), Vector3(0.0, top - 0.02, -0.06), &"plastic")
	for i in SLATS:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.0, top - 0.08 - i * SLAT_GAP, -0.06)
		add_child(pivot)
		ShelterLook.box(pivot, Vector3(size.x - 0.04, 0.006, 0.06), Vector3.ZERO, &"plastic")
		_slats.append(pivot)
	ShelterLook.rod(self, Vector3(size.x * 0.5 - 0.1, top - 0.04, -0.1), Vector3(size.x * 0.5 - 0.1, -top + 0.25, -0.1), 0.003, &"plastic", 4)
	# O vidro, encardido, e um quadro grande lá fora onde a paisagem é pintada pela direção do olhar.
	ShelterLook.box(self, Vector3(size.x, size.y, 0.01), Vector3(0.0, 0.0, 0.06), &"glass")
	var view := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(26.0, 15.0)
	view.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = VIEW_SHADER
	view.material_override = material
	view.position = Vector3(0.0, 2.2, 7.0)
	view.rotation.y = PI
	add_child(view)
	# A luz do dia nublado entrando, com sombra (as lâminas listram o quarto).
	var daylight := SpotLight3D.new()
	daylight.light_color = Color(0.74, 0.78, 0.82)
	daylight.light_energy = 9.0
	daylight.spot_range = 10.0
	daylight.spot_angle = 50.0
	daylight.spot_attenuation = 0.8
	daylight.shadow_enabled = true
	daylight.shadow_blur = 1.5
	daylight.position = Vector3(0.0, 0.5, 1.4)
	daylight.rotation = Vector3(deg_to_rad(-22.0), 0.0, 0.0)
	add_child(daylight)
	_rattle = AudioStreamPlayer3D.new()
	_rattle.stream = RATTLE
	_rattle.bus = &"Shelter"
	_rattle.volume_db = -10.0
	_rattle.unit_size = 2.0
	add_child(_rattle)
	_tilt_slats()


func interaction_prompt() -> String:
	return ("Fechar a persiana" if openness > 0.5 else "Abrir a persiana") if Game.awake else ""


func interact(_body: Node) -> void:
	set_open(0.1 if openness > 0.5 else 0.9)


func set_open(value: float, seconds := 0.45) -> void:
	if _tween != null:
		_tween.kill()
	if seconds <= 0.0:
		openness = value
		return
	_tween = create_tween()
	_tween.tween_property(self, ^"openness", value, seconds).set_trans(Tween.TRANS_SINE)
	_rattle.play()


func _tilt_slats() -> void:
	# Fechada, a lâmina fica quase em pé (82°); aberta, deitada.
	var angle := deg_to_rad(lerpf(82.0, 4.0, openness))
	var top := size.y * 0.5
	# As de cima se empilham juntinhas sob o trilho; as outras continuam penduradas embaixo.
	var stacked := _slats.size() - roundi(_slats.size() * (1.0 - raised))
	for i in _slats.size():
		var slat := _slats[i]
		if i < stacked:
			slat.position.y = top - 0.06 - i * 0.008
			slat.rotation.x = 0.0
		else:
			slat.position.y = top - 0.08 - stacked * 0.008 - (i - stacked) * SLAT_GAP
			slat.rotation.x = angle
