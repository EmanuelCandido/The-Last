shader_type canvas_item;
// A memória de outro ciclo (§7): a imagem desbotada, com grão e as bordas apagando, como um
// vídeo velho; `glitch` (0..1) quebra a tela em faixas que escorregam, separa as cores e
// enche de chiado, até sobrar só o ruído.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float memory : hint_range(0.0, 1.0) = 1.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.7778;

// Hash sem seno (o de seno vira listras diagonais com números grandes).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 24.0);
	// Faixas que escorregam de lado: mais e maiores com o glitch.
	float band = floor(uv.y * mix(18.0, 60.0, hash(vec2(t, 3.0))));
	float slip = hash(vec2(band, t)) - 0.5;
	float slipping = step(1.0 - glitch * 0.9, hash(vec2(band * 1.7, t + 1.0)));
	uv.x += slip * 0.12 * glitch * slipping;
	// Blocos que travam num pedaço errado da tela.
	vec2 block = floor(uv * vec2(16.0, 9.0));
	float stuck = step(1.0 - glitch * glitch * 0.5, hash(block + t));
	uv = mix(uv, uv + (vec2(hash(block), hash(block + 9.0)) - 0.5) * 0.2, stuck);
	// As cores se separam.
	float split = 0.002 * memory + 0.02 * glitch;
	vec3 color = vec3(
		texture(screen, uv + vec2(split, 0.0)).r,
		texture(screen, uv).g,
		texture(screen, uv - vec2(split, 0.0)).b);
	// Desbotada: perde a cor, puxa para um tom frio, e o contraste afrouxa.
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 faded = mix(vec3(gray), color, 0.35) * vec3(0.92, 0.97, 1.04);
	color = mix(color, faded * 1.1 + 0.025, memory);
	// Grão, as bordas apagando e linhas de varredura.
	float grain = hash(floor(FRAGCOORD.xy * 0.5) + t * 17.0) - 0.5;
	color += grain * (0.06 * memory + 0.5 * glitch * glitch);
	vec2 centered = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	color *= 1.0 - 0.8 * memory * smoothstep(0.5, 1.1, length(centered));
	color *= 1.0 - 0.08 * memory * step(0.5, fract(SCREEN_UV.y * 180.0));
	// No fim do glitch só sobra o chiado.
	float noise = hash(floor(SCREEN_UV * vec2(320.0, 180.0)) + t);
	color = mix(color, vec3(noise * 0.6), smoothstep(0.75, 1.0, glitch));
	COLOR = vec4(color, 1.0);
}
