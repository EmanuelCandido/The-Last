shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// A imagem de uma câmera externa do Abrigo 9 (§8): Vilarrasa com gente, vista em preto e branco
// esverdeado, com chiado, linhas e a faixa que rola. Desenhada por conta, sem textura.
// `view`: 0 mercado, 1 telhados com chaminés, 2 rua, 3 portão norte (os pinheiros).
// `signal_amount`: 0 = só chiado (desligada), 1 = imagem.

uniform int view = 0;
uniform float signal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.43;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

// 1 dentro do retângulo de centro `c` e meia medida `h`.
float rect(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return 1.0 - step(0.0, max(d.x, d.y));
}

// Uma pessoa de pé em `feet`, com altura `s`, andando (`phase` mexe as pernas).
float person(vec2 p, vec2 feet, float s, float phase) {
	float swing = sin(phase) * s * 0.09;
	float body = rect(p, feet + vec2(0.0, s * 0.55), vec2(s * 0.12, s * 0.27));
	float head = 1.0 - step(s * 0.1, length(p - feet - vec2(0.0, s * 0.92)));
	float leg_a = rect(p, feet + vec2(swing, s * 0.14), vec2(s * 0.035, s * 0.14));
	float leg_b = rect(p, feet + vec2(-swing, s * 0.14), vec2(s * 0.035, s * 0.14));
	return max(max(body, head), max(leg_a, leg_b));
}

// Fileira de prédios: telhados de alturas sorteadas a partir de `base`, com janelas.
float skyline(vec2 p, float base, float height, float width, float salt, out float windows) {
	float index = floor(p.x / width);
	float top = base + hash(vec2(index, salt)) * height;
	float inside = step(p.y, top);
	vec2 cell = fract(vec2(p.x / width * 4.0, p.y * 22.0));
	windows = inside * step(0.35, cell.x) * step(cell.x, 0.75) * step(0.3, cell.y) * step(cell.y, 0.75) * step(p.y, top - 0.03);
	return inside;
}

// Fumaça subindo de `at`, levada pelo vento para a direita.
float smoke(vec2 p, vec2 at, float t) {
	vec2 q = p - at;
	if (q.y < 0.0) {
		return 0.0;
	}
	float spread = 0.02 + q.y * 0.35;
	float drift = q.y * q.y * 0.9;
	float cone = 1.0 - smoothstep(spread * 0.4, spread, abs(q.x - drift));
	float puffs = fbm(vec2(q.x * 9.0 - t * 0.2, q.y * 6.0 - t * 0.6));
	return cone * smoothstep(0.35, 0.7, puffs) * (1.0 - smoothstep(0.1, 0.45, q.y));
}

// Gente atravessando: `count` pessoas em faixas de profundidade entre `near` e `far` (y dos pés).
float crowd(vec2 p, float t, int count, float near, float far, float salt, out float shade) {
	float mask = 0.0;
	shade = 0.2;
	for (int i = 0; i < 12; i++) {
		if (i >= count) {
			break;
		}
		float fi = float(i) + salt;
		float depth = hash(vec2(fi, 1.7));
		float y = mix(near, far, depth);
		float s = mix(0.3, 0.11, depth);
		float direction = hash(vec2(fi, 4.1)) < 0.5 ? -1.0 : 1.0;
		float speed = mix(0.02, 0.05, hash(vec2(fi, 2.3)));
		float span = aspect + 0.4;
		float x = mod(hash(vec2(fi, 9.2)) * span + t * speed * direction, span) - 0.2;
		float m = person(p, vec2(x, y), s, t * 7.0 * speed / 0.03 + fi);
		if (m > 0.0) {
			mask = 1.0;
			shade = mix(0.08, 0.32, hash(vec2(fi, 6.6)));
		}
	}
	return mask;
}

float scene_market(vec2 p, float t) {
	float color = 0.72 + p.y * 0.15;
	float windows;
	float far = skyline(p, 0.5, 0.25, 0.16, 3.0, windows);
	color = mix(color, 0.42 - windows * 0.18, far);
	color = mix(color, 0.85, smoke(p, vec2(0.37, 0.71), t) * 0.8);
	color = mix(color, 0.85, smoke(p, vec2(1.02, 0.64), t + 3.0) * 0.6);
	// O chão da praça (pedras) e as barracas com toldo listrado.
	float ground = step(p.y, 0.36);
	color = mix(color, 0.52 + noise(p * vec2(60.0, 90.0)) * 0.1, ground);
	for (int i = 0; i < 3; i++) {
		float x = 0.3 + float(i) * 0.42;
		float stripes = step(0.5, fract(p.x * 30.0));
		color = mix(color, mix(0.25, 0.6, stripes), rect(p, vec2(x, 0.47), vec2(0.15, 0.03)));
		color = mix(color, 0.2, rect(p, vec2(x - 0.13, 0.4), vec2(0.008, 0.07)));
		color = mix(color, 0.2, rect(p, vec2(x + 0.13, 0.4), vec2(0.008, 0.07)));
		color = mix(color, 0.3, rect(p, vec2(x, 0.33), vec2(0.13, 0.025)));
	}
	float shade;
	float people = crowd(p, t, 11, 0.04, 0.3, 0.0, shade);
	return mix(color, shade, people);
}

float scene_roofs(vec2 p, float t) {
	float color = 0.75 + p.y * 0.12;
	float windows;
	float far = skyline(p, 0.35, 0.2, 0.1, 7.0, windows);
	color = mix(color, 0.5, far);
	// Telhados de duas águas, perto, e as chaminés soltando fumaça.
	for (int i = 0; i < 4; i++) {
		float x = 0.15 + float(i) * 0.38;
		float roof = step(p.y, 0.42 - abs(p.x - x) * 0.6) * step(abs(p.x - x), 0.2);
		color = mix(color, 0.22 + noise(p * 80.0) * 0.05, roof);
		vec2 chimney = vec2(x + 0.07, 0.42);
		color = mix(color, 0.18, rect(p, chimney, vec2(0.018, 0.05)));
		color = mix(color, 0.88, smoke(p, chimney + vec2(0.0, 0.05), t + float(i) * 1.7));
	}
	color = mix(color, 0.16, step(p.y, 0.12));
	// Uma corda de roupa entre duas casas, balançando.
	float line = 0.2 + sin((p.x - 0.55) * 8.0) * 0.015;
	float cloth = rect(p, vec2(0.6 + sin(t * 1.3) * 0.004, line - 0.03), vec2(0.03, 0.03));
	color = mix(color, 0.8, cloth * step(0.5, p.x) * step(p.x, 0.75));
	return color;
}

float scene_street(vec2 p, float t) {
	float color = 0.7 + p.y * 0.15;
	// A rua em perspectiva, fugindo para o meio da imagem.
	vec2 vanish = vec2(aspect * 0.5, 0.52);
	float side = abs(p.x - vanish.x) / max(vanish.y - p.y, 0.001);
	float facade = step(0.9, side) * step(p.y, vanish.y + 0.4);
	float windows = step(0.5, fract(p.y * 18.0)) * step(0.5, fract(side * 3.0));
	color = mix(color, 0.38 - windows * 0.12, facade);
	float ground = step(p.y, vanish.y) * (1.0 - facade);
	color = mix(color, 0.58 + step(0.97, fract(side * 6.0)) * 0.1, ground);
	float shade;
	float people = crowd(p, t, 8, 0.03, 0.4, 20.0, shade);
	color = mix(color, shade, people);
	// Uma carroça indo e voltando.
	float cart_x = mod(t * 0.03, aspect + 0.6) - 0.3;
	color = mix(color, 0.15, rect(p, vec2(cart_x, 0.17), vec2(0.12, 0.05)));
	color = mix(color, 0.1, 1.0 - step(0.035, length(p - vec2(cart_x - 0.07, 0.11))));
	color = mix(color, 0.1, 1.0 - step(0.035, length(p - vec2(cart_x + 0.07, 0.11))));
	return color;
}

float scene_gate(vec2 p, float t) {
	float color = 0.78 + p.y * 0.1;
	// O pinheiral na neblina, como da janela da sala 2714.
	for (int i = 0; i < 9; i++) {
		float x = float(i) * 0.19 + hash(vec2(float(i), 3.0)) * 0.08;
		float h = 0.25 + hash(vec2(float(i), 5.0)) * 0.2;
		float tree = step(p.y, 0.42 + h - abs(p.x - x) * 3.2) * step(0.42, p.y);
		color = mix(color, 0.55 - h * 0.4, tree);
	}
	color = mix(color, 0.5 + noise(p * 40.0) * 0.08, step(p.y, 0.42));
	// O portão, a estrada e um caminhão que passa de vez em quando.
	color = mix(color, 0.2, rect(p, vec2(0.3, 0.42), vec2(0.012, 0.16)));
	color = mix(color, 0.2, rect(p, vec2(0.62, 0.42), vec2(0.012, 0.16)));
	color = mix(color, 0.25, rect(p, vec2(0.46, 0.56), vec2(0.17, 0.012)));
	float truck_x = mod(t * 0.06, 4.0) - 0.6;
	color = mix(color, 0.12, rect(p, vec2(truck_x, 0.3), vec2(0.18, 0.08)));
	color = mix(color, 0.2, rect(p, vec2(truck_x + 0.22, 0.27), vec2(0.06, 0.05)));
	float shade;
	float people = crowd(p, t, 5, 0.06, 0.3, 40.0, shade);
	color = mix(color, shade, people);
	// A equipe de resgate parada no portão (F14): macacão claro e o respirador com os dois filtros
	// escuros na frente do rosto, a mesma silhueta da máscara dos orcs.
	for (int i = 0; i < 3; i++) {
		float s = 0.27 - float(i) * 0.02;
		vec2 feet = vec2(0.38 + float(i) * 0.085, 0.16 + float(i % 2) * 0.025);
		float sway = sin(t * 0.8 + float(i) * 2.1) * 0.004;
		color = mix(color, 0.68, person(p, feet + vec2(sway, 0.0), s, 0.0));
		// O visor numa faixa escura em cima e os filtros embaixo, de lado, na altura da boca.
		vec2 face = feet + vec2(sway, s * 0.84);
		color = mix(color, 0.12, rect(p, face + vec2(0.0, s * 0.11), vec2(s * 0.075, s * 0.022)));
		float filters = max(1.0 - step(s * 0.032, length(p - face - vec2(-s * 0.06, 0.0))),
			1.0 - step(s * 0.032, length(p - face - vec2(s * 0.06, 0.0))));
		color = mix(color, 0.07, filters);
		color = mix(color, 0.3, rect(p, face + vec2(0.0, -s * 0.01), vec2(s * 0.03, s * 0.025)));
	}
	return color;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// A imagem treme de vez em quando numa linha.
	float jitter = (hash(vec2(floor(uv.y * 90.0), floor(t * 12.0))) - 0.5) * 0.006 * step(0.93, hash(vec2(floor(t * 3.0), 1.0)));
	vec2 p = vec2((uv.x + jitter) * aspect, 1.0 - uv.y);
	float image;
	if (view == 0) {
		image = scene_market(p, t);
	} else if (view == 1) {
		image = scene_roofs(p, t);
	} else if (view == 2) {
		image = scene_street(p, t);
	} else {
		image = scene_gate(p, t);
	}
	image += (hash(uv * 400.0 + fract(t) * 37.0) - 0.5) * 0.14;
	image *= 0.92 + 0.08 * sin(uv.y * 520.0);
	float bar = smoothstep(0.0, 0.08, abs(fract(uv.y + t * 0.06) - 0.5) - 0.42);
	image *= 0.85 + 0.15 * bar;
	float snow = hash(floor(uv * vec2(170.0, 120.0)) + floor(t * 24.0) * 1.37);
	float value = mix(snow * 0.45, image, signal_amount);
	vec2 edge = uv - 0.5;
	value *= 1.0 - dot(edge, edge) * 1.1;
	ALBEDO = vec3(value) * vec3(0.78, 1.0, 0.84) * 0.95;
}
