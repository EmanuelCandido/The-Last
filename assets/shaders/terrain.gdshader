shader_type spatial;

// Terreno: mistura grama, chão de floresta, terra e rocha pelos pesos da cor do vértice
// (R rocha, G terra, B floresta). As transições seguem os pixels de uma textura de
// ruído com filtro nearest, para manter o visual pixelado.

uniform sampler2D grass_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D dither_noise : filter_nearest, repeat_enable;
// Metros cobertos por uma repetição das texturas.
uniform float tile_size = 3.0;
uniform float macro_size = 70.0;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_position;
varying vec3 world_normal;

vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = NORMAL;
}

void fragment() {
	vec3 p = world_position / tile_size;
	vec2 uv = p.xz;
	vec3 grass = texture(grass_texture, uv).rgb;
	vec3 forest = texture(forest_texture, uv * 0.9 + 0.31).rgb;
	vec3 dirt = texture(dirt_texture, uv + 0.57).rgb;
	vec3 rock = triplanar(rock_texture, p * 0.8, normalize(world_normal));

	float macro = texture(macro_noise, world_position.xz / macro_size).r;
	// Ruído no tamanho do texel (128 px por repetição) para as bordas saírem "em escada".
	float dither = texture(dither_noise, uv * 2.0).r - 0.5;

	float forest_w = step(0.5, COLOR.b + (macro - 0.5) * 0.5 + dither * 0.35);
	float dirt_w = step(0.5, COLOR.g + dither * 0.5);
	float rock_w = step(0.5, COLOR.r + dither * 0.4);

	vec3 color = mix(grass, forest, forest_w);
	color = mix(color, dirt, dirt_w);
	color = mix(color, rock, rock_w);
	// Variação grande de tom, para quebrar a repetição.
	color *= mix(0.78, 1.12, macro) * tint;

	ALBEDO = color;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
