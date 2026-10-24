extends Node
## Vento global: o clima muda de força devagar, rajadas atravessam o mapa e
## há lugares abrigados.
##
## Força num ponto = abrigo(p) * intensidade(t) * (0.35 + 0.9 * rajada(p, t))
##  - intensidade(t): o clima varia entre calmaria e ventania em ciclos de minutos;
##  - rajada(p, t): ruído arrastado na direção do vento; as frentes de rajada passam
##    pela grama como ondas, então mesmo na ventania há pontos batendo forte e outros não;
##  - abrigo(p): mapa da fase (mata fechada, vales e caverna abrigam; topos e clareiras expõem).
## Os shaders recebem os mesmos dados por parâmetros globais (wind_*), então o que se
## vê balançando bate com o que se ouve.

const GUST_TEXTURE := preload("res://assets/textures/macro_noise.png")

@export var main_direction := Vector2(1.0, 0.35)
## Tamanho (m) de uma repetição do ruído de rajadas.
@export var gust_scale := 70.0
## Velocidade (m/s) das frentes de rajada.
@export var gust_speed := 8.0

## Direção atual (normalizada) no plano (x, z).
var direction := Vector2.RIGHT
## Intensidade do clima (0 = calmaria, 1 = ventania).
var intensity := 0.5

var _time := 0.0
var _offset := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _gust_image: Image
var _exposure_image: Image
var _exposure_rect := Rect2(-1.0, -1.0, 2.0, 2.0)


func _ready() -> void:
	_noise.seed = 99
	_noise.frequency = 0.05
	_noise.fractal_octaves = 2
	_gust_image = GUST_TEXTURE.get_image()
	if _gust_image.is_compressed():
		_gust_image.decompress()
	RenderingServer.global_shader_parameter_set(&"wind_gust_scale", gust_scale)
	var open := Image.create(1, 1, false, Image.FORMAT_L8)
	open.fill(Color.WHITE)
	set_exposure(open, Rect2(-1.0, -1.0, 2.0, 2.0))


func _process(delta: float) -> void:
	_time += delta
	intensity = clampf(0.5 + _noise.get_noise_1d(_time * 0.5) * 0.9, 0.08, 1.0)
	direction = main_direction.normalized().rotated(_noise.get_noise_1d(_time * 0.3 + 500.0) * 0.3)
	_offset += direction * gust_speed * (0.6 + intensity) * delta
	RenderingServer.global_shader_parameter_set(&"wind_direction", direction)
	RenderingServer.global_shader_parameter_set(&"wind_intensity", intensity)
	RenderingServer.global_shader_parameter_set(&"wind_offset", _offset)


## Força do vento (0..~1.2) num ponto do mundo. Mesma conta do shader foliage.
func strength_at(world_position: Vector3) -> float:
	var p := Vector2(world_position.x, world_position.z)
	return exposure_at(p) * aloft_at(world_position)


## O vento no alto, acima do abrigo do chão e da mata (clima × rajada): o que bate num sino
## pendurado a 5 m (RuinBell). No chão, strength_at ainda multiplica pelo abrigo.
func aloft_at(world_position: Vector3) -> float:
	var uv := (Vector2(world_position.x, world_position.z) - _offset) / gust_scale
	var gust := smoothstep(0.35, 0.8, _sample(_gust_image, uv - uv.floor()))
	return intensity * (0.35 + 0.9 * gust)


## Quanto o ponto está exposto ao vento (0 abrigado .. 1 aberto).
func exposure_at(p: Vector2) -> float:
	var uv := ((p - _exposure_rect.position) / _exposure_rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	return _sample(_exposure_image, uv)


## Registra o mapa de abrigo da fase (canal R, 0..1) cobrindo `rect` no plano (x, z).
func set_exposure(image: Image, rect: Rect2) -> void:
	_exposure_image = image
	_exposure_rect = rect
	RenderingServer.global_shader_parameter_set(&"wind_exposure", ImageTexture.create_from_image(image))
	RenderingServer.global_shader_parameter_set(&"wind_exposure_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


## Leitura bilinear de uma imagem em uv (0..1), com centro nos texels igual à GPU.
func _sample(image: Image, uv: Vector2) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var x := uv.x * w - 0.5
	var y := uv.y * h - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var tx := x - x0
	var ty := y - y0
	var a := image.get_pixel(clampi(x0, 0, w - 1), clampi(y0, 0, h - 1)).r
	var b := image.get_pixel(clampi(x0 + 1, 0, w - 1), clampi(y0, 0, h - 1)).r
	var c := image.get_pixel(clampi(x0, 0, w - 1), clampi(y0 + 1, 0, h - 1)).r
	var d := image.get_pixel(clampi(x0 + 1, 0, w - 1), clampi(y0 + 1, 0, h - 1)).r
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)
