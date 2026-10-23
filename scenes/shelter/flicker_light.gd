class_name FlickerLight
extends OmniLight3D
## Luz do Abrigo com a própria luminária: acesa direto ("steady"), piscando devagar como luz
## de emergência ("blink") ou falhando como lâmpada velha ("flicker"). O brilho da luminária
## acompanha a luz, e a lâmpada que falha zumbe (light_buzz) quando acende.

const BUZZ := preload("res://assets/audio/ambience/light_buzz.wav")

## "steady", "blink" ou "flicker".
@export var mode := &"steady"
## "blink": segundos de uma piscada inteira.
@export var period := 1.6

var fixture_material: StandardMaterial3D

var _energy := 1.0
var _fixture_energy := 3.0
var _time := 0.0
var _off_for := 0.0
var _buzz: AudioStreamPlayer3D


## `fixture`: o material da luminária (de ShelterLook.light_material), que brilha junto.
func setup(energy: float, color: Color, reach: float, fixture: StandardMaterial3D = null, buzzing := false) -> void:
	_energy = energy
	light_energy = energy
	light_color = color
	omni_range = reach
	omni_attenuation = 1.4
	shadow_enabled = false
	fixture_material = fixture
	if fixture != null:
		_fixture_energy = fixture.emission_energy_multiplier
	_time = randf() * 10.0
	if buzzing:
		_buzz = AudioStreamPlayer3D.new()
		_buzz.stream = BUZZ
		_buzz.bus = &"Shelter"
		_buzz.volume_db = -22.0
		_buzz.unit_size = 1.5
		_buzz.autoplay = true
		add_child(_buzz)


func _process(delta: float) -> void:
	_time += delta
	var level := 1.0
	match mode:
		&"blink":
			# Sobe e desce macio, com um tempo apagada (luz de emergência girando por dentro).
			level = pow(maxf(sin(_time * TAU / period), 0.0), 2.0) * 0.85 + 0.15
		&"flicker":
			_off_for -= delta
			if _off_for <= 0.0 and randf() < delta * 0.8:
				_off_for = randf_range(0.04, 0.5)
			level = 0.0 if _off_for > 0.0 else 0.85 + 0.15 * sin(_time * 90.0)
	light_energy = _energy * level
	if fixture_material != null:
		fixture_material.emission_energy_multiplier = _fixture_energy * maxf(level, 0.05)
	if _buzz != null:
		_buzz.volume_db = -22.0 if level > 0.1 else -60.0
