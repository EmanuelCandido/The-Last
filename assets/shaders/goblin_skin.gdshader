shader_type spatial;
// Pele, trapo e couro do goblin sem emendas: a textura é projetada dos três lados e
// misturada pela normal, tudo na pose de repouso (posição em UV/UV2, normal em COLOR,
// gravadas pelo GoblinLook). Assim ela não escorrega quando os ossos mexem.
// Por cima vem a lama (global goblin_mud, 0..1, do MudCamouflage): manchas que crescem com
// a quantidade, mais grossas nas pernas, pixeladas como a textura.

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.9;
// Metros cobertos por uma repetição da textura.
uniform float texel_span = 0.32;
uniform vec3 mud_color : source_color = vec3(0.34, 0.26, 0.17);
global uniform float goblin_mud;

varying vec3 rest_position;
varying vec3 rest_normal;

void vertex() {
	rest_position = vec3(UV.x, UV.y, UV2.x);
	rest_normal = COLOR.rgb * 2.0 - 1.0;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Ruído de valor 3D em células de `cell` metros.
float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(0.0, 1.0, fract(p));
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void fragment() {
	vec3 weights = pow(abs(normalize(rest_normal)), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	vec3 p = rest_position / texel_span;
	vec3 color = texture(albedo_texture, vec2(p.z, -p.y)).rgb * weights.x
		+ texture(albedo_texture, vec2(p.x, p.z)).rgb * weights.y
		+ texture(albedo_texture, vec2(p.x, -p.y)).rgb * weights.z;
	color *= tint.rgb;
	float rough = roughness;
	if (goblin_mud > 0.001) {
		// Mesmo grão da textura (64 texels por repetição): a lama é pixelada como a pele.
		vec3 cell = floor(rest_position / texel_span * 64.0) / 64.0 * texel_span;
		float blotch = value_noise(cell * 14.0) * 0.65 + value_noise(cell * 40.0) * 0.35;
		// Manchas, não uma pintura: cheia, cobre uns 2/3 das pernas e 1/4 da cabeça.
		float low = clamp(1.0 - rest_position.y * 0.9, 0.0, 1.0);
		float cover = smoothstep(0.0, 0.05, goblin_mud * (0.3 + 0.36 * low) - blotch);
		vec3 mud = mud_color * (0.75 + 0.5 * hash(cell * 7.0));
		color = mix(color, mud, cover * 0.9);
		// Lama fresca brilha um pouco; seca, fica fosca.
		rough = mix(rough, mix(0.95, 0.55, goblin_mud), cover);
	}
	ALBEDO = color;
	ROUGHNESS = rough;
}
