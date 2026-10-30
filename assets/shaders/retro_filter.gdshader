shader_type canvas_item;
// Filtro retrô sobre toda a imagem 3D (floresta e Abrigo), abaixo da interface e do Brilho.
// Na ordem: pixel grande (a média do bloco, em 4 amostras lineares), brilho estourando em volta das
// luzes, cor quente e um pouco dessaturada, vinheta, grão e poucas cores por canal
// com um pontilhado Bayer 4x4 na grade dos pixels grandes. Os números vêm de Tuning.RETRO_*.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// Os mipmaps da tela do Godot já vêm borrados: servem para o brilho, não para a média do bloco.
uniform sampler2D blurred_screen : hint_screen_texture, filter_linear_mipmap;
uniform float virtual_height = 180.0;
uniform float levels = 32.0;
uniform float dither = 1.0;
uniform float bloom = 0.8;
uniform float bloom_threshold = 0.55;
uniform vec3 bloom_tint = vec3(1.0, 0.72, 0.45);
uniform float saturation = 0.7;
uniform vec3 shadow_tint = vec3(0.82, 0.66, 0.6);
uniform vec3 light_tint = vec3(1.08, 0.98, 0.86);
uniform float vignette = 0.75;
uniform vec2 vignette_range = vec2(0.25, 0.95);
uniform float grain = 0.05;
uniform float grain_fps = 24.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	// Bloco inteiro de pixels de tela: o pixel grande fica nítido em qualquer resolução.
	float block = max(1.0, round(size.y / virtual_height));
	vec2 cell = floor(FRAGCOORD.xy / block);
	vec2 uv = (cell + 0.5) * block * SCREEN_PIXEL_SIZE;
	// Cada amostra linear num canto de pixel tira a média de 2x2; quatro cobrem o bloco de 4x4.
	vec2 quarter = block * 0.25 * SCREEN_PIXEL_SIZE;
	vec3 color = (texture(screen_texture, uv + vec2(-quarter.x, -quarter.y)).rgb
		+ texture(screen_texture, uv + vec2(quarter.x, -quarter.y)).rgb
		+ texture(screen_texture, uv + vec2(-quarter.x, quarter.y)).rgb
		+ texture(screen_texture, uv + quarter).rgb) * 0.25;
	color = max(color, vec3(0.0));

	// Brilho: os mipmaps altos são a tela borrada; só o que passa do limiar acende em volta.
	vec3 halo = textureLod(blurred_screen, uv, 2.0).rgb * 0.6 + textureLod(blurred_screen, uv, 3.5).rgb * 0.4;
	float halo_l = dot(halo, vec3(0.299, 0.587, 0.114));
	color += bloom_tint * bloom * max(halo_l - bloom_threshold, 0.0) / (1.0 - bloom_threshold);

	// Cor: dessatura e esquenta (sombra marrom, luz creme). Nada de esmagar as sombras: a cena já é escura.
	float l = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(l), color, saturation);
	color *= mix(shadow_tint, light_tint, smoothstep(0.0, 0.6, l));

	// Vinheta na grade dos pixels grandes (a borda escurece em degraus pontilhados).
	vec2 centered = (uv - 0.5) * vec2(size.x / size.y, 1.0);
	color *= 1.0 - vignette * smoothstep(vignette_range.x, vignette_range.y, length(centered));

	// Grão, um por pixel grande, trocando no ritmo de filme.
	float frame = floor(TIME * grain_fps);
	color += (hash(cell + frame * vec2(17.0, 31.0)) - 0.5) * grain;

	// Poucas cores por canal, com o Bayer decidindo o degrau.
	ivec2 b = ivec2(mod(cell, 4.0));
	float threshold = 0.5 + (BAYER[b.y * 4 + b.x] / 16.0 - 0.47) * dither;
	color = floor(clamp(color, 0.0, 1.0) * (levels - 1.0) + threshold) / (levels - 1.0);
	COLOR = vec4(color, 1.0);
}
