class_name VitalsMonitor
extends Node3D
## O monitor ao lado da cápsula (§6.1): LEITO 2714, ciclo, dia, nutrição e batimento, com o
## traçado do coração e um bipe a cada batida. Os números vêm do jogo de verdade: o ciclo do
## Story, o dia do Clock e a nutrição da fome do goblin (Vitals.satiety), porque a fome da
## floresta é a nutrição de Ari. A tela olha para +Z.

const BEEP := preload("res://assets/audio/sfx/monitor_beep.wav")
const ECG_SHADER := preload("res://assets/shaders/ecg.gdshader")
const SCREEN := Vector2(0.46, 0.33)
const SCREEN_HEIGHT := 1.12

## Batimento mostrado e ouvido.
var bpm := Tuning.SHELTER_BPM:
	set(value):
		bpm = value
		if _ecg != null:
			_ecg.set_shader_parameter(&"bpm", value)
## Bipa a cada batida.
var beeping := true

var _text: Label3D
var _ecg: ShaderMaterial
var _beep: AudioStreamPlayer3D
var _beat := 0.0
var _refresh := 0.0


func _ready() -> void:
	ShelterLook.cylinder(self, 0.18, 0.04, Vector3(0.0, 0.02, 0.0), &"dark_metal")
	ShelterLook.cylinder(self, 0.018, SCREEN_HEIGHT - 0.12, Vector3(0.0, (SCREEN_HEIGHT - 0.12) * 0.5, 0.0), &"metal")
	ShelterLook.box(self, Vector3(SCREEN.x + 0.06, SCREEN.y + 0.06, 0.1), Vector3(0.0, SCREEN_HEIGHT, -0.05), &"plastic")
	ShelterLook.box(self, Vector3(SCREEN.x, SCREEN.y, 0.005), Vector3(0.0, SCREEN_HEIGHT, 0.002), &"screen")
	var ecg := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(SCREEN.x - 0.03, SCREEN.y * 0.42)
	ecg.mesh = quad
	_ecg = ShaderMaterial.new()
	_ecg.shader = ECG_SHADER
	_ecg.set_shader_parameter(&"bpm", bpm)
	ecg.material_override = _ecg
	ecg.position = Vector3(0.0, SCREEN_HEIGHT - SCREEN.y * 0.22, 0.008)
	add_child(ecg)
	# Alinhado à esquerda, o Label3D começa na própria origem: ela fica na borda da tela.
	_text = ShelterLook.label(self, "", Vector3(-SCREEN.x * 0.5 + 0.025, SCREEN_HEIGHT + SCREEN.y * 0.22, 0.008), 0.021, Color(0.45, 1.0, 0.6), true)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 1.0, 0.65)
	glow.light_energy = 0.35
	glow.omni_range = 1.6
	glow.position = Vector3(0.0, SCREEN_HEIGHT, 0.25)
	add_child(glow)
	_beep = AudioStreamPlayer3D.new()
	_beep.stream = BEEP
	_beep.bus = &"Shelter"
	_beep.volume_db = -16.0
	_beep.unit_size = 1.5
	_beep.position = Vector3(0.0, SCREEN_HEIGHT, 0.0)
	add_child(_beep)
	_refresh_text()


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		_refresh_text()
	_beat += delta * bpm / 60.0
	if _beat >= 1.0:
		_beat -= 1.0
		if beeping:
			_beep.play()


func _refresh_text() -> void:
	_text.text = "LEITO 2714 · CICLO %d · DIA %d\nNUTRIÇÃO %d%%      BPM %d" % [Story.cycle, Clock.day, roundi(Vitals.satiety), roundi(bpm)]
