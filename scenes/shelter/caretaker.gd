class_name Caretaker
extends Node3D
## O corpo do Zelador (ZL-0, §1): base de roda, tronco fino, dois braços articulados e uma
## cabeça que é uma lente com luz e um alto-falante. Aqui só o corpo e o que ele faz ouvir
## (roda, servo, bipe de passo, voz); quem decide para onde ele vai são os flashes (F5) e a
## IA da ronda (F6). Frente em +Z; origem no chão, no meio da base.

const WHEEL := preload("res://assets/audio/ambience/wheel_loop.wav")
const SERVO := preload("res://assets/audio/sfx/servo.wav")
const STEP_BEEP := preload("res://assets/audio/sfx/keeper_beep.wav")
const VOICES := [preload("res://assets/audio/sfx/keeper_voice_1.wav"), preload("res://assets/audio/sfx/keeper_voice_2.wav")]
## Cor da lente por estado (§6.3): ronda, verificando, encontrou.
const LIGHTS := {&"green": Color(0.35, 1.0, 0.5), &"amber": Color(1.0, 0.62, 0.18), &"red": Color(1.0, 0.18, 0.12)}
const NECK_HEIGHT := 1.32

## A cabeça (lente + alto-falante). Pode ser movida e girada à parte: o pescoço estica.
var head: Node3D
var arms: Array[Node3D] = []
## Andando: a roda ronca e o bipe de passo toca.
var moving := false:
	set(value):
		moving = value
		if _wheel != null:
			_wheel.stream_paused = not value

var _lens_material: StandardMaterial3D
var _card: MeshInstance3D
var _lens_light: OmniLight3D
var _wheel: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _step := 0.0
var _neck: MeshInstance3D


func _ready() -> void:
	ShelterLook.cylinder(self, 0.27, 0.2, Vector3(0.0, 0.12, 0.0), &"metal", Vector3.ZERO, 16)
	ShelterLook.cylinder(self, 0.24, 0.03, Vector3(0.0, 0.235, 0.0), &"dark_metal", Vector3.ZERO, 16)
	ShelterLook.cylinder(self, 0.08, 0.06, Vector3(0.0, 0.04, 0.0), &"rubber", Vector3(0.0, 0.0, PI * 0.5))
	ShelterLook.cylinder(self, 0.055, 0.9, Vector3(0.0, 0.69, 0.0), &"metal")
	# O peito: a caixa onde fica o cartão de acesso (R4), com a fenda acesa.
	ShelterLook.box(self, Vector3(0.3, 0.24, 0.16), Vector3(0.0, 1.02, 0.0), &"metal")
	ShelterLook.box(self, Vector3(0.09, 0.015, 0.01), Vector3(0.0, 1.06, 0.082), &"amber")
	_card = ShelterLook.box(self, Vector3(0.07, 0.045, 0.006), Vector3(0.0, 1.035, 0.083), &"plastic")
	ShelterLook.cylinder(self, 0.03, 0.44, Vector3(0.0, 1.16, 0.0), &"dark_metal", Vector3(0.0, 0.0, PI * 0.5))
	for side in [-1.0, 1.0]:
		arms.append(_build_arm(side))
	_neck = ShelterLook.cylinder(self, 0.018, 0.2, Vector3(0.0, 1.22, 0.0), &"dark_metal")
	head = Node3D.new()
	head.position = Vector3(0.0, NECK_HEIGHT, 0.0)
	add_child(head)
	ShelterLook.cylinder(head, 0.105, 0.14, Vector3(0.0, 0.0, 0.0), &"plastic", Vector3(PI * 0.5, 0.0, 0.0), 16)
	ShelterLook.cylinder(head, 0.085, 0.03, Vector3(0.0, 0.0, 0.075), &"rubber", Vector3(PI * 0.5, 0.0, 0.0), 16)
	var lens := ShelterLook.sphere(head, 0.062, Vector3(0.0, 0.0, 0.07), &"green")
	_lens_material = ShelterLook.light_material(&"green")
	lens.material_override = _lens_material
	# Alto-falante: uma grade embaixo da lente.
	ShelterLook.box(head, Vector3(0.12, 0.05, 0.08), Vector3(0.0, -0.1, 0.02), &"dark_metal")
	for i in 3:
		ShelterLook.box(head, Vector3(0.1, 0.006, 0.005), Vector3(0.0, -0.088 - i * 0.012, 0.062), &"rubber")
	_lens_light = OmniLight3D.new()
	_lens_light.light_energy = 0.7
	_lens_light.omni_range = 2.6
	_lens_light.position = Vector3(0.0, 0.0, 0.16)
	head.add_child(_lens_light)
	_wheel = _sound(WHEEL, -14.0, self)
	_wheel.autoplay = true
	_wheel.stream_paused = true
	_voice = _sound(VOICES[0], -4.0, head)
	set_light(&"green")


func _process(delta: float) -> void:
	# O pescoço acompanha a cabeça quando ela estica para fora do corpo.
	var neck_top := head.position
	var neck_base := Vector3(0.0, 1.18, 0.0)
	var length := maxf(neck_base.distance_to(neck_top), 0.05)
	var along := (neck_top - neck_base) / length
	var side := along.cross(Vector3.FORWARD if absf(along.y) > 0.9 else Vector3.UP).normalized()
	_neck.position = (neck_top + neck_base) * 0.5
	_neck.basis = Basis(side, along * (length / 0.2), side.cross(along))
	if moving:
		_step -= delta
		if _step <= 0.0:
			_step = 1.4
			_play(STEP_BEEP, -12.0)


## Cor da lente: "green" (ronda), "amber" (verificando), "red" (encontrou).
func set_light(state: StringName) -> void:
	var color: Color = LIGHTS.get(state, LIGHTS[&"green"])
	_lens_material.emission = color
	_lens_light.light_color = color


## O cartão de acesso no peito (R4 tira).
func set_card(present: bool) -> void:
	_card.visible = present


## Brilho da lente (1 = normal): chega perto e acende.
func set_glow(amount: float) -> void:
	_lens_material.emission_energy_multiplier = 3.0 * amount
	# A luz em volta não acompanha tudo: de perto ela estouraria a cápsula de branco.
	_lens_light.light_energy = 0.7 * minf(amount, 1.1)


## Fala pelo alto-falante (a legenda é de quem chama). `index`: 0 curta, 1 longa.
func speak(index: int) -> void:
	_voice.stream = VOICES[clampi(index, 0, VOICES.size() - 1)]
	_voice.play()


## Gira um braço (0 esquerdo, 1 direito): `lift` ergue para a frente, `bend` dobra o cotovelo.
func pose_arm(index: int, lift: float, bend: float) -> void:
	var arm := arms[index]
	arm.rotation.x = -lift
	(arm.get_child(0) as Node3D).rotation.x = -bend


func servo() -> void:
	_play(SERVO, -10.0)


func _build_arm(side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(0.23 * side, 1.16, 0.0)
	add_child(shoulder)
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.3, 0.0)
	shoulder.add_child(elbow)
	ShelterLook.sphere(shoulder, 0.035, Vector3.ZERO, &"dark_metal")
	ShelterLook.cylinder(shoulder, 0.022, 0.3, Vector3(0.0, -0.15, 0.0), &"metal")
	ShelterLook.sphere(elbow, 0.028, Vector3.ZERO, &"dark_metal")
	ShelterLook.cylinder(elbow, 0.018, 0.28, Vector3(0.0, -0.14, 0.0), &"metal")
	# A mão: três dedos de pinça.
	for finger in 3:
		var angle := (finger - 1) * 0.5
		ShelterLook.box(elbow, Vector3(0.012, 0.07, 0.012), Vector3(sin(angle) * 0.02, -0.31, cos(angle) * 0.02 - 0.01), &"dark_metal", Vector3(0.25 * cos(angle), 0.0, -0.25 * sin(angle)))
	shoulder.rotation.x = 0.15
	elbow.rotation.x = -0.35
	return shoulder


func _sound(stream: AudioStream, volume: float, parent: Node3D) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"Shelter"
	player.volume_db = volume
	player.unit_size = 2.5
	parent.add_child(player)
	return player


func _play(stream: AudioStream, volume: float) -> void:
	var player := _sound(stream, volume, self)
	player.position = Vector3(0.0, 1.0, 0.0)
	player.finished.connect(player.queue_free)
	player.play()
