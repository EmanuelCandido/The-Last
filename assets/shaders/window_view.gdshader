shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// O que se vê pela janela da sala 2714 (§6.1): o pinheiral e a Ruína de São Brás afundados
// na Cinza. É a mesma paisagem que o Zelador copiou para a floresta. A pintura é feita pela
// direção do olhar (como um céu), não pela posição no quadro: a paisagem fica no infinito, com
// o horizonte na altura dos olhos, vista da cápsula ou de pé. Pixelada como o resto do jogo.

uniform vec3 fog_color : source_color = vec3(0.6, 0.62, 0.62);
uniform vec3 ground_color : source_color = vec3(0.16, 0.17, 0.15);
uniform vec3 pine_color : source_color = vec3(0.1, 0.12, 0.1);
// Quanto da volta cabe na pintura: largura (rad, para os dois lados de quem olha pela janela)
// e altura (rad de uma unidade de `h`).
uniform float azimuth_range = 1.6;
uniform float elevation_range = 0.5;
uniform vec2 pixels = vec2(220.0, 70.0);

// Onde fica a ruína (em u): uns 35° para o lado da cápsula, no meio da vista de quem está
// deitado e no canto da vista de quem está de pé na frente da janela.
const float RUIN_X = 0.89;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// Uma fileira de pinheiros: 1 dentro da silhueta. `spacing` em u; alturas em h.
float pines(vec2 uv, float base, float spacing, float height, float seed, float aspect) {
	float x = uv.x / spacing;
	float covered = 0.0;
	for (int k = -1; k <= 1; k++) {
		float cell = floor(x) + float(k);
		float center = cell + 0.25 + 0.5 * hash(cell + seed);
		float h = height * (0.6 + 0.6 * hash(cell * 1.7 + seed));
		float local = abs(x - center) * spacing;
		float top = base + h;
		// Cone com galhos em degraus: a borda serrilha a cada patamar.
		float t = clamp((uv.y - base) / h, 0.0, 1.0);
		float half_width = (1.0 - t) * h * 0.45 * aspect * (0.85 + 0.15 * sin(t * 40.0 + cell));
		covered = max(covered, step(uv.y, top) * step(local, half_width) * step(base - 0.2, uv.y));
	}
	return covered;
}

// A capela caída: nave com o telhado quebrado, uma torre partida e o arco da porta vazio.
float ruin(vec2 uv, float aspect) {
	// Escala 1,75: a capela ocupa uns 10° do olhar (está perto, logo depois do pinheiral).
	vec2 p = vec2((uv.x - RUIN_X) / aspect, uv.y - 0.27) / 1.75;
	float nave = step(abs(p.x - 0.02), 0.075) * step(p.y, 0.09 - max(p.x - 0.04, 0.0) * 1.4);
	float roof = step(abs(p.x - 0.0), 0.06) * step(p.y, 0.15 - abs(p.x) * 1.1) * step(0.0, p.y);
	float tower = step(abs(p.x + 0.07), 0.022) * step(p.y, 0.2 - step(p.x + 0.07, 0.0) * 0.03);
	float door = step(abs(p.x - 0.01), 0.014) * step(p.y, 0.04 + 0.01 * cos((p.x - 0.01) * 110.0));
	return max(max(nave, roof), tower) * (1.0 - door) * step(-0.02, p.y);
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 dir = normalize(world - CAMERA_POSITION_WORLD);
	// u: 0,5 = olhando reto para fora (+Z); h: 0,3 = a altura dos olhos.
	vec2 uv = vec2(atan(dir.x, dir.z) / azimuth_range + 0.5, asin(clamp(dir.y, -1.0, 1.0)) / elevation_range + 0.3);
	uv = floor(uv * pixels) / pixels;
	// Proporção de uma unidade de u para uma de h, para os desenhos não esticarem.
	float aspect = elevation_range / azimuth_range;
	// Céu de Cinza: claro no horizonte, um pouco mais escuro em cima.
	vec3 color = mix(fog_color, fog_color * 0.86, smoothstep(0.35, 1.0, uv.y));
	// Do fundo para a frente: cada camada mais escura e menos afogada na neblina.
	float far_pines = pines(uv, 0.27, 0.012, 0.07, 3.0, aspect);
	color = mix(color, mix(pine_color, fog_color, 0.78), far_pines);
	float ruin_shape = ruin(uv, aspect);
	color = mix(color, mix(vec3(0.12, 0.12, 0.11), fog_color, 0.3), ruin_shape);
	float clearing = 1.0 - step(abs(uv.x - RUIN_X), 0.06);
	float mid_pines = pines(uv + vec2(0.37, 0.0), 0.25, 0.02, 0.13, 11.0, aspect) * clearing;
	color = mix(color, mix(pine_color, fog_color, 0.55), mid_pines);
	float ground = step(uv.y, 0.27 + 0.01 * sin(uv.x * 30.0));
	color = mix(color, mix(ground_color, fog_color, 0.45), ground);
	float near_pines = pines(uv + vec2(0.11, 0.0), 0.15, 0.05, 0.26, 23.0, aspect) * (1.0 - step(abs(uv.x - RUIN_X), 0.08));
	color = mix(color, mix(pine_color, fog_color, 0.25), near_pines);
	// Bancos de neblina passando devagar.
	float drift = sin(uv.x * 20.0 + TIME * 0.05) * 0.5 + sin(uv.x * 51.0 - TIME * 0.08) * 0.25;
	float bank = smoothstep(0.2, 0.3, uv.y + drift * 0.02) * (1.0 - smoothstep(0.3, 0.42, uv.y + drift * 0.03));
	color = mix(color, fog_color, bank * 0.35);
	ALBEDO = color;
}
