shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

// Cartões de folhagem (grama, agulhas de pinheiro, folhas) que balançam com o vento global.
// O vento vem dos parâmetros globais wind_* (autoload Wind): cada instância balança com a
// força do vento no seu ponto (abrigo do lugar + rajadas que viajam pelo mapa).

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
// Deslocamento máximo, em metros, na rajada mais forte.
uniform float sway = 0.25;
// 0: o balanço cresce com a altura do cartão (grama). 1: vem do canal R da cor do vértice (árvores).
uniform float sway_from_color : hint_range(0.0, 1.0) = 0.0;
// Puxa a normal para cima: deixa a luz dos cartões mais uniforme.
uniform float up_normal : hint_range(0.0, 1.0) = 0.6;
// Variação de brilho entre instâncias.
uniform float variation = 0.25;
uniform float translucency = 0.3;
// Abaixo desta distância da câmera a folhagem some (em degraus), para não tampar a visão.
uniform float near_fade = 0.6;
// 1: cada vértice sobe/desce com o relevo sob ele (grama e samambaia em encosta).
uniform float follow_ground : hint_range(0.0, 1.0) = 0.0;
// Com a câmera baixa (encostada no chão), a grama deste raio em volta dela se deita para
// longe da lente, em vez de virar uma parede de cartões na frente do goblin.
uniform float part_radius = 0.75;

global uniform sampler2D terrain_height;
global uniform vec4 terrain_height_rect;
global uniform vec2 wind_direction;
global uniform float wind_intensity;
global uniform vec2 wind_offset;
global uniform float wind_gust_scale;
global uniform sampler2D wind_gust_noise;
global uniform sampler2D wind_exposure;
global uniform vec4 wind_exposure_rect;

varying float instance_variation;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Limiar de dither ordenado (Bayer 4x4) do pixel: os pontos se espalham por igual, sem
// formar listras, e o cartão parece ficar transparente aos poucos.
float bayer(vec2 frag) {
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(frag) & ivec2(3);
	return (m[p.y * 4 + p.x] + 0.5) / 16.0;
}

// Mesma conta de Wind.strength_at(): abrigo * clima * rajada que viaja com o vento.
float wind_strength_at(vec2 p) {
	float g = textureLod(wind_gust_noise, fract((p - wind_offset) / wind_gust_scale), 0.0).r;
	vec2 exposure_uv = clamp((p - wind_exposure_rect.xy) / wind_exposure_rect.zw, vec2(0.0), vec2(1.0));
	float exposure = textureLod(wind_exposure, exposure_uv, 0.0).r;
	return exposure * wind_intensity * (0.35 + 0.9 * smoothstep(0.35, 0.8, g));
}

float ground_at(vec2 p) {
	vec2 uv = clamp((p - terrain_height_rect.xy) / terrain_height_rect.zw, vec2(0.0), vec2(1.0));
	return textureLod(terrain_height, uv, 0.0).r;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (follow_ground > 0.0) {
		// O tufo é plantado no centro; cada vértice acompanha a diferença de altura do
		// chão embaixo dele, então o pé do cartão não fica flutuando na encosta.
		VERTEX.y += (ground_at(VERTEX.xz) - ground_at(origin.xz)) * follow_ground;
	}
	float strength = wind_strength_at(origin.xz);
	float weight = mix(1.0 - UV.y, COLOR.r, sway_from_color);
	weight *= weight;
	float phase = dot(origin.xz, vec2(0.21, 0.17)) + dot(VERTEX.xz, vec2(0.35, 0.29));
	float wave = sin(TIME * (1.3 + strength * 1.6) + phase) * 0.5 + 0.5;
	float bend = strength * 0.55 + wave * (0.15 + strength * 0.5);
	vec2 offset = wind_direction * bend;
	offset += vec2(sin(TIME * 5.7 + phase * 3.1), cos(TIME * 4.9 + phase * 2.3)) * 0.12 * strength;
	VERTEX.xz += offset * weight * sway;
	VERTEX.y -= length(offset) * weight * sway * 0.25;
	if (follow_ground > 0.0) {
		// A lente abre caminho: o pé fica plantado e a ponta deita para fora do raio.
		vec2 away = VERTEX.xz - CAMERA_POSITION_WORLD.xz;
		float d = max(length(away), 0.001);
		float low = 1.0 - smoothstep(1.0, 1.6, CAMERA_POSITION_WORLD.y - origin.y);
		float push = max(part_radius - d, 0.0) * low * sqrt(weight);
		VERTEX.xz += away / d * push;
		VERTEX.y -= push * 0.6;
	}
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), up_normal));
	instance_variation = (hash(floor(origin.xz * 10.0)) - 0.5) * variation;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * tint * (1.0 + instance_variation);
	// Dissolve com padrão de tela (dither) quando o cartão encosta na câmera.
	float camera_distance = length(VERTEX);
	if (camera_distance < near_fade * (0.6 + 0.4 * bayer(FRAGCOORD.xy))) {
		discard;
	}
	// Com cull desligado o Godot inverte a normal do verso; desfaz para os dois lados
	// receberem a mesma luz (senão metade dos cartões fica preta).
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = tex.rgb * translucency;
}
