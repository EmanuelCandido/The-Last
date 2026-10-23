shader_type canvas_item;
// Visão de quem acorda dopado (flashes e o despertar na cápsula, §7): a imagem borra, as
// cores se separam nas bordas, uma segunda imagem fantasma escorrega por cima, a borda
// escurece e as pálpebras pesam. `amount` 0 = visão limpa; `lids` 0 = olhos abertos,
// 1 = fechados.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float lids : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;

vec3 blurred(vec2 uv, float lod, float spread) {
	// Anel de amostras num nível de mipmap: o bilinear do mip sozinho fica quadriculado.
	vec3 sum = textureLod(screen_texture, uv, lod).rgb * 2.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854 + 0.4;
		vec2 offset = vec2(cos(a), sin(a) * aspect) * spread;
		sum += textureLod(screen_texture, uv + offset, lod).rgb;
	}
	return sum / 10.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_center = uv - 0.5;
	float edge = length(from_center * vec2(aspect, 1.0));
	// A cabeça não para: a imagem boia devagar.
	vec2 drift = vec2(sin(TIME * 0.43), cos(TIME * 0.31)) * 0.003 * amount;
	float lod = mix(0.0, 2.2, amount) + edge * 1.0 * amount;
	float spread = 0.004 * amount;
	vec2 split = from_center * 0.01 * amount * (0.6 + edge);
	vec3 color;
	color.r = blurred(uv + drift + split, lod, spread).r;
	color.g = blurred(uv + drift, lod, spread).g;
	color.b = blurred(uv + drift - split, lod, spread).b;
	// Visão dupla: os olhos não convergem.
	vec2 ghost_offset = vec2(0.018 + 0.008 * sin(TIME * 0.27), 0.004 * cos(TIME * 0.19)) * amount;
	vec3 ghost = blurred(uv + ghost_offset, lod + 0.6, spread * 1.5);
	color = mix(color, ghost, 0.28 * amount);
	// Borda escura e um véu claro no meio, como luz batendo em olho molhado.
	float vignette = smoothstep(1.05, 0.3, edge);
	color *= mix(1.0, vignette, 0.75 * amount + 0.15);
	color += vec3(0.05, 0.07, 0.06) * amount * (1.0 - edge);
	// Pálpebras: bordas de cima e de baixo fechando, mais abertas no meio que nos cantos.
	float lid_edge = 0.5 - lids * 0.52 - from_center.x * from_center.x * 0.7 * lids;
	float open = smoothstep(lid_edge, lid_edge - 0.08, abs(from_center.y));
	COLOR = vec4(color * open, 1.0);
}
