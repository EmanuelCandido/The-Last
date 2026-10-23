class_name VitalsHud
extends Control
## HUD de sinais vitais (§7): no canto de baixo, o traçado do coração, o batimento e o oxigênio
## de Ari. No Abrigo fica sempre lá. Na floresta, depois do R3 (flag "climate_cut"), aparece de
## leve e falhando quando a vida está baixa: é a verdade vazando por cima do jogo.
## O batimento sobe nos últimos segundos de lucidez e com o Zelador atrás de Ari; o oxigênio cai
## com o ar preso.

const ECG_SHADER := preload("res://assets/shaders/ecg_hud.gdshader")
const TRACE_SIZE := Vector2(150.0, 34.0)
const COLOR := Color(0.45, 1.0, 0.62)

var _ecg: ShaderMaterial
var _label: Label
var _spo2 := Tuning.SPO2_NORMAL
var _bpm := Tuning.SHELTER_BPM
var _alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 22.0
	offset_top = -104.0
	offset_right = offset_left + TRACE_SIZE.x
	offset_bottom = -52.0
	var trace := ColorRect.new()
	trace.size = TRACE_SIZE
	trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecg = ShaderMaterial.new()
	_ecg.shader = ECG_SHADER
	_ecg.set_shader_parameter(&"trace_color", COLOR)
	trace.material = _ecg
	add_child(trace)
	_label = Label.new()
	_label.position = Vector2(0.0, TRACE_SIZE.y + 2.0)
	_label.add_theme_font_size_override(&"font_size", 13)
	_label.add_theme_color_override(&"font_color", COLOR)
	add_child(_label)
	modulate.a = 0.0


func _process(delta: float) -> void:
	var target := 0.0
	var bpm := Tuning.SHELTER_BPM
	var holding := false
	var flicker := 0.0
	var spo2_rest := Tuning.SPO2_NORMAL
	var shelter := Game.shelter
	if Game.awake and shelter != null and shelter.ari != null:
		target = Tuning.VITALS_HUD_ALPHA
		holding = shelter.ari.breath_held
		var visit := shelter.visit
		if visit != null and visit.active:
			var warning := clampf(1.0 - visit.seconds_left / Tuning.LUCIDITY_WARNING, 0.0, 1.0)
			bpm = lerpf(Tuning.SHELTER_BPM + 6.0, 138.0, warning)
		if shelter.keeper != null and shelter.keeper.state in [Keeper.State.FOUND, Keeper.State.CAPTURE]:
			bpm += 24.0
	elif Story.has_flag(&"climate_cut") and Game.player != null and not Game.resting and not Game.cutscene:
		var hurt := clampf((Tuning.LOW_HEALTH - Vitals.health) / Tuning.LOW_HEALTH, 0.0, 1.0)
		flicker = 0.7
		target = Tuning.VITALS_HUD_FOREST_ALPHA * hurt * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.0021))
		bpm = lerpf(96.0, 132.0, hurt)
		holding = Game.player.breath_held
		spo2_rest -= 5.0 * hurt
	if Game.in_flash():
		target = 0.0
	_alpha = move_toward(_alpha, target, delta * 1.5)
	modulate.a = _alpha
	visible = _alpha > 0.001
	if not visible:
		return
	_bpm = lerpf(_bpm, bpm, 1.0 - exp(-1.5 * delta))
	if holding:
		_spo2 = maxf(_spo2 - Tuning.SPO2_HOLD_DROP * delta, 84.0)
	else:
		_spo2 = move_toward(_spo2, spo2_rest, Tuning.SPO2_RECOVER * delta)
	_ecg.set_shader_parameter(&"bpm", _bpm)
	_ecg.set_shader_parameter(&"flicker", flicker)
	_label.text = "♥ %d    SpO₂ %d%%" % [roundi(_bpm), roundi(_spo2)]
