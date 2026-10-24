class_name DayNight
extends Node
## Luz do dia e da noite: sol, céu e cor da neblina seguem Clock.night(), misturando
## Tuning.DAY_LIGHT e Tuning.NIGHT_LIGHT. No meio da passagem a neblina esquenta
## (lusco-fusco). O céu é sempre nublado: de noite não há lua, só um resto de luz azul.
##
## A luz ambiente vem do céu (Environment.ambient_light_source = sky), então escurecer o
## céu escurece tudo o que não é iluminado pelo fogo.

@export var sun: DirectionalLight3D
@export var environment: WorldEnvironment

## O vazio além da borda norte (R3): 0..1, quanto o céu embaixo do horizonte fica preto.
var void_amount := 0.0:
	set(value):
		if absf(value - void_amount) > 0.01 or (value == 0.0 and void_amount != 0.0):
			void_amount = value
			apply(_last_night)

var _sky: ProceduralSkyMaterial
var _sky_rest := {}
var _last_night := -1.0
var _last_rain := -1.0


func _ready() -> void:
	_sky = environment.environment.sky.sky_material as ProceduralSkyMaterial
	_sky_rest = {
		"top": _sky.sky_top_color, "horizon": _sky.sky_horizon_color,
		"ground_bottom": _sky.ground_bottom_color, "ground_horizon": _sky.ground_horizon_color,
		"cover": _sky.sky_cover_modulate,
	}
	apply(Clock.night())


func _process(_delta: float) -> void:
	var night := Clock.night()
	# O céu refaz a luz ambiente quando muda: só mexe quando a diferença aparece.
	if absf(night - _last_night) > 0.004 or absf(Weather.rain - _last_rain) > 0.01:
		apply(night)


func apply(night: float) -> void:
	_last_night = night
	_last_rain = Weather.rain
	# Na chuva o céu fecha: menos sol e menos luz do céu.
	var overcast := 1.0 - Tuning.RAIN_DARK * Weather.rain
	var day := Tuning.DAY_LIGHT
	var dark := Tuning.NIGHT_LIGHT
	var twilight := (1.0 - absf(night * 2.0 - 1.0)) * Tuning.TWILIGHT_WEIGHT
	sun.light_energy = lerpf(day.sun_energy, dark.sun_energy, night) * overcast
	sun.light_color = (day.sun_color as Color).lerp(dark.sun_color, night)
	var fog: Color = (day.fog_color as Color).lerp(dark.fog_color, night).lerp(Tuning.TWILIGHT_FOG, twilight)
	environment.environment.fog_light_color = fog
	var sky_energy: float = lerpf(day.sky_energy, dark.sky_energy, night)
	_sky.energy_multiplier = sky_energy * overcast
	# O olho se acostuma: de noite parte da luz ambiente deixa de vir do céu (quase preto) e
	# passa a ser um piso azulado fixo. A noite continua escura, mas as silhuetas aparecem.
	environment.environment.ambient_light_color = Tuning.NIGHT_AMBIENT_COLOR
	environment.environment.ambient_light_sky_contribution = 1.0 - Tuning.NIGHT_AMBIENT_FLOOR * night
	# O horizonte some na neblina: puxa as cores do céu para a cor dela.
	var tint := fog * (1.0 / maxf(fog.get_luminance(), 0.001)) * Color(_sky_rest.horizon).get_luminance()
	_sky.sky_horizon_color = Color(_sky_rest.horizon).lerp(tint, night * 0.6 + twilight)
	_sky.ground_horizon_color = Color(_sky_rest.ground_horizon).lerp(tint, night * 0.6 + twilight).lerp(Color.BLACK, void_amount)
	_sky.ground_bottom_color = Color(_sky_rest.ground_bottom).lerp(Color.BLACK, void_amount)
	_sky.sky_top_color = Color(_sky_rest.top).lerp(Color(0.2, 0.24, 0.36), night * 0.6)
