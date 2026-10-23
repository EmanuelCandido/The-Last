class_name PropLook
extends RefCounted
## Materiais dos props montados por código (coleta, tocaia, defumador, troféus), no estilo do
## resto do mundo: texturas pixeladas (filtro nearest com mipmaps) e folhagem pelo
## foliage.gdshader, que balança com o vento. Cada material é criado uma vez e compartilhado.

const FOLIAGE := preload("res://assets/shaders/foliage.gdshader")

static var _cache := {}


## Casca de galho, como a das árvores.
static func bark() -> StandardMaterial3D:
	return _textured(&"bark", preload("res://assets/textures/bark.png"), Color.WHITE, false)


## Osso e chifre: o reboco claro amarelado, projetado nos três lados.
static func bone() -> StandardMaterial3D:
	return _textured(&"bone", preload("res://assets/textures/plaster.png"), Color(0.9, 0.84, 0.7), true, 6.0)


## Chapéu de cogumelo: o couro manchado puxado para o castanho.
static func mushroom_cap() -> StandardMaterial3D:
	return _textured(&"cap", preload("res://assets/textures/leather.png"), Color(1.15, 0.82, 0.58), true, 9.0)


## Pé de cogumelo: o reboco creme.
static func mushroom_stem() -> StandardMaterial3D:
	return _textured(&"stem", preload("res://assets/textures/plaster.png"), Color(0.95, 0.9, 0.76), true, 12.0)


## Ramos de pinheiro (tocaia), iguais aos das árvores.
static func needles() -> ShaderMaterial:
	return _foliage(&"needles", preload("res://assets/textures/pine_branch.png"), Color(0.85, 0.95, 0.85), 0.35, 0.3)


## Folhas miúdas do arbusto de frutinhas.
static func bush() -> ShaderMaterial:
	return _foliage(&"bush", preload("res://assets/textures/bush_card.png"), Color.WHITE, 0.25, 0.4)


## Os cachos de frutinhas, por cima das folhas.
static func berries() -> ShaderMaterial:
	return _foliage(&"berries", preload("res://assets/textures/berry_card.png"), Color.WHITE, 0.25, 0.4)


static func _textured(key: StringName, texture: Texture2D, tint: Color, triplanar: bool, scale := 1.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 1.0
	if triplanar:
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * scale
	_cache[key] = material
	return material


static func _foliage(key: StringName, texture: Texture2D, tint: Color, sway: float, up_normal: float) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"alpha_cut", 0.45)
	material.set_shader_parameter(&"sway", sway)
	material.set_shader_parameter(&"sway_from_color", 1.0)
	material.set_shader_parameter(&"up_normal", up_normal)
	material.set_shader_parameter(&"variation", 0.2)
	material.set_shader_parameter(&"translucency", 0.3)
	_cache[key] = material
	return material
